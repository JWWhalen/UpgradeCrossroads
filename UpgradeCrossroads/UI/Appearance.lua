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
    if a.font~="classic" then a.font="plain" end
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
    if self.window then self:LayoutPages() end
    if self.appearanceWindow then self:SyncAppearance() end
end
function XC:PickAppearanceColor(key)
    local a=self:Appearance(); local colorKey=key=="background" and "bg" or key=="accent" and "gold" or "border"
    if not ColorPickerFrame then
        local loader=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if loader then pcall(loader,"Blizzard_ColorPicker") end
    end
    local picker=ColorPickerFrame
    if not picker then self.appearanceWindow.status:SetText("Enter six HEX digits, then press Enter to apply."); return end
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
function XC:BuildAppearance()
    if self.appearanceWindow then return end
    self:BuildUI()
    local f=W.Page(self.window,"appearance"); self.appearanceWindow=f
    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT",0,-10); f.scroll:SetPoint("BOTTOMRIGHT",-26,10)
    local body=CreateFrame("Frame",nil,f.scroll); body:SetSize(644,600); f.scroll:SetScrollChild(body); f.content=body
    W.Place(W.Text(body,"Window style",13,self.Colors.gold),28,8)
    f.preset=W.Place(W.Button(body,"",240,30,function()
        local a=self:Appearance(); local index=1
        for i,id in ipairs(self.ThemeOrder) do if id==a.theme then index=i end end
        a.theme=self.ThemeOrder[index%#self.ThemeOrder+1]; a.background=nil; a.accent=nil; a.border=nil; self:ApplyAppearance()
    end),28,31)
    W.Place(W.Text(body,"Font",13,self.Colors.gold),330,8)
    f.font=W.Place(W.Button(body,"",280,30,function() local a=self:Appearance(); a.font=a.font=="classic" and "plain" or "classic"; self:ApplyAppearance() end),330,31)
    f.opacityLabel=W.Place(W.Text(body,"",13,self.Colors.gold),28,81)
    local slider=CreateFrame("Slider","UpgradeCrossroadsOpacitySlider",body,"OptionsSliderTemplate"); f.opacity=slider
    W.Place(slider,36,112); slider:SetSize(566,18); slider:SetMinMaxValues(0,100); slider:SetValueStep(5)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local low=slider.Low or _G.UpgradeCrossroadsOpacitySliderLow
    local high=slider.High or _G.UpgradeCrossroadsOpacitySliderHigh
    if low then low:SetText("Transparent"); W.RegisterFont(low,slider,11,self.Colors.muted) end
    if high then high:SetText("Opaque"); W.RegisterFont(high,slider,11,self.Colors.muted) end
    slider:SetScript("OnValueChanged",function(_,value) if not f.syncing then self:Appearance().opacity=value/100; self:ApplyAppearance() end end)
    f.colorFields={}
    for i,entry in ipairs({{"background","Background tint"},{"accent","Accent / headings"},{"border","Frame border"}}) do
        local key,label=entry[1],entry[2]; local y=165+(i-1)*46
        W.Place(W.Text(body,label,13,self.Colors.text),28,y+7)
        local choose=W.Place(W.Button(body,"Choose color",132,30,function() self:PickAppearanceColor(key) end),230,y)
        local hex=W.Place(W.Input(body,106,30),378,y); hex.edit:SetMaxLetters(7)
        local swatch=W.Bar(body,self.Colors.gold,28,28); W.Place(swatch,505,y+1)
        hex.edit:SetScript("OnEnterPressed",function(edit)
            local _,value=self.ParseHex(edit:GetText())
            if not value then f.status:SetText("Use six HEX digits, for example CCAE69."); return end
            self:Appearance()[key]=value; edit:ClearFocus(); f.status:SetText("Appearance saved."); self:ApplyAppearance()
        end)
        f.colorFields[key]={input=hex,swatch=swatch,choose=choose,y=y}
    end
    f.readable=W.Place(W.Toggle(body,"Readable scaling",function(v) self:Appearance().readable=v; self:ApplyAppearance() end),25,315)
    f.textSize=W.Place(W.Button(body,"",280,28,function() local a=self:Appearance(); a.textBoost=(a.textBoost+1)%3; self:ApplyAppearance() end),330,315)
    f.outline=W.Place(W.Toggle(body,"Text outline",function(v) self:Appearance().outline=v; self:ApplyAppearance() end),25,355)
    f.info=W.Place(W.Text(body,"Keep labels readable while shrinking the window. Shift-drag the corner to change layout space without shrinking text. Turn this off only if you prefer very small UI.",12,self.Colors.muted,580),28,398)
    f.status=W.Place(W.Text(body,"Background opacity changes panels only; text and controls stay opaque.",12,self.Colors.muted,580),28,474); f.status:SetHeight(36)
    f.scaleLabel=W.Place(W.Text(body,"",13,self.Colors.text),28,430)
    f.scaleSlider=CreateFrame("Slider","UpgradeCrossroadsScaleSlider",body,"OptionsSliderTemplate")
    W.Place(f.scaleSlider,36,464); f.scaleSlider:SetSize(566,18); f.scaleSlider:SetMinMaxValues(80,150); f.scaleSlider:SetValueStep(5)
    if f.scaleSlider.SetObeyStepOnDrag then f.scaleSlider:SetObeyStepOnDrag(true) end
    f.scaleSlider:SetScript("OnValueChanged",function(_,value)
        if not f.syncing then W.SetWindowScale(self.window,self:ClampWindowScale(value/100)); self.window:SaveGeometry() end
    end)
    f.reset=W.Place(W.Button(body,"Restore appearance",200,30,function() self.db.appearance={}; self:ApplyAppearance() end),28,600)
    f.Layout=function(_,width)
        body:SetWidth(width-28)
        for _,field in pairs(f.colorFields) do
            local x=math.max(378,230+field.choose:GetWidth()+16)
            W.Place(field.input,x,field.y); W.Place(field.swatch,x+122,field.y+1)
        end
        f.info:SetWidth(width-100); f.info:SetHeight(0); local h=f.info:GetStringHeight(); f.info:SetHeight(h)
        f.status:SetWidth(width-100); f.status:SetHeight(0); local sh=f.status:GetStringHeight(); f.status:SetHeight(sh)
        W.Place(f.scaleLabel,28,416+h); W.Place(f.scaleSlider,36,448+h); W.Place(f.status,28,494+h); W.Place(f.reset,28,510+h+sh); body:SetHeight(555+h+sh)
    end
end
function XC:SyncAppearance()
    local f=self.appearanceWindow; if not f then return end
    local a=self:Appearance(); f.syncing=true
    f.preset.label:SetText(self.Themes[a.theme].label.."  >")
    f.font.label:SetText(a.font=="classic" and "WoW fantasy font  >" or "Plain readable font  >")
    f.opacityLabel:SetText("Background opacity: "..math.floor(a.opacity*100+.5).."%")
    f.opacity:SetValue(a.opacity*100)
    f.readable:SetChecked(a.readable); f.outline:SetChecked(a.outline)
    f.textSize.label:SetText(({"Text size: Normal  >","Text size: Larger  >","Text size: Largest  >"})[a.textBoost+1])
    for key,field in pairs(f.colorFields) do
        local color=self.Colors[key=="background" and "bg" or key=="accent" and "gold" or "border"]
        if not field.input.edit:HasFocus() then field.input.edit:SetText(self.ColorHex(color)) end
        field.swatch:SetColorTexture(unpack(color))
    end
    f.scaleLabel:SetText("Window scale: "..math.floor(self.window:GetScale()*100+.5).."%")
    f.scaleSlider:SetMinMaxValues(a.readable and 80 or 50,150); f.scaleSlider:SetValue(self.window:GetScale()*100)
    f.syncing=nil
end
function XC:ShowAppearance() self:ShowPage("appearance") end
