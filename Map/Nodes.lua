QuestieOcto.Nodes = QuestieOcto.Nodes or {}
local N = QuestieOcto.Nodes

N.ready=false
N.running=false
N.generation=0
N.nodes={}
N.byMap={}
N.questMaps={}
N.questNodes={}
N.nodeSequence=0
N.stateRevision=0
N.stats={
  total=0,
  availableCreature=0,
  availableObject=0,
  itemStart=0,
  objectiveCreature=0,
  objectiveObject=0,
  objectiveItemSource=0,
  objectiveArea=0,
  turnin=0,
  flightMaster=0,
  auctioneer=0,
  banker=0,
  mailbox=0,
  battlemaster=0,
  innkeeper=0,
  meetingStone=0,
  repair=0,
  spiritHealer=0,
  stableMaster=0,
  vendor=0,
  rareMob=0,
}

local function NewStats()
  return {
    total=0,
    availableCreature=0,
    availableObject=0,
    itemStart=0,
    objectiveCreature=0,
    objectiveObject=0,
    objectiveItemSource=0,
    objectiveArea=0,
    turnin=0,
    flightMaster=0,
    auctioneer=0,
    banker=0,
    mailbox=0,
    battlemaster=0,
    innkeeper=0,
    meetingStone=0,
    repair=0,
    spiritHealer=0,
    stableMaster=0,
    vendor=0,
    rareMob=0,
  }
end

local function ResetStats()
  N.stats=NewStats()
end

local function CurrentStats()
  return N.buildStats or N.stats
end

local function CurrentNodes()
  return N.buildNodes or N.nodes
end

local function CurrentByMap()
  return N.buildByMap or N.byMap
end

local function CurrentQuestMaps()
  return N.buildQuestMaps or N.questMaps
end

local function CurrentQuestNodes()
  return N.buildQuestNodes or N.questNodes
end

local function ApplyIconScaleKey(node)
  return node
end

local function IsPresentationEvent(q)
  if not q or not q.eventID or not QuestieOcto.EventAvailability then return false end
  if QuestieOcto.EventAvailability.IsPresentationEventForQuest then
    return QuestieOcto.EventAvailability:IsPresentationEventForQuest(q) and true or false
  end
  return QuestieOcto.EventAvailability:IsPresentationEvent(q.eventID) and true or false
end

local function AddNode(node)
  node=ApplyIconScaleKey(node)
  CurrentStats().total=CurrentStats().total+1
  N.nodeSequence=(N.nodeSequence or 0)+1
  node.nodeID=N.nodeSequence
  -- Global canonical nodes are keyed by nodeID rather than kept as a compact
  -- array. Incremental quest removal can therefore delete known node IDs
  -- directly without copying the entire global node table. All consumers use
  -- pairs(), so ordering is intentionally provided by byMap where required.
  CurrentNodes()[node.nodeID]=node

  local questID=tonumber(node.questID)
  if questID and questID>0 then
    local questNodes=CurrentQuestNodes()
    questNodes[questID]=questNodes[questID] or {}
    table.insert(questNodes[questID],node)
  end

  local coords=node.coords
  if coords then
    -- A canonical node belongs to a map once, even if the source has dozens
    -- of spawn coordinates on that map. Clustering handles those coordinates
    -- later. 0.1.5 incorrectly inserted the same node once per coordinate,
    -- causing hundreds of duplicate render work items.
    local seenMaps={}
    for _,coord in pairs(coords) do
      if type(coord)=="table" and tonumber(coord[3]) then
        local mapID=tonumber(coord[3])
        if not seenMaps[mapID] then
          seenMaps[mapID]=true
          local byMap=CurrentByMap()
          byMap[mapID]=byMap[mapID] or {}
          table.insert(byMap[mapID],node)
          if tonumber(node.questID) and tonumber(node.questID)>0 then
            local questMaps=CurrentQuestMaps()
            questMaps[node.questID]=questMaps[node.questID] or {}
            questMaps[node.questID][mapID]=true
          end
        end
      end
    end
  end
end

local function ApplyObjectiveState(node,state)
  if state then
    node.objectiveIndex=state.objectiveIndex
    node.objectiveText=state.objectiveText
    node.objectiveType=state.objectiveType
    node.current=state.current
    node.required=state.required
    node.objectiveComplete=state.complete and true or false
  end
  return node
end

local function ConditionalCreatureCoords(q,creatureID,role)
  local marker=q and q.conditionalMapMarker or nil
  if marker and tonumber(marker.creatureID)==tonumber(creatureID)
     and (role=="available" or role=="turnin") then
    return marker.coords
  end
  return nil
end


local function HasCoords(coords)
  for _,coord in pairs(coords or {}) do
    if type(coord)=="table" and tonumber(coord[1]) and tonumber(coord[2]) and tonumber(coord[3]) then
      return true
    end
  end
  return false
end

local function ScriptedEncounterInfo(creatureID,role)
  if role~="objectiveCreature" and role~="objectiveItemSource" and role~="itemStart"
     and role~="available" and role~="turnin" then return nil end
  local data=QuestieOcto.ScriptedEncounterData
  local info=data and data[tonumber(creatureID)] or nil
  if not info then return nil end
  if info.roles and not info.roles[role] then return nil end
  return info
end

local function AddCreatureNode(questID,role,creatureID,itemID,chance,objectiveState,vendor)
  local q=QuestieOcto.QuestModel:Get(questID)
  local coords=ConditionalCreatureCoords(q,creatureID,role) or QuestieOcto.DatabaseAPI:GetCreatureCoords(creatureID)
  local scripted=ScriptedEncounterInfo(creatureID,role)
  local usedScripted=false
  if scripted and not HasCoords(coords) and HasCoords(scripted.coords) then
    coords=scripted.coords
    usedScripted=true
  end
  local node={
    questID=questID,role=role,event=IsPresentationEvent(q),eventID=q and q.eventID or nil,pvp=q and q.pvp or false,repeatable=q and q.presentationRepeatable or false,sourceKind="creature",sourceID=creatureID,
    sourceName=(usedScripted and scripted.displayName) or QuestieOcto.DatabaseAPI:GetCreatureName(creatureID),
    sourceRank=QuestieOcto.DatabaseAPI:GetCreatureRank(creatureID),
    respawnSeconds=QuestieOcto.DatabaseAPI:GetCreatureRespawnSeconds(creatureID),
    itemID=itemID,itemName=itemID and QuestieOcto.DatabaseAPI:GetItemName(itemID) or nil,
    chance=chance,vendor=vendor and true or false,coords=coords,
    conditionalOffer=q and q.conditionalOffer or nil,
    scriptedEncounterNote=usedScripted and scripted.note or nil,
  }
  AddNode(ApplyObjectiveState(node,objectiveState))
end

local function AddObjectNode(questID,role,objectID,itemID,chance,objectiveState)
  local q=QuestieOcto.QuestModel:Get(questID)
  local node={
    questID=questID,role=role,event=IsPresentationEvent(q),eventID=q and q.eventID or nil,pvp=q and q.pvp or false,repeatable=q and q.presentationRepeatable or false,sourceKind="gameObject",sourceID=objectID,
    sourceName=QuestieOcto.DatabaseAPI:GetObjectName(objectID),
    itemID=itemID,itemName=itemID and QuestieOcto.DatabaseAPI:GetItemName(itemID) or nil,
    chance=chance,coords=QuestieOcto.DatabaseAPI:GetObjectCoords(objectID)
  }
  AddNode(ApplyObjectiveState(node,objectiveState))
end

local function AddAreaTriggerNode(questID,source)
  if not source or not source.mapID or not source.x or not source.y then return end
  local q=QuestieOcto.QuestModel:Get(questID)
  AddNode(ApplyObjectiveState({
    questID=questID,role="objectiveArea",event=IsPresentationEvent(q),eventID=q and q.eventID or nil,pvp=q and q.pvp or false,repeatable=q and q.presentationRepeatable or false,
    sourceKind="areaTrigger",sourceID=source.id,sourceName="Exploration Mark",
    coords={{source.x,source.y,source.mapID}}
  },source))
end

local function BuildAvailableQuestNodes(questID)
  local q=QuestieOcto.QuestModel:Get(questID)
  if not q then return end

  if q.starts.creature then
    for _,id in pairs(q.starts.creature) do
      if not QuestieOcto.DatabaseAPI.CreatureAllowsPlayerFaction or QuestieOcto.DatabaseAPI:CreatureAllowsPlayerFaction(id) then
        AddCreatureNode(questID,"available",id,nil,nil)
        CurrentStats().availableCreature=CurrentStats().availableCreature+1
      end
    end
  end

  if q.starts.gameObject then
    for _,id in pairs(q.starts.gameObject) do
      if not QuestieOcto.DatabaseAPI.ObjectAllowsPlayerFaction or QuestieOcto.DatabaseAPI:ObjectAllowsPlayerFaction(id) then
        AddObjectNode(questID,"available",id,nil,nil)
        CurrentStats().availableObject=CurrentStats().availableObject+1
      end
    end
  end
end

local function BuildItemStartQuestNodes(questID,resolved,availableSet)
  -- ItemStarts is a derived cache; the published AvailableQuests snapshot is
  -- the authoritative visibility gate. Never let an older item-start cache
  -- bypass completion/event/repeatable filtering during an async refresh.
  if not availableSet[questID] or not resolved then return end

  for _,item in pairs(resolved.items or {}) do
    for _,src in pairs(item.creatureSources or {}) do
      AddCreatureNode(questID,"itemStart",src.id,item.itemID,src.chance,nil,src.vendor)
      CurrentStats().itemStart=CurrentStats().itemStart+1
    end

    for _,src in pairs(item.objectSources or {}) do
      AddObjectNode(questID,"itemStart",src.id,item.itemID,src.chance)
      CurrentStats().itemStart=CurrentStats().itemStart+1
    end
  end
end


local function PlayerFactionCode()
  local playerFaction=UnitFactionGroup and UnitFactionGroup("player") or nil
  if playerFaction=="Alliance" then return "A" end
  if playerFaction=="Horde" then return "H" end
  return nil
end

local function FactionAllows(allowed,factionCode)
  return type(allowed)=="string" and factionCode and string.find(allowed,factionCode,1,true) and true or false
end

local function TrackingMeta(metaKey)
  return QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetTrackingMeta and QuestieOcto.DatabaseAPI:GetTrackingMeta(metaKey) or nil
end

local function BuildServiceCreatureNodes(metaKey,role,statKey)
  local list=TrackingMeta(metaKey)
  if not list then return end
  local factionCode=PlayerFactionCode()
  if not factionCode then return end

  for creatureID,allowed in pairs(list) do
    creatureID=tonumber(creatureID)
    if creatureID and creatureID>0 and FactionAllows(allowed,factionCode) then
      local coords=QuestieOcto.DatabaseAPI:GetCreatureCoords(creatureID)
      if coords and next(coords) then
        AddNode({
          questID=0,
          role=role,
          sourceKind="creature",
          sourceID=creatureID,
          sourceName=QuestieOcto.DatabaseAPI:GetCreatureName(creatureID),
          coords=coords,
          serviceFaction=allowed
        })
        CurrentStats()[statKey]=(CurrentStats()[statKey] or 0)+1
      end
    end
  end
end

local function BuildServiceObjectNodes(metaKey,role,statKey)
  local list=TrackingMeta(metaKey)
  if not list then return end
  local factionCode=PlayerFactionCode()
  if not factionCode then return end

  for signedObjectID,allowed in pairs(list) do
    local objectID=math.abs(tonumber(signedObjectID) or 0)
    if objectID>0 and FactionAllows(allowed,factionCode) then
      local coords=QuestieOcto.DatabaseAPI:GetObjectCoords(objectID)
      if coords and next(coords) then
        AddNode({
          questID=0,
          role=role,
          sourceKind="gameObject",
          sourceID=objectID,
          sourceName=QuestieOcto.DatabaseAPI:GetObjectName(objectID),
          coords=coords,
          serviceFaction=allowed
        })
        CurrentStats()[statKey]=(CurrentStats()[statKey] or 0)+1
      end
    end
  end
end

local function BuildMailboxNodes()
  BuildServiceObjectNodes("mailbox","mailbox","mailbox")
end

local optionalServiceSettings={
  battlemaster={"showMapBattlemaster","showMinimapBattlemaster"},
  innkeeper={"showMapInnkeeper","showMinimapInnkeeper"},
  meetingStone={"showMapMeetingStone","showMinimapMeetingStone"},
  repair={"showMapRepair","showMinimapRepair"},
  spiritHealer={"showMapSpiritHealer","showMinimapSpiritHealer"},
  stableMaster={"showMapStableMaster","showMinimapStableMaster"},
  vendor={"showMapVendor","showMinimapVendor"},
}

local function OptionalServiceEnabled(role)
  local keys=optionalServiceSettings[role]
  if not keys or not QuestieOcto.MinimapSettings then return true end
  return QuestieOcto.MinimapSettings:Get(keys[1]) or QuestieOcto.MinimapSettings:Get(keys[2])
end

local function BuildOptionalServiceCreatureNodes(metaKey,role,statKey)
  if OptionalServiceEnabled(role) then BuildServiceCreatureNodes(metaKey,role,statKey) end
end

local function BuildOptionalServiceObjectNodes(metaKey,role,statKey)
  if OptionalServiceEnabled(role) then BuildServiceObjectNodes(metaKey,role,statKey) end
end

local function ProcessServiceCreatureSlice(metaKey,role,statKey,cursor,limit)
  local list=TrackingMeta(metaKey)
  if not list then return nil,true end
  local factionCode=PlayerFactionCode()
  if not factionCode then return nil,true end

  local count=0
  while count<(limit or 128) do
    local rawID,allowed=next(list,cursor)
    if rawID==nil then return nil,true end
    cursor=rawID
    local creatureID=tonumber(rawID)
    if creatureID and creatureID>0 and FactionAllows(allowed,factionCode) then
      local coords=QuestieOcto.DatabaseAPI:GetCreatureCoords(creatureID)
      if coords and next(coords) then
        AddNode({
          questID=0,
          role=role,
          sourceKind="creature",
          sourceID=creatureID,
          sourceName=QuestieOcto.DatabaseAPI:GetCreatureName(creatureID),
          coords=coords,
          serviceFaction=allowed
        })
        CurrentStats()[statKey]=(CurrentStats()[statKey] or 0)+1
      end
    end
    count=count+1
  end

  return cursor,false
end

local function ProcessServiceObjectSlice(metaKey,role,statKey,cursor,limit)
  local list=TrackingMeta(metaKey)
  if not list then return nil,true end
  local factionCode=PlayerFactionCode()
  if not factionCode then return nil,true end

  local count=0
  while count<(limit or 128) do
    local rawID,allowed=next(list,cursor)
    if rawID==nil then return nil,true end
    cursor=rawID
    local objectID=math.abs(tonumber(rawID) or 0)
    if objectID>0 and FactionAllows(allowed,factionCode) then
      local coords=QuestieOcto.DatabaseAPI:GetObjectCoords(objectID)
      if coords and next(coords) then
        AddNode({
          questID=0,
          role=role,
          sourceKind="gameObject",
          sourceID=objectID,
          sourceName=QuestieOcto.DatabaseAPI:GetObjectName(objectID),
          coords=coords,
          serviceFaction=allowed
        })
        CurrentStats()[statKey]=(CurrentStats()[statKey] or 0)+1
      end
    end
    count=count+1
  end

  return cursor,false
end

local function ProcessRareMobSlice(cursor,limit)
  local list=TrackingMeta("rares")
  if not list then return nil,true end

  local count=0
  while count<(limit or 128) do
    local rawID,rareLevel=next(list,cursor)
    if rawID==nil then return nil,true end
    cursor=rawID
    local creatureID=tonumber(rawID)
    if creatureID and creatureID>0 then
      local coords=QuestieOcto.DatabaseAPI:GetCreatureCoords(creatureID)
      if coords and next(coords) then
        AddNode({
          questID=0,
          role="rareMob",
          sourceKind="creature",
          sourceID=creatureID,
          sourceName=QuestieOcto.DatabaseAPI:GetCreatureName(creatureID),
          sourceRank=QuestieOcto.DatabaseAPI:GetCreatureRank(creatureID),
          respawnSeconds=QuestieOcto.DatabaseAPI:GetCreatureRespawnSeconds(creatureID),
          rareLevel=tonumber(rareLevel),
          coords=coords
        })
        CurrentStats().rareMob=CurrentStats().rareMob+1
      end
    end
    count=count+1
  end

  return cursor,false
end

local function BuildRareMobNodes()
  local list=TrackingMeta("rares")
  if not list then return end

  for creatureID,rareLevel in pairs(list) do
    creatureID=tonumber(creatureID)
    if creatureID and creatureID>0 then
      local coords=QuestieOcto.DatabaseAPI:GetCreatureCoords(creatureID)
      if coords and next(coords) then
        AddNode({
          questID=0,
          role="rareMob",
          sourceKind="creature",
          sourceID=creatureID,
          sourceName=QuestieOcto.DatabaseAPI:GetCreatureName(creatureID),
          sourceRank=QuestieOcto.DatabaseAPI:GetCreatureRank(creatureID),
          respawnSeconds=QuestieOcto.DatabaseAPI:GetCreatureRespawnSeconds(creatureID),
          rareLevel=tonumber(rareLevel),
          coords=coords
        })
        CurrentStats().rareMob=CurrentStats().rareMob+1
      end
    end
  end
end

local function BuildPermanentMapNodes()
  -- Questie 3.3.5/7/8 model Auctioneer, Banker and Flight Master as
  -- townsfolk map categories. pfQuest supplies the Vanilla/Turtle-compatible
  -- faction lists, mailbox object IDs, rare-mob list and spawn coordinates.
  BuildServiceCreatureNodes("flight","flightMaster","flightMaster")
  BuildServiceCreatureNodes("auctioneer","auctioneer","auctioneer")
  BuildServiceCreatureNodes("banker","banker","banker")
  BuildMailboxNodes()
  BuildOptionalServiceCreatureNodes("battlemaster","battlemaster","battlemaster")
  BuildOptionalServiceCreatureNodes("innkeeper","innkeeper","innkeeper")
  BuildOptionalServiceObjectNodes("meetingstone","meetingStone","meetingStone")
  BuildOptionalServiceCreatureNodes("repair","repair","repair")
  BuildOptionalServiceCreatureNodes("spirithealer","spiritHealer","spiritHealer")
  BuildOptionalServiceCreatureNodes("stablemaster","stableMaster","stableMaster")
  BuildOptionalServiceCreatureNodes("vendor","vendor","vendor")
  BuildRareMobNodes()
end

local function BuildActiveQuestNodes(questID)
  local state=QuestieOcto.QuestLog.active[questID]
  local q=QuestieOcto.QuestModel:Get(questID)
  if not state or not q then return end

  if state.complete then
    for _,id in pairs(q.finishes.creature or {}) do
      AddCreatureNode(questID,"turnin",id,nil,nil)
      CurrentStats().turnin=CurrentStats().turnin+1
    end
    for _,id in pairs(q.finishes.gameObject or {}) do
      AddObjectNode(questID,"turnin",id,nil,nil)
      CurrentStats().turnin=CurrentStats().turnin+1
    end
    return
  end

  local resolved=QuestieOcto.Objectives.byQuest[questID]
  if not resolved then return end

  for _,src in pairs(resolved.creature or {}) do
    if not src.complete then
      AddCreatureNode(questID,"objectiveCreature",src.id,src.itemID,nil,src)
      CurrentStats().objectiveCreature=CurrentStats().objectiveCreature+1
    end
  end
  for _,src in pairs(resolved.gameObject or {}) do
    if not src.complete then
      AddObjectNode(questID,"objectiveObject",src.id,src.itemID,nil,src)
      CurrentStats().objectiveObject=CurrentStats().objectiveObject+1
    end
  end
  for _,item in pairs(resolved.item or {}) do
    if not item.complete then
      for _,src in pairs(item.sources or {}) do
        if src.kind=="creature" then
          AddCreatureNode(questID,"objectiveItemSource",src.id,item.itemID,src.chance,item,src.vendor)
        else
          AddObjectNode(questID,"objectiveItemSource",src.id,item.itemID,src.chance,item)
        end
        CurrentStats().objectiveItemSource=CurrentStats().objectiveItemSource+1
      end
    end
  end
  for _,src in pairs(resolved.areaTrigger or {}) do
    if not src.complete then
      AddAreaTriggerNode(questID,src)
      CurrentStats().objectiveArea=(CurrentStats().objectiveArea or 0)+1
    end
  end
end

local function BuildActiveNodes()
  for questID in pairs(QuestieOcto.QuestLog.active or {}) do
    BuildActiveQuestNodes(questID)
  end
end

local function StatKeyForNode(node)
  if not node then return nil end
  if node.role=="available" then
    return node.sourceKind=="gameObject" and "availableObject" or "availableCreature"
  end
  if node.role=="itemStart" then return "itemStart" end
  if node.role=="objectiveCreature" then return "objectiveCreature" end
  if node.role=="objectiveObject" then return "objectiveObject" end
  if node.role=="objectiveItemSource" then return "objectiveItemSource" end
  if node.role=="objectiveArea" then return "objectiveArea" end
  if node.role=="turnin" then return "turnin" end
  if node.role=="flightMaster" then return "flightMaster" end
  if node.role=="auctioneer" then return "auctioneer" end
  if node.role=="banker" then return "banker" end
  if node.role=="mailbox" then return "mailbox" end
  if node.role=="battlemaster" then return "battlemaster" end
  if node.role=="innkeeper" then return "innkeeper" end
  if node.role=="meetingStone" then return "meetingStone" end
  if node.role=="repair" then return "repair" end
  if node.role=="spiritHealer" then return "spiritHealer" end
  if node.role=="stableMaster" then return "stableMaster" end
  if node.role=="vendor" then return "vendor" end
  if node.role=="rareMob" then return "rareMob" end
  return nil
end

local function DecrementNodeStats(node)
  N.stats.total=math.max(0,(N.stats.total or 0)-1)
  local key=StatKeyForNode(node)
  if key then N.stats[key]=math.max(0,(N.stats[key] or 0)-1) end
end

local function NormalizeChangedQuests(changedQuests)
  local changed={}
  for questID in pairs(changedQuests or {}) do
    questID=tonumber(questID)
    if questID and questID>0 then changed[questID]=true end
  end
  return changed
end

local function RemoveChangedQuestNodes(changed)
  local affectedMaps={}

  -- questNodes is the reverse canonical-node ownership index. Remove each
  -- changed quest's exact global nodes directly, including coordinate-less
  -- tooltip/objective nodes, instead of copying/scanning every canonical node.
  for questID in pairs(changed) do
    for _,node in pairs(N.questNodes[questID] or {}) do
      if N.nodes[node.nodeID] then
        N.nodes[node.nodeID]=nil
        DecrementNodeStats(node)
      end
    end
    N.questNodes[questID]=nil
    for mapID in pairs(N.questMaps[questID] or {}) do affectedMaps[mapID]=true end
  end

  -- Filter each affected map exactly once no matter how many changed quests
  -- share it. The previous implementation rebuilt the same map array once per
  -- changed quest.
  for mapID in pairs(affectedMaps) do
    local kept={}
    for _,node in pairs(N.byMap[mapID] or {}) do
      if not changed[tonumber(node.questID)] then table.insert(kept,node) end
    end
    N.byMap[mapID]=kept
  end

  for questID in pairs(changed) do N.questMaps[questID]=nil end
  return affectedMaps
end

local function SortAffectedMaps(affectedMaps)
  for mapID in pairs(affectedMaps or {}) do
    local mapNodes=N.byMap[mapID]
    if mapNodes then
      table.sort(mapNodes,function(a,b)
        if a.questID~=b.questID then return a.questID<b.questID end
        if a.role~=b.role then return tostring(a.role)<tostring(b.role) end
        if a.sourceKind~=b.sourceKind then return tostring(a.sourceKind)<tostring(b.sourceKind) end
        return tonumber(a.sourceID or 0)<tonumber(b.sourceID or 0)
      end)
    end
  end
end

function N:GetQuestNodes(questID)
  questID=tonumber(questID)
  return questID and self.questNodes[questID] or nil
end

function N:RefreshQuests(changedQuests)
  if not self.ready or self.running or not QuestieOcto.Objectives.ready then
    self:Rebuild()
    return
  end

  local changed=NormalizeChangedQuests(changedQuests)
  if not next(changed) then return end

  local affectedMaps=RemoveChangedQuestNodes(changed)

  -- Objective/progress refreshes re-add only the active semantic state.
  for questID in pairs(changed) do
    BuildActiveQuestNodes(questID)
    for mapID in pairs(self.questMaps[questID] or {}) do affectedMaps[mapID]=true end
  end

  SortAffectedMaps(affectedMaps)
  self.stateRevision=(self.stateRevision or 0)+1
  QuestieOcto:SendMessage("NODES_CHANGED",affectedMaps,changed)
end

-- Availability filters used to rebuild the complete canonical node graph even
-- when only a handful of quests crossed the visible/hidden boundary. On dense
-- continent maps that forced every existing icon through another render pass
-- and looked like flicker. Patch just the changed quests instead.
function N:RefreshAvailability(changedQuests)
  if not self.ready or self.running or not QuestieOcto.Objectives.ready
     or not QuestieOcto.ItemStarts.ready then
    self:Rebuild()
    return
  end

  local changed=NormalizeChangedQuests(changedQuests)
  if not next(changed) then return end

  local affectedMaps=RemoveChangedQuestNodes(changed)
  local availableSet=QuestieOcto.AvailableQuests.available or {}
  local itemStarts=QuestieOcto.ItemStarts.byQuest or {}

  for questID in pairs(changed) do
    -- This normally covers available quests only, but rebuilding the current
    -- semantic state makes the patch safe if another producer races the filter.
    if QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID] then
      BuildActiveQuestNodes(questID)
    elseif availableSet[questID] then
      BuildAvailableQuestNodes(questID)
      BuildItemStartQuestNodes(questID,itemStarts[questID],availableSet)
    end
    for mapID in pairs(self.questMaps[questID] or {}) do affectedMaps[mapID]=true end
  end

  SortAffectedMaps(affectedMaps)
  self.stateRevision=(self.stateRevision or 0)+1
  QuestieOcto:SendMessage("NODES_CHANGED",affectedMaps,changed)
end

function N:Rebuild()
  if not QuestieOcto.AvailableQuests.ready
     or not QuestieOcto.Objectives.ready
     or not QuestieOcto.ItemStarts.ready
     or not QuestieOcto.DatabaseAPI:IsReady()
     or not QuestieOcto.QuestLog.snapshot then
    self.ready=false
    return
  end

  self.generation=self.generation+1
  local generation=self.generation

  -- Build into private buffers. The published node set stays live until the
  -- replacement is complete, preventing map/minimap disappearance during an
  -- asynchronous rebuild.
  local hadReady=self.ready and true or false
  if not hadReady then self.ready=false end
  self.running=true
  self.nodeSequence=0
  self.buildNodes={}
  self.buildByMap={}
  self.buildQuestMaps={}
  self.buildQuestNodes={}
  self.buildStats=NewStats()

  -- Capture the input snapshots. A newer publication triggers another rebuild
  -- and increments generation, while this build can finish/cancel safely
  -- without walking a table that changes underneath next().
  local availableSet=QuestieOcto.AvailableQuests.available or {}
  local itemStartSet=QuestieOcto.ItemStarts.byQuest or {}
  local availableCursor=nil
  local itemStartCursor=nil

  local function Publish()
    if generation~=N.generation then return end
    N.nodes=N.buildNodes or {}
    N.byMap=N.buildByMap or {}
    N.questMaps=N.buildQuestMaps or {}
    N.questNodes=N.buildQuestNodes or {}
    N.stats=N.buildStats or N.stats
    N.buildNodes=nil
    N.buildByMap=nil
    N.buildQuestMaps=nil
    N.buildQuestNodes=nil
    N.buildStats=nil
    N.running=false
    N.ready=true
    N.stateRevision=(N.stateRevision or 0)+1
    QuestieOcto:SendMessage("NODES_READY")
  end

  local function SortMaps()
    if generation~=N.generation then return end
    local mapIDs={}
    for mapID in pairs(N.buildByMap or {}) do table.insert(mapIDs,mapID) end
    table.sort(mapIDs)
    local pos=1

    local function SortStep()
      if generation~=N.generation then return end
      local count=0
      while pos<=table.getn(mapIDs) and count<4 do
        local mapNodes=N.buildByMap[mapIDs[pos]]
        pos=pos+1
        if mapNodes then
          table.sort(mapNodes,function(a,b)
            if a.questID~=b.questID then return a.questID<b.questID end
            if a.role~=b.role then return tostring(a.role)<tostring(b.role) end
            if a.sourceKind~=b.sourceKind then return tostring(a.sourceKind)<tostring(b.sourceKind) end
            return tonumber(a.sourceID or 0)<tonumber(b.sourceID or 0)
          end)
        end
        count=count+1
      end
      if pos<=table.getn(mapIDs) then
        QuestieOcto.Scheduler:Enqueue(SortStep,"nodes-sort")
      else
        Publish()
      end
    end

    QuestieOcto.Scheduler:Enqueue(SortStep,"nodes-sort")
  end

  -- Keep service tracking incremental too. Vendor/repair metadata is large in
  -- pfQuest, and enabling an opt-in category must not turn into one long frame.
  local permanentBuilders={
    {kind="creature",metaKey="flight",role="flightMaster",statKey="flightMaster"},
    {kind="creature",metaKey="auctioneer",role="auctioneer",statKey="auctioneer"},
    {kind="creature",metaKey="banker",role="banker",statKey="banker"},
    {kind="object",metaKey="mailbox",role="mailbox",statKey="mailbox"},
    {kind="creature",metaKey="battlemaster",role="battlemaster",statKey="battlemaster",optional=true},
    {kind="creature",metaKey="innkeeper",role="innkeeper",statKey="innkeeper",optional=true},
    {kind="object",metaKey="meetingstone",role="meetingStone",statKey="meetingStone",optional=true},
    {kind="creature",metaKey="repair",role="repair",statKey="repair",optional=true},
    {kind="creature",metaKey="spirithealer",role="spiritHealer",statKey="spiritHealer",optional=true},
    {kind="creature",metaKey="stablemaster",role="stableMaster",statKey="stableMaster",optional=true},
    {kind="creature",metaKey="vendor",role="vendor",statKey="vendor",optional=true},
    {kind="rare"},
  }

  local function PermanentStep(index,cursor)
    if generation~=N.generation then return end
    local job=permanentBuilders[index]
    if not job then SortMaps(); return end

    if job.optional and not OptionalServiceEnabled(job.role) then
      QuestieOcto.Scheduler:Enqueue(function() PermanentStep(index+1,nil) end,"nodes-permanent")
      return
    end

    local nextCursor=nil
    local done=true
    if job.kind=="creature" then
      nextCursor,done=ProcessServiceCreatureSlice(job.metaKey,job.role,job.statKey,cursor,128)
    elseif job.kind=="object" then
      nextCursor,done=ProcessServiceObjectSlice(job.metaKey,job.role,job.statKey,cursor,128)
    elseif job.kind=="rare" then
      nextCursor,done=ProcessRareMobSlice(cursor,128)
    end

    if done then
      QuestieOcto.Scheduler:Enqueue(function() PermanentStep(index+1,nil) end,"nodes-permanent")
    else
      QuestieOcto.Scheduler:Enqueue(function() PermanentStep(index,nextCursor) end,"nodes-permanent")
    end
  end

  local function ItemStartStep()
    if generation~=N.generation then return end
    local count=0
    while count<24 do
      local questID,resolved=next(itemStartSet,itemStartCursor)
      if questID==nil then
        PermanentStep(1)
        return
      end
      itemStartCursor=questID
      BuildItemStartQuestNodes(questID,resolved,availableSet)
      count=count+1
    end
    QuestieOcto.Scheduler:Enqueue(ItemStartStep,"nodes-itemstart")
  end

  local function AvailableStep()
    if generation~=N.generation then return end
    local count=0
    while count<32 do
      local questID=next(availableSet,availableCursor)
      if questID==nil then
        QuestieOcto.Scheduler:Enqueue(ItemStartStep,"nodes-itemstart")
        return
      end
      availableCursor=questID
      BuildAvailableQuestNodes(questID)
      count=count+1
    end
    QuestieOcto.Scheduler:Enqueue(AvailableStep,"nodes-available")
  end

  QuestieOcto.Scheduler:Enqueue(function()
    if generation~=N.generation then return end
    BuildActiveNodes()
    QuestieOcto.Scheduler:Enqueue(AvailableStep,"nodes-available")
  end,"nodes-active")
end

function N:GetMapNodes(mapID)
  return self.byMap[tonumber(mapID)] or {}
end

function N:OnInputReady()
  self:Rebuild()
end

function N:OnObjectivesChanged(changedQuests)
  self:RefreshQuests(changedQuests)
end

function N:OnItemStartsChanged(changedQuests)
  self:RefreshAvailability(changedQuests)
end

QuestieOcto:RegisterMessage("OBJECTIVES_READY",N,"OnInputReady")
QuestieOcto:RegisterMessage("OBJECTIVES_CHANGED",N,"OnObjectivesChanged")
QuestieOcto:RegisterMessage("ITEM_STARTS_READY",N,"OnInputReady")
QuestieOcto:RegisterMessage("ITEM_STARTS_CHANGED",N,"OnItemStartsChanged")
