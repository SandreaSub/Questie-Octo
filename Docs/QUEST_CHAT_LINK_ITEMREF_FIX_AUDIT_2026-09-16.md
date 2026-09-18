# Questie-Octo 1.27 — Chat quest hyperlink ItemRef fix

## Report and reproduced source path

Player using pfUI reports `Interface\FrameXML\ItemRef.lua:48: Unknown link type` on clicking a linked quest. The supplied Blizzard InterfaceCode shows line 48 calling `ItemRefTooltip:SetHyperlink(link)` for ordinary clicks. Its native hyperlink handler cannot accept Questie-Octo's `quest:<id>:<level>` hyperlinks. In 1.26 `UI/QuestLinkTooltip.lua` used a `hooksecurefunc("SetItemRef", ...)` post-hook; that callback cannot prevent an exception raised by the original function. pfUI chat wrappers forward links to their captured `SetItemRef` and so can expose the same error, but the broken hook strategy is in Questie-Octo.

## Scoped correction

- Install an early, link-specific `SetItemRef` wrapper instead of the post-hook when `FOUNDATION_READY` fires.
- Intercept only the `quest:`/`quest2:` link types before the stock ItemRef handler. All other types forward to the captured pre-existing handler without alteration.
- Open existing Questie-Octo detailed quest tooltip for a known quest; display a safe unavailable-details tooltip for unrecognized/absent quests. Neither case calls the native `SetHyperlink`.
- Preserve Shift-to-chat insertion when the chat box is open; consume Ctrl quest-link clicks rather than trying to dress up an un-dressable quest. No changes to item/player/url paths, world map, data, tracker, polling, or SavedVariables.
- pfUI chat's pre-existing and later-installing wrappers forward to this quest-specific dispatch if they preserve the SetItemRef chain as in the supplied pfUI source.

## Validation scope

Run focused Lua harness against the actual file for native error reproduction, known/unknown quest clicks, pfUI wrappers in both load orders, modifier behavior, non-quest link forwarding, and redundant hook-install idempotence. Run Lua parse, TOC, database and provenance checks plus the source/runtime package parity checks. In-game confirmation remains necessary.
