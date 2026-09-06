# Quest Log / Tracker Level-Plus Consistency Audit — 1.14

## Trigger

A live screenshot on accepted 1.13 showed **The Gnarled Bramblehide (41759)** correctly rendering `[31+]` in the World Map tooltip after the 1.13 RFK type correction, while the active Quest Log row and Questie-Octo tracker still rendered `[31]`.

## Root cause

The three surfaces were using different authority orders:

- World Map/minimap: native active Quest Log tag when present, otherwise compiled `questType` Type 1/62/81.
- Quest Log enhancement: native `GetQuestLogTitle().tag` only.
- Tracker: cached native Quest Log `state.tag` only.

Quest 41759 has an audited compiled Type 81 correction because the current Turtle metadata is stale, but the native active Quest Log tag remains absent. The map therefore had the `+` while the Quest Log and tracker did not.

## Fix

Added `QuestModel:HasLevelPlus(questID,nativeTag)` as the shared presentation fallback:

1. a non-empty native Quest Log tag wins;
2. otherwise the compiled quest model supplies `+` for Type 1 (Elite), 62 (Raid), or 81 (Dungeon).

The Quest Log enhancement and TrackerDriver now use that helper. Tracker rows carry a dedicated `levelPlus` presentation boolean instead of changing the preserved native `tag` field. This keeps native quest-state truth untouched while making `[level+]` consistent across UI surfaces.

## Scope / performance

No polling, `OnUpdate`, map scan, objective scan, database rebuild, or ZoneBootstrap change was introduced. The helper performs at most one cached QuestModel lookup per visible Quest Log/tracker quest when the native tag is absent.

## Regression targets

- 41759 The Gnarled Bramblehide: native tag missing + compiled Type 81 => `[31+]` in Quest Log and tracker.
- 41758 Tainted Brambleheart and 41555 Razorfen Grog: same fallback behavior.
- ordinary Type 0 quest with no native tag => no `+`.
- correctly native-tagged dungeon/elite/raid quest => still shows `+` without changing native tag semantics.
