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
