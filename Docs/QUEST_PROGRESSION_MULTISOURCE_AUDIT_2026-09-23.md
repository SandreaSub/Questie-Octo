# Questie-Octo — Multi-source quest progression audit (1.40)

**Date:** 2026-09-23  
**Input:** accepted Questie-Octo 1.39  
**Output:** three narrowly authored optional-introduction links; historical 1.38 projection unchanged.  
**Live-server confirmation:** not yet available for these three new cases.

## Scope and sources actually checked

Every one of the **1,822** forward links from the previous 1.38 source-only progression archive was compared by exact quest ID with:

- Questie-Octo 1.39's compiled quest records and availability/completion/progression implementation;
- the supplied Turtle server `sql/base/tw_world_quest_template.sql`, its original 1.38 exclusion classification, and relevant `sql/database_updates` statements;
- Questie **5.2.3** and **6.0.0** `Database/questDB.lua` (forward `nextQuestInChain`, reverse `preQuestSingle`, and exclusivity);
- the supplied pfQuest ClassicAPI `db/quests.lua` and pfQuest Turtle `db/quests-turtle.lua` (reverse prerequisite and exclusion metadata);
- individual indexed Turtle database, Classic-era, and historical quest-series pages where retrievable, including the three promoted examples.

The JSON `Data/archive/quest_progression_multisource_2026-09-23.json` contains the complete 1,822-edge per-source evidence matrix and input-file SHA-256 provenance. It is **source-only**: not in the TOC, never compiled, and excluded from the player ZIP. The original 1.38 archive is preserved byte-for-byte with its original classifications.

**What this is not:** We did not inspect all 1,822 public quest pages, verify every NPC on the live server, or pretend that two closely related Questie database versions are independent live confirmations. pfQuest, Questie and Turtle data can share historical provenance. A quest series establishes ordering but, by itself, does not prove that the server withdraws a skipped introduction. `NextQuestInChain` plus eligibility metadata supplies the relevant additional evidence; live tests remain necessary.

## Audit census

| Original classification | Edges | Treatment |
|---|---:|---|
| Strict reciprocal, ordinary single chain | 1,487 | Keep existing generated projection; no changes |
| Branches/multiple prerequisites | 124 | Deferred: path-specific validity cannot be inferred |
| Event/Hardcore | 54 | Deferred |
| Runtime exclusivity | 47 | Deferred pending path-specific checks |
| SQL successor `PrevQuestId` absent/zero | 38 | Three previously authored, three newly corroborated, **32 still deferred** |
| Repeatable/resettable | 32 | Deferred |
| SQL exclusive group | 22 | Deferred |
| Metadata disagreement | 7 | Deferred |
| No reciprocal runtime prerequisite | 4 | Deferred |
| Disabled quest | 2 | Deferred |
| Nonstandard SQL method | 2 | Deferred |
| Negative predecessor | 1 | Deferred |
| Required SQL condition | 1 | Deferred |
| Missing runtime/server successor | 1 | Deferred |
| **Total** | **1,822** | **1,487 generated + 6 authored optional + 329 deferred** |

Cross-source coverage, not a claim of independent proof: **1,128** of the 1,487 existing generated edges have both quests in the historical Questie versions; **1,107** of these have matching Questie forward links. The others include absent `nextQuestInChain` values and two noteworthy historically swapped druid links, 26→29 and 27→28, which current Turtle SQL/Questie-Octo represent differently from historical Questie. Keep the current server/runtime agreement rather than applying a historical reversal. The available public Turtle page for quest 27 confirms the Tauren druid context, but does not expose sufficiently reliable IDs for an exhaustive live-path verification.

For the 38 nonreciprocal SQL-predecessor edges, Questie 5.2.3 and 6.0.0 both contain the relevant quests for 30 pairs and explicitly point forward for 29; pfQuest ClassicAPI contains both for 31 and preserves a reciprocal prerequisite for all 31; pfQuest Turtle preserves one for 32 of 37 represented pairs. These facts help locate candidate breadcrumbs but do not independently establish every current offer lock. Questie 5.2.3 and 6.0.0 share ancestry.

The server archive also contains **108** `sql/database_updates/*.sql` files. Among the **8,885** `quest_template` UPDATE statements, the parser could attribute **8,472** to a single numeric `entry`; the remaining **413** have non-simple where clauses or other formats and **none sets a forward, previous or exclusive quest-chain field in its first statement**. The **1,715** parseable unconditional chain-update rows match the corresponding fields already present in the supplied base snapshot, so they do not change the archived 1,822 forward edges. Later conditional predecessor updates cannot be assumed to have applied to absent or differently versioned rows. This is a statement-level check, not a live database migration replay.

## Three separately corroborated optional introductions

| Introduction | Later quest | Why this narrowly qualifies |
|---|---|---|
| **436** Ironband's Excavation | **297** Gathering Idols | Turtle snapshot `NextQuestInChain=297`; current runtime 297 has sole prerequisite 436; both historical Questie versions have 436→297; both pfQuest variants preserve the reverse prerequisite; Classic-era source explicitly calls 436 a breadcrumb for 297. [ClassicDB quest 436](https://classicdb.ch/?quest=436). |
| **860** Sergra Darkthorn | **844** Plainstrider Menace | Turtle snapshot and its database-update row preserve 860→844; current runtime 844 has sole prerequisite 860; Questie 5/6 and pfQuest agree on their relationship; indexed [Turtle quest series](https://database.turtlecraft.gg/?quest=882) lists those steps consecutively. |
| **1132** Fiora Longears | **1133** Journey to Astranaar | Turtle snapshot 1132→1133 and zero optional successor `PrevQuestId`; current runtime has sole prerequisite 1132 on 1133; both Questie versions and pfQuest agree; [Turtle quest 1132](https://database.turtlecraft.gg/?quest=1132) lists the series. |

These three use the **existing** narrow authored `nextChain` mechanism, exactly as the player-confirmed 1.37 links and the 1.39 Darkshore case do. If the later quest is active or rewarded, hide the old **available marker**; if completion history is missing, the existing cached ordinary-successor direct flag is permitted. If the successor has failed, is not known or the character has not progressed, the introduction remains visible. An earlier skipped quest is never marked completed. No prerequisites, quest-givers, NPCs, items, map data, or resettable quest flags change.

## Why the rest were not imported

- **Branch/OR paths (124):** A shared follow-up or an alternate route is not enough to prove that every predecessor stops being offered. Existing 324/526→322 is an explicit regression guard.
- **Other optional/nonreciprocal paths (32 still open):** The graph agrees in some historical sources, but the current server's availability lock, progression alternatives, or custom behavior have not been individually established. Examples 1036→4621 and 1483→1093 lack a reciprocal prerequisite in the supplied Turtle pfQuest data; the custom 39994–39999 chain is absent from older Questie datasets.
- **Events/Hardcore, repeatable, exclusivity, metadata conflict and missing records:** These need individual stateful rules. A general forward walk would risk hiding legitimately repeatable or alternative quests.
- **Existing 1,487 edges:** Their original two-field SQL and current-runtime checks remain valid against the supplied snapshot. The historical references expose discrepancies, not sufficient grounds to replace current Turtle server relationships wholesale. No live-per-quest validation is claimed.

## Runtime and release boundaries

Changed only three authored `nextChain` fields in `Data/pfDB/enrichment.lua` and compiler-generated `Data/runtime/quests.lua`, plus version/changelog, targeted regression tests, this audit and its **source-only** JSON. The existing 1,487-link `Data/QuestProgression.lua` and all eight previous source-only archive JSONs must remain byte-identical to 1.39. No generic inference, permanent polling, new `OnUpdate`, SavedVariables changes or direct-flag query for the 1,487 projected links.

Regression harness checks fresh/eligible characters, active/rewarded/failed later quests, incomplete bulk completion, unrelated completions, both factions and no fictitious completion; source/runtime compilation and package parity are required. In-game tests for all three new links remain the final confirmation.
