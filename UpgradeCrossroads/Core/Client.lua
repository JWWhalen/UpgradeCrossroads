local _, XC = ...
local C = {}
XC.Client=C
local statMap={ITEM_MOD_STRENGTH_SHORT="str",ITEM_MOD_AGILITY_SHORT="agi",ITEM_MOD_STAMINA_SHORT="sta",ITEM_MOD_INTELLECT_SHORT="int",ITEM_MOD_SPIRIT_SHORT="spi",ITEM_MOD_SPELL_POWER_SHORT="sp",ITEM_MOD_SPELL_DAMAGE_DONE_SHORT="sp",ITEM_MOD_SPELL_HEALING_DONE_SHORT="heal",ITEM_MOD_ATTACK_POWER_SHORT="ap",ITEM_MOD_RANGED_ATTACK_POWER_SHORT="rap",RESISTANCE0_NAME="armor",ITEM_MOD_DEFENSE_SKILL_RATING_SHORT="def",ITEM_MOD_DAMAGE_PER_SECOND_SHORT="dps",ITEM_MOD_MANA_REGENERATION_SHORT="mpr"}
local ratingKeys={ITEM_MOD_CRIT_RATING_SHORT=true,ITEM_MOD_HIT_RATING_SHORT=true,ITEM_MOD_HASTE_RATING_SHORT=true,ITEM_MOD_DODGE_RATING_SHORT=true,ITEM_MOD_PARRY_RATING_SHORT=true}
local invMap={INVTYPE_HEAD=1,INVTYPE_NECK=2,INVTYPE_SHOULDER=3,INVTYPE_BODY=4,INVTYPE_CHEST=5,INVTYPE_WAIST=6,INVTYPE_LEGS=7,INVTYPE_FEET=8,INVTYPE_WRIST=9,INVTYPE_HAND=10,INVTYPE_FINGER=11,INVTYPE_TRINKET=12,INVTYPE_WEAPON=13,INVTYPE_SHIELD=14,INVTYPE_RANGED=15,INVTYPE_CLOAK=16,INVTYPE_2HWEAPON=17,INVTYPE_ROBE=20,INVTYPE_WEAPONMAINHAND=21,INVTYPE_WEAPONOFFHAND=22,INVTYPE_HOLDABLE=23,INVTYPE_THROWN=25,INVTYPE_RANGEDRIGHT=26,INVTYPE_RELIC=28}
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local values={pcall(fn,...)}
    if not values[1] then return nil end
    return unpack(values,2)
end
C.Safe=safe
function C.ItemInfo(link)
    return safe(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
end
function C.ItemStats(link)
    local raw=safe(C_Item and C_Item.GetItemStats or GetItemStats,link)
    if type(raw)~="table" then return nil end
    local stats={}
    local unsupported=false
    for key,value in pairs(raw) do
        if statMap[key] and type(value)=="number" then stats[statMap[key]]=value end
        if ratingKeys[key] and type(value)=="number" and value~=0 then unsupported=true end
    end
    -- Ratings and procs are deliberately not converted to percent or guessed.
    return stats,unsupported
end
function C.ResolveItem(id)
    local name,link,quality,ilvl,req,_,_,_,equip,icon,_,classID,subclassID=C.ItemInfo(id)
    if not name then return nil end
    local stats,unsupported=C.ItemStats(link or id)
    local entry={id=id,name=name,link=link,quality=quality or 1,ilvl=ilvl or 0,req=req or 0,inv=invMap[equip] or 0,icon=icon,classID=classID,subclassID=subclassID,stats=stats,basis="live",sources={}}
    if classID==2 and (not stats or not stats.dps) then entry.incomplete=true end
    if not stats then entry.incomplete=true end
    if unsupported then entry.incomplete=true end
    return entry
end
function C.RequestItem(id)
    XC.requested=XC.requested or {}
    if XC.requested[id] then return end
    XC.requested[id]=true
    safe(C_Item and C_Item.RequestLoadItemDataByID,id)
end
function C.Context()
    local _,class,classID=UnitClass("player")
    local _,_,raceID=UnitRace("player")
    local faction=UnitFactionGroup("player")
    local side=faction=="Alliance" and 1 or (faction=="Horde" and 2 or 0)
    local ctx={class=class,classID=classID,raceID=raceID,side=side,level=UnitLevel("player"),equipped={},occupied={},worn={},completed={}}
    for _,slot in ipairs(XC.Slots) do
        local link=GetInventoryItemLink("player",slot.id)
        local id=safe(GetInventoryItemID,"player",slot.id)
        if link then id=id or tonumber(link:match("item:(%d+)")) end
        if id then
            ctx.worn[id]=true; ctx.occupied[slot.id]=true
            local entry=C.ResolveItem(id)
            local snap=XC.Catalog[id]
            if entry and entry.stats then
                -- Use the same dated model on both sides when the catalog knows
                -- the equipped item; mixing live rating units with old percent
                -- weights would create false upgrade deltas.
                if snap then entry.stats=snap.stats; entry.basis=snap.basis; entry.incomplete=nil end
                ctx.equipped[slot.id]=entry
            elseif snap then ctx.equipped[slot.id]=snap else C.RequestItem(id) end
        end
    end
    local main=ctx.equipped[16]; ctx.mainTwoHand=main and main.inv==17
    local completed=safe(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    if type(completed)=="table" then for _,id in ipairs(completed) do ctx.completed[id]=true end end
    return ctx
end
function C.Catalog()
    local catalog={}
    for id,item in pairs(XC.Catalog) do catalog[id]=item end
    -- Custom entries supplement or explicitly replace a catalog source for this character.
    for id,item in pairs(XC.db.custom) do catalog[id]=item end
    return catalog
end
function C.Presentation(item)
    local name,link,quality,_,_,_,_,_,_,icon=C.ItemInfo(item.id)
    if not name then C.RequestItem(item.id) end
    return name or item.name or ("Item #"..item.id),icon or item.icon or "Interface\\Icons\\INV_Misc_QuestionMark",link or item.link,quality or item.quality or 1
end
function XC:LinkItem(item)
    if not item then return false end
    local _,_,link=C.Presentation(item)
    if not link then self:Print("Loading this item. Click Chat again in a moment."); return false end
    local api=ChatFrameUtil or {}
    local active=(ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) or (api.GetActiveWindow and api.GetActiveWindow())
    local insert=ChatEdit_InsertLink or api.InsertLink
    local open=ChatFrame_OpenChat or api.OpenChat
    if active and insert then
        local ok,inserted=pcall(insert,link)
        if ok and inserted~=false then return true end
    end
    if open then
        local ok=pcall(open,link,DEFAULT_CHAT_FRAME)
        if ok then return true end
    end
    self:Print("Open a chat box first, then Shift-click the item.")
    return false
end
function C.Owned(id)
    local count=safe(C_Item and C_Item.GetItemCount or GetItemCount,id,false)
    return type(count)=="number" and count>0
end
function C.UpdatePins()
    for _,pin in pairs(XC.db.pins) do
        if C.Owned(pin.item.id) and not pin.acquired then pin.acquired=true; pin.acquiredAt=time(); XC:Print("Target obtained: "..pin.item.name) end
    end
end
function XC:SourceText(source)
    local text
    if source.personal then text="Personal "..(self.KindLabels[source.kind] or "target")..": "..source.name.."\n"..(source.zone or "")
    elseif source.kind=="quest" then text="Quest: "..source.name.."\n"..(source.zone or "").."  /  #"..tostring(source.questID)
    elseif source.kind=="craft" then text=source.name.."  /  Skill "..(source.skill or "?").."\nRecipe #"..(source.spellID or "?")
    else text=(source.name or self.KindLabels[source.kind] or "Target").."\n"..(source.zone or source.details or "Source details not supplied") end
    if source.side==1 then text=text.."\nAlliance only" elseif source.side==2 then text=text.."\nHorde only" end
    return text
end
function XC:Availability(row)
    if self.Rules.OtherFaction(row.source,self.context or C.Context()) then
        return (row.source.side==1 and "Alliance" or "Horde").." source / not available to this character"
    end
    if row.locked then return "Requires level "..row.minLevel end
    if row.source.kind=="quest" then
        if row.source.questID and safe(C_QuestLog and C_QuestLog.IsOnQuest,row.source.questID) then return "In your quest log" end
        return "Check quest chain and availability"
    end
    if row.source.kind=="craft" then return "Check recipe access and materials" end
    if row.source.kind=="dungeon" or row.source.kind=="raid" then return "Check access, group and loot availability" end
    return "Confirm source requirements"
end
function XC:Pin(row,lane)
    local key=tostring(row.item.id)
    if not self.db.pins[key] then
        self.db.pinOrder=self.db.pinOrder+1
        self.db.pins[key]={item=row.item,source=row.source,lane=lane,addedAt=time(),order=self.db.pinOrder,checks={},notes=""}
        self:Print("Pinned "..row.item.name..". Open My hunts for your checklist.")
    else self:Print("That target is already in My hunts.") end
    C.UpdatePins()
    self:Refresh()
end
function XC:SetProfile(id)
    local profile=self:GetProfile(id)
    if profile.id~=id then return false end
    self.db.profile=id
    self.selection={}; self.sourceSelection={}
    self:Refresh()
    return true
end
function XC:CycleProfile()
    local profiles=self:GetProfiles(); if #profiles==0 then return end
    local current=self:GetProfile(self.db.profile).id; local index=1
    for i,profile in ipairs(profiles) do if profile.id==current then index=i; break end end
    self:SetProfile(profiles[index%#profiles+1].id)
end
function XC:Refresh()
    if not self.db then return end
    self.context=C.Context()
    if self.InvalidateJournal then self:InvalidateJournal() end
    self:MigrateProfiles(self.context.class)
    if not self.Rules.FactionLabels[self.db.options.faction] and self.context.side~=0 then
        self.db.options.faction=self.Rules.FactionMode(self.db.options,self.context)
    end
    self.lanes,self.baseline,self.baselineScore=self.Rules.Build(C.Catalog(),self.context,self.db.options,self:GetSlot(self.db.slot),self:GetProfile(self.db.profile))
    local query=(self.search or ""):lower():match("^%s*(.-)%s*$")
    if query~="" then
        for key,rows in pairs(self.lanes) do
            local matches={}
            for _,row in ipairs(rows) do
                local text=(row.item.name or "").." "..self:SourceText(row.source)
                if text:lower():find(query,1,true) then matches[#matches+1]=row end
            end
            self.lanes[key]=matches
        end
    end
    if self.Render then self:Render() end
end
function XC:QueueRefresh()
    if self.queued then return end
    self.queued=true
    C_Timer.After(.2,function()
        XC.queued=nil
        if XC.db then
            C.UpdatePins()
            if XC.window and XC.window:IsShown() then XC:Refresh() end
            if XC.RenderGuide then XC:RenderGuide() end
        end
    end)
end
