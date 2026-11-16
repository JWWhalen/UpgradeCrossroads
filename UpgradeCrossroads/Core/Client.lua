local _, XC = ...
local C = {}
XC.Client=C
local statMap={ITEM_MOD_STRENGTH_SHORT="str",ITEM_MOD_AGILITY_SHORT="agi",ITEM_MOD_STAMINA_SHORT="sta",ITEM_MOD_INTELLECT_SHORT="int",ITEM_MOD_SPIRIT_SHORT="spi",ITEM_MOD_SPELL_POWER_SHORT="sp",ITEM_MOD_SPELL_DAMAGE_DONE_SHORT="sp",ITEM_MOD_SPELL_HEALING_DONE_SHORT="heal",ITEM_MOD_ATTACK_POWER_SHORT="ap",ITEM_MOD_RANGED_ATTACK_POWER_SHORT="rap",RESISTANCE0_NAME="armor",ITEM_MOD_DEFENSE_SKILL_RATING_SHORT="def",ITEM_MOD_DAMAGE_PER_SECOND_SHORT="dps",ITEM_MOD_MANA_REGENERATION_SHORT="mpr"}
local ratingKeys={ITEM_MOD_CRIT_RATING_SHORT=true,ITEM_MOD_HIT_RATING_SHORT=true,ITEM_MOD_HASTE_RATING_SHORT=true,ITEM_MOD_DODGE_RATING_SHORT=true,ITEM_MOD_PARRY_RATING_SHORT=true}
local invMap={INVTYPE_HEAD=1,INVTYPE_NECK=2,INVTYPE_SHOULDER=3,INVTYPE_BODY=4,INVTYPE_CHEST=5,INVTYPE_WAIST=6,INVTYPE_LEGS=7,INVTYPE_FEET=8,INVTYPE_WRIST=9,INVTYPE_HAND=10,INVTYPE_FINGER=11,INVTYPE_TRINKET=12,INVTYPE_WEAPON=13,INVTYPE_SHIELD=14,INVTYPE_RANGED=15,INVTYPE_CLOAK=16,INVTYPE_2HWEAPON=17,INVTYPE_ROBE=20,INVTYPE_WEAPONMAINHAND=21,INVTYPE_WEAPONOFFHAND=22,INVTYPE_HOLDABLE=23,INVTYPE_THROWN=25,INVTYPE_RANGEDRIGHT=26,INVTYPE_RELIC=28}
local function successful(ok,...)
    if ok then return ... end
end
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    return successful(pcall(fn,...))
end
C.Safe=safe
function C.ItemInfo(link)
    return safe(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
end
local function matchesSuffix(item,link)
    if type(link)~="string" or (issecretvalue and issecretvalue(link)) then return false end
    if tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))~=item.id then return false end
    local name=link:match("|h%[(.-)%]|h") or C.ItemInfo(link)
    local suffix=" "..item.suggestedSuffix
    return type(name)=="string" and name:sub(-#suffix)==suffix
end
function C.ItemStats(link,exact)
    local raw=safe(C_Item and C_Item.GetItemStats or GetItemStats,link)
    if type(raw)~="table" then return nil end
    local stats={}
    local unsupported=false
    for key,value in pairs(raw) do
        local defenseRating=exact and key=="ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"
        if statMap[key] and not defenseRating and type(value)=="number" then stats[statMap[key]]=value end
        if (ratingKeys[key] or defenseRating) and type(value)=="number" and value~=0 then unsupported=true end
    end
    -- Ratings and procs are deliberately not converted to percent or guessed.
    return stats,unsupported
end
function C.ResolveItem(id,exactLink)
    local name,link,quality,ilvl,req,_,_,_,equip,icon,_,classID,subclassID=C.ItemInfo(exactLink or id)
    if not name then return nil end
    link=exactLink or link
    local stats,unsupported=C.ItemStats(link or id,exactLink~=nil)
    local entry={id=id,name=name,link=link,quality=quality or 1,ilvl=ilvl or 0,req=req or 0,inv=invMap[equip] or 0,icon=icon,classID=classID,subclassID=subclassID,stats=stats,basis="live",sources={}}
    if classID==2 and (not stats or not stats.dps) then
        entry.incomplete=true
        entry.missingDps=true
    end
    if not stats then entry.incomplete=true end
    if unsupported then
        entry.incomplete=true
        entry.unsupportedRatings=true
    end
    return entry
end
function C.RequestItem(id)
    XC.requested=XC.requested or {}
    if XC.requested[id] then return end
    XC.requested[id]=true
    safe(C_Item and C_Item.RequestLoadItemDataByID,id)
end
function C.Context(exactInventory)
    local _,class,classID=UnitClass("player")
    local _,_,raceID=UnitRace("player")
    local faction=UnitFactionGroup("player")
    local side=faction=="Alliance" and 1 or (faction=="Horde" and 2 or 0)
    local ctx={class=class,classID=classID,raceID=raceID,side=side,level=UnitLevel("player"),equipped={},occupied={},worn={},completed={}}
    if exactInventory then ctx.equippedIDs={} end
    for _,slot in ipairs(XC.Slots) do
        local link=GetInventoryItemLink("player",slot.id)
        local id=safe(GetInventoryItemID,"player",slot.id)
        if link then id=id or tonumber(link:match("item:(%d+)")) end
        if id then
            local snap=XC.Catalog[id]
            local representative=snap and snap.suggestedSuffix
            if not representative or matchesSuffix(snap,link) then ctx.worn[id]=true end
            ctx.occupied[slot.id]=true
            local entry
            if exactInventory or representative then
                if link then entry=C.ResolveItem(id,link) end
            else entry=C.ResolveItem(id) end
            if exactInventory then
                ctx.equippedIDs[slot.id]=id
                if entry and (entry.inv==0 or not entry.classID or not entry.subclassID) then entry=nil end
                ctx.equipped[slot.id]=entry
                if not entry or not entry.stats then C.RequestItem(id) end
            elseif representative then
                -- A catalog roll describes one possible suffix. Equipment
                -- comparison must use the wearer's actual link and stats.
                if entry and entry.stats then
                    if not next(entry.stats) then entry.incomplete=true end
                    ctx.equipped[slot.id]=entry
                else C.RequestItem(id) end
            elseif entry and entry.stats then
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
    local name,link,quality,_,_,_,_,_,_,icon=C.ItemInfo(item.link or item.id)
    if not name then C.RequestItem(item.id) end
    name=name or item.name or ("Item #"..item.id)
    if item.suggestedSuffix then name=name.." "..item.suggestedSuffix end
    return name,icon or item.icon or "Interface\\Icons\\INV_Misc_QuestionMark",item.link or link,quality or item.quality or 1
end
function XC:LinkItem(item)
    if not item then return false end
    local _,_,link=C.Presentation(item)
    if not link then self:Print("Loading this item. Click Chat again in a moment."); return false end
    if item.suggestedSuffix then link=link.." ("..item.suggestedSuffix..")" end
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
function C.Owned(item)
    local id=type(item)=="table" and item.id or item
    local count=safe(C_Item and C_Item.GetItemCount or GetItemCount,id,false)
    if type(count)~="number" or count<=0 then return false end
    if type(item)~="table" or not item.suggestedSuffix then return true end
    for _,slot in ipairs(XC.Slots) do
        if matchesSuffix(item,safe(GetInventoryItemLink,"player",slot.id)) then return true end
    end
    local bags=C_Container
    if not bags then return false end
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot=1,(safe(bags.GetContainerNumSlots,bag) or 0) do
            if matchesSuffix(item,safe(bags.GetContainerItemLink,bag,slot)) then return true end
        end
    end
    return false
end
function C.UpdatePins()
    for _,pin in pairs(XC.db.pins) do
        if not pin.acquired and C.Owned(pin.item) then
            pin.acquired=true; pin.acquiredAt=time(); XC:Print("Target obtained: "..C.Presentation(pin.item))
        end
    end
end
function XC:GetRecipeSource(source)
    if source.kind=="craft" then return self.RecipeSources and self.RecipeSources[source.spellID] end
end
function XC:SourceText(source)
    local text
    if source.personal then text="Personal "..(self.KindLabels[source.kind] or "target")..": "..source.name.."\n"..(source.zone or "")
    elseif source.kind=="quest" then
        text="Quest: "..source.name.."\n"..(source.zone or "").."  /  #"..tostring(source.questID)
        if source.details then text=text.."\n"..source.details end
    elseif source.kind=="craft" then
        local recipe=self:GetRecipeSource(source)
        text=source.name or "Crafting"
        if recipe and recipe.skill then text=text.."  /  Skill "..recipe.skill end
        if recipe then
            text=text.."\n"..recipe.text
            if recipe.basis=="Classic baseline" then text=text.."\nClassic recipe source. Verify in Forever." end
        else
            text=text.."\nRecipe source unverified."
            if source.spellID then text=text.." Crafting spell #"..source.spellID.."." end
        end
    else
        text=(source.name or self.KindLabels[source.kind] or "Target").."\n"..(source.zone or source.details or "Source details not supplied")
        if source.zone and source.details then text=text.."\n"..source.details end
    end
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
    if row.source.kind=="craft" then return "Crafted gear" end
    if row.source.bindOnEquip then return "Bind on Equip / can be traded" end
    if row.source.kind=="dungeon" or row.source.kind=="raid" then return "Check access, group and loot availability" end
    return "Confirm source requirements"
end
function XC:Pin(row,lane)
    local key=tostring(row.item.id)
    if not self.db.pins[key] then
        self:EnsureHunt(row,lane)
        self:Print("Saved "..row.item.name.." to Hunts.")
    else self:Print("That target is already in Hunts.") end
    C.UpdatePins()
    self:Refresh()
end
function XC:SetProfile(id)
    local profile=self:GetProfile(id)
    if profile.id~=id then return false end
    self.db.profile=id
    self.journalSourceSelection=nil
    self:Refresh()
    self:RefreshUpgradeHints()
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
    self:Render()
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
            XC:RefreshUpgradeHints()
        end
    end)
end
