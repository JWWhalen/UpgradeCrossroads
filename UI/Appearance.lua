local _,XC=...
local W=XC.W
XC.ThemeOrder={"classic","alliance","horde","midnight"}
XC.Themes={
 classic={label="Classic",bg={.055,.05,.043,1},panel={.095,.085,.068,1},raised={.16,.14,.105,1},border={.36,.31,.22,1},text={.93,.92,.87,1},muted={.71,.69,.62,1},gold={.95,.77,.37,1}},
 alliance={label="Alliance",bg={.035,.05,.075,1},panel={.06,.085,.12,1},raised={.1,.13,.18,1},border={.82,.7,.43,1},text={.94,.96,1,1},muted={.74,.8,.91,1},gold={.48,.74,1,1}},
 horde={label="Horde",bg={.075,.035,.025,1},panel={.12,.06,.045,1},raised={.18,.1,.065,1},border={.73,.53,.32,1},text={1,.92,.8,1},muted={.87,.73,.62,1},gold={1,.45,.25,1}},
 midnight={label="Midnight",bg={.035,.035,.045,1},panel={.065,.065,.08,1},raised={.11,.11,.135,1},border={.63,.65,.72,1},text={.95,.96,1,1},muted={.75,.77,.83,1},gold={.78,.69,1,1}},
}
function XC:Appearance()
    self.db.appearance=self.db.appearance or {}
    local a=self.db.appearance
    if not self.Themes[a.theme] then a.theme="classic" end
    a.opacity=math.max(0,math.min(1,tonumber(a.opacity) or 1))
    a.textBoost=math.max(0,math.min(2,math.floor(tonumber(a.textBoost) or 0)))
    if a.readable==nil then a.readable=true end
    if a.outline==nil then a.outline=false end
    if a.font~="plain" then a.font="classic" end
    return a
end
function XC.ParseHex(hex)
    hex=tostring(hex or ""):gsub("#",""):upper()
    if not hex:match("^%x%x%x%x%x%x$") then return nil end
    return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,1},hex
end
function XC.ColorHex(c) return string.format("%02X%02X%02X",math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5)) end
function XC:ClampWindowScale(scale)
    return math.max(self:Appearance().readable and .8 or .5,math.min(1.5,scale))
end
local function replaceColor(target,source) for i=1,4 do target[i]=source[i] or 1 end end
function XC:ApplyAppearance()
    local a=self:Appearance(); local theme=self.Themes[a.theme]
    for key,color in pairs(theme) do if type(color)=="table" then replaceColor(self.Colors[key],color) end end
    local bg=self.ParseHex(a.background); local accent=self.ParseHex(a.accent); local border=self.ParseHex(a.border)
    if bg then replaceColor(self.Colors.bg,bg); for i=1,3 do self.Colors.panel[i]=math.min(1,bg[i]*1.25+.04) end end
    if accent then replaceColor(self.Colors.gold,accent) end
    if border then replaceColor(self.Colors.border,border) end
    -- WoW item rarity still carries its own color; section headings share a restrained accent.
    for _,key in ipairs({"reliable","dungeon","longterm"}) do replaceColor(self.Colors[key],self.Colors.gold) end
    W.ApplyTheme()
    for _,f in ipairs(W.windows) do W.SetWindowScale(f,self:ClampWindowScale(f:GetScale())); f:SaveGeometry() end
    if self.context then self:Render() end
    if self.guide and self.db.activeHunt then self:RenderGuide() end
end
function XC:PickAppearanceColor(key)
    local a=self:Appearance(); local colorKey=key=="background" and "bg" or key=="accent" and "gold" or "border"
    if not ColorPickerFrame then
        local loader=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if loader then pcall(loader,"Blizzard_ColorPicker") end
    end
    local picker=ColorPickerFrame
    if not picker then
        self.appearanceWindow.status:SetText("Enter six hex digits, then press Enter to apply.")
        self.appearanceWindow:ApplyLayout()
        return
    end
    local old=a[key]; local color=self.Colors[colorKey]
    local function changed()
        local r,g,b=picker:GetColorRGB(); a[key]=self.ColorHex({r,g,b}); self:ApplyAppearance()
    end
    local function cancel() a[key]=old; self:ApplyAppearance() end
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({r=color[1],g=color[2],b=color[3],hasOpacity=false,swatchFunc=changed,cancelFunc=cancel})
    else
        picker:Hide(); picker.hasOpacity=false; picker.func=changed; picker.cancelFunc=cancel
        picker:SetColorRGB(color[1],color[2],color[3]); picker:Show()
    end
end
local sections={{"appearance","Appearance"},{"hints","Gear hints"},{"weights","Stat weights"}}
local colorFields={{"background","Background tint"},{"accent","Heading color"},{"border","Border color"}}

local function placeText(text,width,x,y)
    text:SetWidth(width)
    text:SetHeight(0)
    local height=text:GetStringHeight()
    text:SetHeight(height)
    W.Place(text,x,y)
    return y+height
end

local function scaleControl(parent,name,minimum,maximum,callback)
    local slider=CreateFrame("Slider",name,parent,"OptionsSliderTemplate")
    slider:SetHeight(18)
    slider:SetMinMaxValues(minimum,maximum)
    slider:SetValueStep(5)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetScript("OnValueChanged",callback)
    return slider
end

function XC:BuildAppearance()
    if self.appearanceWindow then return end
    self:BuildUI()
    local f=W.Page(self.window,"appearance"); self.appearanceWindow=f
    f.sectionButtons={}
    f.section="appearance"
    for _,section in ipairs(sections) do
        local id,label=section[1],section[2]
        f.sectionButtons[id]=W.Row(f,label,108,29,function() self:SelectAppearanceSection(id) end)
    end
    f.divider=W.Bar(f,self.Colors.border,200,1)
    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("BOTTOMRIGHT",-26,10)
    local body=CreateFrame("Frame",nil,f.scroll)
    body:SetSize(644,1); f.scroll:SetScrollChild(body); f.content=body

    f.views={}
    for _,section in ipairs(sections) do
        local view=CreateFrame("Frame",nil,body)
        view:SetPoint("TOPLEFT",0,0)
        f.views[section[1]]=view
    end

    local appearance=f.views.appearance
    f.colorHeading=W.Text(appearance,"Window colors",15,self.Colors.gold,nil,true)
    f.presets={}
    for _,id in ipairs(self.ThemeOrder) do
        f.presets[id]=W.Row(appearance,self.Themes[id].label,90,28,function()
            local a=self:Appearance()
            if a.theme==id and not (a.background or a.accent or a.border) then return end
            a.theme=id; a.background=nil; a.accent=nil; a.border=nil
            f.status:SetText("")
            self:ApplyAppearance()
        end)
    end
    f.opacityLabel=W.Text(appearance,"",13,self.Colors.text)
    f.opacity=scaleControl(appearance,"UpgradeCrossroadsOpacitySlider",0,100,function(_,value)
        if not f.syncing then self:Appearance().opacity=value/100; self:ApplyAppearance() end
    end)
    W.Hint(f.opacity,"Adjust the frame and panel backgrounds. Text and buttons stay opaque.")
    f.colorFields={}
    for _,entry in ipairs(colorFields) do
        local key,label=entry[1],entry[2]
        local choose=W.Button(appearance,"Choose color",120,29,function() self:PickAppearanceColor(key) end)
        local hex=W.Input(appearance,88,29); hex.edit:SetMaxLetters(7)
        W.Hint(hex.edit,"Type a six-digit hex color and press Enter to apply.")
        local swatch=W.Bar(appearance,self.Colors.gold,25,25)
        hex.edit:SetScript("OnEnterPressed",function(edit)
            local _,value=self.ParseHex(edit:GetText())
            if not value then
                f.status:SetText("Enter six hex digits, such as CCAE69.")
                f:ApplyLayout()
                return
            end
            self:Appearance()[key]=value
            edit:ClearFocus()
            f.status:SetText(label.." saved.")
            self:ApplyAppearance()
        end)
        f.colorFields[key]={input=hex,swatch=swatch,choose=choose,label=W.Text(appearance,label,13,self.Colors.text)}
    end
    f.status=W.Text(appearance,"",12,self.Colors.muted,330)
    f.textHeading=W.Text(appearance,"Text and size",15,self.Colors.gold,nil,true)
    f.font=W.Button(appearance,"",220,29,function()
        local a=self:Appearance()
        a.font=a.font=="classic" and "plain" or "classic"; a.fontChosen=true
        self:ApplyAppearance()
    end)
    f.textSize=W.Button(appearance,"",220,29,function()
        local a=self:Appearance(); a.textBoost=(a.textBoost+1)%3; self:ApplyAppearance()
    end)
    f.readable=W.Toggle(appearance,"Readable scaling",function(v) self:Appearance().readable=v; self:ApplyAppearance() end)
    W.Hint(f.readable,"Keep the text readable when shrinking the window.")
    f.outline=W.Toggle(appearance,"Text outline",function(v) self:Appearance().outline=v; self:ApplyAppearance() end)
    f.scaleLabel=W.Text(appearance,"",13,self.Colors.text)
    f.scaleSlider=scaleControl(appearance,"UpgradeCrossroadsScaleSlider",80,150,function(_,value)
        if not f.syncing then W.SetWindowScale(self.window,self:ClampWindowScale(value/100)); self.window:SaveGeometry() end
    end)
    f.info=W.Text(appearance,"Drag the lower-right corner to scale the whole window. Shift-drag it to resize the layout.",12,self.Colors.muted,330)
    f.reset=W.Button(appearance,"Restore appearance",174,29,function()
        self.db.appearance={}
        f.status:SetText("")
        self:ApplyAppearance()
    end)

    local hints=f.views.hints
    f.upgradeTooltips=W.Toggle(hints,"Compare gear in item tooltips",function(checked)
        self.db.options.upgradeTooltips=checked
        self:RefreshUpgradeHints()
    end)
    f.tooltipHelp=W.Text(hints,"See the equipped comparison and catalog rank where available. Uses your active spec.",13,self.Colors.muted,420)
    f.bagUpgrades=W.Toggle(hints,"Show upgrade markers",function(checked)
        self.db.options.bagUpgrades=checked
        self:RefreshUpgradeHints()
    end)
    f.bagHelp=W.Text(hints,"A green marker flags upgrades in Blizzard bags and on quest rewards.",13,self.Colors.muted,420)
    f.statWeights=self:BuildStatWeightControls(f.views.weights)

    function appearance:Layout(width)
        local column=math.floor((width-60)/2)
        local left,right=16,column+44
        local colorsY=placeText(f.colorHeading,column,left,10)+12
        local styleWidth=math.floor((column-8)/2)
        for i,id in ipairs(XC.ThemeOrder) do
            local preset=f.presets[id]
            W.ResizeButton(preset,styleWidth)
            preset:SetHeight(math.max(28,preset.label:GetStringHeight()+5))
            W.Place(preset,left+(i-1)%2*(styleWidth+8),colorsY+math.floor((i-1)/2)*(preset:GetHeight()+3))
        end
        colorsY=colorsY+f.presets.classic:GetHeight()*2+18
        colorsY=placeText(f.opacityLabel,column,left,colorsY)+7
        f.opacity:SetWidth(column-18); W.Place(f.opacity,left+9,colorsY)
        colorsY=colorsY+32
        for _,entry in ipairs(colorFields) do
            local field=f.colorFields[entry[1]]
            colorsY=placeText(field.label,column,left,colorsY)+4
            W.FitButton(field.choose)
            local inputX=left+field.choose:GetWidth()+16
            W.Place(field.choose,left,colorsY)
            W.Place(field.input,inputX,colorsY)
            W.Place(field.swatch,inputX+field.input:GetWidth()+11,colorsY+2)
            colorsY=colorsY+math.max(field.choose:GetHeight(),field.input:GetHeight())+10
        end
        if f.status:GetText()~="" then
            colorsY=placeText(f.status,column,left,colorsY)+10
        end

        local textY=placeText(f.textHeading,column,right,10)+12
        for _,button in ipairs({f.font,f.textSize}) do
            W.FitButton(button,column)
            W.Place(button,right,textY)
            textY=textY+button:GetHeight()+7
        end
        for _,check in ipairs({f.readable,f.outline}) do
            local rowHeight=math.max(check:GetHeight(),check.label:GetStringHeight()+4)
            W.Place(check,right,textY+(rowHeight-check:GetHeight())*.5)
            textY=textY+rowHeight+6
        end
        textY=placeText(f.scaleLabel,column,right,textY+8)+7
        f.scaleSlider:SetWidth(column-18); W.Place(f.scaleSlider,right+9,textY)
        textY=placeText(f.info,column,right,textY+32)

        local resetY=math.max(colorsY,textY)+8
        W.FitButton(f.reset)
        W.Place(f.reset,left,resetY)
        self:SetHeight(resetY+f.reset:GetHeight()+10)
    end
    function hints:Layout(width)
        local y=10
        for _,row in ipairs({{f.upgradeTooltips,f.tooltipHelp},{f.bagUpgrades,f.bagHelp}}) do
            local check,description=unpack(row)
            local rowHeight=math.max(check:GetHeight(),check.label:GetStringHeight()+4)
            W.Place(check,16,y+(rowHeight-check:GetHeight())*.5)
            y=placeText(description,math.min(580,width-58),42,y+rowHeight+2)+19
        end
        self:SetHeight(y)
    end
    function f.views.weights:Layout(width)
        W.Place(f.statWeights,16,10)
        f.statWeights:Layout(width-32)
        self:SetHeight(f.statWeights:GetHeight()+20)
    end
    function f:Layout(width)
        local x,y,rowHeight=16,0,29
        for _,section in ipairs(sections) do
            local button=self.sectionButtons[section[1]]
            button.label:SetWidth(0)
            W.ResizeButton(button,math.max(108,button.label:GetStringWidth()+23))
            button:SetHeight(math.max(29,button.label:GetStringHeight()+8))
            rowHeight=math.max(rowHeight,button:GetHeight())
            W.Place(button,x,y)
            x=x+button:GetWidth()+6
        end
        self.divider:SetWidth(width-32); W.Place(self.divider,16,rowHeight+6)
        self.scroll:SetPoint("TOPLEFT",0,-rowHeight-15)
        body:SetWidth(width-28)
        for id,view in pairs(self.views) do view:SetShown(id==self.section) end
        local view=self.views[self.section]
        view:SetWidth(body:GetWidth())
        view:Layout(view:GetWidth())
        body:SetHeight(view:GetHeight())
    end
end

function XC:SelectAppearanceSection(section)
    local f=self.appearanceWindow
    if not f or not f.views[section] then return end
    if f.section~=section then
        if f.section=="weights" then f.statWeights:ClearEditFocus() end
        if f.section=="appearance" then
            for _,field in pairs(f.colorFields) do field.input.edit:ClearFocus() end
        end
        f.section=section
        f.scroll:SetVerticalScroll(0)
    end
    self:SyncAppearance()
    f:ApplyLayout()
end

function XC:SyncAppearance()
    local f=self.appearanceWindow; if not f or f.syncing then return end
    local a=self:Appearance(); f.syncing=true
    for id,button in pairs(f.sectionButtons) do W.SelectRow(button,id==f.section) end
    for id,button in pairs(f.presets) do W.SelectRow(button,id==a.theme) end
    f.font.label:SetText(a.font=="classic" and "Font: WoW standard  >" or "Font: Plain  >")
    f.opacityLabel:SetText("Background opacity: "..math.floor(a.opacity*100+.5).."%")
    f.opacity:SetValue(a.opacity*100)
    f.readable:SetChecked(a.readable); f.outline:SetChecked(a.outline)
    f.upgradeTooltips:SetChecked(self.db.options.upgradeTooltips)
    f.bagUpgrades:SetChecked(self.db.options.bagUpgrades)
    f.statWeights:Sync()
    f.textSize.label:SetText(("Text size: %s  >"):format(({"Normal","Larger","Largest"})[a.textBoost+1]))
    for key,field in pairs(f.colorFields) do
        local color=self.Colors[key=="background" and "bg" or key=="accent" and "gold" or "border"]
        if not field.input.edit:HasFocus() then field.input.edit:SetText(self.ColorHex(color)) end
        field.swatch:SetColorTexture(unpack(color))
    end
    f.scaleLabel:SetText("Planner scale: "..math.floor(self.window:GetScale()*100+.5).."%")
    f.scaleSlider:SetMinMaxValues(a.readable and 80 or 50,150); f.scaleSlider:SetValue(self.window:GetScale()*100)
    f.syncing=nil
end

function XC:ShowAppearance(section)
    self:ShowPage("appearance")
    if section then self:SelectAppearanceSection(section) end
end
