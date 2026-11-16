local _, XC = ...
local safe = XC.Client.Safe
local installedDisplay, installedRewards, queued
local markedRewards

local function enabled()
    return XC.db and XC.db.options.bagUpgrades ~= false
end

local function clearMarkers(rewards)
    for _, button in ipairs(rewards.RewardButtons) do
        XC:SetUpgradeMarker(button, false)
    end
end

local function readable(value, kind)
    return type(value) == kind and not (issecretvalue and issecretvalue(value))
end

local function rewardLink(button, questID, fromLog)
    -- Reward buttons are recycled for currencies and for other quests.
    if not button:IsShown() or button.objectType ~= "item" or not readable(button.questID, "number")
        or button.questID ~= questID then return end
    local kind, index = button.type, button:GetID()
    if kind ~= "choice" and kind ~= "reward" then return end

    local getLink, getTooltip = GetQuestItemLink, C_TooltipInfo and C_TooltipInfo.GetQuestItem
    if fromLog then
        getLink = GetQuestLogItemLink
        getTooltip = C_TooltipInfo and C_TooltipInfo.GetQuestLogItem
    end
    local link = safe(getLink, kind, index)
    if readable(link, "string") then return link end
    local data = safe(getTooltip, kind, index)
    if readable(data, "table") and readable(data.hyperlink, "string") then return data.hyperlink end
end

function XC:RefreshQuestUpgradeHints()
    local info = QuestInfoFrame
    local rewards = info and info.rewardsFrame
    local visible = rewards and safe(rewards.IsVisible or rewards.IsShown, rewards)
    if not enabled() or not visible or type(rewards.RewardButtons) ~= "table" then rewards = nil end
    if markedRewards and markedRewards ~= rewards then clearMarkers(markedRewards) end
    markedRewards = rewards
    if not rewards then return end

    local getQuestID = GetQuestID
    if info.questLog then getQuestID = C_QuestLog and C_QuestLog.GetSelectedQuest or GetQuestLogSelectedID end
    local questID = safe(getQuestID)
    if not readable(questID, "number") or questID <= 0 then
        clearMarkers(rewards)
        return
    end
    for _, button in ipairs(rewards.RewardButtons) do
        local link = rewardLink(button, questID, info.questLog)
        self:SetUpgradeMarker(button, link ~= nil and self:IsLiveUpgrade(link))
    end
end

local function queueRefresh()
    if queued or not enabled() then return end
    queued = true
    -- Quest offers and map details may still be opening their parent frame.
    C_Timer.After(0, function()
        queued = nil
        XC:RefreshQuestUpgradeHints()
    end)
end

function XC:InitializeQuestUpgradeHints()
    if not hooksecurefunc then return end
    -- Display templates retain their original rewards function. Blizzard also
    -- calls the global directly when quest items finish loading.
    if not installedDisplay and QuestInfo_Display then
        installedDisplay = pcall(hooksecurefunc, "QuestInfo_Display", queueRefresh)
    end
    if not installedRewards and QuestInfo_ShowRewards then
        installedRewards = pcall(hooksecurefunc, "QuestInfo_ShowRewards", queueRefresh)
    end
end
