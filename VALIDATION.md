# Upgrade Crossroads 0.7.0 validation

Target: WoW: Forever, interface 16001. Built 2026-11-10.

## Consolidated journal and content-page theme in 0.7.0

Journal is the only visible gear-browsing page. Equipment selects one slot or
all slots; the detail pane includes equipped item information and its Chat
action along with the candidate's source, stats and model comparison. The
legacy Compare page request redirects to Journal. Acquisition paths, source
cycling, filters, ranking, chat, guides, saved hunts, notes and lifecycle views
remain available.

Hunts, Help and Add item use the same original panorama, aged-paper treatment,
native frame references and WoW font as Journal. The Settings page keeps its
plain controls and has no illustrated page background. This revision does not
replace the art or refresh the dated catalog.

All 88 automated groups and 21 strict offline layouts pass. New cases cover
the five public tabs, slot-filter persistence, browsing beyond ten results,
equipped comparisons and unsent chat even with no matching upgrade, shared
page artwork, plain Settings, input contrast, and Largest-text control bounds.
Editor fields, Help headings and hunt notes/actions use measured reflow. The
old comparison frame stays hidden for compatibility; public Compare requests
redirect to Journal.

Default, themed and minimum-size pages were visually reviewed. The panorama
source/export check also passes. Offline previews use substitute native
frame/font/icon rendering and do not constitute an in-game test. Verify slot
selection, equipped comparisons, page exclusivity, note editing, editor Cancel
and readable scaling in the live client before publishing.

## Native default font in 0.6.5

The default font uses the client's STANDARD_TEXT_FONT when valid, falling back
to Fonts/FRIZQT__.TTF. Body text, item rows, controls, settings and tracker text
use the shared font handling; the Plain option retains its readable typeface.
No client font is copied into the addon. Physical-pixel sizing, text-size options
and dark parchment ink remain in place.

Schema 6 switches older font settings once to the WoW default. Older saved Plain
settings cannot distinguish an earlier automatic default from an explicit choice;
users who prefer Plain can select it again. New explicit choices are saved for
future reloads. Hunts, notes, custom colors and the darker panorama are retained.

All 85 automated groups and 18 strict offline layouts pass for this revision.
Updated assertions cover default fonts across registered text, the client font
override and fallback, one-time migration preserving hunts and custom colors,
Plain persistence and restoring the font default. Offline previews use
substitute fonts and cannot prove the exact native typeface or its live-client
rendering.

## Darker journal palette in 0.6.4

This visual refinement changes only the pane color glazes: deeper scenery on
the left and richer warm-tan parchment on the right. The same continuous
panorama, geometry, actions and saved preferences remain.

All 18 layouts were freshly exported from the actual Lua UI and pass strict
offline text checks. The default palette was visually compared with the prior
preview. The 85-group result for 0.6.3 below remains historical evidence; the
unchanged scoring/hunt suite was not rerun for this color-only change.
Live-client appearance remains untested.

## Continuous panorama in 0.6.3

The journal uses one background texture across the list, center gap and detail
pane. It is one uninterrupted original scene, with dark cool terrain on the
left fading into pale parchment and faint sepia terrain on the right. Pane
borders remain separate while their interiors reveal the shared canvas.
Pane-local color-only washes preserve contrast for pale list text and dark
detail ink. These tints contain no additional scene artwork.

The master is art/JournalPanorama.png. The client export is
Media/JournalPanorama.tga, 1024x512 uncompressed 32-bit RGBA.
prepare_journal_art.py rebuilds/checks the current panorama against its master.
The two earlier client scenery exports are removed; their original PNG masters
and provenance notes remain as design history.

The offline preview uses the actual shared image, with native border, font and
item-icon approximations. This revision passes all 85 automated groups and 18
strict offline layouts, plus the current panorama and approved logo export
checks. Focused Lua checks confirm one scene texture spans both panes during
900/1200-width resizing, with transparent pane backdrops and color-only washes.
Default and minimum/Largest-text layouts were visually inspected. Live texture
loading and native-client appearance remain untested.

## Illustrated detail pane in 0.6.2

The right journal pane uses original illustrated parchment rather than plain
paper. Its faint sepia mountain valley is derived from the project's original
landscape artwork. The source is art/JournalParchment.png; the client export is
Media/JournalParchment.tga, 512x1024 uncompressed 32-bit RGBA.
prepare_journal_art.py rebuilds/checks both scenery exports against their PNG
masters. The right pane retains dark ink and its existing readability floor;
item actions, scroll layout and hunt behavior are unchanged.

The preview uses the bundled illustrations on both sides, while still
approximating native frame textures, fonts and item icons. This revision passes
all 85 automated groups and 18 strict offline layouts, including minimum sizes
with Largest text. Both scenery exports and both logo exports pass their
source/format checks. Focused Lua checks also cover the new paper, resize
anchors and its opacity floor. Live texture loading remains untested.

## Scenic skin revision in 0.6.1

An original generated mountain landscape is shipped as a 512x1024 uncompressed
32-bit RGBA TGA. Its source PNG is retained under art; prepare_journal_art.py
rebuilds it and --check verifies exact pixel equality and client texture format.
CI and tagged releases run that check. The list applies a separate dark veil.
An ornamental shell adds native dialog borders, an umber title bar and brass
trim without creating interactive overlay frames or changing item actions.
Its textures reflow during normal scale/resize and appearance changes.

The offline preview uses the actual bundled scenery, with native border/title
art substitutions. Live texture loading and client-native appearance still need
verification. This revision does not add or remove journal, scoring or hunt
features.

The scenic build passes all 85 automated groups and 18 strict offline layouts,
including minimum geometry with Largest text and non-default UI scales. Both
logo exports and the new landscape pass their source/format checks. Catalog
rebuild and audit pass with the unchanged October 13 snapshot.

## Quest journal revision in 0.6.0

The new default Journal uses grouped equipment headings, ranked rows, native
quest highlights and parchment item details. Active, Completed and Removed are
views in the same page. Track, map, source selection, removal/restoration and
unsent chat linking operate on the displayed item. Compare preserves the prior
single-slot workflow; Hunts, Settings, Help and the editor remain shared pages.

Removal preserves pin notes and checklists and stops that active tracker.
Restoration makes the suggestion eligible for the normal rules again. Completion
requires observed item ownership or a previously acquired pin; it does not infer
ownership from a quest completion or a checklist. Observations persist after an
item is sold. The list is not a complete historical collection of unseen items.

The journal model indexes the catalog by inventory type before applying the
existing scoring and eligibility rules. It retains source, faction, armor
training, weapon setup and class restrictions. Future armor preserves the level
40 training floor. Comparable downgrades stay excluded. Unknown comparisons are
labeled as target model scores. Custom weights are labeled accurately.

Responsive tests cover item actions, alternate sources, lifecycle persistence,
search, collapse/expand, pick counts, filters, future requirements, page
exclusivity and large text. Footer actions can wrap to two rows; tab widths and
the shared footer reserve are measured from their actual fonts. The parchment
scroll child stays separate from fixed actions. Native art previews are
approximate substitutes and remain labeled as offline layouts.

The release validation comprises 85 automated groups and 18 offline layouts.
The extreme-size case uses a 900x720 shell, 80% addon scale, 64% global UI scale,
Largest text and the long Hunter Survival specialization label. Explicit checks
cover header/navigation separation, panel/intro separation, measured state tabs,
search-row bounds and non-overlapping footer buttons. Catalog rebuild/audit and
the approved logo texture checks also pass.

No live WoW client was connected, and no in-game screenshot or playtest is
claimed. Verify texture loading, scrolling, font rendering and actual native
templates in game before publishing. This update does not add GearQuest's
simulator, enchant recommendations, gamepad navigation or its item database.

## Earlier validation retained below

## Evidence and changes

The user's v0.4.0 screenshots show overlapping main/settings windows, nearly
transparent surfaces, excessive gold controls, outlined text and truncated
small button labels. The old offline preview did not reproduce those client
texture/template effects. The revision addresses those concrete problems:

- Gear, Hunts, Settings, Help and editor are mutually exclusive child pages.
- Only the shared shell and tracker are movable/resizable top-level windows.
- Main pages inherit shell geometry and are hidden when the shell closes.
- Solid WHITE8X8 surfaces give explicit opacity; text alpha is unchanged.
- Native action buttons own one font string, have no added backdrop and fit
  using actual font measurements. Lists use quieter rows instead of buttons.
- Native close/resize textures replace tiny textual chrome controls.
- Plain body text and no outline are the new defaults; title fonts remain distinct.
- A circular RGBA emblem with transparent corners replaces the square minimap art.

## Automated checks

76 groups load the actual TOC and Lua under Lua 5.1 via lupa with an explicit
client double. Existing scoring/filter/class/slot/profile, cache, saved hunt,
notes, ownership, weight, chat, quest/provider, waypoint and combat cases pass.
The changed UI cases cover shell geometry, page inheritance, exclusive page
navigation without new floating frames, native single-label buttons, measured
button bounds, shell close/resume tracker behavior, editor cancellation, style
migration preserving custom data, and large text with non-default UI scaling.

The double uses substitute font measurements and does not emulate native
button templates or GPU font rendering. Its native-template assertions are
structural checks, not a claim that the user's client has been exercised.

Both current TGA assets are uncompressed 32-bit RGBA, at 64x64 and 256x256.
All four corners are fully transparent and their centers are opaque. The PNG
master retains generated transparency. The minimap button has no square backdrop.
The texture build check verifies both committed assets against that master.

Fourteen offline frame-tree layouts cover default and compact shell pages, normal
and largest text at 80% scale, and the separate tracker. Strict text overflow
checks and visual spacing review pass. Native art/font substitutions are labeled.
The preview respects scroll clipping, scale, alpha and packaged texture pixels.

## Persistence and data

Schema 5 retains hunt notes, custom items, weights, source corrections, colors,
minimap state and shared shell/tracker geometry. Obsolete per-page window
geometry no longer controls page positions. /uc resetwindows clears it.

Catalog remains 3,529 items from 2026-10-13: 2,149 Forever overrides and 1,380
marked Classic baselines. The 411 dungeon-drop source links map to bundled
outdoor approaches offline; this is not interior routing or live loot coverage.

## Required live pass

No live WoW client was connected. Verify actual native button and close art,
font bounds, texture loading, focus, wheel scrolling, color-picker layering,
combat/taint behavior and interaction with other addons. Restart after installing
new texture filenames; START_HERE.txt gives the short install and check sequence.
No offline result is presented as an in-game playtest.

## Faction selector in 0.5.1

Five additional groups cover exactly three choices; faction detection for
Alliance/Horde characters; tagged sources across all supported source kinds;
shared/untagged source retention; class/solo/crafting rules; opposite-faction
racial/history previews; alternate source lists without duplicate items; saved
hunt/notes retention; cycling/persistence; and the control's bounds at minimum
size with largest text and non-default global UI scaling. Source labels and
availability identify faction-exclusive acquisition. Source tags come from the
existing snapshot; this release does not add or infer new faction data.

## Class/spec feedback in 0.5.3

The character class replaces broad role labels; only its specs are cycled.
29 choices cover nine classes, including Hunter Survival melee/ranged and
Druid Feral cat/bear. Starter weights are original role estimates: same-role
specs intentionally share defaults and are not advertised as simulated BiS.
Hunter ranged recommendations reject thrown weapons regardless of score;
bows, guns and crossbows remain. Explicit DPS-slot policy is used for both
candidates and equipped baselines. Forever Feral presets include main-hand
weapon DPS following Blizzard's published class change.

Seven new groups verify weapon filtering, all-nine-class ranged compatibility,
explicit DPS policy, class-only selection, independent per-spec overrides,
legacy migration, safe reset/reload, and longest-label geometry. Fourteen
layouts include minimum-size Hunter Survival and Warlock Destruction at
largest text. All 76 groups and 14 strict layouts pass. No live-client pass
has been performed for v0.5.3; the user's prior v0.5.2 pass is not reused as
proof of these changes. The catalog snapshot remains October 13.
