# Map / Minimap Shift-Hover Refinement Audit — 2026-09-11

## Scope

Questie-Octo 1.21 refines the 1.20 Shift-hover feature after live UI review. Shift-hover is now intentionally limited to World Map and minimap quest markers. The custom tracker already renders live objective rows, so its transient Shift expansion was redundant and could compete with the tracker text itself.

## Tracker-style objective presentation

Map/minimap Shift-hover now renders a compact `[level+] Quest` header followed directly by `- objective` rows and an optional Rewards section. Active quests read the same Quest Log objective state used by the tracker, including native current/required counters. No objective percentages are synthesized.

For available/non-active quests there is no live Quest Log leaderboard state. A new `Data/QuestObjectiveRequirements.lua` projection was generated from the supplied authoritative Turtle `tw_world_quest_template.sql`. After intersecting server requirements with the current compiled runtime objective identities, it contains 3,777 quests and 5,923 exact item/creature/gameobject required-count relations. `QuestModel.objectiveData` attaches a required count only when the quest ID, objective kind, and objective entity ID all match. Unmatched/custom/scripted objectives retain the existing authored-text/name fallback instead of receiving guessed counts.

Example: quest 60032 `Fashion Demands Sacrifices` now has authoritative requirements 5 Heavy Leather, 5 Silk Cloth, 1 Stylish Green Shirt, and 5 Torn Bear Pelt available to the compact hover even before acceptance. Quest 2930 `Data Rescue` carries the authoritative one-Prismatic-Punch-Card requirement, while an active copy continues to prefer the live `0/1` Quest Log text.

## Runtime / performance

The requirement data is a static lookup loaded with the addon. There is no runtime database scan, polling, `OnUpdate`, ZoneBootstrap work, node rebuild, clustering change, or map identity change. The map/minimap `MODIFIER_STATE_CHANGED` watcher remains the only modifier refresh path. The tracker-specific modifier watcher introduced by 1.18 is removed.

## Compatibility

Full chat quest links continue to use `ItemRefTooltip` and their existing verbose detail renderer. Normal map/minimap hover is unchanged when Shift is not held. Tracker left click, right click, Shift+click untracking, hover focus, and ordinary help tooltip are unchanged apart from removal of the obsolete Shift-hover hint.
