# Questie-Octo 1.17 — Perceptual Objective Color Separation Audit

## Why this pass exists

Questie-Octo 1.15 guaranteed that different quests would not quantize to the exact same objective RGB on the previously tested candidate sets. That guarantee was useful but insufficient: two different RGB triplets can still be visually indistinguishable on a small colored map node.

The 1.17 audit therefore uses **CIEDE2000 (DeltaE00)** as the separation metric and validates colors **after 8-bit quantization**, matching the effective rendered color resolution rather than comparing only full-precision RGB.

## Correct co-occurrence scope

`Data/runtime/map-candidates.lua` is intentionally optimized for quest starter/item-start discovery and is not the active-objective color graph. This audit reconstructs the map memberships for the roles that actually receive quest colors:

- `objectiveCreature`
- `objectiveObject`
- `objectiveItemSource`

The reconstruction includes normal creature/object sources, item/reference/vendor sources, scripted encounter fallbacks, objective-source overrides, and IR guidance. Disabled quests and AreaTrigger-only objectives are excluded because AreaTrigger pins currently do not use per-quest objective tint.

Current audited graph:

- **3,446** quests with at least one colorized objective map
- **119** maps
- **700,992** unique quest pairs that can share at least one colorized-objective map

## Accepted 1.16 vs 1.17

Counts below are unique same-map objective quest pairs after conventional 8-bit output.

| Mode | 1.16 min DeltaE00 | 1.16 <2.3 | 1.16 <5 | 1.17 min DeltaE00 | 1.17 <2.3 | 1.17 <5 |
|---|---:|---:|---:|---:|---:|---:|
| Default | 0.056 | 5,076 | 24,719 | **2.321** | **0** | **6,768** |
| Red-deficient | 0.000 | 4,947 | 21,432 | **2.303** | **0** | **6,095** |
| Green-deficient | 0.000 | 6,259 | 26,617 | **2.303** | **0** | **8,510** |
| Blue-deficient | 0.000 | 4,354 | 19,689 | **2.304** | **0** | **3,463** |
| High Contrast | 0.096 | 4,096 | 18,409 | **2.301** | **0** | **3,640** |

Every 1.17 mode has **zero exact 8-bit RGB collisions** on the same-map objective graph.

### Grim Reaches (map 5602)

Default mode improves from **403 pairs below DeltaE00 2.3** to **0**, and from **2,000 pairs below DeltaE00 5** to **801**. All five modes now have zero sub-2.3 pairs on the map.

### Westfall (map 40)

Default mode improves from **107 pairs below DeltaE00 2.3** to **0** and from **579 pairs below 5** to **159**. All five modes now have zero sub-2.3 pairs.

## Runtime design

The expensive graph construction and perceptual optimization are offline build work only. `Data/ObjectiveColorPalette.lua` stores each audited quest's final mode-specific 8-bit RGB in a compact 15-byte string. `Map/Visuals.lua` performs one quest lookup and three `string.byte` reads for the selected mode.

This preserves the existing invariants:

- one quest has one stable color within a selected mode;
- World Map and minimap agree;
- Full Nodes, clustered tint, and glow agree;
- changing other active quests does not recolor existing quests;
- no map-local runtime palette allocation;
- no polling, `OnUpdate`, ZoneBootstrap work, map scan, or objective DB scan.

The 1.15 deterministic palette remains as a defensive fallback for a future/unmapped quest ID that is not yet present in the generated table.
