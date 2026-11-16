local _, XC = ...
local function defaults()
    local db=type(UpgradeCrossroadsDB)=="table" and UpgradeCrossroadsDB or {}
    UpgradeCrossroadsDB=db; XC.db=db
    db.appearance=type(db.appearance)=="table" and db.appearance or {}
    if (db.schema or 0)<5 then
        db.appearance.outline=false
        if not db.appearance.opacity or db.appearance.opacity>=.95 then db.appearance.opacity=1 end
    end
    -- Older versions saved the automatic plain default as a normal selection.
    -- Switch it once; choices made with the new font control remain explicit.
    if (db.schema or 0)<6 and db.appearance.fontChosen~=true then db.appearance.font="classic" end
    db.schema=6
    if type(db.windows)~="table" then db.windows={} end
    if type(db.locations)~="table" then db.locations={} end
    if type(db.pins)~="table" then db.pins={} end
    if XC.JournalState then XC:JournalState(); XC:InvalidateJournal() end
    if type(db.custom)~="table" then db.custom={} end
    if type(db.weights)~="table" then db.weights={} end
    if type(db.minimap)~="table" then db.minimap={angle=225,hidden=false} end
    if type(db.minimap.angle)~="number" then db.minimap.angle=225 end
    if type(db.options)~="table" then db.options={} end
    if not XC.Rules.FactionLabels[db.options.faction] then db.options.faction=nil end
    if db.options.crafted==nil then db.options.crafted=true end
    if db.options.auction==nil then db.options.auction=false end
    if db.options.solo==nil then db.options.solo=false end
    if db.options.upgradeTooltips==nil then db.options.upgradeTooltips=true end
    if db.options.bagUpgrades==nil then db.options.bagUpgrades=true end
    db.slot=db.slot or 16
    db.pinOrder=db.pinOrder or 0
    local _,class=UnitClass("player")
    XC:MigrateProfiles(class)
end
local function open()
    if not XC.db then return end
    if InCombatLockdown() then XC:Print("Open Upgrade Crossroads after combat."); return end
    XC:BuildUI()
    if XC.window:IsShown() then XC.window:Hide() else XC:ShowPage(XC.window.activePage or "gear") end
end
local function command(msg)
    if not XC.db then return end
    local cmd,rest=(msg or ""):match("^(%S*)%s*(.-)%s*$")
    cmd=(cmd or ""):lower()
    if cmd=="" then open(); return end
    if cmd=="appearance" then
        if InCombatLockdown() then XC:Print("Open Appearance after combat."); return end
        XC:ShowAppearance(rest)
    elseif cmd=="resetwindows" then
        for id in pairs(XC.db.windows) do XC.db.windows[id]=nil end
        XC.db.guidePosition=nil
        if XC.window then XC.window:ResetGeometry() end
        if XC.guide then XC.guide:ResetGeometry() end
        XC:Print("Window sizes, positions and scales restored.")
    elseif cmd=="guide" then
        XC.db.trackerHidden=nil
        if InCombatLockdown() then XC:Print("Open the guide after combat."); return end
        if XC.window and XC.db.activeHunt then XC.window:Hide() end
        XC:RenderGuide()
        if not XC.db.activeHunt then XC:Print("Click an item or Track on an item card to start a guide.") end
    elseif cmd=="hunts" or cmd=="add" or cmd=="about" then
        if InCombatLockdown() then XC:Print("Open Upgrade Crossroads after combat."); return end
        if cmd=="hunts" then XC:ShowHunts() elseif cmd=="add" then XC:ShowTargetEditor() else XC:ShowAbout() end
    elseif cmd=="weights" then
        if rest=="" then
            XC:Print(XC:GetProfile(XC.db.profile).label..": "..XC:StatWeightText())
        else
            local _,message=XC:ApplyStatWeights(rest)
            if message then XC:Print(message) end
        end
    elseif cmd=="minimap" then
        if rest=="hide" then XC.db.minimap.hidden=true
        elseif rest=="reset" then XC.db.minimap.angle=225; XC.db.minimap.hidden=false
        else XC.db.minimap.hidden=false end
        XC:CreateMinimapButton()
        XC:Print(XC.db.minimap.hidden and "Minimap shortcut hidden. Restore with /uc minimap show." or "Minimap shortcut shown. Left-click to open, right-click for hunts; drag to move.")
    elseif cmd=="scale" then
        local n=tonumber(rest)
        if n and n>=.5 and n<=1.5 then XC:BuildUI(); XC.W.SetWindowScale(XC.window,XC:ClampWindowScale(n)); XC.window:SaveGeometry() else XC:Print("Use /uc scale 0.8 (range 0.5 to 1.5).") end
    elseif cmd=="status" then
        local v,b,_,interface=GetBuildInfo()
        XC:Print("v"..XC.version.." / client "..tostring(v).." build "..tostring(b).." / interface "..tostring(interface).." / catalog "..XC.CatalogMeta.count.." items / snapshot "..XC.CatalogMeta.date)
        XC:Print("Item API: "..tostring(C_Item and type(C_Item.GetItemInfo)).."; quest history: "..tostring(C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs)))
        XC:Print("Location provider: "..(LibQuestieDB and "installed QuestieDB" or "native quest guidance + bundled entrances").." / active hunt: "..tostring(XC.db.activeHunt or "none"))
    else XC:Print("/uc | /uc appearance | /uc hunts | /uc add | /uc minimap | /uc weights | /uc about | /uc status") end
end
SLASH_UPGRADECROSSROADS1="/uc"
SLASH_UPGRADECROSSROADS2="/crossroads"
SlashCmdList.UPGRADECROSSROADS=command
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,arg1)
    if event=="ADDON_LOADED" then
        if arg1~=XC.name then
            if XC.db then XC:InitializeQuestUpgradeHints() end
            return
        end
        defaults()
        XC:RefreshSavedHuntSources()
        XC:InitializeUpgradeHints()
        XC:InitializeQuestUpgradeHints()
        XC:ApplyAppearance()
        XC:CreateMinimapButton()
        XC:RenderGuide()
        for _,name in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE_DELAYED","QUEST_LOG_UPDATE","QUEST_TURNED_IN","PLAYER_LEVEL_UP","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(name) end
        XC:Print("Ready. Type /uc to compare your upgrade paths.")
    elseif event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        if XC.requested and XC.requested[arg1] then
            XC:InvalidateUpgradeHints()
            XC:QueueRefresh()
        end
    else
        if event=="PLAYER_ENTERING_WORLD" then XC:CreateMinimapButton() end
        if event=="PLAYER_EQUIPMENT_CHANGED" or event=="PLAYER_LEVEL_UP" or event=="PLAYER_ENTERING_WORLD" or event=="QUEST_TURNED_IN" then
            XC:InvalidateUpgradeHints()
        end
        XC:QueueRefresh()
    end
end)
