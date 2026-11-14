local _, XC = ...
local N={}
XC.Navigation=N
local safe=XC.Client.Safe
local function copy(t) local out={}; for k,v in pairs(t or {}) do out[k]=v end; return out end
function N.SourceKey(source)
    if source.questID then return "quest:"..source.questID end
    if source.npcID then return "npc:"..source.npcID..":"..tostring(source.zoneID or 0) end
    if source.spellID then return "craft:"..source.spellID end
    return tostring(source.kind)..":"..tostring(source.name)..":"..tostring(source.zone or "")
end
function N.ValidPoint(point)
    return type(point)=="table" and type(point.mapID)=="number" and point.mapID>0 and point.mapID==math.floor(point.mapID)
        and type(point.x)=="number" and point.x>=0 and point.x<=100
        and type(point.y)=="number" and point.y>=0 and point.y<=100
        and (not C_Map or not C_Map.GetMapInfo or safe(C_Map.GetMapInfo,point.mapID)~=nil)
end
local function entity(kind,id,key)
    local provider=LibQuestieDB
    local api=provider and provider[kind]
    if api and type(api.Get)=="function" then return safe(api.Get,id,key) end
end
local function zoneModule()
    if QuestieLoader and type(QuestieLoader.ImportModule)=="function" then
        return safe(QuestieLoader.ImportModule,QuestieLoader,"ZoneDB")
    end
end
-- Only parse numeric table entries from provider-owned support strings. Never
-- execute data strings or infer a UI map ID from an AreaID.
local function numericMap(value)
    if type(value)=="table" then return value end
    local out={}
    if type(value)=="string" then
        for a,b in value:gmatch("%[(%d+)%]%s*=%s*(%d+)") do out[tonumber(a)]=tonumber(b) end
    end
    return out
end
function N.UiMap(areaID)
    local z=zoneModule()
    if z and type(z.GetUiMapIdByAreaId)=="function" then
        local result=safe(z.GetUiMapIdByAreaId,z,areaID)
        if result then return result end
    end
    local p=LibQuestieDB
    local support=p and p.Support and safe(p.Support.Get,"ZoneDB")
    local private=support and support.private
    if private then
        local override=numericMap(private.areaIdToUiMapIdOverride)
        return override[areaID] or numericMap(private.areaIdToUiMapId)[areaID]
    end
end
local function pointFromSpawns(spawns,label)
    if type(spawns)~="table" then return nil end
    local points={}
    for area,coords in pairs(spawns) do
        local mapID=N.UiMap(area)
        if mapID and type(coords)=="table" then
            for _,xy in ipairs(coords) do
                local p={mapID=mapID,x=xy[1],y=xy[2],label=label,basis="Installed QuestieDB location"}
                if N.ValidPoint(p) then points[#points+1]=p end
            end
        end
    end
    local here=C_Map and safe(C_Map.GetBestMapForUnit,"player")
    local pos=here and safe(C_Map.GetPlayerMapPosition,here,"player")
    local px,py
    if pos and pos.GetXY then px,py=pos:GetXY() end
    table.sort(points,function(a,b)
        local ah,bh=a.mapID==here,b.mapID==here
        if ah~=bh then return ah end
        if ah and px and py then
            local ad=(a.x/100-px)^2+(a.y/100-py)^2
            local bd=(b.x/100-px)^2+(b.y/100-py)^2
            if ad~=bd then return ad<bd end
        end
        if a.mapID~=b.mapID then return a.mapID<b.mapID end
        if a.x~=b.x then return a.x<b.x end
        return a.y<b.y
    end)
    return points[1]
end
local function npcPoint(id)
    return pointFromSpawns(entity("Npc",id,"spawns"),entity("Npc",id,"name") or ("NPC #"..id))
end
local function recipePoint(recipe)
    if not recipe or not recipe.locations or recipe.basis~="Forever" then return nil end
    local faction=UnitFactionGroup("player")
    local side=faction=="Alliance" and 1 or faction=="Horde" and 2 or 0
    local here=C_Map and safe(C_Map.GetBestMapForUnit,"player")
    local fallback
    for _,location in ipairs(recipe.locations) do
        if (location.side==3 or location.side==side) and N.ValidPoint(location) then
            if location.mapID==here then return location end
            fallback=fallback or location
        end
    end
    return fallback
end
local function isDone(id)
    local done=C_QuestLog and safe(C_QuestLog.IsQuestFlaggedCompleted,id)
    if done~=nil then return done end
    return XC.context and XC.context.completed and XC.context.completed[id] or false
end
local function onQuest(id) return C_QuestLog and safe(C_QuestLog.IsOnQuest,id) end
local function nextKnownQuest(target)
    local visited={}
    local function visit(id,depth)
        if depth>12 or visited[id] then return nil,"Quest prerequisite data contains a cycle or exceeds the guide limit." end
        visited[id]=true
        if onQuest(id) then return id end
        local all=entity("Quest",id,"preQuestGroup")
        if type(all)=="table" then for _,q in ipairs(all) do if q>0 and not isDone(q) then return visit(q,depth+1) end end end
        local any=entity("Quest",id,"preQuestSingle")
        if type(any)=="table" and #any>0 then
            local satisfied=false
            for _,q in ipairs(any) do if q>0 and isDone(q) then satisfied=true end end
            if not satisfied then
                for _,q in ipairs(any) do if q>0 and onQuest(q) then return q end end
                -- Ambiguous alternatives need the player to choose; do not
                -- silently send a player down a class/faction-specific branch.
                local positive={}; for _,q in ipairs(any) do if q>0 then positive[#positive+1]=q end end
                if #positive==1 then return visit(positive[1],depth+1) end
                if #positive>1 then return id,"Multiple prerequisite branches: check eligibility before starting." end
            end
        end
        return id
    end
    return visit(target,1)
end
local function questPoint(id)
    local complete=C_QuestLog and safe(C_QuestLog.IsComplete,id)
    local field=complete and "finishedBy" or "startedBy"
    local starters=entity("Quest",id,field)
    if type(starters)~="table" then return nil end
    for _,npc in ipairs(starters[1] or {}) do local p=npcPoint(npc); if p then return p end end
    for _,object in ipairs(starters[2] or {}) do
        local p=pointFromSpawns(entity("Object",object,"spawns"),entity("Object",object,"name") or ("Object #"..object))
        if p then return p end
    end
end
function N.Resolve(source)
    local result={status="missing",message="Location not available yet. The item is still trackable.",sourceKey=N.SourceKey(source)}
    if source.questID then
        if isDone(source.questID) then return {status="completed",message="This reward quest is already completed. Choose another source if you did not keep the item."} end
        local id,warning=nextKnownQuest(source.questID)
        id=id or source.questID
        result.questID=id; result.questName=entity("Quest",id,"name") or (id==source.questID and source.name or ("Quest #"..id)); result.warning=warning
        result.prerequisite=id~=source.questID
        if onQuest(id) then
            result.status="quest"; result.message="Follow the game's tracked quest objective."
            local mapID,x,y=safe(C_QuestLog.GetNextWaypoint,id)
            if mapID and x and y then
                local p={mapID=mapID,x=x*100,y=y*100,label=result.questName,basis="Live quest navigation"}
                if N.ValidPoint(p) then result.point=p end
            end
            return result
        end
        result.point=questPoint(id)
        if result.point then result.status="point"; result.message=(result.prerequisite and "Next known prerequisite: " or "Quest giver: ")..result.questName; return result end
    end
    local override=XC.db and XC.db.locations and XC.db.locations[result.sourceKey]
    if N.ValidPoint(override) then result.point=copy(override); result.point.basis="Personal source location"; result.status="point"; result.message="Your saved source location."; return result end
    if N.ValidPoint(source) then result.point=copy(source); result.point.basis=source.personal and "Personal source location" or "Bundled source location"; result.status="point"; result.message="Source location ready."; return result end
    if source.kind=="craft" then
        local location=recipePoint(XC:GetRecipeSource(source))
        if location then
            result.point=copy(location)
            result.point.basis="Bundled recipe location"
            result.status="point"
            result.message="Recipe location: "..location.label.."."
        else
            result.message="No verified recipe map location for this character."
        end
        return result
    elseif source.kind=="dungeon" or source.kind=="raid" then
        local entry=XC.Entrances and XC.Entrances[source.zoneID]
        if entry then
            local selected=(UnitFactionGroup("player")=="Alliance" and entry.alliance) or entry
            local p=copy(selected); p.label=entry.label.." approach"; p.basis=entry.basis; p.entrance=true
            if N.ValidPoint(p) then result.point=p; result.status="point"; result.message="Entrance / approach only. Defeat "..source.name.." inside; a drop is not guaranteed."; return result end
        end
        local z=zoneModule()
        local locations=z and safe(z.GetDungeonLocation,z,source.zoneID)
        if type(locations)=="table" then
            for _,entryPoint in ipairs(locations) do
                local p={mapID=N.UiMap(entryPoint[1]),x=entryPoint[2],y=entryPoint[3],label=source.zone.." entrance",basis="Installed Questie entrance",entrance=true}
                if N.ValidPoint(p) then result.point=p; result.status="point"; result.message="Dungeon entrance only; find "..source.name.." inside."; return result end
            end
        end
    elseif source.npcID then
        local p=npcPoint(source.npcID)
        if p then result.point=p; result.status="point"; result.message="Reported creature spawn; this does not detect whether it is currently alive."; return result end
    end
    if source.questID and not LibQuestieDB then result.message="Track this quest from your log, or install QuestieDB for known quest-giver locations." end
    return result
end
function N.Signature(result,itemID)
    local key=tostring(itemID or "")..":"..tostring(result.questID or "")..":"..result.status
    local p=result.point
    if p then key=key..":"..p.mapID..":"..p.x..":"..p.y end
    return key
end
function N.ReleaseOwnedWaypoint(owner)
    if owner and owner~=N.pointOwner then return end
    local own=N.lastPoint
    local current=C_Map and safe(C_Map.GetUserWaypoint)
    if own and current and current.position and current.position.GetXY then
        local x,y=current.position:GetXY()
        if current.uiMapID==own.mapID and x and y and math.abs(x-own.x/100)<.00001 and math.abs(y-own.y/100)<.00001 then
            safe(C_Map.ClearUserWaypoint)
        end
    end
    N.lastPoint=nil; N.pointOwner=nil
end
function N.Apply(result,showMap,owner)
    if InCombatLockdown() then return false,"Navigation changes are available after combat." end
    local p=result.point
    if result.status=="quest" and result.questID then
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(result.questID) end
        if showMap and QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(result.questID) end
        return true,"Following "..(result.questName or "the active quest").."."
    end
    if p and N.ValidPoint(p) and C_Map and C_Map.SetUserWaypoint and UiMapPoint then
        if C_Map.CanSetUserWaypointOnMap and not safe(C_Map.CanSetUserWaypointOnMap,p.mapID) then return false,"The client does not allow a waypoint on this map." end
        local ok,wasSet=pcall(C_Map.SetUserWaypoint,UiMapPoint.CreateFromCoordinates(p.mapID,p.x/100,p.y/100))
        if not ok or wasSet==false then return false,"The client could not set this waypoint." end
        N.lastPoint=copy(p); N.pointOwner=owner
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        if showMap then
            if OpenWorldMap then OpenWorldMap(p.mapID)
            elseif WorldMapFrame then WorldMapFrame:Show(); if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(p.mapID) end end
        end
        return true,(p.entrance and "Entrance waypoint set." or "Source waypoint set.").." This is a destination pin, not terrain routing."
    end
    return false,result.message
end
