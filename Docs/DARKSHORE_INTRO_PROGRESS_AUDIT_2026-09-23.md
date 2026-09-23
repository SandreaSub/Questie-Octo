# Questie-Octo — Darkshore optional introduction, 1.39

**Baseline:** 1.38. **Scope:** quest 730 only. **Live outcome:** player confirmation still pending for 1.39.

## Report

After confirming the 1.38 fixes for 1339 and 468, a player reported that quest **730, Trouble In Darkshore?**, still appears as available after the NPC stops offering it.

## Evidence and why 1.38 excluded the link

- Supplied Turtle `sql/base/tw_world_quest_template.sql`, quest **730**, has `NextQuestInChain=729`; quest **729**, The Absent Minded Prospector, has `PrevQuestId=0`. Both have normal method, no required SQL condition, and ordinary non-repeatable metadata.
- The packaged runtime has quest **729** with a single `pre={730}` and quest 730 without `nextChain`; 730 is consequently absent from the generated 1,487-link progression projection.
- Turtle's indexed quest 730 page lists the 730 -> 729 series. Historical Wowhead comments describe 730 as an optional introduction and say it becomes unavailable after 729 is active or completed. These are supporting evidence, not an assertion that current live Turtle is identical in every detail.
- The player's observation independently supports the missing visibility condition.

The SQL successor's zero predecessor is **not** evidence against an optional breadcrumb: taking 729 without first completing 730 is exactly the case we need to account for. Changing 729's prerequisites to force 730, or importing all non-reciprocal relationships, would be unsafe.

## Narrow correction

Add only `nextChain=729` to the build-time quest 730 enrichment and recompile `Data/runtime/quests.lua`. The existing 1.38 `Progression:HasProgressedPast` service hides 730 when 729 is active or rewarded, including a cached direct ordinary-completion-flag fallback if bulk history omitted 729. Leave 729's existing source prerequisite untouched. Do not mark 730 completed or change questgiver mechanics. No polling, new event loop, or scanning.

The source-only progression audit remains a **historical 1.38 audit**: it correctly classified 730 -> 729 as `no_reciprocal_sql_previous` when generated. No regeneration or silent reclassification of its original evidence. The 38 such records included the two 1.37 corrections and now this one 1.39 exception; the other 35 have not been individually confirmed and remain deferred.

## Required regression coverage

A fresh character sees 730; active/rewarded 729 suppresses 730; stale bulk completion history is repaired only for 729; unrelated completion and failed 729 do not hide 730; a skipped 730 is never marked complete. Preserve the other 1,487 audited links, both 1.37 exceptions, the previous seven source-only archives, and existing player packaging exclusions. Confirm with a live character before claiming the reported marker is resolved in game.
