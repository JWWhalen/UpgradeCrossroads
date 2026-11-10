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
assert(XC.db.profile=="melee" and XC.db.slot==16)
assert(type(SlashCmdList.UPGRADECROSSROADS)=="function")
assert(XC.CatalogMeta.count==3529)
''')
test('complete native UI opens with catalog recommendations', '''
SlashCmdList.UPGRADECROSSROADS("")
assert(XC.window:IsShown())
assert(#XC.lanes.reliable>0 and #XC.lanes.dungeon>0 and #XC.lanes.longterm>0)
assert(XC.window.lanes.reliable.name.text~="")
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
local w=XC:GetProfile("ranged").weights
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
  for _,profile in ipairs(XC.Profiles) do
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
  assert(record.object.fontFlags=="" and record.object.shadowOffset[1]==1)
 end
end
UIParent:SetScale(old); XC:ApplyAppearance()
""")
test('appearance can change fonts sizes outlines and restore without clearing hunts', """
local f=XC.appearanceWindow; local pins=XC.db.pins
f.font.scripts.OnClick(); assert(XC.db.appearance.font=="classic"); f.font.scripts.OnClick()
f.textSize.scripts.OnClick(); assert(XC.db.appearance.textBoost==1)
f.outline:SetChecked(false); f.outline.scripts.OnClick(f.outline)
assert(XC.window.profile.label.fontPath:find("ARIALN") and XC.window.profile.label.fontFlags=="")
f.reset.scripts.OnClick(); assert(XC:Appearance().theme=="classic" and not XC:Appearance().outline and XC.db.pins==pins)
f:Hide()
""")
test('path tabs and item list inspect sources before one-click tracking', """
XC:ShowPage("gear"); XC.db.slot=16; XC.search=""; XC:Refresh(); XC:SelectPath("dungeon")
assert(XC.window.lanes.dungeon:IsShown() and not XC.window.lanes.reliable:IsShown())
local c=XC.window.lanes.dungeon; local before=XC.db.activeHunt
assert(c.items[2]:IsShown()); c.items[2].scripts.OnClick(c.items[2],"LeftButton")
assert(XC.selection.dungeon==2 and XC.db.activeHunt==before)
assert(c.name.text==XC:DisplayRow("dungeon").item.name)
c.itemButton.scripts.OnClick(c.itemButton,"LeftButton"); assert(XC.db.activeHunt and XC.guide:IsShown())
XC:ShowPage("gear"); XC.window.tabs.reliable.scripts.OnClick(); assert(XC.window.lanes.reliable:IsShown())
""")
test('native framing and approved logo paths are used consistently', """
assert(XC.window.backdrop.bgFile:find("WHITE8X8",1,true) and XC.window.bg[4]==1)
assert(XC.window.profile.template:find("UIPanelButtonTemplate",1,true))
assert(XC.minimapButton.icon.texture:match("UpgradeCrossroads.+Media.+IconRound$"))
assert(XC.window.headerIcon.texture:match("UpgradeCrossroads.+Media.+LogoRound$"))
""")
test('page navigation is exclusive and never creates floating settings windows', """
XC:ShowTargetEditor(); XC:ShowAppearance(); local root=XC.window
for _,id in ipairs({"gear","hunts","appearance","help","editor"}) do XC:ShowPage(id) end
local count=#Frames
for pass=1,4 do
 for _,id in ipairs({"gear","hunts","appearance","help","editor"}) do
  XC:ShowPage(id); local shown=0
  for key,page in pairs(root.pages) do
   assert(page:GetParent()==root.pageHost and not page.resizable and not page.closeButton)
   if page:IsShown() then shown=shown+1; assert(key==id) end
  end
  assert(shown==1 and root.activePage==id)
 end
end
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
assert(db.schema==5 and db.pins==pins)
assert(db.appearance.background=="112233" and db.appearance.opacity==.65)
assert(db.appearance.font=="plain" and not db.appearance.outline)
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
def convert(x):
    if hasattr(x,'items'):
        if x.exportID: return {'ref':x.exportID}
        return {str(k):convert(v) for k,v in x.items() if (not callable(v) or hasattr(v,'items')) and k not in ('parent','scripts','scrollChild','allPoints','ScrollBar','pin')}
    return x

def export_layout(name):
    lua.execute('for i,f in ipairs(Frames) do f.exportID=i end; for _,f in ipairs(Frames) do f.parentID=f.parent and f.parent.exportID or nil; f.visible=f:IsShown() end')
    out=[]
    for f in lua.globals().Frames.values():
        props={k:convert(f[k]) for k in ('exportID','parentID','kind','name','width','height','point','points','bg','border','text','color','texture','fontSize','fontPath','fontFlags','scale','backdrop','value','minValue','maxValue','justify','visible','checked','template','normalTexture','level') if f[k] is not None}
        if f.allPoints: props['fillParent']=True
        out.append(props)
    (ROOT/'research'/name).write_text(json.dumps(out))

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
(ROOT/'research/test-results.json').write_text(json.dumps(dict(runtime='Lua 5.1 via lupa',passed=cases),indent=2))
print(f'\n{len(cases)} test groups passed; twelve layout fixtures exported.')
