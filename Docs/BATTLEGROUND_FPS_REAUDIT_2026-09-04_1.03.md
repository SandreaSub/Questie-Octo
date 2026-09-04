# Questie-Octo 1.03 — Battleground FPS Re-audit

Date: 2026-09-04
Baseline: accepted Questie-Octo 1.02
Trigger: player reports that Arathi Basin still reproduces the battleground FPS problem after the 1.0.98 candidate-index correction.

## Finding

Arathi Basin was not omitted from 1.0.98. The compiled release path is generic: `MapCandidateIndex:Get(mapID)` returns an authoritative empty array for every absent bucket. Arathi Basin area 3358 has no compiled candidate bucket, just like Warsong Gulch 3277. Therefore the persistent AB report demonstrates that the earlier diagnosis removed one major source of work (the 6,701-quest fallback) but did not remove all empty-map work.

## Current battleground identities checked

Current supplied server/client references expose: Alterac Valley (server map 30, WorldMapArea/area 2597), Warsong Gulch (489 / 3277), Arathi Basin (529 / 3358), Blood Ring (26 / 4014), and Sunnyglade Valley (27 / 5023). The current compiled candidate index contains 77 starter candidates for Alterac Valley, 2 for Sunnyglade, and no bucket for WSG/AB/Blood Ring. WSG/AB sub-area IDs likewise have no candidate buckets.

## Remaining empty-map work in 1.02

Even after an empty compiled candidate list was selected, ZoneBootstrap still enqueued one `zone-priority-scan` continuation merely to publish an empty prepared plan. More importantly, once that empty plan was installed, `QuestieOctoMinimapUpdater` continued its 0.05-second update path. It still read player position and evaluated minimap geometry/discovery despite having zero descriptors to position. Zone settlement also called `SetMapToCurrentZone()` and could run the Vanilla indoor-state zoom probe even when Questie-Octo had no minimap pins to draw.

These paths cannot provide useful presentation on an empty plan and are therefore unnecessary work, especially visible during battleground transitions where starter-less maps are common.

## 1.03 correction

1. Compiled empty candidate + zero active local nodes now publishes `{}` plans immediately, without a scheduler continuation.
2. Minimap records whether either current prepared plan contains descriptors. With no descriptors, the 20 Hz position/discovery work returns immediately.
3. Native map-context retargeting and active indoor/zoom probing are deferred until a plan actually contains something that needs positioning.
4. A later real marker publication wakes the existing fast path immediately; battleground objective/service support is not blanket-disabled.
5. The low-frequency map identity safety check remains, so unusual physical-map transitions can still recover.

## Explicit non-changes

- No reduction to ZoneBootstrap's 400 indexed-candidate batch.
- No slower quest icon appearance.
- No QuestBeacon-style spatial buckets or additional persistent minimap indexes.
- No hardcoded WSG/AB-only suppression.
- No database or candidate-index data change.
