# Turtle database salvage audit — 2026-09-13

## Scope

Systematic salvage audit requested by the 1.25 handoff. The website is treated as a secondary salvage source, not as an authority to bulk-import. Current live evidence remains highest priority, followed by current server SQL/scripts, current client DBFiles/geometry, and already-audited Questie-Octo data.

Inputs used in this pass:

- Questie-Octo 1.25 accepted source/runtime baseline.
- Current supplied Tortoise/Turtle server snapshot: SHA-256 `ed3b3638f26733d30993e0d2a1fac1e31a0738d5f66bd11a23c52509f7d47ee9`.
- Current supplied DBFilesClient reference: SHA-256 `5ea0f15b14803b20848f4063f9af4a98bf8088a76a0eb1bd1eb780b56682bd05`.
- Current Turtle database/indexed quest pages and Turtle forum chain references where retrievable.
- Questie 5.2.3/6.0.0 and pfQuest-family uploads remain comparison references only; they were not promoted over current Turtle evidence.

## What the Turtle database is useful for

Indexed quest pages expose useful salvage fields including quest/required level, side/race/class masks, formal start/end entities, objective identity/count, reward data, and chain hints such as required/open quests. Coordinates are less dependable in text/indexed access and must still be corroborated against current client/server geometry.

## Broad comparison results

The current server snapshot contains 5,989 `quest_template` rows versus 6,701 Questie-Octo 1.25 runtime quest rows. Eight ordinary-sized current server quest IDs were absent from 1.25. They are not one homogeneous class and therefore must not be bulk-added:

- `960` — internal/unused-looking row without usable starter/finisher/objective relations.
- `39980`, `39981` — dynamic PvP/system quests; unsuitable for a static automatic import.
- `40273` **In Search of the Owner** — accepted after the second pass recovered both current static endpoints; repaired for 1.26.
- `40915`, `40916` — real missing Hardcore chain steps; accepted and repaired for 1.26.
- `50215`, `50220` — Type 82/internal exchange-style rows without normal starter/finisher relations; not imported as ordinary quests.

The resulting 1.26 runtime contains 6,704 quest IDs. No static import was made for the dynamic/internal rows above.

Direct field differences (level/min-level/type/race/class/skill) were inventoried but not bulk-applied. Questie-Octo deliberately carries audited corrections where current server metadata is known to be presentation-inaccurate, particularly dungeon/elite quest type data.

## Starter / finisher relation audit

Most formal current-server relations that appear missing from Questie-Octo belong to quests already marked `[Deprecated]`, `[DEPRECATED]`, or `[CANCELLED]`. Restoring those relations would resurrect obsolete map markers, so they remain suppressed.

The remaining prominent non-deprecated differences are navigation substitutions rather than stale relations:

- The Azshara Way-Stone chain uses locatable Way-Stone objects for route guidance even where the formal server relation points to Keeper Laena.
- The Kheyna Spinpistol summon chain uses locatable crystal/interact objects where the formal summoned NPC has no useful static coordinate.

These proxies are intentionally preserved. Formal database ownership is not automatically the best map-guidance entity.


## Accepted 1.26 correction: In Search of the Owner

Quest `40273` **In Search of the Owner** is a current Alliance quest that post-dates the packaged Turtle extraction. The current server snapshot provides all pieces needed for a non-speculative map repair:

- `quest_template`: level 1 / minimum 1, race mask 589, source/required item 60349 **Uncommon Journal**;
- `gameobject_questrelation`: object `2010854` starts quest 40273;
- `creature_involvedrelation`: creature `60517` **Roheg Clay** finishes quest 40273;
- current gameobject spawn: object 2010854 on server map 0 at world `(-921.462, -541.461)`, which exactly matches Questie-Octo's already-packaged Hillsbrad coordinate `50.3, 61.9` on AreaTable 267;
- current creature spawn: Roheg Clay on server map 0 at world `(-8877.39, 671.785)`. Using the supplied client's current Stormwind WorldMapArea bounds converts this to `52.76, 66.77`, stored as `52.8, 66.8` on AreaTable 1519.

1.26 therefore adds only the missing quest record and Roheg Clay unit record. It reuses the already-present Uncommon Journal object geometry and does not invent any position.

## Accepted 1.26 correction: Hardcore mystery chain

Current server quest data and current relation tables prove this progression:

`40914 -> 40915 -> 40916 -> 40917 -> 40918 -> 40919 -> 40920 -> 40921 -> 40922 -> 40923`

Questie-Octo 1.25 omitted 40915/40916. Its inherited 40917 prerequisite pointed forward to 40922, while enrichment also added 40921 to 40922 and 40922 to 40923. That produced a stale prerequisite loop instead of a traversable chain.

1.26 therefore:

- adds `40915` **A Mysterious Errand**: Mysterious Mailbox -> Marin Noggenfogger;
- adds `40916` **The 52nd Package**: Marin Noggenfogger -> Mysterious Mailbox, requiring item 61458;
- corrects 40917 to require 40916;
- corrects 40922 to require 40921;
- corrects 40923 to require 40922;
- removes the obsolete enrichment prerequisite additions that previously compounded the bad chain;
- adds Hardcore and Type 62 metadata for 40915/40916;
- adds the authoritative 1x requirement for item 61458;
- syncs the audited 40915-40923 English quest text to the current server rows.

Item 61458 already exists in source data and is a 100% quest source from Princess Theradras (12201), whose current Questie-Octo coordinates are on Maraudon AreaTable 2100. No invented spawn geometry is needed.

The restored 40916 objective color is materialized in the static palette. Its five final 8-bit mode colors were checked against the currently resolvable Maraudon objective-color set; the minimum CIEDE2000 distance remains above the locked 2.3 floor in Default, Red-deficient, Green-deficient, Blue-deficient, and High Contrast modes.

## Objective requirements

For objective entities already shared by the current server projection and Questie-Octo's existing objective identities, no required-count disagreements were found in this audit. Large naive objective-ID/item-ID diffs are mostly expected because Questie-Octo intentionally suppresses delivery/source items or substitutes scripted/actionable targets. They are not safe bulk-import candidates.

## Karazhan

This pass did not produce stronger evidence for Pedestal Plaque 2020125 / quest 41395 floor ownership or for creatures 60063/60064. The existing fail-closed Karazhan decision remains unchanged.

## Direct metadata discrepancy classification

After compiling the accepted salvage records, a direct comparison of fields shared by current server `quest_template` and the 1.26 runtime leaves a small set of disagreements: 4 quest-level rows, 15 minimum-level rows, 16 race-mask rows, 2 class-mask rows, 6 profession-skill rows, and 25 quest-type rows. These were reviewed as discrepancy classes instead of being copied wholesale.

### Website/database confirms Questie-Octo over the current base SQL

Examples recovered from the current Turtle/Octo database include:

- `9260` **Investigate the Scourge of Stormwind** — current Octo database lists level 6 / requires 1, matching Questie-Octo rather than the base SQL level 10.
- `40642` **Lighting the Oilmaster** — current Octo database lists level 28 / requires 20, matching Questie-Octo rather than base SQL level 23.
- `80301` **Lighting the Pyres** — Turtle database lists level 10 / requires 10, matching Questie-Octo rather than base SQL level 60.
- `40078` **The Murloc Menace** — Turtle database lists minimum level 35, matching Questie-Octo rather than base SQL minimum 40.
- `80383` **Sharks Are Friends, Not Food** — Turtle database lists level/minimum 35, matching Questie-Octo rather than base SQL minimum 1.
- Mirage Raceway quests `50311`/`50313` are currently listed as level 60 / requires 28, supporting the Questie-Octo minimum-level projection over base SQL minimum 1.
- `8292`/`8293` **Marks of Honor** are currently listed as requires level 1, supporting the Questie-Octo value over base SQL minimum 10.
- `41338` **Mount Hyjal In Turmoil** is currently listed as all races / Druid only (race 0, class 1024), confirming the Questie-Octo interpretation and exposing the base SQL's race/class-field inconsistency. Current pages for the following chain steps likewise show all races where the base rows contain race mask 1024.
- `41378` **Blood of Vorgendor** and `41381` **The Wolf, the Crone and the Scythe** are currently Type 62; `41385` **Gilnean Pricolich** is currently Type 81. These match Questie-Octo's audited type projection rather than the Type 0 base rows.

### Audited overrides retained

Several remaining type/mask differences are already explicit Questie-Octo corrections with independent provenance. Examples include the Blood Ring PvP rows `41107`-`41110`, dungeon-contained `40539` **Hunting Engineer Figgles**, and the Hyjal corrections `40959` **Into the Dream III**, `40962` **Into the Dream VI**, and `40990` **The Runestone Scepter**. Turtle patch notes explicitly corrected the latter three quest classifications, so reverting them to the base SQL would be a regression.

Legacy profession/race gating and event rows are likewise left on their existing audited/extracted values unless current live evidence shows a problem. The purpose of this audit is to recover missing truth, not force every field to equal the base SQL snapshot.

### Deliberately unresolved: Saving the Shadowtooth

`41095` **Saving the Shadowtooth** remains contradictory across current references:

- Questie-Octo/current Octo database: quest level 55, minimum level 60;
- supplied current base SQL: quest level 60, minimum level 60;
- Turtle patch notes dated 2025-08-13 explicitly say the quest requirement was lowered from 60 to 55.

Because none of those three states cleanly expresses the patch-note intent and no live reproduction was supplied, 1.26 does not alter 41095. This remains a fail-closed metadata discrepancy for future live verification.

## Result

The salvage source is useful primarily as corroboration and for recovering narrow missing relationships. The safe 1.26 implementation consists of three recovered quest records (`40273`, `40915`, `40916`) plus the Hardcore prerequisite repair. Current database evidence also validates multiple existing Questie-Octo overrides against stale or inconsistent base-SQL metadata. No broad SQL/database merge was performed, and the unresolved 41095 conflict remains intentionally unchanged.
