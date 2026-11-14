local oldDisplay, oldShowRewards = QuestInfo_Display, QuestInfo_ShowRewards
local oldQuestInfo, oldHook = QuestInfoFrame, hooksecurefunc
local oldQuestID, oldSelected = GetQuestID, C_QuestLog.GetSelectedQuest
local oldLink, oldLogLink, oldTooltipInfo = GetQuestItemLink, GetQuestLogItemLink, C_TooltipInfo
local oldHead, oldMarkers = FakeInventory[1], XC.db.options.bagUpgrades
local oldCombat = MockCombat
local addonHookCalls, redraws = 0, 0

local function helm(name, strength)
    return {name=name, quality=2, ilvl=20, req=10, equip="INVTYPE_HEAD", classID=4, subclassID=1,
        stats={ITEM_MOD_STRENGTH_SHORT=strength}}
end
local wornID, upgradeID, downgradeID = 992801, 992802, 992803
ItemInfo[wornID], ItemInfo[upgradeID], ItemInfo[downgradeID] = helm("Worn", 5), helm("Upgrade", 10), helm("Downgrade", 2)
FakeInventory[1] = wornID
XC.db.options.bagUpgrades = true
XC:InvalidateUpgradeHints()

local function rewardButton(frame, typeName, kind, id, quest)
    local button = CreateFrame("Button", nil, frame)
    button.type, button.objectType, button.questID = typeName, kind, quest
    button.GetID = function() return id end
    frame.RewardButtons[#frame.RewardButtons+1] = button
    return button
end

local offer, log = CreateFrame("Frame", nil, UIParent), CreateFrame("Frame", nil, UIParent)
offer.RewardButtons, log.RewardButtons = {}, {}
local choice = rewardButton(offer, "choice", "item", 1, 9901)
local currency = rewardButton(offer, "choice", "currency", 2, 9901)
local stale = rewardButton(offer, "reward", "item", 1, 9750)
local fixed = rewardButton(log, "reward", "item", 1, 9902)
local function shownMarker(button)
    for _, frame in ipairs(Frames) do
        if frame:GetParent() == button and frame:IsShown() and frame.drawLayer == "OVERLAY" then return frame end
    end
end

local offerLink = "item:"..upgradeID
GetQuestID = function() return 9901 end
C_QuestLog.GetSelectedQuest = function() return 9902 end
GetQuestItemLink = function(kind, id)
    assert(kind == "choice" and id == 1)
    return offerLink
end
GetQuestLogItemLink = function(kind, id)
    assert(kind == "reward" and id == 1)
    return nil -- Some rewards supply a link only in the tooltip data.
end
local loggedLink = "item:"..upgradeID
C_TooltipInfo = {GetQuestLogItem=function(kind, id)
    assert(kind == "reward" and id == 1)
    return {hyperlink=loggedLink}
end}
QuestInfoFrame = {rewardsFrame=offer}
QuestInfo_Display = function(frame, questLog)
    QuestInfoFrame.rewardsFrame, QuestInfoFrame.questLog = frame, questLog
end
QuestInfo_ShowRewards = function() redraws = redraws+1 end
hooksecurefunc = function(name, callback)
    if name ~= "QuestInfo_Display" and name ~= "QuestInfo_ShowRewards" then
        if oldHook then return oldHook(name, callback) end
        return
    end
    addonHookCalls = addonHookCalls+1
    local original = _G[name]
    _G[name] = function(...) original(...); callback(...) end
end

FireEvent("ADDON_LOADED", "Blizzard_UIPanels_Game")
XC:InitializeQuestUpgradeHints()
assert(addonHookCalls == 2)
QuestInfo_Display(offer, false)
FlushTimers()
local marker = assert(shownMarker(choice))
assert(not shownMarker(currency) and not shownMarker(stale))

choice.objectType = "currency"
QuestInfo_ShowRewards()
FlushTimers()
assert(redraws == 1 and not shownMarker(choice))
choice.objectType = "item"
offerLink = "item:"..downgradeID
QuestInfo_ShowRewards()
FlushTimers()
assert(not shownMarker(choice))
offerLink = "item:"..upgradeID
QuestInfo_ShowRewards()
FlushTimers()
assert(shownMarker(choice) == marker)

MockCombat = true
QuestInfo_Display(log, true)
FlushTimers()
assert(not shownMarker(choice) and not shownMarker(fixed))
MockCombat = false
XC:RefreshUpgradeHints()
assert(shownMarker(fixed))
loggedLink = "item:992804"
QuestInfo_ShowRewards()
FlushTimers()
assert(not shownMarker(fixed) and XC.requested[992804])
ItemInfo[992804] = helm("Newly loaded upgrade", 13)
FireEvent("ITEM_DATA_LOAD_RESULT", 992804, true)
FlushTimers()
assert(shownMarker(fixed))
XC.db.options.bagUpgrades = false
XC:RefreshUpgradeHints()
assert(not shownMarker(fixed))

offer:Hide(); log:Hide()
XC:RefreshQuestUpgradeHints()
QuestInfo_Display, QuestInfo_ShowRewards = oldDisplay, oldShowRewards
QuestInfoFrame, hooksecurefunc = oldQuestInfo, oldHook
GetQuestID, C_QuestLog.GetSelectedQuest = oldQuestID, oldSelected
GetQuestItemLink, GetQuestLogItemLink, C_TooltipInfo = oldLink, oldLogLink, oldTooltipInfo
FakeInventory[1], XC.db.options.bagUpgrades = oldHead, oldMarkers
MockCombat = oldCombat
ItemInfo[wornID], ItemInfo[upgradeID], ItemInfo[downgradeID] = nil, nil, nil
ItemInfo[992804], XC.requested[992804] = nil, nil
XC:InvalidateUpgradeHints()
