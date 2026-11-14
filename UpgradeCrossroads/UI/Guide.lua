local _, XC = ...
local W=XC.W
local at=W.Place
local huntWaypoint="hunt"

function XC:EnsureHunt(row,lane)
    local key=tostring(row.item.id)
    local pin=self.db.pins[key]
    if not pin then
        self.db.pinOrder=self.db.pinOrder+1
        pin={item=row.item,source=row.source,lane=lane,addedAt=time(),order=self.db.pinOrder,checks={},notes=""}
        self.db.pins[key]=pin
    elseif self.Navigation.SourceKey(pin.source)~=self.Navigation.SourceKey(row.source) then
        pin.source=row.source
        pin.lane=lane
        pin.checks={}
    end
    pin.checks=pin.checks or {}
    return pin
end

function XC:RefreshSavedHuntSources()
    for _,pin in pairs(self.db.pins) do
        local item=pin.item and self.Catalog[pin.item.id]
        local savedSource=pin.source
        if item and savedSource and not savedSource.personal then
            local key=self.Navigation.SourceKey(savedSource)
            for _,source in ipairs(item.sources) do
                if self.Navigation.SourceKey(source)==key then
                    pin.item=item
                    pin.source=source
                    break
                end
            end
        end
    end
end

function XC:HuntChecklist(pin)
    local kind=pin.source.kind
    local tasks={"Check requirements and availability","Prepare access, materials or a group","Obtain the item"}
    if kind=="quest" then
        tasks={"Find the quest and check prerequisites","Complete the quest objectives","Turn in and pick up the reward"}
    elseif kind=="craft" then
        tasks={"Check the recipe source","Collect the required materials","Craft or receive the item"}
    elseif kind=="dungeon" or kind=="raid" then
        tasks={"Check access and travel to the instance","Defeat "..pin.source.name,"Loot the item from an eligible run"}
    end
    local step,done=nil,0
    for i=1,#tasks do
        if pin.acquired or (pin.checks and pin.checks[i]) then
            done=done+1
        elseif not step then
            step=i
        end
    end
    return tasks,step,done
end

local function huntBlock(pin)
    if pin.acquired then return "Item obtained" end
    local level=UnitLevel("player")
    local required=pin.source.minLevel or 0
    local faction=UnitFactionGroup("player")
    local side=faction=="Alliance" and 1 or (faction=="Horde" and 2 or 0)
    if XC.Rules.OtherFaction(pin.source,{side=side}) then
        return (pin.source.side==1 and "Alliance" or "Horde").." source"
    end
    if required>(level or 0) then return "Available at level "..required end
end

function XC:StopHunt()
    self.Navigation.ReleaseOwnedWaypoint(huntWaypoint)
    self.db.activeHunt=nil
    self.db.trackerHidden=nil
    self.guideNavKey=nil
    if self.guide then self.guide:Hide() end
end

local function huntDestination(pin)
    local blocked=huntBlock(pin)
    if blocked then return nil,blocked end
    return XC.Navigation.Resolve(pin.source)
end

local function syncDestination(pin,result,showMap,requested)
    if InCombatLockdown() then return end
    local nav=XC.Navigation
    if not result then
        nav.ReleaseOwnedWaypoint(huntWaypoint)
        XC.guideNavKey=nil
        return
    end
    local key=nav.Signature(result,pin.item.id)
    if not requested and key==XC.guideNavKey then return end
    XC.guideNavKey=key
    if result.status=="quest" or not result.point then nav.ReleaseOwnedWaypoint(huntWaypoint) end
    local ok,message=nav.Apply(result,showMap,huntWaypoint)
    if showMap and not ok and message then XC:Print(message) end
end

function XC:TrackItem(row,lane,showMap)
    if not row then return end
    if InCombatLockdown() then self:Print("Start or change tracking after combat."); return end
    local pin=self:EnsureHunt(row,lane)
    self.db.activeHunt=tostring(pin.item.id)
    self.db.trackerHidden=nil
    self.Client.UpdatePins()
    self:BuildGuide()
    syncDestination(pin,huntDestination(pin),showMap,true)
    if self.window and self.window:IsShown() then self.window:Hide() end
    self:RenderGuide()
end

local function firstObjective(questID)
    local api=C_QuestLog or {}
    local safe=XC.Client.Safe
    if safe(api.IsComplete,questID) then return "Ready to turn in." end
    local objectives=safe(api.GetQuestObjectives,questID)
    if type(objectives)~="table" or (issecretvalue and issecretvalue(objectives)) then return end
    for _,objective in ipairs(objectives) do
        if type(objective)=="table" and not (issecretvalue and issecretvalue(objective))
            and not (issecretvalue and (issecretvalue(objective.finished) or issecretvalue(objective.text)))
            and objective.finished==false and type(objective.text)=="string" and objective.text~="" then
            return objective.text
        end
    end
end

function XC:BuildGuide()
    if self.guide then return end
    local f=W.Panel(UIParent,360,470,self.Colors.bg); self.guide=f
    f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-35,-210)
    f:SetFrameStrata("HIGH")
    f:Hide()
    f.title=W.Text(f,"Hunt tracker",16,self.Colors.gold,nil,true)

    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT",16,-62)
    f.scroll:SetPoint("BOTTOMRIGHT",-35,127)
    f.content=CreateFrame("Frame",nil,f.scroll)
    f.content:SetSize(309,240)
    f.scroll:SetScrollChild(f.content)

    f.itemButton=CreateFrame("Button",nil,f.content)
    f.itemButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    f.icon=f.itemButton:CreateTexture(nil,"ARTWORK")
    f.icon:SetSize(32,32)
    at(f.icon,0,0)
    f.name=W.Text(f.itemButton,"",17,self.Colors.text,267,true)
    f.step=W.Text(f.content,"",13,self.Colors.gold,309)
    f.progress=W.Text(f.content,"",11,self.Colors.muted,309)
    f.source=W.Text(f.content,"",12,self.Colors.text,309)
    f.status=W.Text(f.content,"",11,self.Colors.muted,309)
    f.map=W.Button(f,"Show on map",140,27,function()
        if InCombatLockdown() then self:Print("Change the map waypoint after combat."); return end
        local pin=self.db.pins[self.db.activeHunt or ""]
        if pin then
            syncDestination(pin,huntDestination(pin),true,true)
            self:RenderGuide()
        end
    end)
    f.location=W.Button(f,"Set location",140,27,function()
        if InCombatLockdown() then self:Print("Edit source locations after combat."); return end
        local pin=self.db.pins[self.db.activeHunt or ""]
        if pin then self:ShowTargetEditor({item=pin.item,source=pin.source},pin.lane) end
    end)
    W.Hint(f.location,"Save map coordinates for this source.")
    f.next=W.Button(f,"Step done",140,27,function()
        local pin=self.db.pins[self.db.activeHunt or ""]
        if not pin or huntBlock(pin) then return end
        local _,step=self:HuntChecklist(pin)
        if step then pin.checks[step]=true; self:RenderGuide() end
    end)
    W.Hint(f.next,"Check off the current manual step. Live quest objectives update automatically.")
    f.stop=W.Button(f,"Stop tracking",140,27,function() self:StopHunt() end)
    W.Hint(f.stop,"Close the tracker. The hunt and notes stay saved.")
    f.hunts=W.Button(f,"Open Hunts",140,26,function()
        if InCombatLockdown() then self:Print("Open Hunts after combat."); return end
        self:ShowHunts()
    end)
    W.Hint(f.hunts,"Go to your hunt queue, checklists and notes.")
    f.chat=W.Button(f,"Chat",140,26,function()
        local pin=self.db.pins[self.db.activeHunt or ""]
        if pin then self:LinkItem(pin.item) end
    end)

    local function layoutFooter(_,width,height)
        local inner=width-32
        local half=(inner-12)/2
        f.content:SetWidth(width-51)
        for _,el in ipairs({f.step,f.progress,f.source,f.status}) do el:SetWidth(width-51) end
        f.itemButton:SetWidth(width-51)
        f.name:SetWidth(width-93)
        local widest=0
        for _,button in ipairs({f.map,f.location,f.next,f.stop,f.hunts,f.chat}) do
            W.ResizeButton(button,half)
            widest=math.max(widest,button:GetWidth())
        end
        local needed=2*widest+44
        if needed>width+1 then f:SetWidth(needed); return end
        local nextY=height-30-math.max(f.next:GetHeight(),f.stop:GetHeight())
        local mapY=nextY-8-math.max(f.map:GetHeight(),f.location:GetHeight())
        local huntsY=mapY-8-math.max(f.hunts:GetHeight(),f.chat:GetHeight())
        at(f.map,16,mapY); at(f.location,28+half,mapY)
        at(f.next,16,nextY); at(f.stop,28+half,nextY)
        at(f.hunts,16,huntsY); at(f.chat,28+half,huntsY)
        f.scroll:SetPoint("BOTTOMRIGHT",-35,height-huntsY+8)
        if f.ReflowContent then f:ReflowContent() end
    end
    function f:ReflowContent()
        at(self.itemButton,0,0)
        at(self.name,42,0)
        self.name:SetHeight(0)
        local nameHeight=self.name:GetStringHeight()
        self.name:SetHeight(nameHeight)
        local top=math.max(32,nameHeight)
        self.itemButton:SetHeight(top)
        local y=top+12
        for _,el in ipairs({self.step,self.progress,self.source,self.status}) do
            local content=el:GetText()
            local visible=content and content~=""
            el:SetShown(visible)
            if visible then
                el:SetHeight(0)
                local h=el:GetStringHeight()
                el:SetHeight(h)
                at(el,0,y)
                y=y+h+10
            end
        end
        self.content:SetHeight(y)
    end
    self.db.windows=self.db.windows or {}
    if not self.db.windows.tracker and self.db.guidePosition then self.db.windows.tracker={position=self.db.guidePosition} end
    W.Resizable(f,"tracker",330,330,layoutFooter)
    W.OrnateShell(f)
    f.closeButton:SetScript("OnClick",function() self.db.trackerHidden=true; f:Hide() end)
end

function XC:RenderGuide()
    if not self.db then return end
    local pin=self.db.pins[self.db.activeHunt or ""]
    if not pin then
        if self.guide then self.guide:Hide() end
        return
    end
    self:BuildGuide()
    local f=self.guide
    local browsing=self.window and self.window:IsShown()
    f:SetShown(not self.db.trackerHidden and not browsing)
    local name,icon=self.Client.Presentation(pin.item)
    f.name:SetText(name)
    f.icon:SetTexture(icon)
    W.Tooltip(f.itemButton,pin.item,"Shift-click or right-click: chat")
    f.itemButton:SetScript("OnClick",function(_,button) W.ItemClick(pin.item,nil,button) end)
    if f.pin~=pin then
        f.pin=pin
        if f.scroll.SetVerticalScroll then f.scroll:SetVerticalScroll(0) end
    end

    local result,blocked=huntDestination(pin)
    syncDestination(pin,result,false,false)
    local tasks,step,done=self:HuntChecklist(pin)
    local text,status
    if blocked then
        text=blocked
    elseif result.status=="quest" then
        local prefix=result.prerequisite and "Prerequisite" or "Quest"
        text=prefix.." / "..(result.questName or pin.source.name).."\n"
            ..(firstObjective(result.questID) or "Follow the tracked quest objective.")
    elseif result.prerequisite then
        text="Next prerequisite / "..(result.questName or "Check the quest chain")
    elseif result.status=="completed" then
        text="Reward quest completed"
    elseif step then
        text=tasks[step]
    else
        text="Checklist complete"
        status="Item ownership has not been confirmed."
    end
    if result then
        local p=result.point
        status=result.warning or status or (p and (p.basis..(p.entrance and " / entrance only" or "")) or result.message)
        if pin.source.kind=="craft" then status=result.message end
        local equipLevel=pin.item.req or 0
        if equipLevel>(UnitLevel("player") or 0) then
            local equip="Equip at level "..equipLevel.."."
            status=status and (equip.."\n"..status) or equip
        end
    end
    f.step:SetText(text)
    f.progress:SetText(not blocked and string.format("Checklist: %d/%d steps",done,#tasks) or "")
    f.source:SetText(self:SourceText(pin.source))
    f.status:SetText(status or "")
    f.next:SetEnabled(step~=nil and not blocked and result.status~="quest" and result.status~="completed")
    f.map:SetEnabled(not blocked and result.status~="completed")
    local canMap=result and (result.point or result.status=="quest")
    f.map.label:SetText((canMap or not result) and "Show on map" or (result.status=="completed" and "Show on map" or "Retry location"))
    f:ApplyLayout()
end
