# Shared Instance Map Audit — 2026-09-05

## Scope

This audit was triggered by the validated Gnomeregan 1.07 correction. It checks the current client `WorldMapArea.dbc` for every case where more than one selectable instance/detail map reuses the same `AreaTable` ID, then checks Questie-Octo's current runtime sources, current Turtle/Octo server spawns, map geometry, minimap dimensions, and relevant AreaTriggers for the same entrance/interior contamination failure class.

The accepted baseline for the audit is **Questie-Octo 1.07**. The resulting test build is **1.08**.

## Complete shared-ID result

The current `WorldMapArea.dbc` contains exactly seven AreaTable IDs reused by distinct instance/detail map-art contexts:

| AreaTable ID | Contexts | Status |
|---:|---|---|
| 718 | Wailing Caverns Entrance / Wailing Caverns | Fixed in 1.08 |
| 721 | Gnomeregan Entrance / Gnomeregan | Fixed and live-validated in 1.07 |
| 1337 | Uldaman Entrance / Uldaman | Fixed in 1.08 |
| 2100 | Maraudon Entrance / Maraudon | Fixed in 1.08 |
| 2557 | Dire Maul Entrance / Dire Maul | Fixed + coordinates rebuilt in 1.08 |
| 3457 | Lower Karazhan / Upper Karazhan 1F | Existing dedicated context split retained; ambiguous sources remain fail-closed |
| 5640 | Timbermaw Hold Entrance / Timbermaw Hold | Fixed + coordinates rebuilt in 1.08 |

No other current dungeon or raid WorldMapArea uses this exact shared-AreaTable entrance/interior structure.

## Current client geometry

| Area | Entrance server map / size | Interior server map / size |
|---|---|---|
| Wailing Caverns 718 | map 1 — 572.78 × 381.85 | map 43 — 1170 × 785 |
| Uldaman 1337 | map 0 — 563.31 × 376.10 | map 70 — 893.67 × 595.78 |
| Maraudon 2100 | map 1 — 824 × 550 | map 349 — 2112.09 × 1410.89 |
| Dire Maul 2557 | map 1 — 1324 × 869 | map 429 — 1919 × 1250 |
| Timbermaw Hold 5640 | map 1 — 1347 × 971 | map 819 — 1425 × 962 |

The legacy minimap table can store only one width/height pair per numeric AreaTable ID. 1.08 therefore selects the correct geometry from the physical entrance/interior context instead of trusting that single ambiguous value.

## Per-instance findings

### Wailing Caverns — 718

Current source coordinates already match the current client geometry. The problem is presentation context, not stale data.

- 20 entrance-only creature IDs.
- 28 interior-only creature IDs.
- 3 creature IDs legitimately exist in both contexts: 3641, 3835, 61218.
- 5 entrance-only object IDs.
- 5 interior-only object IDs.
- 4 object IDs legitimately exist in both contexts: 1622, 1624, 1731, 13891.
- AreaTriggers 228 is entrance; 226 and 3766 are interior.

Shared sources are separated by their individual one-decimal runtime point, preserving both legitimate populations without showing either population on its sibling map.

### Uldaman — 1337

Current source coordinates already match the current client geometry. The legacy minimap size corresponds to the interior, so the entrance requires its own physical span.

- 25 entrance-only creature IDs.
- 41 interior-only creature IDs.
- Stonevault Rockchewer 4851 legitimately exists in both contexts and is point-disambiguated.
- 14 entrance-only object IDs.
- 7 interior-only object IDs.
- Shared objects 1735, 2040, 126049, and 128293 are point-disambiguated.
- AreaTrigger 286 is entrance; 288, 822, and 882 are interior.

This is important for item-start presentation because a shared creature/object source cannot safely be assigned wholesale to one side.

### Maraudon — 2100

Current entrance/interior coordinates already match the current geometry except for one stale source relation.

- 32 entrance-only creature IDs.
- 42 current interior-only creature IDs.
- 7 entrance-only objects.
- 3 interior-only objects.
- Shared objects 2040, 2047, and 142144 are point-disambiguated.
- AreaTriggers 2267, 3133, and 3134 are entrance; 3126 and 3131 are interior.
- Creature 62755 (Selja) had a legacy map-2100 point but no current spawn inside either Maraudon rectangle. 1.08 removes only that stale map-2100 coordinate. This also removes quest 41896 (`Ursan Charm`) from Maraudon's compiled candidate bucket while preserving the quest/source elsewhere.

### Dire Maul — 2557

This was the most severe remaining case. It had both entrance/interior contamination and genuinely stale coordinate projection.

The old map-2557 coordinates were not merely dense: they were based on obsolete geometry. 1.08 rebuilds all current quest-relevant Dire Maul map-2557 sources from current server positions using the current WorldMapArea rectangles:

- 21 entrance-only creature IDs.
- 18 interior-only creature IDs.
- 12 entrance-only objects.
- 13 interior-only objects.
- Object 175404 legitimately exists in both contexts and is separated by its individual corrected coordinate.
- Final runtime map-2557 rebuild: 478 creature coordinates across 39 creature IDs and 53 object coordinates across 26 object IDs.
- Entrance AreaTriggers 3183, 3184, 3186, 3187, and 3189 were already current.
- Interior AreaTriggers 3193, 3506, 3507, 3508, and 3509 were stale and are rebuilt from current `AreaTrigger.dbc` positions.

### Timbermaw Hold — 5640

Timbermaw Hold is the raid-classified member of this failure class.

- The current runtime quest-relevant 5640 population consists of 24 interior creature IDs.
- Current server map 819 spawns for those IDs come from the July 2026 Timbermaw update.
- The legacy 5640 coordinates were badly mismatched to the current WorldMapArea and the legacy minimap dimensions were transposed/wrong.
- 1.08 rebuilds all 251 current map-5640 creature coordinates against the current 1425 × 962 interior geometry.
- The entrance context now stays empty of those interior quest sources rather than inheriting them through shared AreaTable ID 5640.

## Karazhan re-check

Karazhan was audited separately before this build. The existing dedicated 3457 Lower/Upper context split remains structurally correct and is intentionally not replaced by the new generic module.

Karazhan Crypt (5086) and Upper Karazhan 2F (5557) already use separate identities. Ambiguous 3457 sources, including the unresolved Pedestal Plaque 2020125 / quest 41395 case and conflicting creature evidence around 60063/60064, remain fail-closed rather than being guessed onto a floor.

## 1.08 implementation

`Map/SharedInstanceContext.lua` adds one generic presentation-time context layer for 718, 1337, 2100, 2557, and 5640. It uses:

- displayed World Map texture to distinguish entrance vs interior while browsing;
- physical server map ID to distinguish the minimap/player context;
- audited source identity for sources that exist on only one side;
- one-decimal point keys only for sources proven to exist in both contexts;
- current WorldMapArea width/height for minimap projection.

The database remains keyed by the stable numeric AreaTable IDs. There is no second world database, spatial bucket index, polling loop, or duplicated PreparedMap cache.

## Performance/correctness constraints preserved

1.08 adds no `OnUpdate`, timer, polling, ZoneBootstrap scan, delayed quest loading, or persistent spatial index. The context check happens only on maps already known to be one of the five shared IDs and reuses the existing World Map/minimap context lifecycle.

Gnomeregan 721 and Karazhan 3457 retain their accepted dedicated modules. All normal maps continue down the unchanged path.

## Build validation

- Compiled quests: 6,701.
- Runtime maps: 108.
- Runtime links: 8,674 (one fewer than 1.07 because stale Maraudon candidate 41896 is no longer linked to map 2100).
- Runtime DB validator: pass.
- Lua syntax parse: pass.
- Provenance checker: pass; ClassicAPI.dll absent.
- Focused SharedInstanceContext harness: entrance/interior texture identity, physical server-map identity, minimap sizes, source-only filtering, and shared-point filtering all pass.
