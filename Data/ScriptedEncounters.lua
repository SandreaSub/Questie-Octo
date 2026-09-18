-- Sparse presentation-only data for scripted encounters / exploration
-- objectives that do not exist as ordinary creature spawns in the server
-- creature table.
--
-- IMPORTANT: this table must never be treated as quest/gameplay truth. It is
-- only a fallback for map/minimap guidance when the canonical creature record
-- has no usable coordinates. If future server-derived creature coordinates
-- exist, those normal coordinates win automatically.
--
-- Coordinates below are derived from the current Turtle server scripts/spawns
-- and the current client WorldMapArea/AreaTrigger geometry. The custom
-- exploration entries use the invisible GameObject positions that award their
-- real dummy-creature objective credit.
QuestieOcto.ScriptedEncounterData = QuestieOcto.ScriptedEncounterData or {
  -- Wailing Caverns / Mutanus.
  [3654]={
    roles={objectiveCreature=true},
    coords={{45.8,9.2,718}},
    note="Scripted encounter: Mutanus appears near the end of the Naralex event. Defeat the four Fanglords, then speak to the Disciple of Naralex near the instance entrance to begin the escort.",
  },

  -- Turtle custom exploration objectives. These are real creature objectives
  -- credited by custom_exploration_triggers.cpp when the player approaches the
  -- corresponding invisible GameObject. The creatures have no normal spawns.
  [80203]={
    roles={objectiveCreature=true},
    coords={{78.3,72.3,38}},
    displayName="Exploration Objective",
    note="Explore the marked area to complete this quest objective.",
  },
  [70028]={
    roles={objectiveCreature=true},
    coords={{78.5,84.8,331}},
    displayName="Exploration Objective",
    note="Explore the marked area to complete this quest objective.",
  },
  [20120]={
    roles={objectiveCreature=true},
    coords={{72.0,50.4,1}},
    displayName="Exploration Objective",
    note="Explore the marked area to complete this quest objective.",
  },
  [60343]={
    roles={objectiveCreature=true},
    coords={{40.5,81.4,16},{41.5,79.6,16},{39.9,78.9,16}},
    displayName="Exploration Objective",
    note="Explore the marked area to complete this quest objective.",
  },
  [60374]={
    roles={objectiveCreature=true},
    coords={{57.7,13.7,4}},
    displayName="Exploration Objective",
    note="Explore the marked area to complete this quest objective.",
  },
  [60376]={
    roles={objectiveCreature=true},
    coords={{96.9,58.2,46}},
    displayName="Exploration Objective",
    note="Explore the marked area to complete this quest objective.",
  },

  -- Darkshore / Murkdeep. Entering the murloc-camp AreaTrigger begins the
  -- scripted waves that culminate in Murkdeep.
  [10323]={
    roles={objectiveCreature=true},
    coords={{36.6,76.6,148}},
    note="Scripted encounter: enter the murloc camp here to begin the event that summons Murkdeep.",
  },

  -- Duskwood / Twilight Corrupter. The Twilight Grove AreaTrigger summons the
  -- creature while The Nightmare's Corruption is incomplete.
  [15625]={
    roles={objectiveItemSource=true},
    coords={{45.4,51.1,10}},
    note="Scripted encounter: enter the Twilight Grove here to summon the Twilight Corrupter.",
  },

  -- Felwood / The Ancient Leaf. Vartrus is summoned only after the hunter has
  -- completed the quest objective and enters the Irontree Wood trigger. This is
  -- the actual scripted Vartrus spawn position converted to map coordinates.
  [14524]={
    roles={turnin=true},
    coords={{49.0,24.5,361}},
    note="Scripted quest giver: enter Irontree Wood after completing The Ancient Leaf to summon Vartrus and the other Ancients.",
  },

  -- Sunken Temple / Eranikus, Tyrant of Dreams. Malfurion is summoned by
  -- AreaTrigger 4016 after The Charge of the Dragonflights is rewarded and
  -- before quest 8733 is accepted. The position below is his actual scripted
  -- spawn (15 yards from the trigger), converted through current map geometry.
  [15362]={
    roles={available=true},
    coords={{65.3,87.8,1477}},
    note="Scripted quest giver: approach this part of Sunken Temple after completing The Charge of the Dragonflights to summon Malfurion.",
  },
}
