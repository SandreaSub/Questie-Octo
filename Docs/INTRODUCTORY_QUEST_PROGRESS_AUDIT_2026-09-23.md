# Introductory quest progression audit — 2026-09-23

Baseline: Questie-Octo 1.36. Candidate/final correction: 1.37.

## Player report

Yranienko (Discord, 2026-09-23) reported persistent available-quest markers for two introductory quests when their questgivers no longer offered them: 1339 Mountaineer Stormpike's Task and 468 Report to Mountaineer Rockgar. The supplied screenshot is a report, not an in-game reproduction. Public WotLK Wowhead comments describe the same behavior historically; current Turtle server SQL and Turtle website quest series corroborate the chain identities. Live Turtle character-state verification is still pending.

## Root cause

Both compact quest entries in 1.36 contain the forward prerequisite only on their successor: 1338 has `pre={1339}` and 455 has `pre={468}`. The reverse `nextChain` on 1339 and 468 is absent. The existing AvailableQuests:EvaluateQuest() code already suppresses an introduction when `nextChain` is active or known completed; without the reverse link it cannot do that for these two quests. This is not a map clustering or quest-giver position bug.

The supplied Tortoise quest_template.sql (2026-09-13 snapshot) records `NextQuestInChain=1338` for 1339 and `NextQuestInChain=455` for 468. The successor prerequisite in the existing runtime independently agrees in both cases. Turtle public quest-page series corroborate 1339/1338 and 468/455; WotLK Wowhead's old user comments report these precise post-progression offer restrictions. These external historical comments are corroboration, not proof of present live server behavior.

## Fix (narrow)

- `Data/pfDB/enrichment.lua`: add only the two verified reverse `nextChain` relationships, without modifying existing prerequisites or quest starters.
- `Quest/AvailableQuests.lua`: when the existing reverse-link check cannot establish successor completion from cached history, consult `Completion:VerifyOrdinaryCompletionFlag(nextChain,nil)`. This existing method caches positive/negative per-quest answers; it deliberately excludes repeatable, daily, and yearly successors. If it learns a previously missing completion it signals the existing normal refresh path (`learnedCompletionFlag`). Active successors are already detected without the per-quest query.
- No new polling, OnUpdate, quest giver scanning, SavedVariables, clustering, or browser changes.

Expected behavior: an unprogressed character still sees the introduction when otherwise eligible; an active or rewarded successor hides it on map/minimap. This also works when direct per-quest completion is available but bulk completion history omitted the successor. When the per-quest API is unavailable and bulk history is incomplete, it cannot infer undocumented server state; do not invent a completion.

## Broader failure-class census, no bulk promotion

An offline comparison of 5,989 parsable rows in the *supplied snapshot* against 6,704 packaged quests found 1,822 nonzero `NextQuestInChain` edges, of which 1,820 differed from 1.36's compact `nextChain`. 1,815 of those differed edges had reciprocal successor `pre` in the package, five did not. This is a candidate audit population, **not 1,815 verified player-visible bugs or permission to auto-import the snapshot**. The older SQL can disagree with current Turtle behavior; some chains have repeatability, exclusive branches, conditional presentation, or intentionally retained overrides. A future audited offline projection should distinguish those cases before any wider promotion. Only the two user-reported, independently corroborated ordinary breadcrumbs were changed in 1.37.

## Checks and scope

- 38 focused assertions exercised actual shipped `Quest/Completion.lua` and `Quest/AvailableQuests.lua` with packaged quest records for unprogressed, successor active, history completed, direct-flag completed, negative direct flag, intro active/completed, repeatable successor, and unrelated quest scenarios.
- The generated quest runtime differs from 1.36 on **exactly two records**, 468 and 1339. Their sole new field is `nextChain`; all other quest records and all other runtime files remain byte-identical.
- 6,704 quests, 108 maps, and 8,680 links remain unchanged. Preserve source-only salvage archives and the 1.36 flight-master fixes.

### References

- Supplied `tortoise-wow-main(20260913-143851).zip`, `sql/base/tw_world_quest_template.sql`, fields `entry`, `PrevQuestId`, `NextQuestInChain`.
- `https://database.turtlecraft.gg/?quest=1338` and `https://database.turtlecraft.gg/?quest=455` (quest series).
- `https://www.wowhead.com/wotlk/quest=1339/mountaineer-stormpikes-task` and `https://www.wowhead.com/wotlk/quest=468/report-to-mountaineer-rockgar` (historical player observations; not authoritative current Turtle state).
