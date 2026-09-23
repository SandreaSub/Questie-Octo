# Questie-Octo — 1.36 through 1.41 systems re-audit

**Audit date:** 2026-09-23  
**Comparison anchor:** Questie-Octo 1.35  
**Packages inspected:** actual Full/source and GitHub/runtime ZIPs for every version 1.35 through 1.41  
**Corrective output:** Questie-Octo 1.42

## Executive result

The package history is clean, the 1.36 flight-master changes remain supported, and the 1.38 strict recursive progression projection remains sound. The wider systems audit did, however, find a real semantic defect in the optional/immediate `NextQuestInChain` work introduced from 1.37 through 1.41.

The earlier audits modeled only the **source-side** server rule: an earlier quest becomes unavailable when its immediate `NextQuestInChain` successor is active or complete. Tortoise also implements a distinct **target-side** rule: `ObjectMgr` adds every valid `NextQuestInChain` source to the successor's `prevChainQuests`, and `SatisfyQuestPrevChain()` blocks that successor only while any such source is a current quest.

For a chain relation that is not also a real `PrevQuestId`/`NextQuestId` prerequisite, this means:

- skipping the breadcrumb does **not** require completing it before taking the successor;
- accepting the breadcrumb temporarily blocks the successor while the breadcrumb is current;
- failing the breadcrumb does not block the successor;
- after the breadcrumb is rewarded/removed from the active log, it no longer blocks the successor.

Questie-Octo 1.41 had the first half of this relationship but not the second. Historical pfQuest `pre` data also treated many of these optional chain links as completion prerequisites, so Questie-Octo could hide valid successors after the breadcrumb was skipped.

Version 1.42 corrects this without changing quest completion history or the compiled quest database.

## Package history verification

Every Full/source ZIP and corresponding GitHub/runtime ZIP from 1.35 through 1.41 was freshly inspected.

| Version | Full files | Runtime files | TOC entries | Common-file parity | ZIP integrity |
|---|---:|---:|---:|---|---|
| 1.35 | 259 | 211 | 69 | byte-identical | PASS |
| 1.36 | 260 | 212 | 69 | byte-identical | PASS |
| 1.37 | 261 | 213 | 69 | byte-identical | PASS |
| 1.38 | 267 | 216 | 71 | byte-identical | PASS |
| 1.39 | 268 | 217 | 71 | byte-identical | PASS |
| 1.40 | 270 | 218 | 71 | byte-identical | PASS |
| 1.41 | 274 | 220 | 72 | byte-identical | PASS |

For every version:

- the archive has a single safe `Questie-Octo/` root;
- no unsafe traversal/absolute paths were found;
- every TOC path exists;
- the GitHub/runtime package contains no file absent from the Full/source package;
- every file shared by Full and GitHub/runtime is byte-identical;
- `ClassicAPI.dll` is not bundled.

## Version-by-version change scope

### 1.35 -> 1.36 — complete flight-master audit

Actual code/data delta:

- added `Docs/FLIGHT_MASTER_COMPLETE_AUDIT_2026-09-18.md`;
- changed `CHANGELOG.md`;
- changed source-only `Data/pfDB/overwrites-octo.lua`;
- changed compiled `Data/runtime/meta.lua`;
- changed TOC version.

Only two flight-service metadata decisions changed:

1. **62624 Treggi:** `AH` -> `H`.
2. **1233 Shaethis Darkoak:** removed from runtime flight-service tracking.

Fresh current-reference checks support both decisions:

- current client TaxiNodes.dbc node 89, **Slickwick Oil Rig, Tanaris**, has Horde mount `2224` and Alliance mount `0`, supporting Treggi as Horde-only;
- current Tortoise static creature snapshot contains no spawn for Treggi, matching the original audit's reason for relying on the directly colocated client taxi node;
- current Tortoise snapshot contains no static Shaethis spawn;
- current client taxi data contains no corresponding current Shaethis flight point;
- current Mudsprocket client node 94 and server node 180 remain Horde-only, preserving the earlier Razzit correction.

No unrelated service category or quest data changed in 1.36.

### 1.36 -> 1.37 — two hand-authored skipped-introduction fixes

1.37 added source-side progression suppression for:

- `468 -> 455`
- `1339 -> 1338`

The narrow source-side behavior is correct: if the immediate successor is active/rewarded, the obsolete introduction should no longer appear.

The semantic mistake was treating historical runtime `pre={source}` on the successor as proof of a real completion prerequisite. Current Tortoise SQL has no positive `PrevQuestId` or `NextQuestId` prerequisite for either relationship. The server uses `NextQuestInChain` to create an active-only reverse chain lock instead.

### 1.37 -> 1.38 — strict recursive progression projection

1.38 added:

- `Data/QuestProgression.lua`;
- `Quest/Progression.lua`;
- deterministic projection tooling/archive;
- regression harness;
- availability integration.

The **1,487 strict links remain valid**. They are not justified merely by `NextQuestInChain`: every promoted hop was restricted to a genuine reciprocal single positive completion prerequisite plus the other conservative filters.

Fresh regeneration against the current supplied Tortoise base snapshot still produces exactly:

- 5,989 SQL quest rows;
- 1,822 nonzero `NextQuestInChain` edges;
- 1,487 strict promoted links.

The generated strict table remains deterministic and its longest chain is 12 edges, below the runtime depth guard of 16.

A separate hardening in 1.42 ensures recursion can never enter a later authored optional `nextChain` edge. After an optional authored first hop, only strict generated links may be traversed recursively.

### 1.38 -> 1.39 — Darkshore optional introduction

1.39 added authored source-side suppression:

- `730 -> 729`

The source-side correction is still supported. The successor-side assumption was not: current Tortoise has no positive completion prerequisite from 730 to 729. Skipping 730 must not force completion of 730 before 729 can appear.

### 1.39 -> 1.40 — three additional authored introductions

1.40 added:

- `436 -> 297`
- `860 -> 844`
- `1132 -> 1133`

Again, the source-side suppression is correct. All three are chain-only from the server's perspective and therefore use active-only reverse blocking rather than completion prerequisites.

The clearest reproduced case is `436 -> 297`:

- source 436: `NextQuestInChain=297`, `NextQuestId=0`;
- target 297: `PrevQuestId=0`;
- historical runtime target data: `pre={436}`.

On a fresh/skipped state, Tortoise allows quest 297 because 436 is not current. Questie-Octo 1.41 instead rejected 297 as `prerequisite`. This was reproduced using the actual packaged 1.41 availability code/data.

### 1.40 -> 1.41 — 323 immediate-only source locks

1.41 correctly separated 323 complex but corroborated immediate links from the 1,487 strict recursive projection. That architectural split remains useful and is retained.

The 1.41 second-pass disposition also remains correct on the source side:

- 323 generated immediate-only relations;
- one already-authored relation (`7846 -> 7847`);
- two disabled relations retained as evidence only (`1288 -> 1289`, `60121 -> 60122`);
- two cross-source contradictions rejected (`1083 -> 1084`, `41388 -> 41389`);
- one missing-successor relation rejected (`40749 -> 40750`).

The missing piece was the server's reverse `prevChainQuests` behavior.

## Current Tortoise chain semantics

The supplied current Tortoise source establishes both directions directly.

### Source side

`Player::SatisfyQuestNextChain()`:

- reads only the immediate `NextQuestInChain`;
- blocks the source if that immediate successor is `COMPLETE` or `INCOMPLETE`;
- has a recursive further-chain call present but commented out.

### Target side

During quest loading, `ObjectMgr`:

- resolves each valid `NextQuestInChain` target;
- adds the source quest ID to the target's `prevChainQuests`.

`Player::SatisfyQuestPrevChain()` then:

- blocks the target if **any** `prevChainQuests` source is `IsCurrentQuest()`;
- uses `IsCurrentQuest()` semantics: incomplete or complete-but-unrewarded;
- does not treat a failed quest as current;
- also has recursive chaining commented out.

Both `CanSeeStartQuest()` and `CanTakeQuest()` call the normal previous-quest check, the source-side next-chain check, and the target-side previous-chain check.

## Complete current chain-only census

Reconstructing Tortoise's real previous-quest map from both `PrevQuestId` and `NextQuestId` gives this census for the 1,822 forward `NextQuestInChain` relations:

- **1,731** are also normal positive completion prerequisites;
- **90** have a valid successor but are **chain-only**, not completion prerequisites;
- **1** points to the missing quest 40750 and remains fail-closed.

All 90 valid chain-only relations are already represented by Questie-Octo's source-side progression system:

- 84 are in the 1.41 generated direct-only table;
- 6 are authored `nextChain` exceptions from 1.37/1.39/1.40.

The target-side data problem is exact:

- **86/90** chain-only source IDs appear in historical successor `pre` arrays and were therefore incorrectly treated as completion prerequisites;
- **4/90** do not appear in runtime `pre`, so Questie-Octo had no target-side block at all:
  - `6611 -> 6610`
  - `6612 -> 6610`
  - `6623 -> 6622`
  - `6625 -> 6624`
- the 90 relations affect **56 distinct successor quests**;
- removing only the chain-only IDs from each affected runtime `pre` set leaves **exactly** the positive previous-quest set reconstructed from current Tortoise SQL for all 56 successors;
- none of those 56 targets has a negative previous-quest relation in the current snapshot.

The full 90-record evidence matrix is preserved source-only in:

`Data/archive/quest_chain_availability_2026-09-23.json`

## Higher-risk false-positive examples

Most stale chain-only `pre` entries caused false negatives: a legitimate successor was hidden after its optional introduction was skipped.

Three targets also exposed a false-positive path because a chain-only source was mixed into an OR prerequisite list beside real server prerequisites:

### Quest 322 — Blessed Arm

Historical runtime:

`pre={324,526}`

Current server positive prerequisite:

`324`

Chain-only active blocker:

`526`

Rewarding/skipping 526 must not satisfy quest 322; if 526 is actively in the log, it temporarily blocks quest 322.

### Quest 8412 — Spirit Totem

Historical runtime:

`pre={8410,8411}`

Current server positive prerequisite:

`8410`

Chain-only active blocker:

`8411`

### Quest 40825 — The Key to Karazhan VI

Historical runtime:

`pre={40821,40824,41137}`

Current server positive prerequisites:

`40824`, `41137`

Chain-only active blocker:

`40821`

These cases make a broad "just remove prerequisite checks" fix unacceptable. The correction must remove only the chain-only completion interpretation while retaining real prerequisites.

## Why the 1.41 regression suite passed

The 1.41 harness was extensive but tested the wrong side of this relationship:

- it exhaustively tested source suppression for the 323 direct-only links;
- it verified that those links do not recurse;
- it tested active/rewarded/failed successor states;
- it explicitly asserted some historical successor `pre` entries as corroborating prerequisites.

It did **not** test successor availability after an optional source was skipped, nor did it model Tortoise `prevChainQuests`.

Therefore 23,897 passing assertions did not contradict the bug. The suite faithfully enforced the incomplete semantic model.

## 1.42 correction

### New generated runtime metadata

`Data/QuestChainAvailability.lua` contains the 90 chain-only reverse locks grouped by successor. It is generated from current Tortoise `NextQuestInChain`, `PrevQuestId`, and `NextQuestId` semantics and is separate from both progression tables.

The generator asserts:

- exactly 90 valid chain-only relations;
- exactly 56 affected successors;
- exactly 86 stale historical runtime `pre` relations;
- exactly four chain-only relations absent from runtime `pre`;
- the one missing successor remains `40749 -> 40750`;
- every valid chain-only relation already has source-side coverage;
- after subtracting chain-only IDs, each affected successor's effective runtime `pre` set exactly equals the server's positive previous-quest set.

### Availability behavior

For a chain-only relation `A -> B`:

- if A is not active/current, it is ignored as a completion prerequisite for B;
- if A is active and not failed, B is blocked;
- if A is failed, B is not blocked by the chain relation;
- historical/rewarded completion of A alone does not block B;
- any genuine positive predecessor of B still requires its normal rewarded completion.

The compiled runtime quest database is deliberately left unchanged. The semantic correction is applied at availability evaluation, preserving original source/reference data and making the distinction explicit.

### Recursive hardening

`HasProgressedPast()` now follows only strict generated links after the initial edge. A future authored optional breadcrumb encountered farther down a strict chain cannot accidentally become recursive inference.

## 1.42 regression coverage

The progression harness now contains **24,639 assertions** and adds target-side tests for the failure class that 1.41 omitted.

Coverage includes:

- all 1,487 strict links;
- all 323 direct-only source locks;
- all 90 chain-only target locks;
- all 56 affected successors;
- active / failed / rewarded predecessor states;
- all 86 stale runtime `pre` relations being treated as chain-only rather than completion prerequisites;
- all four relations absent from runtime `pre` still applying their active-only target lock;
- skipped `436 -> 297` end-to-end availability;
- active `436` blocking 297;
- `526` alone not satisfying quest 322 while real prerequisite 324 still does;
- active 526 blocking 322 even after 324 is rewarded;
- active 6611 blocking 6610 despite no historical runtime `pre` relation;
- strict recursion refusing to enter a synthetic descendant authored breadcrumb.

## Performance / state boundary

1.42 adds no polling, timer, `OnUpdate`, SavedVariables field, database scan, or per-quest completion API query.

The hot-path work is limited to:

- one table lookup for the evaluated successor;
- only for one of 56 affected successors, iterating its small chain-only predecessor set (maximum six in the current table);
- filtering small existing prerequisite arrays through the same generated lookup.

No skipped quest is marked complete and no server/Quest Log state is modified.

## Final disposition

The earlier conclusion that 1.41 was fully sound is **superseded** by this wider systems audit. The previous audits correctly established source-side suppression but did not model Tortoise's target-side `prevChainQuests` behavior.

- **1.36 flight-master work:** verified, retained.
- **1.37 authored source suppression:** retained; target-side semantics corrected by 1.42.
- **1.38 strict recursive projection:** verified, retained and recursion boundary hardened.
- **1.39 Darkshore source suppression:** retained; target-side semantics corrected by 1.42.
- **1.40 authored source suppressions:** retained; target-side semantics corrected by 1.42.
- **1.41 323 direct-only source locks:** retained; target-side semantics completed by 1.42.

Questie-Octo **1.42** is the corrective engineering baseline once its release validation passes. Live/in-game confirmation remains desirable for skipped/active optional-breadcrumb examples, but the correction is directly derived from the supplied server implementation rather than speculative quest-series inference.
