"""Rebuild the bundled, attributed catalog from the pinned upstream snapshot.

Requires lupa. Download the five upstream research files listed in SOURCES.md
before running. Only source-linked items are admitted; no invented acquisition data.
"""
from pathlib import Path
from collections import Counter
import json
import re
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lock_path=ROOT/'research/source-lock.json'
if lock_path.exists():
    import hashlib
    lock=json.loads(lock_path.read_text())
    for name,entry in lock['files'].items():
        actual=hashlib.sha256((ROOT/'research'/name).read_bytes()).hexdigest()
        assert actual==entry['sha256'], f'Input changed outside reviewed source refresh: {name}'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('rows={}; overrides={}; data={}; sourceMeta={}; Polestar={ItemDB={Register=function(meta, t) for id,v in pairs(t) do rows[id]=v; if not meta then overrides[id]=true end end end, RegisterLeveling=function(meta,t) data=t; sourceMeta=meta end}}')
for name in ("Items.lua", "Forever.lua"):
    # Upstream files are generated data; remove all system/file access during evaluation.
    run = lua.eval('function(code) local f=assert(loadstring(code)); setfenv(f,{Polestar=Polestar,pairs=pairs}); f() end')
    run((ROOT / 'research' / name).read_text())
g = lua.globals()
d = g.data
snapshot=str(g.sourceMeta.generated)
assert re.fullmatch(r'\d{4}-\d{2}-\d{2}',snapshot), 'Missing upstream data snapshot date'
assert str(g.sourceMeta.licence)=='MIT', 'Source declares a different license; review before rebuilding'

def serialize(value):
    if value is None: return 'nil'
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, str):
        return '"' + value.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\r','\\r') + '"'
    if isinstance(value, list): return '{'+','.join(serialize(x) for x in value)+'}'
    return '{'+','.join('['+serialize(k)+']='+serialize(v) for k,v in value.items())+'}'

quests = {}
for qid, row in d.quests.items():
    fields = row.split('|')
    h = list(map(int, fields[0].split()))
    quests[qid] = dict(level=h[0], minLevel=h[1], side=h[2], zoneID=h[3], raceMask=h[4], classMask=h[5], group=h[6] != 0, name=fields[3])

def equipment(item_id, name, raw, basis):
    tokens = raw.split()
    inv, ilvl, req, quality, cls, sub = map(int, tokens[:6])
    # Wearable equipment only. Bags, shirts, tabards, ammo and non-equipment are excluded.
    if inv not in {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,20,21,22,23,25,26,28}:
        return None
    stats = {}
    restrictions = {}
    for token in tokens[6:]:
        match = re.fullmatch(r'([a-z]+)(-?[\d.]+)', token)
        if match:
            key, number = match.groups()
            value = float(number)
            if value.is_integer(): value = int(value)
            if key in {'cls','uniq'}: restrictions[key] = value
            else:
                # Upstream uses "defense" for the flat Defense shown on gear.
                # The existing tank model and saved weights use "def".
                key = 'def' if key == 'defense' else key
                assert key not in stats or stats[key] == value, f'Conflicting {key} stat for item {item_id}'
                stats[key] = value
    if stats.get('speed',0)>0:
        stats['dps'] = (stats.get('dmin',0)+stats.get('dmax',0))/2/(stats['speed']/1000)
    return dict(id=item_id,name=name,inv=inv,ilvl=ilvl,req=req,quality=quality,classID=cls,subclassID=sub,stats=stats,classMask=restrictions.get('cls',0),unique=restrictions.get('uniq',0)==1,basis=basis,sources=[])

catalog = {}
missing = []
for itemID, source in sorted(d.src.items()):
    raw = g.rows[itemID]
    if not raw:
        missing.append(itemID)
        continue
    item = equipment(itemID, d.names[itemID] or ('Item #'+str(itemID)), raw, 'forever' if g.overrides[itemID] else 'classic')
    if not item:
        continue
    sources=item['sources']
    for token in source.split():
        if token.startswith('q'):
            qid=int(token[1:]); q=quests.get(qid)
            if not q: continue
            sources.append(dict(kind='quest',questID=qid,name=q['name'],zone=d.zones[q['zoneID']] or 'Unknown zone',zoneID=q['zoneID'],minLevel=q['minLevel'],side=q['side'],raceMask=q['raceMask'],classMask=q['classMask'],group=q['group']))
        elif token.startswith('d'):
            m=re.fullmatch(r'd(\d+)x(\d+)z(\d+)',token)
            if not m: continue
            npc,pct,zone=map(int,m.groups())
            raids={1977,2677,3428,3429,3456,2717,409}
            instances={209,491,717,718,719,721,722,796,1176,1216,1337,1417,1477,1581,1583,1584,2017,2057,2100,2437,2557,16544,16560,16611,16732,16919,17191,17803,17804}
            kind='raid' if zone in raids else ('dungeon' if zone in instances else 'world')
            sources.append(dict(kind=kind,npcID=npc,name=d.npcs[npc] or ('Creature #'+str(npc)),zone=d.zones[zone] or ('Area #'+str(zone)),zoneID=zone,reportedDrop=pct/10))
        elif token.startswith('c'):
            m=re.fullmatch(r'c(\d+)p(\d+)s(\d+)',token)
            if not m: continue
            spell,prof,skill=map(int,m.groups())
            sources.append(dict(kind='craft',spellID=spell,name=d.professions[prof] or 'Crafting',skill=skill,zone='Recipe access and materials must be checked'))
    if sources:
        catalog[itemID]=item

# Reviewed live quest reward observations extend the historical snapshot.
# The acquisition evidence and the equipment stat evidence are independent.
reviewed = json.loads((ROOT/'research'/'live_quest_rewards.json').read_text(encoding='utf-8'))
assert re.fullmatch(r'[a-f0-9]{40}', reviewed['commit'])
assert re.fullmatch(r'1\.60\.1\.\d+', reviewed['build'])
assert re.fullmatch(r'\d{4}-\d{2}-\d{2}', reviewed['observedThrough'])
reviewed_stats = reviewed['foreverStats']
reviewed_quests = set()
reviewed_items = set()
reviewed_links = 0
added_items = 0
added_links = 0
for quest in reviewed['quests']:
    quest_id = quest['questID']
    assert type(quest_id) is int and quest_id > 0 and quest_id not in reviewed_quests
    assert quest['name'].strip() and quest['zone'].strip() and quest['zoneID'] > 0
    assert type(quest['side']) is int and quest['side'] in (0, 1, 2)
    assert type(quest['minLevel']) is int and 1 <= quest['minLevel'] <= 60
    assert type(quest['group']) is bool
    if 'details' in quest:
        assert isinstance(quest['details'], str) and quest['details'].strip()
    assert quest['rewards'], f'No reviewed rewards for quest {quest_id}'
    reviewed_quests.add(quest_id)
    for item_key, name in quest['rewards'].items():
        item_id = int(item_key)
        assert item_id > 0 and str(item_id) == item_key and name.strip()
        reviewed_items.add(item_key)
        reviewed_links += 1
        stats = reviewed_stats.get(item_key)
        if stats:
            assert len(set(stats['evidence'])) >= 2 and all(url.startswith('https://') for url in stats['evidence'])
        item = catalog.get(item_id)
        if item is None:
            raw = stats['equipment'] if stats else g.rows[item_id]
            basis = 'forever' if stats or g.overrides[item_id] else 'classic'
            assert raw, f'Missing equipment stats for reviewed reward {item_id}'
            item = equipment(item_id, name, raw, basis)
            assert item and item['stats'], f'No supported equipment stats for reviewed reward {item_id}'
            catalog[item_id] = item
            added_items += 1
        elif stats:
            published = equipment(item_id, name, stats['equipment'], 'forever')
            assert {**item, 'sources': []} == published, f'Reviewed reward differs from existing stats for {item_id}'
        source = dict(
            kind='quest', questID=quest_id, name=quest['name'], zone=quest['zone'],
            zoneID=quest['zoneID'], minLevel=quest['minLevel'], side=quest['side'],
            raceMask=0, classMask=0, group=quest['group'], sourceBuild=reviewed['build'],
        )
        if 'details' in quest:
            source['details'] = quest['details']
        old_index = next((i for i, current in enumerate(item['sources']) if current.get('questID') == quest_id), None)
        if old_index is None:
            item['sources'].append(source)
            added_links += 1
        else:
            item['sources'][old_index] = source
assert set(reviewed_stats) <= reviewed_items, 'Published Forever stats must have a reviewed quest source'

meta = dict(count=len(catalog),date=snapshot,sourceVersion=str(g.sourceMeta.version),
            upstream=(ROOT/'research'/'ref.txt').read_text().strip(),
            liveQuestBuild=reviewed['build'],liveQuestDate=reviewed['observedThrough'],
            liveQuestCount=len(reviewed_quests),liveQuestRewardLinks=reviewed_links,
            liveQuestItemCount=len(reviewed_items),liveQuestStatCount=len(reviewed_stats),
            liveQuestAddedItems=added_items,liveQuestAddedLinks=added_links)

out=ROOT/'UpgradeCrossroads'/'Data'/'Catalog.lua'
out.write_text('-- Generated by tools/build_catalog.py. See SOURCES.md and THIRD_PARTY_NOTICES.txt.\nlocal _, XC = ...\nXC.Catalog = '+serialize(catalog)+'\nXC.CatalogMeta = '+serialize(meta)+'\n', encoding='utf-8')
(ROOT/'research'/'catalog.json').write_text(json.dumps(catalog))
print(json.dumps(dict(items=len(catalog),foreverOverrides=sum(x['basis']=='forever' for x in catalog.values()),sourceKinds=Counter(s['kind'] for i in catalog.values() for s in i['sources']),missingStats=len(missing))))

# Keep recipe acquisition guidance separate from the dated equipment snapshot.
recipe_input = ROOT / 'research/recipe_sources.json'
recipe_rows = json.loads(recipe_input.read_text(encoding='utf-8'))
craft_spells = {
    source['spellID']
    for item in catalog.values()
    for source in item['sources']
    if source['kind'] == 'craft'
}
recipe_sources = {}
for key, row in sorted(recipe_rows.items(), key=lambda pair: int(pair[0])):
    spell = int(key)
    assert spell > 0 and str(spell) == key, f'Invalid recipe spell ID: {key}'
    assert row['kind'] in {'trainer','vendor','drop','quest','reputation','specialization','other','unknown'}, f'Invalid recipe source type: {spell}'
    assert row['basis'] in {'Forever','Classic baseline'}, f'Invalid recipe provenance: {spell}'
    for field in ('text', 'evidence'):
        assert isinstance(row.get(field), str) and row[field].strip(), f'Missing recipe {field}: {spell}'
    for field in ('skill', 'recipeItemID'):
        if field in row:
            assert type(row[field]) is int and row[field] > 0, f'Invalid recipe {field}: {spell}'
    for point in row.get('locations', []):
        assert row['basis'] == 'Forever', f'Legacy location must not create a recipe map pin: {spell}'
        assert type(point['mapID']) is int and point['mapID'] > 0, f'Invalid recipe map: {spell}'
        assert type(point['side']) is int and point['side'] in (1, 2, 3), f'Invalid recipe faction: {spell}'
        assert all(type(point[axis]) in (int, float) and 0 < point[axis] < 100 for axis in ('x','y')), f'Invalid recipe coordinates: {spell}'
        assert isinstance(point['label'], str) and point['label'].strip(), f'Missing recipe map label: {spell}'
    if spell in craft_spells:
        recipe_sources[spell] = {field: value for field, value in row.items() if field != 'evidence'}

recipe_out = ROOT / 'UpgradeCrossroads/Data/RecipeSources.lua'
recipe_out.write_text(
    '-- Generated by tools/build_catalog.py from research/recipe_sources.json. See SOURCES.md.\n'
    'local _, XC = ...\nXC.RecipeSources = ' + serialize(recipe_sources) + '\n',
    encoding='utf-8',
)
recipe_orphans = sorted(set(map(int, recipe_rows)) - craft_spells)
print(json.dumps(dict(recipeGuidance=len(recipe_sources), recipeOrphans=recipe_orphans)))

# Outdoor approaches/entrances only, never fabricated interior boss coordinates.
entrance_input=ROOT/'research/navigation/entrances.json'
if entrance_input.exists():
    lookup={
        1581:'deadmines',718:'wailing-caverns',719:'blackfathom-deeps',209:'shadowfang-keep',717:'stormwind-stockade',
        721:'gnomeregan',491:'razorfen-kraul',722:'razorfen-downs',796:'scarlet-monastery',1337:'uldaman',
        1176:'zulfarrak',1477:'sunken-temple',1417:'sunken-temple',2100:'maraudon',2557:'dire-maul',
        1584:'blackrock-depths',17803:'blackrock-depths',1583:'blackrock-spire',17804:'blackrock-spire',
        2017:'stratholme',2057:'scholomance',2437:'ragefire-chasm',16544:'city-of-dalaran',16560:'city-of-dalaran',
        16611:'ruins-of-lordaeron',16732:'excavation-site-wetlands',16919:'the-hall-of-thanes',
        1977:'zulgurub',2677:'blackwing-lair',3428:'ahnqiraj-temple',3429:'ruins-of-ahnqiraj',3456:'naxxramas',409:'molten-core',
    }
    raw=json.loads(entrance_input.read_text())
    indexed={e['key']:e for e in raw['entrances']}
    locations={}
    for area,key in lookup.items():
        e=indexed.get(key)
        if not e: continue
        entry=dict(mapID=e['map'],x=e['x'],y=e['y'],label=key.replace('-',' ').title(),note=e['note'],evidence=e['source'],basis='Bundled entrance / reported')
        if e.get('A'): entry['alliance']=dict(mapID=e['A']['map'],x=e['A']['x'],y=e['A']['y'],note=e['A']['note'])
        locations[area]=entry
    (ROOT/'UpgradeCrossroads/Data/Locations.lua').write_text('-- Outdoor entrance facts adapted from Polestar, GPL-3.0. See SOURCES.md.\nlocal _, XC = ...\nXC.Entrances = '+serialize(locations)+'\n')
    print(json.dumps(dict(entranceMappings=len(locations),unmatchedKeys=sorted(set(lookup.values())-set(indexed)))))
