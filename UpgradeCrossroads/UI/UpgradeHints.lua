local _, XC = ...
local safe=XC.Client.Safe
local engine=XC.UpgradeComparison
local context, activeProfile, comparisons
local tooltipInstalled, bagHookInstalled, bagRefreshQueued
local markers=setmetatable({}, {__mode="k"})
local visibleBagMarkers={}

local function enabled(key)
    return XC.db and XC.db.options and XC.db.options[key]~=false
end

local function readable(value,kind)
    return type(value)==kind and not (issecretvalue and issecretvalue(value))
end

local function compare(link,slot)
    if not engine.ItemID(link) then return nil end
    if not context then
        context=engine.Context()
        activeProfile=XC:GetProfile(XC.db.profile)
        comparisons={}
    end
    -- Character-slot tooltips intentionally identify the worn piece. Bag,
    -- quest and other tooltips compare the same exact link as a candidate.
    if slot then return engine.Evaluate(link,context,activeProfile,slot) end
    if comparisons[link]==nil then
        -- Item-load and equipment events invalidate even incomplete results.
        comparisons[link]=engine.Evaluate(link,context,activeProfile) or false
    end
    return comparisons[link] or nil
end

function XC:IsLiveUpgrade(link)
    if not self.db or not readable(link,"string") then return false end
    local result=compare(link)
    return result~=nil and result.status=="upgrade"
end

local function equippedSlot(info)
    if not info or not readable(info.getterName,"string") or info.getterName~="GetInventoryItem"
        or not readable(info.getterArgs,"table") then return nil end
    local unit,slot
    if SafeUnpack then
        unit,slot=safe(SafeUnpack,info.getterArgs)
    else
        unit,slot=unpack(info.getterArgs)
    end
    if readable(unit,"string") and unit=="player" and readable(slot,"number") then return slot end
end

local function displayLink(tooltip,data)
    if readable(data,"table") and readable(data.hyperlink,"string") then return data.hyperlink end
    local _,link=safe(TooltipUtil and TooltipUtil.GetDisplayedItem,tooltip)
    if readable(link,"string") then return link end
    _,link=safe(tooltip.GetItem,tooltip)
    if readable(link,"string") then return link end
end

local function showTooltipComparison(tooltip,data)
    if not enabled("upgradeTooltips") or (tooltip~=GameTooltip and tooltip~=ItemRefTooltip) then return end
    local info=safe(tooltip.GetProcessingTooltipInfo,tooltip)
    if not readable(info,"table") then info=nil end
    if info and readable(info.append,"boolean") and info.append then return end
    local link=displayLink(tooltip,data)
    if not link then return end
    local result=compare(link,equippedSlot(info))
    if not result or result.status=="unavailable" then return end

    local slot=result.slotID and XC:GetSlot(result.slotID)
    local slotLabel=slot and slot.label or "Gear"
    local description,r,g,b
    if result.status=="future" then
        description="Usable at level "..result.minimumLevel
        r,g,b=.95,.77,.37
    elseif result.status=="incomplete" then
        description=result.reason or "Comparison unavailable"
        r,g,b=.71,.69,.62
    elseif result.status=="equipped" then
        description="Equipped"
        r,g,b=.71,.69,.62
    elseif result.status=="sidegrade" then
        description="Same score as equipped"
        r,g,b=.71,.69,.62
    else
        local gain=result.percent and string.format("%+.1f%%",result.percent) or string.format("%+.1f points",result.delta)
        local label=result.status=="upgrade" and "upgrade" or "downgrade"
        description=gain.." "..label
        if result.status=="upgrade" then r,g,b=.35,.95,.55 else r,g,b=.95,.49,.42 end
    end

    tooltip:AddLine("Upgrade Crossroads / "..(activeProfile.spec or activeProfile.label),.95,.77,.37,true)
    local detail=slotLabel.." / "..description
    if result.score then detail=detail..string.format(" / %.1f model score",result.score) end
    tooltip:AddLine(detail,r,g,b,true)
    local rank,_,count=XC:CatalogRank(result,context,activeProfile)
    if rank then tooltip:AddLine(string.format("Available catalog rank #%d of %d",rank,count),.71,.69,.62,true) end
    local key=tostring(result.item.id)
    local pin=XC.db.pins[key]
    local journal=XC.db.journal
    local obtained=(pin and pin.acquired) or (journal and journal.obtained and journal.obtained[key])
    if obtained or pin then
        tooltip:AddLine(obtained and "Obtained" or "Tracked in Hunts",.67,.81,.68)
    end
end

local function createMarker(button)
    local marker
    if C_Texture and safe(C_Texture.GetAtlasInfo,"bags-greenarrow") then
        marker=button:CreateTexture(nil,"OVERLAY")
        marker:SetAtlas("bags-greenarrow")
        marker:SetSize(16,16)
    else
        marker=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        marker:SetText("+")
        marker:SetTextColor(.35,.95,.55)
    end
    marker:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
    return marker
end

function XC:SetUpgradeMarker(button,shown)
    local marker=markers[button]
    -- Reuse existing regions in combat. New ones wait for the next refresh.
    if not marker and shown and not InCombatLockdown() then
        marker=createMarker(button)
        markers[button]=marker
    end
    if marker then marker:SetShown(shown) end
    return marker~=nil and shown
end

local function updateBagMarkers()
    local visible={}
    if enabled("bagUpgrades") and ContainerFrameUtil_EnumerateBagFrames and C_Container and C_Container.GetContainerItemLink then
        for _,container in ContainerFrameUtil_EnumerateBagFrames() do
            if container:IsShown() and container.EnumerateValidItems then
                for _,button in container:EnumerateValidItems() do
                    local bagID,slotID=safe(button.GetBagID,button),safe(button.GetID,button)
                    if readable(bagID,"number") and readable(slotID,"number") then
                        local link=safe(C_Container.GetContainerItemLink,bagID,slotID)
                        if XC:IsLiveUpgrade(link) and XC:SetUpgradeMarker(button,true) then visible[button]=true end
                    end
                end
            end
        end
    end
    for button in pairs(visibleBagMarkers) do
        if not visible[button] then XC:SetUpgradeMarker(button,false) end
    end
    visibleBagMarkers=visible
end

local function onBagOpened()
    if not enabled("bagUpgrades") or bagRefreshQueued then return end
    bagRefreshQueued=true
    C_Timer.After(0,function()
        bagRefreshQueued=nil
        updateBagMarkers()
    end)
end

function XC:InitializeUpgradeHints()
    if not tooltipInstalled then
        local itemType=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and itemType~=nil then
            tooltipInstalled=pcall(TooltipDataProcessor.AddTooltipPostCall,itemType,showTooltipComparison)
        end
        if not tooltipInstalled and GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
            GameTooltip:HookScript("OnTooltipSetItem",showTooltipComparison)
            if ItemRefTooltip and ItemRefTooltip.HasScript and ItemRefTooltip:HasScript("OnTooltipSetItem") then
                ItemRefTooltip:HookScript("OnTooltipSetItem",showTooltipComparison)
            end
            tooltipInstalled=true
        end
    end
    if not bagHookInstalled and hooksecurefunc and ContainerFrame_GenerateFrame then
        bagHookInstalled=pcall(hooksecurefunc,"ContainerFrame_GenerateFrame",onBagOpened)
    end
end

function XC:RefreshUpgradeHints()
    self:InvalidateUpgradeHints()
    self:InitializeUpgradeHints()
    updateBagMarkers()
    if self.RefreshQuestUpgradeHints then self:RefreshQuestUpgradeHints() end
end

function XC:InvalidateUpgradeHints()
    context,activeProfile,comparisons=nil,nil,nil
end
