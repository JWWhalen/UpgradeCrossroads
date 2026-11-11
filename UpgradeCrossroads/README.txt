UPGRADE CROSSROADS 0.6.5
WoW: Forever addon by FlakieGames

INSTALL
1. Close World of Warcraft completely.
2. Extract the ZIP somewhere convenient, such as Downloads.
3. Copy the UpgradeCrossroads folder into your Forever client's Interface/AddOns
   folder. Use Battle.net's game options > Show in Explorer to find the client.
   The typical path is:
   World of Warcraft/_forever_/Interface/AddOns/UpgradeCrossroads/
4. Confirm UpgradeCrossroads.toc is directly inside that folder. Avoid an extra
   nested UpgradeCrossroads/UpgradeCrossroads folder.
5. Start the game. Enable Upgrade Crossroads in the character-selection AddOns
   list, enter the world, and type /uc.

FIRST USE
The approved emblem beside your minimap opens the planner. Right-click for Hunts;
drag it to reposition. /uc minimap reset restores the shortcut if it goes missing.

The Journal opens first. It groups ranked suggestions under expandable equipment
headings, with a parchment description and reward on the right. Choose your spec,
then select any item. Track, Show on map, Remove and Chat are on that same item.
Click the reward itself to start its guide. Shift-/right-click drafts an item
link; Ctrl-click previews it. Nothing sends a chat message automatically.

Active shows eligible suggestions. Completed records items actually observed in
your bags/equipment or acquired saved hunts; it is not a full historic collection.
Removed hides an item until you restore it, preserving its hunt notes/checklists.
Use Filters for source paths, Solo, Crafts, AH and Alliance/Horde/Both. Available
now uses your current level; Future goals includes later levels. The left search
matches item, boss, quest and zone names across every slot. Choose 1/3/5/10 picks
per slot; these ranks use model weights, not verified BiS or a simulation.

Compare retains the detailed single-slot Quest & craft, Dungeons and Future gear
views. Hunts retains your saved preparation checklists and notes. All pages share
the same window; appearance, minimap, scaling and source correction still work.

CLASS AND SPEC
The spec button offers only the detected character class's choices: 29 choices
across nine classes. Choose the spec manually; this does not read your talent
allocation or automatically switch when you change talents. Hunter Survival has
separate melee and ranged playstyle choices; Druid Feral has cat and bear choices.

These are starter role-weight presets, not guide-derived or simulated spec
rankings. Specs sharing a role intentionally share their default weights. The
profile explanation describes what is scored and what is not. /uc weights edits
only the selected spec; /uc weights reset restores only that spec's defaults.
Your old broad-role selection maps to a suitable spec for your class. Existing
custom role weights are copied to that class's matching role presets once, while
existing spec overrides and old weight entries are preserved. Hunts and notes
are retained. Resetting a spec does not re-import old weights on the next login.

Weapon recommendations also obey class compatibility. Hunters' ranged-slot
recommendations include bows, guns and crossbows, not thrown weapons. This is a
recommendation filter; it does not delete or alter an item you already equipped.
Weapon DPS is scored in the selected playstyle's attack slots, so melee weapon
DPS does not inflate a ranged Hunter's stat-stick score. Forever Feral cat/bear
presets include main-hand weapon DPS; form abilities and procs are not simulated.

FACTION
Gear has exactly three faction choices: Alliance, Horde and Both. It defaults
to the current character's faction, and saves your choice. Shared/untagged
sources remain visible. Other filters still apply. Opposite-faction sources
are labeled unavailable to this character. Saved hunts and notes are retained;
source cycling only offers sources included by the selected faction view.

ONE WINDOW, CLEANER TEXT
Journal, Compare, Hunts, Settings, Help and Add item share one main window. One page
is shown at a time. They share size, scale, position and a native close button;
the tracker alone stays separate. Closing the shell hides every page.

Settings or /uc appearance opens saved presets, panel opacity, custom colors,
font choice, text size, optional outlines and a window-scale slider. WoW's
standard font is the default throughout the addon, including body text, item
rows, controls and the tracker. Plain readable text remains an optional font.
Older font settings switch once to the WoW default on upgrade; choose Plain
again in Settings if preferred. New explicit choices survive future reloads.

The default appearance uses one continuous panorama across the list and detail
pane, an umber/brass title bar, heavier native frame borders, native action
buttons and a round minimap emblem. The scene flows across the middle, fading from
deep cool terrain on the left into richer warm-tan aged parchment and faint
sepia terrain on the right. Dark ink remains readable over the detail area;
the artwork stays behind every control and follows the shared window when it
is resized.

The circular icon has transparent corners. There is no square minimap backdrop.
Restart the client after installing its new texture filenames.

Drag a title to move; drag the corner grip to scale; Shift-drag to change layout
space. Readable mode keeps whole-pixel text sizes and the 80-150% scale range;
disabling it permits 50-150%. /uc resetwindows resets shell/tracker geometry.
Hunts and appearance choices remain saved. Closing the tracker keeps its hunt;
/uc guide reopens it. Stop tracking releases the waypoint but retains notes.

MAP GUIDANCE
The map action uses active quest guidance, known provider locations, or an
outdoor dungeon entrance/approach. The guide explains which kind it is.
Install a compatible Forever QuestieDB release for additional quest giver,
creature and known prerequisite locations. An absent/incompatible provider
does not prevent the core addon from loading. These integrations need live
testing on your client. Not every prerequisite branch can be solved.

All 411 dungeon-drop source links in this snapshot have a bundled outdoor
approach mapping. This does not cover interior boss coordinates, every quest
pickup or crafting materials. Unknown locations get a clear guide message.
Set location in the guide opens a popup with that item/source already selected;
it saves a source correction, not a duplicate item. Custom item is for gear
outside the catalog, not the normal tracking flow.

THE THREE PATHS
Reliable Upgrade: defined quest rewards and crafts that score higher than your
equipped piece. This does NOT mean a quest or recipe is already available.
Dungeon Hunt: known drops and group quest rewards at your level. Actual access,
loot availability and group requirements still need checking.
Long-term Target: highest-scoring known gear for this slot, including later
levels up to 60. These are goals under a simple model, not verified BiS lists.

PREFERENCES
Solo only hides known dungeon/raid drops and quests tagged as requiring a group.
Crafted allowed permits crafted targets; you may need another player to craft.
AH allowed permits your personal auction targets. This build does not scrape
auction listings, invent prices or promise that an item is for sale.

ADDING YOUR OWN TARGET
Choose Add item, enter an item ID (or paste an item link), cycle the source
type, and enter the source name and location/requirements. The item's data must
be in the client cache or bundled catalog. If the client is loading it, wait a
moment and press Save target again. Adding a source replaces that item's catalog
entry for this character. It is labeled Personal, not independently verified.
An optional valid map ID and X/Y percentages add a destination waypoint.
No coordinates are invented for catalog entries with unknown positions.

SCORING AND DATA LIMITS
Scores are weighted sums of base stats. A +20 score is NOT +20% DPS, healing or
survival. Profiles are starter role presets; choose/edit them for your build.
Procs, set bonuses, caps, talents, school-specific bonuses and encounter effects
are not simulated. Inspect the real tooltip before choosing a target.
Weapon setups that differ (one-hand versus two-hand) do not receive a delta.
Weapon skill, talents, prerequisites and quest availability can still restrict
an otherwise class-compatible item. Custom sources are manually supplied.

Catalog: 3,529 source-linked items from an attributed snapshot dated 2026-10-13.
2,149 entries have Forever stat overrides; 1,380 use clearly labeled Classic
baseline stats. See SOURCES.md. New content and changed stats can be missing.
Known equipped items use the same snapshot for consistent model comparisons.
Client-loaded stats are used for equipment outside the catalog and personal
targets where available. Incomplete comparisons are labeled instead of assigned
a made-up percentage. This is an early build, not a comprehensive live database.

Hunts and settings save per character through WoW's normal SavedVariables.
Ownership detection covers your bags/equipped items, not an unvisited bank.
Hunt checklists and notes are manual. An obtained status stays recorded even
if you later sell or replace the item. Remove a hunt to stop tracking it.

COMMANDS
/uc                  Open or close the addon
/crossroads          Same as /uc
/uc hunts            Open your saved hunts
/uc add              Add a personal target outside the catalog
/uc guide            Return to your active guide
/uc about            Explain the scoring and data
/uc appearance       Open the Settings page to customize colors, opacity, font and readable scaling
/uc weights          Print current profile weights
/uc weights str=1 agi=0.8 sta=0.25
                     Set weights for the current profile; changes save
/uc weights reset    Restore the current profile's default weights
/uc scale 0.8        Set and save planner scale (0.8 to 1.5 in readable mode)
/uc resetwindows     Restore all window sizes, positions and scales
/uc status           Print build/interface and API diagnostics
/uc minimap show     Show the minimap shortcut
/uc minimap hide     Hide the minimap shortcut
/uc minimap reset    Reset its position and show it

UPDATES
See UPDATING.txt. Published releases can be delivered through CurseForge. Your equipment,
level and hunt state refresh in game, but the bundled catalog remains a dated
snapshot until a maintained data release replaces it.

VALIDATION
The source is syntax-checked and tested in Lua 5.1 with client doubles. Tests
exercise filters, scoring, class/slot coverage, custom targets, saved hunts,
ownership changes, UI construction and command/event flows. This v0.5.3 update has
NOT been tested inside the live WoW: Forever client. The included PREVIEW.png
is an offline rendering of the Lua UI layout with sample data and icon
placeholders; it is not an in-game screenshot.

If something fails, run /uc status, then /console scriptErrors 1 and /reload.
Copy the error text and the status lines for troubleshooting. Disable error
popups again with /console scriptErrors 0 when finished.

DEVELOPER FILES
The archive also includes tools, tests and pinned research inputs. You do not
need to copy these into AddOns. The addon itself has no external dependencies.
See the archive's DEVELOPMENT_AND_MAINTENANCE.txt for the full Windows setup,
polish, publishing and ongoing maintenance steps. VALIDATION.md and SOURCES.md
record what was checked and where the data came from.
