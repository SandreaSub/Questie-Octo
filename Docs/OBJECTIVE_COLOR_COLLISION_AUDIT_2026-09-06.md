# Questie-Octo 1.12 — Objective Color Collision Audit

Date: 2026-09-06
Baseline: accepted Questie-Octo 1.11
Trigger: player report from Grim Reaches showing multiple unrelated quests rendered with effectively the same purple, pink, or blue Full Nodes.

## Confirmed root cause

The 1.0.95 objective palette keyed the pfQuest-style string hash with `"quest" .. questID`. The hash itself spans 24-bit RGB, but its byte-grouping is poorly avalanched for nearby decimal strings. Turtle content is frequently assigned consecutive quest IDs, so nearby IDs retain identical or near-identical high RGB components.

The reported Grim Reaches examples reproduce exactly in 1.11:

- 41850 The Gemstone of Naraz: `#523DCE`
- 41852 Earthen Relics: `#5235D0`
- 41853 Groldan's Grudge: `#5231D1`
- 41855 Reclaiming Sal'Galaz: `#5229D3`
- 41857 Miregill Distraction: `#5221D5`
- 41872 Provisions for War: `#CB35D7`
- 41875 Repairing Baggoth's Wall: `#CB29DA`
- 41867 Blemishes on the Land: `#0EA1E1`
- 41869 Death to Grimscale: `#0E99E3`

The screenshot therefore reflects a deterministic palette correlation, not a pin-merging or quest-ownership bug.

## 1.12 correction

`Visuals:GetQuestColor()` now derives its base color directly from the numeric quest ID:

1. Multiply the ID by 40494 modulo the prime 65521.
2. Interpret that phase as hue. The ratio 40494/65521 closely approximates the golden-ratio conjugate, deliberately placing consecutive IDs far apart around the hue wheel.
3. Add small deterministic saturation/value bands to improve separation when non-neighboring IDs happen to land near the same hue.
4. Convert HSV to RGB with Lua-5.0-compatible arithmetic only.
5. Apply the existing Objective Color Vision remap afterward, exactly where it was already applied.

No active-quest-list assignment is introduced: quest ID remains the permanent color identity, so the same quest keeps the same color across sessions, objectives, World Map, minimap, tint, glow, and Full Nodes.

## Reported sample after correction

The same quest IDs now occupy visibly different regions of the palette rather than three tight color families. In approximate 8-bit RGB they become:

- 41850: `(37, 125, 232)`
- 41852: `(233, 58, 240)`
- 41853: `(63, 224, 172)`
- 41855: `(46, 28, 232)`
- 41857: `(240, 48, 143)`
- 41867: `(240, 153, 29)`
- 41869: `(49, 247, 50)`
- 41872: `(211, 240, 19)`
- 41875: `(232, 93, 46)`

## Scope / regression boundaries

Changed only the base active-objective quest palette in `Map/Visuals.lua`.

Unchanged:

- quest/objective ownership and clustering;
- map/minimap candidate generation;
- Full Nodes density and size;
- available `!`, completed `?`, repeatable/event/PvP, Flight Master, rare, and service icons;
- tracker-hover focus behavior;
- Objective Color Vision setting keys and UI;
- map/minimap refresh architecture;
- timers, polling, `OnUpdate`, ZoneBootstrap, and database/runtime data.

The legacy string `HashColor()` remains only for the compatibility `GetObjectiveColor()` path; current quest presentation uses the new numeric palette.
