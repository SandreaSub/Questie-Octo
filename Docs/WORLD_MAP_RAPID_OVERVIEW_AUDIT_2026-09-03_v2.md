# Questie-Octo 1.0.94 — Rapid World Overview Audit

## Status

1.0.93 failed live testing. This audit restarts from accepted 1.0.92 and retains none of 1.0.93's `cid<=0` guard.

## Live evidence

The failure screenshot shows the native map texture already displaying both continents while the visible map context/title still reports Kalimdor. This demonstrates a transient state where GetMapInfo()/the rendered texture has advanced before GetCurrentMapContinent() has settled.

## Current native FrameXML

The supplied current `FrameXML/Overrides.lua` defines `CONTINENTS_LENGTH = 2`. `WorldMapZoomOutButton_OnClick()` and `WorldMap_UpdateContinentDropDownText()` in `WorldMapFrame.lua` explicitly treat `continentId > CONTINENTS_LENGTH` as the global World state. `WorldMapFrame_Update()` renders the texture returned by `GetMapInfo()` independently.

Therefore a fast transition can legitimately expose:

- texture = `World`
- stale continent = Kalimdor (1)
- zone = 0

The 1.0.93 check for `continent <= 0` cannot detect that state.

## Defect 1 — global World identity

1.0.92/1.0.93 can feed the World texture's AreaTable value 0 into selected-map logic while a stale positive continent is still present. Numeric zero is truthy in Lua. More importantly, if selected-map resolution fails but continent resolution accepts the stale continent, Questie-Octo can start a Kalimdor continent projection on top of the World texture.

1.0.94 introduces one shared `IsGlobalWorldOverview()` predicate. The `World` texture is authoritative for the unsupported two-continent view, and the current native `continentId > CONTINENTS_LENGTH` sentinel is also recognized. Both selected-map and continent-map resolution call this predicate.

The old 1.0.93 `cid<=0` rule is intentionally not retained: a custom instance/detail texture may still be safely identified when the continent tuple is nonstandard.

## Defect 2 — orphaned in-flight pins

The continent renderer is intentionally batched. Each rendered pin is shown immediately and appended to `buildActiveFrames`; only `Finish()` promotes that list to `activeFrames`.

Before 1.0.94, `SetMap()` invalidated the generation and called `HideAll()`, but `HideAll()` hid only `activeFrames`. If a context changed after some new pins had already been rendered but before `Finish()`, the generation stopped correctly while the visible pins in `buildActiveFrames` were discarded without being hidden. They became orphaned visible frames on the next map texture.

1.0.94 hides both completed and in-progress frame lists, de-duplicating reused frames before counting/hiding them.

## Regression expectations

1. Kalimdor continent: texture `Kalimdor`, continent 1, zone 0 -> normal Kalimdor continent projection.
2. Eastern Kingdoms continent: texture `Azeroth`, continent 2, zone 0 -> normal Eastern Kingdoms projection.
3. Stable World overview -> no Questie-Octo World Map context/pins.
4. Transient World overview with texture `World` but stale continent 1 or 2 -> still no Questie-Octo context/pins.
5. Texture-identified custom/detail map with a nonstandard continent tuple -> remains selectable when its texture is not `World`.
6. Context change during an unfinished continent render -> every pin already shown by that unfinished generation is hidden immediately.
7. No new background work.

## Live acceptance test

Repeatedly switch as fast as possible from a selected area to its continent and immediately to the two-continent World overview. No Questie-Octo pin should remain visible on the World texture, including pins that had already appeared during a partially completed continent render.
