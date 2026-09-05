# Questie-Octo — Gnomeregan Shared Map Audit

**Audit date:** 2026-09-05  
**Implementation base:** accepted Questie-Octo 1.06  
**Resulting test build:** 1.07

## Player report

Two live screenshots showed two related failures:

- the **Gnomeregan Entrance** World Map displayed a large set of dungeon-looking quest/objective/service nodes;
- the **Gnomeregan dungeon interior** also displayed many nodes in positions inconsistent with the current dungeon artwork.

This was not treated as a Full Nodes density problem. The map/data ownership path was audited first.

## Confirmed root causes

### Shared AreaTable ID

Current client `WorldMapArea.dbc` contains two distinct map-art rows that both resolve to AreaTable ID **721**:

| Context | Server map | AreaTable | Texture | Current span |
| --- | ---: | ---: | --- | ---: |
| Entrance/exterior | 0 | 721 | `GnomereganEntrance` | 571.19 × 379.14 |
| Dungeon interior | 90 | 721 | `Gnomeregan` | 1125 × 740 |

The legacy pfQuest-style runtime keys both populations by numeric map 721, so without a secondary context the renderer cannot know which sibling map owns a source.

### Stale interior geometry

The legacy map-721 interior coordinates were projected against an older approximately **769.67 × 513.11** map span. The current interior artwork uses **1125 × 740**. Current server map-90 spawn positions therefore had to be reprojected against the current client bounds rather than rescaled visually at render time.

### Stale source records

Creature IDs **385** and **9526** retained map-721 coordinates in the packaged legacy data but have no current Gnomeregan spawn in the audited server data. Their map-721 coordinates are removed.

### Legitimately shared source

Mechanical Mailbox **144112** exists in both entrance and interior contexts. It cannot be classified by object ID alone. Its current normalized map-721 points are:

- entrance: `70.0, 3.2` and `68.7, 4.5`;
- interior: `61.8, 40.9`.

The shared-context filter therefore supports coordinate-level source classification.

## Current source population used

Current server data separates the map-721 source population into:

- **40 entrance creature IDs**;
- **21 interior creature IDs**;
- **7 entrance object IDs**;
- **8 interior object IDs** (including the shared mailbox);
- entrance AreaTriggers **324, 523, 1104**;
- interior AreaTriggers **322, 1105**.

The current runtime after regeneration contains no unclassified unit/object/AreaTrigger coordinate on map 721.

## Implementation

1. Added `Map/GnomereganContext.lua` as a narrow shared-area compatibility layer, following the already accepted Karazhan pattern rather than changing normal map identity globally.
2. World Map context is selected from the displayed `GnomereganEntrance` / `Gnomeregan` texture.
3. Minimap physical context is selected from server map 0 / 90 and uses the matching current map dimensions.
4. World Map and minimap node filtering is source-local and coordinate-aware for legitimately shared sources.
5. Minimap descriptor visibility caching includes the shared context so a cached entrance result cannot leak into the interior after a context change.
6. Rebuilt only map-721 coordinates for current interior sources from current server positions + current client WorldMapArea geometry. Non-721 coordinates remain untouched.
7. Corrected quest-relevant interior AreaTriggers 322 and 1105.

## Explicit non-changes

This correction does **not**:

- reduce Full Nodes density;
- slow ZoneBootstrap or quest appearance;
- add polling or another `OnUpdate`;
- add a spatial minimap index;
- add a new global persistent reverse index;
- alter unrelated map IDs;
- change quest availability semantics.

## Validation boundary

Static/runtime validation can prove the generated data, context classification, Lua syntax, package shape, and runtime database integrity. Exact visual placement on the live client still requires the player's in-game Gnomeregan entrance/interior retest.
