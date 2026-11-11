-- A deliberately small client double. It checks UI calls and event/state flows,
-- but does not claim to emulate the WoW renderer or combat security system.
Frames={}; Messages={}; Timers={}; Owned={}; ItemInfo={}; FakeInventory={}; Completed={}; ActiveQuests={}; QuestWaypoints={}
MockMaps={[1429]="Elwynn",[1436]="Westfall",[1416]="Alterac",[1420]="Tirisfal",[1427]="Searing Gorge"}
SlashCmdList={}; UISpecialFrames={}; MockTime=1794052800; MockClass="WARRIOR"; MockClassID=1; MockLevel=25
local methods={}
local function make(kind,name,parent)
    local f={kind=kind,name=name,parent=parent,shown=true,width=0,height=0,scripts={},level=parent and (parent.level+1) or 1}
    setmetatable(f,{__index=methods}); Frames[#Frames+1]=f
    if name then _G[name]=f end
    return f
end
function CreateFrame(kind,name,parent,template)
    local f=make(kind,name,parent); f.template=template
    if template=="UIPanelScrollFrameTemplate" then f.ScrollBar=make("Slider",nil,f) end
    return f
end
function methods:SetSize(w,h)
    self.width=w; self.height=h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end
end
function methods:SetWidth(w) self:SetSize(w,self.height) end
function methods:SetHeight(h) self:SetSize(self.width,h) end
function methods:GetParent() return self.parent end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(...)
    self.point={...}
    self.points=self.points or {}; self.points[self.point[1]]=self.point
end
function methods:GetPoint() return unpack(self.point or {}) end
function methods:ClearAllPoints() self.point=nil; self.points={}; self.allPoints=nil end
function methods:SetAllPoints(other) self.allPoints=other or self.parent end
function methods:SetBackdrop(v) self.backdrop=v end
function methods:SetBackdropColor(...) self.bg={...} end
function methods:SetBackdropBorderColor(...) self.border={...} end
function methods:SetText(v) self.text=tostring(v or ""); if self.kind=="Button" and self.template=="UIPanelButtonTemplate" then self:GetFontString():SetText(v) end end
function methods:GetText() return self.text or "" end
function methods:SetTextColor(...) self.color={...} end
function methods:SetFont(path,size,flags) self.fontSize=size; self.fontPath=path; self.fontFlags=flags end
function methods:SetShadowOffset(...) self.shadowOffset={...} end
function methods:SetJustifyH(v) self.justify=v end
function methods:SetJustifyV(v) self.justifyV=v end
function methods:SetWordWrap(v) self.wrap=v end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetTexture(v) self.texture=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetVertexColor(...) self.vertexColor={...} end
function methods:SetDrawLayer(layer,sublevel) self.drawLayer=layer; self.drawSublevel=sublevel end
function methods:SetBlendMode(mode) self.blendMode=mode end
function methods:SetHighlightTexture(v) self.highlight=v end
function methods:SetNormalTexture(v) self.normalTexture=v end
function methods:GetFontString()
    if not self.label then self.label=self:CreateFontString(nil,"OVERLAY"); self.label:SetPoint("CENTER"); self.label:SetJustifyH("CENTER") end
    return self.label
end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:GetCenter() return 1100,750 end
function methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
local function anchorFactors(anchor)
    return anchor:find("LEFT") and 0 or (anchor:find("RIGHT") and 1 or .5),anchor:find("BOTTOM") and 0 or (anchor:find("TOP") and 1 or .5)
end
local function physicalBounds(f)
    local scale=f:GetEffectiveScale(); local w,h=f.width*scale,f.height*scale
    if not f.parent then return 0,h,w,h end
    local p=f.point or {"TOPLEFT"}; local relative=f.parent; local relativePoint=p[1]; local x,y=0,0
    if type(p[2])=="table" then relative=p[2]; relativePoint=p[3]; x=p[4] or 0; y=p[5] or 0
    elseif type(p[2])=="number" then x=p[2]; y=p[3] or 0 end
    local left,top,rw,rh=physicalBounds(relative)
    local rx,ry=anchorFactors(relativePoint); local ax,ay=anchorFactors(p[1])
    return left+rx*rw+x*scale-ax*w,top-rh+ry*rh+y*scale+(1-ay)*h,w,h
end
function methods:GetLeft() local x=physicalBounds(self); return x/self:GetEffectiveScale() end
function methods:GetTop() local _,y=physicalBounds(self); return y/self:GetEffectiveScale() end
function methods:SetFontObject(v) self.fontSize=12 end
function methods:SetAutoFocus(v) self.autoFocus=v end
function methods:SetMultiLine(v) self.multiline=v end
function methods:SetMaxLetters(v) self.maxLetters=v end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:HookScript(name,fn)
    local previous=self.scripts[name]
    self.scripts[name]=function(...) if previous then previous(...) end; fn(...) end
end
function methods:RegisterForDrag(...) end
function methods:SetResizable(v) self.resizable=v end
function methods:SetResizeBounds(...) self.resizeBounds={...} end
function methods:StartSizing(corner) self.sizing=corner end
function methods:GetScale() return self.scale or 1 end
function methods:GetStringWidth() if MeasureWidth then return MeasureWidth(self:GetText(),self.fontSize or 13,self.fontPath or "") end; return #self:GetText()*(self.fontSize or 13)*.6 end
function methods:GetStringHeight()
    local size=self.fontSize or 12; if MeasureText then return MeasureText(self:GetText(),size,self.width,self.fontPath or "") end; local lines=0
    for raw in (self:GetText().."\n"):gmatch("(.-)\n") do lines=lines+math.max(1,math.ceil(#raw*size*.52/math.max(1,self.width))) end
    return lines*size*1.35
end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.sizing=nil; self.moving=nil end
function methods:SetMovable(v) end
function methods:SetClampedToScreen(v) end
function methods:SetToplevel(v) self.toplevel=v end
function methods:Raise() self.raised=(self.raised or 0)+1 end
function methods:EnableMouse(v) self.mouseEnabled=v end
function methods:SetFrameStrata(v) self.strata=v end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetFrameLevel() return self.level end
function methods:SetScale(v) self.scale=v end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:Show() local before=self.shown; self.shown=true; if not before and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local before=self.shown; self.shown=false; if before and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() if not self.shown then return false end; return not self.parent or self.parent:IsShown() end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(v) self.enabled=v end
function methods:ClearFocus() self.focus=false end
function methods:HasFocus() return self.focus end
function methods:RegisterEvent(v) self.events=self.events or {}; self.events[v]=true end
function methods:UnregisterAllEvents() self.events={} end
function methods:SetScrollChild(v) self.scrollChild=v end
function methods:SetVerticalScroll(v) self.verticalScroll=v end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:SetMinMaxValues(low,high) self.minValue=low; self.maxValue=high end
function methods:SetValueStep(step) self.valueStep=step end
function methods:SetObeyStepOnDrag(v) self.obeyStep=v end
function methods:SetValue(value) self.value=value; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end end
function methods:GetValue() return self.value end
function methods:CreateFontString(name,layer,template) local f=make("FontString",name,self); f.drawLayer=layer; return f end
function methods:CreateTexture(name,layer,template) local f=make("Texture",name,self); f.drawLayer=layer; return f end
function methods:SetOwner(...) end
function methods:SetHyperlink(...) end
function methods:AddLine(...) end
UIParent=make("UIParent","UIParent",nil); UIParent:SetSize(1280,900)
Minimap=make("Minimap","Minimap",UIParent); Minimap:SetSize(140,140); Minimap:Hide()
function GetCursorPosition() return MockCursorX or 1200,MockCursorY or 750 end
DEFAULT_CHAT_FRAME={AddMessage=function(self,m) Messages[#Messages+1]=m end}
GameTooltip=make("Tooltip","GameTooltip",UIParent); GameTooltip:Hide()
ChatFontNormal={}
C_Timer={After=function(delay,fn) Timers[#Timers+1]=fn end}
function FlushTimers() local old=Timers; Timers={}; for _,fn in ipairs(old) do fn() end end
function UnitClass() return MockClass,MockClass,MockClassID end
function UnitRace() return "Human","Human",1 end
function UnitFactionGroup() return MockFaction or "Alliance" end
function UnitName() return "Flakie" end
function UnitLevel() return MockLevel end
function GetScreenWidth() return 1280 end
function GetScreenHeight() return 900 end
function GetInventoryItemID(unit,slot) return FakeInventory[slot] end
function GetInventoryItemLink(unit,slot) local id=FakeInventory[slot]; if id then return "item:"..id end end
function InCombatLockdown() return MockCombat or false end
function GetBuildInfo() return "1.60.1","70790","Nov 2026",16001 end
function time() return MockTime end
C_Item={}
function C_Item.GetItemInfo(id)
    id=tonumber(tostring(id):match("item:(%d+)")) or tonumber(id)
    local i=ItemInfo[id]; if not i then return end
    return i.name,"item:"..id,i.quality,i.ilvl,i.req,"","",1,i.equip,i.icon or "icon",0,i.classID,i.subclassID
end
function C_Item.GetItemStats(id) id=tonumber(tostring(id):match("item:(%d+)")) or tonumber(id); return ItemInfo[id] and ItemInfo[id].stats end
function C_Item.GetItemCount(id) return Owned[id] or 0 end
function C_Item.RequestLoadItemDataByID(id) end
C_QuestLog={GetAllCompletedQuestIDs=function() return Completed end,IsOnQuest=function(id) return ActiveQuests[id] end,
 IsQuestFlaggedCompleted=function(id) for _,q in ipairs(Completed) do if q==id then return true end end; return false end,
 GetNextWaypoint=function(id) local p=QuestWaypoints[id]; if p then return p.id,p.x,p.y end end,
 IsComplete=function() return false end}
C_Map={GetMapInfo=function(id) if MockMaps[id] then return {name=MockMaps[id]} end end,SetUserWaypoint=function(p) LastWaypoint=p end,
 GetUserWaypoint=function() local p=LastWaypoint; if p then return {uiMapID=p.id,position={GetXY=function() return p.x,p.y end}} end end,
 ClearUserWaypoint=function() LastWaypoint=nil end}
UiMapPoint={CreateFromCoordinates=function(id,x,y) return {id=id,x=x,y=y} end}
C_SuperTrack={SetSuperTrackedUserWaypoint=function(v) LastSuperTrack=v end,SetSuperTrackedQuestID=function(id) TrackedQuest=id end}
function OpenWorldMap(id) MapOpened=id end
function QuestMapFrame_OpenToQuestDetails(id) QuestDetailsOpened=id end
function FireEvent(event,...)
    for _,f in ipairs(Frames) do if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end

CharacterFrame=CreateFrame("Frame","CharacterFrame",UIParent); CharacterFrame:Hide()
ChatDraft=""; ChatActive=false; ChatSent=0
function ChatEdit_GetActiveWindow() return ChatActive and DEFAULT_CHAT_FRAME or nil end
function ChatEdit_InsertLink(link) if not ChatActive then return false end; ChatDraft=ChatDraft..link; return true end
function ChatFrame_OpenChat(text) ChatDraft=text; ChatActive=true end
function SendChatMessage() ChatSent=ChatSent+1; error("UI must never send a chat message") end
function IsShiftKeyDown() return MockShift or false end
function IsControlKeyDown() return MockControl or false end
function DressUpItemLink(link) PreviewedLink=link end
