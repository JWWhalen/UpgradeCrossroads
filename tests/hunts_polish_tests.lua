local oldPins,oldActive=XC.db.pins,XC.db.activeHunt
local oldOrder,oldHidden=XC.db.pinOrder,XC.db.trackerHidden
local oldLevel,oldWaypoint=MockLevel,LastWaypoint
local oldPoint,oldOwner=XC.Navigation.lastPoint,XC.Navigation.pointOwner
local oldPage,wasOpen=XC.window.activePage,XC.window:IsShown()
local oldObjectives=C_QuestLog.GetQuestObjectives
XC.db.pins={}

local first={kind="dungeon",name="Queue first",zone="Westfall",mapID=1436,x=32,y=30}
local second={kind="quest",name="Queue second",zone="Westfall",questID=991977,mapID=1436,x=66,y=30}
local future={kind="quest",name="Queue future",zone="Westfall",questID=991978,minLevel=30,mapID=1436,x=77,y=30}
local a={id=991976,name="First reward",sources={first}}
local b={id=991977,name="Second reward",sources={second}}
local c={id=991978,name="Future reward",sources={future}}
local current=XC.Catalog[281291]
local oldSource={kind="quest",questID=98028,name="Baron Marinous",zone="Unknown zone"}
local existing={item={id=281291,name=current.name},source=oldSource,notes="Save with group",checks={true},acquired=true}
XC.db.pins["281291"]=existing
XC:RefreshSavedHuntSources()
assert(existing.item==current and existing.source.zone=="Darkshore")
assert(existing.notes=="Save with group" and existing.checks[1] and existing.acquired)
oldSource.personal=true
existing.source=oldSource
XC:RefreshSavedHuntSources()
assert(existing.source==oldSource)
XC.db.pins["281291"]=nil

XC:EnsureHunt({item=a,source=first},"dungeon")
XC:TrackItem({item=b,source=second},"reliable",false)
local tracker=XC.guide
assert(tracker:IsShown() and LastWaypoint.x==.66)
tracker.next.scripts.OnClick()
assert(XC.db.pins["991977"].checks[1] and tracker.progress:GetText():find("1/3",1,true))

ActiveQuests[second.questID]=true
C_QuestLog.GetQuestObjectives=function(id)
    assert(id==second.questID)
    return {{text="Old objective",finished=true},{text="Murlocs defeated: 4/8",finished=false}}
end
XC:RenderGuide()
assert(tracker.step:GetText():find("Murlocs defeated: 4/8",1,true))
assert(tracker.next.enabled==false and TrackedQuest==second.questID and LastWaypoint==nil)
ActiveQuests[second.questID]=nil
C_QuestLog.GetQuestObjectives=oldObjectives
XC:RenderGuide()

tracker.hunts.scripts.OnClick()
local hunts=XC.huntWindow
assert(hunts:IsShown() and not tracker:IsShown() and hunts.rows[1].pin.item==b)
assert(hunts.rows[1].map.label:GetText()=="Open tracker")
assert(hunts.rows[1].progress:GetText():find("1/3",1,true))
hunts.rows[2].noteInput.edit:SetText("Westfall entrance")
hunts.rows[2].noteInput.edit.scripts.OnTextChanged(hunts.rows[2].noteInput.edit,true)
hunts.search.edit:SetText("entrance")
hunts.search.edit.scripts.OnTextChanged(hunts.search.edit,true)
assert(hunts.rows[1].pin.item==a and not hunts.rows[2]:IsShown())
hunts.search.edit:SetText("")
hunts.search.edit.scripts.OnTextChanged(hunts.search.edit,true)

XC:MapTarget(first)
assert(LastWaypoint.x==.32)
hunts.rows[1].map.scripts.OnClick()
assert(LastWaypoint.x==.32 and tracker:IsShown())
tracker.stop.scripts.OnClick()
assert(LastWaypoint.x==.32 and XC.db.pins["991977"] and not XC.db.activeHunt)

MockLevel=25
XC:TrackItem({item=c,source=future},"longterm",true)
assert(LastWaypoint.x==.32 and tracker.map.enabled==false)
assert(tracker.step:GetText():find("level 30",1,true))
MockLevel=30
XC:RenderGuide()
assert(LastWaypoint.x==.77 and tracker.map.enabled)
XC:StopHunt()
assert(LastWaypoint==nil and XC.db.pins["991978"])

XC.db.pins=oldPins
XC.db.activeHunt,XC.db.pinOrder,XC.db.trackerHidden=oldActive,oldOrder,oldHidden
MockLevel=oldLevel
XC:ShowPage(oldPage)
XC.window:SetShown(wasOpen)
XC:RenderGuide()
LastWaypoint=oldWaypoint
XC.Navigation.lastPoint,XC.Navigation.pointOwner=oldPoint,oldOwner
