# Questie-Octo Changelog

## 1.03
- Fixed remaining unnecessary minimap work on battleground/other maps where Questie-Octo has no pins to display.
- Starter-less compiled maps with no active objectives now publish an empty map plan immediately instead of queueing an empty zone-priority job.
- Empty minimap plans now stay idle instead of continuously reading player position or probing/retargeting the native minimap context; real quest/objective markers still wake the normal fast path immediately.
- This is a performance-only correction: normal zone quest loading speed and the existing 400-candidate fast ZoneBootstrap behavior are unchanged.

## 1.02
- Hovering an active quest in the tracker now focuses that quest's active objective markers on both the World Map and minimap.
- Other active quests' objective markers fade temporarily while hovered, then return immediately when the cursor leaves the quest.
- Available/completed quests, item-start markers, special quests, Flight Masters, rares, and service markers are never dimmed; shared clustered pins containing the hovered quest stay fully visible.
- The focus effect is presentation-only and uses existing visible pins, so it adds no quest/node rebuild, map scan, polling loop, or navigation delay.

## 1.01
- Fixed a rare map-cleanup error that could occur when quest state changed after the map cache was already updated.
- Reduced unnecessary background work when turning in quests and when reputation, profession, or Hardcore eligibility changes.
- Improved long-session World Map memory behavior by reusing map pins instead of retaining old zone pins and their quest data.
- Reduced map, continent, node, and tooltip refresh work so local quest changes stay local while keeping Questie-Octo's current fast in-game response.

## 1.0.99
- Improved quest accept, abandon, and turn-in map cleanup so removing one quest updates only the maps that quest actually uses instead of walking every prepared map.
- Duplicate removal events for an already-cleared quest no longer trigger another prepared-map revision pass.

## 1.0.98
- Fixed a large FPS hitch when entering starter-less maps such as Warsong Gulch by no longer rescanning all 6,701 quests when the compiled map index already proves there are no available-quest starters there.
- Active quest objectives remain supported on those maps; only the unnecessary available-quest fallback scan is skipped.
- Keeps the validated 1.0.96 Objective Color Vision accessibility modes unchanged.

## 1.0.96
- Added **Other → Accessibility → Objective Color Vision** with Default, Red-deficient, Green-deficient, Blue-deficient, and High Contrast modes.
- Accessibility modes recolor active quest objectives consistently across Full Nodes, Clustered objective colors, and enabled map/minimap glow without changing available, completed, special, rare, or service markers.
- Default mode preserves the validated 1.0.95 quest colors exactly, and changing modes refreshes visible map/minimap pins immediately without rebuilding quest nodes.

## 1.0.95
- Improved per-quest objective colors so dense quest areas use a much wider, easier-to-distinguish palette inspired by pfQuest.
- Full Nodes now use the wider quest color directly instead of muting it toward similar dark/pastel shades.
- Clustered Map/Minimap icon glow now follows the same stable per-quest color, so every objective from one quest shares one visual identity.

## 1.0.94
- Fixed World Map pins being stranded on the two-continent World overview when zooming out faster than an asynchronous continent render could finish.
- The global World texture is now recognized even during the client's brief stale-continent transition, so it can never be mistaken for Kalimdor or map ID 0.
- Abandoning a map render now hides both the last completed pin set and any pins already drawn by the unfinished render.

## 1.0.92
- Shift + Left Click on a quest while typing in chat now inserts a clickable quest link instead of plain quest-name text.
- Normal Shift + Left Click tracking/untracking is unchanged when the chat box is closed.
- Clicking Questie-Octo quest links continues to open the existing detailed quest-link tooltip.

## 1.0.91
- Fixed Quest Log changes such as collapsing/expanding categories being able to publish a mixed active-quest snapshot while Questie-Octo was still scanning the old row layout.
- This prevents unrelated active quests/objectives, timers, and quest-state markers from briefly disappearing because their native Quest Log indices shifted mid-refresh.
- Tracker links now re-check the quest's current Quest Log index before opening it, avoiding a neighbouring quest during the same brief reindex window.

## 1.0.90
- Restored the tracker/objective runtime to the accepted 1.0.85 behavior after the 1.0.87-1.0.89 test fixes did not resolve the rare Quest Log category-collapse case.
- No experimental scroll anchoring or cross-cache objective merging is retained.

## 1.0.85
- Fixed the Artisan secondary-profession master quests being hidden unless their optional city breadcrumb quest had been completed first.
- **Nat Pagle, Angler Extreme**, **Clamlette Surprise**, and both faction versions of **Triage** now appear directly when their own level and profession requirements are met.
- Corrected **To Survive in the Jungle** to its current level-35 minimum while keeping its quest level at 45.

## 1.0.84
- Completed quest `?` markers now always render above available quest `!` markers when their icons overlap on the World Map or minimap.
- Existing quest tooltip grouping, icon sizes, and marker visibility settings are unchanged.

## 1.0.83
- Fixed **Hide Completed Objectives** being ignored for fully completed quests in the tracker.
- With the option OFF, completed objective lines remain visible beneath completed quests; with it ON, they are hidden as expected.

## 1.0.82
- Fixed the `+` difficulty marker for available Elite, Dungeon, and Raid quests that have not yet been loaded into the client quest cache.
- World Map and minimap tooltips now use the server quest type stored in Questie-Octo's compiled data, so dungeon/elite quests such as **The Rampant Groveweald** and **The Unwise Elders** show `[level+]` before acceptance.

## 1.0.81
- Added a `+` beside the quest level in World Map and minimap tooltips for Elite, Dungeon, and Raid quests.
- Available dungeon/elite quests now show the same difficulty cue before they are accepted, while active quests continue to follow the native Quest Log tag.

## 1.0.80
- Reduced item-start quest map clutter by treating drop sources below **1.00%** as rare area markers instead of showing every individual source location.
- Item-start sources at exactly **1.00%** or higher continue to use the normal detailed source presentation.

## 1.0.79
- Improved settings compatibility with large UI/addon stacks by keeping Questie-Octo's Ace configuration runtime references stable after addon load.
- If a required settings library is genuinely unavailable, Questie-Octo now reports which Ace component is missing.

## 1.0.78
- Fixed quest tracker objective names/progress sometimes staying visually stale after the latest quest data had already loaded.
- Fixed the Blizzard/pfUI **Quest Timer** getting stuck at the bottom-left while Questie-Octo's tracker is enabled.
- Questie-Octo now hides the duplicate native timer without taking control of its movable position.

## 1.0.74
- Fixed **The Maul'ogg Crisis I**, **III**, and **IX** not showing the NPC you actually need to speak with on the map.
- These conversation objectives now point to **Lord Cruk'Zogg** or **Seer Bol'ukk** while keeping the server's hidden completion credit unchanged.

## 1.0.73
- Split the World Map quest visibility setting into separate **Available Quests** and **Completed Quests** toggles.
- You can now hide available `!` markers on the World Map while keeping completed `?` turn-ins visible.
- Existing settings are preserved on upgrade, and both new toggles remain enabled by default for the current behavior.

## 1.0.72
- Fixed Questie-Octo marker tooltips not appearing while the native World Map is fullscreen.
- World Map marker hover information now stays available in fullscreen without changing minimap tooltip behavior.

## 1.0.71
- Changed fullscreen World Map refresh handling so pending quest markers can keep processing without needing to minimize the map first.
- The existing World Map pin layout, windowed-map behavior, and minimap logic are otherwise unchanged.

## 1.0.70
- Added generic support for quests that are ordinary on their first completion and become repeatable afterward.
- These quests now show a normal yellow `!` the first time and a blue repeatable `!` only after that character has completed them once.
- Repeatable visibility and quest automation settings apply only after the first completion, with no polling or background work.
- **Oink, Oink!** now uses this confirmed first-time-ordinary / later-repeatable behavior.

## 1.0.69
- Fixed quests that become repeatable after their first completion continuing to show an ordinary yellow quest marker until another map/quest refresh occurred.
- Live-observed repeatable quests now update their existing map and minimap markers immediately, with no polling or background distance/movement work.
- **Oink, Oink!** is now recorded as live-confirmed current Octo content: ordinary on its first completion, then repeatable afterward.

## 1.0.68
- Hid **Join The League!** and **Help The League?** because the current Octo realm keeps those quest IDs as unimplemented placeholder quests.
- Added **Oink, Oink!** and its Pig quest giver for live verification.
- Fixed **Shellcoins** so its completed quest points back to **Elodia** for turn-in.
- Updated **Voryn Skystrider** to the relocated Alah'Thalas flight-master position and removed Baron Rivendare's obsolete Stormwind marker.

## 1.0.66
- Removed the non-functional **Proximity** tracker sorting option.
- Tracker sorting now offers only **Zone** and **Level**, avoiding unnecessary background movement/distance work on the Vanilla Lua client.

## 1.0.65
- Improved **The Burning of Spirits** map guidance so it points to the Burning Blade enemies used with the Burning Gem without showing a fake extra item objective.
- Added the real **Grain Sack** locations for *Attack from the Inside* and **Blast Powder Keg** locations for *A Cannon's Misfortune*.
- **Wisdom of Ur** now points to Arch Druid Dreamwind for its conversation objective.

## 1.0.64
- Quest objective AreaTrigger markers now disappear as soon as their specific exploration/event objective is completed instead of waiting for the entire quest to finish.
- Multiple equivalent exploration locations disappear together when that shared objective is completed.
- Ambiguous/custom trigger cases remain visible until quest completion rather than being hidden from guessed objective matching.

## 1.0.63
- Fixed Lower and Upper Karazhan first-floor quest markers sharing the same internal map identity.
- Questie-Octo now keeps Lower Karazhan and Upper Karazhan objectives on their correct maps when that content is available.
- Tracker **Show on Map** also respects the correct Lower/Upper Karazhan context instead of treating both maps as identical.

## 1.0.62
- Removed unverified center-of-map objective markers for **Ursol** and **Peroth'arn** in Timbermaw Hold.
- Their quests and quest pickup markers remain available normally; only the unsupported boss objective locations are hidden until verified location data exists.

## 1.0.61
- Removed the 1.0.60 dungeon entrance quest markers from outdoor maps; normal objectives in pre-instance caves/tunnels and inside dungeons remain unchanged.
- Dungeon objectives can now use the tracker **Objectives → Show on Map** action when their dungeon/detail map is available to the client, including while inside the dungeon or when another map addon already has that map displayed.

## 1.0.60
- Added dungeon entrance markers for active dungeon quests, so outdoor maps can point to the verified entrance while the dungeon itself continues to show the real quest objectives.
- Dungeons with multiple entrances now choose the doorway that best matches the active objective instead of showing every entrance at once.
- Added entrance guidance for supported Turtle dungeons such as Crescent Grove, Hateforge Quarry, Karazhan Crypt, Gilneas City, Stormwind Vault, and Black Morass alongside the classic dungeon set.

## 1.0.59
- Fixed stray `~` characters sometimes appearing in unrelated item, player, or other GameTooltips after viewing a Questie-Octo tooltip.
- Questie-Octo's centered respawn/drop-rate separator now cleans itself up whenever the tooltip is cleared or hidden.

## 1.0.58
- Fixed **The Sal'Galaz Mines** and **Restoration** missing valid quest objectives.
- Improved **Marauders of Darrowshire** and **Deeprun Rat Roundup** map guidance so they point to the creatures players actually need to hunt or interact with.
- Restored the missing **Furen's Notes** delivery objective for **Klockmort Spannerspan**.

## 1.0.57
- Restored LevelRange-style **Friendly / Hostile / Contested** zone information, based on the player faction.
- Fixed **Westfall** not showing a level-range panel: the current client contains two AreaTable entries named Westfall, so Questie-Octo now resolves continent hovers from the exact native World Map highlight texture before falling back to zone names.
- Audited all 53 supported leveling zones against the current 1.18.1 client map data. Every supported zone has a valid WorldMapArea; the remaining outdoor map contexts are non-leveling entrance/helper/special maps and stay intentionally excluded.
- Current-client faction ownership was audited from AreaTable data, including Turtle zones: Thalassian Highlands is Alliance, Blackstone Island is Horde, and the other supported custom leveling zones are Contested.

## 1.0.56
- Added an optional **Show Zone Level Ranges** World Map feature under **Other → Interface**, directly above Dark Theme.
- Updated the integrated Turtle zone list for the current 1.18.1 client, adding **Moonwhisper Coast (50–56)** and the previously missing **Icepoint Rock (40–50)**.
- Zone hover matching now uses current client map IDs/localized area data instead of relying on English zone-name keys, including the old Northwind trailing-space edge case.
- The integration is intentionally focused on zone level ranges; LevelRange-Turtle's separate fishing/instance/raid option system is not imported.

## 1.0.55
- Rebuilt static quest-objective locations for **Windhorn Canyon, Timbermaw Hold, and Frostmane Hollow** from the current Octo client map data and current Turtle server spawns.
- Fixed the inherited `50,50` placeholder markers in those instances and restored missing quest-object locations, including all **Windhorn Relics** and the **Tablet of Kaz'gan**.
- Completed a wider instance/entrance audit. Ambiguous helper-map projection, unavailable content, and scripted encounters without ordinary server spawns were deliberately left unchanged rather than guessed.
- If you are updating directly from 1.0.53, this build also includes 1.0.54's fix for stale completed-quest history after Hardcore restarts or delete/recreate cases at level 1 with 0 XP.

## 1.0.54
- Fixed old completed-quest history carrying over when a character starts fresh at level 1 with 0 XP, including Hardcore restarts and delete/recreate cases that reuse the same character name.
- Questie-Octo now discards only the inherited completion/reset history for that unmistakably fresh character state, then rebuilds completion state from the current server character.
- Settings, tracker position, UI preferences, and other character options are preserved.

## 1.0.53
- Fixed moving party/teammate markers appearing to blink or snap on the minimap while the player was moving continuously.
- Our mistake was leaving an old Vanilla indoor/outdoor detection trick inside minimap movement rediscovery; it briefly changed the native minimap zoom and forced Blizzard's own moving markers to redraw.
- Questie-Octo now keeps normal movement updates read-only and only settles that minimap state when the minimap or zone context actually changes. The 1.0.49 performance improvements remain in place.

## 1.0.52
- Fixed tracker objectives occasionally appearing as only `: 0/10` (or similar) after logging in.
- Our mistake was trusting the first Quest Log snapshot too early, before Turtle had always finished loading objective names.
- Questie-Octo now rechecks the Quest Log during the first few seconds after login while keeping the lower-memory compiled runtime.

## 1.0.51
- Temporarily disabled **In Search of Solar Knowledge (40795)** from appearing as an available quest because current live-realm behavior does not match the bundled database.
- The quest data is retained so it can be restored easily when its live availability is confirmed.

## 1.0.50
- Added a right-click menu to quests in the tracker.
- Use **Objectives → Show on Map** to open the World Map to an unfinished objective.
- Completed quests can use **Show on Map** to locate their turn-in.
- Existing left-click and Shift+Left Click tracker controls are unchanged.
