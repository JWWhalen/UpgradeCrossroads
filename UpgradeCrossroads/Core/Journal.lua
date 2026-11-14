-- Quest-log browsing over the existing recommendation rules. Ownership is
-- observed from the client; completing a quest or a manual checklist is never
-- treated as proof that its reward was obtained.
local _, XC = ...
local laneNames={all=true,reliable=true,dungeon=true,longterm=true}
local raidZones={[1977]=true,[2677]=true,[3428]=true,[3429]=true,[3456]=true,[2717]=true,[409]=true}
-- These quests are catalogued by pickup zone. The instance association is
-- used only for browsing, so quest givers and navigation stay with the quest.
-- https://www.wowhead.com/forever/quests/dungeons/the-deadmines
-- https://www.wowhead.com/forever/quests/dungeons/wailing-caverns
local questDungeon={
    [166]=1581,[167]=1581,[168]=1581,[214]=1581,[2040]=1581,
    [914]=718,[962]=718,[1486]=718,[1487]=718,
}

local function copy(t)
    local out={}; for k,v in pairs(t or {}) do out[k]=v end; return out
end
local function itemKey(id)
    id=tonumber(id)
    if not id or id<=0 or id~=math.floor(id) then return nil end
    return tostring(id)
end
function XC:JournalState()
    local db=self.db
    if not db then return nil end
    if type(db.journal)~="table" then db.journal={} end
    local state=db.journal
    if type(state.removed)~="table" then state.removed={} end
    if type(state.obtained)~="table" then state.obtained={} end
    state.schema=1
    return state
end
function XC:InvalidateJournal()
    self.journalCache=nil
end

local function sourceLane(source)
    if source.kind=="dungeon" or source.kind=="raid" or source.group then return "dungeon" end
    if source.kind=="world" then return "longterm" end
    return "reliable"
end
local function minimumLevel(item,source,context,slot)
    return math.max(source.minLevel or 0,XC.Rules.MinimumLevel(item,context,slot))
end
local function destinationKey(kind,source)
    local zone=source.zone
    if not zone or zone=="" or zone=="Unknown zone" then return nil end
    local id=tonumber(source.zoneID)
    return kind..":"..tostring(id and id>0 and id or zone)
end
local function dungeonKey(source)
    if source.kind=="quest" and questDungeon[source.questID] then
        return "dungeon:"..questDungeon[source.questID]
    end
    return destinationKey("dungeon",source)
end
local function eachDestination(source,dungeonZones,visit)
    local quest=source.kind=="quest"
    if quest then
        local key=destinationKey("quest",source)
        if key then visit(key,source.zone,"quest") end
    end
    if source.kind=="dungeon" or quest then
        local key=dungeonKey(source)
        if key and (not quest or dungeonZones[key]) then
            visit(key,dungeonZones[key] or source.zone,"dungeon")
        end
    end
end
local function matchesDestination(source,dungeonZones,key)
    if source.kind=="quest" and destinationKey("quest",source)==key then return true end
    return (source.kind=="dungeon" or (source.kind=="quest" and dungeonZones[key]))
        and dungeonKey(source)==key
end
local function sourcesFor(item, context, options, slot, filter, historical, destination, maxLevel, dungeonZones)
    local out={}
    local ctx=context
    if historical then
        -- A completed reward quest is a valid historical source. Ordinary
        -- recommendations still test the actual character's quest history.
        ctx=copy(context); ctx.completed={}
    end
    for _,source in ipairs(item.sources or {}) do
        local lane=sourceLane(source)
        local fits=filter=="all" or filter=="longterm" or filter==lane
        local level=minimumLevel(item,source,context,slot)
        if fits and (historical or filter=="longterm" or level<=context.level)
            and (not maxLevel or level<=maxLevel)
            and (not destination or matchesDestination(source,dungeonZones,destination))
            and XC.Rules.SourceAllowed(source,ctx,options) then
            out[#out+1]=source
        end
    end
    return out
end
local function makeEntry(self, original, slot, filter, historical, pin, removed, context, destination, maxLevel, dungeonZones)
    context=context or self.context or self.Client.Context()
    local sources=sourcesFor(original.item,context,self.db.options,slot,filter,historical,destination,maxLevel,dungeonZones)
    -- Saved history remains inspectable when a source vanished from a later
    -- catalog. It does not become an active recommendation through this path.
    if #sources==0 and historical and original.source then
        local historicalItem=copy(original.item); historicalItem.sources={original.source}
        sources=sourcesFor(historicalItem,context,self.db.options,slot,filter,true,destination,maxLevel,dungeonZones)
    end
    if #sources==0 then return nil end
    local row=copy(original)
    row.slotID=slot.id; row.slotLabel=slot.label
    row.key=tostring(slot.id)..":"..row.item.id
    row.sourceSelectionKey=row.key..(destination and ":"..destination or "")..(maxLevel and ":level"..maxLevel or "")
    self.journalSourceSelection=self.journalSourceSelection or {}
    local selected=self.journalSourceSelection[row.sourceSelectionKey]
    if not selected then
        selected=1
        for i,source in ipairs(sources) do if source==original.source then selected=i; break end end
    end
    selected=math.max(1,math.min(#sources,selected))
    row.sources=sources; row.source=sources[selected]
    row.sourceIndex=selected; row.sourceCount=#sources
    row.lane=sourceLane(row.source)
    if filter=="longterm" then row.lane="longterm" end
    row.minLevel=minimumLevel(row.item,row.source,context,slot)
    row.locked=row.minLevel>context.level
    row.pin=pin; row.obtained=historical and not removed or false; row.removed=removed or false
    return row
end

function XC:BuildJournalCache()
    local state=self:JournalState(); if not state then return nil end
    local context=self.context or self.Client.Context()
    local profile=self:GetProfile(self.db.profile)
    local catalog=self.Client.Catalog()
    local byInventory,dungeonZones,dungeonFallbacks={},{},{}
    for zone,entrance in pairs(self.Entrances or {}) do
        if not raidZones[zone] then dungeonFallbacks["dungeon:"..zone]=entrance.label end
    end
    local now=time and time() or 0
    for id,item in pairs(catalog) do
        local inv=item.inv or 0
        byInventory[inv]=byInventory[inv] or {}
        byInventory[inv][item.id or id]=item
        for _,source in ipairs(item.sources or {}) do
            if source.kind=="dungeon" then
                local key=dungeonKey(source)
                if key and (not dungeonZones[key] or source.zone<dungeonZones[key]) then dungeonZones[key]=source.zone end
            end
        end
        local key=itemKey(item.id or id)
        if key and ((context.worn and context.worn[item.id]) or self.Client.Owned(item.id)) then
            if not state.obtained[key] then state.obtained[key]={itemID=item.id,observedAt=now} end
        end
    end
    for key,label in pairs(dungeonFallbacks) do dungeonZones[key]=dungeonZones[key] or label end
    for id,pin in pairs(self.db.pins or {}) do
        local key=pin.item and itemKey(pin.item.id or id)
        if key and (pin.acquired or self.Client.Owned(pin.item.id) or (context.worn and context.worn[pin.item.id])) then
            if not state.obtained[key] then state.obtained[key]={itemID=pin.item.id,observedAt=pin.acquiredAt or now} end
        end
    end
    local cache={active={},completed={},removed={},context=context,profile=profile,dungeonZones=dungeonZones}
    local future=copy(context); future.level=60; future.mainTwoHand=false
    for _,slot in ipairs(self.Slots) do
        -- Rules.Build performs full eligibility/scoring, but need not visit the
        -- entire catalog seventeen times just to reject the wrong slot.
        local slotCatalog={}
        for _,inv in ipairs(slot.inv) do
            for id,item in pairs(byInventory[inv] or {}) do slotCatalog[id]=item end
        end
        local lanes,baseline,baselineScore=self.Rules.Build(slotCatalog,context,self.db.options,slot,profile)
        for _,row in ipairs(lanes.longterm) do
            local key=itemKey(row.item.id)
            if key and not state.obtained[key] and not state.removed[key] then
                local entry=copy(row); entry.slot=slot
                entry.currentUsable=self.Rules.Usable(row.item,context,slot) and true or false
                cache.active[#cache.active+1]=entry
            end
        end
        -- History includes items which no longer beat the equipped item. Using
        -- level 60 here permits old observations to remain visible across armor
        -- training and two-hand/off-hand loadout changes; no upgrade is asserted.
        local history={}
        for key,record in pairs(state.obtained) do
            local pin=self.db.pins[key]
            local item=catalog[tonumber(key)] or (pin and pin.item)
            if item and self.Rules.Usable(item,future,slot) then
                history[key]={item=item,source=pin and pin.source or (item.sources or {})[1],
                    score=self.Rules.Score(item,profile.weights,slot.id,profile.weaponDpsSlots),
                    baseline=baselineScore,slot=slot,observedAt=type(record)=="table" and record.observedAt or nil}
            end
        end
        for key,row in pairs(history) do
            if not state.removed[key] then cache.completed[#cache.completed+1]=row end
        end
        for key,record in pairs(state.removed) do
            local pin=self.db.pins[key]
            local item=catalog[tonumber(key)] or (pin and pin.item) or (type(record)=="table" and record.item)
            if item and self.Rules.Usable(item,future,slot) then
                local source=(type(record)=="table" and record.source) or (pin and pin.source) or (item.sources or {})[1]
                cache.removed[#cache.removed+1]={item=item,source=source,
                    score=self.Rules.Score(item,profile.weights,slot.id,profile.weaponDpsSlots),
                    baseline=baselineScore,slot=slot,observedAt=history[key] and history[key].observedAt,
                    historicallyObtained=state.obtained[key]~=nil}
            end
        end
    end
    -- Slot order is deliberately preserved, with best-to-worst scores inside
    -- each equipment category. These remain weighted estimates, not a BiS claim.
    local order={}; for i,slot in ipairs(self.Slots) do order[slot.id]=i end
    local function sorted(a,b)
        if a.slot.id~=b.slot.id then return order[a.slot.id]<order[b.slot.id] end
        if (a.score or 0)~=(b.score or 0) then return (a.score or 0)>(b.score or 0) end
        if a.item.id~=b.item.id then return a.item.id<b.item.id end
        return (a.source and a.source.name or "")<(b.source and b.source.name or "")
    end
    for _,rows in pairs({cache.active,cache.completed,cache.removed}) do table.sort(rows,sorted) end
    self.journalCache=cache
    return cache
end

function XC:GetJournalEntries(state,query,slotID,laneFilter,filters)
    if not self.db then return {} end
    state=(state=="completed" or state=="removed") and state or "active"
    laneFilter=laneNames[laneFilter] and laneFilter or "all"
    local cache=self.journalCache or self:BuildJournalCache(); if not cache then return {} end
    local lookahead=filters and tonumber(filters.lookahead)
    local maxLevel=state=="active" and laneFilter=="longterm" and lookahead and lookahead>0 and (cache.context.level+lookahead) or nil
    local destination=filters and filters.destination
    query=tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local linkID=tonumber(query:match("|hitem:(%d+)") or query:match("^item:(%d+)$"))
    local queryID=tonumber(query:match("^%d+$"))
    query=query:match("^%[(.+)%]$") or query
    local out={}; local ranks={}
    for _,entry in ipairs(cache[state]) do
        if (not slotID or slotID==0 or entry.slot.id==tonumber(slotID))
            and (state~="active" or laneFilter=="longterm" or entry.currentUsable) then
            local key=itemKey(entry.item.id)
            local row=makeEntry(self,entry,entry.slot,laneFilter,state~="active",self.db.pins[key],state=="removed",cache.context,destination,maxLevel,cache.dungeonZones)
            if row then
                local matches=query=="" or row.item.id==(linkID or queryID)
                if not matches and not linkID then
                    local haystack=(row.item.name or "").." "..row.slotLabel
                    for _,source in ipairs(row.sources) do haystack=haystack.." "..self:SourceText(source) end
                    matches=haystack:lower():find(query,1,true)~=nil
                end
                if matches then
                    row.state=state
                    row.obtained=state=="completed" or (state=="removed" and entry.historicallyObtained) or false
                    ranks[row.slotID]=(ranks[row.slotID] or 0)+1
                    row.rank=ranks[row.slotID]
                    out[#out+1]=row
                end
            end
        end
    end
    return out
end

function XC:GetJournalDestinations(entries)
    local cache=self.journalCache
    if not cache then return {} end
    local groups={}
    for _,row in ipairs(entries) do
        for _,source in ipairs(row.sources) do
            eachDestination(source,cache.dungeonZones,function(key,label,kind)
                local group=groups[key]
                if not group then
                    group={key=key,label=label,kind=kind,levels={}}
                    groups[key]=group
                end
                local id=row.item.id
                local level=math.max(1,minimumLevel(row.item,source,cache.context,self:GetSlot(row.slotID)))
                group.levels[id]=math.min(group.levels[id] or level,level)
            end)
        end
    end
    local list={}
    for _,group in pairs(groups) do
        group.count,group.now,group.later=0,0,0
        group.minLevel,group.maxLevel=math.huge,0
        for _,level in pairs(group.levels) do
            group.count=group.count+1
            if level<=cache.context.level then group.now=group.now+1 else group.later=group.later+1 end
            group.minLevel=math.min(group.minLevel,level)
            group.maxLevel=math.max(group.maxLevel,level)
        end
        group.levels=nil
        list[#list+1]=group
    end
    table.sort(list,function(a,b)
        if a.kind~=b.kind then return a.kind<b.kind end
        if a.minLevel~=b.minLevel then return a.minLevel<b.minLevel end
        if a.label~=b.label then return a.label<b.label end
        return a.key<b.key
    end)
    return list
end

function XC:SetJournalSource(row,index)
    if not row or not row.key or type(row.sources)~="table" or #row.sources==0 then return false end
    index=tonumber(index)
    if not index or index~=math.floor(index) or index<1 or index>#row.sources then return false end
    self.journalSourceSelection=self.journalSourceSelection or {}
    self.journalSourceSelection[row.sourceSelectionKey or row.key]=index
    return true
end
function XC:RemoveJournalEntry(row)
    local key=row and row.item and itemKey(row.item.id)
    local state=self:JournalState()
    if not key or not state then return false end
    state.removed[key]={itemID=row.item.id,item=row.item,source=row.source,slotID=row.slotID,lane=row.lane,removedAt=time and time() or 0}
    if self.db.activeHunt==key then self:StopHunt() end
    self:InvalidateJournal()
    return true
end
function XC:RestoreJournalEntry(row)
    local key=row and row.item and itemKey(row.item.id)
    local state=self:JournalState()
    if not key or not state then return false end
    state.removed[key]=nil
    self:InvalidateJournal()
    return true
end
