local _, XC = ...
-- Native launcher: no extra addon is required. This button opens the planner;
-- it is distinct from a world-map destination waypoint for a gear source.
function XC:PositionMinimapButton()
    if not self.minimapButton or not self.db or not Minimap then return end
    local angle=math.rad(self.db.minimap.angle or 225)
    local rx,ry=Minimap:GetWidth()/2+9,Minimap:GetHeight()/2+9
    local x,y=math.cos(angle),math.sin(angle)
    if GetMinimapShape and GetMinimapShape()=="SQUARE" then
        local edge=math.max(math.abs(x),math.abs(y))
        if edge>0 then x=x/edge; y=y/edge end
    end
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER",Minimap,"CENTER",x*rx,y*ry)
end
function XC:CreateMinimapButton()
    if not self.db or not Minimap then return end
    if self.minimapButton then
        self:PositionMinimapButton(); self.minimapButton:SetShown(not self.db.minimap.hidden); return
    end
    local b=CreateFrame("Button","UpgradeCrossroadsMinimapButton",Minimap)
    self.minimapButton=b
    b:SetSize(28,28); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel()+8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetSize(28,28); icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\UpgradeCrossroads\\Media\\IconRound"); b.icon=icon
    b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick",function(_,button)
        if b.dragged then b.dragged=nil; return end
        if SlashCmdList.UPGRADECROSSROADS then SlashCmdList.UPGRADECROSSROADS(button=="RightButton" and "hunts" or "") end
    end)
    b:SetScript("OnEnter",function()
        if b.dragging then return end
        GameTooltip:SetOwner(b,"ANCHOR_LEFT"); GameTooltip:SetText("Upgrade Crossroads  "..XC.version)
        GameTooltip:AddLine("Left-click: open or close",.9,.93,.96)
        GameTooltip:AddLine("Right-click: saved hunts",.9,.93,.96)
        GameTooltip:AddLine("Drag: move around the minimap",.6,.67,.75)
        GameTooltip:AddLine("Catalog snapshot: "..XC.CatalogMeta.date,.95,.73,.36)
        GameTooltip:AddLine("Catalog updates require a new data release.",.6,.67,.75,true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart",function()
        b.dragging=true; b.dragged=true; GameTooltip:Hide()
        b:SetScript("OnUpdate",function()
            local mx,my=Minimap:GetCenter()
            if not mx or not my then return end
            local px,py=GetCursorPosition(); local scale=Minimap:GetEffectiveScale()
            XC.db.minimap.angle=math.deg(math.atan2(py/scale-my,px/scale-mx))%360
            XC:PositionMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop",function()
        b.dragging=nil; b:SetScript("OnUpdate",nil)
        C_Timer.After(0,function() b.dragged=nil end)
    end)
    self:PositionMinimapButton(); b:SetShown(not self.db.minimap.hidden)
end
