# Phase 2 quest archive — source-only, not game content

This archive responds to the request to **retain questionable database quests without showing them in game**. The archival JSON lives at `Data/archive/quest_salvage_phase2_2026-09-16.json` in the **full/source** package, and is deliberately omitted from the GitHub/runtime build.

- **Five** server-snapshot quest rows that Questie-Octo 1.27 did not contain are preserved with all 129 columns from the supplied SQL: `960`, `39980`, `39981`, `50215`, `50220`. Their current live availability is unverified; no NPC, object, item or map marker is created.
- **720** quests were already in Questie-Octo 1.27 but missing from the supplied server snapshot. The archive records their IDs as an *audit roster*, not as new or newly hidden quests. They retain their existing runtime behavior; absence from an older snapshot is not a basis for disabling them.
- **Three** website-reported reward examples (42029, 42036, 41774) are preserved as explicitly unverified evidence only. No unknown reward item IDs, choice/guaranteed groupings, or rates are fabricated, and no entries are inserted into `Data/QuestRewards.lua`.

## Separation contract

`Data/archive/` is not referenced by `Questie-Octo.toc`, `Data/init` or `Tools/compile_runtime_db.lua`; the compiler's source inputs and generated `Data/runtime/*` are unchanged. Archive records cannot be read by the addon or populate Quest Browser, quest candidate indexes, map pins or minimap pins. No SavedVariables and no live-game rules are changed.

Source provenance: `tortoise-wow-main(20260913-143851).zip`, `sql/base/tw_world_quest_template.sql` (SQL member SHA-256 in JSON), existing 1.27 quest roster, and the indexed website observations documented in `QUESTIE_OCTO_PHASE2_SALVAGE_AUDIT_2026-09-16.md` supplied with the audit.

**Future promotions require current/live corroboration**, especially for older, system, deprecated, or special-type quests. Do not promote archive contents by a bulk database merge.
