# Turtle database salvage — Phase 8 (Questie-Octo 1.34)

**Basis:** Questie-Octo 1.33, the six unchanged Phase 2–7 reference archives, and three individually rechecked *indexed* Turtle database quest pages on 2026-09-16. Indexed pages were crawled months earlier and **are not live-server exports**. The public database root returned HTTP 502 for direct requests during this pass; the indexed results supplied the three item/name/quantity associations below.

## Narrow in-game change: display-only objective quantities

Only the following existing `quest ID → existing objective item ID → required count` relationships were added to `Data/QuestObjectiveRequirements.lua`:

| Quest | Existing item ID | Website/archived item name | Amount | Indexed source |
|---|---:|---|---:|---|
| 41913 Draenei Divination | 42134 | Arcane Bark | 10 | https://database.turtlecraft.gg/?quest=41913 |
| 41913 Draenei Divination | 42135 | Highborne Fragment | 6 | Same quest page |
| 41913 Draenei Divination | 8831 | Purple Lotus | 12 | Same quest page |
| 41935 Rite of Resurrection | 42179 | Blue Dragon Essence | 10 | https://database.turtlecraft.gg/?quest=41935 |
| 42003 The Silver Blade | 12662 | Demonic Rune | 30 | https://database.turtlecraft.gg/?quest=42003 |

The existing compiled quest objective sets contain those exact item IDs, and the existing runtime locale maps each ID to the corresponding name. The addition has **three quests and five item/count pairs**. Do not infer quantities for separate items: Rite of Resurrection (42178), Nail of a Dreadlord (42296), and Raw Draenethyst Formation (42001) have **no new count entries**. Existing requirements remain untouched.

`Database/QuestModel.lua` attaches these static quantities to `objectiveData` only for matching item identities. Active quests continue to prefer live Quest Log counters in the relevant tooltip paths. No quest template, objective identity, item source, drop rate, reward, map marker, color, eligibility, repeatability, script or runtime compiler code is changed. These are display corrections based on cached/indexed evidence, **not** a claim of current in-game confirmation.

## Offline provenance lookup: source-only

Added `Tools/build_salvage_index.py`, which deterministically builds `Data/archive/quest_salvage_provenance_index_2026-09-16.json` from the original six archives. It indexes:

- 127 existing quest-starting items and their classified snapshot/historical acquisition evidence (original source data stays in the archives);
- 14 upstream container parent items **separately** from their child quest-starting items;
- 39 cached website observation records concerning 36 unique quests;
- five additional **snapshot-only** quest records that were never promoted into the game.

Each relationship links to the original JSON archive and an exact, validated JSON pointer; original source archive SHA-256 hashes are recorded. The index is **not** a newly verified gameplay database, does not assign source rates, and cannot turn a parent-container drop into a direct child-item drop. Items 17115 and 17116 remain unproven.

Both the index JSON and its Python generator are **full/source-only**; they must not enter the player ZIP, TOC, compiler, or runtime. All six original phase archives remain byte-for-byte unchanged.

## Not promoted

- The eleven Phase 7 weapon-mastery book reward pairs are preserved with their older SQL provenance. Without current numeric reward IDs confirmed in contemporary source or in-game reward panels, none were added to `QuestRewards.lua`.
- The other 17 website-derived objective-count candidates have not been silently imported. The three chosen quests were rechecked individually; further quests need their own identity/quantity verification.
- Five snapshot-only quests, Squirrel Tokens, historical relic drop rates, Saving the Shadowtooth (41095), and unresolved Karazhan identities remain unchanged/fail-closed.

## Release verification gates

Test that all five changed `objectiveData.required` values resolve for their exact quest/item IDs, old counts remain identical, unrelated items have no invented quantities, and the index is repeatable with resolvable provenance pointers. All 16 compiled runtime files, quest IDs, maps, rewards, objective identities and prior six archives must match 1.33 byte-for-byte. Check all Lua syntax, TOC paths, runtime validator, clean source recompilation, provenance, archive integrity, source/player parity, and source-only exclusion before promoting 1.34.
