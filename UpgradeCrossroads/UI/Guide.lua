local _, XC = ...
local W=XC.W
local function at(f,x,y) f:SetPoint("TOPLEFT",x,-y); return f end
function XC:AllowedSources(item,lane)
    local out={}; local context=self.context or self.Client.Context()
    for _,source in ipairs(item.sources or {}) do
        local grouped=source.kind=="dungeon" or source.kind=="raid" or source.group
        local fits=lane==nil or lane=="longterm" or (lane=="dungeon" and grouped) or (lane=="reliable" and not grouped and source.kind~="world")
        local levelOK=lane==nil or lane=="longterm" or math.max(item.req or 0,source.minLevel or 0)<=context.level
        if fits and levelOK and self.Rules.SourceAllowed(source,context,self.db.options) then out[#out+1]=source end
    end
    return out
end
function XC:DisplayRow(lane)
    local original=self.lanes and self.lanes[lane] and self.lanes[lane][self.selection[lane] or 1]
    if not original then return nil end
    local row={}; for k,v in pairs(original) do row[k]=v end
    local sources=self:AllowedSources(row.item,lane)
    self.sourceSelection=self.sourceSelection or {}
    local key=lane..":"..row.item.id
    local index=self.sourceSelection[key]
    if not index then
        index=1
        for i,source in ipairs(sources) do if source==original.source then index=i; break end end
    end
    index=math.max(1,math.min(#sources,index))
    row.source=sources[index] or original.source; row.sourceIndex=index; row.sourceCount=#sources
    row.minLevel=math.max(row.item.req or 0,row.source.minLevel or 0)
    row.locked=row.minLevel>(self.context and self.context.level or UnitLevel("player"))
    return row
end
function XC:CycleCardSource(lane)
    local row=self:DisplayRow(lane); if not row or row.sourceCount<2 then return end
    self.sourceSelection[lane..":"..row.item.id]=row.sourceIndex%row.sourceCount+1
    self:Render()
end
function XC:EnsureHunt(row,lane)
    local key=tostring(row.item.id); local pin=self.db.pins[key]
    if not pin then
        self.db.pinOrder=self.db.pinOrder+1
        pin={item=row.item,source=row.source,lane=lane,addedAt=time(),order=self.db.pinOrder,checks={},notes=""}
        self.db.pins[key]=pin
    elseif self.Navigation.SourceKey(pin.source)~=self.Navigation.SourceKey(row.source) then
        pin.source=row.source; pin.lane=lane; pin.checks={}
    end
    return pin
end
function XC:TrackItem(row,lane,showMap)
    if not row then return end
    if InCombatLockdown() then self:Print("Start or change tracking after combat."); return end
    local pin=self:EnsureHunt(row,lane)
    self.db.activeHunt=tostring(pin.item.id)
    self.db.trackerHidden=nil
    self.Client.UpdatePins()
    self:BuildGuide()
    local result=self.Navigation.Resolve(pin.source)
    if not result.point and result.status~="quest" then self.Navigation.ReleaseOwnedWaypoint() end
    local ok,message=self.Navigation.Apply(result,showMap)
    self.guideMessage=message
    self.guideNavKey=ok and self.Navigation.Signature(result,pin.item.id) or nil
    if self.window and self.window:IsShown() then self.window:Hide() end
    self:RenderGuide()
    if showMap and not result.point and result.status~="quest" then self:Print(message) end
end
function XC:BuildGuide()
    if self.guide then return end
    local f=W.Panel(UIParent,360,470,self.Colors.bg); self.guide=f
    f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-35,-210); f:SetFrameStrata("HIGH"); f:Hide()
    f.title=at(W.Text(f,"Gear hunt",14,self.Colors.reliable),16,20)
    f.description=at(W.Text(f,"Your next step and source.",12,self.Colors.muted,328),16,54)
    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT",16,-92); f.scroll:SetPoint("BOTTOMRIGHT",-35,139)
    f.content=CreateFrame("Frame",nil,f.scroll); f.content:SetSize(309,240); f.scroll:SetScrollChild(f.content)
    f.name=at(W.Text(f.content,"",17,self.Colors.text,309),0,0); f.name:SetHeight(48)
    f.itemButton=CreateFrame("Button",nil,f.content); at(f.itemButton,0,0); f.itemButton:SetSize(309,53); f.itemButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    f.step=at(W.Text(f.content,"",13,self.Colors.reliable,309),0,62); f.step:SetHeight(62)
    f.source=at(W.Text(f.content,"",12,self.Colors.text,309),0,134); f.source:SetHeight(45)
    f.status=at(W.Text(f.content,"",11,self.Colors.muted,309),0,188); f.status:SetHeight(50)
    f.map=W.Button(f,"Show on map",156,29,function()
        local pin=self.db.pins[self.db.activeHunt or ""]
        if pin then self:TrackItem({item=pin.item,source=pin.source},pin.lane,true) end
    end,{.10,.28,.26,1})
    f.location=W.Button(f,"Set location",156,29,function()
        local pin=self.db.pins[self.db.activeHunt or ""]
        if pin then self:BuildUI(); self.window:Show(); self:ShowTargetEditor({item=pin.item,source=pin.source},pin.lane) end
    end)
    W.Hint(f.location,"Fill in missing map coordinates for this source. Item and source are already selected.")
    f.next=W.Button(f,"Step done",156,26,function()
        local pin=self.db.pins[self.db.activeHunt or ""]
        if pin then for i=1,3 do if not pin.checks[i] then pin.checks[i]=true; break end end; self:RenderGuide() end
    end)
    f.stop=W.Button(f,"Stop tracking",156,26,function()
        self.Navigation.ReleaseOwnedWaypoint(); self.db.activeHunt=nil; self.guideMessage=nil; self.guideNavKey=nil
        f:Hide(); if self.window and self.window:IsShown() then self:Render() end
    end)
    W.Hint(f.stop,"Hide this tracker and release its waypoint. The hunt and notes stay saved.")
    f.chat=W.Button(f,"Chat",70,24,function()
        local pin=self.db.pins[self.db.activeHunt or ""]; if pin then self:LinkItem(pin.item) end
    end)
    f.tip=W.Text(f,"Shift-click: link",10,self.Colors.muted,230)
    XC.db.windows=XC.db.windows or {}
    if not XC.db.windows.tracker and XC.db.guidePosition then XC.db.windows.tracker={position=XC.db.guidePosition} end
    W.Resizable(f,"tracker",330,330,function(_,width,height)
        local inner=width-32; local half=(inner-12)/2
        f.content:SetWidth(width-51)
        for _,el in ipairs({f.name,f.step,f.source,f.status}) do el:SetWidth(width-51) end
        f.itemButton:SetWidth(width-51)
        for _,b in ipairs({f.map,f.location,f.next,f.stop}) do W.ResizeButton(b,half) end
        local needed=math.max(f.map:GetWidth()+f.location:GetWidth(),f.next:GetWidth()+f.stop:GetWidth())+44
        if needed>width+1 then f:SetWidth(needed); return end
        local nextY=height-30-math.max(f.next:GetHeight(),f.stop:GetHeight())
        local mapY=nextY-8-math.max(f.map:GetHeight(),f.location:GetHeight())
        local chatY=mapY-8-f.chat:GetHeight()
        at(f.map,16,mapY); at(f.location,28+half,mapY)
        at(f.next,16,nextY); at(f.stop,28+half,nextY)
        at(f.chat,width-94,chatY); at(f.tip,16,chatY+3); f.tip:SetWidth(width-126)
        f.scroll:SetPoint("BOTTOMRIGHT",-35,height-chatY+8)
        if f.ReflowContent then f:ReflowContent() end
    end)
    f.ReflowContent=function()
        local y=0
        for _,el in ipairs({f.name,f.step,f.source,f.status}) do
            el:SetHeight(0); local h=el:GetStringHeight(); el:SetHeight(h)
            W.Place(el,0,y); y=y+h+15
            if el==f.name then f.itemButton:SetHeight(h) end
        end
        f.content:SetHeight(y)
    end
    f.closeButton:SetScript("OnClick",function() self.db.trackerHidden=true; f:Hide() end)
end
function XC:RenderGuide()
    if not self.db then return end
    local pin=self.db.pins[self.db.activeHunt or ""]
    if not pin then if self.guide then self.guide:Hide() end; return end
    self:BuildGuide()
    local f=self.guide
    local browsing=self.window and self.window:IsShown()
    f:SetShown(not self.db.trackerHidden and not browsing)
    f.name:SetText(pin.item.name)
    W.Tooltip(f.itemButton,pin.item,"Shift-click or right-click: chat")
    f.itemButton:SetScript("OnClick",function(_,button) W.ItemClick(pin.item,nil,button) end)
    local result=self.Navigation.Resolve(pin.source)
    -- Only change navigation when the active guide's destination changes.
    -- Ordinary bag events do not repeatedly seize the user's waypoint.
    local navKey=self.Navigation.Signature(result,pin.item.id)
    if not pin.acquired and self.guideNavKey~=navKey and not InCombatLockdown() then
        local ok=self.Navigation.Apply(result,false)
        if ok then self.guideNavKey=navKey end
    end
    local tasks={"Confirm requirements and availability.","Prepare access, materials or your group.","Obtain "..pin.item.name.."."}
    if pin.source.kind=="quest" then tasks={"Find and accept "..pin.source.name..".","Complete the quest objectives.","Turn in and select your item reward."} end
    if pin.source.kind=="craft" then tasks={"Find a crafter or learn recipe #"..tostring(pin.source.spellID or "?")..".","Collect the materials for this recipe.","Craft or receive "..pin.item.name.."."} end
    if pin.source.kind=="dungeon" or pin.source.kind=="raid" then tasks={"Check access and travel to "..(pin.source.zone or "the instance")..".","Form your group and defeat "..pin.source.name..".","Loot the item; repeat eligible runs if needed."} end
    local step=1
    while step<=3 and pin.checks[step] do step=step+1 end
    local otherFaction=self.Rules.OtherFaction(pin.source,self.context or self.Client.Context())
    if pin.acquired then f.step:SetText("OBTAINED / "..pin.item.name)
    elseif otherFaction then f.step:SetText((pin.source.side==1 and "Alliance" or "Horde").." source. This character cannot complete this source.")
    elseif step>3 then f.step:SetText("Checklist complete. Item ownership has not been confirmed.")
    elseif result.prerequisite and not pin.checks[1] then f.step:SetText("NEXT KNOWN PREREQUISITE\n"..(result.questName or "Check the quest chain"))
    elseif result.status=="quest" then f.step:SetText((result.prerequisite and "PREREQUISITE / " or "QUEST / ")..(result.questName or pin.source.name).."\nFollow the tracked quest objective.")
    else f.step:SetText("STEP "..step.." OF 3 / "..tasks[step]) end
    f.source:SetText(self:SourceText(pin.source))
    local label=result.point and (result.point.basis..(result.point.entrance and " / entrance only" or "")) or result.message
    if result.warning then label=result.warning end
    f.status:SetText(label)
    f.next:SetEnabled(not pin.acquired and not otherFaction and step<=3)
    f.map.label:SetText((result.point or result.status=="quest") and "Show on map" or "Retry location")
    f:ReflowContent()
end
