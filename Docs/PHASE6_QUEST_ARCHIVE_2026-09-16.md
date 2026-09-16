# Questie-Octo — Phase 6 Turtle salvage (source archive only)

**Baseline:** 1.31. **Gameplay and compiled runtime:** deliberately unchanged. This phase continues following 18 quest-starting items whose acquisition was unproven in the previous snapshot audit.

## Three additional starter-item creation mechanisms

- **Cuergo's Treasure Map (9254; quest 2882)**: the server snapshot's spell **11438, Join Map Fragments**, creates the finished map using one each of Upper Map Fragment (9251), Lower Map Fragment (9252), and Middle Map Fragment (9253). All 3 original fragment item-template rows, 4 fragment item-container loot rows, both parent container item-template rows, and 5 original creature-loot rows for Pirate's Footlocker (9276) are archived. The separate Gadgetzan Water Co. Care Package (8484) contains a fragment in the supplied SQL; no parent source is established for it here. **None of those rows is a direct drop of the assembled map.**
- **Warlord Goretooth's Command (12563; quest 4903)**: spell **16548, Goretooth's Orders**, creates the item; original gossip-script **2889** casts that spell. No reagent is defined on the spell row. The archived script tuple does not independently establish NPC/eligibility.
- **Elegant Letter (17126; quest 6681)**: spell **21100, Conjure Elegant Letter**, creates the item; original gossip-script **16** casts it. No reagent is defined on the spell row. The script's initiating NPC/conditions are not established by these rows alone.

## Remaining uncertainties

**15 of the original 18** now remain without an acquisition mechanism established by the inspected snapshot evidence: the two Squirrel Tokens (17115/17116), eleven Mastery of [weapon] items (70227–70236 and 70238), and two custom item IDs (41799/41802) missing entirely from the snapshot item_template. Absence from this snapshot does **not** mean they are unused on the live server. The phase 3/4 archives already preserve their available item/quest references; no invented origins were added.

## Archive boundaries and provenance

`Data/archive/quest_salvage_phase6_2026-09-16.json` contains original server spell rows, original gossip-script tuples, item/loot rows and SHA-256 fingerprints. This is **historical server-snapshot evidence**, not verification of live drops, quests, spawn positions or current quest availability. All Phase 2–5 archives are carried forward byte-identically.

This JSON and its report exist in the full/source ZIP only. The JSON is absent from the TOC, runtime compiler and player ZIP. All game-loaded Lua and runtime DB remain byte-identical to 1.31; the only existing files updated are the TOC version and engineering changelog.
