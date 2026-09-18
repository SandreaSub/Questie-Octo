# Flight-master faction audit — 2026-09-18

## Player report
An Alliance player sees a Mudsprocket flight-master marker labeled Razzit and asks whether the two apparent flight paths are both usable by Alliance. Their screenshot alone does not identify the owner of every overlapping icon; pfUI and other addons may also paint map icons.

## Reproduction from supplied Questie-Octo 1.34 source
- `Data/pfDB/meta-turtle.lua` originally identifies NPC 61133 (Razzit) as `AH`, so `Map/Nodes.lua` builds the NPC's flight-master marker for both player factions.
- `Data/runtime/units.lua` places NPC 61133 at Dustwallow Marsh 42.8, 72.5; supplied server `tw_world_creature.sql` spawn GUID 2573746 locates that NPC 1.3 world yards from taxi node 180.
- Supplied server `tw_world_taxi_nodes.sql` row 180 is `Mudsprocket`, with `mount_creature_id1=2224` (Horde) and `mount_creature_id2=0` (no Alliance mount). Neighboring Theramore row 32 has the opposite slot pattern, supporting the column interpretation. `tw_world_creature_template.sql` assigns Razzit NPC faction 1682: creature reaction is not proof of flight service access.
- Existing Questie-Octo renders one Razzit flight source on the Dustwallow map. The player screenshot does not establish whether a second nearby icon is from Questie-Octo, pfUI, or the underlying World Map.

## Scope of cross-check
- Compared the compiled flight tracking table (83 NPC IDs) against the supplied server creature spawn positions and taxi node positions within 125 world yards on the same map.
- 72 tracked flight NPC IDs have static server spawns and each matches a taxi node in that comparison; the other 11 have no matching static spawn in this supplied snapshot and are left untouched.
- Among the 72 matched IDs, the only substantive faction contradiction was Razzit. Four other printed string mismatches (`AH` vs `HA`) are equivalent dual-faction values.
- This is a snapshot audit, not a complete census of current OctoWoW live flight service or arbitrary additional map addons.

## 1.35 implementation
- Correct `pfDB["meta-turtle"]["flight"][61133]` to `"H"` via `Data/pfDB/overwrites-octo.lua`. The compiler writes the corrected `Data/runtime/meta.lua`; all other compiled runtime data stays intact. Do not rewrite Razzit's neutral NPC faction or insert an unconfirmed Alliance taxi point.
- Existing faction filtering in `Map/Nodes.lua` now omits Razzit for Alliance while retaining him for Horde, on both World Map and minimap.
- Flight-master tooltip service lines specify `Flight Master (Alliance)`, `(Horde)`, or `(Alliance & Horde)` using the node's service metadata, not its NPC faction. Other services preserve their existing tooltip format.
- No additional toggles, polling, OnUpdate, map clustering, quest changes, or SavedVariables edits.

## Verification and remaining uncertainty
- Offline Lua harness exercises the real service-slice faction filter and the real World Map/minimap tooltip with Alliance, Horde, and shared flight masters, plus an unrelated banker tooltip.
- Validate current live gameplay with an Alliance and Horde character at Mudsprocket. If a second marker remains after this correction, capture its tooltip / identify which addon owns it before suppressing any additional marker.
