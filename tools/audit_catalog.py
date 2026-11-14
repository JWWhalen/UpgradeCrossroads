"""Report catalog age, quest destinations and bundled navigation coverage."""
from pathlib import Path
from datetime import date
from collections import Counter
import argparse, json
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--max-age',type=int,default=45); p.add_argument('--strict',action='store_true'); args=p.parse_args()
L=LuaRuntime(unpack_returned_tuples=True); ns=L.table()
load=L.eval('function(s,ns) local f=assert(loadstring(s)); setfenv(f,{}); f("UpgradeCrossroads",ns) end')
for filename in ['Catalog.lua','Locations.lua','RecipeSources.lua']: load((ROOT/'UpgradeCrossroads/Data'/filename).read_text(),ns)
snapshot=date.fromisoformat(ns.CatalogMeta.date); age=(date.today()-snapshot).days
items=list(ns.Catalog.items()); sources=[s for _,i in items for _,s in i.sources.items()]
quest_sources=[s for s in sources if s.kind=='quest']
quest_destinations={}
unresolved_quests=set()
for source in quest_sources:
    if not source.zoneID or source.zoneID<1 or not source.zone or source.zone=='Unknown zone':
        unresolved_quests.add(source.questID)
        continue
    quest_destinations.setdefault(source.zone,set()).add(source.questID)
reviewed_destinations=Counter(s.zone for s in quest_sources if s.sourceBuild)
craft_spells={s.spellID for s in sources if s.kind=='craft'}
recipe_sources=[ns.RecipeSources[spell] for spell in craft_spells if ns.RecipeSources[spell] is not None]
report={'snapshot':snapshot.isoformat(),'age_days':age,'age_threshold_days':args.max_age,'age_warning':age>args.max_age,'items':len(items),
 'forever_override_items':sum(i.basis=='forever' for _,i in items),'classic_baseline_items':sum(i.basis=='classic' for _,i in items),
 'reviewed_quest_rewards':{'build':ns.CatalogMeta.liveQuestBuild,'observed_through':ns.CatalogMeta.liveQuestDate,
                           'quests':ns.CatalogMeta.liveQuestCount,'items':ns.CatalogMeta.liveQuestItemCount,
                           'reward_links':ns.CatalogMeta.liveQuestRewardLinks,'forever_stat_items':ns.CatalogMeta.liveQuestStatCount,
                           'added_items':ns.CatalogMeta.liveQuestAddedItems,'added_reward_links':ns.CatalogMeta.liveQuestAddedLinks,
                           'links_by_destination':dict(sorted(reviewed_destinations.items()))},
 'quest_destinations':{'named_destinations':len(quest_destinations),
                       'quests_by_destination':{name:len(quests) for name,quests in sorted(quest_destinations.items())},
                       'quests_without_named_destination':len(unresolved_quests),
                       'quest_ids_without_named_destination':sorted(unresolved_quests)},
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
