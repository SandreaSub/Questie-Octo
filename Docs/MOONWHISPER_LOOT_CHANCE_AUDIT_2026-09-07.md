# Questie-Octo 1.16 — Moonwhisper Coast Loot-Chance Audit

## Trigger

A live player report on **Echoes of Nendis (42086)** showed **Nendis Memento (42394)** as `1.00%` on Questie-Octo objective tooltips even though the current OctoWoW database reports the ground containers at 100%. The player also reported the same class of bad percentage on creature-sourced Moonwhisper objectives.

## Root cause

This was a data-layer problem, not tooltip formatting.

Questie-Octo's packaged Turtle item data contains many custom item-source relationships with a placeholder chance of `1`. The current server loot tables contain the real percentages. For Nendis Memento specifically, the packaged item row contained:

- object 2020345 -> 1
- object 2020346 -> 1

Current server `gameobject_loot_template` contains both sources as quest-conditioned `-100`; the negative sign is the server's quest-chance encoding, so the player-facing chance is 100%.

Questie-Octo already carried a small `itemfix` table containing the intended 100% Nendis correction and several similar audited object fixes, but the application loop only inserted a correction when the entire item record was absent. Existing records therefore kept their stale source chances and the correction table was effectively skipped for the cases it was meant to repair.

## Audit scope

The audit used the current server quest, creature/gameobject template, creature loot, skinning loot, and gameobject loot data supplied with the project.

Moonwhisper Coast currently has:

- 105 server quests with ZoneOrSort 5642;
- 72 distinct required-item objectives;
- 68 custom Moonwhisper item IDs in the current Turtle item range examined here;
- 353 existing custom item/source pairs that resolve directly to a current creature-loot, skinning-loot, or gameobject-loot relationship.

Of those 353 directly verifiable pairs:

- 29 already matched the current server percentage;
- 324 were wrong, overwhelmingly because a placeholder `1%` had been flattened into the packaged Turtle item data;
- after the 1.16 correction, all 353/353 directly verifiable pairs match the current server percentage.

The four non-custom required items used by Moonwhisper quests (8348, 8831, 15054, 15061) are ordinary pre-existing materials and are outside this custom-loot correction pass.

## Representative corrections

Examples include:

- Nendis Memento (42394): ground objects 2020345/2020346, 1% -> 100%.
- Blackroot Totem (41996): current Blackroot creature sources, 1% -> 8%.
- Raw Draenethyst Formation (42001): ground objects 1% -> 100%; verified creature sources 1% -> 8% or 16% according to their current loot template.
- Glowing Draenethyst Cluster (42015): ground objects 1% -> 4%; verified creature sources 1% -> 2% or 4%.
- Arcane Bark (42134): 1% -> 35%.
- Foulheart Hooves (42137): 1% -> 60%.
- Hydra Leather (42215): verified skinning sources 1% -> 35% or 100%.
- Glimmering Hydra Scale (42258): 1% -> 8%.
- Falling the Fallen item source (42351): 1% -> 90%.
- Tideblade Scale (42396): 1% -> 85%.

No global `1% => X%` rule is used. Every changed source/item pair is explicitly constrained to a percentage verified from the current server relationship, because legitimate 1% drops exist elsewhere.

## Implementation

`Data/pfDB/overwrites-octo.lua` now merges audited source-level item corrections into an existing Turtle item row instead of skipping that row. Unrelated source fields are preserved.

A Moonwhisper-specific correction table then patches only the verified creature (`U`) and object (`O`) source IDs. Creature-source verification follows the current creature loot ID, and uses the current skinning loot ID for skinning-only acquisitions such as Hydra Leather. Object-source verification follows the current gameobject loot ID.

The existing pre-1.16 `itemfix` table was separately checked: all 22 item/object pairs in that table match the current server values, so making that table actually merge is safe. This also restores the two intended 30% object-source relationships for items 42178 and 42180 that were previously absent from the compiled runtime.

## Regression / architecture checks

- Nendis Memento runtime sources compile as 100% for both current ground objects.
- All 353 directly verifiable custom Moonwhisper item/source pairs match current server percentages after the overwrite layer.
- Runtime database validation passes.
- No tooltip formatter, objective-state logic, map clustering, polling, `OnUpdate`, ZoneBootstrap, or minimap architecture is changed.
- The correction is data-only at build time; players do not incur a new runtime scan.
