# Questie-Octo Tracker-Hover Objective Focus Audit

**Version:** 1.02  
**Baseline:** accepted 1.01

## Scope

Implement the approved tracker-hover backlog behavior without changing Questie-Octo's fast-response architecture.

## Behavior

- Hovering an active quest title uses its numeric quest ID as the transient focus key.
- World Map and minimap active objective pins belonging only to other quests fade to 30% alpha.
- Pins containing the hovered quest stay at normal opacity, including clustered/shared pins that also contain other quests.
- Any pin containing a non-objective semantic entry stays at normal opacity, protecting available/completed/item-start/special/service/rare presentation.
- Leaving the quest row or hiding the tracker clears focus immediately.

## Performance boundary

Hover does not rebuild Nodes, PreparedMap, clustering, availability, minimap discovery, or map context. It only updates the alpha of the currently active World Map and minimap pin pools. No recurring timer or polling path was introduced.

## Compatibility

The implementation uses the existing Questie-Octo tracker rows and existing `Visuals:SetAlpha` presentation path. Full Nodes preserve their existing 0.85 opacity multiplier. No external addon source code was copied.
