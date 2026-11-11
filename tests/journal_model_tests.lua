-- Run with the addon loaded and initialized. These checks exercise the real
-- journal against a small catalog; no UI or live client result is fabricated.
local saved={db=XC.db,context=XC.context,cache=XC.journalCache,
    selection=XC.journalSourceSelection,sourceSelection=XC.sourceSelection,
    catalog=XC.Client.Catalog,owned=XC.Client.Owned,release=XC.Navigation.ReleaseOwnedWaypoint,
    guide=XC.guide,guideMessage=XC.guideMessage,guideNavKey=XC.guideNavKey,
    mockClass=MockClass,mockClassID=MockClassID,mockLevel=MockLevel}
MockClass="WARRIOR"; MockClassID=1; MockLevel=21
local owned={}
local sources={
    quest={kind="quest",name="Journal Test Quest",questID=991001,side=1,minLevel=1},
    second={kind="vendor",name="Journal Test Vendor",side=1,minLevel=1},
    dungeon={kind="dungeon",name="Journal Test Dungeon",side=1,minLevel=1},
    horde={kind="vendor",name="Horde Journal Vendor",side=2,minLevel=1},
    craft={kind="craft",name="Journal Test Craft",minLevel=1},
}
local function item(id,inv,score,s,req)
    return {id=id,name="Journal Item "..id,inv=inv,classID=4,subclassID=1,req=req or 1,
        stats={str=score},sources=s,basis="forever"}
end
local catalog={
    [990001]=item(990001,1,10,{sources.quest,sources.second}),
    [990002]=item(990002,1,20,{sources.dungeon}),
    [990003]=item(990003,2,5,{sources.craft}),
    [990004]=item(990004,1,50,{sources.horde}),
    [990005]=item(990005,1,40,{{kind="vendor",name="Future Journal Vendor",minLevel=40}},40),
    [990006]=item(990006,11,7,{sources.second}),
}
XC.db={profile="warrior_arms",weights={},pins={},custom={},options={faction="alliance",solo=false,crafted=true,auction=false}}
XC.context={class="WARRIOR",classID=1,raceID=1,side=1,level=21,equipped={},occupied={},worn={},completed={}}
XC.Client.Catalog=function() return catalog end
XC.Client.Owned=function(id) return owned[id]==true end
XC.journalSourceSelection=nil; XC.sourceSelection=nil; XC:InvalidateJournal()
local function count(rows,id)
    local n=0; for _,row in ipairs(rows) do if not id or row.item.id==id then n=n+1 end end; return n
end
local function find(rows,id)
    for _,row in ipairs(rows) do if row.item.id==id then return row end end
end

local active=XC:GetJournalEntries("active",nil,nil,"all")
assert(#active==5 and active[1].item.id==990002 and active[1].slotID==1)
assert(active[1].rank==1 and active[2].rank==2 and active[3].slotID==2 and active[3].rank==1)
assert(count(active,990006)==2, "paired slots are represented independently")
assert(not find(active,990004) and not find(active,990005))
assert(find(XC:GetJournalEntries("active",nil,nil,"longterm"),990005).locked)
assert(#XC:GetJournalEntries("active","test vendor",1,"all")==1, "search includes alternate source names")
assert(#XC:GetJournalEntries("active","",2,"all")==1)

XC.db.options.solo=true; XC.db.options.crafted=false; XC:InvalidateJournal()
active=XC:GetJournalEntries("active")
assert(not find(active,990002) and not find(active,990003))
XC.db.options.solo=false; XC.db.options.crafted=true; XC:InvalidateJournal()
local row=find(XC:GetJournalEntries("active"),990001)
assert(row.sourceCount==2 and row.sourceIndex==1)
assert(XC:SetJournalSource(row,2))
row=find(XC:GetJournalEntries("active"),990001)
assert(row.source==sources.second and row.sourceIndex==2)
assert(not XC:SetJournalSource(row,0) and not XC:SetJournalSource(row,3))

local pin={item=catalog[990001],source=sources.quest,lane="reliable",checks={true,true,true},notes="keep these notes",order=1}
XC.db.pins["990001"]=pin; XC.db.activeHunt="990001"
local released=0; XC.Navigation.ReleaseOwnedWaypoint=function() released=released+1 end
XC.guide=nil
assert(XC:RemoveJournalEntry(row) and released==1 and not XC.db.activeHunt)
assert(XC.db.pins["990001"]==pin and pin.notes=="keep these notes" and pin.checks[3])
assert(not find(XC:GetJournalEntries("active"),990001))
assert(find(XC:GetJournalEntries("removed"),990001).removed)
assert(XC:RestoreJournalEntry(row))
assert(find(XC:GetJournalEntries("active"),990001) and not next(XC.db.journal.removed))
assert(XC.db.pins["990001"]==pin and pin.notes=="keep these notes")

-- A checklist or completed reward quest does not prove item ownership.
XC.context.completed[sources.quest.questID]=true; XC:InvalidateJournal()
assert(not find(XC:GetJournalEntries("completed"),990001))
assert(find(XC:GetJournalEntries("active"),990001).source==sources.second)
owned[990001]=true; XC:InvalidateJournal()
assert(not find(XC:GetJournalEntries("active"),990001))
local completed=find(XC:GetJournalEntries("completed"),990001)
assert(completed and completed.obtained and completed.sourceCount==2)
-- An observation survives a later sale or addon reload, like acquired pins.
owned[990001]=nil; XC:InvalidateJournal()
assert(find(XC:GetJournalEntries("completed"),990001))
assert(XC:RemoveJournalEntry(completed))
assert(not find(XC:GetJournalEntries("completed"),990001))
assert(find(XC:GetJournalEntries("removed"),990001).obtained)
assert(XC:RestoreJournalEntry(completed))
assert(find(XC:GetJournalEntries("completed"),990001) and not find(XC:GetJournalEntries("active"),990001))

-- An older obtained pin is imported into completion history even when the
-- client does not currently see that item in the player's bags.
pin.acquired=true; pin.acquiredAt=123
XC.db.journal.obtained={}; XC:InvalidateJournal()
assert(find(XC:GetJournalEntries("completed"),990001))
assert(XC.db.journal.obtained["990001"].observedAt==123)

-- A low printed item requirement never overrides the level 40 armor training
-- requirement, including when an owned item is viewed as completed history.
catalog[990007]=item(990007,5,30,{sources.second},15)
catalog[990007].subclassID=4
XC:InvalidateJournal()
assert(not find(XC:GetJournalEntries("active",nil,nil,"all"),990007))
local plate=find(XC:GetJournalEntries("active",nil,nil,"longterm"),990007)
assert(plate and plate.minLevel==40 and plate.locked)
owned[990007]=true; XC:InvalidateJournal()
plate=find(XC:GetJournalEntries("completed"),990007)
assert(plate and plate.minLevel==40 and plate.locked and plate.obtained)

MockClass="HUNTER"; MockClassID=3
XC.context.class="HUNTER"; XC.context.classID=3; XC.db.profile="hunter_beastmastery"
catalog[990008]=item(990008,1,30,{sources.second},15)
catalog[990008].subclassID=3
XC:InvalidateJournal()
assert(not find(XC:GetJournalEntries("active",nil,nil,"all"),990008))
local mail=find(XC:GetJournalEntries("active",nil,nil,"longterm"),990008)
assert(mail and mail.minLevel==40 and mail.locked)
owned[990008]=true; XC:InvalidateJournal()
mail=find(XC:GetJournalEntries("completed"),990008)
assert(mail and mail.minLevel==40 and mail.locked and mail.obtained)

-- Current browsing preserves the underlying rule's downgrade exclusion. A
-- pending/incomplete baseline instead remains explicitly incomparable.
MockClass="WARRIOR"; MockClassID=1
XC.context.class="WARRIOR"; XC.context.classID=1; XC.db.profile="warrior_arms"
XC.context.equipped[1]={id=999901,inv=1,classID=4,subclassID=1,stats={str=100}}
XC:InvalidateJournal()
assert(not find(XC:GetJournalEntries("active",nil,nil,"all"),990002))
XC.context.equipped[1].incomplete=true; XC:InvalidateJournal()
local incomparable=find(XC:GetJournalEntries("active",nil,nil,"all"),990002)
assert(incomparable and incomparable.delta==nil)

XC.db=saved.db; XC.context=saved.context; XC.journalCache=saved.cache
XC.journalSourceSelection=saved.selection; XC.sourceSelection=saved.sourceSelection
XC.Client.Catalog=saved.catalog; XC.Client.Owned=saved.owned
XC.Navigation.ReleaseOwnedWaypoint=saved.release; XC.guide=saved.guide
XC.guideMessage=saved.guideMessage; XC.guideNavKey=saved.guideNavKey
MockClass=saved.mockClass; MockClassID=saved.mockClassID; MockLevel=saved.mockLevel
return true
