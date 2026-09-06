-- Questie-Octo canonical quest model.
-- Questie-facing semantic model over pfQuest/Tortoise quest truth.

QuestieOcto.QuestModel = QuestieOcto.QuestModel or {}
local QM = QuestieOcto.QuestModel

QM.cache = {}

local function CopyArray(src)
  if not src then return nil end
  local out={}
  local keys={}

  -- These sources are arrays, but pairs() does not guarantee their numeric
  -- order on Lua 5.0. Preserve the database/compiler order explicitly so
  -- objective #1/#2 cannot be swapped before BuildObjectiveData consumes it.
  for k in pairs(src) do
    if type(k)=="number" then table.insert(keys,k) end
  end
  table.sort(keys)

  for i=1,table.getn(keys) do
    table.insert(out,src[keys[i]])
  end
  return out
end

local function CopyGroups(src)
  if not src then return nil end
  local out={}
  for _,group in pairs(src) do
    table.insert(out,CopyArray(group) or {})
  end
  return out
end

-- Supplied Questie 3.3.5 classic corrections:
-- these quests have their item objective before the normal category order.
local ITEM_OBJECTIVE_FIRST={
  [503]=true,
  [5088]=true,
}

-- Quests that are not normal static NPC offers. Questie 6 blacklists these
-- because the NPC only exposes the quest after a scripted world interaction.
-- Keeping the real starter relation is useful for quest truth/tooltips, but it
-- must not become a permanent map pickup marker.
local CONDITIONAL_OFFERS={
  [3861]="Use /chicken on a Chicken until it temporarily offers CLUCK!.",
  [7946]="Requires Jubjub to be lured back with Dark Iron Ale.",
}

-- Some situational quests benefit from one deliberately chosen discovery marker
-- without pretending every scripted source is a permanent questgiver. CLUCK! can
-- be triggered from many Chickens, but the Westfall Chicken at 55.6,30.9 is used
-- as the single representative pickup/turn-in marker so new players can discover
-- that the quest exists without covering every Chicken spawn with quest icons.
-- The underlying starter/finisher relation remains NPC 620 and server truth is
-- unchanged; this table is presentation only.
local CONDITIONAL_MAP_MARKERS={
  [3861]={
    creatureID=620,
    coords={{55.6,30.9,40,300}},
  },
}

-- Server repeatability and map presentation are separate. CLUCK! is technically
-- repeatable, but Questie-Octo already treats it as one-and-done after the first
-- completion. Present any marker that is legitimately shown for it as an
-- ordinary yellow quest rather than a blue repeatable quest.
local NORMAL_REPEATABLE_PRESENTATION={
  [3861]=true,
}

local function AddObjectiveData(list,kind,id)
  if not id then return end

  local typ=nil
  if kind=="creature" then typ="monster"
  elseif kind=="gameObject" then typ="object"
  elseif kind=="item" then typ="item"
  end

  table.insert(list,{
    kind=kind,
    type=typ,
    id=id
  })
end

local function BuildObjectiveData(questID,objectives)
  local result={}
  local itemFirst=ITEM_OBJECTIVE_FIRST[questID] and true or false

  if itemFirst then
    for i=1,table.getn(objectives.item or {}) do
      AddObjectiveData(result,"item",objectives.item[i])
    end
  end

  -- Questie 3.3.5/7/8 DB compiler category order.
  for i=1,table.getn(objectives.creature or {}) do
    AddObjectiveData(result,"creature",objectives.creature[i])
  end

  for i=1,table.getn(objectives.gameObject or {}) do
    AddObjectiveData(result,"gameObject",objectives.gameObject[i])
  end

  if not itemFirst then
    for i=1,table.getn(objectives.item or {}) do
      AddObjectiveData(result,"item",objectives.item[i])
    end
  end

  return result
end

local function IsLevelPlusQuestType(questType)
  questType=tonumber(questType)
  return questType==1 or questType==62 or questType==81
end

function QM:HasLevelPlus(questID,nativeTag)
  -- The native Quest Log tag remains authoritative whenever the client
  -- supplies one. Some Turtle custom quests have stale client/server type
  -- metadata, however, while Questie-Octo carries an audited Type 1/62/81
  -- projection for map presentation. Reuse that same projection for the
  -- Quest Log and tracker so every surface shows a consistent [level+] cue.
  if nativeTag and nativeTag~="" then return true end
  questID=tonumber(questID)
  if not questID then return false end
  local q=self:Get(questID)
  return q and IsLevelPlusQuestType(q.questType) or false
end

function QM:Clear()
  self.cache={}
end


local function ObservedRepeatables()
  QuestieOctoGlobalDB=QuestieOctoGlobalDB or {}
  QuestieOctoGlobalDB.observedRepeatableQuests=QuestieOctoGlobalDB.observedRepeatableQuests or {}
  return QuestieOctoGlobalDB.observedRepeatableQuests
end

local function CompletedOnce(questID)
  questID=tonumber(questID)
  if not questID then return false end
  if QuestieOcto.Completion and QuestieOcto.Completion.IsEverComplete then
    return QuestieOcto.Completion:IsEverComplete(questID) and true or false
  end
  local completed=QuestieOctoDB and QuestieOctoDB.completed
  return completed and completed[questID] and true or false
end

function QM:IsRepeatableAfterFirstCompletionRaw(questID,raw)
  questID=tonumber(questID)
  raw=raw or (questID and QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:GetQuestRaw(questID)) or nil
  return raw and raw["repeatableAfterFirstCompletion"] and true or false
end

function QM:IsRepeatableRaw(questID,raw)
  questID=tonumber(questID)
  raw=raw or (questID and QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:GetQuestRaw(questID)) or nil
  if not raw then return false end

  -- Some quests are ordinary one-time offers on a character's first completion
  -- and only become repeatable afterward. That transition is character-local,
  -- so it must never inherit QuestieOctoGlobalDB's observed-repeatable state
  -- from another character. The explicit database semantic wins here.
  if raw["repeatableAfterFirstCompletion"] then
    return CompletedOnce(questID)
  end

  return (raw["repeatable"] or (questID and ObservedRepeatables()[questID])) and true or false
end

function QM:GetConditionalOffer(questID)
  return CONDITIONAL_OFFERS[tonumber(questID)]
end

function QM:GetConditionalMapMarker(questID)
  return CONDITIONAL_MAP_MARKERS[tonumber(questID)]
end

function QM:IsNormalRepeatablePresentation(questID)
  return NORMAL_REPEATABLE_PRESENTATION[tonumber(questID)] and true or false
end

function QM:MarkObservedRepeatable(questID)
  questID=tonumber(questID)
  if not questID then return false end

  -- Known repeatable-after-first-completion quests use character completion
  -- history instead of the global observation cache. This prevents one
  -- character's completed quest from making another character's first offer
  -- blue/repeatable.
  if self:IsRepeatableAfterFirstCompletionRaw(questID,nil) then return false end

  local db=ObservedRepeatables()
  if db[questID] then return false end
  db[questID]=true
  if self.cache[questID] then
    self.cache[questID].repeatable=true
    self.cache[questID].presentationRepeatable=not NORMAL_REPEATABLE_PRESENTATION[questID]
  end

  -- Repeatability is presentation state as well as an availability filter.
  -- An observed quest can stay in the available set before and after this
  -- transition, so AvailableQuests' membership-only diff has nothing to report.
  -- Refresh just this quest's already-published nodes immediately so an ordinary
  -- yellow pickup can become the blue repeatable pickup without a reload, map
  -- change, or unrelated quest-state change. This is event-driven and allocates
  -- no background ticker/cache.
  if QuestieOcto.Nodes and QuestieOcto.Nodes.RefreshAvailability
     and QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.available
     and QuestieOcto.AvailableQuests.available[questID] then
    QuestieOcto.Nodes:RefreshAvailability({[questID]=true})
  end

  if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.Schedule then
    QuestieOcto.AvailableQuests:Schedule(true,0.02)
  end
  return true
end

function QM:Get(questID)
  questID=tonumber(questID) or questID
  if self.cache[questID] then
    local cached=self.cache[questID]
    local repeatable=self:IsRepeatableRaw(questID,nil)
    if cached.repeatable~=repeatable then
      cached.repeatable=repeatable
      cached.presentationRepeatable=repeatable and not NORMAL_REPEATABLE_PRESENTATION[tonumber(questID)] and true or false
    end
    return cached
  end
  if not QuestieOcto.DatabaseAPI:IsReady() then return nil end

  local raw=QuestieOcto.DatabaseAPI:GetQuestRaw(questID)
  if not raw then return nil end

  local q={
    id=questID,
    title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID),
    descriptionText=QuestieOcto.DatabaseAPI.GetQuestDescriptionText and QuestieOcto.DatabaseAPI:GetQuestDescriptionText(questID) or nil,
    objectiveText=QuestieOcto.DatabaseAPI.GetQuestObjectiveText and QuestieOcto.DatabaseAPI:GetQuestObjectiveText(questID) or nil,

    -- lvl is the displayed quest level. min/max are the actual server
    -- acceptance bounds and are deliberately kept separate.
    level=tonumber(raw["lvl"] or 0) or 0,
    requiredLevel=tonumber(raw["min"] or 0) or 0,
    maximumLevel=tonumber(raw["max"] or 0) or 0,

    -- Questie 6 uses quest Type 41 as the canonical PvP classification.
    -- This comes from the authoritative Turtle enrichment, including only
    -- verified local corrections for misclassified custom PvP quests.
    questType=tonumber(raw["type"] or 0) or 0,
    pvp=(tonumber(raw["type"] or 0) or 0)==41,

    raceMask=raw["race"],
    classMask=raw["class"],
    requiredSkill=raw["skill"],
    requiredSkillValue=tonumber(raw["skillValue"] or 1) or 1,
    repMinFaction=tonumber(raw["repMinFaction"]),
    repMinValue=tonumber(raw["repMinValue"] or 0) or 0,
    repMaxFaction=tonumber(raw["repMaxFaction"]),
    repMaxValue=tonumber(raw["repMaxValue"] or 0) or 0,

    -- Preserve the authoritative raw event association, but normalize the two
    -- Darkmoon Faire location IDs into one logical event for every runtime
    -- consumer. Turtle/pfQuest reuse the same Faire NPCs and quest offers at
    -- both Elwynn and Mulgore while many shared quest rows are inconsistently
    -- tagged as event 4 or event 5. Keeping rawEventID makes diagnostics lossless;
    -- eventID is the logical availability/presentation identity.
    rawEventID=tonumber(raw["event"]),
    eventID=(tonumber(raw["event"])==5 and 4 or tonumber(raw["event"])),
    event=raw["event"],
    repeatable=self:IsRepeatableRaw(questID,raw),
    repeatableAfterFirstCompletion=raw["repeatableAfterFirstCompletion"] and true or false,
    hideAfterFirstCompletion=raw["hideAfterFirstCompletion"] and true or false,
    daily=raw["daily"] and true or false,
    yearly=raw["yearly"] and true or false,
    hardcore=raw["hardcore"] and true or false,
    timed=raw["timed"] and true or false,
    disabled=raw["disabled"] and true or false,
    conditionalOffer=self:GetConditionalOffer(questID),
    conditionalMapMarker=self:GetConditionalMapMarker(questID),
    exclusive=raw["exclusive"] and true or false,
    nextChain=tonumber(raw["nextChain"]),

    -- pfQuest's ordinary pre remains OR semantics. The enrichment restores
    -- signed active predecessors and negative ExclusiveGroup all-of groups
    -- separately so their server meaning is not flattened again.
    preQuestSingle=CopyArray(raw["pre"]),
    preQuestActive=CopyArray(raw["preActive"]),
    preQuestAll=CopyGroups(raw["preAll"]),

    -- close is only authoritative when the migrated server still marks the
    -- quest as a positive ExclusiveGroup member (q.exclusive=true).
    exclusiveTo=CopyArray(raw["close"]),

    starts={
      creature=raw["start"] and CopyArray(raw["start"]["U"]) or nil,
      gameObject=raw["start"] and CopyArray(raw["start"]["O"]) or nil,
      item=raw["start"] and CopyArray(raw["start"]["I"]) or nil,
    },

    finishes={
      creature=raw["end"] and CopyArray(raw["end"]["U"]) or nil,
      gameObject=raw["end"] and CopyArray(raw["end"]["O"]) or nil,
    },

    objectives={
      creature=raw["obj"] and CopyArray(raw["obj"]["U"]) or nil,
      gameObject=raw["obj"] and CopyArray(raw["obj"]["O"]) or nil,
      item=raw["obj"] and CopyArray(raw["obj"]["I"]) or nil,
      irItems=raw["obj"] and CopyArray(raw["obj"]["IR"]) or nil,
      -- A = quest-bound AreaTrigger objective. This is deliberately distinct
      -- from generic map exploration/fog data: only triggers referenced by an
      -- actual quest are retained here.
      areaTrigger=raw["obj"] and CopyArray(raw["obj"]["A"]) or nil,
    },
  }

  -- Keep server repeatability authoritative for completion/filtering while
  -- allowing a narrow presentation exception such as CLUCK!.
  q.presentationRepeatable=q.repeatable and not NORMAL_REPEATABLE_PRESENTATION[tonumber(questID)] and true or false
  -- CLUCK! was explicitly chosen to stay an ordinary yellow discovery marker.
  -- Keep that presentation exception independent from the Turtle low-level gray
  -- marker rule so a high-level player does not turn its representative marker gray.
  q.presentationAlwaysNormal=NORMAL_REPEATABLE_PRESENTATION[tonumber(questID)] and true or false

  -- IR items are intentionally NOT added to objectiveData. They are a
  -- pfQuest-special interaction relationship that becomes target guidance
  -- only while the player actually possesses the required item.
  q.objectiveData=BuildObjectiveData(questID,q.objectives)

  self.cache[questID]=q
  return q
end
