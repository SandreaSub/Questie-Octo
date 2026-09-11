# Tracker Shift-Hover Quest Tooltip Audit — 1.18

## Scope

Questie-Octo 1.18 adds a detailed quest tooltip while Shift is held over an active quest row in the custom tracker. The request is specifically a hover presentation feature; it does not alter quest tracking, Quest Log state, map nodes, or chat-link handling.

## Reuse of the existing quest-link presentation

`UI/QuestLinkTooltip.lua` previously built the detailed chat-link view directly into `ItemRefTooltip`. 1.18 extracts that line construction into `PopulateQuestTooltip(tooltip, questID, text)`. Both the clicked chat-link path and the new tracker hover path use that same function, so the two presentations contain the same quest title/difficulty color, current status, objective text, description, required level, quest level, and optional Quest ID line.

The tracker uses `GameTooltip`, not `ItemRefTooltip`, for Shift-hover. This keeps hover information transient and avoids changing the existing click-to-open/toggle semantics of chat quest links.

## Modifier detection

The supplied ClassicAPI 1.13.4 binary exposes and fires `MODIFIER_STATE_CHANGED`. 1.18 registers one event frame and refreshes the tooltip only while a quest row is actively hovered. This means pressing or releasing Shift while the pointer remains over the row updates immediately without polling and without an `OnUpdate` loop. Registration is guarded with `pcall` so a client that unexpectedly lacks the event still retains safe enter/leave behavior.

## Existing tracker behavior preserved

Without Shift, the existing tracker tooltip remains and now includes a short `Hold Shift for full quest details.` hint. Tracker hover focus still calls `SetTrackerHoverQuest`, so World Map/minimap focus behavior from 1.02 is unchanged. Shift + Left Click still untracks the quest, ordinary Left Click still opens it in the Quest Log, and Right Click still opens quest options.

Pooled tracker rows clear the transient hover owner during rebuilds so a later modifier event cannot resurrect a tooltip for a row that has been hidden or reused.

## Performance

No polling, new `OnUpdate`, map scan, database scan, ZoneBootstrap work, or objective rebuild is added. The detailed quest model is read only while a tracker quest is hovered with Shift held.
