local _, XC = ...
local W = XC.W
local groups = {
    {"Attributes", {{"str","Strength"},{"agi","Agility"},{"sta","Stamina"},{"int","Intellect"},{"spi","Spirit"},{"mpr","MP5","Mana per 5 seconds"}}},
    {"Offense / healing", {{"sp","Spell power"},{"heal","Healing"},{"ap","Attack power","Melee attack power"},{"rap","Ranged AP","Ranged attack power"},{"dps","Weapon DPS"},{"crit","Crit","Critical strike chance"},{"hit","Hit","Hit chance"}}},
    {"Defense", {{"armor","Armor"},{"def","Defense"},{"dodge","Dodge"},{"parry","Parry"},{"block","Block"}}},
}
local allowed = {}
for _,group in ipairs(groups) do
    for _,stat in ipairs(group[2]) do allowed[stat[1]]=true end
end

local function parseValue(number)
    if number:match("^-?[%d.]+$") or number:match("^-?[%d.]+[eE][+-]?%d+$") then
        local value=tonumber(number)
        if value and value >= 0 and value <= 1000 then return value end
    end
end

function XC:StatWeightText()
    local profile = self:GetProfile(self.db.profile)
    local weights = {}
    for stat, weight in pairs(profile.weights) do weights[#weights+1] = stat.."="..weight end
    table.sort(weights)
    return table.concat(weights, " ")
end

local function saveWeights(profile,updates)
    local weights
    if updates then
        weights = {}
        for stat, weight in pairs(profile.weights) do weights[stat] = weight end
        for stat, weight in pairs(updates) do weights[stat] = weight end
    end
    XC.db.weights[profile.id] = weights
    XC:Refresh()
    XC:RefreshUpgradeHints()
    if XC.appearanceWindow then XC.appearanceWindow.statWeights:Sync() end
    return true, (updates and "Saved " or "Restored ")..profile.label.." weights."
end

function XC:ApplyStatWeights(text)
    local profile = self:GetProfile(self.db.profile)
    text = text:match("^%s*(.-)%s*$")
    if text == "reset" then return saveWeights(profile) end
    if text == "" then return false, "Enter at least one weight, such as str=1." end
    local updates = {}
    for token in text:gmatch("%S+") do
        local stat, number = token:match("^(%a+)=([^%s]+)$")
        local value = number and parseValue(number)
        if not allowed[stat] or value==nil then
            return false, "Invalid weight: "..token..". Example: /uc weights str=1 agi=0.8 sta=0.25"
        end
        updates[stat] = value
    end
    return saveWeights(profile,updates)
end

function XC:BuildStatWeightControls(parent)
    local editor=CreateFrame("Frame",nil,parent)
    editor.heading=W.Text(editor,"",15,self.Colors.gold,420,true)
    editor.instructions=W.Text(editor,"Use 0 to ignore a stat. Values apply to the active spec in Journal, tooltips and upgrade markers.",13,self.Colors.muted,420)
    editor.status=W.Text(editor,"",13,self.Colors.muted,420)
    editor.fields={}
    editor.groups={}

    local function showStatus(message)
        editor.status:SetText(message or "")
        XC.appearanceWindow:ApplyLayout()
    end
    local function submit(reset)
        local profile=XC:GetProfile(XC.db.profile)
        if editor.profileID~=profile.id then editor:Sync(); return end
        local updates=nil
        if not reset then
            updates={}
            for _,group in ipairs(groups) do
                for _,stat in ipairs(group[2]) do
                    local id,label=unpack(stat)
                    local value=parseValue(editor.fields[id].edit:GetText():match("^%s*(.-)%s*$"))
                    if value==nil then
                        showStatus("Invalid weight for "..label..". Enter a number from 0 to 1000.")
                        return
                    end
                    if value~=(profile.weights[id] or 0) then
                        updates[id]=value
                    end
                end
            end
            if not next(updates) then showStatus("No changes to save."); return end
        end
        local _,message=saveWeights(profile,updates)
        editor:ClearEditFocus()
        showStatus(message)
    end

    for _,group in ipairs(groups) do
        local column={title=W.Text(editor,group[1],14,self.Colors.gold,nil,true),stats=group[2]}
        editor.groups[#editor.groups+1]=column
        for _,stat in ipairs(group[2]) do
            local id,label,detail=unpack(stat)
            local input=W.Input(editor,76,28)
            input.edit:SetMaxLetters(26)
            input.edit:SetScript("OnEnterPressed",function() submit(false) end)
            if detail then W.Hint(input.edit,detail) end
            input.label=W.Text(editor,label,13,self.Colors.text,130)
            editor.fields[id]=input
        end
    end
    editor.save=W.Button(editor,"Save weights",116,30,function() submit(false) end)
    editor.reset=W.Button(editor,"Restore defaults",132,30,function() submit(true) end)

    function editor:ClearEditFocus()
        for _,input in pairs(self.fields) do input.edit:ClearFocus() end
    end
    function editor:Sync()
        local profile=XC:GetProfile(XC.db.profile)
        self.heading:SetText(profile.label)
        if self.profileID~=profile.id then
            self.status:SetText("")
            self:ClearEditFocus()
        end
        if self.profileID~=profile.id or self.weights~=profile.weights then
            for id,input in pairs(self.fields) do input.edit:SetText(profile.weights[id] or 0) end
        end
        self.profileID,self.weights=profile.id,profile.weights
    end
    function editor:Layout(width)
        self:SetWidth(width)
        local y=0
        for _,line in ipairs({self.heading,self.instructions}) do
            line:SetWidth(width)
            line:SetHeight(0)
            W.Place(line,0,y)
            y=y+line:GetStringHeight()+8
        end
        y=y+10
        local columnWidth=math.floor((width-32)/#self.groups)
        local gridEnd=y
        for i,column in ipairs(self.groups) do
            local x=(i-1)*(columnWidth+16)
            column.title:SetWidth(columnWidth); column.title:SetHeight(0)
            W.Place(column.title,x,y)
            local rowY=y+column.title:GetStringHeight()+7
            for _,stat in ipairs(column.stats) do
                local input=self.fields[stat[1]]
                input.label:SetWidth(columnWidth-90); input.label:SetHeight(0)
                local height=math.max(input:GetHeight(),input.label:GetStringHeight())
                W.Place(input.label,x,rowY+math.max(0,(height-input.label:GetStringHeight())*.5))
                W.Place(input,x+columnWidth-input:GetWidth(),rowY)
                rowY=rowY+height+5
            end
            gridEnd=math.max(gridEnd,rowY)
        end
        local buttonsY=gridEnd+9
        W.FitButton(self.save); W.FitButton(self.reset)
        W.Place(self.save,0,buttonsY)
        W.Place(self.reset,self.save:GetWidth()+8,buttonsY)
        local statusY=buttonsY+math.max(self.save:GetHeight(),self.reset:GetHeight())+8
        self.status:SetWidth(width); self.status:SetHeight(0)
        W.Place(self.status,0,statusY)
        self:SetHeight(statusY+(self.status:GetText()~="" and self.status:GetStringHeight() or 0))
    end
    editor:Sync()
    return editor
end
