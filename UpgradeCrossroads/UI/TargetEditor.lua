local _, XC = ...
local W=XC.W
local kinds={"dungeon","quest","craft","raid","vendor","reputation","auction","world"}
local function at(f,x,y) f:SetPoint("TOPLEFT",x,-y); return f end
function XC:ShowTargetEditor(row,lane)
    self:BuildUI()
    if not self.editor then
        local f=W.Page(self.window,"editor"); self.editor=f
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); f.scroll:SetPoint("TOPLEFT",10,-8); f.scroll:SetPoint("BOTTOMRIGHT",-28,10)
        local body=CreateFrame("Frame",nil,f.scroll); body:SetSize(760,580); f.scroll:SetScrollChild(body); f.content=body
        f.title=at(W.Text(body,"Add a personal target",16,self.Colors.gold,nil,true),20,12)
        at(W.Text(body,"Item ID or link",10,self.Colors.muted),24,94)
        f.item=at(W.Input(body,610,30),24,114)
        at(W.Text(body,"Source type",10,self.Colors.muted),24,162)
        f.kind=1
        f.kindButton=at(W.Button(body,"Dungeon drop  >",210,30,function()
            f.kind=f.kind%#kinds+1; f.kindButton.label:SetText(XC.KindLabels[kinds[f.kind]].."  >")
        end),24,182)
        at(W.Text(body,"Source, boss, quest or vendor",10,self.Colors.muted),24,231)
        f.source=at(W.Input(body,610,30),24,251)
        at(W.Text(body,"Location or requirements",10,self.Colors.muted),24,299)
        f.details=at(W.Input(body,610,30),24,319)
        at(W.Text(body,"Optional map ID",10,self.Colors.muted),24,367)
        at(W.Text(body,"X (0-100)",10,self.Colors.muted),199,367)
        at(W.Text(body,"Y (0-100)",10,self.Colors.muted),349,367)
        f.mapID=at(W.Input(body,155,28),24,387)
        f.x=at(W.Input(body,130,28),199,387); f.y=at(W.Input(body,130,28),349,387)
        f.status=at(W.Text(body,"Personal source. Item stats load from the client or bundled catalog.",10,self.Colors.muted,610),24,426)
        f.save=at(W.Button(body,"Save target",180,32,function() XC:SavePersonalTarget() end),454,482)
        f.cancel=at(W.Button(body,"Cancel",100,32,function() XC:ShowPage(f.returnPage or "gear") end),24,482)
        f.tip=at(W.Text(body,"Coordinates use percentages, such as 42.5 / 71.0.",11,self.Colors.muted,610),24,530)
        W.Hint(f.item,"Paste an item link or enter its numeric ID. Use the card Track button for catalog items.")
        W.Hint(f.kindButton,"Select the type of source: quest, dungeon, craft, vendor and more.")
        W.Hint(f.details,"Optional notes about the zone, access or materials. This does not create a route.")
        W.Hint(f.mapID,"Numeric UI map ID, not the zone name. X and Y are percentages on that map.")
        f.Layout=function(_,width,height)
            body:SetWidth(width-38); body:SetHeight(580)
            for _,field in ipairs({f.item,f.source,f.details}) do field:SetWidth(width-88) end
            f.status:SetWidth(width-88); f.tip:SetWidth(width-88)
            f.status:SetHeight(0); local sh=f.status:GetStringHeight(); f.status:SetHeight(sh)
            local actionY=math.max(482,426+sh+16)
            W.Place(f.save,width-250,actionY); W.Place(f.cancel,24,actionY); W.Place(f.tip,24,actionY+54)
            body:SetHeight(actionY+100)
        end
    end
    local f=self.editor
    f.returnPage=(self.window.activePage~="editor" and self.window.activePage) or f.returnPage or "gear"
    f.context=row and {row=row,lane=lane} or nil
    f.title:SetText(row and "Set source location" or "Add a personal target")
    f.save.label:SetText(row and "Save location" or "Save target")
    f.item.edit:SetText(row and tostring(row.item.id) or "")
    f.source.edit:SetText(row and row.source.name or "")
    f.details.edit:SetText(row and row.source.zone or "")
    f.mapID.edit:SetText(""); f.x.edit:SetText(""); f.y.edit:SetText("")
    f.kind=1
    if row then
        for i,kind in ipairs(kinds) do if kind==row.source.kind then f.kind=i end end
        local point=self.Navigation.Resolve(row.source).point
        if point then f.mapID.edit:SetText(tostring(point.mapID)); f.x.edit:SetText(tostring(point.x)); f.y.edit:SetText(tostring(point.y)) end
    end
    f.kindButton.label:SetText(self.KindLabels[kinds[f.kind]].."  >")
    f.status:SetText(row and "Item and source are selected. Enter map ID and X/Y percentages. Saving updates only this source." or "Personal source. Item stats load from the client or bundled catalog.")
    self:ShowPage("editor")
end
function XC:SavePersonalTarget()
    local f=self.editor
    if f.context then
        local point={mapID=tonumber(f.mapID.edit:GetText()),x=tonumber(f.x.edit:GetText()),y=tonumber(f.y.edit:GetText())}
        if not self.Navigation.ValidPoint(point) then f.status:SetText("Enter a valid map ID and both coordinates between 0 and 100."); return end
        local context=f.context
        self.db.locations[self.Navigation.SourceKey(context.row.source)]=point
        f:Hide(); self:TrackItem(context.row,context.lane,true)
        return
    end
    local input=f.item.edit:GetText() or ""
    local id=tonumber(input:match("item:(%d+)")) or tonumber(input)
    if not id or id<1 or id~=math.floor(id) then f.status:SetText("Enter a positive item ID or paste a full item link."); return end
    local sourceName=f.source.edit:GetText():match("^%s*(.-)%s*$")
    if sourceName=="" then f.status:SetText("Give the source a name so your future self knows where to go."); return end
    local item=self.Client.ResolveItem(id) or self.Catalog[id]
    if not item then self.Client.RequestItem(id); f.status:SetText("Requested item data. Wait a moment, then click Save target again. Unknown IDs cannot be scored."); return end
    if not item.inv or item.inv==0 or not item.stats then f.status:SetText("This item is not known equipment or its stats have not loaded yet."); return end
    local mapText=f.mapID.edit:GetText(); local xText=f.x.edit:GetText(); local yText=f.y.edit:GetText()
    local mapID,x,y=tonumber(mapText),tonumber(xText),tonumber(yText)
    if mapText~="" or xText~="" or yText~="" then
        if not mapID or mapID<1 or mapID~=math.floor(mapID) or not x or not y or x<0 or x>100 or y<0 or y>100 then
            f.status:SetText("For a waypoint, enter a valid map ID and both coordinates between 0 and 100."); return
        end
        if C_Map and C_Map.GetMapInfo and not C_Map.GetMapInfo(mapID) then f.status:SetText("The client does not recognize that map ID."); return end
    end
    local copy={}; for k,v in pairs(item) do copy[k]=v end
    local kind=kinds[f.kind]
    local source={kind=kind,name=sourceName,zone=f.details.edit:GetText(),personal=true,mapID=mapID,x=x,y=y}
    -- A free-text quest target is not a verified quest-ID lookup.
    if kind=="quest" then source.questID=nil end
    copy.sources={source}; self.db.custom[id]=copy
    local lane=(kind=="dungeon" or kind=="raid") and "dungeon" or (kind=="world" and "longterm" or "reliable")
    self:Pin({item=copy,source=source},lane)
    f.item.edit:SetText(""); f.source.edit:SetText(""); f.details.edit:SetText("")
    f.mapID.edit:SetText(""); f.x.edit:SetText(""); f.y.edit:SetText(""); self:ShowPage("hunts")
end
