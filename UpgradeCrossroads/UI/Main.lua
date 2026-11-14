local _, XC = ...
local W=XC.W
local at=W.Place
local navigation={{"gear","Journal"},{"hunts","Hunts"},{"editor","Add item"},{"appearance","Settings"},{"help","Help"}}
local captions={hunts="Your saved gear, checklists and notes.",appearance="Customize the addon and how it scores gear.",
    help="How to browse, compare and track upgrades.",editor="Add gear to your Journal or update a hunt's map location."}

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
    if id=="compare" then
        id="gear"
        self:SetJournalSlot(self.db.slot or 0)
    end
    if id=="appearance" then self:BuildAppearance() end
    local f=self.window
    if not f.pages[id] then return end
    if id~="gear" then
        f.journal.slotPickerOpen=false
        f.journal.destinationPickerOpen=false
    end
    f.activePage=id
    for key,page in pairs(f.pages) do page:SetShown(key==id) end
    f.description:SetText(captions[id] or "")
    if id=="appearance" then self:SyncAppearance() end
    self:LayoutNavigation()
    self:LayoutPages()
    if f:IsShown() then self:Render() else f:Show() end
    if f.Raise then f:Raise() end
end

function XC:LayoutNavigation()
    local f=self.window
    local x=22
    local navY=math.max(56,18+f.title:GetStringHeight()+6)
    local navHeight=30
    for _,entry in ipairs(navigation) do
        local id=entry[1]
        local b=f.nav[id]
        b.label:SetWidth(0)
        local width=math.max(94,b.label:GetStringWidth()+25)
        b:SetWidth(width)
        b.label:SetWidth(width-16)
        b:SetHeight(math.max(30,b.label:GetStringHeight()+8))
        navHeight=math.max(navHeight,b:GetHeight())
        at(b,x,navY)
        x=x+width+6
        W.SelectRow(b,id==f.activePage)
    end
    at(f.divider,22,navY+navHeight+5)
    f.description:SetShown(f.activePage~="gear")
    if f.activePage=="gear" then
        f.pageTop=navY+navHeight+14
    else
        f.description:SetWidth(f:GetWidth()-44)
        f.description:SetHeight(0)
        at(f.description,22,navY+navHeight+15)
        f.pageTop=navY+navHeight+f.description:GetStringHeight()+27
    end
end

function XC:LayoutPages()
    local f=self.window; if not f then return end
    f.catalog:SetWidth(f:GetWidth()-44); f.catalog:SetHeight(0)
    local footerHeight=f.catalog:GetStringHeight(); f.catalog:SetHeight(footerHeight)
    at(f.catalog,22,f:GetHeight()-footerHeight-9)
    local pageTop=f.pageTop or 135; at(f.pageHost,18,pageTop)
    f.pageHost:SetSize(f:GetWidth()-36,f:GetHeight()-pageTop-footerHeight-15)
    for _,page in pairs(f.pages) do
        local width,height=f.pageHost:GetWidth(),f.pageHost:GetHeight()
        if page:GetWidth()~=width or page:GetHeight()~=height then page:SetSize(width,height)
        elseif page.pageID==f.activePage then page:ApplyLayout() end
    end
end
function XC:SetFactionFilter(mode)
    if not self.Rules.FactionLabels[mode] then return end
    self.db.options.faction=mode; self.journalSourceSelection=nil
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
    f.description=at(W.Text(f,"",13,self.Colors.muted,930),22,58)
    f.pages={}; f.nav={}
    for i,entry in ipairs(navigation) do
        local id,label=entry[1],entry[2]
        local b=W.Row(f,label,130,30,function() if id=="editor" then XC:ShowTargetEditor() else XC:ShowPage(id) end end)
        f.nav[id]=b; at(b,22+(i-1)*140,91)
    end
    f.hunts=f.nav.hunts; f.appearance=f.nav.appearance; f.help=f.nav.help; f.add=f.nav.editor
    f.divider=at(W.Bar(f,self.Colors.border,996,1),22,126)
    f.pageHost=CreateFrame("Frame",nil,f); at(f.pageHost,18,135); f.pageHost:SetSize(1004,626)
    f.catalog=W.Text(f,"v"..self.version.."  |  "..self.CatalogMeta.count.." catalog items",12,self.Colors.muted)
    W.Hint(f.nav.help,"Controls, scoring and catalog information.")
    self:BuildJournal(); self:BuildHunts(); self:BuildAbout()
    f.activePage="gear"; f.pages.gear:Show()
    W.Resizable(f,"planner",900,720,function(_,width,height)
        f.divider:SetWidth(width-44); at(f.catalog,22,height-22)
        XC:LayoutNavigation()
        XC:LayoutPages()
    end)
    W.OrnateShell(f)
    f:HookScript("OnShow",function() XC:Refresh() end)
    _G.UpgradeCrossroadsWindow=f
end
function XC:Render()
    local f=self.window
    if not f or not f:IsShown() then return end
    local count=0
    for _ in pairs(self.db.pins) do count=count+1 end
    local huntsLabel=count>0 and ("Hunts ("..count..")") or "Hunts"
    if f.nav.hunts.label:GetText()~=huntsLabel then
        f.nav.hunts.label:SetText(huntsLabel)
        self:LayoutNavigation()
    end
    if f.activePage=="gear" then self:RenderJournal()
    elseif f.activePage=="hunts" then self:RenderHunts()
    elseif f.activePage=="appearance" then self:SyncAppearance() end
end

function XC:MapTarget(source)
    local _,message=self.Navigation.Apply(self.Navigation.Resolve(source),true); self:Print(message)
end
function XC:BuildAbout()
    local f=W.Page(self.window,"help"); self.about=f
    W.ThemedPage(f)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",20,-12); scroll:SetPoint("BOTTOMRIGHT",-32,12)
    local body=CreateFrame("Frame",nil,scroll); body:SetSize(720,1120); scroll:SetScrollChild(body)
    local meta=self.CatalogMeta
    local sections={
        {"FIND YOUR NEXT UPGRADE","Start in Journal. Use Equipment for a single slot or Destinations for a quest zone or dungeon. Search by item or source. Filters lets you choose your faction, skip group content or look ahead to future gear."},
        {"COMPARE AND TRACK","Select an item for its equipped comparison and source. Track saves it to Hunts and opens the tracker. Show on map opens the destination. Recipe jumps to crafting instructions. Shift-click or right-click gear to link it in chat. Ctrl-click previews it."},
        {"MANAGE YOUR HUNTS","Hunts keeps your preparation and notes. Obtaining the item records it in Completed. Stop tracking keeps the hunt. Remove in Journal hides the suggestion until you restore it. Use Add item for gear missing from the catalog."},
        {"SCORING AND GEAR HINTS","Your spec's stat weights determine the score. Edit them under Settings / Stat weights. The scores model base stats. Inspect effects and set bonuses in game. Gear hints controls comparisons in tooltips and upgrade markers in Blizzard bags and quest rewards."},
        {"WINDOW CONTROLS","Drag the title bar to move a window. Drag the grip to scale it or Shift-drag to change the layout size. X or Escape closes the addon. /uc guide reopens the tracker and /uc resetwindows restores window geometry."},
        {"CATALOG AND MAPS",string.format("%s items. Base snapshot %s; reviewed quest data through %s. Sources and stats marked Classic baseline should be checked in Forever. Optional QuestieDB adds quest locations when available.",
            meta.count,meta.date,meta.liveQuestDate or meta.date)},
    }
    f.helpSections={}
    for _,section in ipairs(sections) do
        f.helpSections[#f.helpSections+1]={heading=W.JournalText(body,section[1],12,nil,true),text=W.JournalText(body,section[2],13,710)}
    end
    f.Layout=function(_,width)
        body:SetWidth(width-72); local y=0
        for _,section in ipairs(f.helpSections) do
            section.heading:SetWidth(width-80); section.heading:SetHeight(0)
            local headingHeight=section.heading:GetStringHeight(); section.heading:SetHeight(headingHeight)
            at(section.heading,0,y); at(section.text,0,y+headingHeight+8); section.text:SetWidth(width-80)
            section.text:SetHeight(0)
            local textHeight=section.text:GetStringHeight()
            section.text:SetHeight(textHeight); y=y+headingHeight+textHeight+28
        end
        body:SetHeight(y)
    end
end
function XC:ShowAbout() self:ShowPage("help") end
