# Questie-Octo — Comprehensive flight-master audit (1.35 → 1.36)

Audit date: 2026-09-18. Scope: the **83 NPC IDs** in `Data/runtime/meta.lua` flight tracking as delivered with 1.35, all **109** taxi-node records in the supplied Turtle server SQL snapshot, and all **122** TaxiNodes.dbc entries in the supplied client. NPC service eligibility is determined from the faction-specific mount slots of a nearby taxi node, not NPC creature reaction/faction. The source files are not a live server query.

## Findings and decisions

- **72/83** tracked NPCs have static server spawns within 25 world yards of a server taxi node. Their service factions agree with 1.35 metadata, including the earlier Razzit correction; their corresponding client DBC node factions agree too. NPC IDs and taxi node IDs are separate namespaces.
- **8/83** custom NPCs have no matching static spawn in the supplied server SQL but map within 6 yards of their respective *client* TaxiNodes.dbc points. Seven agree on faction; **Treggi (NPC 62624, Slickwick Oil Rig, taxi node 89)** is marked `AH` in 1.35 although client node 89 has Horde mount 2224 and Alliance mount 0. The narrow 1.36 correction is `H`. The server SQL snapshot has no node 89 to corroborate this individually; the direct client location match is the basis.
- **Shaethis Darkoak (NPC 1233)** has two inherited map coordinates and `AH` flight-service tracking, but no static spawn in the supplied SQL and no client taxi node within approximately 875 world yards of either position. The current client has no matching Valor's Rest flight point. Vanilla sources also record this NPC's earlier removal; that alone would not establish Turtle behavior. Remove *flight tracking only*, retaining his original unit information and historical `meta-turtle.lua` entry for reversibility.
- **Grommok (92942)** and **Vifri Brent (92943)** have no coordinates in the packaged runtime and therefore produce no map icons. Their service factions are *not* confirmed by either taxi data source; they are left untouched.
- No same-faction pair of tracked flight masters has coordinates less than 10 zone-map percentage points apart on the same map. That does not establish ownership of the player's second Mudsprocket icon; pfUI, Blizzard, or other addons need an in-game UI check.

## Other client taxi nodes

The client has **102 taxi nodes with nonzero mount slots**. **80** are associated with the addon flight masters above; **22** are not. These include inert, transport, battleground, and specialized nodes as well as potentially usable newer routes. A mount flag or route by itself is not sufficient evidence that a visible, interactable flight-master NPC should be created in Questie-Octo.

Of particular interest are Moonwhisper Coast's Narvalis Point (DBC 120), Shimmerstar Lake (122), and Moonhoof Village (123). The supplied server SQL has no static flight NPCs for them, and current Questie-Octo has no flight-service IDs at those points. Leave this as a **coverage investigation**, not an invented NPC/marker. Client-only extra routes are not an additional same-kind faction contradiction among *existing* markers.

## Coordinate findings (kept separate from faction changes)

Some inherited secondary zone coordinates differ from the supplied server spawn positions when projected using the older `Map/ContinentProjection.lua` bounds (notably Stonetalon map 406 and Stormwind 1519). The current client WorldMapArea.dbc bounds differ from those stored in the projector. These require their own map-geometry audit; do not casually rewrite the shared map projection to address a flight-master faction report. In particular **Voryn Skystrider (93100)** is intentionally placed at the Citadel of the Sun landing pad in a previously live-verified Questie override and must not be “fixed” back to the older server/DBC spawn.

## Full 83-NPC census

| NPC ID | Name | 1.35 flight metadata | Taxi node (SQL / client when different) | Taxi service | Evidence | Status |
|---:|---|:---:|---:|:---:|---|---|
| 352 | Dungar Longdrink | A | 2 | A | SQL+DBC (4.8 yd) | MATCH |
| 523 | Thor | A | 4 | A | SQL+DBC (0.9 yd) | MATCH |
| 931 | Ariena Stormfeather | A | 5 | A | SQL+DBC (7.1 yd) | MATCH |
| 1233 | Shaethis Darkoak | AH | — | — | No matched taxi/spawn | REMOVED from flight tracking in 1.36 |
| 1387 | Thysta | H | 20 | H | SQL+DBC (3.8 yd) | MATCH |
| 1571 | Shellei Brondir | A | 7 | A | SQL+DBC (1.6 yd) | MATCH |
| 1572 | Thorgrum Borrelson | A | 8 | A | SQL+DBC (3.0 yd) | MATCH |
| 1573 | Gryth Thurden | A | 6 | A | SQL+DBC (3.1 yd) | MATCH |
| 2226 | Karos Razok | H | 10 | H | SQL+DBC (5.6 yd) | MATCH |
| 2299 | Borgus Stoutarm | A | 71 | A | SQL+DBC (1.5 yd) | MATCH |
| 2389 | Zarise | H | 13 | H | SQL+DBC (3.4 yd) | MATCH |
| 2409 | Felicia Maline | A | 12 | A | SQL+DBC (3.3 yd) | MATCH |
| 2432 | Darla Harris | A | 14 | A | SQL+DBC (5.0 yd) | MATCH |
| 2835 | Cedrik Prose | A | 16 | A | SQL+DBC (2.3 yd) | MATCH |
| 2851 | Urda | H | 17 | H | SQL+DBC (2.4 yd) | MATCH |
| 2858 | Gringer | H | 18 | H | SQL+DBC (5.5 yd) | MATCH |
| 2859 | Gyll | A | 19 | A | SQL+DBC (4.9 yd) | MATCH |
| 2861 | Gorrik | H | 21 | H | SQL+DBC (2.4 yd) | MATCH |
| 2941 | Lanie Reed | A | 74 | A | SQL+DBC (6.6 yd) | MATCH |
| 2995 | Tal | H | 22 | H | SQL+DBC (3.7 yd) | MATCH |
| 3305 | Grisha | H | 75 | H | SQL+DBC (4.4 yd) | MATCH |
| 3310 | Doras | H | 23 | H | SQL+DBC (2.7 yd) | MATCH |
| 3615 | Devrak | H | 25 | H | SQL+DBC (4.7 yd) | MATCH |
| 3838 | Vesprystus | A | 27 | A | SQL+DBC (3.0 yd) | MATCH |
| 3841 | Caylais Moonfeather | A | 26 | A | SQL+DBC (4.4 yd) | MATCH |
| 4267 | Daelyshia | A | 28 | A | SQL+DBC (5.1 yd) | MATCH |
| 4312 | Tharm | H | 29 | H | SQL+DBC (2.5 yd) | MATCH |
| 4314 | Gorkas | H | 76 | H | SQL+DBC (3.5 yd) | MATCH |
| 4317 | Nyse | H | 30 | H | SQL+DBC (5.4 yd) | MATCH |
| 4319 | Thyssiana | A | 31 | A | SQL+DBC (2.6 yd) | MATCH |
| 4321 | Baldruc | A | 32 | A | SQL+DBC (3.6 yd) | MATCH |
| 4407 | Teloren | A | 33 | A | SQL+DBC (5.1 yd) | MATCH |
| 4551 | Michael Garrett | H | 11 | H | SQL+DBC (2.2 yd) | MATCH |
| 6026 | Breyk | H | 56 | H | SQL+DBC (2.3 yd) | MATCH |
| 6706 | Baritanas Skyriver | A | 37 | A | SQL+DBC (3.1 yd) | MATCH |
| 6726 | Thalon | H | 38 | H | SQL+DBC (3.2 yd) | MATCH |
| 7823 | Bera Stonehammer | A | 39 | A | SQL+DBC (3.7 yd) | MATCH |
| 7824 | Bulkrek Ragefist | H | 40 | H | SQL+DBC (3.8 yd) | MATCH |
| 8018 | Guthrum Thunderfist | A | 43 | A | SQL+DBC (2.3 yd) | MATCH |
| 8019 | Fyldren Moonfeather | A | 41 | A | SQL+DBC (3.6 yd) | MATCH |
| 8020 | Shyn | H | 42 | H | SQL+DBC (2.4 yd) | MATCH |
| 8609 | Alexandra Constantine | A | 45 | A | SQL+DBC (2.4 yd) | MATCH |
| 8610 | Kroum | H | 44 | H | SQL+DBC (2.5 yd) | MATCH |
| 10378 | Omusa Thunderhorn | H | 77 | H | SQL+DBC (3.8 yd) | MATCH |
| 10583 | Gryfe | AH | 79 | HA | SQL+DBC (4.1 yd) | MATCH |
| 10897 | Sindrayl | A | 49 | A | SQL+DBC (5.7 yd) | MATCH |
| 11138 | Maethrya | A | 52 | A | SQL+DBC (1.3 yd) | MATCH |
| 11139 | Yugrek | H | 53 | H | SQL+DBC (2.3 yd) | MATCH |
| 11899 | Shardi | H | 55 | H | SQL+DBC (1.8 yd) | MATCH |
| 11900 | Brakkar | H | 48 | H | SQL+DBC (4.0 yd) | MATCH |
| 11901 | Andruk | H | 58 | H | SQL+DBC (2.8 yd) | MATCH |
| 12577 | Jarrodenus | A | 64 | A | SQL+DBC (3.9 yd) | MATCH |
| 12578 | Mishellena | A | 65 | A | SQL+DBC (2.6 yd) | MATCH |
| 12596 | Bibilfaz Featherwhistle | A | 66 | A | SQL+DBC (3.2 yd) | MATCH |
| 12616 | Vhulgra | H | 61 | H | SQL+DBC (5.5 yd) | MATCH |
| 12617 | Khaelyn Steelwing | A | 67 | A | SQL+DBC (4.8 yd) | MATCH |
| 12636 | Georgia | H | 68 | H | SQL+DBC (4.0 yd) | MATCH |
| 12740 | Faustron | H | 69 | H | SQL+DBC (4.4 yd) | MATCH |
| 13177 | Vahgruk | H | 70 | H | SQL+DBC (3.2 yd) | MATCH |
| 15177 | Cloud Skydancer | A | 73 | A | SQL+DBC (4.8 yd) | MATCH |
| 15178 | Runk Windtamer | H | 72 | H | SQL+DBC (5.1 yd) | MATCH |
| 16227 | Bragok | AH | 80 | HA | SQL+DBC (5.0 yd) | MATCH |
| 52093 | Falok Thurden | A | 176 / 93 | A | SQL+DBC (2.7 yd) | MATCH |
| 52094 | Greta Stonehammer | A | 175 / 92 | A | SQL+DBC (2.8 yd) | MATCH |
| 61132 | Tezzin Skyfuse | AH | 185 / 98 | HA | SQL+DBC (5.4 yd) | MATCH |
| 61133 | Razzit | H | 180 / 94 | H | SQL+DBC (1.3 yd) | MATCH |
| 61532 | Levenda Skytalon | AH | 186 / 99 | HA | SQL+DBC (2.7 yd) | MATCH |
| 61548 | Andana | H | 188 / 101 | H | SQL+DBC (4.8 yd) | MATCH |
| 61549 | Maria Galwest | A | 187 / 100 | A | SQL+DBC (5.6 yd) | MATCH |
| 61623 | Orrik Thunderbeard | A | 197 / 105 | A | SQL+DBC (5.3 yd) | MATCH |
| 62100 | Nelly Cogwheel | A | 103 | A | DBC only (3.1 yd) | MATCH |
| 62101 | Mary Willowfield | H | 102 | H | DBC only (5.9 yd) | MATCH |
| 62147 | Leonhart Hamel | A | 82 | A | DBC only (2.4 yd) | MATCH |
| 62415 | Krangosh Thunderwind | A | 91 | A | DBC only (1.4 yd) | MATCH |
| 62438 | Razikgar | H | 90 | H | DBC only (1.9 yd) | MATCH |
| 62465 | Nundir Feathersoar | A | 83 | A | DBC only (1.5 yd) | MATCH |
| 62574 | Hefeni | H | 88 | H | DBC only (0.7 yd) | MATCH |
| 62624 | Treggi | AH | 89 | H | DBC only (3.6 yd) | FIXED 1.36 |
| 92942 | Grommok | H | — | — | No matched taxi/spawn | No map coordinates |
| 92943 | Vifri Brent | AH | — | — | No matched taxi/spawn | No map coordinates |
| 93100 | Voryn Skystrider | A | 184 / 97 | A | SQL+DBC (4.1 yd) | MATCH |
| 93101 | Vanessa Porter\9 | A | 182 / 95 | A | SQL+DBC (2.6 yd) | MATCH |
| 93102 | Nal'rak | H | 183 / 96 | H | SQL+DBC (1.8 yd) | MATCH |

## Client taxi nodes without a tracked flight-master association

The entries below are **not** a recommendation to display every node as an ordinary flight master. Some are noninteractive transit endpoints and others may be seasonal, class-restricted, or represented by objects. Route counts are from the supplied client TaxiPath.dbc.

| Client node | Name | Mount-slot faction | Outgoing routes | Note |
|---:|---|:---:|---:|---|
| 1 | Northshire Abbey | H | 0 | No route in supplied client |
| 9 | Booty Bay, Stranglethorn | H | 0 | No route in supplied client |
| 15 | Eastern Plaguelands | H | 0 | No route in supplied client |
| 36 | Generic, World target | H | 1 | Transport/special route; not ordinary NPC taxi |
| 57 | Fishing Village, Teldrassil | A | 0 | No route in supplied client |
| 59 | Dun Baldar, Alterac Valley | A | 1 | Battleground endpoint |
| 60 | Frostwolf Keep, Alterac Valley | H | 1 | Battleground endpoint |
| 62 | Nighthaven, Moonglade | A | 1 | Moonglade class-related flight; do not assume general access |
| 63 | Nighthaven, Moonglade | H | 1 | Moonglade class-related flight; do not assume general access |
| 84 | Plaguewood Tower, Eastern Plaguelands | HA | 3 | Plaguelands tower-specific route |
| 85 | Northpass Tower, Eastern Plaguelands | HA | 0 | Plaguelands tower-specific route |
| 86 | Eastwall Tower, Eastern Plaguelands | HA | 0 | Plaguelands tower-specific route |
| 87 | Crown Guard Tower, Eastern Plaguelands | HA | 0 | Plaguelands tower-specific route |
| 112 | Stormwind Harbor, Stormwind | A | 1 | Possible transport/destination-only node; verify |
| 113 | Stormbreaker Point, Balor | A | 0 | Possible transport/destination-only node; verify |
| 116 | Gazzik's Workshop, Blackstone Island | H | 1 | Transport/special route; not ordinary NPC taxi |
| 117 | Sparkwater Port, Durotar | H | 1 | Transport/special route; not ordinary NPC taxi |
| 118 | Canoe: Darkshore - Icepoint Rock | H | 1 | Transport/special route; not ordinary NPC taxi |
| 119 | Canoe: Icepoint Rock - Darkshore | H | 1 | Transport/special route; not ordinary NPC taxi |
| 120 | Narvalis Point, Moonwhisper Coast | A | 3 | Confirm service NPC/availability in game |
| 122 | Shimmerstar Lake, Moonwhisper Coast | HA | 6 | Confirm service NPC/availability in game |
| 123 | Moonhoof Village, Moonwhisper Coast | HA | 1 | Confirm service NPC/availability in game |

## Provenance and limits

- Addon baseline: supplied `Questie-Octo-1.35.zip` (SHA256 `55860c0cadc9e47a48742acf35d8066469b7d91de92fc95ef710ca05338a0000`).
- Turtle server snapshot: `tortoise-wow-main(20260913-143851).zip`, tables `tw_world_creature.sql`, `tw_world_creature_template.sql`, and `tw_world_taxi_nodes.sql`.
- Client snapshot: `DBFilesClient(7).zip`, `TaxiNodes.dbc`, `TaxiPath.dbc` and `WorldMapArea.dbc`. Client node IDs 82–123 do **not** align numerically with later server custom taxi IDs (e.g. client Mudsprocket 94 ↔ server Mudsprocket 180). Match by map/position/name, not ID.
- Addon provenance: `Data/pfDB/meta-turtle.lua`, `Data/pfDB/overwrites-octo.lua`, `Data/runtime/{meta,units,enUS}.lua`, and `Map/ContinentProjection.lua`.
- This is an offline snapshot audit. Neither a live taxi UI nor the exact overlapping-icon owner has been observed for every destination. No assumption that the full client DBC list is a list of available character routes.
