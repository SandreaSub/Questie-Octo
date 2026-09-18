# Razorfen Kraul Dungeon Quest Type Audit — 1.13

## Trigger

A live report showed **The Gnarled Bramblehide (41759)** available at Calaran Windseeker with Questie-Octo rendering `[31]` instead of `[31+]`. The quest itself and its starter were already present and correct.

## Root cause

Questie-Octo's available-quest `+` marker intentionally uses the compiled server quest type because ClassicAPI quest details can be cache-cold before acceptance. The current Turtle server row for 41759 has `Type = 0`, while its text and objective data unambiguously make it a Razorfen Kraul dungeon quest.

Current objective evidence:

- 41759 requires item **41856 — Gnarled Brambleroot**.
- Item 41856 drops only from creatures **62501** and **62502**.
- Every current coordinate for both creatures is on **AreaTable 491 — Razorfen Kraul**.

Therefore this is stale quest-type metadata rather than a map, availability, or objective-source failure.

## Same-failure-class audit

The merged current Questie-Octo/Turtle objective graph was checked for quests where:

1. server/compiled quest type is normal (`Type = 0`);
2. the quest has objective sources; and
3. every current objective source is confined to Razorfen Kraul (AreaTable 491).

The audit finds exactly three semantic dungeon quests with the stale normal type:

| Quest | Objective evidence | Correction |
|---|---|---|
| 41555 — Razorfen Grog | Required item is sourced only inside RFK | Type 81 |
| 41758 — Tainted Brambleheart | Required item source is only inside RFK | Type 81 |
| 41759 — The Gnarled Bramblehide | Required item sources 62501/62502 are only inside RFK | Type 81 |

Existing correctly typed RFK dungeon quests such as The Crone of the Kraul, A Vengeful Fate, Going, Going, Guano!, Mortality Wanes, and An Unholy Alliance already carry Type 81 and require no correction.

## Implementation

The three verified exceptions are added to the existing build-time elite/dungeon/raid type projection as Type 81. No runtime dungeon inference is introduced.

This preserves the established authority order:

- **active quest:** native Quest Log tag;
- **available/cache-cold quest:** compiled quest type.

## Performance / scope

No polling, `OnUpdate`, scheduler work, map scan, objective scan at runtime, spatial index, or new runtime table is added. Only three existing quest records gain the already-supported numeric `type = 81` field in the compiled runtime.
