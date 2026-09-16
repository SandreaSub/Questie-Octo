# Questie-Octo — Phase 5 Turtle salvage audit (reference archive only)

**Base:** 1.30. **Gameplay/runtime:** deliberately unchanged.

## New acquisition evidence

- **Four formerly unresolved quest-starting books** (item IDs 56108–56111) are produced by **four distinct create-item spells** (29950–29953). The original 149-field spell rows are archived, including each book's *two exact reagent halves*. Each half's original item-template row and all **37 creature-loot / 4 gameobject-loot** snapshot rows are retained. The component loot rows belong to the halves, **not the finished quest-starting books**. No live drop rate or current spawn is asserted.
- **A Mysterious Missive (item 61457, quest 40914)** is explicitly *created and sent by mail in the supplied server C++ source*, gated on Hardcore status, level 55–59, and a one-time flag. Calls appear on login and level-up. The original code with line numbers and SHA-256 is preserved; it is **snapshot evidence, not a verified live Octo server behavior**. Do not create a creature-drop marker for this item.
- Consequently, **5 of the previous 23 unresolved item starts now have a documented *snapshot* acquisition mechanism; 18 remain unresolved** in the tables and sources examined here. This does not say that those 18 items or quests are removed from live play.

## A misleading archived container

- **Dragon's Year Gift (91790)** has a tempting mail-grant block in the supplied code, but it is **fully commented out**. An active separate reference only exempts it from a Hardcore inventory reset under a regional configuration; that is not an acquisition route. Darkmoon Faire Fortune (19422) likewise lacks a confirmed origin in the sources examined. Both remain unresolved.

## Website references

Seven individually indexed Turtle item/spell pages are retained as corroborating *page observations* only, including the Advanced Gemology book/spell pages. Pages do not verify the current Octo runtime, spawn locations, or reward/item-drop probabilities. All raw field identity and full SQL/source provenance are maintained in the JSON archive.

## Release boundary

`Data/archive/quest_salvage_phase5_2026-09-16.json` is **source-only** and never loaded by the TOC or compiler; it is excluded from the GitHub/player package. Prior Phase 2–4 archives remain byte-identical. Existing runtime, reward files, quest availability, quest IDs, map pins and markers are byte-identical to 1.30. No existing addon source file changes other than TOC version and engineering changelog.
