"""Lua 5.1 tests of real rules, real catalog and UI/event wiring.

python3 -m pip install lupa
python3 tests/run_tests.py
"""
from pathlib import Path
import json
import re
from lupa.lua51 import LuaRuntime
from PIL import ImageFont
from functools import lru_cache

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT/'tests/wow_stub.lua').read_text())
# Font measurement is a deterministic preview substitute, never a WoW renderer.
@lru_cache(maxsize=256)
def measured_font(path,size):
    candidates=(["/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf","C:/Windows/Fonts/georgia.ttf"] if "FRIZQT" in path else ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf","C:/Windows/Fonts/arial.ttf"])
    selected=next((p for p in candidates if Path(p).is_file()),None)
    return ImageFont.truetype(selected,max(1,round(size*8))) if selected else ImageFont.load_default(size=max(1,round(size*8)))
def measure_text(text,size,width,path):
    font=measured_font(path,size); count=0
    for raw in text.split("\n"):
        current=""
        for word in raw.split(" "):
            candidate=(current+" "+word).strip()
            if current and width>0 and font.getlength(candidate)>width*8:
                count+=1; current=word
            else: current=candidate
        count+=1
    return count*size*1.35+2
lua.globals().MeasureText=measure_text
lua.globals().MeasureWidth=lambda text,size,path: max((measured_font(path,size).getlength(line)/8 for line in text.split("\n")),default=0)
xc=lua.table(); lua.globals().XC=xc
toc=(ROOT/'UpgradeCrossroads/UpgradeCrossroads.toc').read_text()
load=lua.eval('function(s,n,xc) local f,e=loadstring(s,n); assert(f,e); return f("UpgradeCrossroads",xc) end')
for line in toc.splitlines():
    if line and not line.startswith('#'):
        path=ROOT/'UpgradeCrossroads'/line.replace('\\','/')
        load(path.read_text(),str(path),xc)

cases=[]
def test(name, code):
    lua.execute(code)
    cases.append(name)
    print('PASS',name)

test('initialization and slash commands', '''
FireEvent("ADDON_LOADED","UpgradeCrossroads")
assert(XC.db.profile=="warrior_arms" and XC.db.slot==16)
assert(XC.db.schema==6 and XC:Appearance().font=="classic")
assert(type(SlashCmdList.UPGRADECROSSROADS)=="function")
assert(XC.CatalogMeta.count==3529)
''')
test('complete native UI opens with catalog recommendations', '''
SlashCmdList.UPGRADECROSSROADS("")
assert(XC.window:IsShown())
assert(XC.window.activePage=="gear" and XC.window.journal:IsShown() and not XC.window.pages.compare:IsShown())
assert(not XC.window.nav.compare, "Journal is the only visible gear-browsing tab")
assert(#XC.lanes.reliable>0 and #XC.lanes.dungeon>0 and #XC.lanes.longterm>0)
assert(XC.window.lanes.reliable.name.text~="")
for _,record in ipairs(XC.W.fonts) do assert(record.object.fontPath=="Fonts\\\\FRIZQT__.TTF") end
''')
test('close button is outside the title drag region and closes without Escape', '''
local f=XC.window; local drag=f.dragHandle; local close=f.closeButton
assert(drag and close and close.mouseEnabled)
local right=drag.points.TOPRIGHT; local left=drag.points.TOPLEFT
assert(right[2]==f and right[3]=="TOPRIGHT" and right[4]==-48)
local dragRight=f.width+right[4]
assert(left[4]==0 and dragRight<close.point[2])
assert(close:GetFrameLevel()>drag:GetFrameLevel())
assert(close.clicks[1]=="LeftButtonUp")
close.scripts.OnClick(close,"LeftButton"); assert(not f:IsShown())
SlashCmdList.UPGRADECROSSROADS(""); assert(f:IsShown())
close.scripts.OnClick(close,"LeftButton"); assert(not f:IsShown())
SlashCmdList.UPGRADECROSSROADS("")
''')
test('minimap launcher opens planner and hunts without duplicate buttons', '''
local b=XC.minimapButton; assert(b and b.name=="UpgradeCrossroadsMinimapButton")
XC.window:Hide(); b.scripts.OnClick(b,"LeftButton"); assert(XC.window:IsShown())
b.scripts.OnClick(b,"RightButton"); assert(XC.huntWindow:IsShown())
XC.huntWindow:Hide(); XC:CreateMinimapButton(); assert(XC.minimapButton==b)
''')
test('minimap dragging and hide/show survive saved-state initialization', '''
local b=XC.minimapButton
b.scripts.OnDragStart(b); assert(b.scripts.OnUpdate)
b.scripts.OnUpdate(b); assert(XC.db.minimap.angle==0)
b.scripts.OnDragStop(b); assert(not b.scripts.OnUpdate); FlushTimers()
SlashCmdList.UPGRADECROSSROADS("minimap hide"); assert(not b.shown)
FireEvent("ADDON_LOADED","UpgradeCrossroads"); assert(XC.db.minimap.hidden and not b.shown)
SlashCmdList.UPGRADECROSSROADS("minimap show"); assert(b.shown)
SlashCmdList.UPGRADECROSSROADS("minimap reset"); assert(XC.db.minimap.angle==225)
''')
test('source eligibility and race/class masks', '''
local R=XC.Rules
local c={classID=1,raceID=1,side=1,completed={[1]=true}}
local o={solo=false,crafted=true,auction=false}
assert(not R.SourceAllowed({kind="quest",side=2},c,o))
assert(not R.SourceAllowed({kind="quest",questID=1},c,o))
assert(not R.SourceAllowed({kind="quest",raceMask=2},c,o))
assert(R.SourceAllowed({kind="quest",raceMask=1,classMask=1,side=3},c,o))
assert(not R.SourceAllowed({kind="auction"},c,o))
''')
test('solo and crafting preferences actually remove candidates', '''
XC.db.options.solo=true; XC.db.options.crafted=false; XC:Refresh()
assert(#XC.lanes.dungeon==0)
for _,lane in pairs(XC.lanes) do for _,row in ipairs(lane) do assert(row.source.kind~="dungeon" and row.source.kind~="raid" and row.source.kind~="craft" and not row.source.group) end end
XC.db.options.solo=false; XC.db.options.crafted=true; XC:Refresh()
''')
test('future gear stays out of current paths', '''
for _,key in ipairs({"reliable","dungeon"}) do for _,row in ipairs(XC.lanes[key]) do assert(row.minLevel<=MockLevel) end end
local future=false; for _,r in ipairs(XC.lanes.longterm) do if r.minLevel>MockLevel then future=true end end
assert(future)
''')
test('class armor filtering and future armor training', '''
local item={inv=5,classID=4,subclassID=4,classMask=0}
local c={class="WARRIOR",classID=1,level=25}
assert(not XC.Rules.Usable(item,c,XC:GetSlot(5)))
c.level=40; assert(XC.Rules.Usable(item,c,XC:GetSlot(5)))
c.class="MAGE"; assert(not XC.Rules.Usable(item,c,XC:GetSlot(5)))
''')
test('two-hand versus one-hand never fabricates an upgrade delta', '''
local a={id=900001,inv=17,classID=2,subclassID=1,req=1,stats={str=20,dps=20},sources={{kind="dungeon",name="Test"}}}
local b={id=900002,inv=21,classID=2,subclassID=7,stats={str=1,dps=2}}
local c={class="WARRIOR",classID=1,raceID=1,side=1,level=25,equipped={[16]=b},worn={},completed={}}
local rows=XC.Rules.Build({a},c,XC.db.options,XC:GetSlot(16),XC:GetProfile("melee"))
assert(rows.dungeon[1] and rows.dungeon[1].delta==nil)
''')
test('weapon DPS weight applies to hunter ranged slot, not melee stat sticks', '''
local i={classID=2,stats={dps=10,agi=1}}
local w
for _,profile in ipairs(XC:GetProfiles("HUNTER")) do if profile.role=="ranged" then w=profile.weights; break end end
assert(w)
assert(XC.Rules.Score(i,w,18)>XC.Rules.Score(i,w,16))
''')
test('equipped item exclusion and scored downgrade exclusion', '''
local item={id=900001,inv=1,classID=4,subclassID=1,stats={str=1},sources={{kind="quest",name="Test"}}}
local c={class="WARRIOR",classID=1,raceID=1,side=1,level=25,equipped={[1]={stats={str=10}}},worn={},completed={}}
local rows=XC.Rules.Build({item},c,XC.db.options,XC:GetSlot(1),XC:GetProfile("melee")); assert(#rows.reliable==0)
c.equipped={}; c.worn[900001]=true
rows=XC.Rules.Build({item},c,XC.db.options,XC:GetSlot(1),XC:GetProfile("melee")); assert(#rows.reliable==0)
''')
test('pending equipped item does not become an empty zero-score slot', '''
FakeInventory[16]=999999; XC:Refresh()
assert(XC.context.occupied[16] and XC.baselineScore==nil)
assert(XC.lanes.reliable[1].delta==nil)
FakeInventory[16]=nil; XC:Refresh()
''')
test('pinning is idempotent and checklists render', '''
local r=XC.lanes.dungeon[1]; PinnedID=r.item.id
XC:Pin(r,"dungeon"); XC:Pin(r,"dungeon")
local n=0; for _ in pairs(XC.db.pins) do n=n+1 end; assert(n==1)
XC:ShowHunts(); assert(XC.huntWindow.rows[1].pin.item.id==PinnedID)
''')
test('ownership detection and persistence across addon reload', '''
Owned[PinnedID]=1; XC.Client.UpdatePins()
assert(XC.db.pins[tostring(PinnedID)].acquired)
local before=XC.db
FireEvent("ADDON_LOADED","UpgradeCrossroads")
assert(XC.db==before and XC.db.pins[tostring(PinnedID)].acquired)
XC:RenderHunts()
''')
test('weights save, invalid input is atomic, reset restores defaults', '''
SlashCmdList.UPGRADECROSSROADS("weights str=3 agi=0.2")
assert(XC:GetProfile("melee").weights.str==3)
SlashCmdList.UPGRADECROSSROADS("weights str=8 bogus=2")
assert(XC:GetProfile("melee").weights.str==3)
SlashCmdList.UPGRADECROSSROADS("weights reset")
assert(XC:GetProfile("melee").weights.str==1)
''')
test('manual targets validate IDs, source names and waypoint coordinates', '''
XC:ShowTargetEditor(); local f=XC.editor
f.item.edit:SetText("bogus"); f.source.edit:SetText("Test boss"); XC:SavePersonalTarget(); assert(f:IsShown())
f.item.edit:SetText("872"); f.mapID.edit:SetText("1429"); f.x.edit:SetText("101"); f.y.edit:SetText("30")
XC:SavePersonalTarget(); assert(f:IsShown() and not XC.db.custom[872])
f.x.edit:SetText("42"); XC:SavePersonalTarget(); assert(not f:IsShown() and XC.db.custom[872])
assert(XC.db.pins["872"].source.personal)
XC:MapTarget(XC.db.pins["872"].source); assert(LastWaypoint.x==.42 and LastWaypoint.y==.30)
''')
test('personal quest sources without IDs remain safe', '''
assert(XC:SourceText({kind="quest",name="Personal quest",zone="Test",personal=true}):find("Personal"))
assert(XC:Availability({locked=false,source={kind="quest"}}):find("Check"))
''')
test('combat refuses new windows and waypoint actions', '''
XC.window:Hide(); MockCombat=true
SlashCmdList.UPGRADECROSSROADS(""); assert(not XC.window:IsShown())
LastWaypoint=nil; XC:MapTarget({mapID=1429,x=10,y=20}); assert(LastWaypoint==nil)
MockCombat=false
''')
test('item events coalesce and UI handles empty recommendations', '''
FireEvent("BAG_UPDATE_DELAYED"); FireEvent("PLAYER_EQUIPMENT_CHANGED"); assert(#Timers>=1)
FlushTimers()
XC.db.options.solo=true; XC:Refresh()
assert(XC.window.lanes.dungeon.name.text:find("No matching dungeon"))
XC.db.options.solo=false
''')
test('modern item data load event refreshes requested item presentation', '''
FlushTimers(); XC.queued=nil; XC.requested[872]=true
FireEvent("ITEM_DATA_LOAD_RESULT",872,true)
assert(XC.queued and #Timers==1)
FlushTimers()
''')
test('unsupported live rating units cannot create a false comparison', '''
ItemInfo[900010]={name="Test helm",quality=2,ilvl=25,req=20,equip="INVTYPE_HEAD",classID=4,subclassID=3,stats={ITEM_MOD_STRENGTH_SHORT=4,ITEM_MOD_CRIT_RATING_SHORT=8}}
local i=XC.Client.ResolveItem(900010)
assert(i.incomplete and i.stats.str==4 and not i.stats.crit)
FakeInventory[1]=900010; XC.db.slot=1; XC:Refresh()
for _,r in ipairs(XC.lanes.reliable) do assert(r.delta==nil) end
FakeInventory[1]=nil; ItemInfo[900010]=nil; XC.db.slot=16; XC:Refresh()
''')
test('all nine classes, every slot and profile generate valid results', '''
local classes={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11}
for class,id in pairs(classes) do
 local c={class=class,classID=id,raceID=1,side=1,level=25,equipped={},worn={},completed={}}
 for _,slot in ipairs(XC.Slots) do
  for _,profile in ipairs(XC:GetProfiles(class)) do
   local lanes=XC.Rules.Build(XC.Catalog,c,XC.db.options,slot,profile)
   for _,rows in pairs(lanes) do
    local seen={}
    for i,row in ipairs(rows) do
     assert(row.score==row.score and row.score>0)
     assert(not seen[row.item.id]); seen[row.item.id]=true
     if i>1 then assert(rows[i-1].score>=row.score) end
    end
   end
  end
 end
end
''')

test('clicking the displayed item starts a persistent guide directly', '''
XC.db.pins={}; XC.db.activeHunt=nil; XC.db.custom={}; XC.db.slot=16; XC:Refresh(); XC.editor:Hide(); XC.huntWindow:Hide()
XC.window.lanes.dungeon.itemButton.scripts.OnClick()
assert(XC.db.activeHunt and XC.guide:IsShown() and not XC.editor:IsShown() and not XC.huntWindow:IsShown())
XC.window:Hide(); assert(XC.guide:IsShown())
FireEvent("ADDON_LOADED","UpgradeCrossroads"); assert(XC.guide:IsShown())
XC.window:Show()
local row=XC:DisplayRow("dungeon")
if row.source.questID then
 ActiveQuests[row.source.questID]=true; XC:Render()
 assert(XC.window.lanes.dungeon.pin.label.text=="Track + map")
 XC.window.lanes.dungeon.pin.scripts.OnClick()
 assert(QuestDetailsOpened==row.source.questID)
 ActiveQuests[row.source.questID]=nil
end
''')
test('card map action pins a labeled outdoor entrance and opens its map', '''
local item=XC.Catalog[872]
assert(item and item.sources[1].zoneID==1581)
XC:TrackItem({item=item,source=item.sources[1]},"dungeon",true)
assert(LastWaypoint.id==1436 and MapOpened==1436)
assert(XC.Navigation.Resolve(item.sources[1]).point.entrance)
assert(XC.guide.status.text:find("entrance"))
''')
test('missing crafting location keeps guide without a fabricated waypoint', '''
local source={kind="craft",name="Tailoring",spellID=900080,skill=75}
XC:TrackItem({item={id=900080,name="Craft target",sources={source}},source=source},"reliable",true)
assert(XC.guide:IsShown() and XC.guide.step.text:find("recipe"))
assert(LastWaypoint==nil)
assert(XC.guide.map.label.text=="Retry location")
''')
test('an unrelated user waypoint is preserved when a hunt cannot be mapped', '''
XC.Navigation.lastPoint={mapID=1436,x=42.5,y=71.7}
LastWaypoint={id=1429,x=.2,y=.3}
XC.Navigation.ReleaseOwnedWaypoint(); assert(LastWaypoint.id==1429)
''')
test('installed QuestieDB resolves giver locations and ignores sentinel spawns', '''
ProviderQuests={ [900101]={name="Reward quest",startedBy={{900201}},preQuestSingle={900100}},[900100]={name="Before the reward",startedBy={{900200}}} }
ProviderNPCs={ [900200]={name="First giver",spawns={[12]={{-1,-1},{42,65}}}},[900201]={name="Reward giver",spawns={[12]={{51,30}}}} }
LibQuestieDB={Quest={Get=function(id,key) local q=ProviderQuests[id]; return q and q[key] end},Npc={Get=function(id,key) local n=ProviderNPCs[id]; return n and n[key] end},
 Support={Get=function(name) return {private={areaIdToUiMapId="return {[12] = 1429, [999] = 999999}"}} end}}
local r=XC.Navigation.Resolve({kind="quest",questID=900101,name="Reward quest"})
assert(r.questID==900100 and r.prerequisite and r.point.mapID==1429 and r.point.x==42)
assert(r.point.basis=="Installed QuestieDB location")
''')
test('quest completion advances the guide while the main planner is closed', '''
Completed={}; local source={kind="quest",questID=900101,name="Reward quest"}
XC:TrackItem({item={id=900102,name="Quest target",sources={source}},source=source},"reliable",false)
assert(LastWaypoint.x==.42)
XC.window:Hide(); Completed={900100}; FireEvent("QUEST_TURNED_IN",900100); FlushTimers()
assert(XC.guide:IsShown() and LastWaypoint.x==.51)
assert(not XC.guide.step.text:find("PREREQUISITE"))
''')
test('active quest uses live objective tracking rather than its old giver', '''
ActiveQuests[900101]=true; QuestWaypoints[900101]={id=1429,x=.7,y=.8}
local r=XC.Navigation.Resolve({kind="quest",questID=900101,name="Reward quest"})
assert(r.status=="quest" and r.point.x==70)
assert(XC.Navigation.Apply(r,true)); assert(TrackedQuest==900101 and QuestDetailsOpened==900101)
ActiveQuests[900101]=nil; QuestWaypoints[900101]=nil
''')
test('ambiguous prerequisite branches and cycles are explicit and bounded', '''
ProviderQuests[900101].preQuestSingle={900111,900112}; Completed={}
local r=XC.Navigation.Resolve({kind="quest",questID=900101,name="Reward quest"})
assert(r.questID==900101 and r.warning:find("Multiple"))
ProviderQuests[900101].preQuestSingle={900100}; ProviderQuests[900100].preQuestSingle={900101}
r=XC.Navigation.Resolve({kind="quest",questID=900101,name="Reward quest"}); assert(r.warning:find("cycle"))
ProviderQuests[900100].preQuestSingle=nil
''')
test('source selection is inline and tracking can change sources without duplication', '''
local item={id=900301,name="Two source item",sources={{kind="dungeon",name="First boss",mapID=1429,x=20,y=30},{kind="dungeon",name="Second boss",mapID=1429,x=50,y=60}}}
XC.db.pins={}; XC.lanes={reliable={},longterm={},dungeon={{item=item,source=item.sources[1],score=100,delta=100}}}; XC.selection={dungeon=1}; XC.sourceSelection={}
local row=XC:DisplayRow("dungeon"); assert(row.sourceCount==2)
XC:TrackItem(row,"dungeon",false)
XC:CycleCardSource("dungeon"); row=XC:DisplayRow("dungeon"); assert(row.source.name=="Second boss")
XC:TrackItem(row,"dungeon",true)
local n=0; for _ in pairs(XC.db.pins) do n=n+1 end
assert(n==1 and XC.db.pins["900301"].source.name=="Second boss" and LastWaypoint.x==.5)
''')
test('context location editor preselects the item and updates only its source', '''
local pin=XC.db.pins[XC.db.activeHunt]
XC:ShowTargetEditor({item=pin.item,source=pin.source},pin.lane)
local f=XC.editor; assert(f.item.edit.text==tostring(pin.item.id) and f.context)
f.mapID.edit:SetText("1429"); f.x.edit:SetText("66"); f.y.edit:SetText("44")
local old=XC.db.custom[pin.item.id]; XC:SavePersonalTarget()
assert(XC.db.custom[pin.item.id]==old and LastWaypoint.x==.66 and not f:IsShown())
assert(XC.db.locations[XC.Navigation.SourceKey(pin.source)].x==66)
''')
test('unchanged guide does not repeatedly seize a user-selected waypoint', '''
XC:RenderGuide(); LastWaypoint={id=1429,x=.1,y=.1}
FireEvent("BAG_UPDATE_DELAYED"); FlushTimers()
assert(LastWaypoint.x==.1)
''')
test('completed reward quest is not presented as a repeatable pickup', '''
Completed={900101}
local r=XC.Navigation.Resolve({kind="quest",questID=900101,name="Reward quest"})
assert(r.status=="completed" and not r.point)
Completed={}; LibQuestieDB=nil; XC.db.activeHunt=nil; XC.guide:Hide()
''')
test('guide position is saved and restored when its frame is rebuilt', '''
local f=XC.guide
f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-120,-170)
local heading=f.dragHandle
assert(heading); heading.scripts.OnDragStop(heading)
assert(XC.db.guidePosition.x==-120 and XC.db.guidePosition.y==-170)
f:Hide(); XC.guide=nil; XC:BuildGuide()
assert(XC.guide.point[4]==-120 and XC.guide.point[5]==-170)
XC.db.guidePosition=nil
''')

test('shell and tracker preserve native close controls and corner gestures', """
XC:BuildUI(); XC:BuildGuide(); XC:ShowTargetEditor()
for _,f in ipairs({XC.window,XC.guide}) do
 assert(f.resizable and f.resizeGrip and not f.scaleDown and not f.scaleUp)
 assert(f.resizeBounds[1]==f.minWidth and f.resizeBounds[2]==f.minHeight)
 f:SetSize(f.minWidth,f.minHeight)
 assert(f.closeButton.point[2]==f.width-40 and f.closeButton.template=="UIPanelCloseButton")
 assert(f.dragHandle.points.TOPRIGHT[4]==-48)
 assert(f.closeButton:GetFrameLevel()>f.dragHandle:GetFrameLevel())
 MockShift=true; f.resizeGrip.scripts.OnDragStart(); MockShift=false; assert(f.sizing=="BOTTOMRIGHT")
 f.resizeGrip.scripts.OnDragStop(); assert(not f.sizing)
 f:Show(); f.closeButton.scripts.OnClick(); assert(not f:IsShown())
end
XC.db.trackerHidden=nil
""")

test('gear detail pane reflows within the shared page host', """
local f=XC.window; f:SetSize(900,720); local before=f.lanes.reliable.width
f:SetSize(1300,900); assert(f.lanes.reliable.width>before)
assert(f.pageHost.width==f.width-36)
for _,page in pairs(f.pages) do assert(page.width==f.pageHost.width and page.height==f.pageHost.height) end
local c=f.lanes.reliable
assert(c.point[2]+c.width<=f.gearPage.width)
assert(c.pin.width+c.chat.width+10<=c.width-284)
""")

test('main shell geometry saves and restores independently of page selection', """
local f=XC.window; f:SetSize(1120,820); f:SetScale(.85)
f:ClearAllPoints(); f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",90,-130); f:SaveGeometry()
XC:ShowPage("hunts"); XC:ShowPage("help")
assert(f.width==1120 and f.height==820 and f:GetScale()==.85)
assert(XC.db.windows.planner.position.x==90 and XC.db.windows.planner.position.y==-130)
""")

test('settings scale slider changes the shared shell and keeps tracker scale', """
XC:ShowAppearance(); local f=XC.appearanceWindow; local tracker=XC.guide:GetScale()
f.scaleSlider:SetValue(90)
assert(math.abs(XC.window:GetScale()-.9)<.001 and XC.guide:GetScale()==tracker)
assert(XC.db.windows.planner.scale==XC.window:GetScale())
""")

test('tracker supports compact scrolling and stays closed until explicitly reopened', """
local item=XC.Catalog[872]; XC:TrackItem({item=item,source=item.sources[1]},"dungeon",false)
local f=XC.guide; f:SetSize(330,330)
assert(f.scroll.scrollChild==f.content and f.content.height>0)
assert(-f.map.point[3]+f.map.height<=-f.next.point[3]-7)
assert(-f.next.point[3]+f.next.height<=f.height-29)
f.closeButton.scripts.OnClick(); FireEvent("BAG_UPDATE_DELAYED"); FlushTimers()
assert(not f:IsShown() and XC.db.activeHunt)
SlashCmdList.UPGRADECROSSROADS("guide"); assert(f:IsShown())
XC:ShowHunts(); assert(not f:IsShown()); XC.window:Hide(); assert(f:IsShown())
XC:ShowAbout(); assert(not f:IsShown()); XC.window:Hide(); assert(f:IsShown())
""")
test('chat action opens an unsent draft and inserts into an existing draft', """
ItemInfo[872]={name="Rockslicer",quality=2,equip="INVTYPE_2HWEAPON",classID=2,subclassID=1,stats={}}
ChatDraft=""; ChatActive=false
assert(XC:LinkItem(XC.Catalog[872]) and ChatDraft=="item:872" and ChatActive)
ChatDraft="Looking for "; assert(XC:LinkItem(XC.Catalog[872]))
assert(ChatDraft=="Looking for item:872" and ChatSent==0)
""")
test('uncached links request data without changing a draft or creating a hunt', """
local item={id=99999999,name="Not cached"}; local before=ChatDraft; local active=XC.db.activeHunt
assert(not XC:LinkItem(item))
assert(ChatDraft==before and ChatSent==0 and XC.db.activeHunt==active)
assert(XC.requested[item.id])
""")
test('chat namespace fallback supports modern clients and missing APIs safely', """
local get,insert,open=ChatEdit_GetActiveWindow,ChatEdit_InsertLink,ChatFrame_OpenChat
ChatEdit_GetActiveWindow=nil; ChatEdit_InsertLink=nil; ChatFrame_OpenChat=nil
local draft=""
ChatFrameUtil={GetActiveWindow=function() return true end,InsertLink=function(link) draft=draft..link; return true end,OpenChat=function(link) draft=link end}
assert(XC:LinkItem(XC.Catalog[872]) and draft=="item:872")
ChatFrameUtil=nil; assert(not XC:LinkItem(XC.Catalog[872]))
ChatEdit_GetActiveWindow=get; ChatEdit_InsertLink=insert; ChatFrame_OpenChat=open
""")
test('right-click and shift-click link items while control-click previews', """
XC:ShowPage("gear"); XC.db.slot=16; XC.search=""; XC:Refresh()
local row=XC:DisplayRow("reliable"); local item=row.item
ItemInfo[item.id]={name=item.name,quality=2,equip="INVTYPE_WEAPON",classID=2,subclassID=7,stats={}}
local b=XC.window.lanes.reliable.itemButton; local active=XC.db.activeHunt
ChatDraft=""; ChatActive=true; b.scripts.OnClick(b,"RightButton")
assert(ChatDraft=="item:"..item.id and XC.db.activeHunt==active)
MockShift=true; b.scripts.OnClick(b,"LeftButton"); MockShift=false
assert(ChatDraft=="item:"..item.id.."item:"..item.id and XC.db.activeHunt==active)
MockControl=true; b.scripts.OnClick(b,"LeftButton"); MockControl=false
assert(PreviewedLink=="item:"..item.id and XC.db.activeHunt==active and ChatSent==0)
XC.window.lanes.reliable.chat.scripts.OnClick(); assert(ChatSent==0)
ItemInfo[item.id]=nil
""")
test('search filters item and source names without changing saved hunts', """
local count=0; for _ in pairs(XC.db.pins) do count=count+1 end
local function query(q) XC.window.search.edit:SetText(q); XC.window.search.edit.scripts.OnTextChanged(XC.window.search.edit,true) end
query("zzzz_unmatched_%["); for _,rows in pairs(XC.lanes) do assert(#rows==0) end
assert(XC.window.lanes.reliable.name.text:find("No matches"))
query("blacksmithing"); assert(#XC.lanes.longterm>0)
for _,rows in pairs(XC.lanes) do for _,row in ipairs(rows) do assert(XC:SourceText(row.source):lower():find("blacksmithing",1,true)) end end
XC.window.clearSearch.scripts.OnClick(); assert(#XC.lanes.reliable>0)
local after=0; for _ in pairs(XC.db.pins) do after=after+1 end; assert(after==count)
""")
test('hunts reflow notes and support obtained filtering and direct chat', """
local pin=XC:EnsureHunt({item=XC.Catalog[872],source=XC.Catalog[872].sources[1]},"dungeon"); pin.acquired=nil
XC:ShowHunts(); local f=XC.huntWindow
XC.window:SetSize(900,720); local row
for _,r in ipairs(f.rows) do if r.pin==pin then row=r end end
assert(row and row.width==f.width-44 and row.noteInput.width==row.width-32)
row.noteInput.edit.focus=true; row.noteInput.edit:SetText("Meet at the entrance")
row.noteInput.edit.scripts.OnTextChanged(row.noteInput.edit,true)
XC.window:SetSize(1120,820); assert(row.noteInput.edit.text=="Meet at the entrance" and pin.notes=="Meet at the entrance")
ChatDraft=""; row.chat.scripts.OnClick(); assert(ChatDraft=="item:872")
row.noteInput.edit.focus=false
pin.acquired=true; f.hideObtained:SetChecked(true); f.hideObtained.scripts.OnClick(f.hideObtained)
assert(not row:IsShown() or row.pin~=pin)
f.hideObtained:SetChecked(false); f.hideObtained.scripts.OnClick(f.hideObtained); pin.acquired=nil
""")
test('character panel remains free of addon launcher buttons', """
assert(not XC.launcher)
for _,f in ipairs(Frames) do assert(f.parent~=CharacterFrame) end
assert(XC.minimapButton)
""")
test('corner drag scales every window around its fixed top-left corner', """
local parentScale=UIParent:GetScale(); UIParent:SetScale(.8)
for _,f in ipairs({XC.window,XC.guide}) do
 f:Show(); f:SetScale(1); f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",30,-20)
 local width,height=f.width,f.height; local effective=f:GetEffectiveScale()
 local left,top=f:GetLeft()*effective,f:GetTop()*effective
 MockCursorX=left+width*effective-10; MockCursorY=top-height*effective+10
 f.resizeGrip.scripts.OnDragStart(); assert(not f.sizing and f.resizeGrip.scripts.OnUpdate)
 MockCursorX=MockCursorX+width*effective*.2; MockCursorY=MockCursorY-height*effective*.2
 f.resizeGrip.scripts.OnUpdate()
 assert(math.abs(f:GetScale()-1.2)<.00001 and f.width==width and f.height==height)
 assert(math.abs(f:GetLeft()*f:GetEffectiveScale()-left)<.00001)
 assert(math.abs(f:GetTop()*f:GetEffectiveScale()-top)<.00001)
 f.resizeGrip.scripts.OnDragStop(); assert(not f.resizeGrip.scripts.OnUpdate)
 assert(math.abs(XC.db.windows[f.windowID].scale-1.2)<.00001)
 f:Hide()
end
MockCursorX=nil; MockCursorY=nil; UIParent:SetScale(parentScale)
""")
test('corner scaling shrinks smoothly and clamps at the supported scale bounds', """
local f=XC.window; XC:Appearance().readable=false; f:Show(); f:SetScale(1)
MockCursorX=1000; MockCursorY=400; f.resizeGrip.scripts.OnDragStart()
local width,height=f.width*f:GetEffectiveScale(),f.height*f:GetEffectiveScale()
MockCursorX=1000-width*.25; MockCursorY=400+height*.25; f.resizeGrip.scripts.OnUpdate()
assert(math.abs(f:GetScale()-.75)<.00001)
MockCursorX=1000-width*10; MockCursorY=400+height*10; f.resizeGrip.scripts.OnUpdate(); assert(f:GetScale()==.5)
MockCursorX=1000+width*10; MockCursorY=400-height*10; f.resizeGrip.scripts.OnUpdate(); assert(f:GetScale()==1.5)
f.resizeGrip.scripts.OnMouseUp(); assert(not f.resizeGrip.scripts.OnUpdate)
assert(XC.db.windows.planner.scale==1.5)
f:Hide(); MockCursorX=nil; MockCursorY=nil; XC:Appearance().readable=true
""")
test('shift corner drag resizes layout and interrupted scaling cleans up', """
local f=XC.window; f:Show(); f:SetScale(1)
MockShift=true; f.resizeGrip.scripts.OnDragStart(); MockShift=false
assert(f.sizing=="BOTTOMRIGHT" and not f.resizeGrip.scripts.OnUpdate)
f:SetSize(1280,900); f.resizeGrip.scripts.OnDragStop()
assert(f:GetScale()==1 and XC.db.windows.planner.width==1280)
f.resizeGrip.scripts.OnDragStart(); assert(f.resizeGrip.scripts.OnUpdate)
f:Hide(); assert(not f.resizeGrip.scripts.OnUpdate)
f:Show(); f.resizeGrip.scripts.OnDragStart(); f:ResetGeometry()
assert(not f.resizeGrip.scripts.OnUpdate and f.width==f.defaultGeometry.width)
f:Hide()
""")
test('appearance opens from the planner and slash command with saved defaults', """
XC.window.appearance.scripts.OnClick(); local f=XC.appearanceWindow
assert(f and f:IsShown() and f.info and f.scroll.scrollChild==f.content)
assert(f:GetParent()==XC.window.pageHost and not f.resizable and not f.closeButton and XC:Appearance().theme=="classic")
f:Hide(); SlashCmdList.UPGRADECROSSROADS("appearance"); assert(f:IsShown()); f:Hide()
""")
test('preset and opacity controls update existing panels without fading text', """
XC:ShowAppearance(); local f=XC.appearanceWindow; local old=XC.window
f.preset.scripts.OnClick(); assert(XC.db.appearance.theme=="alliance" and XC.window==old)
f.opacity:SetValue(25)
assert(XC.window.bg[4]==.25 and XC.window.current.bg[4]==.25)
assert(XC.window.lanes.reliable.name.color[4]~=0.25)
assert(not XC.window.profile.backdrop and XC.window.border[4]==1)
""")
test('custom HEX colors validate atomically and color picker cancel restores them', """
local f=XC.appearanceWindow; local edit=f.colorFields.accent.input.edit
local old=XC.db.appearance.accent
edit:SetText("oops"); edit.scripts.OnEnterPressed(edit); assert(XC.db.appearance.accent==old)
edit:SetText("#FF8040"); edit.scripts.OnEnterPressed(edit)
assert(XC.db.appearance.accent=="FF8040" and XC.Colors.gold[1]==1)
ColorPickerFrame={SetupColorPickerAndShow=function(self,info) self.info=info end,GetColorRGB=function() return .2,.4,.6 end}
f.colorFields.accent.choose.scripts.OnClick(); ColorPickerFrame.info.swatchFunc()
assert(XC.db.appearance.accent=="336699")
ColorPickerFrame.info.cancelFunc(); assert(XC.db.appearance.accent=="FF8040")
ColorPickerFrame=nil
""")
test('readable scaling snaps fonts to physical pixels and prevents tiny windows', """
local f=XC.window; f:SetScale(.5); XC:Appearance().readable=true; XC:ApplyAppearance()
assert(f:GetScale()==.8 and XC.db.windows.planner.scale==.8)
local old=UIParent:GetScale(); UIParent:SetScale(.75); XC.W.SetWindowScale(f,.8)
for _,record in ipairs(XC.W.fonts) do
 local parent=record.parent
 while parent and parent~=f do parent=parent:GetParent() end
 if parent==f then
  local pixels=record.object.fontSize*record.parent:GetEffectiveScale()
  assert(pixels>=12-.0001 and math.abs(pixels-math.floor(pixels+.5))<.0001)
  assert(record.object.fontFlags=="")
  assert(record.object.shadowOffset[1]==(record.paper and 0 or 1))
 end
end
UIParent:SetScale(old); XC:ApplyAppearance()
""")
test('appearance can change fonts sizes outlines and restore without clearing hunts', """
local f=XC.appearanceWindow; local pins=XC.db.pins
assert(XC:Appearance().font=="classic" and XC.window.profile.label.fontPath:find("FRIZQT"))
local standard=STANDARD_TEXT_FONT
STANDARD_TEXT_FONT="Fonts\\\\CLIENT_STANDARD.TTF"; XC:ApplyAppearance()
assert(XC.window.profile.label.fontPath==STANDARD_TEXT_FONT and XC.window.journal.description.fontPath==STANDARD_TEXT_FONT)
STANDARD_TEXT_FONT=standard; XC:ApplyAppearance()
f.font.scripts.OnClick(); assert(XC.db.appearance.font=="plain" and XC.db.appearance.fontChosen)
FireEvent("ADDON_LOADED","UpgradeCrossroads")
assert(XC:Appearance().font=="plain" and XC.window.profile.label.fontPath:find("ARIALN"))
f.textSize.scripts.OnClick(); assert(XC.db.appearance.textBoost==1)
f.outline:SetChecked(false); f.outline.scripts.OnClick(f.outline)
assert(XC.window.profile.label.fontPath:find("ARIALN") and XC.window.profile.label.fontFlags=="")
f.font.scripts.OnClick(); assert(XC:Appearance().font=="classic" and XC.window.profile.label.fontPath:find("FRIZQT"))
f.reset.scripts.OnClick(); assert(XC:Appearance().theme=="classic" and XC:Appearance().font=="classic" and not XC:Appearance().outline and XC.db.pins==pins)
f:Hide()
""")
test('journal acquisition filters inspect sources before one-click tracking', """
XC:ShowPage("gear"); XC:SetJournalSlot(16)
local p=XC.window.journal; p.clear.scripts.OnClick()
XC.db.journalUI.state="active"; XC.db.journalUI.lane="all"; XC:Refresh()
p.filterButton.scripts.OnClick(); p.lane.scripts.OnClick(); p.lane.scripts.OnClick()
assert(XC.db.journalUI.lane=="dungeon" and #p.entries>1)
local before=XC.db.activeHunt; local selected=p.entries[2]
local button
for _,b in ipairs(p.rows) do if b:IsShown() and b.label.text:find(selected.item.name,1,true) then button=b; break end end
assert(button); button.scripts.OnClick(button,"LeftButton")
assert(p.selectedRow.key==selected.key and XC.db.activeHunt==before)
assert(p.title.text==selected.item.name and p.source.text~="")
p.track.scripts.OnClick(); assert(XC.db.activeHunt and XC.guide:IsShown())
XC:ShowPage("gear"); XC.db.journalUI.lane="all"; XC:SetJournalSlot(0)
XC.db.journalUI.filters=false; p:ApplyLayout()
""")
test('native framing and approved logo paths are used consistently', """
assert(XC.window.backdrop.bgFile:find("WHITE8X8",1,true) and XC.window.bg[4]==1)
assert(XC.window.profile.template:find("UIPanelButtonTemplate",1,true))
assert(XC.minimapButton.icon.texture:match("UpgradeCrossroads.+Media.+IconRound$"))
assert(XC.window.headerIcon.texture:match("UpgradeCrossroads.+Media.+LogoRound$"))
""")
test('page navigation is exclusive and never creates floating settings windows', """
XC:ShowTargetEditor(); XC:ShowAppearance(); local root=XC.window
local public={"gear","hunts","appearance","help","editor"}
for _,id in ipairs(public) do XC:ShowPage(id) end
assert(not root.nav.compare)
local navCount=0; for _ in pairs(root.nav) do navCount=navCount+1 end; assert(navCount==5)
local count=#Frames
for pass=1,4 do
 for _,id in ipairs(public) do
  XC:ShowPage(id); local shown=0
  for key,page in pairs(root.pages) do
   assert(page:GetParent()==root.pageHost and not page.resizable and not page.closeButton)
   if page:IsShown() then shown=shown+1; assert(key==id) end
  end
  assert(shown==1 and root.activePage==id)
 end
end
XC:ShowPage("compare")
assert(root.activePage=="gear" and root.journal:IsShown() and not root.pages.compare:IsShown())
assert(#Frames==count and root.toplevel and root.raised>0)
""")
test('native buttons use one measured label with no custom backdrop or tiny text chrome', """
XC:Appearance().textBoost=2; XC:ApplyAppearance(); XC.W.SetWindowScale(XC.window,.8)
for _,b in ipairs(XC.W.buttons) do
 local parent=b
 while parent and parent~=XC.window do parent=parent:GetParent() end
 if parent==XC.window then
  assert(b.label==b:GetFontString() and not b.backdrop)
  assert(b:GetWidth()+.01>=b.label:GetStringWidth()+20)
  assert(b:GetHeight()+.01>=b.label:GetStringHeight()+6)
 end
end
assert(not XC.window.scaleDown and not XC.window.scaleUp and not XC.window.closeButton.label)
assert(not XC.window.resizeGrip.label and XC.window.resizeGrip.normalTexture)
XC:Appearance().textBoost=0; XC:ApplyAppearance()
""")
test('closing the shared shell hides every page and resumes the tracker', """
local item=XC.Catalog[872]; XC:TrackItem({item=item,source=item.sources[1]},"dungeon",false)
XC:ShowHunts(); assert(not XC.guide:IsShown())
XC.window.closeButton.scripts.OnClick()
for _,page in pairs(XC.window.pages) do assert(not page:IsShown()) end
assert(XC.guide:IsShown())
XC.minimapButton.scripts.OnClick(XC.minimapButton,"LeftButton")
assert(XC.window.activePage=="hunts" and XC.huntWindow:IsShown())
XC:ShowTargetEditor({item=item,source=item.sources[1]},"dungeon")
XC.editor.cancel.scripts.OnClick(); assert(XC.window.activePage=="hunts" and not XC.editor:IsShown())
""")
test('visual migration preserves custom colors opacity and saved hunts', """
local db=XC.db; local pins=db.pins
local prior=db.appearance; db.schema=4
 db.appearance={theme="classic",background="112233",opacity=.65,font="classic",outline=true}
FireEvent("ADDON_LOADED","UpgradeCrossroads")
assert(db.schema==6 and db.pins==pins)
assert(db.appearance.background=="112233" and db.appearance.opacity==.65)
assert(db.appearance.font=="classic" and not db.appearance.outline)
db.schema=5; db.appearance.font="plain"
FireEvent("ADDON_LOADED","UpgradeCrossroads")
assert(db.schema==6 and db.appearance.font=="classic" and db.pins==pins)
assert(db.appearance.background=="112233" and db.appearance.opacity==.65)
db.schema=5; db.appearance.font="plain"; db.appearance.fontChosen=true
FireEvent("ADDON_LOADED","UpgradeCrossroads")
assert(db.schema==6 and db.appearance.font=="plain" and db.pins==pins)
db.appearance=prior; XC:ApplyAppearance()
""")
test('large text with global UI scaling keeps form and tracker controls apart', """
local previous=UIParent:GetScale(); UIParent:SetScale(.75)
XC:Appearance().textBoost=2; XC:ApplyAppearance(); XC.W.SetWindowScale(XC.window,.8)
XC:ShowAppearance(); local f=XC.appearanceWindow
for _,field in pairs(f.colorFields) do
 assert(field.input.point[2]>=field.choose.point[2]+field.choose.width+15)
end
local item=XC.Catalog[872]; XC:ShowTargetEditor({item=item,source=item.sources[1]},"dungeon")
assert(-XC.editor.save.point[3]>=-XC.editor.status.point[3]+XC.editor.status.height+15)
XC:TrackItem({item=item,source=item.sources[1]},"dungeon",false); XC.W.SetWindowScale(XC.guide,.8)
assert(XC.guide.location.point[2]>=XC.guide.map.point[2]+XC.guide.map.width+10)
UIParent:SetScale(previous); XC:Appearance().textBoost=0; XC:ApplyAppearance()
""")
test('resetwindows restores window defaults and keeps hunts and notes', """
local pin=XC.db.pins["872"]; local notes=pin.notes
SlashCmdList.UPGRADECROSSROADS("resetwindows")
for _,f in ipairs({XC.window,XC.guide}) do
 assert(f.width==f.defaultGeometry.width and f.height==f.defaultGeometry.height)
 assert(f:GetScale()==f.defaultGeometry.scale)
end
assert(XC.db.pins["872"]==pin and pin.notes==notes)
""")

test('faction selector offers exactly Alliance Horde and Both with detected defaults', """
local R=XC.Rules; assert(#R.FactionOrder==3 and not R.FactionLabels.player)
assert(R.FactionMode({}, {side=1})=="alliance" and R.FactionMode({}, {side=2})=="horde")
XC.db.options.faction=nil; MockFaction="Horde"; XC:Refresh()
assert(XC.db.options.faction=="horde" and XC.window.faction.label.text:find("Horde"))
MockFaction="Alliance"; XC:SetFactionFilter("alliance")
""")
test('faction filtering applies to every tagged source and keeps shared sources', """
local R=XC.Rules; local c={side=1,classID=1,raceID=1,completed={}}
for _,mode in ipairs(R.FactionOrder) do
 local o={faction=mode,crafted=true,auction=true}
 for _,kind in ipairs({"quest","dungeon","raid","craft","vendor","world","auction"}) do
  assert(R.SourceAllowed({kind=kind,side=1},c,o)==(mode~="horde"))
  assert(R.SourceAllowed({kind=kind,side=2},c,o)==(mode~="alliance"))
  for _,side in ipairs({0,3}) do assert(R.SourceAllowed({kind=kind,side=side},c,o)) end
  assert(R.SourceAllowed({kind=kind},c,o))
 end
end
local o={faction="both",solo=true,crafted=false,auction=false}
assert(not R.SourceAllowed({kind="dungeon",side=2},c,o))
assert(not R.SourceAllowed({kind="craft",side=1},c,o))
""")
test('opposite faction browsing uses faction identity without borrowing player race or history', """
local R=XC.Rules; local c={side=1,classID=1,raceID=1,completed={[900401]=true}}
local h={kind="quest",side=2,raceMask=2,classMask=1,questID=900401}
assert(R.SourceAllowed(h,c,{faction="horde",crafted=true}))
assert(R.SourceAllowed(h,c,{faction="both",crafted=true}))
assert(not R.SourceAllowed(h,c,{faction="alliance",crafted=true}))
h.classMask=2; assert(not R.SourceAllowed(h,c,{faction="both",crafted=true}))
assert(not R.SourceAllowed({kind="quest",side=1,raceMask=2},c,{faction="both",crafted=true}))
assert(not R.SourceAllowed({kind="quest",side=1,questID=900401},c,{faction="both",crafted=true}))
""")
test('changing faction updates alternate sources without deleting saved hunts', """
local id=900402
local item={id=id,name="Faction test crown",inv=1,classID=4,subclassID=1,req=1,stats={str=999},sources={
 {kind="quest",name="Alliance reward",side=1,questID=900402},
 {kind="quest",name="Horde reward",side=2,raceMask=2,questID=900403}}}
local slot=XC.db.slot; XC.db.slot=1; XC.db.custom[id]=item
XC:SetFactionFilter("both"); local row=XC:DisplayRow("reliable")
assert(row.item.id==id and row.sourceCount==2)
local pin=XC:EnsureHunt(row,"reliable"); pin.notes="Keep these notes"; pin.checks[1]=true
XC:CycleCardSource("reliable"); assert(XC:DisplayRow("reliable").source.side==2)
XC:SetFactionFilter("alliance"); row=XC:DisplayRow("reliable"); assert(row.source.side==1 and row.sourceCount==1)
XC:SetFactionFilter("horde"); row=XC:DisplayRow("reliable"); assert(row.source.side==2 and row.sourceCount==1)
assert(XC:Availability(row):find("not available") and XC:SourceText(row.source):find("Horde only"))
assert(XC.db.pins[tostring(id)]==pin and pin.notes=="Keep these notes" and pin.checks[1])
XC.db.custom[id]=nil; XC.db.pins[tostring(id)]=nil; XC.db.slot=slot; XC:SetFactionFilter("alliance")
""")
test('faction button cycles three choices and its saved selection survives initialization', """
XC:SetFactionFilter("alliance"); local b=XC.window.faction
b.scripts.OnClick(); assert(XC.db.options.faction=="horde")
b.scripts.OnClick(); assert(XC.db.options.faction=="both")
FireEvent("ADDON_LOADED","UpgradeCrossroads"); assert(XC.db.options.faction=="both")
b.scripts.OnClick(); assert(XC.db.options.faction=="alliance")
local prior=UIParent:GetScale(); UIParent:SetScale(.75); XC:Appearance().textBoost=2; XC:ApplyAppearance(); XC.W.SetWindowScale(XC.window,.8)
local last=XC.window.auction
assert(b.point[2]>=last.point[2]+last.width+2+last.label:GetStringWidth()+8)
assert(b.point[2]+b.width<=XC.window.gearPage.width-9)
UIParent:SetScale(prior); XC:Appearance().textBoost=0; XC:ApplyAppearance(); XC.window:ResetGeometry()
""")

test('Hunter ranged recommendations exclude thrown in every path and retain shot weapons', '''
local c={class="HUNTER",classID=3,raceID=1,side=1,level=25,equipped={},worn={},completed={}}
local options={solo=false,crafted=true,auction=false,faction="both"}
local catalog={}
for _,sub in ipairs({2,3,16,18,19}) do
    catalog[#catalog+1]={id=990100+sub,name="Weapon",classID=2,subclassID=sub,
        inv=sub==16 and 25 or (sub==19 and 26 or 15),req=1,stats={agi=10,dps=sub==16 and 9999 or 30},
        sources={{kind="quest",name="Quest"},{kind="dungeon",name="Dungeon"}}}
end
local profile={weights={agi=1,dps=5},weaponDpsSlots={[18]=true}}
local lanes=XC.Rules.Build(catalog,c,options,XC:GetSlot(18),profile)
for _,lane in pairs(lanes) do
    assert(#lane==3)
    for _,row in ipairs(lane) do assert(row.item.subclassID==2 or row.item.subclassID==3 or row.item.subclassID==18) end
end
-- Real dagger melee stat sticks remain eligible; the thrown classification is distinct.
assert(XC.Rules.Usable({inv=13,classID=2,subclassID=15},c,XC:GetSlot(16)))
-- Quest faction/class gates are not bypassed by a matching weapon type.
catalog[1].classMask=1
assert(not XC.Rules.Usable(catalog[1],c,XC:GetSlot(18)))
''')
test('ranged weapon types stay class-specific across all nine classes', '''
local c={level=60}
local ranged=XC:GetSlot(18)
for class,id in pairs({WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11}) do
    c.class=class; c.classID=id
    for _,sub in ipairs({2,3,16,18,19}) do
        local expected=(sub==19 and (class=="PRIEST" or class=="MAGE" or class=="WARLOCK"))
            or (sub~=19 and (class=="WARRIOR" or class=="ROGUE" or (class=="HUNTER" and sub~=16)))
        local item={classID=2,subclassID=sub,inv=sub==16 and 25 or (sub==19 and 26 or 15)}
        assert(not not XC.Rules.Usable(item,c,ranged)==not not expected,class.." / "..sub)
    end
end
''')
test('explicit weapon DPS slots override stat heuristics for melee ranged and feral profiles', '''
local item={classID=2,stats={agi=2,dps=20}}
local weights={agi=1,dps=5,rap=.5}
local melee={[16]=true,[17]=true}; local ranged={[18]=true}; local feral={}
assert(XC.Rules.Score(item,weights,16,melee)==102)
assert(XC.Rules.Score(item,weights,18,melee)==2)
assert(XC.Rules.Score(item,weights,18,ranged)==102)
assert(XC.Rules.Score(item,weights,16,ranged)==2)
assert(XC.Rules.Score(item,weights,16,feral)==2)
assert(XC.Rules.Score({classID=4,stats={agi=2,dps=20}},weights,16,melee)==2)
local c={class="HUNTER",classID=3,raceID=1,side=1,level=60,equipped={
    [16]={inv=13,classID=2,subclassID=15,stats={agi=1,dps=10}}},worn={},completed={}}
local target={id=990199,inv=13,classID=2,subclassID=15,req=1,stats={agi=1,dps=20},sources={{kind="quest",name="Test"}}}
local lanes=XC.Rules.Build({target},c,{crafted=true},XC:GetSlot(16),{weights=weights,weaponDpsSlots=melee})
assert(#lanes.reliable==1 and lanes.reliable[1].delta==50)
''')

test('class selectors expose only the character specs and preserve independent custom weights', """
local oldClass,oldID,oldProfile=MockClass,MockClassID,XC.db.profile
local pin=XC.db.pins[tostring(PinnedID)]; local oldNote=pin and pin.notes
MockClass="MAGE"; MockClassID=8; XC.db.profile="mage_frost"; XC:Refresh()
assert(#XC:GetProfiles()==3 and XC.window.classLabel.text=="Mage")
assert(XC.window.profile.label.text:find("Frost",1,true))
assert(not XC:SetProfile("hunter_marksmanship"))
SlashCmdList.UPGRADECROSSROADS("weights int=4")
assert(XC:GetProfile("mage_frost").weights.int==4)
XC.window.profile.scripts.OnClick(); assert(XC.db.profile=="mage_arcane")
assert(XC:GetProfile(XC.db.profile).weights.int==.6)
SlashCmdList.UPGRADECROSSROADS("weights int=2")
XC:SetProfile("mage_frost"); assert(XC:GetProfile(XC.db.profile).weights.int==4)
FireEvent("ADDON_LOADED","UpgradeCrossroads"); assert(XC.db.profile=="mage_frost")
SlashCmdList.UPGRADECROSSROADS("weights reset"); assert(XC:GetProfile(XC.db.profile).weights.int==.6)
assert(XC:GetProfile("mage_arcane").weights.int==2)
XC.db.weights.mage_arcane=nil
if pin then assert(XC.db.pins[tostring(PinnedID)]==pin and pin.notes==oldNote) end
MockClass=oldClass; MockClassID=oldID; XC.db.profile=oldProfile; XC:Refresh()
""")
test('legacy class roles and custom weights migrate once without clearing saved goals', """
local original=XC.db
local hunt={notes="keep",checks={[1]=true}}
XC.db={profile="ranged",weights={ranged={agi=8,dps=3},hunter_marksmanship={agi=7}},pins={hunt=hunt},options={},windows={}}
XC:MigrateProfiles("HUNTER")
assert(XC.db.profile=="hunter_beastmastery" and XC.db.profileMigration==1)
assert(XC.db.weights.hunter_beastmastery.agi==8)
assert(XC.db.weights.hunter_survivalranged.agi==8)
assert(XC.db.weights.hunter_marksmanship.agi==7)
assert(XC.db.weights.hunter_beastmastery~=XC.db.weights.ranged)
assert(XC.db.weights.hunter_beastmastery~=XC.db.weights.hunter_survivalranged)
assert(XC.db.pins.hunt==hunt and hunt.notes=="keep" and hunt.checks[1])
XC.db.weights.hunter_beastmastery=nil; XC:MigrateProfiles("HUNTER")
assert(not XC.db.weights.hunter_beastmastery)
assert(XC:ResolveProfileID("tank","DRUID")=="druid_feralbear")
assert(XC:ResolveProfileID("caster","PRIEST")=="priest_shadow")
assert(XC:ResolveProfileID("healer","PALADIN")=="paladin_holy")
assert(XC:ResolveProfileID("hunter_marksmanship","MAGE")=="mage_frost")
XC.db=original; XC:Refresh()
""")
test('survival playstyles choose the relevant weapon DPS slot without assuming retail mechanics', """
local priorClass,priorID=MockClass,MockClassID
MockClass="HUNTER"; MockClassID=3
local melee=XC:GetProfile("hunter_survival"); local ranged=XC:GetProfile("hunter_survivalranged")
local weapon={classID=2,stats={dps=20}}
assert(XC.Rules.Score(weapon,melee.weights,16,melee.weaponDpsSlots)==100)
assert(XC.Rules.Score(weapon,melee.weights,18,melee.weaponDpsSlots)==0)
assert(XC.Rules.Score(weapon,ranged.weights,16,ranged.weaponDpsSlots)==0)
assert(XC.Rules.Score(weapon,ranged.weights,18,ranged.weaponDpsSlots)==100)
MockClass="DRUID"; MockClassID=11
local cat=XC:GetProfile("druid_feralcat")
assert(XC.Rules.Score(weapon,cat.weights,16,cat.weaponDpsSlots)>0)
MockClass=priorClass; MockClassID=priorID
""")
test('long spec names remain within the shared page at minimum size and largest text', """
local class,id,profile=MockClass,MockClassID,XC.db.profile
MockClass="HUNTER"; MockClassID=3; XC.db.profile="hunter_survivalranged"; XC:Refresh()
XC.window:SetSize(900,720); XC:Appearance().textBoost=2; XC:ApplyAppearance()
local f=XC.window
assert(f.classLabel.text=="Hunter" and f.profile.label.text:find("Survival (ranged)",1,true))
assert(f.profile.point[3]==-40)
assert(f.profile.point[2]+f.profile.width<f.gearPage.width-10)
assert(f.profileBasis.point[2]+f.profileBasis.width<=f.gearPage.width-9)
assert(f.current.point[3]==-87)
assert(f.faction.point[2]>f.auction.point[2]+f.auction.width+f.auction.label:GetStringWidth()+10)
XC:Appearance().textBoost=0; XC:ApplyAppearance(); XC.window:ResetGeometry()
MockClass=class; MockClassID=id; XC.db.profile=profile; XC:Refresh()
""")

test('journal model ranks every slot and preserves removal and ownership history', (ROOT/'tests/journal_model_tests.lua').read_text())

test('quest journal opens grouped slots and selects inline without creating a hunt', '''
JournalUITest={db=XC.db,savedVars=UpgradeCrossroadsDB,catalog=XC.Client.Catalog,class=MockClass,classID=MockClassID,level=MockLevel,
    owned=Owned,inventory=FakeInventory,completed=Completed,sourceSelection=XC.sourceSelection,
    journalSourceSelection=XC.journalSourceSelection,profile=XC.db.profile}
MockClass="WARRIOR"; MockClassID=1; MockLevel=21; Owned={}; FakeInventory={}; Completed={}
local db={}; for k,v in pairs(XC.db) do db[k]=v end
db.profile="warrior_arms"; db.slot=16; db.pins={}; db.pinOrder=0; db.custom={}; db.journal={}; db.journalUI={}
db.weights={}; for id,weights in pairs(XC.db.weights) do db.weights[id]=weights end
db.options={faction="alliance",solo=false,crafted=true,auction=false}; db.activeHunt=nil
XC.db=db; UpgradeCrossroadsDB=db; XC.sourceSelection={}; XC.journalSourceSelection={}
JournalUICatalog={
 [991101]={id=991101,name="Journal Crown",quality=3,inv=1,classID=4,subclassID=1,req=1,stats={str=60},basis="forever",sources={
  {kind="vendor",name="Journal Vendor",zone="Westfall",mapID=1436,x=12,y=34,side=1},
  {kind="dungeon",name="Journal Boss",zone="Journal Dungeon",mapID=1436,x=21,y=43,side=1}}},
 [991102]={id=991102,name="Journal Crafted Crown",quality=2,inv=1,classID=4,subclassID=1,req=1,stats={str=40},basis="forever",sources={
  {kind="craft",name="Journal Crown Recipe",skill=100}}},
 [991103]={id=991103,name="Journal Pendant",quality=3,inv=2,classID=4,subclassID=1,req=1,stats={str=10},basis="forever",sources={
  {kind="vendor",name="Pendant Vendor",zone="Westfall",mapID=1436,x=15,y=35,side=1}}},
 [991104]={id=991104,name="Future Journal Shoulders",quality=3,inv=3,classID=4,subclassID=1,req=40,stats={str=70},basis="forever",sources={
  {kind="vendor",name="Future Vendor",minLevel=40}}},
}
for id,item in pairs(JournalUICatalog) do ItemInfo[id]={name=item.name,quality=item.quality,ilvl=20,req=item.req,equip="INVTYPE_HEAD",classID=4,subclassID=1,stats={ITEM_MOD_STRENGTH_SHORT=item.stats.str}} end
XC.Client.Catalog=function() return JournalUICatalog end
XC.window.journal.query=""; XC.window.journal.search.edit:SetText("")
XC:ShowPage("gear"); XC:Refresh()
local p=XC.window.journal; assert(p and p:IsShown() and not XC.window.pages.compare:IsShown())
assert(p.left.surfaceKind=="list" and p.paper.surfaceKind=="parchment")
assert(#p.entries==3 and p.entries[1].slotID==1 and p.entries[3].slotID==2)
assert(p.rows[1].label.text:find("Head",1,true) and p.rows[4].label.text:find("Neck",1,true))
local before=#Frames; p.rows[5].scripts.OnClick(p.rows[5],"LeftButton")
assert(p.selectedRow.item.id==991103 and p.title.text=="Journal Pendant")
assert(XC.db.activeHunt==nil and not next(XC.db.pins) and #Frames==before)
assert(p.track:GetParent()==p.paper and p.map:GetParent()==p.paper)
''')
test('journal equipment picker filters slots inline and preserves the saved choice', '''
local p=XC.window.journal
p.scroll:SetVerticalScroll(90); p.slotButton.scripts.OnClick()
assert(p.slotPickerOpen and p.slotChoices[0] and p.slotChoices[1] and p.slotChoices[2])
assert(p.slotChoices[2]:IsShown() and p.slotChoices[2]:GetParent()==p.child)
p.slotChoices[2].scripts.OnClick()
assert(not p.slotPickerOpen and XC.db.journalUI.slotID==2 and XC.db.slot==2)
assert(#p.entries==1 and p.selectedRow.item.id==991103 and p.scroll:GetVerticalScroll()==0)
FireEvent("ADDON_LOADED","UpgradeCrossroads"); XC:Refresh()
XC:ShowHunts(); XC:ShowPage("gear")
assert(XC.db.journalUI.slotID==2 and #p.entries==1 and p.selectedRow.slotID==2)
XC:SetJournalSlot(999); assert(XC.db.journalUI.slotID==2)
p.slotButton.scripts.OnClick(); p.slotChoices[0].scripts.OnClick()
assert(XC.db.journalUI.slotID==0 and #p.entries==3 and not p.slotPickerOpen)
-- The consolidated browser must retain access past the old ten-pick cap.
for i=1,12 do
 local id=992200+i; local name=string.format("Journal Extra Crown %02d",i)
 JournalUICatalog[id]={id=id,name=name,quality=2,inv=1,classID=4,subclassID=1,req=1,stats={str=10+i},sources={{kind="vendor",name="Extra Crown Vendor",side=1}}}
 ItemInfo[id]={name=name,quality=2,ilvl=20,req=1,equip="INVTYPE_HEAD",classID=4,subclassID=1,stats={ITEM_MOD_STRENGTH_SHORT=10+i}}
end
XC:SetJournalSlot(1); XC.db.journalUI.limit=10; XC:RenderJournal()
local function visibleItems()
 local count=0
 for _,b in ipairs(p.rows) do if b:IsShown() and b.label.text:find("Journal",1,true) then count=count+1 end end
 return count
end
assert(#p.entries==14 and visibleItems()==10)
p.limit.scripts.OnClick()
assert(XC.db.journalUI.limit==0 and visibleItems()==14 and p.limit.label.text:find("All",1,true))
assert(p.child.height>=14*28, "all matching rows need a reachable scroll range")
local last
for _,b in ipairs(p.rows) do if b:IsShown() and b.label.text:find("Journal Extra Crown 01",1,true) then last=b; break end end
assert(last); last.scripts.OnClick(last,"LeftButton")
assert(p.selectedRow.item.id==992201 and not XC.db.activeHunt)
for i=1,12 do JournalUICatalog[992200+i]=nil; ItemInfo[992200+i]=nil end
XC.db.journalUI.limit=3; XC:SetJournalSlot(0); XC:Refresh(); assert(#p.entries==3)
''')
test('journal equipped comparison distinguishes empty pending comparable and incompatible gear', '''
local p=XC.window.journal; local profile=XC:GetProfile(XC.db.profile)
XC:SetJournalSlot(1); FakeInventory={}; XC:Refresh()
assert(not p.equippedItem and not p.equippedChat.enabled)
assert(p.equippedName.text:lower():find("empty",1,true))
FakeInventory[1]=991190
ItemInfo[991190]={name="Equipped Training Crown",quality=2,ilvl=15,req=1,equip="INVTYPE_HEAD",classID=4,subclassID=1,stats={ITEM_MOD_STRENGTH_SHORT=5}}
XC:Refresh()
local row=p.selectedRow; local equipped=p.equippedItem
local score=XC.Rules.Score(equipped,profile.weights,row.slotID,profile.weaponDpsSlots)
assert(equipped.id==991190 and p.equippedName.text:find("Equipped Training Crown",1,true))
assert(p.equippedStats.text:find("5",1,true) and p.equippedScore.text:find(string.format("%.1f",score),1,true))
assert(row.delta and math.abs(row.delta-(row.score-score))<.0001 and p.comparison.text:find("+",1,true))
local sent=ChatSent; ChatActive=false; ChatDraft=""
p.equippedChat.scripts.OnClick()
assert(ChatDraft=="item:991190" and ChatSent==sent and not next(XC.db.pins))
ItemInfo[991190].stats.ITEM_MOD_STRENGTH_SHORT=120; XC:Refresh()
assert(#p.entries==0 and not p.selectedRow and p.empty:IsShown())
assert(p.equippedItem.id==991190 and p.equippedChat.enabled and p.equippedChat:IsShown())
assert(not p.track.enabled and not p.map.enabled, "an equipped-only slot cannot track a nonexistent candidate")
ChatDraft=""; ChatActive=false; p.equippedChat.scripts.OnClick()
assert(ChatDraft=="item:991190" and ChatSent==sent)
FakeInventory[1]=991192; XC:Refresh()
assert(not p.equippedItem and not p.equippedChat.enabled and p.equippedName.text:lower():find("loading",1,true))
assert(not p.selectedRow.delta and not p.comparison.text:match("^%+"))
JournalUICatalog[991105]={id=991105,name="Journal Two Hander",quality=3,inv=17,classID=2,subclassID=1,req=1,stats={str=10,dps=9},sources={{kind="vendor",name="Weapon Vendor",side=1}}}
ItemInfo[991105]={name="Journal Two Hander",quality=3,ilvl=20,req=1,equip="INVTYPE_2HWEAPON",classID=2,subclassID=1,stats={ITEM_MOD_STRENGTH_SHORT=10,ITEM_MOD_DAMAGE_PER_SECOND_SHORT=9}}
ItemInfo[991191]={name="Equipped One Hander",quality=2,ilvl=15,req=1,equip="INVTYPE_WEAPONMAINHAND",classID=2,subclassID=7,stats={ITEM_MOD_STRENGTH_SHORT=2,ITEM_MOD_DAMAGE_PER_SECOND_SHORT=3}}
FakeInventory={ [16]=991191 }; XC:SetJournalSlot(16); XC:Refresh()
assert(p.selectedRow.item.id==991105 and p.equippedItem.id==991191 and not p.selectedRow.delta)
assert(not p.comparison.text:match("^%+"), "different hand setups must not claim a direct upgrade")
FakeInventory={ [3]=991193 }; XC:SetJournalSlot(3); XC:Refresh()
assert(#p.entries==0 and not p.selectedRow and not p.equippedItem)
assert(p.equippedName.text:lower():find("loading",1,true) and not p.equippedChat.enabled)
assert(not p.track.enabled and not p.map.enabled)
FakeInventory={}; JournalUICatalog[991105]=nil
for _,id in ipairs({991105,991190,991191,991192,991193}) do ItemInfo[id]=nil end
XC:SetJournalSlot(0); XC:Refresh()
assert(#p.entries==3)
''')
test('journal item actions cycle sources map directly and draft unsent chat', '''
local p=XC.window.journal
p.rows[2].scripts.OnClick(p.rows[2],"LeftButton")
assert(p.selectedRow.item.id==991101 and p.selectedRow.sourceCount==2)
assert(XC:SetJournalSource(p.selectedRow,1)); XC:RenderJournal()
assert(p.selectedRow.source.kind=="vendor")
local key=p.selectedRow.key; p.sourceChoice.scripts.OnClick()
assert(p.selectedRow.key==key and p.selectedRow.source.kind=="dungeon")
p.sourceChoice.scripts.OnClick(); assert(p.selectedRow.source.kind=="vendor")
LastWaypoint=nil; MapOpened=nil; p.map.scripts.OnClick()
assert(LastWaypoint and LastWaypoint.id==1436 and LastWaypoint.x==.12 and MapOpened==1436)
assert(not next(XC.db.pins), "show on map must not silently create a hunt")
ChatActive=false; ChatDraft=""; local sent=ChatSent
p.chat.scripts.OnClick(); assert(ChatDraft=="item:991101" and ChatSent==sent)
ChatDraft="existing "; ChatActive=true; p.rewardButton.scripts.OnClick(p.rewardButton,"RightButton")
assert(ChatDraft=="existing item:991101" and ChatSent==sent)
MockControl=true; p.rewardButton.scripts.OnClick(p.rewardButton,"LeftButton"); MockControl=false
assert(PreviewedLink=="item:991101" and not next(XC.db.pins))
''')
test('journal track and reward click share a persistent hunt and ownership moves it to completed', '''
local p=XC.window.journal; p.track.scripts.OnClick()
local pin=XC.db.pins["991101"]; assert(pin and XC.db.activeHunt=="991101" and XC.guide:IsShown())
pin.notes="journal notes"; pin.checks[1]=true
XC:ShowPage("gear"); p.rewardButton.scripts.OnClick(p.rewardButton,"LeftButton")
assert(XC.db.pins["991101"]==pin and pin.notes=="journal notes" and pin.checks[1])
XC:ShowPage("gear"); p.tabs.completed.scripts.OnClick()
assert(#p.entries==0 and p.empty:IsShown(), "tracking alone is not completion")
Owned[991101]=1; FireEvent("BAG_UPDATE_DELAYED"); FlushTimers()
assert(pin.acquired)
p.tabs.completed.scripts.OnClick(); assert(#p.entries==1 and p.selectedRow.item.id==991101)
assert(p.rewardMeta.text=="Obtained" and p.track.enabled)
Owned[991101]=nil; XC:Refresh(); assert(#p.entries==1, "observed completion survives a sale")
''')
test('journal remove and restore retain hunt notes across saved-state initialization', '''
local p=XC.window.journal; local pin=XC.db.pins["991101"]
p.remove.scripts.OnClick(); assert(XC.db.journal.removed["991101"] and #p.entries==0)
p.tabs.removed.scripts.OnClick()
assert(#p.entries==1 and p.remove.label.text=="Restore" and not XC.db.activeHunt)
FireEvent("ADDON_LOADED","UpgradeCrossroads"); XC:Refresh()
assert(#p.entries==1 and p.selectedRow.obtained)
p.remove.scripts.OnClick(); assert(not XC.db.journal.removed["991101"] and #p.entries==0)
p.tabs.completed.scripts.OnClick(); assert(#p.entries==1)
assert(XC.db.pins["991101"]==pin and pin.notes=="journal notes" and pin.checks[1])
''')
test('journal search filters alternate sources and collapsing does not change selection', '''
local p=XC.window.journal; p.tabs.active.scripts.OnClick()
-- Restore the crown to active only for this independent UI scenario.
XC.db.journal.obtained["991101"]=nil; XC.db.pins["991101"].acquired=nil; XC:Refresh()
p.search.edit:SetText("journal boss"); p.search.edit.scripts.OnTextChanged(p.search.edit,true)
assert(#p.entries==1 and p.selectedRow.item.id==991101)
p.clear.scripts.OnClick(); assert(#p.entries==3 and p.query=="")
local selected=XC.db.journalUI.selected
p.rows[1].scripts.OnClick(); assert(XC.db.journalUI.collapsed[1] and XC.db.journalUI.selected==selected)
assert(p.rows[2].label.text:find("Neck",1,true))
p.expand.scripts.OnClick(); assert(not next(XC.db.journalUI.collapsed))
local limit=XC.db.journalUI.limit; p.limit.scripts.OnClick(); assert(XC.db.journalUI.limit~=limit)
p.filterButton.scripts.OnClick(); assert(p.filters:IsShown())
p.solo:SetChecked(true); p.solo.scripts.OnClick(p.solo)
for _,row in ipairs(p.entries) do for _,source in ipairs(row.sources) do assert(source.kind~="dungeon") end end
p.craft:SetChecked(false); p.craft.scripts.OnClick(p.craft)
for _,row in ipairs(p.entries) do assert(row.source.kind~="craft") end
p.faction.scripts.OnClick(); assert(XC.db.options.faction=="horde")
p.faction.scripts.OnClick(); assert(XC.db.options.faction=="both")
p.faction.scripts.OnClick(); assert(XC.db.options.faction=="alliance")
for i=1,3 do p.lane.scripts.OnClick() end
assert(XC.db.journalUI.lane=="longterm")
p.search.edit:SetText("Future Journal"); p.search.edit.scripts.OnTextChanged(p.search.edit,true)
assert(#p.entries==1 and p.selectedRow.item.id==991104 and p.selectedRow.locked)
assert(p.rewardMeta.text=="Requires level 40")
p.clear.scripts.OnClick(); p.lane.scripts.OnClick()
assert(XC.db.journalUI.lane=="all")
for _,row in ipairs(p.entries) do assert(row.item.id~=991104) end
''')
test('journal weights tooltip and comparison identify custom per-spec estimates', '''
local p=XC.window.journal; local profile=XC.db.profile; local prior=XC.db.weights[profile]
XC.db.weights[profile]=nil; XC:Refresh()
assert(p.basis.text:find("Starter role weights",1,true))
SlashCmdList.UPGRADECROSSROADS("weights str=3")
assert(p.basis.text:find("Custom stat weights",1,true))
p.profile.scripts.OnEnter(p.profile)
assert(GameTooltip.text:find("str=3",1,true) and GameTooltip.text:find("Custom stat weights",1,true))
p.profile.scripts.OnLeave(p.profile); assert(not GameTooltip:IsShown())
p.profile.scripts.OnClick(); assert(XC.db.profile~=profile)
assert(XC:GetProfile(XC.db.profile).weights.str~=3)
XC:SetProfile(profile); assert(XC:GetProfile(profile).weights.str==3 and p.basis.text:find("Custom stat weights",1,true))
XC.db.weights[profile]=prior; XC:Refresh()
''')
test('journal theme carries to Hunts Help and Add Item while Settings stays plain', '''
local root=XC.window; local p=root.journal
XC:ShowHunts(); XC:ShowAbout(); XC:ShowTargetEditor(); XC:ShowAppearance()
for _,page in ipairs({XC.huntWindow,XC.about,XC.editor}) do
 local skin=page.themeSkin; assert(skin and skin.panorama and skin.wash and skin.border)
 assert(skin.panorama:GetParent()==page and skin.wash:GetParent()==page)
 local count=0
 for _,region in ipairs(Frames) do
  if region.texture and tostring(region.texture):find("JournalPanorama",1,true) then
   local parent=region:GetParent()
   while parent and parent~=page do parent=parent:GetParent() end
   if parent==page then count=count+1 end
  end
 end
 assert(count==1, "each content page shares a single scene behind its controls")
end
assert(not XC.appearanceWindow.themeSkin and not root.nav.compare)
local row=XC.huntWindow.rows[1]; assert(row and row.name.color[1]<.5 and row.source.color[1]<.5)
assert(XC.about.helpSections[1].text.color[1]<.5 and XC.editor.title.color[1]<.5)
local opacity=XC:Appearance().opacity; XC:Appearance().opacity=0; XC:ApplyAppearance()
assert(row.noteInput.bg[4]>=.92 and XC.editor.item.bg[4]>=.92)
assert(XC.appearanceWindow.colorFields.accent.input.bg[4]==0, "Settings keeps its normal appearance controls")
XC:Appearance().opacity=opacity; XC:ApplyAppearance()
XC:ShowPage("gear")
''')
test('journal parchment scroll and fixed actions stay separate at minimum size and largest text', '''
local p=XC.window.journal; XC.window:SetSize(900,720)
XC:Appearance().textBoost=2; XC:ApplyAppearance(); XC.W.SetWindowScale(XC.window,.8)
local previous=UIParent:GetScale(); UIParent:SetScale(.64); XC.W.SetWindowScale(XC.window,.8)
p:ApplyLayout()
local root=XC.window
assert(not root.description:IsShown(), "journal uses its own introduction")
local navTop=-root.nav.gear.point[3]
assert(navTop>=-root.title.point[3]+root.title:GetStringHeight()+4, "navigation must clear the shell title")
local profileBottom=-p.profile.point[3]+p.profile.height
local introTop=-p.intro.point[3]; local introBottom=introTop+p.intro:GetStringHeight()
assert(introTop>=profileBottom+8 and introTop>=-p.heading.point[3]+p.heading:GetStringHeight()+4)
assert(p.intro.point[2]>=p.slotButton.point[2]+p.slotButton.width+8)
assert(-p.slotButton.point[3]>=profileBottom+8)
assert(-p.left.point[3]>=introBottom+8 and -p.paper.point[3]>=introBottom+8)
assert(-p.left.point[3]>=-p.slotButton.point[3]+p.slotButton.height+8)
if p.filters:IsShown() then
 assert(-p.filters.point[3]>=introBottom+8)
 assert(-p.left.point[3]>=-p.filters.point[3]+p.filters.height+8)
end
assert(p.left:GetWidth()>=350 and p.paper:GetWidth()>400 and not p.left.allPoints and not p.paper.allPoints)
assert(p.left.point[2]+p.left.width<p.paper.point[2])
local tabRight=0
for _,id in ipairs({"active","completed","removed"}) do
 local b=p.tabs[id]
 assert(b.label:GetStringWidth()+16<=b.width+.01, id.." tab label must fit")
 assert(b.point[2]>=tabRight and b.point[2]+b.width<=p.left.width-4)
 tabRight=b.point[2]+b.width
 assert(-p.search.point[3]>=-b.point[3]+b.height+8)
end
assert(p.clear.point[2]>=p.search.point[2]+p.search.width+8)
assert(p.clear.point[2]+p.clear.width<=p.left.width-8)
assert(p.clear.label:GetStringWidth()+20<=p.clear.width+.01)
assert(-p.scroll.points.TOPLEFT[3]>=-p.search.point[3]+p.search.height+10)
local boxes={}; local scrollBottom=p.detailScroll.points.BOTTOMRIGHT[3]
for _,b in ipairs({p.track,p.map,p.remove,p.chat}) do
 assert(b.point[2]>=10 and b.point[2]+b.width<=p.paper.width-8)
 assert(b.label:GetStringWidth()+20<=b.width+.01)
 assert(b:GetParent()==p.paper and -b.point[3]>p.paper.height-scrollBottom)
 local current={x=b.point[2],y=-b.point[3],w=b.width,h=b.height}
 for _,other in ipairs(boxes) do
  assert(current.x+current.w<=other.x or other.x+other.w<=current.x
   or current.y+current.h<=other.y or other.y+other.h<=current.y)
 end
 boxes[#boxes+1]=current
end
assert(p.sourceChoice.label:GetStringWidth()+20<=p.sourceChoice.width+.01)
for _,b in ipairs({p.limit,p.expand}) do
 assert(b.point[2]>=8 and b.point[2]+b.width<=p.left.width-8)
 assert(b.label:GetStringWidth()+20<=b.width+.01)
end
p.detailScroll:SetVerticalScroll(170); p.scroll:SetVerticalScroll(90)
assert(p.detailScroll:GetVerticalScroll()==170 and p.scroll:GetVerticalScroll()==90)
for _,record in ipairs(XC.W.fonts) do
 if record.paper then
  assert(record.object.color[1]<.5 and record.object.color[2]<.5 and record.object.shadowOffset[1]==0 and record.object.fontFlags=="")
 end
end
for _,id in ipairs({"hunts","appearance","help","editor"}) do
 XC:ShowPage(id)
 assert(root.description:IsShown())
 local descriptionBottom=-root.description.point[3]+root.description:GetStringHeight()
 local navBottom=0
 for _,b in pairs(root.nav) do navBottom=math.max(navBottom,-b.point[3]+b.height) end
 assert(-root.description.point[3]>=navBottom+8)
 assert(-root.pageHost.point[3]>=descriptionBottom+8)
 if id~="appearance" then
  local page=root.pages[id]; local skin=page.themeSkin
  assert(skin and skin.panorama.width==page.width-12 and skin.panorama.height==page.height-12)
 end
end
XC:ShowHunts()
local hunt=XC.huntWindow.rows[1]
assert(-hunt.noteInput.point[3]>=-hunt.notesLabel.point[3]+hunt.notesLabel:GetStringHeight()+6)
assert(hunt.noteInput.height>=hunt.noteInput.edit.fontSize+8)
local actionBottom=0
for _,button in ipairs({hunt.remove,hunt.map,hunt.chat}) do
 assert(button.point[2]>=hunt.name.point[2]+hunt.name.width+8)
 assert(button.point[2]+button.width<=hunt.width-8)
 assert(-button.point[3]>=actionBottom+6 and -button.point[3]+button.height<=hunt.height-8)
 actionBottom=-button.point[3]+button.height
end
XC:ShowAbout()
for _,section in ipairs(XC.about.helpSections) do
 assert(-section.text.point[3]>=-section.heading.point[3]+section.heading:GetStringHeight()+6)
end
XC:ShowTargetEditor()
local editor=XC.editor
for key,label in pairs(editor.formLabels) do
 local field=key=="kind" and editor.kindButton or editor[key]
 assert(-field.point[3]>=-label.point[3]+label:GetStringHeight()+6)
 if field.edit then assert(field.height>=field.edit.fontSize+8) end
end
assert(-editor.save.point[3]>=-editor.status.point[3]+editor.status:GetStringHeight()+8)
XC:ShowPage("gear")
UIParent:SetScale(previous); XC:Appearance().textBoost=0; XC:ApplyAppearance(); XC.window:ResetGeometry()
''')
test('journal UI scenarios restore the original character and catalog', '''
local saved=JournalUITest
XC.db=saved.db; UpgradeCrossroadsDB=saved.savedVars; XC.Client.Catalog=saved.catalog
MockClass=saved.class; MockClassID=saved.classID; MockLevel=saved.level
Owned=saved.owned; FakeInventory=saved.inventory; Completed=saved.completed
XC.sourceSelection=saved.sourceSelection; XC.journalSourceSelection=saved.journalSourceSelection
for id in pairs(JournalUICatalog) do ItemInfo[id]=nil end
XC:ShowPage("gear"); XC:Refresh(); assert(XC.window.journal:IsShown())
JournalUITest=nil; JournalUICatalog=nil
''')

# Texture packaging checks do not depend on the client double.
import struct
for filename,size in [("IconRound.tga",64),("LogoRound.tga",256)]:
    blob=(ROOT/"UpgradeCrossroads/Media"/filename).read_bytes()
    assert blob[2]==2 and blob[16]==32, "Logo must be uncompressed RGBA TGA"
    assert struct.unpack_from("<HH",blob,12)==(size,size)
    from PIL import Image
    texture=Image.open(ROOT/"UpgradeCrossroads/Media"/filename).convert("RGBA")
    for corner in [(0,0),(size-1,0),(0,size-1),(size-1,size-1)]: assert texture.getpixel(corner)[3]==0
    assert texture.getpixel((size//2,size//2))[3]>240

# Export fixtures from the ACTUAL Lua UI, including each window at its minimum.
exported=[]
def convert(x):
    if hasattr(x,'items'):
        if x.exportID: return {'ref':x.exportID}
        return {str(k):convert(v) for k,v in x.items() if (not callable(v) or hasattr(v,'items')) and k not in ('parent','scripts','scrollChild','allPoints','ScrollBar','pin')}
    return x

def export_layout(name):
    lua.execute('for i,f in ipairs(Frames) do f.exportID=i end; for _,f in ipairs(Frames) do f.parentID=f.parent and f.parent.exportID or nil; f.visible=f:IsShown() end')
    out=[]
    for f in lua.globals().Frames.values():
        props={k:convert(f[k]) for k in ('exportID','parentID','kind','name','width','height','point','points','bg','border','text','color','texture','fontSize','fontPath','fontFlags','scale','backdrop','value','minValue','maxValue','justify','visible','checked','template','normalTexture','level','alpha','vertexColor','atlas','drawLayer','blendMode','styleRole') if f[k] is not None}
        if f.allPoints: props['fillParent']=True
        out.append(props)
    (ROOT/'research'/name).write_text(json.dumps(out))
    exported.append(name)

lua.execute('XC.db.activeHunt=nil; XC.db.custom={}; XC.db.pins={}; XC.db.slot=16; XC.db.profile="melee"; XC.db.path="reliable"; XC.db.options.solo=false; XC.db.options.crafted=true; XC:ShowPage("gear"); XC:Refresh()')
export_layout('layout.json')
lua.execute('XC.window:SetSize(900,720)')
export_layout('layout-planner-min.json')
lua.execute('XC.window:ResetGeometry(); local item=XC.Catalog[872]; XC:TrackItem({item=item,source=item.sources[1]},"dungeon",false); XC.guide:ClearAllPoints(); XC.guide:SetPoint("CENTER",UIParent,"CENTER",0,0)')
export_layout('layout-guide.json')
lua.execute('XC.guide:SetSize(330,330)')
export_layout('layout-guide-min.json')
lua.execute('XC:ShowHunts(); XC.window:SetSize(900,720)')
export_layout('layout-hunts-min.json')
lua.execute('XC:ShowTargetEditor()')
export_layout('layout-editor-min.json')
lua.execute('XC:ShowAbout()')
export_layout('layout-help-min.json')
lua.execute('XC:ShowAppearance()')
export_layout('layout-appearance-min.json')
lua.execute('XC.W.SetWindowScale(XC.window,.8); XC:ShowPage("gear"); XC:Refresh()')
export_layout('layout-readable-small.json')
lua.execute('XC:Appearance().textBoost=2; XC:ApplyAppearance()')
export_layout('layout-readable-largest.json')
lua.execute('XC:Appearance().textBoost=0; XC:ApplyAppearance(); XC.window:ResetGeometry(); XC:ShowAppearance()')
export_layout('layout-appearance.json')
lua.execute('XC:Appearance().textBoost=2; XC:ApplyAppearance(); local item=XC.Catalog[872]; XC:TrackItem({item=item,source=item.sources[1]},"dungeon",false); XC.guide:SetSize(330,330); XC.W.SetWindowScale(XC.guide,.8)')
export_layout('layout-guide-readable.json')
lua.execute('XC:ShowPage("gear"); XC.window:SetSize(900,720); XC:Appearance().textBoost=2; XC:ApplyAppearance(); MockClass="HUNTER"; MockClassID=3; XC.db.profile="hunter_survivalranged"; XC:Refresh()')
export_layout('layout-hunter-spec-min.json')
lua.execute('MockClass="WARLOCK"; MockClassID=9; XC.db.profile="warlock_destruction"; XC:Refresh()')
export_layout('layout-warlock-spec-min.json')

lua.execute('XC:Appearance().textBoost=0; XC:ApplyAppearance(); XC.window:ResetGeometry(); MockClass="MAGE"; MockClassID=8; MockLevel=21; XC.db.profile="mage_frost"; XC.db.options.solo=false; XC.db.options.crafted=true; XC.db.options.faction="alliance"; XC.db.journalUI={state="active",lane="all",limit=3,collapsed={}}; XC.window.journal.query=""; XC:ShowPage("gear"); XC:Refresh()')
export_layout('layout-journal.json')
lua.execute('XC.window:SetSize(900,720); UIParent:SetScale(.64); XC:Appearance().textBoost=2; XC:ApplyAppearance(); XC.W.SetWindowScale(XC.window,.8); MockClass="HUNTER"; MockClassID=3; XC.db.profile="hunter_survivalranged"; XC:Refresh(); XC.window.journal:ApplyLayout()')
export_layout('layout-journal-min-large.json')
lua.execute('UIParent:SetScale(1); XC:Appearance().textBoost=0; XC:ApplyAppearance(); XC.window:ResetGeometry(); MockClass="MAGE"; MockClassID=8; XC.db.profile="mage_frost"; XC.db.journalUI.filters=true; XC.window.journal.query="Deadmines"; XC:Refresh(); XC.window.journal:ApplyLayout()')
export_layout('layout-journal-filtered.json')
lua.execute('XC.window.journal.query=""; XC.db.journalUI.filters=false; XC.db.journalUI.state="active"; XC:Refresh(); local row=XC.window.journal.selectedRow; if row then XC:RemoveJournalEntry(row) end; XC.db.journalUI.state="removed"; XC:RenderJournal(); XC.window.journal:ApplyLayout()')
export_layout('layout-journal-removed.json')
lua.execute('XC.db.journal.removed={}; XC.db.journalUI.state="active"; XC:Refresh(); XC.window.journal:ApplyLayout()')
lua.execute('local pin=XC.db.pins["872"]; pin.notes="Confirm access, bring your group and keep the entrance pinned."; pin.checks[1]=true; XC:ShowHunts()')
export_layout('layout-themed-hunts.json')
lua.execute('XC:ShowAbout()')
export_layout('layout-themed-help.json')
lua.execute('local pin=XC.db.pins["872"]; XC:ShowTargetEditor({item=pin.item,source=pin.source},pin.lane)')
export_layout('layout-themed-editor.json')
lua.execute('XC:ShowPage("gear")')
(ROOT/'research/test-results.json').write_text(json.dumps(dict(runtime='Lua 5.1 via lupa',passed=cases),indent=2))
print(f'\n{len(cases)} test groups passed; {len(exported)} layout fixtures exported.')
