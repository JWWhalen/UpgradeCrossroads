# Upgrade Crossroads 0.5.1 validation

Target: WoW: Forever, interface 16001. Built 2026-11-08.

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

69 groups load the actual TOC and Lua under Lua 5.1 via lupa with an explicit
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

Twelve offline frame-tree layouts cover default and compact shell pages, normal
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
