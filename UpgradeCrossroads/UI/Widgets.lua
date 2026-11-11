local _, XC = ...
local W={}
XC.W=W
W.panels={}; W.fonts={}; W.windows={}; W.bars={}; W.buttons={}; W.questSurfaces={}; W.ornateShells={}; W.journalPanoramas={}
local dialog={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}
local inset={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}
local function appearance() return XC.db and XC.Appearance and XC:Appearance() or {opacity=1,textBoost=0,readable=true,outline=false,font="classic"} end
function W.Font(record)
    local a=appearance(); local effective=record.parent:GetEffectiveScale()
    local pixels=math.floor((record.size+a.textBoost)*effective+.5)
    if a.readable then pixels=math.max(12+a.textBoost,pixels) end
    local standard=type(STANDARD_TEXT_FONT)=="string" and STANDARD_TEXT_FONT~="" and STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local font=(record.heading or a.font=="classic") and standard or "Fonts\\ARIALN.TTF"
    local outline=a.outline and not record.paper
    record.object:SetFont(font,math.max(1,pixels)/effective,outline and "OUTLINE" or "")
    record.object:SetShadowOffset((outline or record.paper) and 0 or 1,(outline or record.paper) and 0 or -1)
    if record.object.inputPanel then record.object.inputPanel:SetHeight(math.max(record.object.inputBaseHeight,math.max(1,pixels)/effective+8)) end
end
function W.RegisterFont(object,parent,size,color,heading)
    local record={object=object,parent=parent,size=size or 13,color=color,heading=heading}
    W.fonts[#W.fonts+1]=record; W.Font(record); return record
end
function W.Fonts(root)
    for _,record in ipairs(W.fonts) do
        local parent=record.parent
        while parent do
            if parent==root then W.Font(record); break end
            parent=parent:GetParent()
        end
    end
    for _,b in ipairs(W.buttons) do
        local parent=b
        while parent and parent~=root do parent=parent:GetParent() end
        if parent==root then W.FitButton(b) end
    end
end
function W.SetWindowScale(f,scale)
    f:SetScale(scale); W.Fonts(f)
    if f.ApplyLayout then f:ApplyLayout() end
    if f.ReflowContent then f:ReflowContent() end
    if XC.SyncAppearance and XC.appearanceWindow then XC:SyncAppearance() end
end
function W.ApplyTheme()
    local a=appearance()
    for _,panel in ipairs(W.panels) do
        panel.object:SetBackdropColor(panel.color[1],panel.color[2],panel.color[3],panel.button and 1 or a.opacity)
        panel.object:SetBackdropBorderColor(unpack(XC.Colors.border))
    end
    for _,record in ipairs(W.fonts) do if record.color then record.object:SetTextColor(unpack(record.color)) end; W.Font(record) end
    for _,bar in ipairs(W.bars) do bar.object:SetColorTexture(unpack(bar.color)) end
    for _,surface in ipairs(W.questSurfaces) do surface:ApplySurfaceTheme(a) end
    for _,shell in ipairs(W.ornateShells) do shell:ApplyOrnateTheme(a) end
    for _,panorama in ipairs(W.journalPanoramas) do panorama:SetAlpha(math.max(.94,a.opacity or 1)) end
end
local backdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}
function W.Panel(parent,width,height,color)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    if width then f:SetSize(width,height) end
    f:SetBackdrop(inset)
    color=color or XC.Colors.panel
    f:SetBackdropColor(color[1],color[2],color[3],appearance().opacity)
    W.panels[#W.panels+1]={object=f,color=color}
    f:SetBackdropBorderColor(unpack(XC.Colors.border))
    return f
end
function W.Text(parent,text,size,color,width,heading)
    local f=parent:CreateFontString(nil,"OVERLAY")
    W.RegisterFont(f,parent,size or 13,color or XC.Colors.text,heading)
    f:SetTextColor(unpack(color or XC.Colors.text))
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    if width then f:SetWidth(width); f:SetWordWrap(true) end
    f:SetText(text or "")
    return f
end

-- Original journal paintings sit inside native dialog borders. Keep parchment
-- and its ink paired: a custom accent or transparent outer frame must not turn
-- the description into pale text on pale paper, or dark text over the world.
local journalInk={.18,.12,.065}
local journalHeadingInk={.25,.13,.045}
local journalSelected={.95,.82,.45}
function W.JournalPanorama(parent)
    local texture=parent:CreateTexture(nil,"BACKGROUND")
    texture:SetTexture("Interface\\AddOns\\UpgradeCrossroads\\Media\\JournalPanorama")
    texture.styleRole="journalPanorama"
    texture:SetAlpha(math.max(.94,appearance().opacity or 1))
    W.journalPanoramas[#W.journalPanoramas+1]=texture
    return texture
end
function W.QuestSurface(parent,kind,shared)
    local paper=kind=="parchment"
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetAllPoints(parent); f.surfaceKind=paper and "parchment" or "list"; f.sharedPanorama=shared and true or false
    f:SetBackdrop({bgFile=not shared and "Interface\\Buttons\\WHITE8X8" or nil,edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=16,insets={left=6,right=6,top=6,bottom=6}})
    if shared then
        -- Color-only glazing preserves the one scene underneath. Its contrast
        -- follows the pane boundaries when large fonts change their split.
        f.wash=f:CreateTexture(nil,"BACKGROUND")
        f.wash:SetPoint("TOPLEFT",6,-6); f.wash:SetPoint("BOTTOMRIGHT",-6,6)
        if paper then f.wash:SetColorTexture(.90,.72,.43,.68)
        else f.wash:SetColorTexture(.008,.014,.018,.62) end
        f.wash.styleRole=paper and "journalPaperWash" or "journalListWash"
    end
    if not shared then
        f.background=f:CreateTexture(nil,"BACKGROUND")
        f.background:SetPoint("TOPLEFT",6,-6); f.background:SetPoint("BOTTOMRIGHT",-6,6)
        f.background:SetTexture(paper and "Interface\\QuestFrame\\QuestBG" or "Interface\\DialogFrame\\UI-DialogBox-Background")
        f.background.styleRole=paper and "nativeJournalParchment" or "nativeJournalList"
        if not paper then
            f.veil=f:CreateTexture(nil,"BACKGROUND",nil,1)
            f.veil:SetPoint("TOPLEFT",6,-6); f.veil:SetPoint("BOTTOMRIGHT",-6,6)
            f.veil:SetColorTexture(.008,.014,.018,.43); f.veil.styleRole="journalLandscapeVeil"
        end
    end
    function f:ApplySurfaceTheme(a)
        local opacity=math.max(paper and .94 or .82,a.opacity or 1)
        if self.sharedPanorama then self:SetBackdropColor(0,0,0,0)
        elseif paper then self:SetBackdropColor(.88,.78,.58,opacity)
        else self:SetBackdropColor(.025,.035,.04,opacity) end
        if paper then self:SetBackdropBorderColor(.32,.23,.12,1)
        else self:SetBackdropBorderColor(.57,.43,.23,1) end
        if self.background and self.background.SetAlpha then self.background:SetAlpha(opacity) end
    end
    f:ApplySurfaceTheme(appearance()); W.questSurfaces[#W.questSurfaces+1]=f
    return f
end

-- An ornamental skin on the existing shell, not another window. Every element
-- is a texture on its background/border layers, so the real title, emblem,
-- native close control and resize grip retain their input and frame ordering.
function W.OrnateShell(f)
    if f.ornateSkin then return f.ornateSkin end
    local skin={}; f.ornateSkin=skin
    local function texture(role,layer)
        local t=f:CreateTexture(nil,layer or "BACKGROUND")
        t.styleRole=role
        return t
    end
    skin.header=texture("ornateHeader")
    skin.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    if skin.header.SetVertexColor then skin.header:SetVertexColor(.85,.65,.40,1) end
    skin.headerTint=texture("ornateHeaderTint")
    skin.headerTint:SetColorTexture(.22,.105,.037,.68)
    skin.topRule=texture("ornateHeaderTopRule","BORDER")
    skin.topShadow=texture("ornateHeaderTopShadow","BORDER")
    skin.bottomRule=texture("ornateHeaderBottomRule","BORDER")
    skin.bottomShadow=texture("ornateHeaderBottomShadow","BORDER")
    skin.footerRule=texture("ornateFooterRule","BORDER")
    skin.seal=texture("ornateEmblemRing","BORDER")
    skin.seal:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    skin.seal:SetSize(52,52); W.Place(skin.seal,8,1)
    skin.rivets={}
    for i=1,4 do
        local shadow=texture("ornateRivetShadow","BORDER")
        local rivet=texture("ornateRivet","BORDER")
        shadow:SetColorTexture(.07,.045,.018,1); shadow:SetSize(7,7)
        rivet:SetColorTexture(.72,.54,.26,1); rivet:SetSize(4,4)
        skin.rivets[i]={shadow=shadow,face=rivet}
    end
    function skin:Layout()
        local width,height=f:GetWidth(),f:GetHeight()
        local headerHeight=math.max(44,(f.title and f.title:GetStringHeight() or 28)+16)
        W.Place(self.header,8,6); self.header:SetSize(width-16,headerHeight)
        W.Place(self.headerTint,8,6); self.headerTint:SetSize(width-16,headerHeight)
        W.Place(self.topShadow,20,7); self.topShadow:SetSize(width-40,2)
        W.Place(self.topRule,20,9); self.topRule:SetSize(width-40,1)
        W.Place(self.bottomRule,18,6+headerHeight); self.bottomRule:SetSize(width-36,2)
        W.Place(self.bottomShadow,18,8+headerHeight); self.bottomShadow:SetSize(width-36,2)
        W.Place(self.footerRule,20,height-9); self.footerRule:SetSize(width-40,1)
        local positions={{13,13},{width-19,13},{13,height-20},{width-19,height-20}}
        for i,point in ipairs(positions) do
            W.Place(self.rivets[i].shadow,point[1],point[2])
            W.Place(self.rivets[i].face,point[1]+1,point[2]+1)
        end
    end
    function f:ApplyOrnateTheme(a)
        self:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
        self:SetBackdropColor(XC.Colors.bg[1],XC.Colors.bg[2],XC.Colors.bg[3],a.opacity or 1)
        self:SetBackdropBorderColor(unpack(XC.Colors.border))
        skin.header:SetAlpha(a.opacity or 1)
        skin.headerTint:SetAlpha(a.opacity or 1)
        local accent=XC.Colors.gold
        skin.topRule:SetColorTexture(accent[1],accent[2],accent[3],.72)
        skin.bottomRule:SetColorTexture(accent[1],accent[2]*.88,accent[3]*.72,.95)
        skin.footerRule:SetColorTexture(accent[1],accent[2]*.8,accent[3]*.7,.44)
        skin.topShadow:SetColorTexture(.02,.014,.008,.9)
        skin.bottomShadow:SetColorTexture(.015,.01,.006,.95)
    end
    local previous=f.ApplyLayout
    f.ApplyLayout=function(...)
        if previous then previous(...) end
        skin:Layout()
    end
    f:HookScript("OnSizeChanged",function() skin:Layout() end)
    W.ornateShells[#W.ornateShells+1]=f
    f:ApplyOrnateTheme(appearance()); skin:Layout()
    return skin
end
function W.JournalText(parent,text,size,width,heading)
    local f=parent:CreateFontString(nil,"OVERLAY")
    local color=heading and journalHeadingInk or journalInk
    local record=W.RegisterFont(f,parent,size or 14,color,heading)
    record.paper=true; W.Font(record)
    f:SetTextColor(unpack(color)); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    if width then f:SetWidth(width); f:SetWordWrap(true) end
    f:SetText(text or "")
    return f
end
function W.JournalRow(parent,text,width,height,handler)
    local b=CreateFrame("Button",nil,parent); b:SetSize(width,height or 27)
    b.isRow=true; b.isJournalRow=true
    b.highlight=b:CreateTexture(nil,"BACKGROUND"); b.highlight:SetAllPoints()
    b.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    if b.highlight.SetBlendMode then b.highlight:SetBlendMode("ADD") end
    b.highlight:Hide()
    b.label=b:CreateFontString(nil,"OVERLAY")
    b.labelRecord=W.RegisterFont(b.label,b,13,XC.Colors.text)
    b.label:SetPoint("LEFT",10,0); b.label:SetWidth(width-20)
    b.label:SetTextColor(unpack(XC.Colors.text)); b.label:SetJustifyH("LEFT"); b.label:SetJustifyV("MIDDLE")
    b.label:SetWordWrap(false); b.label:SetText(text or "")
    function b:JournalHover(hover)
        self.journalHovered=hover
        self.highlight:SetShown(self.selected or hover)
        if self.highlight.SetAlpha then self.highlight:SetAlpha(self.selected and .8 or .38) end
    end
    b:SetScript("OnEnter",function(self) self:JournalHover(true) end)
    b:SetScript("OnLeave",function(self) self:JournalHover(false) end)
    if handler then b:SetScript("OnClick",handler) end
    return b
end
function W.SelectJournalRow(b,selected,color)
    if color then b.journalColor=color end
    local chosen=selected and journalSelected or b.journalColor or XC.Colors.text
    b.selected=selected; b.labelRecord.color=chosen
    b.label:SetTextColor(unpack(chosen)); b:JournalHover(b.journalHovered)
end
function W.Bar(parent,color,width,height)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetColorTexture(unpack(color)); t:SetSize(width,height or 2)
    W.bars[#W.bars+1]={object=t,color=color}
    return t
end
function W.FitButton(b,width)
    if width then b.requestedWidth=width end
    b.label:SetWidth(0); b.label:SetHeight(0); b.label:SetWordWrap(false)
    local needed=b.label:GetStringWidth()+24
    b:SetSize(math.max(b.requestedWidth or 0,needed),math.max(b.baseHeight or 28,b.label:GetStringHeight()+8))
end
function W.Button(parent,text,width,height,handler,color)
    -- Use the template's own font string. A backdrop or a second label can
    -- cover its art and compete with the template's text bounds in the client.
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    W.buttons[#W.buttons+1]=b
    b.requestedWidth=width; b.baseHeight=height or 28; b:SetText(text or "")
    b.label=b:GetFontString(); W.RegisterFont(b.label,b,13,XC.Colors.text)
    b.label:SetTextColor(unpack(XC.Colors.text)); b.label:SetWordWrap(false)
    W.FitButton(b,width)
    if handler then b:SetScript("OnClick",handler) end
    return b
end
function W.Row(parent,text,width,height,handler)
    local b=CreateFrame("Button",nil,parent); b:SetSize(width,height or 28); b.isRow=true
    b.highlight=b:CreateTexture(nil,"BACKGROUND"); b.highlight:SetAllPoints(); b.highlight:SetColorTexture(.65,.48,.2,.16); b.highlight:Hide()
    b.label=W.Text(b,text,13,XC.Colors.text,width-16); b.label:SetPoint("LEFT",8,0)
    b.label:SetJustifyV("MIDDLE"); b.label:SetWordWrap(false)
    if handler then b:SetScript("OnClick",handler) end
    b:SetScript("OnEnter",function() b.highlight:Show() end)
    b:SetScript("OnLeave",function() b.highlight:SetShown(b.selected) end)
    return b
end
function W.SelectRow(b,selected)
    b.highlight:SetColorTexture(XC.Colors.gold[1],XC.Colors.gold[2],XC.Colors.gold[3],.12)
    b.selected=selected; b.highlight:SetShown(selected); b.label:SetTextColor(unpack(selected and XC.Colors.gold or XC.Colors.text))
end
function W.Toggle(parent,label,handler)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    b:SetSize(24,24)
    local t=W.Text(b,label,11,XC.Colors.muted); b.label=t
    t:SetPoint("LEFT",b,"RIGHT",2,0)
    b:SetScript("OnClick",function(self) handler(self:GetChecked() and true or false) end)
    return b
end
function W.Input(parent,width,height,multiline)
    local panel=W.Panel(parent,width,height,XC.Colors.bg)
    local edit=CreateFrame("EditBox",nil,panel)
    edit:SetPoint("TOPLEFT",8,-2); edit:SetPoint("BOTTOMRIGHT",-8,2)
    edit:SetAutoFocus(false); W.RegisterFont(edit,panel,12,XC.Colors.text)
    edit:SetMultiLine(multiline and true or false)
    edit:SetMaxLetters(multiline and 500 or 180)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    edit.inputPanel=panel; edit.inputBaseHeight=height
    panel.edit=edit
    return panel
end
function W.Tooltip(frame,item,shortcut)
    frame:SetScript("OnEnter",function(self)
        if self.JournalHover then self:JournalHover(true) end
        local _,_,link=XC.Client.Presentation(item)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        if link then GameTooltip:SetHyperlink(link)
        else GameTooltip:SetText(item.name); GameTooltip:AddLine("Item data is not cached yet.",.6,.7,.8,true) end
        GameTooltip:AddLine(shortcut or "Click: track  /  Shift-click or right-click: chat",.45,.85,.75,true)
        GameTooltip:AddLine("Ctrl-click: dressing room",.6,.7,.8,true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function(self) if self.JournalHover then self:JournalHover(false) end; GameTooltip:Hide() end)
end

-- Native resizing, saved per character. Content lays out again at the new size;
-- corner drags and A-/A+ scale this window with readable, pixel-snapped fonts.
function W.ResizeButton(button,width)
    if button.isRow then button:SetWidth(width); button.label:SetWidth(width-16) else W.FitButton(button,width) end
end
function W.Place(frame,x,y) frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",x,-y); return frame end
function W.Hint(frame,text)
    frame:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(text); GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function W.ItemClick(item,onTrack,button)
    if button=="RightButton" or (IsShiftKeyDown and IsShiftKeyDown()) then return XC:LinkItem(item) end
    if IsControlKeyDown and IsControlKeyDown() then
        local _,_,link=XC.Client.Presentation(item)
        if link and DressUpItemLink then DressUpItemLink(link) end
        return
    end
    if onTrack then onTrack() end
end
function W.Resizable(f,id,minW,minH,layout)
    XC.db.windows=XC.db.windows or {}
    local defaults={width=f:GetWidth(),height=f:GetHeight(),scale=f:GetScale(),point={f:GetPoint()}}
    local saved=XC.db.windows[id] or {}; XC.db.windows[id]=saved
    f.windowID=id; f.minWidth=minW; f.minHeight=minH; f.defaultGeometry=defaults
    W.windows[#W.windows+1]=f; f:SetBackdrop(dialog)
    f:SetBackdropColor(XC.Colors.bg[1],XC.Colors.bg[2],XC.Colors.bg[3],appearance().opacity)
    f:SetBackdropBorderColor(unpack(XC.Colors.border))
    if f.title then f.title:SetTextColor(unpack(XC.Colors.gold)) end
    f.headerIcon=f:CreateTexture(nil,"ARTWORK"); f.headerIcon:SetSize(32,32); W.Place(f.headerIcon,18,12)
    f.headerIcon:SetTexture("Interface\\AddOns\\UpgradeCrossroads\\Media\\LogoRound")
    f:SetMovable(true); f:SetResizable(true); f:SetResizeBounds(minW,minH,1800,1200)
    f:SetClampedToScreen(true); f:EnableMouse(true)
    if f.SetToplevel then f:SetToplevel(true) end
    local function save()
        local point,_,relativePoint,x,y=f:GetPoint()
        saved.width=f:GetWidth(); saved.height=f:GetHeight(); saved.scale=f:GetScale()
        saved.position={point=point,relativePoint=relativePoint,x=x,y=y}
        if id=="tracker" then XC.db.guidePosition=saved.position end
    end
    local function reflow()
        local width=f:GetWidth()
        W.Place(f.closeButton,width-40,8)
        if f.title then W.Place(f.title,60,18); f.title:SetWidth(width-116) end
        if f.description then f.description:SetWidth(width-40) end
        layout(f,width,f:GetHeight())
    end
    local drag=CreateFrame("Frame",nil,f); f.dragHandle=drag
    drag:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); drag:SetPoint("TOPRIGHT",f,"TOPRIGHT",-48,0)
    drag:SetHeight(48); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() f:StartMoving() end)
    drag:SetScript("OnDragStop",function() f:StopMovingOrSizing(); save() end)
    f.closeButton=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    f.closeButton:SetSize(32,32); f.closeButton:SetScript("OnClick",function() f:Hide() end)
    f.closeButton:SetFrameLevel(drag:GetFrameLevel()+2); f.closeButton:EnableMouse(true); f.closeButton:RegisterForClicks("LeftButtonUp")
    W.Hint(f.closeButton,"Close this window.")
    f.resizeGrip=CreateFrame("Button",nil,f)
    f.resizeGrip:SetSize(22,22); f.resizeGrip:SetPoint("BOTTOMRIGHT",-4,4); f.resizeGrip:SetFrameLevel(f:GetFrameLevel()+5)
    f.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.resizeGrip:EnableMouse(true); f.resizeGrip:RegisterForDrag("LeftButton")
    local gesture
    local function finish()
        if not gesture then return end
        gesture=nil; f.resizeGrip:SetScript("OnUpdate",nil)
        f:StopMovingOrSizing(); reflow(); save()
    end
    f.resizeGrip:SetScript("OnDragStart",function()
        finish(); GameTooltip:Hide()
        if IsShiftKeyDown and IsShiftKeyDown() then
            gesture={resize=true}; f:StartSizing("BOTTOMRIGHT"); return
        end
        local effective=f:GetEffectiveScale()
        local left,top=f:GetLeft(),f:GetTop()
        if not left or not top then return end
        local x,y=GetCursorPosition()
        local parentScale=UIParent:GetEffectiveScale()
        gesture={scale=f:GetScale(),effective=effective,x=x,y=y,left=left*effective,top=top*effective,
            parentLeft=UIParent:GetLeft()*parentScale,parentTop=UIParent:GetTop()*parentScale,
            width=f:GetWidth()*effective,height=f:GetHeight()*effective}
        f.resizeGrip:SetScript("OnUpdate",function()
            local g=gesture; if not g or g.resize then return end
            local px,py=GetCursorPosition()
            -- Project cursor movement onto the original diagonal. Using the
            -- drag's starting values avoids feedback as the frame changes scale.
            local ratio=1+((px-g.x)*g.width+(g.y-py)*g.height)/(g.width*g.width+g.height*g.height)
            local scale=XC:ClampWindowScale(math.floor(g.scale*ratio*100+.5)/100)
            local nextEffective=g.effective*scale/g.scale
            if scale==f:GetScale() then return end
            W.SetWindowScale(f,scale)
            -- Offsets use this frame's scaled units, so the opposite corner
            -- remains at exactly the same physical screen position.
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",(g.left-g.parentLeft)/nextEffective,(g.top-g.parentTop)/nextEffective)
        end)
    end)
    f.resizeGrip:SetScript("OnDragStop",finish)
    f.resizeGrip:SetScript("OnMouseUp",finish)
    f.resizeGrip:SetScript("OnHide",finish)
    f:HookScript("OnHide",finish)
    W.Hint(f.resizeGrip,"Drag to scale the whole window, including text and buttons. Shift-drag to resize its layout. Settings save per window. /uc resetwindows restores defaults.")
    f.ApplyLayout=reflow; f.SaveGeometry=save
    f.ResetGeometry=function()
        finish()
        f:ClearAllPoints(); f:SetPoint(unpack(defaults.point)); W.SetWindowScale(f,XC:ClampWindowScale(defaults.scale))
        f:SetSize(defaults.width,defaults.height); reflow(); save()
    end
    f:SetScript("OnSizeChanged",function() reflow(); save() end)
    W.SetWindowScale(f,XC:ClampWindowScale(tonumber(saved.scale) or defaults.scale))
    if saved.position and saved.position.point and saved.position.relativePoint then
        local p=saved.position; f:ClearAllPoints(); f:SetPoint(p.point,UIParent,p.relativePoint,p.x or 0,p.y or 0)
    end
    -- Copy both values before SetSize invokes OnSizeChanged and saves geometry.
    local width=math.max(minW,math.min(1800,tonumber(saved.width) or defaults.width))
    local height=math.max(minH,math.min(1200,tonumber(saved.height) or defaults.height))
    f:SetSize(width,height); reflow()
    if id~="tracker" then
        f:HookScript("OnShow",function() if XC.RenderGuide then XC:RenderGuide() end end)
        f:HookScript("OnHide",function() if XC.RenderGuide then XC:RenderGuide() end end)
    end
    local global="UpgradeCrossroads"..id.."Window"
    _G[global]=f; if UISpecialFrames then table.insert(UISpecialFrames,global) end
end
function W.StatLine(item,weights)
    if not item or not item.stats then return "Item stats are loading" end
    local labels={str="Str",agi="Agi",sta="Sta",int="Int",spi="Spirit",sp="Spell",heal="Healing",ap="AP",rap="Ranged AP",armor="Armor",dps="Weapon DPS",crit="Crit",hit="Hit",mpr="MP5",def="Defense"}
    local order={"dps","str","agi","sta","int","spi","sp","heal","ap","rap","armor","crit","hit","mpr","def"}
    local out={}
    for _,key in ipairs(order) do
        local v=item.stats[key]
        if v and v~=0 and (weights[key] or key=="dps") then out[#out+1]=string.format("%g %s",math.floor(v*10+.5)/10,labels[key]) end
        if #out>=5 then break end
    end
    if #out==0 then return "No weighted base stats; inspect effects" end
    return table.concat(out,"  /  ")
end
