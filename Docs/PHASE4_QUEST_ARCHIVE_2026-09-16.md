# Questie-Octo — Phase 4 Turtle salvage audit (source archive only)

**Base:** 1.29. **Scope:** follow the 74 preserved container-loot rows upstream, classify the 55 unresolved item starters against additional SQL relationships, and preserve individually verified indexed public quest-page observations. **Gameplay:** unchanged.

## Item-source provenance, without invented markers

- The 72 quest-starting items already archived inside containers map to **14 unique parent items**. 12 of these parents have at least one reference in the examined original server SQL tables. Source categories for parents (non-exclusive): {'creature_loot': 1, 'none_in_selected_tables': 2, 'quest_reward': 8, 'nested_item': 3}. Each parent preserves the matching original loot/vendor relations and full upstream quest-template rows, where available. This represents container → parent → upstream reference, *not* a claimed mob-to-quest-item drop.
- The previous **55** starter items with no compiled direct source and no SQL item-container link now have other server-SQL references for **32** of them; **23** have no reference in the specifically checked tables. These are not equivalent to missing markers: source-item grants, previous quest rewards, vendor stock and mailed items may not have outdoor spawn positions. The archive includes full snapshot item-template rows to preserve original context.
- Example: Silithus logistics/tactical assignment envelopes are downstream of quest reward items; Pirate's Footlocker is separately represented as creature loot in this SQL snapshot. The snapshot does not establish any current live drop rate or whether a character can still obtain these quests.
- Every original SQL file used has a SHA-256 fingerprint; archived quest-template references retain their original field identity, keeping `SrcItemId` separate from guaranteed and choice rewards.

## Public Turtle quest pages

- Saved **19 additional individual indexed quest-page observations**; **18** correspond to quests already in the addon but absent from the supplied server SQL snapshot. The 17 earlier Phase 3 observations and three Phase 2 observations remain intact.
- Records preserve observed level/minimum level, XP, *max-level conversion money* (not ordinary reward money), specified item/kill counts, repeatability, named prerequisite/follow-up links and distinctions between choice and fixed rewards where directly visible.
- Website data is indexed/crawled, not live verification. Named rewards have no claimed numeric item ID. No unobserved objective quantities, source coordinates, reputation factions, or item drop chances are inferred.

## Strict safety

`Data/archive/quest_salvage_phase4_2026-09-16.json` is **source-only** and is not present in the TOC, compiler inputs or the GitHub/player ZIP. Existing phase 2/3 archives are preserved byte-for-byte. Only the archive, this report, TOC version and engineering changelog differ from 1.29; all other files, including the compiled runtime and rewards, must be byte-identical. This is not a complete public website roster and does not establish whether any archival quest is live-obtainable.
