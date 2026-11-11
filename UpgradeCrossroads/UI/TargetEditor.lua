local _, XC = ...
local W=XC.W
local kinds={"dungeon","quest","craft","raid","vendor","reputation","auction","world"}
local function at(f,x,y) f:SetPoint("TOPLEFT",x,-y); return f end
local function setStatus(f,message) f.status:SetText(message); f:ApplyLayout() end
function XC:ShowTargetEditor(row,lane)
    self:BuildUI()
    if not self.editor then
        local f=W.Page(self.window,"editor"); self.editor=f
        W.ThemedPage(f)
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); f.scroll:SetPoint("TOPLEFT",10,-8); f.scroll:SetPoint("BOTTOMRIGHT",-28,10)
        local body=CreateFrame("Frame",nil,f.scroll); body:SetSize(760,580); f.scroll:SetScrollChild(body); f.content=body
        f.title=at(W.JournalText(body,"Add a personal target",16,nil,true),20,12)
        f.formLabels={}
        f.formLabels.item=at(W.JournalText(body,"Item ID or link",10),24,94)
        f.item=at(W.PaperInput(body,610,30),24,114)
        f.formLabels.kind=at(W.JournalText(body,"Source type",10),24,162)
        f.kind=1
        f.kindButton=at(W.Button(body,"Dungeon drop  >",210,30,function()
            f.kind=f.kind%#kinds+1; f.kindButton.label:SetText(XC.KindLabels[kinds[f.kind]].."  >")
            f:ApplyLayout()
        end),24,182)
        f.formLabels.source=at(W.JournalText(body,"Source, boss, quest or vendor",10),24,231)
        f.source=at(W.PaperInput(body,610,30),24,251)
        f.formLabels.details=at(W.JournalText(body,"Location or requirements",10),24,299)
        f.details=at(W.PaperInput(body,610,30),24,319)
        f.formLabels.mapID=at(W.JournalText(body,"Optional map ID",10),24,367)
        f.formLabels.x=at(W.JournalText(body,"X (0-100)",10),199,367)
        f.formLabels.y=at(W.JournalText(body,"Y (0-100)",10),349,367)
        f.mapID=at(W.PaperInput(body,155,28),24,387)
        f.x=at(W.PaperInput(body,130,28),199,387); f.y=at(W.PaperInput(body,130,28),349,387)
        f.status=at(W.JournalText(body,"Personal source. Item stats load from the client or bundled catalog.",10,610),24,426)
        f.save=at(W.Button(body,"Save target",180,32,function() XC:SavePersonalTarget() end),454,482)
        f.cancel=at(W.Button(body,"Cancel",100,32,function() XC:ShowPage(f.returnPage or "gear") end),24,482)
        f.tip=at(W.JournalText(body,"Coordinates use percentages, such as 42.5 / 71.0.",11,610),24,530)
        W.Hint(f.item,"Paste an item link or enter its numeric ID. Use the card Track button for catalog items.")
        W.Hint(f.kindButton,"Select the type of source: quest, dungeon, craft, vendor and more.")
        W.Hint(f.details,"Optional notes about the zone, access or materials. This does not create a route.")
        W.Hint(f.mapID,"Numeric UI map ID, not the zone name. X and Y are percentages on that map.")
        f.Layout=function(_,width,height)
            body:SetWidth(width-38)
            local inner=width-88
            local function textAt(label,x,y,textWidth)
                label:SetWidth(textWidth); label:SetHeight(0); W.Place(label,x,y)
                local h=label:GetStringHeight(); label:SetHeight(h)
                return y+h
            end
            local y=textAt(f.title,20,12,inner)+20
            local function fieldAt(key,field,fullWidth)
                y=textAt(f.formLabels[key],24,y,inner)+6
                if fullWidth then field:SetWidth(inner) else W.FitButton(field,210) end
                W.Place(field,24,y); y=y+field:GetHeight()+18
            end
            fieldAt("item",f.item,true); fieldAt("kind",f.kindButton,false)
            fieldAt("source",f.source,true); fieldAt("details",f.details,true)
            local col=(inner-32)/3; local coordLabels=0
            for i,key in ipairs({"mapID","x","y"}) do
                local label=f.formLabels[key]
                coordLabels=math.max(coordLabels,textAt(label,24+(i-1)*(col+16),y,col)-y)
            end
            y=y+coordLabels+6
            local coordHeight=0
            for i,key in ipairs({"mapID","x","y"}) do
                local field=f[key]; field:SetWidth(col); W.Place(field,24+(i-1)*(col+16),y)
                coordHeight=math.max(coordHeight,field:GetHeight())
            end
            y=textAt(f.status,24,y+coordHeight+18,inner)+18
            W.FitButton(f.save,180); W.FitButton(f.cancel,100)
            W.Place(f.cancel,24,y); W.Place(f.save,24+inner-f.save:GetWidth(),y)
            y=y+math.max(f.save:GetHeight(),f.cancel:GetHeight())+16
            body:SetHeight(textAt(f.tip,24,y,inner)+20)
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
    setStatus(f,row and "Item and source are selected. Enter map ID and X/Y percentages. Saving updates only this source." or "Personal source. Item stats load from the client or bundled catalog.")
    self:ShowPage("editor")
end
function XC:SavePersonalTarget()
    local f=self.editor
    if f.context then
        local point={mapID=tonumber(f.mapID.edit:GetText()),x=tonumber(f.x.edit:GetText()),y=tonumber(f.y.edit:GetText())}
        if not self.Navigation.ValidPoint(point) then setStatus(f,"Enter a valid map ID and both coordinates between 0 and 100."); return end
        local context=f.context
        self.db.locations[self.Navigation.SourceKey(context.row.source)]=point
        f:Hide(); self:TrackItem(context.row,context.lane,true)
        return
    end
    local input=f.item.edit:GetText() or ""
    local id=tonumber(input:match("item:(%d+)")) or tonumber(input)
    if not id or id<1 or id~=math.floor(id) then setStatus(f,"Enter a positive item ID or paste a full item link."); return end
    local sourceName=f.source.edit:GetText():match("^%s*(.-)%s*$")
    if sourceName=="" then setStatus(f,"Give the source a name so your future self knows where to go."); return end
    local item=self.Client.ResolveItem(id) or self.Catalog[id]
    if not item then self.Client.RequestItem(id); setStatus(f,"Requested item data. Wait a moment, then click Save target again. Unknown IDs cannot be scored."); return end
    if not item.inv or item.inv==0 or not item.stats then setStatus(f,"This item is not known equipment or its stats have not loaded yet."); return end
    local mapText=f.mapID.edit:GetText(); local xText=f.x.edit:GetText(); local yText=f.y.edit:GetText()
    local mapID,x,y=tonumber(mapText),tonumber(xText),tonumber(yText)
    if mapText~="" or xText~="" or yText~="" then
        if not mapID or mapID<1 or mapID~=math.floor(mapID) or not x or not y or x<0 or x>100 or y<0 or y>100 then
            setStatus(f,"For a waypoint, enter a valid map ID and both coordinates between 0 and 100."); return
        end
        if C_Map and C_Map.GetMapInfo and not C_Map.GetMapInfo(mapID) then setStatus(f,"The client does not recognize that map ID."); return end
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
