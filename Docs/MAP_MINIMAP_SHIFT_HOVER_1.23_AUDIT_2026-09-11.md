# Map / Minimap Shift-hover 1.23 Audit — 2026-09-11

## Scope

Questie-Octo 1.23 follows live review of the 1.22 Shift-hover layout and Shift + Left Click browser behavior. The feature remains limited to World Map and minimap quest markers.

## Authored objective wording

Travel and conversation quests once again use their authored objective sentence in the compact Shift-hover view. The 1.22 destination-only fallback (`Speak with <NPC>` / `Interact with <object>`) is removed because it lost useful quest flavor and context. Counted/structured objectives still prefer authoritative required counts before acceptance and live Quest Log counters after acceptance.

## Wrapping fix

Hover prose is still explicitly wrapped with a tracker-style hanging indent, but those explicit line breaks are now passed to the Vanilla tooltip without enabling a second native wrap pass. This avoids the double-reflow failure where a sensible wrapped line could be split again into very short fragments.

Examples covered by the regression target include `Malin's Request` and `My Darling Wife`.

## Quest Browser layering

`WorldMapFrame` uses `FULLSCREEN` strata. The Quest Browser previously used `DIALOG`, so a browser opened from a World Map Shift-click could exist behind the map. The browser now uses `FULLSCREEN_DIALOG` (and an explicit high frame level within that strata), which places it above the World Map but below normal tooltip strata. Existing browser instances are normalized to the same strata whenever reopened.

## Runtime / performance

The change is UI-only. It adds no polling, `OnUpdate`, ZoneBootstrap work, database scan, node rebuild, clustering, or map-identity work.
