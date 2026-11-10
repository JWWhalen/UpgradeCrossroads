local _, XC = ...
local function defaults()
    local db=type(UpgradeCrossroadsDB)=="table" and UpgradeCrossroadsDB or {}
    UpgradeCrossroadsDB=db; XC.db=db
    if (db.schema or 0)<5 then
        db.appearance=type(db.appearance)=="table" and db.appearance or {}
        db.appearance.font="plain"; db.appearance.outline=false
        if not db.appearance.opacity or db.appearance.opacity>=.95 then db.appearance.opacity=1 end
    end
    db.schema=5
    if type(db.windows)~="table" then db.windows={} end
    if type(db.locations)~="table" then db.locations={} end
    if type(db.pins)~="table" then db.pins={} end
    if type(db.custom)~="table" then db.custom={} end
    if type(db.weights)~="table" then db.weights={} end
    if type(db.minimap)~="table" then db.minimap={angle=225,hidden=false} end
    if type(db.minimap.angle)~="number" then db.minimap.angle=225 end
    if type(db.options)~="table" then db.options={} end
    if not XC.Rules.FactionLabels[db.options.faction] then db.options.faction=nil end
    if db.options.crafted==nil then db.options.crafted=true end
    if db.options.auction==nil then db.options.auction=false end
    if db.options.solo==nil then db.options.solo=false end
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
    local cmd,rest=(msg or ""):match("^(%S*)%s*(.-)%s*$")
    cmd=(cmd or ""):lower()
    if cmd=="" then open(); return end
    if cmd=="appearance" then
        if InCombatLockdown() then XC:Print("Open Appearance after combat."); return end
        XC:ShowAppearance()
    elseif cmd=="resetwindows" then
        for _,f in ipairs({XC.window or false,XC.guide or false,XC.huntWindow or false,XC.editor or false,XC.about or false,XC.appearanceWindow or false}) do
            if f and f.ResetGeometry then f:ResetGeometry() end
        end
        -- Clear saved geometry for windows not constructed in this session.
        for id in pairs(XC.db.windows) do
            local live=(id=="planner" and XC.window) or (id=="tracker" and XC.guide) or (id=="hunts" and XC.huntWindow) or (id=="editor" and XC.editor) or (id=="help" and XC.about) or (id=="appearance" and XC.appearanceWindow)
            if not live then XC.db.windows[id]=nil end
        end
        XC.db.guidePosition=nil; XC:Print("Window sizes, positions and scales restored.")
    elseif cmd=="guide" then
        XC.db.trackerHidden=nil
        if InCombatLockdown() then XC:Print("Open the guide after combat."); return end
        if XC.window and XC.db.activeHunt then XC.window:Hide() end
        XC:RenderGuide()
        if not XC.db.activeHunt then XC:Print("Click an item or Track on an item card to start a guide.") end
    elseif cmd=="hunts" or cmd=="add" or cmd=="about" then
        if InCombatLockdown() then XC:Print("Open Upgrade Crossroads after combat."); return end
        XC:BuildUI(); XC.window:Show()
        if cmd=="hunts" then XC:ShowHunts() elseif cmd=="add" then XC:ShowTargetEditor() else XC:ShowAbout() end
    elseif cmd=="weights" then
        local profile=XC:GetProfile(XC.db.profile)
        if rest=="reset" then XC.db.weights[profile.id]=nil; XC:Print("Restored "..profile.label.." weights."); XC:Refresh(); return end
        if rest=="" then
            local parts={}; for k,v in pairs(profile.weights) do parts[#parts+1]=k.."="..v end; table.sort(parts)
            XC:Print(profile.label..": "..table.concat(parts," ")); return
        end
        local allowed={str=true,agi=true,sta=true,int=true,spi=true,sp=true,heal=true,ap=true,rap=true,armor=true,dps=true,crit=true,hit=true,mpr=true,def=true,dodge=true,parry=true,block=true}
        local nextWeights={}; for k,v in pairs(profile.weights) do nextWeights[k]=v end
        local changed=0
        for token in rest:gmatch("%S+") do
            local key,value=token:match("^(%a+)=([%d%.%-]+)$"); value=tonumber(value)
            if not allowed[key] or not value or value<0 or value>1000 then XC:Print("Invalid weight: "..token..". Example: /uc weights str=1 agi=0.8 sta=0.25"); return end
            nextWeights[key]=value; changed=changed+1
        end
        if changed>0 then XC.db.weights[profile.id]=nextWeights; XC:Print("Saved "..profile.label.." weights."); XC:Refresh() end
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
        if arg1~=XC.name then return end
        defaults()
        XC:ApplyAppearance()
        XC:CreateMinimapButton()
        XC:RenderGuide()
        for _,name in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE_DELAYED","QUEST_LOG_UPDATE","QUEST_TURNED_IN","PLAYER_LEVEL_UP","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(name) end
        XC:Print("Ready. Type /uc to compare your upgrade paths.")
    elseif event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        if XC.requested and XC.requested[arg1] then XC:QueueRefresh() end
    else
        if event=="PLAYER_ENTERING_WORLD" then XC:CreateMinimapButton() end
        XC:QueueRefresh()
    end
end)
