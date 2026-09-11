# Map / Minimap Shift-Click and Compact Layout Audit — 2026-09-11

## Scope

Questie-Octo 1.22 follows live review of the 1.21 compact Shift-hover presentation. The feature remains intentionally limited to World Map and minimap quest markers; the custom tracker already exposes its objectives directly.

## Compact objective layout

Counted item/creature/gameobject objectives continue to use the authoritative `QuestObjectiveRequirements` projection before acceptance and live Quest Log counters after acceptance. Long fallback prose now receives a tracker-style hanging indent when wrapping is necessary.

For quests with no structured objective rows at all, the compact transient hover now prefers the quest's real finisher relation as a concise destination (`Speak with <NPC>` / `Interact with <object>`) instead of placing a long authored sentence into a cursor tooltip. This only applies when no counted/structured objective exists; full authored text remains available in the Quest Browser and chat-link details.

## Shift + Left Click

World Map and minimap pins now register Shift + Left Click as a direct Quest Browser action. The exact quest ID is passed to a new `QuestResearch:OpenQuest()` entry point, which uses an exact numeric browser query and selects that quest. World Map ordinary click behavior remains unchanged when Shift is not held; minimap pins gain no ordinary-click action.

When a physical pin represents more than one quest, the click targets the pin's established visual-primary quest (the same `pin.questID` selected by existing visual priority). This is deterministic and avoids inventing a second selector interaction.

## Runtime / performance

The change is UI-only. It adds no polling, `OnUpdate`, ZoneBootstrap work, database scan, node rebuild, clustering, or map-identity work. Modifier refresh remains event-driven through the existing `MODIFIER_STATE_CHANGED` watcher.
