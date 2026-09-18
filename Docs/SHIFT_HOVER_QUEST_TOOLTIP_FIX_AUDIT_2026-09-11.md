# Shift-Hover Quest Tooltip Fix Audit — 1.19

## Report

The 1.18 feature was incomplete: it only registered quest-row hover state in the custom tracker, so World Map and minimap pins had no Shift-hover path at all. The supplied live recording also showed the tracker tooltip occasionally retaining an oversized horizontal width while moving between normal and detailed hover states.

## 1.19 correction

`UI/QuestLinkTooltip.lua` remains the single quest-detail content builder used by chat quest links and hover details. Tracker Shift-hover now hides and clears the Vanilla `GameTooltip` before every detailed/basic rebuild. Hover-only objective/description prose is explicitly line-bounded before it is handed to Vanilla's tooltip layout so stale dimensions cannot expand the tooltip across the screen. Chat `ItemRefTooltip` keeps its existing native wrapping.

`Map/Tooltips.lua` now tracks the exact pin under the cursor and listens to `MODIFIER_STATE_CHANGED`. Holding Shift rebuilds that pin with the same `PopulateQuestTooltip()` content used by chat links. The existing tooltip router is preserved: fullscreen World Map pins use `WorldMapTooltip`, while minimap pins use the existing GameTooltip/pfUI-private tooltip path. Releasing Shift immediately restores the ordinary node/source tooltip.

If a physical pin represents several quests, the detailed view includes each distinct quest represented by that exact pin, sorted by quest level/id. Nearby World Map pins that are normally combined for compact ordinary hover are deliberately not pulled into the detailed Shift view, preventing dense maps from expanding into several unrelated quest descriptions.

## Performance and compatibility

The correction is event-driven only. It adds no polling, no `OnUpdate`, no ZoneBootstrap work, no map/objective/database scan, and no node rebuild. Existing map pin pooling, tracker hover focus, quest clicks, right-click menus, and Shift+Click untracking are unchanged.
