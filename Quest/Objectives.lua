QuestieOcto.Objectives = QuestieOcto.Objectives or {}
local O = QuestieOcto.Objectives

O.byQuest={}
O.ready=false
O.running=false
O.pending=false
O.generation=0
O.stats={
  quests=0, creature=0, object=0, item=0, areaTrigger=0, itemSources=0, irTargets=0,
  areaTriggerMapped=0, areaTriggerUnmapped=0,
  mapped=0, unmapped=0, direct=0, fallback=0, fuzzy=0, single=0, typeMismatch=0,
  rebuilds=0, dependencyWaits=0
}
O.irItems=O.irItems or {}
O.irItemQuests=O.irItemQuests or {}
O.irPresence=O.irPresence or {}
O.irPresenceScratch=O.irPresenceScratch or {}
O.irChangedItems=O.irChangedItems or {}
O.irAffectedQuests=O.irAffectedQuests or {}
O.irTrackedCount=0
O.irRegistryDirty=true
O.irStats=O.irStats or {bagEvents=0,bagScans=0,bagSkips=0,changedScans=0}

local MIN_DROP_CHANCE=1

local function ResetStats()
  local rebuilds=O.stats.rebuilds or 0
  local waits=O.stats.dependencyWaits or 0
  O.stats={
    quests=0, creature=0, object=0, item=0, areaTrigger=0, itemSources=0, irTargets=0,
    areaTriggerMapped=0, areaTriggerUnmapped=0,
    mapped=0, unmapped=0, direct=0, fallback=0, fuzzy=0, single=0, typeMismatch=0,
    rebuilds=rebuilds, dependencyWaits=waits
  }
end

local function DependenciesReady()
  return QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:IsReady()
    and QuestieOcto.QuestLog and QuestieOcto.QuestLog.snapshot
end

local function AddSource(list,kind,id,itemID,chance,vendor)
  table.insert(list,{kind=kind,id=id,itemID=itemID,chance=chance,vendor=vendor and true or false})
end

local function AddUniqueSource(list,seen,kind,id,itemID,chance,vendor)
  local key=kind..":"..tostring(id)
  if seen[key] then return end
  seen[key]=true
  AddSource(list,kind,id,itemID,chance,vendor)
  O.stats.itemSources=O.stats.itemSources+1
end

-- pfQuest SearchItemID semantics: direct creature/object drops above the
-- configured threshold, reference-loot owners, and vendors. The original
-- pfQuest default threshold is 1%, which we preserve here without adding a
-- new player-facing option.
local function ResolveItemSources(questID,itemID)
  local result={}
  local seen={}
  local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)

  if sources and sources.Creature then
    for creatureID,chance in pairs(sources.Creature) do
      chance=tonumber(chance) or 0
      if chance>=MIN_DROP_CHANCE then
        AddUniqueSource(result,seen,"creature",creatureID,itemID,chance,false)
      end
    end
  end

  if sources and sources.GameObject then
    for objectID,chance in pairs(sources.GameObject) do
      chance=tonumber(chance) or 0
      if chance>=MIN_DROP_CHANCE and chance>0 then
        AddUniqueSource(result,seen,"gameObject",objectID,itemID,chance,false)
      end
    end
  end

  if sources and sources.Reference then
    for refID,chance in pairs(sources.Reference) do
      chance=tonumber(chance) or 0
      if chance>=MIN_DROP_CHANCE then
        local ref=QuestieOcto.DatabaseAPI:GetReferenceLootRaw(refID)
        if ref and ref["U"] then
          for creatureID in pairs(ref["U"]) do
            AddUniqueSource(result,seen,"creature",creatureID,itemID,chance,false)
          end
        end
        if ref and ref["O"] then
          for objectID in pairs(ref["O"]) do
            AddUniqueSource(result,seen,"gameObject",objectID,itemID,chance,false)
          end
        end
      end
    end
  end

  if sources and sources.Vendor then
    for creatureID in pairs(sources.Vendor) do
      AddUniqueSource(result,seen,"creature",creatureID,itemID,nil,true)
    end
  end

  -- Poisoned Water (6804): Discordant Bracers (17309) belong to the temporary
  -- Discordant Surge (13279), which has no natural world spawn. The quest text
  -- sends the player to use Aspect of Neptulon on poisoned elementals, and the
  -- updated pfQuest-octo 1.1.0 audit identifies Blighted Surge (8519) as the
  -- actionable source. Keep 17309 as the real live item objective and add only
  -- 8519's physical positions as presentation guidance.
  if tonumber(questID)==6804 and tonumber(itemID)==17309 then
    AddUniqueSource(result,seen,"creature",8519,itemID,nil,false)
  end

  -- Marauders of Darrowshire (5206): the current server requires five
  -- Resonating Skulls (13155) plus the Mystic Crystal (13156). The player
  -- obtains those skulls by testing Fetid Skulls (13157), whose physical
  -- source is the useful hunting target. Keep the formal server objectives
  -- intact and use the current Fetid Skull source, Scourge Champion (8529),
  -- only as presentation guidance for the Resonating Skull objective. Do not
  -- display the Fetid Skull's 80% drop chance as if it were the conversion
  -- chance for a Resonating Skull.
  if tonumber(questID)==5206 and tonumber(itemID)==13155 then
    AddUniqueSource(result,seen,"creature",8529,itemID,nil,false)
  end

  return result
end

local function ClearTable(tbl)
  if not tbl then return {} end
  for key in pairs(tbl) do tbl[key]=nil end
  return tbl
end

local function ItemIDFromLink(link)
  if not link then return nil end
  local _,_,id=string.find(link,"item:(%d+)")
  return tonumber(id)
end

local function PlayerHasItem(itemID)
  itemID=tonumber(itemID)
  if not itemID then return false end

  if GetContainerNumSlots and GetContainerItemLink then
    for bag=0,4 do
      local slots=GetContainerNumSlots(bag) or 0
      for slot=1,slots do
        if ItemIDFromLink(GetContainerItemLink(bag,slot))==itemID then return true end
      end
    end
  end

  if GetInventoryItemLink then
    for slot=1,19 do
      if ItemIDFromLink(GetInventoryItemLink("player",slot))==itemID then return true end
    end
  end

  return false
end

-- IR dependencies are rare, so keep a tiny active-quest registry instead of
-- rescanning every active quest after every inventory event. Presence is built
-- with one pass over bags/equipment for all tracked IR items together.
local function RefreshIRRegistry()
  local items=ClearTable(O.irItems)
  local itemQuests=ClearTable(O.irItemQuests)
  local trackedCount=0

  for questID in pairs(QuestieOcto.QuestLog.active or {}) do
    local q=QuestieOcto.QuestModel:Get(questID)
    if q and q.objectives and q.objectives.irItems then
      for _,itemID in pairs(q.objectives.irItems) do
        itemID=tonumber(itemID)
        if itemID and itemID>0 then
          if not items[itemID] then
            items[itemID]=true
            trackedCount=trackedCount+1
          end
          local quests=itemQuests[itemID]
          if not quests then
            quests={}
            itemQuests[itemID]=quests
          end
          quests[tonumber(questID) or questID]=true
        end
      end
    end
  end

  O.irItems=items
  O.irItemQuests=itemQuests
  O.irTrackedCount=trackedCount
  return trackedCount
end

local function ScanIRPresence()
  local tracked=O.irItems or {}
  local trackedCount=tonumber(O.irTrackedCount) or 0
  local current=ClearTable(O.irPresenceScratch)
  local changed=ClearTable(O.irChangedItems)
  O.irPresenceScratch=current
  O.irChangedItems=changed

  if trackedCount<=0 then
    O.irPresence=ClearTable(O.irPresence)
    return nil
  end

  O.irStats.bagScans=(O.irStats.bagScans or 0)+1
  local foundCount=0

  if GetContainerNumSlots and GetContainerItemLink then
    local bag=0
    while bag<=4 and foundCount<trackedCount do
      local slots=GetContainerNumSlots(bag) or 0
      local slot=1
      while slot<=slots and foundCount<trackedCount do
        local itemID=ItemIDFromLink(GetContainerItemLink(bag,slot))
        if itemID and tracked[itemID] and not current[itemID] then
          current[itemID]=true
          foundCount=foundCount+1
        end
        slot=slot+1
      end
      bag=bag+1
    end
  end

  if foundCount<trackedCount and GetInventoryItemLink then
    local slot=1
    while slot<=19 and foundCount<trackedCount do
      local itemID=ItemIDFromLink(GetInventoryItemLink("player",slot))
      if itemID and tracked[itemID] and not current[itemID] then
        current[itemID]=true
        foundCount=foundCount+1
      end
      slot=slot+1
    end
  end

  local previous=O.irPresence or {}
  local changedAny=false
  for itemID in pairs(tracked) do
    local present=current[itemID] and true or false
    current[itemID]=present
    if previous[itemID]~=present then
      changed[itemID]=true
      changedAny=true
    end
  end

  -- Reuse both presence tables instead of allocating a new snapshot for every
  -- bag event. The old presence table becomes next scan's scratch table.
  O.irPresenceScratch=previous
  O.irPresence=current

  if changedAny then
    O.irStats.changedScans=(O.irStats.changedScans or 0)+1
    return changed
  end
  return nil
end

local function RefreshIRRegistryAndPresence()
  RefreshIRRegistry()
  ScanIRPresence()
end

local function TrackedIRItemPresent(itemID)
  itemID=tonumber(itemID)
  if not itemID then return false end
  local present=O.irPresence and O.irPresence[itemID]
  if present~=nil then return present and true or false end
  -- Defensive fallback for a dependency resolved before the active IR registry
  -- is initialized. Normal rebuild/refresh paths populate the shared snapshot
  -- before ResolveQuest, so this should not be a hot-path inventory scan.
  return PlayerHasItem(itemID)
end

local function BuildIRTargets(q)
  local targets={}
  local skipCreature={}
  local skipObject={}

  for _,itemID in pairs(q.objectives.irItems or {}) do
    local requirement=QuestieOcto.DatabaseAPI:GetQuestItemRequirementRaw(itemID)
    if requirement then
      local hasItem=TrackedIRItemPresent(itemID)
      for signedID in pairs(requirement) do
        signedID=tonumber(signedID)
        if signedID and signedID<0 then
          local id=math.abs(signedID)
          skipObject[id]=true
          if hasItem then
            table.insert(targets,{kind="gameObject",id=id,itemID=itemID,ir=true})
          end
        elseif signedID and signedID>0 then
          skipCreature[signedID]=true
          if hasItem then
            table.insert(targets,{kind="creature",id=signedID,itemID=itemID,ir=true})
          end
        end
      end
    end
  end

  return targets,skipCreature,skipObject
end

local function NormalizeLogType(typ)
  typ=string.lower(tostring(typ or ""))
  if typ=="monster" or typ=="creature" or typ=="kill" then return "creature" end
  if typ=="item" then return "item" end
  if typ=="object" or typ=="gameobject" then return "gameObject" end
  return typ
end

-- Sparse presentation-only corrections for capture/transform objectives where
-- the server awards quest credit against a temporary NPC entry that has no
-- natural spawn points. Keep the authoritative live objective ID for progress
-- and completion; only map/minimap guidance uses the actionable source entity.
--
-- Plagued Lands (2118): Tortoise darkshore.cpp handles spell 9439 by changing
-- Rabid Thistle Bear (2164) into Captured Rabid Thistle Bear (11836), then
-- awards KilledMonsterCredit for 11836. The player must therefore find 2164,
-- while 11836 remains the correct completion target in the quest log/database.
-- Deeprun Rat Roundup (6661): the server's formal objective is Enthralled
-- Deeprun Rat (13017), but players create that state by using the Rat Catcher's
-- Flute on normal Deeprun Rats (13016). Guide to 13016 without rewriting the
-- live completion target.
local CREATURE_OBJECTIVE_SOURCE_OVERRIDES={
  [2118]={ [11836]={kind="creature",id=2164} },
  [6661]={ [13017]={kind="creature",id=13016} },

  -- Attack from the Inside (40099): Grain Sack 2010824 awards the formal
  -- hidden credit creature 60323 when poisoned with Grelda's Poison Vial.
  [40099]={ [60323]={kind="gameObject",id=2010824} },

  -- A Cannon's Misfortune (40174): Blast Powder Keg 2010834 awards the
  -- formal hidden credit creature 60328 when sabotaged with Special Water.
  [40174]={ [60328]={kind="gameObject",id=2010834} },

  -- The Maul'ogg Crisis I (40264): speaking with Lord Cruk'Zogg completes
  -- the formal hidden credit creature 60337. Guide to Cruk'Zogg himself.
  [40264]={ [60337]={kind="creature",id=92180} },

  -- The Maul'ogg Crisis III (40266): completing Seer Bol'ukk's dialogue awards
  -- the formal hidden credit creature 60338. Guide to Bol'ukk himself.
  [40266]={ [60338]={kind="creature",id=91854} },

  -- The Maul'ogg Crisis IX (40272): giving the Elixir of Insom'ni to Lord
  -- Cruk'Zogg awards the formal hidden credit creature 60339. Guide to him.
  [40272]={ [60339]={kind="creature",id=92180} },

  -- Wisdom of Ur (41383): completing Arch Druid Dreamwind's dialogue awards
  -- the formal hidden credit creature 60056. Guide to Dreamwind himself.
  [41383]={ [60056]={kind="creature",id=61512} },
}

local function PresentationCreatureSource(questID,objectiveID)
  local byQuest=CREATURE_OBJECTIVE_SOURCE_OVERRIDES[tonumber(questID)]
  local source=byQuest and byQuest[tonumber(objectiveID)]
  if type(source)=="table" and tonumber(source.id) then
    return source.kind or "creature",tonumber(source.id)
  end
  return "creature",tonumber(objectiveID)
end

local function Levenshtein(str1,str2)
  str1=string.lower(tostring(str1 or ""))
  str2=string.lower(tostring(str2 or ""))
  local len1=string.len(str1)
  local len2=string.len(str2)
  local matrix={}
  local cost=0
  if len1==0 then return len2 end
  if len2==0 then return len1 end
  if str1==str2 then return 0 end
  for i=0,len1 do matrix[i]={}; matrix[i][0]=i end
  for j=0,len2 do matrix[0][j]=j end
  for i=1,len1 do
    for j=1,len2 do
      if string.byte(str1,i)==string.byte(str2,j) then cost=0 else cost=1 end
      matrix[i][j]=math.min(matrix[i-1][j]+1,matrix[i][j-1]+1,matrix[i-1][j-1]+cost)
    end
  end
  return matrix[len1][len2]
end

local function MergeState(entry,row)
  entry.objectiveIndex=row.index
  entry.objectiveID=row.objectiveID
  entry.objectiveText=row.text
  entry.rawObjectiveText=row.rawText or row.text
  entry.objectiveType=row.type
  entry.current=row.current
  entry.required=row.required
  entry.complete=row.complete and true or false
  return entry
end

local function ObjectiveTypesMatch(logType,dbType)
  local kind=NormalizeLogType(logType)
  if kind=="creature" then return dbType=="monster" end
  if kind=="gameObject" then return dbType=="object" end
  if kind=="item" then return dbType=="item" end
  return false
end

-- Vanilla stores exploration/event completion as one quest-level state rather
-- than one state per AreaTrigger. A quest can therefore list several A nodes
-- that are OR-equivalent ways to satisfy the same live event objective. Never
-- infer that relationship from DB/objective array order: prefer an exact live
-- leaderboard ID when ClassicAPI exposes one, otherwise accept only one unique
-- live event-style row. Ambiguous/missing rows deliberately fail safe and leave
-- the AreaTrigger visible until the whole quest completes, matching 1.0.63.
local function AreaTriggerObjectiveRow(q,state)
  local triggers=q and q.objectives and q.objectives.areaTrigger or nil
  local rows=state and state.objectives or nil
  if type(triggers)~="table" or type(rows)~="table" or table.getn(triggers)==0 then return nil end

  local triggerSet={}
  for _,id in pairs(triggers) do
    id=tonumber(id)
    if id then triggerSet[id]=true end
  end

  local exact=nil
  local exactCount=0
  for i=1,table.getn(rows) do
    local row=rows[i]
    local id=tonumber(row and row.objectiveID)
    if id and triggerSet[id] then
      exact=row
      exactCount=exactCount+1
    end
  end
  if exactCount==1 then return exact,"id" end
  if exactCount>1 then return nil end

  local eventRow=nil
  local eventCount=0
  for i=1,table.getn(rows) do
    local row=rows[i]
    local typ=string.lower(tostring(row and row.type or ""))
    if typ=="event" or typ=="exploration" or typ=="areatrigger" or typ=="area" then
      eventRow=row
      eventCount=eventCount+1
    end
  end
  if eventCount==1 then return eventRow,"event" end
  return nil
end

local function EntryFromLiveObjectiveID(q,row)
  local id=tonumber(row and row.objectiveID)
  if not q or not id then return nil end
  local typ=string.lower(tostring(row.type or ""))
  local creatureMatch=nil
  local objectMatch=nil
  local itemMatch=nil

  for i=1,table.getn(q.objectiveData or {}) do
    local entry=q.objectiveData[i]
    if entry and tonumber(entry.id)==id then
      if entry.kind=="creature" then creatureMatch=entry
      elseif entry.kind=="gameObject" then objectMatch=entry
      elseif entry.kind=="item" then itemMatch=entry end
    end
  end

  if typ=="item" then return itemMatch end
  if typ=="object" or typ=="gameobject" then return objectMatch end
  if typ=="monster" or typ=="creature" or typ=="kill" then
    -- pfQuest notes that Vanilla can return "monster" for some object-style
    -- objectives; let the live ClassicAPI ID disambiguate the namespace.
    return creatureMatch or objectMatch
  end
  return creatureMatch or objectMatch or itemMatch
end

local function CandidateName(kind,id)
  if kind=="creature" then return QuestieOcto.DatabaseAPI:GetCreatureName(id) end
  if kind=="gameObject" then return QuestieOcto.DatabaseAPI:GetObjectName(id) end
  if kind=="item" then return QuestieOcto.DatabaseAPI:GetItemName(id) end
  return nil
end

local function CandidateIDs(q,kind)
  if kind=="creature" then return q.objectives.creature or {} end
  if kind=="gameObject" then return q.objectives.gameObject or {} end
  if kind=="item" then return q.objectives.item or {} end
  return {}
end

-- Native objective text often contains a short action label rather than the
-- database entity's full name (for example `Check First Cage` versus
-- `First Witherbark Cage`). Pure edit distance can then prefer the wrong
-- sibling merely because another full name happens to be one character
-- closer. Rank shared whole-word tokens first, with words unique among the
-- remaining same-type candidates carrying the most weight, then use the old
-- Levenshtein distance only as a tie-break/fallback. This stays locale-local:
-- both the native objective text and candidate names come from the active
-- client/pfDB locale.
local OBJECTIVE_MATCH_STOP_WORDS={
  ["a"]=true,["an"]=true,["the"]=true,["of"]=true,["to"]=true,["in"]=true,
  ["on"]=true,["and"]=true,["or"]=true,["with"]=true,["at"]=true,["from"]=true,
  ["for"]=true,["is"]=true,["are"]=true,["be"]=true,["by"]=true,["into"]=true,
  ["this"]=true,["that"]=true,["your"]=true,["you"]=true,["his"]=true,["her"]=true,
  ["its"]=true,["their"]=true,["our"]=true,["my"]=true,["has"]=true,["have"]=true,
  ["had"]=true,["was"]=true,["were"]=true,["as"]=true,["then"]=true,["return"]=true,
}

local function ObjectiveMatchTokens(text)
  local result={}
  local lowered=string.lower(tostring(text or ""))
  string.gsub(lowered,"([%w]+)",function(token)
    if not OBJECTIVE_MATCH_STOP_WORDS[token] then result[token]=true end
    return token
  end)
  return result
end

local function BetterObjectiveTokenScore(aExclusive,aShared,aWeight,aDistance,
                                         bExclusive,bShared,bWeight,bDistance)
  if aExclusive~=bExclusive then return aExclusive>bExclusive end
  if aShared~=bShared then return aShared>bShared end
  if aWeight~=bWeight then return aWeight>bWeight end
  return aDistance<bDistance
end

local function BestSameTypeCandidate(q,kind,row,used)
  local ids=CandidateIDs(q,kind)
  local available={}
  local names={}
  local tokenFrequency={}

  -- These are packed objective arrays. Use their numeric order only to build
  -- the candidate set; matching itself is text/identity based and does not
  -- assume that the Quest Log and database objective arrays share an order.
  for i=1,table.getn(ids) do
    local id=ids[i]
    if not used[kind..":"..tostring(id)] then
      local name=CandidateName(kind,id)
      if name then
        table.insert(available,id)
        names[id]=name
        local tokens=ObjectiveMatchTokens(name)
        names["tokens:"..tostring(id)]=tokens
        for token,_ in pairs(tokens) do
          tokenFrequency[token]=(tokenFrequency[token] or 0)+1
        end
      end
    end
  end

  if table.getn(available)==1 then
    O.stats.single=O.stats.single+1
    return available[1]
  end
  if table.getn(available)==0 then return nil end

  local desc=row.text or row.rawText or ""
  local descTokens=ObjectiveMatchTokens(desc)
  local bestID=nil
  local bestExclusive=-1
  local bestShared=-1
  local bestWeight=-1
  local bestDistance=999999

  for i=1,table.getn(available) do
    local id=available[i]
    local name=names[id]
    local tokens=names["tokens:"..tostring(id)] or {}
    local exclusive=0
    local shared=0
    local weight=0

    for token,_ in pairs(tokens) do
      if descTokens[token] then
        local frequency=tokenFrequency[token] or 1
        shared=shared+1
        if frequency==1 then exclusive=exclusive+1 end
        -- Integer weighting keeps the comparison simple on Lua 5.0 while
        -- still making uncommon and longer matching words more informative.
        weight=weight+math.floor(1000/frequency)+math.min(string.len(token),10)*10
      end
    end

    local distance=Levenshtein(desc,name)
    if not bestID or BetterObjectiveTokenScore(
      exclusive,shared,weight,distance,
      bestExclusive,bestShared,bestWeight,bestDistance
    ) then
      bestID=id
      bestExclusive=exclusive
      bestShared=shared
      bestWeight=weight
      bestDistance=distance
    end
  end

  if bestID then O.stats.fuzzy=O.stats.fuzzy+1 end
  return bestID
end

function O:ResolveQuest(questID)
  if not DependenciesReady() then return nil end
  local q=QuestieOcto.QuestModel:Get(questID)
  if not q then return nil end

  local state=QuestieOcto.QuestLog.active[questID]
  local result={questID=questID,creature={},gameObject={},item={},areaTrigger={}}

  -- Failed quests retain their tracker state but have no active objective map
  -- guidance until the server permits a retry.
  if state and state.failed then return result end

  local used={}
  local irTargets,skipCreature,skipObject=BuildIRTargets(q)

  for _,row in pairs(state and state.objectives or {}) do
    local direct=EntryFromLiveObjectiveID(q,row)
    local kind=nil
    local id=nil

    if direct then
      -- pfQuest-style primary path: use ClassicAPI's live leaderboard entity
      -- ID so server objective ordering cannot attach one boss's progress to
      -- another boss's map node.
      kind=direct.kind
      id=direct.id
      O.stats.direct=O.stats.direct+1
    else
      -- Questie 5/6-style fallback: when no trustworthy live ID is available,
      -- match the native objective text against same-type DB candidates rather
      -- than assuming objective array positions are identical.
      kind=NormalizeLogType(row.type)
      id=BestSameTypeCandidate(q,kind,row,used)
      if id then O.stats.fallback=O.stats.fallback+1 end
    end

    if id and kind then
      local key=kind..":"..tostring(id)
      if not used[key] then
        used[key]=true
        O.stats.mapped=O.stats.mapped+1

        if kind=="creature" and not skipCreature[id] then
          local sourceKind,sourceID=PresentationCreatureSource(questID,id)
          local entry=MergeState({
            kind=sourceKind,id=sourceID,objectiveTargetID=id,
            sourceOverride=(sourceKind~="creature" or sourceID~=id) and true or nil
          },row)
          if sourceKind=="gameObject" then
            table.insert(result.gameObject,entry)
            O.stats.object=O.stats.object+1
          else
            table.insert(result.creature,entry)
            O.stats.creature=O.stats.creature+1
          end
        elseif kind=="gameObject" and not skipObject[id] then
          table.insert(result.gameObject,MergeState({kind="gameObject",id=id},row))
          O.stats.object=O.stats.object+1
        elseif kind=="item" then
          table.insert(result.item,MergeState({
            itemID=id,name=QuestieOcto.DatabaseAPI:GetItemName(id),sources=ResolveItemSources(questID,id)
          },row))
          O.stats.item=O.stats.item+1
        end
      else
        O.stats.unmapped=O.stats.unmapped+1
      end
    else
      O.stats.unmapped=O.stats.unmapped+1
    end
  end

  -- Preserve DB-only/special candidates without inventing progress state.
  for i=1,table.getn(q.objectiveData or {}) do
    local entry=q.objectiveData[i]
    local key=entry.kind..":"..tostring(entry.id)
    if not used[key] then
      if entry.kind=="creature" and not skipCreature[entry.id] then
        table.insert(result.creature,{kind="creature",id=entry.id})
        O.stats.creature=O.stats.creature+1
      elseif entry.kind=="gameObject" and not skipObject[entry.id] then
        table.insert(result.gameObject,{kind="gameObject",id=entry.id})
        O.stats.object=O.stats.object+1
      elseif entry.kind=="item" then
        table.insert(result.item,{
          itemID=entry.id,name=QuestieOcto.DatabaseAPI:GetItemName(entry.id),sources=ResolveItemSources(questID,entry.id)
        })
        O.stats.item=O.stats.item+1
      end
    end
  end

  -- Quest-bound area triggers are not generic exploration/fog helpers. Resolve
  -- their shared live event row when that relationship is unambiguous, so all
  -- OR-equivalent locations disappear immediately once the exploration/event
  -- objective completes. If no trustworthy row exists, preserve the old safe
  -- behavior and keep the marker until the quest as a whole completes.
  local areaTriggerRow=AreaTriggerObjectiveRow(q,state)
  for _,areaTriggerID in pairs(q.objectives.areaTrigger or {}) do
    local info=QuestieOcto.API and QuestieOcto.API.GetAreaTriggerInfo
      and QuestieOcto.API:GetAreaTriggerInfo(areaTriggerID) or nil
    if info then
      local source={
        kind="areaTrigger",
        id=tonumber(areaTriggerID),
        mapID=info.areaID,
        x=info.mapX,
        y=info.mapY
      }
      if areaTriggerRow then
        MergeState(source,areaTriggerRow)
        O.stats.areaTriggerMapped=(O.stats.areaTriggerMapped or 0)+1
      else
        O.stats.areaTriggerUnmapped=(O.stats.areaTriggerUnmapped or 0)+1
      end
      table.insert(result.areaTrigger,source)
      O.stats.areaTrigger=(O.stats.areaTrigger or 0)+1
    end
  end

  -- IR target guidance appears only while the required quest item is in the
  -- player's bags/equipment. Its corresponding ordinary U/O objective is
  -- suppressed even while the item is missing, matching pfQuest SearchQuestID.
  for _,target in pairs(irTargets) do
    if target.kind=="creature" then
      table.insert(result.creature,target)
      O.stats.creature=O.stats.creature+1
    else
      table.insert(result.gameObject,target)
      O.stats.object=O.stats.object+1
    end
    O.stats.irTargets=O.stats.irTargets+1
  end

  return result
end

function O:Rebuild()
  if not DependenciesReady() then
    self.ready=false
    self.pending=true
    self.stats.dependencyWaits=(self.stats.dependencyWaits or 0)+1
    return
  end
  if self.running then self.pending=true; return end

  self.pending=false
  self.stats.rebuilds=(self.stats.rebuilds or 0)+1
  self.generation=self.generation+1
  local generation=self.generation
  self.byQuest={}
  self.ready=false
  self.running=true
  ResetStats()

  local ids={}
  for questID in pairs(QuestieOcto.QuestLog.active or {}) do table.insert(ids,questID) end
  table.sort(ids)

  -- Build one shared IR inventory snapshot before resolving quests. This avoids
  -- scanning the entire inventory independently for each active IR item.
  RefreshIRRegistryAndPresence()
  O.irRegistryDirty=false

  local pos=1
  local function step()
    if generation~=O.generation then return end
    local count=0
    while pos<=table.getn(ids) and count<32 do
      local questID=ids[pos]
      pos=pos+1
      local resolved=O:ResolveQuest(questID)
      if resolved then O.byQuest[questID]=resolved end
      O.stats.quests=O.stats.quests+1
      count=count+1
    end
    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"objective-resolve")
      return
    end
    O.running=false
    O.ready=true
    QuestieOcto:SendMessage("OBJECTIVES_READY")
    if O.pending then O.pending=false; O:Schedule(0.01) end
  end
  QuestieOcto.Scheduler:Enqueue(step,"objective-resolve")
end

function O:Schedule(delay)
  self.pending=true
  QuestieOcto.Scheduler:After(delay or 0.15,function()
    if O.pending then O.pending=false; O:Rebuild() end
  end,"objectives-rebuild")
end

function O:RefreshQuests(changedQuests,irPresenceFresh)
  if not self.ready or self.running or not DependenciesReady() then
    self:Schedule(0.01)
    return
  end

  local ids={}
  for questID in pairs(changedQuests or {}) do table.insert(ids,tonumber(questID)) end
  table.sort(ids)
  if table.getn(ids)==0 then return end

  if not irPresenceFresh and O.irRegistryDirty then
    RefreshIRRegistryAndPresence()
    O.irRegistryDirty=false
  end

  self.running=true
  self.generation=self.generation+1
  local generation=self.generation
  local pos=1

  local function step()
    if generation~=O.generation then return end
    local count=0
    while pos<=table.getn(ids) and count<8 do
      local questID=ids[pos]
      pos=pos+1
      if QuestieOcto.QuestLog.active[questID] then
        O.byQuest[questID]=O:ResolveQuest(questID)
      else
        O.byQuest[questID]=nil
      end
      count=count+1
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"objective-refresh-quests")
      return
    end

    O.running=false
    QuestieOcto:SendMessage("OBJECTIVES_CHANGED",changedQuests)
    if O.pending then O.pending=false; O:Schedule(0.01) end
  end

  QuestieOcto.Scheduler:Enqueue(step,"objective-refresh-quests")
end

function O:OnDependencyChanged(changedQuests)
  if type(changedQuests)=="table" and self.ready then
    self:RefreshQuests(changedQuests)
  else
    self:Schedule(0.01)
  end
end

function O:OnActiveSetChanged()
  -- Active quest membership is the only normal event that changes which IR
  -- items need tracking. Mark the registry dirty here; the following map-state
  -- refresh rebuilds it once before resolving affected quests.
  self.irRegistryDirty=true
end

QuestieOcto:RegisterMessage("QUEST_ACTIVE_SET_CHANGED",O,"OnActiveSetChanged")
QuestieOcto:RegisterMessage("QUEST_MAP_STATE_CHANGED",O,"OnDependencyChanged")
QuestieOcto:RegisterMessage("DATABASE_API_READY",O,"OnDependencyChanged")

local bagFrame=CreateFrame("Frame","QuestieOctoObjectiveItemEvents",UIParent)
-- ClassicAPI exposes BAG_UPDATE_DELAYED on this Vanilla client. Use the settled
-- event rather than reacting to every individual stack/ammunition mutation.
bagFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagFrame:SetScript("OnEvent",function()
  O.irStats.bagEvents=(O.irStats.bagEvents or 0)+1
  if (tonumber(O.irTrackedCount) or 0)<=0 then
    O.irStats.bagSkips=(O.irStats.bagSkips or 0)+1
    return
  end

  -- Coalesce any additional delayed inventory burst. Scan the inventory once
  -- for all currently relevant IR items, then refresh only quests mapped to the
  -- item IDs whose presence actually changed.
  QuestieOcto.Scheduler:After(0.25,function()
    if (tonumber(O.irTrackedCount) or 0)<=0 then return end
    local changedItems=ScanIRPresence()
    if not changedItems then return end

    local affected=ClearTable(O.irAffectedQuests)
    O.irAffectedQuests=affected
    for itemID in pairs(changedItems) do
      for questID in pairs((O.irItemQuests and O.irItemQuests[itemID]) or {}) do
        affected[questID]=true
      end
    end
    if next(affected) then O:RefreshQuests(affected,true) end
  end,"objective-ir-bag-check")
end)
