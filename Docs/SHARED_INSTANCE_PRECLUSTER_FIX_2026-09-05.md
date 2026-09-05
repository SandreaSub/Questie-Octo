# Shared Instance Pre-Cluster Fix — 2026-09-05

## Status

Questie-Octo 1.09 candidate. This fixes the correctness regression found during the 1.08 audit. Live player validation is still required before promotion to the accepted baseline.

## Problem

1.08 classified shared entrance/interior ownership after PreparedMap had already clustered objective points or aggregated item-start points. Shared sources are classified from exact one-decimal source coordinates, while a cluster position is usually a synthetic centroid. Reclassifying the centroid could therefore hide valid clusters or reject mixed item-start aggregates on both sibling maps.

## Fix

- The generic SharedInstanceContext resolver is enabled during preparation only for AreaTable IDs 718, 1337, 2100, 2557, and 5640.
- Raw objective points are classified and separated by context before clustering.
- Prepared descriptors carry `preparedMapContext`; World Map and minimap rendering compare that proven tag to the active context and do not infer ownership from a centroid.
- Item-start grouping is split by context before normal clustering.
- Ultra-rare `<1.00%` starter items produce one real-coordinate representative per context.
- Full Nodes remain exact point-level.
- Non-shared maps keep the existing fast path.
- Gnomeregan 721 and Karazhan 3457 remain under their dedicated context modules.

## Focused regression results

- Wailing Caverns creature 3641: 8 entrance + 2 interior raw points preserved; 2 entrance + 1 interior clusters.
- Uldaman creature 4851: 10 entrance + 19 interior raw points preserved; 4 entrance + 3 interior clusters.
- Dire Maul object 175404: 2 entrance + 7 interior raw points preserved; 1 entrance + 1 interior clusters.
- Uldaman quest 635 / item 4614: 121 entrance + 72 interior points; exactly one ultra-rare representative per context in both Clustered and Full item density modes.
- Uldaman quest 2198 / item 7666: 104 entrance + 42 interior points; 6 entrance + 2 interior clustered areas; all 146 points preserved in Full Nodes.
- Displayed texture, physical server-map identity, and minimap dimensions passed for all five generic shared IDs.

## Performance scope

The context split is map-local and only activated for the five proven shared IDs. No new polling, `OnUpdate`, ZoneBootstrap rate change, global quest scan, or minimap spatial index is added.
