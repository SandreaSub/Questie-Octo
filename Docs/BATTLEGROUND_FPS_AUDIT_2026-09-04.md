# Questie-Octo 1.0.98 — Battleground FPS Audit

Date: 2026-09-04
Baseline: accepted Questie-Octo 1.0.96
Scope: severe FPS drop reported on entering/leaving battlegrounds, with Warsong Gulch as the reproduction example.

## Evidence

The supplied pfDebug screenshot places `QuestieOctoSchedulerFrame:OnUpdate()` at the top of accumulated execution time and also shows `QuestieOctoMinimapUpdater:OnUpdate()` prominently. pfDebug attributes the runtime of functions invoked by an OnUpdate wrapper to that frame, so scheduler-owned queued jobs are included in the scheduler row. The displayed Time value is accumulated across executions, not a single frame.

The affected ZoneBootstrap code is unchanged between 1.0.95 and the accepted 1.0.96 color-vision build.

## Confirmed source defect

The compiled release contains an authoritative map candidate index generated from every packaged quest starter/source coordinate and independently checked by `Tools/validate_runtime_db.lua`. Warsong Gulch (map/AreaTable ID 3277) has minimap geometry but intentionally has no candidate bucket because no packaged available quest starts there.

`ZoneBootstrap:Start()` previously used the compiled candidate bucket only when `MapCandidateIndex:HasMap(mapID)` was true. When the map had no bucket, it fell back to `DatabaseAPI:GetQuestIDs()` and tested all 6,701 quests in 160-quest scheduler slices. On a first visit to Warsong Gulch this created roughly 42 priority-scan slices despite the compiled database already proving there were zero available-quest starter candidates.

This class affects other starter-less maps with minimap geometry as well; the packaged 1.0.95 data contains 18 minimap map IDs without a starter bucket, including Warsong Gulch (3277) and Arathi Basin (3358).

## 1.0.98 correction

When `MapCandidateIndex.compiled == true`, `ZoneBootstrap` now always consumes `MapCandidateIndex:Get(mapID)`. For a map absent from the compiled index this returns an empty array and is authoritative. The dynamic/development path retains the old all-quest fallback because its index can legitimately be incomplete while being built.

`AddActiveNodes()` still runs before candidate selection. Active quest objectives that genuinely have coordinates on a starter-less map therefore remain eligible for presentation. The correction skips only the impossible available-quest starter scan.

## Rejected broader changes

- Do not blanket-disable Questie-Octo minimap work in `pvp`/`arena` instances: battleground-local service or future objective markers could be useful, and this was not required to remove the confirmed scan.
- Do not change the 0.05-second nearby-pin movement path: the report did not demonstrate that normal position updates are the root cause.
- Do not alter `SetMapToCurrentZone()` event handling without evidence of a feedback loop.
- Do not mix the pre-existing scheduler temporary-table micro-optimization into this fix.

## Static regression

For the packaged compiled index:

- map 3277: old path = all 6,701 quests; new path = 0 available-quest candidates;
- map 3358: old path = all 6,701 quests; new path = 0 available-quest candidates;
- maps with compiled candidate buckets: old and new paths return the same pre-sorted quest ID arrays;
- development/non-compiled missing map: old and new paths both retain the full quest-ID fallback.

## Live acceptance test

1. Reload/login in a normal outdoor zone.
2. Enter Warsong Gulch and watch FPS during the transition and first seconds inside.
3. Leave Warsong Gulch and watch the return transition.
4. Repeat the same BG once more in the same session.
5. If using pfDebug, reset/rescan its Analyzer immediately before the transition and inspect both **Overall Execution Time** and **Average Execution Time** rather than comparing a long-session cumulative Time number.
6. Verify normal outdoor map/minimap quest markers still refresh after leaving the battleground.
7. If available, repeat in Arathi Basin.

## Version consolidation note

1.0.97 was a consumed test build created from 1.0.95 before 1.0.96 was live-validated. 1.0.98 is rebuilt from the accepted 1.0.96 baseline and carries forward the complete 1.0.96 color-vision accessibility feature unchanged while applying only this audited ZoneBootstrap correction.
