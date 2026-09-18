# Questie-Octo 1.0.95 — Color Vision Accessibility Audit

Date: 2026-09-03
Baseline audited: Questie-Octo 1.0.95 Full/source
Status: implemented in Questie-Octo 1.0.96; live validation pending

## Scope

Audit the new deterministic per-quest active-objective colors introduced in 1.0.95 and define the safest way to add color-vision accessibility controls. The requested UI location is the **Other** tab in Questie Options.

## Current 1.0.95 color path

`Map/Visuals.lua` is the correct central integration point.

- `Visuals:GetQuestColor(questID)` hashes `"quest" .. questID` into full-range RGB and caches the result.
- Clustered World Map objective tint uses `GetQuestColor()` when `questObjectiveColors` is enabled.
- Clustered minimap objective tint uses `GetQuestColor()` when `questMinimapObjectiveColors` is enabled.
- Map/minimap glow uses `GetQuestColor()` independently of the tint toggle.
- Full Nodes always use `GetQuestColor()` directly, on both World Map and minimap, at the existing 85% alpha.
- Available, completed, repeatable, event, PvP, Flight Master, rare and service markers are outside this system and must stay unchanged.

Therefore accessibility must be implemented underneath `GetQuestColor()`. Applying a mode only to the existing tint toggles would miss Full Nodes and glow.

## Accessibility finding

The full 24-bit hash is excellent for deterministic variety but is not accessibility-aware. It does not constrain luminance or perceptual separation under color-vision deficiencies.

Static inspection of all 6,701 packaged quest IDs found that about 19.7% of their base hashed colors have sRGB relative luminance below 0.10 before Full Nodes apply their existing 85% alpha. This is not a formal contrast failure because World Map backgrounds vary, but it confirms that the unrestricted hash can produce very dark colors.

Red-deficient, green-deficient and blue-deficient should be treated as the useful player-facing color-vision families; the internal implementation may still use protan/deutan/tritan keys. Separate anomaly/anopia UI entries are unnecessary; one robust mode per family is preferable. Complete/monochrome color loss cannot honestly be solved by a color-only palette and should not be labelled as fully supported unless Questie-Octo later adds a non-color cue such as shapes/patterns/symbols.

## Recommended UI

Add a new section to **Questie Options -> Other**, between **Interface** and **Reset Questie Options**:

```text
---------------- Accessibility ----------------
Objective Color Vision                  [ Default ▼ ]
```

Recommended selector values:

```text
Default
Red-deficient
Green-deficient
Blue-deficient
High Contrast
```

Use one selector, not multiple toggles, because the modes are mutually exclusive.

Default must remain `Default` so 1.0.95 appearance is unchanged for existing players.

## Settings architecture

Add one global setting, not a per-character setting:

```text
objectiveColorVisionMode = "default"
```

Accepted values:

```text
default
protan
deutan
tritan
highContrast
```

It belongs in `QuestieOctoGlobalDB.minimap` through the existing MinimapSettings global-option path. A vision/display preference should follow the player across characters.

`MinimapSettings:Set()` should validate the string value. On change it should call the existing `Map:RefreshVisualSettings()` path. That path recolors active World Map pins in place and cascades to `Minimap:RefreshVisualSettings()`, whose visible-frame pool is rebound immediately. No node rebuild, database scan, polling, timer, or new OnUpdate work is required.

`Reset Options` already copies every declared default back into the correct SavedVariables table, so adding the new key to `S.defaults` automatically gives it correct reset behavior.

## Color implementation rule

Do **not** replace the current deterministic quest identity architecture and do not dynamically assign colors according to the active quest list. Quest ID must remain the stable identity key.

Recommended structure:

```text
quest ID
-> existing deterministic base hash / stable seed
-> selected color-vision mapping
-> RGB returned by GetQuestColor()
-> existing map/minimap Full Nodes, clustered tint and glow consumers
```

The accessibility modes should be designed palettes/mappings intended to remain distinguishable for the selected deficiency, not simulations of what color blindness looks like. Simulation is an offline validation tool, not the runtime correction itself.

Avoid caching a transformed color only by the old `"quest..."` key, because changing modes would then reuse stale colors. Either keep the existing cache as the base-color cache and apply the selected mapping afterwards, or include the mode in a separate transformed-color cache key.

## Validation requirements for the future implementation

Offline/static:

1. Preserve exact 1.0.95 colors in `Default` mode.
2. Test candidate palettes under protan/deutan/tritan simulation, including severe/full dichromacy.
3. Check luminance distribution so small Full Nodes do not disappear into dark map regions.
4. Confirm one quest retains one color across all objectives, both map surfaces and glow.
5. Confirm available/turn-in/special/service icons are byte/presentation unchanged.
6. Confirm changing the selector refreshes currently visible map and minimap pins without rebuilding semantic nodes.
7. Confirm no new recurring work or per-frame allocations.
8. Confirm old Lua/Interface 11200 compatibility.

Live in-game:

- Clustered map with tint only.
- Clustered map with glow only.
- Clustered map with tint + glow.
- Full Nodes World Map.
- Full Nodes minimap.
- Switch modes while pins are visible.
- Dense area with several active quests.
- Dark/light map backgrounds.

## Explicit non-goals

- Do not recolor available `!`, completed `?`, repeatable/event/PvP, rare or service icons.
- Do not alter clustering, Full Nodes density, candidate generation, tooltip grouping, map identity, minimap movement or scheduler behavior.
- Do not add runtime color-blindness simulation of the whole UI.
- Do not claim achromatopsia/monochrome support from color alone.
- The original audit itself was design-only; implementation was generated later as 1.0.96 after explicit approval.

## Conclusion

The 1.0.95 architecture is already well positioned for this feature. The change should stay narrow: one new global selector in **Other -> Accessibility**, one validated setting, and one accessibility mapping layer behind `Visuals:GetQuestColor()`. Existing visual refresh paths can apply mode changes immediately with essentially no new runtime architecture.


## 1.0.96 implementation result

Implemented from the accepted 1.0.95 baseline. The visible selector uses the simplified player-facing labels requested after the design audit: **Default**, **Red-deficient**, **Green-deficient**, **Blue-deficient**, and **High Contrast**. Internal values remain `default`, `protan`, `deutan`, `tritan`, and `highContrast`.

The runtime implementation stays behind `Visuals:GetQuestColor()`. `Default` returns the original 1.0.95 hash unchanged. Accessibility modes apply fixed deterministic channel remaps plus a small dark-color lift. The remaps were selected offline against severe protan/deutan/tritan simulations; no color-blindness simulation runs in-game. The new setting uses the existing visual-only refresh path and introduces no recurring work.
