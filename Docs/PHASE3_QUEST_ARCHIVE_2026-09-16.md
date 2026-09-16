# Questie-Octo salvage audit — phase 3 (archive only)

**Baseline:** 1.28. **Result:** source-only reference archive; no new in-game quest or gameplay edits.

## Recoveries

- Archived **127** already-present quest-start items that have no direct creature/object source in the compiled addon. The supplied server SQL preserves **74 item-container loot rows for 72 items**, including exact container IDs and the source snapshot's loot fields. The remaining **55 items** are explicitly unresolved. This is not evidence that 127 map markers are missing; a contained quest item must not be reinterpreted as a creature drop.
- Preserved **16** additional starter/finisher relation rows (2 creature starters, 2 creature finishers, 6 gameobject starters, 6 gameobject finishers) attached to the *five* server-only quests already archived in phase 2. The five quests remain absent from the runtime.
- Archived **17 indexed public database quest-page observations**, including XP, max-level money, some explicit reputation gains, counted objectives, prerequisite/follow-up names, and reward presentation where the page distinguishes a choice from a fixed or spell reward. **15 are among the 720 quests already present in Questie-Octo but absent from the supplied SQL snapshot; 2 are SQL-shared corroboration.** No reward rows were promoted. The prior three website observations remain intact in the phase-2 archive.

## Provenance and uncertainty

`Data/archive/quest_salvage_phase3_2026-09-16.json` stores SHA-256 hashes of the relevant original SQL table files, the addon locale file used for name-to-ID cross-reference, an exact website URL on each indexed observation, and separate confidence/unknown fields. Website pages are indexed copies, not proof of current live-server conditions. A local item name matching an observed website reward is **only a candidate ID**, not a verified numeric website reward ID. `RewMoneyMaxLevel` is retained as max-level conversion money, never ordinary quest money. Missing page fields are left absent, not filled in from assumptions.

Full website roster enumeration still cannot be claimed: listing data was not accessible as a complete table in this environment. The earlier archive's 720-ID reference list is not a list of quests to hide or re-import.

## Safety contract

The archive is under `Data/archive/`, which is not referenced from the TOC or compiler, and is excluded from GitHub/runtime packaging. The release changes only the source-only JSON, this report, version metadata and engineering changelog. Compile-time quest data, rewards, map candidates and all other game-loaded files must remain byte-identical to 1.28.
