local _, XC = ...
local C, R = XC.Client, XC.Rules
local U = {}
XC.UpgradeComparison = U

function U.Context()
    return C.Context(true)
end

function U.ItemID(link)
    if type(link)~="string" then return nil end
    local id=tonumber(link:match("^item:(%d+)") or link:match("|Hitem:(%d+)"))
    if id and id>0 then return id end
end

function U.HasSuffix(link)
    local fields=type(link)=="string" and link:match("item:([%d:%-]+)")
    if not fields then return false end
    local suffix=fields:match("^%d+:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]*)")
    return suffix and suffix~="" and suffix~="0"
end

local function snapshot(item)
    if not item or U.HasSuffix(item.link) then return nil end
    local entry=XC.Catalog[item.id]
    if entry and entry.inv==item.inv and entry.classID==item.classID and entry.subclassID==item.subclassID
        and not ((entry.ilvl or 0)>0 and (item.ilvl or 0)>0 and entry.ilvl~=item.ilvl) then
        return entry
    end
end

local function score(item,profile,slot)
    if not item or not item.stats then return nil end
    if item.inv==12 and not next(item.stats) then return nil end
    if item.incomplete and (not item.missingDps or item.unsupportedRatings
        or (profile.weaponDpsSlots[slot] and (profile.weights.dps or 0)>0)) then return nil end
    return R.Score(item,profile.weights,slot,profile.weaponDpsSlots)
end

local function withSnapshotDps(item,entry,profile,slot)
    if not item.missingDps then return score(item,profile,slot) end
    if not entry.stats.dps then return nil end
    local stats={dps=entry.stats.dps}
    for key,value in pairs(item.stats) do stats[key]=value end
    return score({classID=item.classID,inv=item.inv,stats=stats},profile,slot)
end

local function itemLimits(id)
    local api=C_Item or {}
    local unique,_,limit,category=C.Safe(api.GetItemUniquenessByID,id)
    if type(category)~="number" or category<=0 or type(limit)~="number" or limit<=0 then
        category,limit=C.Safe(api.GetItemUniqueness,id)
    end
    if type(category)~="number" or category<=0 or type(limit)~="number" or limit<=0 then category,limit=nil,nil end
    return unique==true,category,limit
end

local function canReplace(item,slotID,context,unique,category,limit,categories)
    if not unique and not category then return true end
    local matches=0
    for _,slot in ipairs(XC.Slots) do
        local replaced=slot.id==slotID or (slotID==16 and item.inv==17 and slot.id==17)
        if not replaced and context.occupied[slot.id] then
            local other=context.equipped[slot.id]
            local otherID=other and other.id or context.equippedIDs and context.equippedIDs[slot.id]
            if not otherID then return nil end
            if unique and otherID==item.id then return false end
            if category and categories[otherID]==nil then
                local _,otherCategory=itemLimits(otherID)
                categories[otherID]=otherCategory or false
            end
            if category and categories[otherID]==category then
                matches=matches+1
                if matches>=limit then return false end
            end
        end
    end
    return true
end

local function compareSlot(item,context,profile,slot)
    local slotID=slot.id
    local equipped=context.equipped[slotID]
    local result={status="incomplete",item=item,slotID=slotID,baselineItem=equipped,basis="live"}
    if context.occupied[slotID] and not equipped then
        result.reason="Equipped item data is loading."
        return result
    end
    if (slotID==16 and ((equipped and (item.inv==17)~=(equipped.inv==17))
        or (item.inv==17 and context.occupied[17])))
        or (slotID==17 and (not context.occupied[16] or not context.equipped[16])) then
        result.reason="Compare the full weapon setup."
        return result
    end

    local value=score(item,profile,slotID)
    local baseline=0
    if equipped then baseline=score(equipped,profile,slotID) end
    if item.stats and not item.unsupportedRatings
        and (not equipped or (equipped.stats and not equipped.unsupportedRatings))
        and ((value==nil and item.missingDps) or (baseline==nil and equipped and equipped.missingDps)) then
        -- Borrow only missing DPS from one consistent snapshot. Live base
        -- stats stay intact, and random rolls cannot use the fallback.
        local candidate,old=snapshot(item),snapshot(equipped)
        if candidate and (not equipped or (old and candidate.basis==old.basis)) then
            value=withSnapshotDps(item,candidate,profile,slotID)
            if old then baseline=withSnapshotDps(equipped,old,profile,slotID) end
            if value and baseline then result.basis=candidate.basis end
        end
    end
    result.score=value
    if value==nil or baseline==nil then
        result.reason="Comparable stats are unavailable."
        return result
    end
    result.baseline=baseline
    result.delta=value-baseline
    if baseline>0 then result.percent=100*result.delta/baseline end
    result.status=result.delta>.01 and "upgrade" or result.delta<-.01 and "downgrade" or "sidegrade"
    return result
end

function U.Evaluate(link,context,profile,equippedSlot)
    local id=U.ItemID(link)
    if not id then return nil end
    local item=C.ResolveItem(id,link)
    if not item then C.RequestItem(id); return nil end
    if not item.inv or item.inv==0 or not item.classID or not item.subclassID then return nil end
    if not item.stats then C.RequestItem(id) end
    item.randomSuffix=U.HasSuffix(link)
    context=context or U.Context()
    profile=profile or XC:GetProfile(XC.db and XC.db.profile)
    if not profile then return nil end
    local catalogItem=XC.Catalog[id]
    if catalogItem then item.classMask=catalogItem.classMask end

    local worn=equippedSlot and context.equipped[equippedSlot]
    if worn and worn.id==id then
        return {status="equipped",item=item,slotID=equippedSlot,score=score(item,profile,equippedSlot),basis="live"}
    end

    local api=C_Item or {}
    local equippable=C.Safe(api.IsEquippableItem or IsEquippableItem,link)
    local unique,category,limit=itemLimits(id)
    unique=unique or (catalogItem and catalogItem.unique)
    local categories={}
    local best,uncertain,restricted,future
    for _,slot in ipairs(XC.Slots) do
        local usable,reason=R.Usable(item,context,slot)
        if reason~="Wrong slot" then
            local required=R.MinimumLevel(item,context,slot)
            if required>context.level then
                local later={class=context.class,classID=context.classID,level=required,mainTwoHand=context.mainTwoHand}
                if R.Usable(item,later,slot) and (not future or required<future.minimumLevel) then
                    future={status="future",item=item,slotID=slot.id,minimumLevel=required}
                end
            elseif usable and equippable~=false then
                local replace=canReplace(item,slot.id,context,unique,category,limit,categories)
                if replace then
                    local result=compareSlot(item,context,profile,slot)
                    if result.delta==nil then uncertain=uncertain or result
                    elseif not best or result.delta>best.delta then best=result end
                elseif replace==nil then
                    uncertain=uncertain or {status="incomplete",item=item,slotID=slot.id,reason="Equipped item data is loading."}
                else
                    restricted=restricted or {status="unavailable",item=item,slotID=slot.id,reason="Unique-equipped limit."}
                end
            else
                local message=reason or "The client reports an equip restriction."
                restricted=restricted or {status="unavailable",item=item,slotID=slot.id,reason=message}
            end
        end
    end
    if best and (best.status=="upgrade" or not uncertain) then return best end
    return uncertain or best or future or restricted
end
