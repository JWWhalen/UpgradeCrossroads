# Catalog provenance

The bundled catalog was generated from source-linked equipment records in:

- Polestar: https://github.com/fitzforge/polestar
- Pinned commit: 9013704545b81d3b4a0117712228861b7bc921f5
- `addon/Polestar_ItemDB/Forever.lua`
- `addon/Polestar_ItemDB/Items.lua`
- `addon/Polestar_ItemDB/LICENSE-DATA.txt`
- `THIRD_PARTY.md`

`Forever.lua` identifies its source as ForeverLevelingBiS v0.12.0-beta by
Thunder, snapshot 2026-10-13, licensed MIT. The original MIT notice is included
in THIRD_PARTY_NOTICES.txt. Polestar is GPL-3.0; this distribution uses GPL-3.0
and preserves the applicable MIT data notice. No Polestar routing or UI code is
included. The generator is original to Upgrade Crossroads.

The upstream `Items.lua` contains facts from Blizzard Classic Era client
build 1.15.9.70576, not a promise of Forever equivalence. Equipment with no
Forever override remains explicitly marked `classic` in the catalog and UI.
There are 2,149 Forever override records and 1,380 Classic baseline records.
An override is a historical dataset entry, not a fresh observation on your realm.
All 3,529 admitted records have a name, equipment data and at least one source.

The source data contains 2,002 quest-source associations, 411 dungeon-source
associations, and 1,321 crafting-source associations. Several items have more
than one source. These are associations, not distinct item counts. No vendor,
auction, raid or reputation catalog coverage is claimed in this first build;
personal targets support those source types.

Quest faction, race, class and minimum-level requirements come from that
snapshot. Full prerequisite chains and source coordinates are not included
in Catalog.lua. Optional runtime QuestieDB reads can add known prerequisite
links and giver/spawn locations. See its public API:
https://github.com/Questie/QuestieDB/blob/master/docs/api.md
No Questie database code or complete provider dataset is bundled.
Reported drop chances are preserved as historical source facts but are not
shown as verified live odds or used to invent completion times.

Item names, icons and tooltips displayed in the live client use its own item
API when loaded. Known equipped items are scored against the same snapshot as
the candidate catalog to avoid mixing rating scales. Unknown equipped items
can use supported client base stats; incomplete comparisons are labeled.

# API reference

Inspected on 2026-11-07:

- https://github.com/Gethe/wow-ui-source/tree/forever
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua`

These generated client documentation files confirm the signatures of
`C_Item.GetItemInfo`, `C_Item.GetItemStats`, `C_Item.GetItemCount`,
`C_Item.RequestLoadItemDataByID`, `C_QuestLog.GetAllCompletedQuestIDs` and
`C_QuestLog.IsOnQuest`. The client reference is consulted, not redistributed
as part of the runtime addon. Interface 16001 targets the currently reported
Forever client; actual compatibility still requires live-client testing.

# Rebuild

From the extracted archive root, install Python's `lupa` package, then run:

    python tools/build_catalog.py
    python tests/run_tests.py

The pinned input files and ref are in `research/`. Updating them changes data
provenance and should be followed by regeneration, validation and updated
notices/counts. The addon does not download anything during gameplay.

# Direct tracking and entrance data (v0.2.0)

Data/Locations.lua contains 33 AreaID-to-approach mappings adapted from
Polestar's `data/codex/entrances.json` at the same pinned commit. Those cover
all 411 dungeon-drop source associations in this catalog; aliases can share
one approach. They are reported outdoor entrances/approaches, not precise
interior boss positions or newly verified live observations. Source URLs and
notes are retained on each entry and in the pinned JSON. Some instances have
different Alliance/Horde approaches; the resolver selects accordingly.

Optional installed QuestieDB's LibQuestieDB.Quest/Npc/Object.Get functions
provide composed entity fields. AreaID mappings use its ZoneDB support data
or the installed Questie ZoneDB consumer module. AreaIDs are never treated
as interchangeable with UiMapIDs. Numeric support strings are parsed as data,
not executed. The addon does not double-transform provider coordinates.

Native quest navigation uses C_QuestLog.GetNextWaypoint and the game's quest
tracking functions. The actual provider/client integration remains subject
to live-client validation. Alternative prerequisite branches, unavailable
quests and moved spawns may require corrections or a stronger eligibility
solver. The UI calls out missing/ambiguous information rather than claiming
full world guidance.

The generator now validates reviewed source hashes from research/source-lock.json
and reads the actual upstream generated snapshot date. tools/refresh_source.py
can stage an explicitly reviewed commit/date before a rebuild. A newer commit
with the same old snapshot is not presented as new game data.

# Class/spec profile design (v0.5.3)

The 29 manual class/spec choices are based on the nine classes' talent-tree
identities, with separate Survival melee/ranged and Feral cat/bear playstyles.
Class identity comes from the live client's UnitClass; talent allocation is not
read or simulated. The spec selector does not imply automatic talent detection.

Primary mechanic references inspected on 2026-11-10:

- Blizzard Hunter and Druid class deep dive:
  https://news.blizzard.com/en-us/article/24301515/world-of-warcraft-forever-class-deep-dives-hunter-and-druid
  Supports Beast Mastery, Marksmanship and Survival; Survival combines melee,
  trap and ranged options. Describes equipped weapon DPS being used for Feral
  cat/bear autoattacks and weapon-damage abilities in Forever. Accordingly,
  both Feral presets include main-hand weapon DPS rather than Classic Era's
  old stat-stick-only assumption. It does not validate numerical stat weights.
- Blizzard Mage and Shaman class deep dive:
  https://news.blizzard.com/en-us/article/24302097/world-of-warcraft-forever-class-deep-dives-mage-and-shaman
  Describes Arcane/Fire/Frost and Elemental/Enhancement/Restoration identities.
- Blizzard Paladin class deep dive:
  https://news.blizzard.com/en-us/article/24302099/world-of-warcraft-forever-class-deep-dives-paladin
  Describes Holy healing/spell options, Protection and Retribution. The starter
  Holy choice scores healing; hybrid Shockadin damage is not simulated.
- Blizzard Rogue and Warlock class deep dive:
  https://news.blizzard.com/en-us/article/24310968/world-of-warcraft-forever-class-deep-dives-rogue-and-warlock
  Describes Assassination/Combat/Subtlety and Affliction/Demonology/Destruction.
- Blizzard Priest and Warrior class deep dive:
  https://worldofwarcraft.blizzard.com/en-us/news/24301514/
  Identifies Discipline/Holy/Shadow and Arms/Fury/Protection. Direct retrieval
  was restricted during this review; class identities are not stat-weight evidence.

All numerical starter weights are Upgrade Crossroads' existing heuristic role
weights, not copied guide rankings, published simulations or validated damage
coefficients. Same-role specs intentionally share defaults. Each spec can save
independent custom weights. Descriptions call out unmodeled talents, procs,
weapon speed, school effects and other limitations. A named spec is a convenient
selection and customization key, not a promise that its score models every build.

The Hunter thrown-weapon exclusion applies to ranged recommendations. It does
not modify equipped gear or assert that every class-compatible weapon is trained
or appropriate for every build. Weapon DPS contributes only in each selected
playstyle's designated attack slots; this avoids scoring ranged Hunter melee
stat sticks as if they were the Hunter's shot weapon.

These changes do not refresh Catalog.lua: its underlying snapshot remains
2026-10-13 with the Forever/Classic coverage limitations recorded above.

# Crafting recipe acquisition

`research/recipe_sources.json` is a separate, reviewed snapshot, keyed by the
catalog's crafting spell IDs. It contains source facts and original summaries.
`tools/build_catalog.py` validates the entries, then generates
`Data/RecipeSources.lua` for spells in the current equipment catalog. The
build reports the counts of retained and unmatched recipes so that a refresh can
be reviewed before release. The game reads the generated table offline.

- Efficient Games EG Link, CC BY 4.0:
  https://github.com/JIVESCORP/eg-link-output-wowf/tree/3067c6919046428152f2152fa551f44a8c215d79
  Trainer, vendor, quest-reward and loot observations from live Forever
  builds 1.60.1.70790, 1.60.1.70862 and 1.60.1.70888. The most recent
  observation of each source was preferred. Named loot observations identify
  possible drops without implying a chance, guarantee, or exclusive source.
  Coordinates are reported player approach positions, limited to named
  vendors and trainers in their faction's capitals and starter towns.
  Conflicting observed trainer ranks are omitted.
- LibProfessionDB v1.9.1, MIT:
  https://www.curseforge.com/wow/addons/libprofessiondb/files/9095167
  Forever client build 1.60.1.69977 teaching-item IDs and automatic acquisition
  flags. The archive's SHA-256 is
  `909cb41720cf6bf6920f1c25c644f89b39ad63087f589c07737e7da943c52379`.
  When recent Forever sources are missing, the explicitly borrowed Vanilla
  sources in this release are shown as Classic baseline leads without map pins.
  Borrowed skill thresholds are excluded.
- WCLBox Forever profession pages for Blacksmithing, Enchanting, Engineering,
  Leatherworking and Tailoring:
  https://wowforever.wclbox.com/en/zhuanye/tailoring
  Build 1.60.1.70888 teaching-item facts. Rows are matched to a unique
  output item and omitted if the known teaching item disagrees. A teaching
  item can be confirmed even when its trainer, vendor, drop, or quest is unknown.
- WoW-Professions and ForeverDB vendor references:
  https://www.wow-professions.com/forever/npc/mivin-shadowweave
  https://www.wow-professions.com/forever/npc/jimbek
  https://www.foreverdb.app/en/forever/items/253890/pattern-pristine-boots
  Matched 65 Merchant's Favor recipes to the same stock, skill and cost
  at both faction vendors. Used the published Forever map IDs and vendor
  positions. Faction-specific reputation is noted where required.
- Individual recipe references:
  https://www.wowhead.com/forever/quest=6032/sacred-cloth
  https://www.wowhead.com/forever/spell=13240/the-mortar-reloaded
  Sacred Cloth teaches Mooncloth Boots. The Mortar: Reloaded refills a
  Goblin Mortar and cannot be used to obtain a new one.

Of 1,321 catalogued crafting spells, 410 have Forever guidance beyond the
identity of a teaching item, 496 have a labeled Classic baseline lead, and
415 name a teaching item with the acquisition source unverified. There are
202 recipes with at least one faction-filtered map pin. Recipe notes identify
where to learn a recipe. Crafting stations, ingredients, and recipe ownership
are not inferred. When refreshing the snapshot, review the new facts in the
JSON, preserve the evidence field, and rebuild the generated Lua.

## Quest journal design reference (0.6.0)

The requested reference was GearQuest Forever's public quest-log workflow and
gallery, reviewed November 10, 2026:

- https://www.curseforge.com/wow/addons/gearquest-forever
- https://www.curseforge.com/wow/addons/gearquest-forever/gallery

Crossroads implements its own equipment groups, item-detail parchment, item
actions and Active/Completed/Removed lifecycle on its existing data and scoring.
No GearQuest source code, hunt database, custom artwork or brand assets are
included. Surfaces use Blizzard quest/dialog UI resources supplied by the game;
the Crossroads emblem is the previously approved project asset. Offline previews
substitute native art and fonts and are labeled accordingly.

## Original scenic skin (0.6.1)

The mountain-valley background is original generated project artwork, not a
GearQuest asset. The source is art/JournalLandscape.png; the client export is
Media/JournalLandscape.tga, built and checked by tools/prepare_journal_art.py.
art/Journal-Landscape-Notes.txt records its provenance and prompt summary.
The title bar and borders reference the game's own dialog/minimap resources.
Offline previews load the actual bundled scenery while approximating those
native textures and fonts. They are not live-client captures.

## Original illustrated parchment (0.6.2)

The right detail pane's paper is original project artwork generated from the
project's mountain-valley painting as a faint sepia illustration on parchment.
It does not use GearQuest's custom artwork. The source is
art/JournalParchment.png; the client export is Media/JournalParchment.tga.
art/Journal-Parchment-Notes.txt records its provenance and prompt summary.
tools/prepare_journal_art.py checks both original scenery exports. Offline
previews render the bundled paper pixels; native frame/font substitutions
remain approximations and are labeled accordingly.

## Original continuous panorama (0.6.3)

One original wide landscape now spans both journal panes and their center gap.
It reinterprets the project's own mountain-landscape motif as an uninterrupted
scene, with cool dark painting on the left fading into pale parchment and faint
sepia terrain on the right. It does not repeat the scene or use GearQuest art.
The master is art/JournalPanorama.png; the client export is
Media/JournalPanorama.tga, built/checked by tools/prepare_journal_art.py.
art/Journal-Panorama-Notes.txt records its provenance and prompt summary.
Earlier landscape/parchment PNG masters remain as design history, while their
separate client TGA exports are no longer shipped or used. Offline previews
render the actual shared canvas; native frame/font substitutions remain labeled.
Pane-local readability washes are color tints, not repeated illustrations.
