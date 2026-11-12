"""Report catalog age and bundled navigation coverage without claiming live coverage."""
from pathlib import Path
from datetime import date
import argparse, json
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--max-age',type=int,default=45); p.add_argument('--strict',action='store_true'); args=p.parse_args()
L=LuaRuntime(unpack_returned_tuples=True); ns=L.table()
load=L.eval('function(s,ns) local f=assert(loadstring(s)); setfenv(f,{}); f("UpgradeCrossroads",ns) end')
for filename in ['Catalog.lua','Locations.lua','RecipeSources.lua']: load((ROOT/'UpgradeCrossroads/Data'/filename).read_text(),ns)
snapshot=date.fromisoformat(ns.CatalogMeta.date); age=(date.today()-snapshot).days
items=list(ns.Catalog.items()); sources=[s for _,i in items for _,s in i.sources.items()]
craft_spells={s.spellID for s in sources if s.kind=='craft'}
recipe_sources=[ns.RecipeSources[spell] for spell in craft_spells if ns.RecipeSources[spell] is not None]
report={'snapshot':snapshot.isoformat(),'age_days':age,'age_threshold_days':args.max_age,'age_warning':age>args.max_age,'items':len(items),
 'forever_override_items':sum(i.basis=='forever' for _,i in items),'classic_baseline_items':sum(i.basis=='classic' for _,i in items),
 'source_links':len(sources),'dungeon_source_links':sum(s.kind=='dungeon' for s in sources),
 'dungeon_source_links_with_bundled_approach':sum(s.kind=='dungeon' and ns.Entrances[s.zoneID] is not None for s in sources),
 'craft_recipe_spells':len(craft_spells),
 'recipes_with_known_acquisition':sum(recipe.kind!='unknown' for recipe in recipe_sources),
 'recipes_with_classic_acquisition':sum(recipe.kind!='unknown' and recipe.basis=='Classic baseline' for recipe in recipe_sources),
 'recipes_with_bundled_map_location':sum(recipe.locations is not None and len(recipe.locations)>0 for recipe in recipe_sources),
 'note':'Approach coverage is not interior boss coverage. Optional installed QuestieDB and live quest guidance are not measured offline.'}
out=ROOT/'dist'; out.mkdir(exist_ok=True); (out/'catalog-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if args.strict and report['age_warning']: raise SystemExit('Catalog snapshot exceeds the chosen age threshold; review the source before a data release.')
