# Questie-Octo 1.0.95 — Objective Color Palette Audit

## Scope

This pass changes only active-objective coloring on the World Map and minimap. It starts from the live-validated 1.0.94 baseline.

## Reference comparison

Questie 5.2.3 generated deterministic quest colors by seeding a pseudo-random generator with the quest ID, but constrained each RGB channel to 0.45..0.95. In dense objective areas this strongly biases the palette toward pale blue/green/gray combinations that can be mathematically different while remaining visually similar.

pfQuest uses a deterministic string hash that spans the full 24-bit RGB range. Its quest nodes therefore have much stronger separation. pfQuest keys that hash from quest-title strings. Questie-Octo instead hashes a fixed `quest` namespace plus the numeric quest ID so colors are locale-independent and cannot collide merely because two quests share a title.

## 1.0.95 behavior

- `Visuals:GetQuestColor(questID)` uses the pfQuest full-range RGB hash keyed by a fixed `quest` namespace plus numeric quest ID.
- Clustered objective icon fill uses that quest color when **Enable Different Map/Minimap Icon Color for Each Quest** is enabled.
- Clustered objective glow/contour uses the same quest color when **Enable Map/Minimap Icon Glow** is enabled. It no longer changes color between objectives of the same quest.
- Full Nodes use that same quest color directly and retain their existing 85% alpha/14px presentation. The former additional 0.72 RGB darkening is removed.
- Available `!`, completed `?`, repeatable/event/PvP markers, Flight Masters, rares, and other service icons are not recolored.
- A merged/clustered pin that represents multiple quest entries still has one visual owner under the existing priority rules; this pass does not split or rebuild shared pins merely to show several colors at one coordinate.

## Performance

The hash is cached per key. Only active-objective quest IDs normally request these colors, so the cache is small. No polling, timers, OnUpdate work, map rescans, or database work were added.

## Regression boundaries

The validated 1.0.94 rapid World Map transition fixes are retained unchanged. Objective visibility, clustering, Full Nodes density, tooltip grouping, icon scale, map candidate generation, and minimap movement are unchanged.
