-- Pure recommendation rules. No client APIs are called in this module.
local _, XC = ...
local Rules = {}
XC.Rules = Rules
local weaponSkills = {
    WARRIOR={0,1,2,3,4,5,6,7,8,10,13,15,16,18},
    PALADIN={0,1,4,5,6,7,8}, HUNTER={0,1,2,3,6,7,8,10,13,15,16,18},
    ROGUE={0,2,3,4,7,13,15,16,18}, PRIEST={4,10,15,19},
    SHAMAN={0,1,4,5,10,13,15}, MAGE={7,10,15,19},
    WARLOCK={7,10,15,19}, DRUID={4,5,6,10,13,15},
}
local armorLimit={WARRIOR=4,PALADIN=4,HUNTER=3,ROGUE=2,PRIEST=1,SHAMAN=3,MAGE=1,WARLOCK=1,DRUID=2}
local dual={WARRIOR=20,ROGUE=10,HUNTER=20}
local shield={WARRIOR=true,PALADIN=true,SHAMAN=true}
local function contains(t,v) for _,x in ipairs(t or {}) do if x==v then return true end end return false end
local function maskAllows(mask, index)
    if not mask or mask==0 then return true end
    if not index or index<1 then return false end
    return math.floor(mask / 2^(index-1)) % 2 == 1
end
Rules.MaskAllows=maskAllows
Rules.FactionOrder={"alliance","horde","both"}
Rules.FactionLabels={alliance="Alliance",horde="Horde",both="Both"}
function Rules.WeaponLevel(item,context,slot)
    if item.classID~=2 then return 0 end
    return math.max(item.subclassID==6 and 20 or 0,slot.id==17 and (dual[context.class] or 0) or 0)
end
local function advancedArmorLevel(item,context)
    local armor=armorLimit[context.class]
    if item.classID==4 and (armor==3 or armor==4) and item.subclassID==armor then return 40 end
    return 0
end
function Rules.MinimumLevel(item,context,slot)
    return math.max(item.req or 0,Rules.WeaponLevel(item,context,slot),advancedArmorLevel(item,context))
end
function Rules.FactionMode(options,context)
    local mode=options and options.faction
    if Rules.FactionLabels[mode] then return mode end
    return context and context.side==1 and "alliance" or (context and context.side==2 and "horde" or "both")
end
function Rules.OtherFaction(source,context)
    return (source.side==1 or source.side==2) and context and context.side and context.side~=0 and source.side~=context.side
end
function Rules.Usable(item, context, slot)
    if not contains(slot.inv,item.inv) then return false,"Wrong slot" end
    if not maskAllows(item.classMask,context.classID) then return false,"Class restriction" end
    if item.classID==2 and not contains(weaponSkills[context.class],item.subclassID) then return false,"Weapon type" end
    -- Recommendation eligibility is stricter than merely being able to equip
    -- an item: thrown weapons do not replace a Hunter's shot weapon.
    if slot.id==18 and context.class=="HUNTER" and item.classID==2
        and item.subclassID~=2 and item.subclassID~=3 and item.subclassID~=18 then
        return false,"Hunter shot weapon"
    end
    if slot.id==17 and item.classID==2 and not dual[context.class] then return false,"No dual wield" end
    if (context.level or 1)<Rules.WeaponLevel(item,context,slot) then return false,"Weapon training" end
    if item.inv==14 and not shield[context.class] then return false,"Shield restriction" end
    if item.classID==4 then
        local maxArmor=armorLimit[context.class] or 1
        -- A future armor tier may be planned, but never counted as wearable now.
        if item.subclassID>=1 and item.subclassID<=4
            and (item.subclassID>maxArmor or (context.level or 1)<advancedArmorLevel(item,context)) then
            return false,"Armor training"
        end
        if item.subclassID==7 and context.class~="PALADIN" then return false,"Libram" end
        if item.subclassID==8 and context.class~="DRUID" then return false,"Idol" end
        if item.subclassID==9 and context.class~="SHAMAN" then return false,"Totem" end
    end
    if slot.id==17 and context.mainTwoHand then return false,"Two-handed weapon equipped" end
    return true
end
function Rules.Score(item,weights,slotID,weaponDpsSlots)
    if not item or not item.stats then return nil end
    local total=0
    for key,weight in pairs(weights) do
        local use=true
        if key=="dps" then
            use=item.classID==2
            if weaponDpsSlots then
                use=use and weaponDpsSlots[slotID]==true
            else
                -- Legacy/custom callers retain their historical slot behavior.
                if slotID==18 and weights.rap==nil then use=false end
                if slotID~=18 and weights.rap then use=false end
            end
        end
        if use then total=total+(item.stats[key] or 0)*weight end
    end
    return total
end
function Rules.SourceAllowed(source,context,options)
    local mode=Rules.FactionMode(options,context)
    local selected=mode=="alliance" and 1 or (mode=="horde" and 2 or nil)
    if selected and (source.side==1 or source.side==2) and source.side~=selected then return false end
    if source.kind=="quest" then
        if not maskAllows(source.classMask,context.classID) then return false end
        -- Opposite-faction browsing must not test that faction's racial quests
        -- or history against the logged-in character. Class/gear rules remain.
        if not Rules.OtherFaction(source,context) then
            if not maskAllows(source.raceMask,context.raceID) then return false end
            if context.completed and context.completed[source.questID] then return false end
        end
    end
    if options.solo and (source.kind=="dungeon" or source.kind=="raid" or source.group) then return false end
    if not options.crafted and source.kind=="craft" then return false end
    if not options.auction and source.kind=="auction" then return false end
    return true
end
function Rules.Build(catalog,context,options,slot,profile)
    local lanes={reliable={},dungeon={},longterm={}}
    local futureContext={}
    for k,v in pairs(context) do futureContext[k]=v end
    futureContext.level=60
    local baseline=context.equipped and context.equipped[slot.id]
    local baselineScore=Rules.Score(baseline,profile.weights,slot.id,profile.weaponDpsSlots)
    if not baseline and not (context.occupied and context.occupied[slot.id]) then baselineScore=0 end
    local function insert(lane,item,source,score,minLevel,delta)
        lanes[lane][#lanes[lane]+1]={item=item,source=source,score=score,delta=delta,baseline=baselineScore,minLevel=minLevel,locked=minLevel>context.level}
    end
    for _,item in pairs(catalog) do
        if not (context.worn and context.worn[item.id]) and Rules.Usable(item,futureContext,slot) then
            local score=Rules.Score(item,profile.weights,slot.id,profile.weaponDpsSlots)
            local comparable=baselineScore~=nil
            if slot.id==16 and baseline and ((baseline.inv==17)~=(item.inv==17)) then comparable=false end
            if baseline and baseline.incomplete then comparable=false end
            if item.incomplete then comparable=false end
            local delta=comparable and score and score-baselineScore or nil
            if score and score>0 and (not comparable or delta>0.01) then
                local level=Rules.MinimumLevel(item,context,slot)
                for _,source in ipairs(item.sources or {}) do
                    if Rules.SourceAllowed(source,context,options) then
                        local minLevel=math.max(level,source.minLevel or 0)
                        insert("longterm",item,source,score,minLevel,delta)
                        if minLevel<=context.level then
                            if source.kind=="dungeon" or source.kind=="raid" or source.group then insert("dungeon",item,source,score,minLevel,delta)
                            elseif source.kind~="world" then insert("reliable",item,source,score,minLevel,delta) end
                        end
                    end
                end
            end
        end
    end
    for _,rows in pairs(lanes) do
        table.sort(rows,function(a,b)
            if a.score~=b.score then return a.score>b.score end
            if a.minLevel~=b.minLevel then return a.minLevel<b.minLevel end
            if a.item.id~=b.item.id then return a.item.id<b.item.id end
            return (a.source.name or "")<(b.source.name or "")
        end)
        local seen={}
        local unique={}
        for _,row in ipairs(rows) do if not seen[row.item.id] then seen[row.item.id]=true; unique[#unique+1]=row end end
        for i=#rows,1,-1 do rows[i]=nil end
        for i,row in ipairs(unique) do rows[i]=row end
    end
    return lanes,baseline,baselineScore
end
