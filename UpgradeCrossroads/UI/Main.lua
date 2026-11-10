local _, XC = ...
local W=XC.W
local at=W.Place
local laneOrder={"reliable","dungeon","longterm"}
local titles={reliable="Quest & craft",dungeon="Dungeons",longterm="Future gear"}
local summaries={reliable="Quest rewards and crafts. Choose an item to inspect its source.",dungeon="Group content at your level. Choose an item to plan your next run.",longterm="Future gear goals. Scores are estimates, not a verified BiS list."}
local empty={reliable="No matching upgrade. Try another slot or filter.",dungeon="No matching dungeon upgrade. Solo excludes group content.",longterm="No matching future target. Try another slot or add an item."}
local captions={gear="Compare equipment and choose your next goal.",hunts="Your saved goals, preparation checklists and notes.",appearance="Customize colors, opacity, text and window scale.",help="Controls, scoring and source information.",editor="Add an item or correct its source location."}
local function hideRows(t) for _,r in ipairs(t or {}) do r:Hide() end end
function W.Page(owner,id)
    local f=CreateFrame("Frame",nil,owner.pageHost)
    owner.pages[id]=f; f.pageID=id; f:Hide(); f:SetPoint("TOPLEFT",0,0)
    f:SetSize(owner.pageHost:GetWidth(),owner.pageHost:GetHeight())
    f.ApplyLayout=function() if f.Layout then f:Layout(f:GetWidth(),f:GetHeight()) end end
    f:SetScript("OnSizeChanged",f.ApplyLayout)
    return f
end
function XC:ShowPage(id)
    self:BuildUI()
    if id=="appearance" then self:BuildAppearance() end
    local f=self.window; if not f.pages[id] then return end
    f.activePage=id
    for key,page in pairs(f.pages) do page:SetShown(key==id) end
    for key,b in pairs(f.nav) do W.SelectRow(b,key==id) end
    f.description:SetText(captions[id] or "")
    f:Show(); if f.Raise then f:Raise() end; self:LayoutPages()
    if id=="hunts" then self:RenderHunts() end
    if id=="appearance" then self:SyncAppearance() end
    self:RenderGuide()
end
function XC:LayoutNavigation()
    local f=self.window; local x=22
    for _,id in ipairs({"gear","hunts","appearance","help","editor"}) do
        local b=f.nav[id]; b.label:SetWidth(0)
        local width=math.max(104,b.label:GetStringWidth()+32)
        b:SetWidth(width); b.label:SetWidth(width-16); at(b,x,91); x=x+width+8
        W.SelectRow(b,id==f.activePage)
    end
end
function XC:LayoutPages()
    local f=self.window; if not f then return end
    f.pageHost:SetSize(f:GetWidth()-36,f:GetHeight()-154)
    for _,page in pairs(f.pages) do page:SetSize(f.pageHost:GetWidth(),f.pageHost:GetHeight()); page:ApplyLayout() end
end
function XC:SelectPath(key) self.db.path=key; self:Render() end
function XC:SetFactionFilter(mode)
    if not self.Rules.FactionLabels[mode] then return end
    self.db.options.faction=mode; self.selection={}; self.sourceSelection={}
    self:Refresh()
end
function XC:CycleFactionFilter()
    local current=self.Rules.FactionMode(self.db.options,self.context); local index=1
    for i,id in ipairs(self.Rules.FactionOrder) do if id==current then index=i end end
    self:SetFactionFilter(self.Rules.FactionOrder[index%#self.Rules.FactionOrder+1])
end
function XC:BuildUI()
    if self.window then return end
    local f=W.Panel(UIParent,1040,780,self.Colors.bg); self.window=f
    f:SetPoint("CENTER"); f:SetFrameStrata("HIGH"); f:Hide()
    f:SetScale(math.min(1,(GetScreenWidth()-40)/1040,(GetScreenHeight()-40)/780))
    f.title=at(W.Text(f,"Upgrade Crossroads",20,self.Colors.gold,nil,true),60,18)
    f.description=at(W.Text(f,captions.gear,13,self.Colors.muted,930),22,58)
    f.pages={}; f.nav={}; self.selection={}
    for i,entry in ipairs({{"gear","Gear"},{"hunts","Hunts"},{"appearance","Settings"},{"help","Help"},{"editor","Add item"}}) do
        local id,label=entry[1],entry[2]
        local b=W.Row(f,label,130,30,function() if id=="editor" then XC:ShowTargetEditor() else XC:ShowPage(id) end end)
        f.nav[id]=b; at(b,22+(i-1)*140,91)
    end
    f.hunts=f.nav.hunts; f.appearance=f.nav.appearance; f.help=f.nav.help; f.add=f.nav.editor
    f.divider=at(W.Bar(f,self.Colors.border,996,1),22,126)
    f.pageHost=CreateFrame("Frame",nil,f); at(f.pageHost,18,135); f.pageHost:SetSize(1004,626)
    f.catalog=W.Text(f,"v"..self.version.."  |  Data: "..self.CatalogMeta.date,12,self.Colors.muted)
    self:BuildGear(); self:BuildHunts(); self:BuildAbout()
    W.Resizable(f,"planner",900,720,function(_,width,height)
        f.divider:SetWidth(width-44); at(f.catalog,22,height-22)
        XC:LayoutNavigation()
        XC:LayoutPages()
    end)
    f:HookScript("OnShow",function() XC:Refresh(); XC:RenderGuide() end)
    _G.UpgradeCrossroadsWindow=f
    f.activePage="gear"; f.pages.gear:Show()
end
function XC:BuildGear()
    local f=self.window; local p=W.Page(f,"gear"); f.gearPage=p
    at(W.Text(p,"Equipment",14,self.Colors.gold,nil,true),8,8)
    local slotScroll=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate"); p.slotScroll=slotScroll
    slotScroll:SetPoint("TOPLEFT",4,-38); slotScroll:SetPoint("BOTTOMLEFT",4,10); slotScroll:SetWidth(140)
    local slotList=CreateFrame("Frame",nil,slotScroll); slotList:SetSize(138,550); slotScroll:SetScrollChild(slotList); p.slotList=slotList
    f.slots={}
    for i,slot in ipairs(self.Slots) do
        f.slots[slot.id]=at(W.Row(slotList,slot.label,136,29,function() XC.db.slot=slot.id; XC.selection={}; XC:Refresh() end),0,(i-1)*31)
    end
    f.classLabel=at(W.Text(p,"",14,self.Colors.gold,nil,true),170,8)
    f.profile=at(W.Button(p,"",230,30,function() XC:CycleProfile() end),170,40)
    f.profileBasis=at(W.Text(p,"",12,self.Colors.muted,300),420,49)
    W.Hint(f.profile,"Choose a specialization for your class. These are editable role-based estimates, not simulated BiS rankings. /uc weights customizes this spec.")
    f.solo=W.Toggle(p,"Solo",function(v) XC.db.options.solo=v; XC.selection={}; XC:Refresh() end)
    f.craft=W.Toggle(p,"Crafts",function(v) XC.db.options.crafted=v; XC.selection={}; XC:Refresh() end)
    f.auction=W.Toggle(p,"AH",function(v) XC.db.options.auction=v; XC.selection={}; XC:Refresh() end)
    W.Hint(f.solo,"Exclude known group content."); W.Hint(f.craft,"Allow crafted items."); W.Hint(f.auction,"Allow personal auction targets; no live price scan.")
    f.faction=W.Button(p,"",190,30,function() XC:CycleFactionFilter() end)
    W.Hint(f.faction,"Cycle Alliance, Horde or Both. Shared sources stay visible. Other-faction sources are labeled; class, level and other filters still apply.")
    local current=W.Panel(p,824,87,self.Colors.panel); f.current=current; at(current,170,87)
    current.icon=current:CreateTexture(nil,"ARTWORK"); current.icon:SetSize(38,38); at(current.icon,12,23)
    at(W.Text(current,"Equipped",12,self.Colors.muted),64,12)
    current.name=at(W.Text(current,"",14,self.Colors.text,520),64,32)
    current.stats=at(W.Text(current,"",12,self.Colors.muted,520),64,55)
    current.score=W.Text(current,"",13,self.Colors.gold,120); current.score:SetJustifyH("RIGHT")
    current.chat=W.Button(current,"Chat",62,28,function() XC:LinkItem(XC.baseline) end)
    at(W.Text(p,"Search",13,self.Colors.muted),170,195)
    f.search=at(W.Input(p,350,30),235,185)
    f.search.edit:SetScript("OnTextChanged",function(edit,user) if user then XC.search=edit:GetText(); XC.selection={}; XC:Refresh() end end)
    f.search.edit:SetScript("OnEnterPressed",function(edit) edit:ClearFocus() end)
    W.Hint(f.search,"Item, boss, quest or zone names within this slot.")
    f.clearSearch=W.Button(p,"Clear",70,30,function() XC.search=""; f.search.edit:SetText(""); XC.selection={}; XC:Refresh() end)
    f.tabs={}; f.lanes={}
    for i,key in ipairs(laneOrder) do
        f.tabs[key]=at(W.Row(p,titles[key],145,30,function() XC:SelectPath(key) end),170+(i-1)*151,229)
        local c=W.Panel(p,824,350,self.Colors.panel); f.lanes[key]=c; at(c,170,267)
        c.summary=at(W.Text(c,summaries[key],12,self.Colors.muted,790),14,14)
        c.listScroll=CreateFrame("ScrollFrame",nil,c,"UIPanelScrollFrameTemplate"); c.listScroll:SetPoint("TOPLEFT",12,-55); c.listScroll:SetPoint("BOTTOMLEFT",12,46); c.listScroll:SetWidth(208)
        c.list=CreateFrame("Frame",nil,c.listScroll); c.list:SetSize(204,400); c.listScroll:SetScrollChild(c.list); c.items={}
        for j=1,8 do
            local b=W.Row(c.list,"",200,34); c.items[j]=b; b.label:SetWordWrap(true); b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        end
        c.detailScroll=CreateFrame("ScrollFrame",nil,c,"UIPanelScrollFrameTemplate"); c.detailScroll:SetPoint("TOPLEFT",254,-55); c.detailScroll:SetPoint("BOTTOMRIGHT",-30,104)
        c.detail=CreateFrame("Frame",nil,c.detailScroll); c.detail:SetSize(540,330); c.detailScroll:SetScrollChild(c.detail)
        c.iconButton=CreateFrame("Button",nil,c.detail); c.iconButton:SetSize(42,42); at(c.iconButton,0,0)
        c.icon=c.iconButton:CreateTexture(nil,"ARTWORK"); c.icon:SetAllPoints()
        c.name=at(W.Text(c.detail,"",16,self.Colors.text,480),56,0)
        c.itemButton=CreateFrame("Button",nil,c.detail); at(c.itemButton,0,0); c.itemButton:SetSize(530,50)
        c.itemButton:RegisterForClicks("LeftButtonUp","RightButtonUp"); c.iconButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
        c.score=W.Text(c.detail,"",16,self.Colors.gold,530)
        c.stats=W.Text(c.detail,"",13,self.Colors.text,530)
        c.source=W.Text(c.detail,"",13,self.Colors.text,530)
        c.available=W.Text(c.detail,"",12,self.Colors.muted,530)
        c.basis=W.Text(c.detail,"",12,self.Colors.muted,530)
        c.pin=W.Button(c,"Track",210,31,function() XC:TrackItem(XC:DisplayRow(key),key,true) end)
        c.chat=W.Button(c,"Chat",72,31,function() local row=XC:DisplayRow(key); if row then XC:LinkItem(row.item) end end)
        c.sourceChoice=W.Button(c,"",300,28,function() XC:CycleCardSource(key) end)
        c.counter=W.Text(c,"",12,self.Colors.muted,120)
        c.prev=W.Button(c,"<",34,28,function() XC.selection[key]=math.max(1,(XC.selection[key] or 1)-1); XC:Render() end)
        c.next=W.Button(c,">",34,28,function() XC.selection[key]=math.min(#XC.lanes[key],(XC.selection[key] or 1)+1); XC:Render() end)
        c.ReflowContent=function()
            c.summary:SetHeight(0); local sh=c.summary:GetStringHeight(); c.summary:SetHeight(sh)
            local top=math.max(55,sh+28); c.listScroll:SetPoint("TOPLEFT",12,-top); c.detailScroll:SetPoint("TOPLEFT",254,-top)
            local width=c.detail:GetWidth(); c.name:SetWidth(width-56); c.name:SetHeight(0)
            local nh=math.max(42,c.name:GetStringHeight()); c.name:SetHeight(nh); c.itemButton:SetHeight(nh)
            local y=nh+14
            for _,t in ipairs({c.score,c.stats,c.source,c.available,c.basis}) do
                t:SetWidth(width); t:SetHeight(0); local h=t:GetStringHeight(); at(t,0,y); t:SetHeight(h); y=y+h+16
            end
            c.detail:SetHeight(y)
        end
    end
    p.Layout=function(_,width,height)
        local body=width-180; current:SetWidth(body); current.name:SetWidth(body-210); current.stats:SetWidth(body-140)
        W.FitButton(f.profile,230); at(f.profile,170,40)
        local toggles=190+f.classLabel:GetStringWidth()
        at(f.solo,toggles,3); at(f.craft,toggles+86,3); at(f.auction,toggles+180,3)
        at(current.score,body-132,14); at(current.chat,body-84,49)
        f.search:SetWidth(math.max(200,body-168)); W.FitButton(f.clearSearch,70); at(f.clearSearch,170+body-f.clearSearch:GetWidth(),185)
        local sy=0
        for _,slot in ipairs(XC.Slots) do local b=f.slots[slot.id]; b:SetHeight(math.max(29,b.label:GetStringHeight()+8)); at(b,0,sy); sy=sy+b:GetHeight()+2 end
        slotList:SetHeight(sy)
        local ch=height-277
        for _,key in ipairs(laneOrder) do
            local c=f.lanes[key]; c:SetSize(body,ch); c.summary:SetWidth(body-28); c.detail:SetWidth(body-284); c.itemButton:SetWidth(body-284)
            W.FitButton(c.sourceChoice,body-284); W.FitButton(c.chat,72)
            W.FitButton(c.pin,body-296-c.chat:GetWidth()); at(c.sourceChoice,254,ch-87); at(c.pin,254,ch-49); at(c.chat,body-30-c.chat:GetWidth(),ch-49)
            at(c.counter,12,ch-30); at(c.prev,142,ch-34); at(c.next,181,ch-34); c:ReflowContent()
        end
        if XC.context then XC:Render() end
    end
end
function XC:Render()
    local f=self.window; if not f or not self.context then return end
    local profile=self:GetProfile(self.db.profile); local slot=self:GetSlot(self.db.slot)
    f.classLabel:SetText(self.ClassLabels[self.context.class] or self.context.class)
    f.profile.label:SetText("Spec: "..(profile.spec or profile.label).."  >")
    W.FitButton(f.profile,230)
    f.profileBasis:SetText(self.db.weights[profile.id] and "Custom weights" or "Starter role weights")
    f.profileBasis:SetWidth(math.max(1,f.gearPage:GetWidth()-194-f.profile:GetWidth()))
    at(f.profileBasis,184+f.profile:GetWidth(),49)
    local toggles=190+f.classLabel:GetStringWidth()
    at(f.solo,toggles,3); at(f.craft,toggles+86,3); at(f.auction,toggles+180,3)
    W.Hint(f.profile,(profile.description or "Choose your specialization.").."\n"..(profile.basis or "Role-based estimate").."\nClick to cycle your class's specs. /uc weights edits this spec only.")
    f.faction.label:SetText("Faction: "..self.Rules.FactionLabels[self.Rules.FactionMode(self.db.options,self.context)].."  >")
    W.FitButton(f.faction,190); at(f.faction,f.gearPage:GetWidth()-10-f.faction:GetWidth(),0)
    f.solo:SetChecked(self.db.options.solo); f.craft:SetChecked(self.db.options.crafted); f.auction:SetChecked(self.db.options.auction)
    for id,b in pairs(f.slots) do W.SelectRow(b,id==slot.id) end
    local count=0; for _ in pairs(self.db.pins) do count=count+1 end; f.hunts.label:SetText("Hunts ("..count..")"); self:LayoutNavigation()
    f.current.chat:SetEnabled(self.baseline~=nil)
    if self.baseline then
        local n,icon=self.Client.Presentation(self.baseline); f.current.icon:SetTexture(icon); f.current.name:SetText(n)
        f.current.stats:SetText(W.StatLine(self.baseline,profile.weights)); f.current.score:SetText(self.baselineScore and string.format("%.1f score",self.baselineScore) or "Unscored")
    else
        f.current.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.current.name:SetText(self.context.occupied[slot.id] and "Equipped item data is loading" or ("Empty "..slot.label:lower().." slot"))
        f.current.stats:SetText("Choose an item below to plan its source."); f.current.score:SetText(self.context.occupied[slot.id] and "Unscored" or "0.0 score")
    end
    local active=self.db.path or "reliable"; if not f.lanes[active] then active="reliable"; self.db.path=active end
    for _,key in ipairs(laneOrder) do
        local c=f.lanes[key]; c:SetShown(key==active)
        W.SelectRow(f.tabs[key],key==active)
        f.tabs[key]:SetEnabled(key~=active)
        local rows=self.lanes[key]; local index=math.max(1,math.min(#rows,self.selection[key] or 1)); self.selection[key]=index
        local row=self:DisplayRow(key)
        local first=math.floor((index-1)/8)*8; local listY=0
        if c.listPage~=first then if c.listScroll.SetVerticalScroll then c.listScroll:SetVerticalScroll(0) end; c.listPage=first end
        for j,entry in ipairs(c.items) do
            local choice=rows[first+j]; entry:SetShown(choice~=nil)
            if choice then
                entry.label:SetText(choice.item.name); entry.label:SetHeight(0)
                local textHeight=entry.label:GetStringHeight(); entry.label:SetHeight(textHeight); entry:SetHeight(math.max(43,textHeight+10)); at(entry,0,listY); listY=listY+entry:GetHeight()+5
                W.SelectRow(entry,first+j==index)
                W.Tooltip(entry,choice.item,"Click: inspect source / Shift-click or right-click: chat")
                entry:SetScript("OnClick",function(_,button) W.ItemClick(choice.item,function() XC.selection[key]=first+j; XC:Render() end,button) end)
            end
        end
        c.list:SetHeight(math.max(100,listY))
        for _,el in ipairs({c.iconButton,c.itemButton,c.score,c.stats,c.source,c.available,c.pin,c.chat,c.sourceChoice,c.counter,c.prev,c.next,c.basis}) do el:SetShown(row~=nil) end
        if row then
            if c.lastItem~=row.item.id then if c.detailScroll.SetVerticalScroll then c.detailScroll:SetVerticalScroll(0) end; c.lastItem=row.item.id end
            at(c.name,56,0); c.name:SetWidth(c.detail:GetWidth()-56)
            local n,icon,_,quality=self.Client.Presentation(row.item); c.icon:SetTexture(icon); c.name:SetText(n)
            local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            c.name:SetTextColor(color and color.r or self.Colors.text[1],color and color.g or self.Colors.text[2],color and color.b or self.Colors.text[3])
            c.score:SetText(row.delta and string.format("+%.1f weighted score",row.delta) or string.format("%.1f target score",row.score))
            c.stats:SetText(W.StatLine(row.item,profile.weights)); c.source:SetText(self:SourceText(row.source)); c.available:SetText(self:Availability(row))
            local destination=self.Navigation.Resolve(row.source); c.pin.label:SetText((destination.point or destination.status=="quest") and "Track + map" or "Track + guide")
            c.sourceChoice.label:SetText(string.format("Source %d / %d%s",row.sourceIndex,row.sourceCount,row.sourceCount>1 and "   >" or "")); c.sourceChoice:SetEnabled(row.sourceCount>1)
            c.counter:SetText(string.format("Item %d / %d",index,#rows)); c.prev:SetEnabled(index>1); c.next:SetEnabled(index<#rows)
            c.basis:SetText(row.item.basis=="live" and "Client stats / model estimate" or (row.item.basis=="forever" and "Forever snapshot / model estimate" or "Classic baseline / verify in Forever"))
            W.Tooltip(c.itemButton,row.item); W.Tooltip(c.iconButton,row.item)
            local function click(_,button) W.ItemClick(row.item,function() XC:TrackItem(row,key,false) end,button) end
            c.itemButton:SetScript("OnClick",click); c.iconButton:SetScript("OnClick",click); W.FitButton(c.sourceChoice,c:GetWidth()-284); W.FitButton(c.pin,c:GetWidth()-296-c.chat:GetWidth()); c:ReflowContent()
        else
            at(c.name,0,0); c.name:SetWidth(c.detail:GetWidth()); c.name:SetHeight(200)
            c.name:SetText((self.search or "")~="" and "No matches here. Clear your search or try another slot." or empty[key]); c.detail:SetHeight(210)
        end
    end
    if self.huntWindow and self.huntWindow:IsShown() then self:RenderHunts() end
end
function XC:BuildHunts()
    local f=W.Page(self.window,"hunts"); self.huntWindow=f
    f.hideObtained=at(W.Toggle(f,"Hide obtained",function(v) XC.db.hideObtained=v; XC:RenderHunts() end),12,8)
    f.hideObtained:SetChecked(self.db.hideObtained)
    f.empty=at(W.Text(f,"No hunts to show. Track any item on the planner, or turn off Hide obtained.",14,self.Colors.text,700),18,70)
    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); f.scroll:SetPoint("TOPLEFT",12,-48); f.scroll:SetPoint("BOTTOMRIGHT",-30,12)
    f.child=CreateFrame("Frame",nil,f.scroll); f.child:SetSize(786,430); f.scroll:SetScrollChild(f.child); f.rows={}
    f.Layout=function(_,width,height)
        f.child:SetWidth(width-44); f.empty:SetWidth(width-40)
        if f:IsShown() and XC.context then XC:RenderHunts() end
    end
end
function XC:ShowHunts() self:ShowPage("hunts") end
function XC:RenderHunts()
    local f=self.huntWindow; hideRows(f.rows)
    local pins={}; for _,pin in pairs(self.db.pins) do if not (self.db.hideObtained and pin.acquired) then pins[#pins+1]=pin end end
    table.sort(pins,function(a,b) if a.acquired~=b.acquired then return not a.acquired end return a.order<b.order end)
    f.empty:SetShown(#pins==0); f.child:SetHeight(math.max(f:GetHeight()-160,#pins*238)); local rowY=0
    local width=f.child:GetWidth()
    for i,pin in ipairs(pins) do
        local r=f.rows[i]
        if not r then
            r=W.Panel(f.child,width,226,self.Colors.panel); f.rows[i]=r
            r.name=at(W.Text(r,"",16,self.Colors.text,500),16,16); r.name:SetHeight(42)
            r.itemButton=CreateFrame("Button",nil,r); at(r.itemButton,16,12); r.itemButton:SetSize(width-130,44); r.itemButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
            r.source=at(W.Text(r,"",11,self.Colors.muted,500),16,60); r.source:SetHeight(33)
            r.remove=W.Button(r,"Remove",80,24); r.map=W.Button(r,"Track",80,27); r.chat=W.Button(r,"Chat",80,24)
            r.checks={}
            for j=1,3 do
                local check=at(W.Toggle(r,"",function(v) if r.pin then r.pin.checks[j]=v; XC:RenderGuide() end end),13,98+(j-1)*27)
                check.label=W.Text(check,"",12,self.Colors.text,500); check.label:SetPoint("LEFT",check,"RIGHT",2,0); r.checks[j]=check
            end
            r.notesLabel=at(W.Text(r,"NOTES / saved as you type",10,self.Colors.muted),16,181)
            r.noteInput=at(W.Input(r,width-32,26),16,196)
        end
        if r.pin~=pin then r.noteInput.edit:ClearFocus() end
        at(r,0,rowY); r:SetWidth(width); r:Show(); r.pin=pin
        r.name:SetWidth(width-130); r.source:SetWidth(width-130); r.itemButton:SetWidth(width-130)
        for _,check in ipairs(r.checks) do check.label:SetWidth(width-145) end
        r.noteInput:SetWidth(width-32)
        at(r.remove,width-96,15); at(r.map,width-96,56); at(r.chat,width-96,95)
        r.name:SetText((pin.acquired and "|cff62d3acOBTAINED|r  " or "")..pin.item.name); r.source:SetText(self:SourceText(pin.source))
        local tasks={"Confirm requirements and availability","Prepare access, materials or a group","Obtain the item"}
        if pin.source.kind=="quest" then tasks[1]="Find the quest and check prerequisites"; tasks[2]="Complete the quest objectives" end
        if pin.source.kind=="craft" then tasks[1]="Find a crafter or learn the recipe"; tasks[2]="Collect the required materials" end
        for j,check in ipairs(r.checks) do check.label:SetText(tasks[j]); check:SetChecked(j==3 and pin.acquired or pin.checks[j]); check:SetEnabled(not (j==3 and pin.acquired)) end
        r.remove:SetScript("OnClick",function()
            XC.db.pins[tostring(pin.item.id)]=nil
            if XC.db.activeHunt==tostring(pin.item.id) then XC.Navigation.ReleaseOwnedWaypoint(); XC.db.activeHunt=nil; XC:RenderGuide() end
            XC:Refresh(); XC:RenderHunts()
        end)
        local function track() f:Hide(); XC:TrackItem({item=pin.item,source=pin.source},pin.lane,true) end
        r.map:SetScript("OnClick",track); r.map:SetEnabled(true)
        r.chat:SetScript("OnClick",function() XC:LinkItem(pin.item) end)
        W.Tooltip(r.itemButton,pin.item)
        r.itemButton:SetScript("OnClick",function(_,button) W.ItemClick(pin.item,track,button) end)
        if not r.noteInput.edit:HasFocus() then r.noteInput.edit:SetText(pin.notes or "") end
        r.noteInput.edit:SetScript("OnTextChanged",function(edit,user) if user then pin.notes=edit:GetText() end end)
        r.noteInput.edit:SetScript("OnEnterPressed",function(edit) edit:ClearFocus() end)
        r.name:SetHeight(0); local nameHeight=math.max(26,r.name:GetStringHeight()); r.name:SetHeight(nameHeight); r.itemButton:SetHeight(nameHeight)
        at(r.source,16,22+nameHeight); r.source:SetHeight(0); local sourceHeight=r.source:GetStringHeight(); r.source:SetHeight(sourceHeight)
        local checkY=30+nameHeight+sourceHeight
        for _,check in ipairs(r.checks) do
            check.label:SetHeight(0); local h=math.max(25,check.label:GetStringHeight()+4); check.label:SetHeight(h)
            at(check,13,checkY); checkY=checkY+h+3
        end
        at(r.notesLabel,16,checkY+3); at(r.noteInput,16,checkY+27)
        r:SetHeight(checkY+59); rowY=rowY+r:GetHeight()+12
    end
    f.child:SetHeight(math.max(f:GetHeight()-160,rowY))
end
function XC:MapTarget(source)
    local _,message=self.Navigation.Apply(self.Navigation.Resolve(source),true); self:Print(message)
end
function XC:BuildAbout()
    local f=W.Page(self.window,"help"); self.about=f
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",20,-12); scroll:SetPoint("BOTTOMRIGHT",-32,12)
    local body=CreateFrame("Frame",nil,scroll); body:SetSize(720,1120); scroll:SetScrollChild(body)
    local sections={
        {"UPGRADE PATHS","The tabs show Quest & craft, Dungeons and Future gear. Choose equipment on the left. Faction cycles Alliance, Horde and Both; shared or untagged sources stay visible. Opposite-faction sources are labeled as unavailable to this character. Your class is shown above a specialization selector. Click Spec to cycle your class's presets. /uc weights edits only that spec. Filters remove sources you do not want; search finds item, source and zone names within the selected slot."},
        {"QUEST & CRAFT / DUNGEONS / FUTURE GEAR","Reliable shows quest rewards and crafts with a defined outcome. Dungeon shows eligible group sources. Long-term includes future gear up to level 60. These are scored suggestions, not verified BiS rankings."},
        {"TRACK + MAP / TRACK + GUIDE","Choose an item from the list, then click its name or Track button to save it and start guidance immediately. Known destinations appear on the world map. Dungeon pins show outdoor entrances or approaches, not interior boss routes. Unknown coordinates remain clearly labeled."},
        {"CHAT / ITEM SHORTCUTS","Chat, Shift-click or right-click inserts an item link into your chat draft. You choose the channel and press Enter to send. Ctrl-click previews it in the dressing room. Uncached links may need a second click after data loads."},
        {"SAVED HUNTS / ACTIVE TRACKER","Hunts keep your checklist and notes between sessions. Track resumes a hunt. The separate tracker shows the next step while the planner is closed. Preparation checkboxes are manual; bag ownership is detected automatically. Stop tracking keeps the saved hunt."},
        {"CUSTOM ITEM / SET LOCATION","Use Custom item for gear absent from the catalog. Set location on the tracker fills in the existing item and source; you only enter a map ID and X/Y percentages. Personal locations and targets save for this character."},
        {"APPEARANCE","The Settings page has saved style controls: Classic, Alliance, Horde or Midnight; background opacity; custom background, heading and border colors; two fonts, three text sizes and outlines. Readable scaling keeps text at least 12 screen pixels and window scale at least 80%."},
        {"WINDOWS / CONTROLS","The Gear, Hunts, Settings, Help and Add item pages share one window. Drag the title to move it, or the bottom-right grip to scale it. Shift-drag that grip to resize the layout. Settings also has a scale slider. The tracker remains separate. Close the planner with X or Escape. /uc guide reopens an active tracker; /uc resetwindows restores window defaults."},
        {"SCORING / DATA","Spec presets add weighted base stats using editable role weights. Specs with the same role can share weights; these are not public-guide BiS rankings. Procs, set bonuses, talent multipliers, stat caps and encounter effects are not simulated. Different weapon hand setups do not receive an upgrade delta. /uc weights edits your profile. Inspect tooltips before committing."},
        {"CATALOG / LOCATION COVERAGE","3,529 items; catalog snapshot "..self.CatalogMeta.date..". Forever overrides and source facts are bundled from Polestar; other entries are marked Classic baseline. New or changed items can be missing. Native quest guidance and optional QuestieDB supply known quest locations; ambiguous chains still require checking. No live AH prices or exact walking routes are supplied."},
    }
    f.helpSections={}
    for _,section in ipairs(sections) do
        f.helpSections[#f.helpSections+1]={heading=W.Text(body,section[1],12,self.Colors.reliable),text=W.Text(body,section[2],13,self.Colors.text,710)}
    end
    f.Layout=function(_,width)
        body:SetWidth(width-72); local y=0
        for _,section in ipairs(f.helpSections) do
            at(section.heading,0,y); at(section.text,0,y+25); section.text:SetWidth(width-80)
            section.text:SetHeight(0)
            local textHeight=section.text:GetStringHeight()
            section.text:SetHeight(textHeight); y=y+textHeight+53
        end
        body:SetHeight(y)
    end
end
function XC:ShowAbout() self:ShowPage("help") end
