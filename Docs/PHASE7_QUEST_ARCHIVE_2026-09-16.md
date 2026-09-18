# Questie-Octo — Phase 7 salvage audit (reference archive only)

**Baseline:** 1.32. **Gameplay and compiled runtime:** deliberately unchanged. This phase checks the *historical SQL update directory*, not just the supplied server `sql/base` snapshot.

## Eleven weapon-mastery books: preceding-quest rewards

The historical `20260507165648_world.sql` quest-template records show a consistent two-step handoff. A mastery quest consumes item **70226** and grants its particular book as a **fixed `RewItemId1` reward** (quantity one). The following quest requires that same book as `ReqItemId1` (quantity one). These are **not direct creature drops** and should not be changed into map drop pins.

| Book item | Mastery reward quest | Follow-up requiring book |
|---|---:|---:|
| Mastery of Axes (70227) | 41542 | 41543 |
| Mastery of Swords (70228) | 41536 | 41537 |
| Mastery of Hammers (70229) | 41539 | 41540 |
| Mastery of Fist Weapons (70230) | 41545 | 41546 |
| Mastery of Polearms (70231) | 41533 | 41534 |
| Mastery of Staves (70232) | 41518 | 41519 |
| Mastery of Thrown (70233) | 41521 | 41522 |
| Mastery of Bows (70234) | 41530 | 41531 |
| Mastery of Crossbows (70235) | 41527 | 41528 |
| Mastery of Daggers (70236) | 41548 | 41549 |
| Mastery of Guns (70238) | 41524 | 41525 |

The full historical rows for both steps of each pair (22 quest rows) are archived with original SQL tuples and named fields. This also explains why an item can be linked as a starter in the add-on even though its own historical `item_template.start_quest` is zero: the later quest uses a `ReqItemId`, while the add-on retains an item-based quest navigation association. The snapshot does not establish live-server item acquisition or justify changing the existing in-game association.

## Two missing item definitions and a historical loot reference

The `sql/base` snapshot lacks item-template definitions for **41799** and **41802**. An earlier historical update, `20260505222630_world.sql`, contains both exact item records with the name **Damaged Relic Mechanism**. The `20260507165648_world.sql` quest records require 41799 for **quest 41732**, and 41802 for **quest 41734**.

A separate historical `REPLACE INTO creature_loot_template` statement in `20260511053220_world.sql` contains a row for each item under **loot entry 62252**, with `ChanceOrQuestChance = 4` and min/max count 1. Questie-Octo already identifies NPC **62252** as Shadowforge Appraiser, but the supplied `sql/base` creature-template snapshot does not contain that entry. The archive retains the two complete historical item rows, their two related historical quest rows, and the two exact loot tuples.

**Important ID-collision trap:** historical quest IDs **41799** and **41802** also exist but describe entirely different quests; those numbers must not be confused with item IDs 41799/41802. The item-to-quest links here are **41799 → 41732** and **41802 → 41734**.

The historical `4` field must **not** be promoted to a current drop rate: a newer base snapshot does not contain these same source relationships, and no live Octo evidence was supplied. The two missing item records are therefore *archived only*, not reintroduced into runtime or guessed into a drop map.

## What remains unknown

Of the 15 previously unresolved starting-item origins, **13 now have additional historical snapshot provenance** (11 quest reward handoffs and two historical creature-loot references). **Two Squirrel Tokens (17115, 17116)** still lack an established acquisition path. Neither absence nor the preserved older SQL proves anything about current availability.

## Archive contents and reproducibility

- `Data/archive/quest_salvage_phase7_2026-09-16.json` stores 22 full historical mastery quest rows, two historic relic item rows, two relic-quest rows, two creature-loot rows, exact original SQL tuples, line numbers, per-file SHA-256 fingerprints, and hashes of the untouched earlier archives.
- Historical update provenance is labelled separately from the base snapshot and from independently verified live gameplay.
- It is excluded from the TOC and compiler; the GitHub/player ZIP excludes all six archive JSONs plus the established 40 development DB inputs. The documentation is harmless reference material.
- No quest record, reward, world marker, source list, runtime file, or gameplay code is promoted or changed in this phase.
