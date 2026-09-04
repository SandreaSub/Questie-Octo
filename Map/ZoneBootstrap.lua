QuestieOcto.ZoneBootstrap = QuestieOcto.ZoneBootstrap or {}
local Z = QuestieOcto.ZoneBootstrap

Z.running=false
Z.ready=false
Z.mapID=nil
Z.requestedMapID=nil
Z.generation=0
Z.stats={scanned=0,candidates=0,available=0,nodes=0,itemSources=0,requests=0,cancelled=0,msHint="priority"}

local function CoordsContainMap(coords,mapID)
  if not coords then return false end
  for _,coord in pairs(coords) do
    if type(coord)=="table" and tonumber(coord[3])==tonumber(mapID) then
      return true
    end
  end
  return false
end

local function AddNode(nodes,node)
  table.insert(nodes,node)
end

local function IsPresentationEvent(q)
  if not q or not q.eventID or not QuestieOcto.EventAvailability then return false end
  if QuestieOcto.EventAvailability.IsPresentationEventForQuest then
    return QuestieOcto.EventAvailability:IsPresentationEventForQuest(q) and true or false
  end
  return QuestieOcto.EventAvailability:IsPresentationEvent(q.eventID) and true or false
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

local function CreatureNode(questID,role,id,itemID,chance,objectiveState)
  local q=QuestieOcto.QuestModel:Get(questID)
  return ApplyObjectiveState({
    questID=questID,role=role,event=IsPresentationEvent(q),eventID=q and q.eventID or nil,pvp=q and q.pvp or false,repeatable=q and q.presentationRepeatable or false,
    sourceKind="creature",sourceID=id,
    sourceName=QuestieOcto.DatabaseAPI:GetCreatureName(id),
    sourceRank=QuestieOcto.DatabaseAPI:GetCreatureRank(id),
    respawnSeconds=QuestieOcto.DatabaseAPI:GetCreatureRespawnSeconds(id),
    itemID=itemID,itemName=itemID and QuestieOcto.DatabaseAPI:GetItemName(itemID) or nil,
    chance=chance,coords=ConditionalCreatureCoords(q,id,role) or QuestieOcto.DatabaseAPI:GetCreatureCoords(id),
    conditionalOffer=q and q.conditionalOffer or nil
  },objectiveState)
end

local function ObjectNode(questID,role,id,itemID,chance,objectiveState)
  local q=QuestieOcto.QuestModel:Get(questID)
  return ApplyObjectiveState({
    questID=questID,role=role,event=IsPresentationEvent(q),eventID=q and q.eventID or nil,pvp=q and q.pvp or false,repeatable=q and q.presentationRepeatable or false,
    sourceKind="gameObject",sourceID=id,
    sourceName=QuestieOcto.DatabaseAPI:GetObjectName(id),
    itemID=itemID,itemName=itemID and QuestieOcto.DatabaseAPI:GetItemName(itemID) or nil,
    chance=chance,coords=QuestieOcto.DatabaseAPI:GetObjectCoords(id)
  },objectiveState)
end

local function AddActiveNodes(nodes,mapID)
  if not QuestieOcto.Objectives.ready then return end
  for questID,state in pairs(QuestieOcto.QuestLog.active or {}) do
    local q=QuestieOcto.QuestModel:Get(questID)
    if q then
      if state.complete then
        for _,id in pairs(q.finishes.creature or {}) do
          local node=CreatureNode(questID,"turnin",id,nil,nil)
          if CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
        end
        for _,id in pairs(q.finishes.gameObject or {}) do
          local node=ObjectNode(questID,"turnin",id,nil,nil)
          if CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
        end
      else
        local resolved=QuestieOcto.Objectives.byQuest[questID]
        if resolved then
          for _,src in pairs(resolved.creature or {}) do
            if not src.complete then
              local node=CreatureNode(questID,"objectiveCreature",src.id,nil,nil,src)
              if CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
            end
          end
          for _,src in pairs(resolved.gameObject or {}) do
            if not src.complete then
              local node=ObjectNode(questID,"objectiveObject",src.id,nil,nil,src)
              if CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
            end
          end
          for _,item in pairs(resolved.item or {}) do
            if not item.complete then
              for _,src in pairs(item.sources or {}) do
                local node
                if src.kind=="creature" then
                  node=CreatureNode(questID,"objectiveItemSource",src.id,item.itemID,src.chance,item)
                else
                  node=ObjectNode(questID,"objectiveItemSource",src.id,item.itemID,src.chance,item)
                end
                if node and CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
              end
            end
          end
        end
      end
    end
  end
end

local function StarterTouchesMap(q,mapID)
  for _,id in pairs(q.starts.creature or {}) do
    if not QuestieOcto.DatabaseAPI.CreatureAllowsPlayerFaction or QuestieOcto.DatabaseAPI:CreatureAllowsPlayerFaction(id) then
      local coords=ConditionalCreatureCoords(q,id,"available") or QuestieOcto.DatabaseAPI:GetCreatureCoords(id)
      if CoordsContainMap(coords,mapID) then return true end
    end
  end

  for _,id in pairs(q.starts.gameObject or {}) do
    if (not QuestieOcto.DatabaseAPI.ObjectAllowsPlayerFaction or QuestieOcto.DatabaseAPI:ObjectAllowsPlayerFaction(id))
       and CoordsContainMap(QuestieOcto.DatabaseAPI:GetObjectCoords(id),mapID) then return true end
  end

  for _,itemID in pairs(q.starts.item or {}) do
    local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)
    if sources then
      for id,chance in pairs(sources.Creature or {}) do
        if QuestieOcto.ItemStarts:IsPositiveDropChance(chance)
           and CoordsContainMap(QuestieOcto.DatabaseAPI:GetCreatureCoords(id),mapID) then
          return true
        end
      end
      for id,chance in pairs(sources.GameObject or {}) do
        if QuestieOcto.ItemStarts:IsPositiveDropChance(chance)
           and CoordsContainMap(QuestieOcto.DatabaseAPI:GetObjectCoords(id),mapID) then
          return true
        end
      end
    end
  end

  return false
end

local function AddAvailableQuestNodes(nodes,q,mapID)
  for _,id in pairs(q.starts.creature or {}) do
    if not QuestieOcto.DatabaseAPI.CreatureAllowsPlayerFaction or QuestieOcto.DatabaseAPI:CreatureAllowsPlayerFaction(id) then
      local node=CreatureNode(q.id,"available",id,nil,nil)
      if CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
    end
  end

  for _,id in pairs(q.starts.gameObject or {}) do
    if not QuestieOcto.DatabaseAPI.ObjectAllowsPlayerFaction or QuestieOcto.DatabaseAPI:ObjectAllowsPlayerFaction(id) then
      local node=ObjectNode(q.id,"available",id,nil,nil)
      if CoordsContainMap(node.coords,mapID) then AddNode(nodes,node) end
    end
  end

  for _,itemID in pairs(q.starts.item or {}) do
    local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)
    if sources then
      for id,chance in pairs(sources.Creature or {}) do
        if QuestieOcto.ItemStarts:IsPositiveDropChance(chance) then
          local node=CreatureNode(q.id,"itemStart",id,itemID,chance)
          if CoordsContainMap(node.coords,mapID) then
            AddNode(nodes,node)
            Z.stats.itemSources=Z.stats.itemSources+1
          end
        end
      end
      for id,chance in pairs(sources.GameObject or {}) do
        if QuestieOcto.ItemStarts:IsPositiveDropChance(chance) then
          local node=ObjectNode(q.id,"itemStart",id,itemID,chance)
          if CoordsContainMap(node.coords,mapID) then
            AddNode(nodes,node)
            Z.stats.itemSources=Z.stats.itemSources+1
          end
        end
      end
    end
  end
end

local function DependenciesReady()
  return QuestieOcto.DatabaseAPI:IsReady()
     and QuestieOcto.Completion.ready
     and QuestieOcto.QuestLog.snapshot
     and QuestieOcto.Objectives.ready
end

function Z:Start(mapID)
  mapID=tonumber(mapID or QuestieOcto.API:GetBestMapForPlayer())
  if not mapID or not DependenciesReady() then return end

  self.requestedMapID=mapID
  self.stats.requests=(self.stats.requests or 0)+1

  self.generation=self.generation+1
  local generation=self.generation

  self.running=true
  self.ready=false
  self.mapID=mapID
  local requests=self.stats.requests or 0
  local cancelled=self.stats.cancelled or 0
  self.stats={scanned=0,candidates=0,available=0,nodes=0,itemSources=0,requests=requests,cancelled=cancelled,indexed=false,msHint="priority"}

  local ids=nil
  local indexed=false

  local candidateIndex=QuestieOcto.MapCandidateIndex
  if candidateIndex and candidateIndex.compiled then
    -- Release builds ship a complete, build-time validated starter/source index.
    -- An absent map bucket is therefore authoritative: there are zero available
    -- quest starters to scan on that map. Falling back to every packaged quest
    -- here made first visits to starter-less maps (notably battlegrounds such as
    -- Warsong Gulch) enqueue a needless 6,701-quest priority scan. Active quest
    -- objectives are still added separately above, so an empty starter bucket
    -- does not suppress legitimate active-objective presentation.
    ids=candidateIndex:Get(mapID)
    indexed=true
  elseif candidateIndex and candidateIndex:HasMap(mapID) then
    ids=candidateIndex:Get(mapID)
    indexed=true
  else
    -- Development/source mode can build the candidate index incrementally. Keep
    -- the old full-scan fallback there because a missing bucket may simply mean
    -- that indexing has not reached this map yet.
    ids=QuestieOcto.DatabaseAPI:GetQuestIDs()
  end

  self.stats.indexed=indexed
  local nodes={}
  AddActiveNodes(nodes,mapID)

  local pos=1
  local function step()
    if generation~=Z.generation then
      Z.stats.cancelled=(Z.stats.cancelled or 0)+1
      return
    end

    -- This pass is deliberately bounded so a first map visit cannot monopolize a Vanilla frame.
    -- Most quests fail the cheap starter-map test and never run eligibility.
    local count=0
    local batch=indexed and 400 or 160
    while pos<=table.getn(ids) and count<batch do
      local questID=ids[pos]
      pos=pos+1
      Z.stats.scanned=Z.stats.scanned+1

      local q=QuestieOcto.QuestModel:Get(questID)
      local touches=indexed or (q and StarterTouchesMap(q,mapID))

      if q and touches then
        Z.stats.candidates=Z.stats.candidates+1

        local available=QuestieOcto.AvailableQuests:EvaluateQuest(questID,false)
        if available then
          Z.stats.available=Z.stats.available+1
          AddAvailableQuestNodes(nodes,q,mapID)
        end
      end

      count=count+1
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"zone-priority-scan")
      return
    end

    Z.stats.nodes=table.getn(nodes)
    local plan=QuestieOcto.PreparedMap:BuildPlanFromNodes(mapID,nodes)
    local worldItemStartPlan=QuestieOcto.PreparedMap:BuildWorldItemStartPlanFromNodes(mapID,nodes)
    QuestieOcto.PreparedMap.stats.currentMap=mapID
    QuestieOcto.PreparedMap:SetPreparedMap(mapID,plan,worldItemStartPlan)

    Z.running=false
    Z.ready=true
    QuestieOcto:SendMessage("ZONE_BOOTSTRAP_READY",mapID)
  end

  QuestieOcto.Scheduler:Enqueue(step,"zone-priority-scan")
end

function Z:Request(mapID,delay)
  mapID=tonumber(mapID)
  if not mapID then return end

  -- Already prepared from a complete global build or earlier priority build:
  -- no need to run another zone scan.
  if QuestieOcto.PreparedMap:IsReady(mapID) then
    self.requestedMapID=mapID
    return
  end

  self.requestedMapID=mapID

  QuestieOcto.Scheduler:After(delay or 0.02,function()
    if tonumber(Z.requestedMapID)==mapID and not QuestieOcto.PreparedMap:IsReady(mapID) then
      Z:Start(mapID)
    end
  end,"zone-priority-request")
end

function Z:ScheduleCurrent()
  local current=QuestieOcto.API:GetBestMapForPlayer()
  if current then self:Request(current,0.05) end
end

function Z:OnAvailabilityReady()
  -- Do not invalidate the currently rendered plan here. Availability now
  -- publishes transactionally, and Nodes/PreparedMap will replace presentation
  -- only when the new node set is complete. Invalidating at this boundary made
  -- every settings toggle briefly render an empty map.
  local target=nil
  if WorldMapFrame and WorldMapFrame:IsVisible() then
    target=QuestieOcto.Map and QuestieOcto.Map:GetDisplayedMapID()
  end
  if not target then target=QuestieOcto.API:GetBestMapForPlayer() end
  if target then self:Request(target,0.01) end
end

function Z:OnDependencyReady()
  self:ScheduleCurrent()
end

QuestieOcto:RegisterMessage("AVAILABLE_QUESTS_READY",Z,"OnAvailabilityReady")
QuestieOcto:RegisterMessage("COMPLETION_READY",Z,"OnDependencyReady")
QuestieOcto:RegisterMessage("DATABASE_API_READY",Z,"OnDependencyReady")
