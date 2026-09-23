# Questie-Octo — skipped-chain introduction visibility audit

**Date:** 2026-09-23  
**Input baseline:** accepted 1.37  
**Output:** 1.38 (normal release; live character validation pending)

## Player report and scope

Players can skip introductory quests yet complete or accept a later step; the early questgiver no longer offers the introduction, but a Questie-Octo available marker remains. Version 1.37 corrected the two reported cases, quest 1339 → 1338 and quest 468 → 455. This audit extends the same *visibility-only* behavior to conservatively supported ordinary linear chains, including skipped intermediate steps. It does not claim to model all server-side offer conditions.

## Evidence and census

The supplied `tortoise-wow-main(20260913-143851).zip` SQL snapshot, table `tw_world_quest_template.sql`, has **5,989** parseable quest rows and **1,822** nonzero `NextQuestInChain` links. The actual shipped 1.37 runtime has **6,704** quest records. Each SQL link was compared with the SQL successor's `PrevQuestId`, the shipped successor's *single* `pre` requirement, and both ends' existing eligibility metadata. The SQL snapshot is historical evidence, not proof of live quest availability.

Only **1,487** links pass all checks: both reciprocal fields agree exactly, the successor has exactly one runtime prerequisite, both quests are ordinary (not daily/yearly/repeatable, event, or Hardcore), both are enabled and non-exclusive, SQL methods/conditions are normal, and race/class/level metadata does not conflict. The original two 1.37 breadcrumb links are separately audited exceptions because the SQL successor's `PrevQuestId` is zero; they remain explicit `nextChain` values and are *not* duplicated in the generated table.

| Classification | SQL links | Promoted? |
|---|---:|---|
| Strictly verified single chain | 1,487 | Yes, compact visibility projection |
| Branches/multiple runtime prerequisites | 124 | No |
| Event or Hardcore | 54 | No |
| Runtime exclusivity | 47 | No |
| No reciprocal SQL predecessor | 38 | No; includes two separately audited 1.37 exceptions |
| Repeatable/resettable | 32 | No |
| SQL exclusivity | 22 | No |
| Metadata disagreement | 7 | No |
| No reciprocal runtime prerequisite | 4 | No |
| Disabled quests | 2 | No |
| Nonstandard SQL method | 2 | No |
| Negative previous-quest relationship | 1 | No |
| Required SQL condition | 1 | No |
| Missing runtime or SQL successor | 1 | No |
| **Total** | **1,822** | **1,487 new + 2 existing explicit** |

All 1,822 links, including the **335 deferred** links, their original SQL titles, runtime prerequisite IDs, and exact exclusion reason are preserved in the **source-only** `Data/archive/quest_progression_audit_2026-09-23.json`. Rebuild the deterministic runtime mapping by supplying the *same* SQL file to `Tools/build_progression_projection.py`; the archive includes SHA-256 hashes of SQL and compiled quest data. This archive remains outside the TOC and is excluded from the GitHub/player ZIP. No earlier salvage archive is replaced.

## Runtime behavior

`Data/QuestProgression.lua` is a compact, generated source-ID → successor-ID map, not a replacement quest database. `Quest/Progression.lua` follows only those vetted edges plus preexisting explicit `nextChain` fields, using `Completion:HasBlockingStatus()` (rewarded history or current non-failed active Quest Log state). It stops at an unverified branch, a repeated ID, or depth 16. The longest generated path is 12 edges. `AvailableQuests:EvaluateQuest()` checks this only after ordinary active/completed suppression and before normal prerequisite/eligibility processing. The existing availability refresh/event flow then removes the now-unavailable pin on both World Map and minimap; no new scan or periodic poll is introduced.

Example: the vetted ordinary chain 12 → 13 → 14 (`The People's Militia`). When 14 is active/rewarded, 12 and 13 no longer appear as available even if neither was completed. If the player has not progressed, 12 remains visible when otherwise eligible. A branch such as 324/526 → 322 is **not** traversed, because the successor accepts alternative predecessors and a generic OR relationship is insufficient proof of an invalidated introduction.

**Crucial distinction:** this is only a computed visibility decision. The addon does **not** mark quest 12 or 13 completed, modify the character's completion cache, skip the actual server quest, or alter questgiver behavior. A newly observed repeatable source is not permanently hidden by an inferred ordinary chain link. The 1.37 direct per-quest completion-flag fallback is kept for authored `nextChain` fields only; doing 1,487 additional direct API lookups per availability scan would be a Vanilla-client performance regression. If bulk completion history and active Quest Log state both omit a successor, inferred-link suppression intentionally fails open until that evidence becomes available.

## Verification

- Offline projection: exact 1,822-link census; 1,487 promoted / 335 deferred; deterministic generated Lua and source-only archive; no cycles; longest generated path 12.
- `Tools/test_quest_progression.lua` exercises the actual compiled quest rows, actual Completion/Progression/AvailableQuests code, every generated link, transitive skips, active vs rewarded, fresh characters, branching, dynamically observed repeatables, existing 1.37 direct-flag fallback, no completion-history fabrication, and cycle guarding.
- Full source Lua syntax, every TOC path, `Tools/validate_runtime_db.lua`, clean compiler byte parity across all 16 generated runtime files, provenance, old salvage-archive hash parity, extracted ZIPs, and full/player common-file parity must pass before delivery. The quest database stays at 6,704 rows and the generated 16 runtime files must match 1.37 byte-for-byte.

**Not claimed:** confirmation against each questgiver on the live Turtle server, resolution of all 335 deferred edges, or restoration of completion flags missing from both available client sources. A live character who has bypassed several quests in a safe chain is the key final gameplay check.
