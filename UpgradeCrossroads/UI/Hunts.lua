local _, XC = ...
local W=XC.W
local at=W.Place

local function resetScroll(scroll)
    if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
end

local function layoutText(text,width,x,y)
    text:SetWidth(width)
    text:SetHeight(0)
    local height=text:GetStringHeight()
    text:SetHeight(height)
    at(text,x,y)
    return height
end

function XC:BuildHunts()
    local f=W.Page(self.window,"hunts")
    self.huntWindow=f
    W.ThemedPage(f)

    f.searchLabel=W.JournalText(f,"Find a hunt",12,nil,true)
    f.search=W.PaperInput(f,245,26)
    f.query=""
    f.search.edit:SetScript("OnTextChanged",function(edit,user)
        if not user then return end
        f.query=edit:GetText():lower():match("^%s*(.-)%s*$")
        resetScroll(f.scroll)
        self:RenderHunts()
    end)
    f.search.edit:SetScript("OnEnterPressed",function(edit) edit:ClearFocus() end)
    W.Hint(f.search,"Search saved items, source names, zones and your notes.")
    f.hideObtained=W.Toggle(f,"Hide obtained",function(value)
        self.db.hideObtained=value
        resetScroll(f.scroll)
        self:RenderHunts()
    end)
    W.Paperize(f.hideObtained.label)
    f.summary=W.JournalText(f,"",12,nil,true)
    f.empty=W.JournalText(f,"",14,700)
    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT",12,-78)
    f.scroll:SetPoint("BOTTOMRIGHT",-30,12)
    f.child=CreateFrame("Frame",nil,f.scroll)
    f.child:SetSize(786,430)
    f.scroll:SetScrollChild(f.child)
    f.rows={}
    function f:LayoutHeader(width)
        self.child:SetWidth(width-44)
        self.empty:SetWidth(width-42)
        local searchX=18+self.searchLabel:GetStringWidth()+12
        local fieldWidth=math.min(300,width-searchX-218)
        self.search:SetWidth(fieldWidth)
        local lineHeight=math.max(self.searchLabel:GetStringHeight(),self.search:GetHeight(),self.hideObtained.label:GetStringHeight())
        at(self.searchLabel,18,12+(lineHeight-self.searchLabel:GetStringHeight())/2)
        at(self.search,searchX,12+(lineHeight-self.search:GetHeight())/2)
        at(self.hideObtained,searchX+fieldWidth+10,12+(lineHeight-24)/2)
        local summaryY=12+lineHeight+8
        local summaryHeight=layoutText(self.summary,width-36,18,summaryY)
        local contentTop=summaryY+summaryHeight+8
        self.scroll:SetPoint("TOPLEFT",12,-contentTop)
        at(self.empty,18,contentTop+14)
    end
    function f:Layout(width)
        if self:IsShown() then XC:RenderHunts() else self:LayoutHeader(width) end
    end
end

function XC:ShowHunts() self:ShowPage("hunts") end

local function createRow(parent)
    local r=W.PaperPanel(parent)
    r.icon=CreateFrame("Button",nil,r)
    r.icon:SetSize(32,32)
    at(r.icon,16,16)
    r.icon.texture=r.icon:CreateTexture(nil,"ARTWORK")
    r.icon.texture:SetAllPoints(r.icon)
    r.icon:RegisterForClicks("LeftButtonUp","RightButtonUp")
    r.name=W.JournalText(r,"",16,500,true)
    r.itemButton=CreateFrame("Button",nil,r)
    r.itemButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    r.progress=W.JournalText(r,"",11,500,true)
    r.source=W.JournalText(r,"",12,500)
    r.map=W.Button(r,"Track",80,27)
    r.chat=W.Button(r,"Chat",80,24)
    r.remove=W.Button(r,"Unsave",80,24)
    W.Hint(r.remove,"Delete this saved hunt and its notes. Use Remove in Journal to keep notes for restoration.")
    r.checks={}
    for i=1,3 do
        local check=W.Toggle(r,"",function(value)
            local pin=r.pin
            if not pin or pin.acquired then return end
            pin.checks=pin.checks or {}
            pin.checks[i]=value
            XC:RenderHunts()
            XC:RenderGuide()
        end)
        W.Paperize(check.label)
        check.label:SetWordWrap(true)
        r.checks[i]=check
    end
    r.notesLabel=W.JournalText(r,"Notes",11,nil,true)
    r.noteInput=W.PaperInput(r,740,26)
    r.noteInput.edit:SetScript("OnTextChanged",function(edit,user)
        if user and r.pin then r.pin.notes=edit:GetText() end
    end)
    r.noteInput.edit:SetScript("OnEditFocusLost",function()
        if XC.huntWindow:IsShown() and XC.huntWindow.query~="" then XC:RenderHunts() end
    end)
    r.noteInput.edit:SetScript("OnEnterPressed",function(edit) edit:ClearFocus() end)
    W.Hint(r.noteInput,"Your notes save automatically.")
    return r
end

local function layoutRow(r,width,y)
    at(r,0,y)
    r:SetWidth(width)
    local actionWidth=0
    for _,button in ipairs({r.map,r.chat,r.remove}) do
        W.FitButton(button,80)
        actionWidth=math.max(actionWidth,button:GetWidth())
    end
    local actionX=width-16-actionWidth
    local actionY=16
    for _,button in ipairs({r.map,r.chat,r.remove}) do
        W.FitButton(button,actionWidth)
        at(button,actionX,actionY)
        actionY=actionY+button:GetHeight()+7
    end
    local textX=58
    local titleWidth=actionX-textX-12
    local titleHeight=layoutText(r.name,titleWidth,textX,16)
    r.itemButton:SetSize(titleWidth,titleHeight)
    at(r.itemButton,textX,16)
    local progressY=16+titleHeight+4
    local progressHeight=layoutText(r.progress,titleWidth,textX,progressY)
    local sourceY=math.max(56,progressY+progressHeight+10)
    local sourceHeight=layoutText(r.source,actionX-32,16,sourceY)
    local checkY=math.max(sourceY+sourceHeight+10,actionY)
    for _,check in ipairs(r.checks) do
        check.label:SetWidth(width-68)
        check.label:SetHeight(0)
        local height=math.max(24,check.label:GetStringHeight()+4)
        check.label:SetHeight(height)
        at(check,13,checkY)
        checkY=checkY+height+3
    end
    local noteY=checkY+3+layoutText(r.notesLabel,width-32,16,checkY+3)+8
    r.noteInput:SetWidth(width-32)
    at(r.noteInput,16,noteY)
    r:SetHeight(noteY+r.noteInput:GetHeight()+14)
end

function XC:RenderHunts()
    local f=self.huntWindow
    if not f or f.rendering then return end
    f.rendering=true
    local pins={}
    local obtained,open=0,0
    local active=self.db.activeHunt
    for key,pin in pairs(self.db.pins) do
        if pin.acquired then obtained=obtained+1 else open=open+1 end
        local source=self:SourceText(pin.source)
        local text=pin.item.name.." "..source.." "..(pin.notes or "")
        if not (self.db.hideObtained and pin.acquired) and (f.query=="" or text:lower():find(f.query,1,true)) then
            pins[#pins+1]={key=key,pin=pin,source=source}
        end
    end
    table.sort(pins,function(a,b)
        if (a.key==active)~=(b.key==active) then return a.key==active end
        if (not a.pin.acquired)~=(not b.pin.acquired) then return not a.pin.acquired end
        if (a.pin.order or 0)~=(b.pin.order or 0) then return (a.pin.order or 0)<(b.pin.order or 0) end
        return a.key<b.key
    end)
    local summary=string.format("%d open  /  %d obtained",open,obtained)
    if #pins<open+obtained then summary=summary..string.format("  /  %d shown",#pins) end
    f.summary:SetText(summary)
    f.hideObtained:SetChecked(self.db.hideObtained)
    local emptyText="Track an item in the Journal to start a hunt."
    if f.query~="" then emptyText="No saved hunts match your search."
    elseif obtained>0 and open==0 then emptyText="All saved hunts are obtained. Turn off Hide obtained to view them." end
    f.empty:SetText(emptyText)
    f.empty:SetShown(#pins==0)
    f:LayoutHeader(f:GetWidth())
    f.empty:SetHeight(0)
    f.empty:SetHeight(f.empty:GetStringHeight())

    local width=f.child:GetWidth()
    local y=0
    for i,entry in ipairs(pins) do
        local key,pin=entry.key,entry.pin
        local r=f.rows[i]
        if not r then r=createRow(f.child); f.rows[i]=r end
        if r.pin~=pin then r.noteInput.edit:ClearFocus() end
        r.pin=pin
        r:Show()
        local name,texture=self.Client.Presentation(pin.item)
        r.name:SetText(name)
        r.icon.texture:SetTexture(texture)
        r.source:SetText(entry.source)
        local tasks,_,done=self:HuntChecklist(pin)
        local isActive=key==active
        local label=isActive and "Tracking" or "Saved"
        if pin.acquired then
            r.progress:SetText("Obtained")
        else
            r.progress:SetText(string.format("%s  /  %d/%d steps",label,done,#tasks))
        end
        for j,check in ipairs(r.checks) do
            check.label:SetText(tasks[j])
            check:SetChecked(pin.acquired or (pin.checks and pin.checks[j]) or false)
            check:SetEnabled(not pin.acquired)
        end
        r.remove:SetScript("OnClick",function()
            if XC.db.activeHunt==key then XC:StopHunt() end
            XC.db.pins[key]=nil
            XC:Refresh()
        end)
        local function openTracker()
            if XC.db.activeHunt==key then
                if InCombatLockdown() then XC:Print("Open the tracker after combat."); return end
                XC.db.trackerHidden=nil
                XC.window:Hide()
                XC:RenderGuide()
            else
                XC:TrackItem({item=pin.item,source=pin.source},pin.lane,false)
            end
        end
        r.map.label:SetText(isActive and "Open tracker" or "Track")
        r.map:SetScript("OnClick",openTracker)
        r.chat:SetScript("OnClick",function() XC:LinkItem(pin.item) end)
        for _,button in ipairs({r.itemButton,r.icon}) do
            W.Tooltip(button,pin.item,isActive and "Click: open tracker / Shift-click or right-click: chat" or nil)
            button:SetScript("OnClick",function(_,mouseButton) W.ItemClick(pin.item,openTracker,mouseButton) end)
        end
        if not r.noteInput.edit:HasFocus() then r.noteInput.edit:SetText(pin.notes or "") end
        layoutRow(r,width,y)
        y=y+r:GetHeight()+10
    end
    for i=#pins+1,#f.rows do
        local r=f.rows[i]
        r.noteInput.edit:ClearFocus()
        r.pin=nil
        r:Hide()
    end
    f.child:SetHeight(math.max(1,y))
    f.rendering=nil
end
