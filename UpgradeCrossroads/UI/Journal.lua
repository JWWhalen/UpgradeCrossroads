local _, XC = ...
local W=XC.W
local at=W.Place
local stateLabels={active="Active",completed="Completed",removed="Removed"}
local laneLabels={all="Available now",reliable="Quest & craft",dungeon="Dungeons",longterm="Future goals"}
local laneOrder={"all","reliable","dungeon","longterm"}
local horizons={0,3,5,10}
local function lookaheadLabel(levels)
    return (levels>0 and ("Next "..levels.." levels") or "All levels").."  >"
end
local function filterSummary(v,options,context)
    local parts={laneLabels[v.lane]}
    if v.lane=="longterm" and v.lookahead>0 then parts[#parts+1]="Next "..v.lookahead.." levels" end
    if v.destinationLabel then parts[#parts+1]=v.destinationLabel end
    local faction=XC.Rules.FactionMode(options,context)
    local playerFaction=context.side==1 and "alliance" or (context.side==2 and "horde" or "both")
    if faction~=playerFaction then parts[#parts+1]=faction=="both" and "Both factions" or XC.Rules.FactionLabels[faction] end
    if options.solo then parts[#parts+1]="Solo" end
    if not options.crafted then parts[#parts+1]="Crafts off" end
    if options.auction then parts[#parts+1]="Auction targets" end
    return table.concat(parts,"  /  ")
end
local function prefs()
    XC.db.journalUI=type(XC.db.journalUI)=="table" and XC.db.journalUI or {}
    local p=XC.db.journalUI
    p.state=stateLabels[p.state] and p.state or "active"
    p.lane=laneLabels[p.lane] and p.lane or "all"
    local slotID=tonumber(p.slotID) or 0
    p.slotID=0
    for _,slot in ipairs(XC.Slots) do if slot.id==slotID then p.slotID=slotID; break end end
    if p.limit~=0 and p.limit~=1 and p.limit~=3 and p.limit~=5 and p.limit~=10 then p.limit=3 end
    if p.lookahead~=3 and p.lookahead~=5 and p.lookahead~=10 then p.lookahead=0 end
    if type(p.destination)~="string" then p.destination=nil end
    if type(p.destinationLabel)~="string" then p.destinationLabel=nil end
    p.collapsed=type(p.collapsed)=="table" and p.collapsed or {}
    return p
end
function XC:SetJournalSlot(slotID)
    slotID=tonumber(slotID)
    local valid=slotID==0
    for _,slot in ipairs(self.Slots) do if slot.id==slotID then valid=true; break end end
    if not valid then return false end
    local v=prefs(); v.slotID=slotID; v.selected=nil
    if slotID~=0 then self.db.slot=slotID; v.collapsed[slotID]=nil end
    local p=self.window and self.window.journal
    if p then
        p.slotPickerOpen=false
        p.destinationPickerOpen=false
        if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
    end
    self:Refresh()
    if p then p:ApplyLayout() end
    return true
end
local function hide(rows) for _,r in ipairs(rows or {}) do r:Hide() end end
local function flow(text,x,y,width)
    text:SetWidth(width); text:SetHeight(0); at(text,x,y)
    local h=text:GetStringHeight(); text:SetHeight(h)
    return y+h
end
local function recipeSourceIndex(row)
    if not row then return nil end
    if row.source.kind=="craft" then return row.sourceIndex end
    for i,source in ipairs(row.sources) do
        if source.kind=="craft" then return i end
    end
end
local function currentDestination(groups)
    local mapID=XC.Client.Safe(C_Map and C_Map.GetBestMapForUnit,"player")
    if not mapID then return nil end
    local map=XC.Client.Safe(C_Map.GetMapInfo,mapID)
    local match
    for _,group in ipairs(groups) do
        if map and group.label==map.name then
            if group.kind=="dungeon" then return group end
            match=match or group
        end
    end
    return match
end
function XC:BuildJournal()
    local f=self.window
    local p=W.Page(f,"gear"); f.journal=p
    p.heading=at(W.Text(p,"",15,self.Colors.gold,nil,true),8,5)
    p.intro=W.Text(p,"",12,self.Colors.muted,650)
    p.slotButton=W.Button(p,"All equipment  >",220,30,function()
        p.slotPickerOpen=not p.slotPickerOpen
        p.destinationPickerOpen=false
        if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
        XC:RenderJournal()
    end)
    W.Hint(p.slotButton,"Choose one equipment slot or browse all equipment. The slot picker opens inside the item list.")
    p.destinationButton=W.Button(p,"Destinations  >",134,30,function()
        p.destinationPickerOpen=not p.destinationPickerOpen
        p.slotPickerOpen=false
        if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
        XC:RenderJournal()
    end)
    W.Hint(p.destinationButton,"Browse catalogued dungeon drops and quest rewards by destination.")
    p.profile=W.Button(p,"",220,30,function() XC:CycleProfile() end)
    p.filterButton=W.Button(p,"Filters",90,29,function() prefs().filters=not prefs().filters; p:ApplyLayout() end)
    W.Hint(p.profile,"Your class specialization and scoring weights. /uc weights edits this spec's weights.")
    p.filters=W.Panel(p,900,64,self.Colors.panel)
    p.lane=W.Button(p.filters,"",180,29,function()
        p.slotPickerOpen=false
        p.destinationPickerOpen=false
        local v=prefs(); local n=1; for i,id in ipairs(laneOrder) do if id==v.lane then n=i end end
        v.lane=laneOrder[n%#laneOrder+1]; v.selected=nil; p:ApplyLayout()
    end)
    p.faction=W.Button(p.filters,"",185,29,function() XC:CycleFactionFilter() end)
    p.solo=W.Toggle(p.filters,"Solo",function(v) XC.db.options.solo=v; XC:Refresh() end)
    p.craft=W.Toggle(p.filters,"Crafts",function(v) XC.db.options.crafted=v; XC:Refresh() end)
    p.auction=W.Toggle(p.filters,"AH",function(v) XC.db.options.auction=v; XC:Refresh() end)
    p.lookahead=W.Button(p.filters,"All levels  >",122,29,function()
        local v=prefs(); local index=1
        for i,n in ipairs(horizons) do if n==v.lookahead then index=i; break end end
        v.lookahead=horizons[index%#horizons+1]
        v.selected=nil
        p:ApplyLayout()
    end)
    W.Hint(p.lookahead,"Future goals can include all levels or stop 3, 5, or 10 levels above yours.")
    W.Hint(p.lane,"Available now combines eligible sources at your level. Future goals includes items for later levels. Rankings are model estimates.")
    W.Hint(p.faction,"Cycle Alliance, Horde or Both. Sources for the other faction are labeled.")
    -- One painting continues beneath both border-only panes and their gutter.
    p.panorama=W.JournalPanorama(p)
    p.left=W.QuestSurface(p,"list",true); p.paper=W.QuestSurface(p,"parchment",true)
    p.tabs={}
    for _,id in ipairs({"active","completed","removed"}) do
        p.tabs[id]=W.Row(p.left,stateLabels[id],105,29,function()
            p.slotPickerOpen=false
            p.destinationPickerOpen=false
            prefs().state=id; prefs().selected=nil
            if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
            p:ApplyLayout()
        end)
    end
    p.search=W.Input(p.left,270,30)
    p.searchPrompt=W.Text(p.search,"Search items or sources",12,self.Colors.muted,220)
    p.clear=W.Button(p.left,"Clear",64,30,function()
        p.slotPickerOpen=false
        p.query=""; p.search.edit:SetText(""); prefs().selected=nil
        if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
        XC:RenderJournal()
    end)
    p.search.edit:SetScript("OnTextChanged",function(edit,user)
        if not user then return end
        p.slotPickerOpen=false
        p.query=edit:GetText(); prefs().selected=nil
        if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
        XC:RenderJournal()
    end)
    p.search.edit:SetScript("OnEditFocusGained",function() p.searchPrompt:Hide() end)
    p.search.edit:SetScript("OnEditFocusLost",function(edit) p.searchPrompt:SetShown(edit:GetText()=="") end)
    p.search.edit:SetScript("OnEnterPressed",function(edit) edit:ClearFocus() end)
    W.Hint(p.search,"Search item, boss, quest or zone names across every equipment slot.")
    p.scroll=CreateFrame("ScrollFrame",nil,p.left,"UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT",8,-88); p.scroll:SetPoint("BOTTOMRIGHT",-28,54)
    p.child=CreateFrame("Frame",nil,p.scroll); p.child:SetSize(340,400); p.scroll:SetScrollChild(p.child); p.rows={}
    p.empty=at(W.Text(p.child,"",13,self.Colors.muted,310),8,12)
    p.limit=W.Button(p.left,"",150,28,function()
        local choices={1,3,5,10,0}; local n=1
        for i,v in ipairs(choices) do if v==prefs().limit then n=i end end
        prefs().limit=choices[n%#choices+1]; XC:RenderJournal()
    end)
    p.expand=W.Button(p.left,"Expand all",110,28,function() prefs().collapsed={}; XC:RenderJournal() end)
    W.Hint(p.limit,"Ranked suggestions per slot. Choose All to scroll through every matching item. Completed and Removed show all their saved entries.")
    p.detailScroll=CreateFrame("ScrollFrame",nil,p.paper,"UIPanelScrollFrameTemplate")
    p.detailScroll:SetPoint("TOPLEFT",20,-16); p.detailScroll:SetPoint("BOTTOMRIGHT",-32,108)
    p.body=CreateFrame("Frame",nil,p.detailScroll); p.body:SetSize(500,600); p.detailScroll:SetScrollChild(p.body)
    p.title=W.JournalText(p.body,"",19,460,true)
    p.description=W.JournalText(p.body,"",13,460)
    p.sourceHeading=W.JournalText(p.body,"SOURCE",15,460,true)
    p.source=W.JournalText(p.body,"",13,460)
    p.location=W.JournalText(p.body,"",12,460)
    p.reward=W.Panel(p.body,460,76,self.Colors.raised)
    p.rewardIcon=p.reward:CreateTexture(nil,"ARTWORK"); p.rewardIcon:SetSize(42,42); at(p.rewardIcon,10,12)
    p.rewardName=at(W.Text(p.reward,"",17,self.Colors.text,320),63,12)
    p.rewardMeta=at(W.Text(p.reward,"",12,self.Colors.muted,320),63,39)
    p.rewardButton=CreateFrame("Button",nil,p.reward); p.rewardButton:SetAllPoints(); p.rewardButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    p.compareHeading=W.JournalText(p.body,"EQUIPPED",15,460,true)
    p.equippedName=W.JournalText(p.body,"",13,460)
    p.equippedStats=W.JournalText(p.body,"",12,460)
    p.equippedScore=W.JournalText(p.body,"",12,460)
    p.equippedChat=W.Button(p.body,"Link equipped",130,26,function()
        if p.equippedItem then XC:LinkItem(p.equippedItem) end
    end)
    p.equipped={name=p.equippedName,stats=p.equippedStats,score=p.equippedScore,chat=p.equippedChat}
    p.comparison=W.JournalText(p.body,"",13,460)
    p.stats=W.JournalText(p.body,"",13,460)
    p.statChanges=W.JournalText(p.body,"",13,460)
    p.basis=W.JournalText(p.body,"",12,460)
    p.sourceChoice=W.Button(p.paper,"",230,28,function()
        local row=p.selectedRow; if not row or row.sourceCount<2 then return end
        XC:SetJournalSource(row,row.sourceIndex%row.sourceCount+1)
        XC:RenderJournal()
    end)
    p.recipe=W.Button(p.paper,"Recipe",84,28,function()
        local row=p.selectedRow
        local index=recipeSourceIndex(row)
        if not index then return end
        if row.sourceIndex~=index and XC:SetJournalSource(row,index) then XC:RenderJournal() end
        local offset=p.recipeOffset
        local scroll=p.detailScroll
        if not offset then return end
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        if scroll.GetVerticalScrollRange then offset=math.min(offset,scroll:GetVerticalScrollRange()) end
        scroll:SetVerticalScroll(offset)
    end)
    p.recipe:Hide()
    W.Hint(p.recipe,"Jump to this item's recipe and how to learn it.")
    p.track=W.Button(p.paper,"Track",88,31,function() local row=p.selectedRow; if row then XC:TrackItem(row,row.lane,false) end end)
    p.map=W.Button(p.paper,"Show on map",134,31,function() local row=p.selectedRow; if row then XC:MapTarget(row.source) end end)
    W.Hint(p.map,"Show the selected item's known source, recipe location or outdoor entrance on the map.")
    p.remove=W.Button(p.paper,"Remove",94,31,function()
        local row=p.selectedRow; if not row then return end
        if prefs().state=="removed" then XC:RestoreJournalEntry(row) else XC:RemoveJournalEntry(row) end
        prefs().selected=nil; XC:RenderJournal()
    end)
    p.chat=W.Button(p.paper,"Chat",68,31,function() if p.selectedRow then XC:LinkItem(p.selectedRow.item) end end)
    p.status=W.Text(p,"",12,self.Colors.muted,900)
    p.Layout=function(_,width,height)
        local v=prefs(); local profile=XC:GetProfile(XC.db.profile)
        p.profile.label:SetText((profile.spec or profile.label).."  >"); W.FitButton(p.profile,220)
        W.FitButton(p.filterButton,90); at(p.filterButton,width-p.filterButton:GetWidth()-8,0)
        at(p.profile,width-p.filterButton:GetWidth()-p.profile:GetWidth()-18,0)
        p.heading:SetWidth(width-p.profile:GetWidth()-p.filterButton:GetWidth()-42)
        p.heading:SetHeight(0); p.intro:SetHeight(0)
        local introY=math.max(p.heading:GetStringHeight(),p.profile:GetHeight(),p.filterButton:GetHeight())+10
        local slotLabel=v.slotID~=0 and XC:GetSlot(v.slotID).label or "All equipment"
        p.slotButton.label:SetText(slotLabel.."  >"); W.FitButton(p.slotButton,220)
        at(p.slotButton,8,introY)
        W.FitButton(p.destinationButton,134)
        at(p.destinationButton,p.slotButton:GetWidth()+18,introY)
        local introX=p.slotButton:GetWidth()+p.destinationButton:GetWidth()+32
        p.intro:SetWidth(math.max(1,width-introX-8)); at(p.intro,introX,introY+4)
        local introHeight=p.intro:GetStringHeight()
        p.intro:SetHeight(introHeight)
        local filterY=introY+math.max(p.slotButton:GetHeight(),p.destinationButton:GetHeight(),introHeight+4)+12
        W.FitButton(p.lane,180); W.FitButton(p.faction,185)
        at(p.lane,12,16); at(p.faction,24+p.lane:GetWidth(),16)
        local filterX=36+p.lane:GetWidth()+p.faction:GetWidth()
        for _,toggle in ipairs({p.solo,p.craft,p.auction}) do at(toggle,filterX,18); filterX=filterX+toggle:GetWidth()+toggle.label:GetStringWidth()+16 end
        local filterHeight=math.max(66,p.lane:GetHeight()+28,p.faction:GetHeight()+28)
        p.lookahead.label:SetText(lookaheadLabel(v.lookahead))
        W.FitButton(p.lookahead,122)
        if v.lane=="longterm" and v.state=="active" then
            local lookaheadX=width-28-p.lookahead:GetWidth()
            if lookaheadX<filterX then
                at(p.lookahead,12,filterHeight-6)
                filterHeight=filterHeight+p.lookahead:GetHeight()+6
            else
                at(p.lookahead,lookaheadX,16)
                filterHeight=math.max(filterHeight,p.lookahead:GetHeight()+28)
            end
        end
        local top=filterY+(v.filters and filterHeight+10 or 0)
        p.filters:SetShown(v.filters and true or false); at(p.filters,8,filterY); p.filters:SetSize(width-16,filterHeight)
        p.status:SetWidth(width-24)
        local statusHeight=p.status:GetStringHeight(); p.status:SetHeight(statusHeight)
        local tabWidths,tabTotal,tabHeight={},12,29
        for _,id in ipairs({"active","completed","removed"}) do
            p.tabs[id].label:SetWidth(0)
            tabWidths[id]=math.max(80,p.tabs[id].label:GetStringWidth()+20); tabTotal=tabTotal+tabWidths[id]
            tabHeight=math.max(tabHeight,p.tabs[id].label:GetStringHeight()+8)
        end
        local left=math.max(350,math.floor(width*.42),tabTotal); local right=width-left-20; local ph=height-top-statusHeight-22
        at(p.left,6,top); p.left:SetSize(left,ph); at(p.paper,left+18,top); p.paper:SetSize(right,ph)
        at(p.panorama,12,top+6); p.panorama:SetSize(left+right,math.max(1,ph-12))
        local tabX=6; local extra=(left-tabTotal)/3
        for _,id in ipairs({"active","completed","removed"}) do local b=p.tabs[id]; at(b,tabX,7); W.ResizeButton(b,tabWidths[id]+extra); b:SetHeight(tabHeight); tabX=tabX+b:GetWidth() end
        W.FitButton(p.clear,64)
        local searchY=tabHeight+16; local searchHeight=math.max(p.search:GetHeight(),p.clear:GetHeight())
        at(p.search,10,searchY); p.search:SetWidth(left-30-p.clear:GetWidth()); p.search:SetHeight(searchHeight)
        p.searchPrompt:SetWidth(p.search:GetWidth()-16); p.searchPrompt:SetHeight(0)
        at(p.searchPrompt,8,math.max(2,(searchHeight-p.searchPrompt:GetStringHeight())/2))
        at(p.clear,left-10-p.clear:GetWidth(),searchY)
        p.scroll:SetPoint("TOPLEFT",8,-(searchY+searchHeight+13))
        p.child:SetWidth(left-44); p.empty:SetWidth(left-60)
        W.FitButton(p.limit,128); W.FitButton(p.expand,110)
        local leftFooter=math.max(p.limit:GetHeight(),p.expand:GetHeight())
        at(p.limit,10,ph-leftFooter-12); at(p.expand,18+p.limit:GetWidth(),ph-leftFooter-12)
        p.body:SetWidth(right-54)
        p.map.label:SetText(right<450 and "Map" or "Show on map")
        local buttons={p.track,p.map,p.remove,p.chat}; local requested={80,112,92,62}
        local total,actionHeight=15,0
        for i,b in ipairs(buttons) do W.FitButton(b,requested[i]); total=total+b:GetWidth(); actionHeight=math.max(actionHeight,b:GetHeight()) end
        local wrap=total>right-28; local topY=ph-14-actionHeight*(wrap and 2 or 1)-(wrap and 6 or 0)
        local x=14
        for i,b in ipairs(buttons) do
            if wrap then at(b,14+((i-1)%2)*(right-28)/2,topY+math.floor((i-1)/2)*(actionHeight+6))
            else at(b,x,topY); x=x+b:GetWidth()+5 end
        end
        W.FitButton(p.sourceChoice,230); W.FitButton(p.recipe,84)
        local sourceY=topY-math.max(p.sourceChoice:GetHeight(),p.recipe:GetHeight())-8
        at(p.sourceChoice,14,sourceY); at(p.recipe,right-14-p.recipe:GetWidth(),sourceY)
        p.leftFooterInset=leftFooter+26
        p.actionInset=ph-topY+10
        p.sourceInset=ph-sourceY+10
        at(p.status,10,height-statusHeight-12)
        if XC.context and p:IsShown() and self.window:IsShown() then XC:RenderJournal() end
    end
end
function XC:RenderJournalDetail(row)
    local p=self.window.journal; local width=p.body:GetWidth()
    local comparisonSlot=row and row.slotID or (not p.destinationPickerOpen and prefs().slotID~=0 and prefs().slotID or nil)
    local detailKey=row and row.key or ("empty:"..tostring(comparisonSlot or "all"))
    if p.detailKey~=detailKey and p.detailScroll.SetVerticalScroll then p.detailScroll:SetVerticalScroll(0) end
    p.detailKey=detailKey
    p.selectedRow=row
    local hasRecipe=recipeSourceIndex(row)~=nil
    local alternateSource=row and row.sourceCount>1
    p.recipe:SetShown(hasRecipe)
    p.sourceChoice:SetShown(alternateSource)
    p.sourceChoice:SetWidth(p.paper:GetWidth()-28-(hasRecipe and p.recipe:GetWidth()+6 or 0))
    p.detailScroll:SetPoint("BOTTOMRIGHT",-32,(hasRecipe or alternateSource) and p.sourceInset or (row and p.actionInset or 16))
    p.recipeOffset=nil
    for _,b in ipairs({p.track,p.map,p.remove,p.chat}) do b:SetShown(row~=nil); b:SetEnabled(row~=nil) end
    p.sourceChoice:SetEnabled(alternateSource and true or false)
    p.title:SetShown(row==nil); p.description:SetShown(row==nil)
    p.equippedItem=nil; p.equippedChat:SetEnabled(false)
    for _,el in ipairs({p.equippedName,p.equippedStats,p.equippedScore}) do el:SetShown(comparisonSlot~=nil) end
    for _,el in ipairs({p.sourceHeading,p.source,p.location,p.comparison,p.stats,p.basis}) do el:SetShown(row~=nil) end
    p.equippedChat:Hide(); p.statChanges:Hide()
    p.compareHeading:SetShown(comparisonSlot~=nil)
    p.reward:SetShown(row~=nil)
    if comparisonSlot then
        local profile=self:GetProfile(self.db.profile)
        local equipped=self.context.equipped and self.context.equipped[comparisonSlot]
        local occupied=self.context.occupied and self.context.occupied[comparisonSlot]
        p.equippedItem=equipped
        if equipped then
            local equippedName=self.Client.Presentation(equipped)
            local equippedScore=not equipped.incomplete and self.Rules.Score(equipped,profile.weights,comparisonSlot,profile.weaponDpsSlots) or nil
            p.equippedName:SetText(equippedName)
            p.equippedStats:SetText(W.StatLine(equipped,profile.weights))
            p.equippedScore:SetText(equippedScore and string.format("%.1f model score",equippedScore) or "Incomplete stats")
            p.equippedChat:Show(); p.equippedChat:SetEnabled(true)
        elseif occupied then
            p.equippedName:SetText("Item data is loading")
            p.equippedStats:SetText(""); p.equippedScore:SetText("")
        else
            p.equippedName:SetText("Empty "..self:GetSlot(comparisonSlot).label:lower().." slot")
            p.equippedStats:SetText(""); p.equippedScore:SetText("")
        end
    else
        p.equippedName:SetText(""); p.equippedStats:SetText(""); p.equippedScore:SetText("")
    end
    if not row then
        p.title:SetText(p.destinationPickerOpen and "Choose a destination" or comparisonSlot and (self:GetSlot(comparisonSlot).label.." equipment") or "No gear selected")
        p.description:SetText(p.destinationPickerOpen and "Select a dungeon or quest zone to see its matching gear."
            or "Items that match your search and filters appear on the left.")
        p.source:SetText("No item selected."); p.location:SetText(""); p.comparison:SetText(""); p.stats:SetText(""); p.basis:SetText("")
    else
        local name,icon,_,quality=self.Client.Presentation(row.item)
        p.rewardName:SetText(name); p.rewardName:SetWidth(width-80); p.rewardName:SetHeight(0)
        local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        p.rewardName:SetTextColor(color and color.r or 1,color and color.g or 1,color and color.b or 1)
        p.rewardIcon:SetTexture(icon)
        p.sourceHeading:SetText(row.source.kind=="craft" and "RECIPE" or "SOURCE")
        p.source:SetText(self:SourceText(row.source))
        local nav=self.Navigation.Resolve(row.source)
        if nav.point then
            local map=self.Client.Safe(C_Map and C_Map.GetMapInfo,nav.point.mapID)
            local mapName=map and map.name or nav.point.label or row.source.zone
            p.location:SetText(string.format("%s%.1f, %.1f\n%s",mapName and mapName.." / " or "",nav.point.x,nav.point.y,nav.message or ""))
        else p.location:SetText(nav.message or "Location not available yet. You can still track this item.") end
        local state=prefs().state
        local status=state=="completed" and "Obtained" or self:Availability(row)
        local key=tostring(row.item.id)
        if self.db.activeHunt==key and state~="completed" then status="Tracking / "..status
        elseif self.db.pins[key] and state~="completed" then status="Saved hunt / "..status end
        p.rewardMeta:SetText(status)
        local profile=self:GetProfile(self.db.profile)
        local scoreText=string.format("%.1f model score",row.score or 0)
        if row.delta and p.equippedItem then scoreText=string.format("%+.1f vs equipped / %s",row.delta,scoreText)
        elseif not row.delta then scoreText=scoreText.." / comparison unavailable" end
        p.comparison:SetText(scoreText)
        p.stats:SetText("Target stats: "..W.StatLine(row.item,profile.weights))
        local comparableStats=row.delta and p.equippedItem and p.equippedItem.stats
        p.statChanges:SetShown(comparableStats and true or false)
        if comparableStats then p.statChanges:SetText("Stat changes: "..W.StatLine(row.item,profile.weights,p.equippedItem)) end
        local weightBasis=self.db.weights[profile.id] and "Custom stat weights" or "Starter role weights"
        p.basis:SetText((row.item.basis=="live" and "Client stats" or row.item.basis=="forever" and "Forever snapshot" or "Classic baseline; verify in Forever").." / "..weightBasis..". Score covers base stats.")
        p.sourceChoice.label:SetText(string.format("Source %d / %d  >",row.sourceIndex,row.sourceCount))
        p.remove.label:SetText(state=="removed" and "Restore" or "Remove")
        W.Tooltip(p.rewardButton,row.item)
        p.rewardButton:SetScript("OnClick",function(_,button) W.ItemClick(row.item,function() XC:TrackItem(row,row.lane,false) end,button) end)
    end
    local y=0
    if row then
        at(p.reward,0,y); p.reward:SetWidth(width)
        p.rewardMeta:SetWidth(width-80); p.rewardMeta:SetHeight(0)
        at(p.rewardMeta,63,14+p.rewardName:GetStringHeight())
        p.reward:SetHeight(math.max(66,p.rewardName:GetStringHeight()+p.rewardMeta:GetStringHeight()+27)); y=y+p.reward:GetHeight()+12
        y=flow(p.comparison,0,y,width)+5
        if p.statChanges:IsShown() then y=flow(p.statChanges,0,y,width)+5 end
        y=flow(p.stats,0,y,width)+15
        if row.source.kind=="craft" then p.recipeOffset=math.max(0,y-8) end
        y=flow(p.sourceHeading,0,y,width)+5; y=flow(p.source,0,y,width)+6
        y=flow(p.location,0,y,width)+17
    else
        y=flow(p.title,0,y,width)+8
        y=flow(p.description,0,y,width)+15
    end
    if comparisonSlot then
        y=flow(p.compareHeading,0,y,width)+5
        y=flow(p.equippedName,0,y,width)+6
        if p.equippedItem then
            y=flow(p.equippedStats,0,y,width)+6
            y=flow(p.equippedScore,0,y,width)+8
            W.FitButton(p.equippedChat,130); at(p.equippedChat,0,y); y=y+p.equippedChat:GetHeight()+12
        end
    end
    if row then y=flow(p.basis,0,y,width)+10 end
    p.body:SetHeight(y)
end
function XC:RenderJournal()
    local p=self.window and self.window.journal
    if not p or not p:IsShown() or not self.context then return end
    local v=prefs(); local profile=self:GetProfile(self.db.profile)
    p.heading:SetText("Level "..self.context.level.." "..(self.ClassLabels[self.context.class] or self.context.class))
    p.profile.label:SetText((profile.spec or profile.label).."  >")
    local weights={}; for key,value in pairs(profile.weights) do weights[#weights+1]=key.."="..value end; table.sort(weights)
    W.Hint(p.profile,profile.label.."\n"..(self.db.weights[profile.id] and "Custom stat weights" or "Starter role weights").."\n"..table.concat(weights,"  ").."\nClick to change spec. /uc weights edits this spec's weights.")
    p.lane.label:SetText(laneLabels[v.lane].."  >")
    p.lookahead:SetShown(v.lane=="longterm" and v.state=="active")
    local slotLabel=v.slotID~=0 and self:GetSlot(v.slotID).label or "All equipment"
    p.slotButton.label:SetText(slotLabel..(p.slotPickerOpen and "  <" or "  >"))
    p.destinationButton.label:SetText("Destinations"..(p.destinationPickerOpen and "  <" or "  >"))
    p.intro:SetText(filterSummary(v,self.db.options,self.context))
    local hasResults=not p.slotPickerOpen and not p.destinationPickerOpen
    p.searchPrompt:SetShown((p.query or "")=="" and not p.search.edit:HasFocus())
    p.clear:SetEnabled((p.query or "")~="")
    p.limit:SetShown(hasResults and v.state=="active")
    local hasCollapsed=false
    for _,collapsed in pairs(v.collapsed) do if collapsed then hasCollapsed=true; break end end
    p.expand:SetShown(hasResults and hasCollapsed)
    p.scroll:SetPoint("BOTTOMRIGHT",-28,hasResults and (v.state=="active" or hasCollapsed) and p.leftFooterInset or 12)
    W.Hint(p.search,p.destinationPickerOpen and "Filter destinations by matching item or source."
        or "Search item, boss, quest, recipe source or zone names. Paste an item link or enter its ID to find a specific item.")
    p.faction.label:SetText(self.Rules.FactionLabels[self.Rules.FactionMode(self.db.options,self.context)].."  >")
    p.solo:SetChecked(self.db.options.solo); p.craft:SetChecked(self.db.options.crafted); p.auction:SetChecked(self.db.options.auction)
    for id,b in pairs(p.tabs) do W.SelectRow(b,id==v.state) end
    p.limit.label:SetText((v.limit==0 and "All" or v.limit).." / slot  >")
    local entries=self:GetJournalEntries(v.state,p.query,p.slotPickerOpen and 0 or v.slotID,v.lane,{
        destination=not p.destinationPickerOpen and v.destination or nil,lookahead=v.lookahead,
    })
    p.entries=entries
    local selected
    for _,row in ipairs(entries) do if row.key==v.selected then selected=row; break end end
    selected=selected or entries[1]
    if hasResults then v.selected=selected and selected.key or nil end
    hide(p.rows); p.slotChoices={}; p.destinationChoices={}; local y,index,slotID,count=0,0,nil,0
    local function nextRow()
        index=index+1
        if not p.rows[index] then p.rows[index]=W.JournalRow(p.child,"",p.child:GetWidth(),28) end
        local b=p.rows[index]; b:Show(); b:SetWidth(p.child:GetWidth()); b.label:SetWidth(p.child:GetWidth()-20); return b
    end
    if p.destinationPickerOpen then
        local groups=self:GetJournalDestinations(entries)
        local function destinationRow(label,key,description,handler)
            local b=nextRow()
            b.label:SetText(label); b.label:SetHeight(0); b.label:SetWordWrap(true)
            b:SetHeight(math.max(28,b.label:GetStringHeight()+8)); at(b,0,y); y=y+b:GetHeight()+2
            b:RegisterForClicks("LeftButtonUp")
            b:SetScript("OnEnter",function(button)
                button:JournalHover(true)
                if description then
                    GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); GameTooltip:SetText(description); GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave",function(button) button:JournalHover(false); GameTooltip:Hide() end)
            b:SetScript("OnClick",handler)
            W.SelectJournalRow(b,key and key==(v.destination or "all"),key and self.Colors.text or self.Colors.gold)
            if key then p.destinationChoices[key]=b end
        end
        local function selectDestination(key,label)
            v.destination=key; v.destinationLabel=label; v.selected=nil
            p.destinationPickerOpen=false
            if p.scroll.SetVerticalScroll then p.scroll:SetVerticalScroll(0) end
            self:RenderJournal()
        end
        destinationRow("All destinations","all",nil,function() selectDestination() end)
        local function showDestination(group,here)
            local key,label=group.key,group.label
            local range=group.minLevel==group.maxLevel and tostring(group.minLevel) or (group.minLevel.."–"..group.maxLevel)
            local labelText=string.format("%s%s\n%d %s / Lv %s%s",label,here and " (This zone)" or "",group.count,
                group.count==1 and "target" or "targets",range,v.state=="active" and group.later>0 and (" / "..group.later.." later") or "")
            destinationRow(labelText,key,"Counts matching gear in the catalog. Levels reflect item and known source requirements.",function() selectDestination(key,label) end)
        end
        local here=currentDestination(groups)
        if here then showDestination(here,true) end
        local kind
        for _,group in ipairs(groups) do
            if group~=here then
                if kind~=group.kind then
                    kind=group.kind
                    destinationRow(kind=="dungeon" and "DUNGEONS" or "QUEST ZONES")
                end
                showDestination(group,false)
            end
        end
        if #groups==0 then destinationRow("No destinations match the current filters.") end
    elseif p.slotPickerOpen then
        local choices={{id=0,label="All equipment"}}
        local counts={[0]=#entries}
        for _,row in ipairs(entries) do counts[row.slotID]=(counts[row.slotID] or 0)+1 end
        for _,slot in ipairs(self.Slots) do choices[#choices+1]=slot end
        for _,slot in ipairs(choices) do
            local id=slot.id; local b=nextRow(); p.slotChoices[id]=b
            b.label:SetText(string.format("%s  (%d)",slot.label,counts[id] or 0)); b.label:SetHeight(0); b.label:SetWordWrap(true)
            b:SetHeight(math.max(28,b.label:GetStringHeight()+8)); at(b,0,y); y=y+b:GetHeight()+2
            b:RegisterForClicks("LeftButtonUp")
            b:SetScript("OnEnter",function(button) button:JournalHover(true) end)
            b:SetScript("OnLeave",function(button) button:JournalHover(false); GameTooltip:Hide() end)
            b:SetScript("OnClick",function() XC:SetJournalSlot(id) end)
            W.SelectJournalRow(b,id==v.slotID,self.Colors.text)
        end
    else for _,row in ipairs(entries) do
        if row.slotID~=slotID then
            slotID=row.slotID; count=0; local id=slotID
            local b=nextRow(); b.label:SetText((v.collapsed[id] and "+  " or "-  ")..self:GetSlot(id).label)
            b:SetScript("OnEnter",function(button) button:JournalHover(true) end)
            b:SetScript("OnLeave",function(button) button:JournalHover(false); GameTooltip:Hide() end)
            b.label:SetHeight(0); b:SetHeight(math.max(29,b.label:GetStringHeight()+8)); at(b,0,y); y=y+b:GetHeight()+2
            W.SelectJournalRow(b,false,self.Colors.gold)
            b:SetScript("OnClick",function()
                v.collapsed[id]=not v.collapsed[id] and true or nil
                XC:RenderJournal()
            end)
        end
        count=count+1
        if not v.collapsed[slotID] and (v.state~="active" or v.limit==0 or count<=v.limit) then
            local itemRow=row; local b=nextRow(); local name,_,_,quality=self.Client.Presentation(row.item)
            local tracked=self.db.pins[tostring(row.item.id)] and " *" or ""
            b.label:SetText("    "..(v.state=="active" and ("#"..count.."  ") or "")..name..tracked)
            b.label:SetHeight(0); b.label:SetWordWrap(true); b:SetHeight(math.max(28,b.label:GetStringHeight()+6)); at(b,0,y); y=y+b:GetHeight()+2
            local c=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            W.SelectJournalRow(b,row.key==v.selected,c and {c.r,c.g,c.b} or self.Colors.text)
            b:RegisterForClicks("LeftButtonUp","RightButtonUp"); W.Tooltip(b,row.item,"Click: inspect this hunt / Shift-click or right-click: chat")
            b:SetScript("OnClick",function(_,button) W.ItemClick(itemRow.item,function()
                if v.selected~=itemRow.key and p.detailScroll.SetVerticalScroll then p.detailScroll:SetVerticalScroll(0) end
                v.selected=itemRow.key; XC:RenderJournal()
            end,button) end)
        end
    end end
    p.empty:SetShown(not p.slotPickerOpen and not p.destinationPickerOpen and #entries==0)
    p.empty:SetText(v.state=="removed" and "No removed hunts. Remove hides an item here without deleting its saved notes." or v.state=="completed" and "No obtained items match. Tracking a hunt does not mark it completed." or "No hunts match. Clear search, change filters, choose another equipment slot or add an item.")
    p.child:SetHeight(math.max(100,y+12))
    p.status:SetText(p.destinationPickerOpen and "Counts reflect matching gear in the catalog."
        or p.slotPickerOpen and "Choose an equipment slot."
        or string.format("%d matching %s",#entries,#entries==1 and "item" or "items"))
    if math.abs(p.status:GetHeight()-p.status:GetStringHeight())>.5 or math.abs(p.intro:GetHeight()-p.intro:GetStringHeight())>.5 then
        p:ApplyLayout(); return
    end
    self:RenderJournalDetail(hasResults and selected or nil)
end
