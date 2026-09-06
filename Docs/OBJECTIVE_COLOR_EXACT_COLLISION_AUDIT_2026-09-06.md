# Questie-Octo 1.15 — Objective Color Exact-Collision Audit

Date: 2026-09-06  
Baseline: accepted Questie-Octo 1.14  
Trigger: Grim Reaches follow-up report after the 1.12 palette spread.

## Result

The follow-up Grim Reaches screenshot does **not** show an exact default-palette RGB collision among the zone's current quest candidates. The 1.12 change successfully removed the original sequential-ID purple/pink/blue collapse.

However, a full current-runtime audit found that the palette was still not collision-free after normal 8-bit display quantization. Across all 6,701 runtime quest IDs, 1.14 produced 826 duplicated RGB groups (831 duplicate assignments beyond the first color owner). More importantly, eight duplicate pairs belonged to quests that share the same compiled map-candidate set, across five maps.

Confirmed same-map default collisions in 1.14 included:

- map 85: quest 398 / 8828 and 431 / 8861
- map 141: quest 935 / 9365 and 937 / 9367
- map 440: quest 841 / 9271
- map 1519: quest 392 / 8822 and 397 / 8827
- map 1637: quest 7834 / 41554

This means the player's concern was valid even though the new Grim Reaches screenshot itself was not an exact-collision example.

## Root cause

The 1.12 palette intentionally keeps neighboring quest IDs far apart with:

`hueIndex = (questID * 40494) mod 65521`

Its secondary saturation/value bands repeat every 30 quest IDs. A distant return of the hue sequence can therefore land close enough to another quest that, when the 30-ID secondary state also repeats, both colors round to the same visible 8-bit RGB value. The strongest recurring example is the 8,430-ID separation: `(8430 * 40494) mod 65521 = 10`, while 8,430 is also divisible by 30.

The underlying floating-point colors were technically distinct, but a player sees the framebuffer/display result, so an exact post-quantization duplicate is still a real presentation collision.

## 1.15 correction

The successful 1.12 palette is retained. 1.15 adds a deliberately tiny independent identity signature after HSV conversion:

- independent modulus: 65519
- base signature multiplier: 26367
- each RGB channel shifts by at most 2/255

This is small enough that existing quest colors remain visually the same family while breaking exact display-level ties.

Accessibility remaps can create new post-remap ties because channel remapping plus the dark-color lift changes the quantization geometry. After the existing accessibility transform, 1.15 applies a second independent signature:

- multiplier: 58788
- each RGB channel shifts by at most 1/255

No accessibility mode logic or UI option was otherwise changed.

## Validation

Using conventional 8-bit `floor(channel * 255 + 0.5)` quantization against the packaged runtime data:

### Default

- Runtime quests audited: 6,701
- Exact 8-bit RGB duplicate groups in 1.14: 826
- Exact 8-bit RGB duplicates in 1.15: **0**
- Same-map candidate collision pairs in 1.14: 8 across 5 maps
- Same-map candidate collision pairs in 1.15: **0**

### Accessibility modes

Across all 108 current runtime map-candidate sets, exact same-map 8-bit collision pairs in 1.15:

- Default: **0**
- Red-deficient: **0**
- Green-deficient: **0**
- Blue-deficient: **0**
- High Contrast: **0**

Different quests on unrelated maps can still converge to the same final 8-bit value in an accessibility remap; they cannot be displayed together on any current compiled map-candidate set, and their full-precision colors remain distinct. The map-local collision guarantee is the relevant runtime presentation boundary.

## Scope

Unchanged:

- quest/objective ownership;
- Full Nodes / Clustered density;
- World Map / minimap candidate generation;
- tracker and tracker-hover focus;
- available/completed/special/service icons;
- Objective Color Vision mode choices and remap definitions;
- runtime database contents;
- polling, timers, OnUpdate, ZoneBootstrap, and refresh behavior.
