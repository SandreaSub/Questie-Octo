QuestieOcto.PreparedMap = QuestieOcto.PreparedMap or {}
local P = QuestieOcto.PreparedMap

P.cache={}
P.readyMaps={}
P.cacheRevision={}
P.worldItemStartCache={}
P.worldItemStartRevision={}
P.cacheDensity={}
P.stateRevision=1
P.running=false
P.generation=0
P.dirtyGeneration=0
P.stats={preparedMaps=0,descriptors=0,currentMap=nil,currentReady=false,stateRevision=1,revisionBumps=0,densitySignature="unknown"}

local function CurrentDensitySignature()
  local settings=QuestieOcto.MinimapSettings
  if not settings or not settings.Get then return "clustered:clustered" end
  return tostring(settings:Get("objectiveNodeDensity") or "clustered")..":"..
    tostring(settings:Get("itemStartDensity") or "clustered")
end

function P:GetDensitySignature(mapID)
  mapID=tonumber(mapID)
  if not mapID then return nil end
  return self.cacheDensity[mapID]
end

function P:GetCurrentDensitySignature()
  return CurrentDensitySignature()
end

local function ExactRole(role)
  return role=="available" or role=="turnin" or role=="objectiveArea" or role=="flightMaster"
      or role=="auctioneer" or role=="banker" or role=="mailbox"
      or role=="battlemaster" or role=="innkeeper" or role=="meetingStone"
      or role=="repair" or role=="spiritHealer" or role=="stableMaster" or role=="vendor"
      or role=="rareMob"
end

local function DescriptorKey(node,x,y)
  -- Questie 5/6/3.3.5 places available and complete frames on the same source
  -- coordinate, with the complete texture one draw level above available.
  -- pfQuest likewise resolves coincident quest nodes by visual layer. Collapse
  -- those two semantic entries into one prepared pin so the tooltip retains
  -- both quests while Questie-Octo's turn-in priority selects the complete icon.
  if node.role=="available" or node.role=="turnin" then
    return "exact:quest-source:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
      string.format("%.2f",x)..":"..string.format("%.2f",y)
  end

  return "exact:"..tostring(node.questID)..":"..tostring(node.role)..":"..
    tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
    string.format("%.2f",x)..":"..string.format("%.2f",y)
end

local function AreaKey(node,area)
  return "area:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
    tostring(area.key)
end

local function FullPointKey(prefix,node,x,y)
  -- Full Nodes means every UNIQUE spawn coordinate. Multiple active quests or
  -- item objectives can reference the exact same spawn; pfQuest stores those
  -- references in one coordinate slot and combines their tooltip metadata.
  -- Keep item-start and objective namespaces compatible by sharing the same
  -- quest-coordinate key so one physical spawn never allocates duplicate pins.
  return "full:quest:"..string.format("%.2f",x)..":"..string.format("%.2f",y)
end

local function ContextualKey(key,context)
  if not context then return key end
  return tostring(key)..":context:"..tostring(context)
end

local function SharedPreparationContextResolver(mapID)
  local shared=QuestieOcto.SharedInstanceContext
  if not shared or not shared:IsSharedArea(mapID) then return nil end

  return function(node,x,y)
    return shared:GetSourceContext(
      node and node.sourceKind,node and node.sourceID,x,y,mapID
    )
  end
end

local function PointGroupsForNode(node,mapID,contextResolver)
  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,mapID)
  if not contextResolver then return {{points=points}} end

  local byContext={}
  local _,point
  for _,point in pairs(points or {}) do
    local context=contextResolver(node,point.x,point.y)
    if context then
      local group=byContext[context]
      if not group then
        group={context=context,points={}}
        byContext[context]=group
      end
      table.insert(group.points,point)
    end
  end

  local groups={}
  for _,group in pairs(byContext) do table.insert(groups,group) end
  table.sort(groups,function(a,b) return tostring(a.context)<tostring(b.context) end)
  return groups
end

local function AddNormal(plan,slots,node,x,y,clusterCount,kind,key,preparedMapContext)
  local slot=slots[key]
  if not slot then
    slot={
      type="nodeSlot",
      x=x,
      y=y,
      key=key,
      coordKey=string.format("%.2f:%.2f",x,y),
      preparedMapContext=nil,
      entries={}
    }
    slots[key]=slot
    table.insert(plan,slot)
  end

  if preparedMapContext then
    if slot.preparedMapContext and slot.preparedMapContext~=preparedMapContext then
      return
    end
    slot.preparedMapContext=preparedMapContext
  end

  table.insert(slot.entries,{
    node=node,
    clusterCount=clusterCount or 1,
    kind=kind
  })
end

function P:BuildPlanFromNodes(mapID,nodes)
  mapID=tonumber(mapID)
  if not mapID then return nil end

  local plan={}
  local slots={}
  local contextResolver=SharedPreparationContextResolver(mapID)

  for _,node in pairs(nodes or {}) do
    if node.role~="itemStart" then
      local pointGroups=PointGroupsForNode(node,mapID,contextResolver)

      if ExactRole(node.role) then
        for _,group in pairs(pointGroups) do
          for _,point in pairs(group.points or {}) do
            local key=ContextualKey(DescriptorKey(node,point.x,point.y),group.context)
            AddNormal(
              plan,slots,node,point.x,point.y,1,"exact",key,group.context
            )
          end
        end
      elseif QuestieOcto.MinimapSettings:Get("objectiveNodeDensity")=="full" then
        for _,group in pairs(pointGroups) do
          for _,point in pairs(group.points or {}) do
            local key=ContextualKey(FullPointKey("objective-full",node,point.x,point.y),group.context)
            AddNormal(
              plan,slots,node,point.x,point.y,1,"objectiveFull",key,group.context
            )
          end
        end
      else
        for _,group in pairs(pointGroups) do
          local areas=QuestieOcto.Clustering:BuildAreas(
            group.points,QuestieOcto.Clustering.objectiveRadius
          )

          for _,area in pairs(areas) do
            local key=ContextualKey(AreaKey(node,area),group.context)
            AddNormal(plan,slots,node,area.x,area.y,area.n,"objective",key,group.context)
          end
        end
      end
    end
  end

  if QuestieOcto.MinimapSettings:Get("itemStartDensity")=="full" then
    for _,node in pairs(nodes or {}) do
      if node.role=="itemStart" then
        local pointGroups=PointGroupsForNode(node,mapID,contextResolver)
        for _,group in pairs(pointGroups) do
          for _,point in pairs(group.points or {}) do
            local key=ContextualKey(FullPointKey("itemstart-full",node,point.x,point.y),group.context)
            AddNormal(
              plan,slots,node,point.x,point.y,1,"itemStartFull",key,group.context
            )
          end
        end
      end
    end
  else
    local itemAreas=QuestieOcto.ItemStartAreas:BuildForMap(nodes or {},mapID,nil,contextResolver)
    for _,area in pairs(itemAreas) do
      table.insert(plan,{
        type="itemStartArea",
        area=area,
        preparedMapContext=area.preparedMapContext,
        key="itemarea:"..tostring(area.key)
      })
    end
  end

  table.sort(plan,function(a,b)
    return tostring(a.key)<tostring(b.key)
  end)

  return plan
end



local function IsWorldMapUltraRareItemStart(node)
  return node and node.role=="itemStart" and QuestieOcto.ItemStartAreas
     and QuestieOcto.ItemStartAreas:IsZoneWideRareChance(node.chance) and true or false
end

function P:BuildWorldItemStartPlanFromNodes(mapID,nodes)
  mapID=tonumber(mapID)
  if not mapID then return nil end

  local plan={}
  local slots={}
  local density=QuestieOcto.MinimapSettings:Get("itemStartDensity")
  local contextResolver=SharedPreparationContextResolver(mapID)

  if density=="full" then
    for _,node in pairs(nodes or {}) do
      if node.role=="itemStart" and not IsWorldMapUltraRareItemStart(node) then
        local pointGroups=PointGroupsForNode(node,mapID,contextResolver)
        for _,group in pairs(pointGroups) do
          for _,point in pairs(group.points or {}) do
            local key=ContextualKey(FullPointKey("itemstart-full",node,point.x,point.y),group.context)
            AddNormal(
              plan,slots,node,point.x,point.y,1,"itemStartFull",key,group.context
            )
          end
        end
      end
    end
  else
    local normalAreas=QuestieOcto.ItemStartAreas:BuildForMap(
      nodes or {},mapID,
      function(node) return not IsWorldMapUltraRareItemStart(node) end,
      contextResolver
    )
    for _,area in pairs(normalAreas) do
      table.insert(plan,{
        type="itemStartArea",
        area=area,
        preparedMapContext=area.preparedMapContext,
        key="itemarea:"..tostring(area.key)
      })
    end
  end

  local rareAreas=QuestieOcto.ItemStartAreas:BuildZoneWideRareForMap(
    nodes or {},mapID,contextResolver
  )
  for _,area in pairs(rareAreas) do
    table.insert(plan,{
      type="itemStartArea",
      area=area,
      preparedMapContext=area.preparedMapContext,
      key="itemrarearea:"..tostring(area.key)
    })
  end

  table.sort(plan,function(a,b) return tostring(a.key)<tostring(b.key) end)
  return plan
end


function P:SetPreparedMap(mapID,plan,worldItemStartPlan,densitySignature)
  mapID=tonumber(mapID)
  if not mapID or not plan then return nil end

  local wasReady=self.readyMaps[mapID] and true or false
  local old=self.cache[mapID]
  local oldCount=old and table.getn(old) or 0

  self.cache[mapID]=plan
  self.readyMaps[mapID]=true
  self.cacheRevision[mapID]=self.stateRevision
  self.worldItemStartCache[mapID]=worldItemStartPlan or {}
  self.worldItemStartRevision[mapID]=self.stateRevision
  self.cacheDensity[mapID]=densitySignature or CurrentDensitySignature()

  if not wasReady then
    self.stats.preparedMaps=self.stats.preparedMaps+1
  end

  self.stats.descriptors=self.stats.descriptors-oldCount+table.getn(plan)

  if tonumber(self.stats.currentMap)==mapID then
    self.stats.currentReady=true
  end

  QuestieOcto:SendMessage("PREPARED_MAP_READY",mapID)
  return plan
end

function P:BuildMap(mapID)
  mapID=tonumber(mapID)
  if not mapID or not QuestieOcto.Nodes.ready then return nil end

  local nodes=QuestieOcto.Nodes:GetMapNodes(mapID)
  local plan=self:BuildPlanFromNodes(mapID,nodes)
  local worldItemStartPlan=self:BuildWorldItemStartPlanFromNodes(mapID,nodes)
  return self:SetPreparedMap(mapID,plan,worldItemStartPlan,CurrentDensitySignature())
end

function P:Get(mapID)
  mapID=tonumber(mapID)
  if not mapID then return nil end
  if self.cacheRevision[mapID]~=self.stateRevision then return nil end
  if self.cacheDensity[mapID]~=CurrentDensitySignature() then return nil end
  return self.cache[mapID]
end

function P:GetWorldItemStarts(mapID)
  mapID=tonumber(mapID)
  if not mapID then return nil end
  if self.worldItemStartRevision[mapID]~=self.stateRevision then return nil end
  if self.cacheDensity[mapID]~=CurrentDensitySignature() then return nil end
  return self.worldItemStartCache[mapID]
end

function P:IsReady(mapID)
  mapID=tonumber(mapID)
  return mapID
     and self.readyMaps[mapID]
     and self.cacheRevision[mapID]==self.stateRevision
     and self.cacheDensity[mapID]==CurrentDensitySignature()
     and true or false
end

local function RemoveQuestFromDescriptor(desc,questID)
  if not desc then return false,0 end

  if desc.type=="itemStartArea" and desc.area then
    if tonumber(desc.area.questID)==questID then return true,1 end
    return false,0
  end

  if desc.type=="nodeSlot" then
    local kept={}
    local removed=0
    for _,entry in pairs(desc.entries or {}) do
      if entry.node and tonumber(entry.node.questID)==questID then
        removed=removed+1
      else
        table.insert(kept,entry)
      end
    end
    desc.entries=kept
    return table.getn(kept)==0,removed
  end

  if desc.type=="node" and desc.node and tonumber(desc.node.questID)==questID then
    return true,1
  end

  return false,0
end


local function RemoveChangedFromDescriptor(desc,changed)
  if not desc then return false,0 end

  if desc.type=="itemStartArea" and desc.area then
    if changed[tonumber(desc.area.questID)] then return true,1 end
    return false,0
  end

  if desc.type=="nodeSlot" then
    local kept={}
    local removed=0
    for _,entry in pairs(desc.entries or {}) do
      if entry.node and changed[tonumber(entry.node.questID)] then
        removed=removed+1
      else
        table.insert(kept,entry)
      end
    end
    desc.entries=kept
    return table.getn(kept)==0,removed
  end

  if desc.type=="node" and desc.node and changed[tonumber(desc.node.questID)] then
    return true,1
  end

  return false,0
end

local function QuestRemovalMapSet(self,questID)
  -- Nodes already maintains the authoritative reverse quest -> map index used
  -- by incremental map patches. Reuse it here instead of introducing another
  -- persistent PreparedMap index/table just for immediate quest removals.
  local nodes=QuestieOcto.Nodes
  if nodes and nodes.ready and nodes.questMaps then
    local indexed=nodes.questMaps[questID]
    if indexed and next(indexed) then return indexed,true end

    -- Once Nodes is authoritative, an absent reverse entry is an authoritative
    -- empty set. This is also the normal duplicate-event case after the first
    -- removal already cleared the quest. Do not fall back to a global sweep.
    return {},true
  end

  -- Startup/race compatibility: before semantic Nodes are authoritative, keep
  -- the historical full-cache sweep rather than risking stale prepared pins.
  return self.cache,false
end

function P:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return 0 end

  local mapSet,indexed=QuestRemovalMapSet(self,questID)
  local removed=0
  local droppedDescriptors=0

  for rawMapID in pairs(mapSet or {}) do
    local mapID=tonumber(rawMapID)
    local plan=mapID and self.cache[mapID] or nil
    if plan then
      local filtered={}
      local before=table.getn(plan)
      for _,desc in pairs(plan) do
        local drop,count=RemoveQuestFromDescriptor(desc,questID)
        removed=removed+(count or 0)
        if not drop then table.insert(filtered,desc) end
      end
      self.cache[mapID]=filtered
      droppedDescriptors=droppedDescriptors+before-table.getn(filtered)
    end

    local worldPlan=mapID and self.worldItemStartCache[mapID] or nil
    if worldPlan then
      local filtered={}
      for _,desc in pairs(worldPlan) do
        local drop,count=RemoveQuestFromDescriptor(desc,questID)
        removed=removed+(count or 0)
        if not drop then table.insert(filtered,desc) end
      end
      self.worldItemStartCache[mapID]=filtered
    end
  end

  -- A second compatibility event for the same turn-in can arrive after the
  -- immediate removal. Once the quest metadata is already gone, return without
  -- another global revision bump/recount. The first removal did the real work.
  if removed==0 then return 0 end

  self.stateRevision=self.stateRevision+1
  self.stats.stateRevision=self.stateRevision
  self.stats.revisionBumps=(self.stats.revisionBumps or 0)+1
  self.stats.currentReady=false
  self.lastRevisionReason=indexed and "quest-remove-local" or "quest-remove-fallback"

  -- stateRevision is global cache validity metadata, so ready maps still need
  -- their revision stamp advanced. This is O(number of prepared maps) but does
  -- not inspect or allocate their descriptor plans.
  for mapID in pairs(self.readyMaps or {}) do
    self.cacheRevision[mapID]=self.stateRevision
    self.worldItemStartRevision[mapID]=self.stateRevision
  end

  -- `descriptors` counts coordinate slots in the normal prepared cache. We know
  -- exactly how many slots disappeared from the affected maps, so avoid the old
  -- second full-cache recount.
  self.stats.descriptors=math.max(0,(self.stats.descriptors or 0)-droppedDescriptors)
  if self.stats.currentMap and self.readyMaps[self.stats.currentMap] then
    self.stats.currentReady=true
  end

  return removed
end

function P:BumpStateRevision(reason)
  self.stateRevision=self.stateRevision+1
  self.stats.stateRevision=self.stateRevision
  self.stats.revisionBumps=(self.stats.revisionBumps or 0)+1
  self.stats.currentReady=false
  self.lastRevisionReason=reason
end

function P:Invalidate()
  self.generation=self.generation+1
  self.dirtyGeneration=(self.dirtyGeneration or 0)+1
  self.cache={}
  self.readyMaps={}
  self.cacheRevision={}
  self.worldItemStartCache={}
  self.worldItemStartRevision={}
  self.cacheDensity={}
  self.running=false
  self.stats.preparedMaps=0
  self.stats.descriptors=0
  self.stats.currentReady=false
end

function P:PrepareAll(reason)
  if not QuestieOcto.Nodes.ready then return end

  -- A full preparation pass supersedes every queued incremental prepared-map
  -- patch. Density changes in particular must not let an older dirty job publish
  -- a mixed Clustered/Full plan after the authoritative rebuild has started.
  self.dirtyGeneration=(self.dirtyGeneration or 0)+1
  local densitySignature=CurrentDensitySignature()
  self.stats.densitySignature=densitySignature
  self.lastPrepareReason=reason or "full"

  -- Transactional map-plan rebuild. Keep every currently published plan alive
  -- until that specific map's replacement is ready; density/filter toggles
  -- must never invalidate the live cache first and make pins blink off/on.
  self.generation=self.generation+1
  local generation=self.generation
  self.running=true

  local current=QuestieOcto.API:GetBestMapForPlayer()
  self.stats.currentMap=current

  -- Density changes are shared by the minimap and World Map, but the two can
  -- be looking at different maps. The minimap always follows `current`, while
  -- the World Map can stay open on any selected zone. Rebuild both visible
  -- contexts first so Clustered <-> Full Nodes changes are immediate on each
  -- presentation instead of waiting for the displayed World Map zone to be
  -- reached by the background PrepareAll pass.
  local displayed=nil
  if QuestieOcto.Map then
    if WorldMapFrame and WorldMapFrame:IsVisible() and QuestieOcto.Map.GetDisplayedMapID then
      displayed=QuestieOcto.Map:GetDisplayedMapID()
    elseif tonumber(QuestieOcto.Map.mapID) and tonumber(QuestieOcto.Map.mapID)>0 then
      -- The options window can be used while the World Map is hidden. Preserve
      -- the last selected zone as a priority target so reopening that same zone
      -- never sees the previous density plan.
      displayed=tonumber(QuestieOcto.Map.mapID)
    end
  end

  local mapSet={}
  for mapID in pairs(QuestieOcto.Nodes.byMap or {}) do mapSet[tonumber(mapID)]=true end
  -- Include formerly populated maps so a rebuild that legitimately removes
  -- every node from a map publishes an empty plan rather than leaving stale pins.
  for mapID in pairs(self.readyMaps or {}) do mapSet[tonumber(mapID)]=true end

  local ids={}
  for mapID in pairs(mapSet) do if mapID then table.insert(ids,mapID) end end
  table.sort(ids)

  local function publishMap(mapID)
    if generation~=P.generation then return false end
    local nodes=QuestieOcto.Nodes:GetMapNodes(mapID)
    local plan=P:BuildPlanFromNodes(mapID,nodes) or {}
    local worldItemStartPlan=P:BuildWorldItemStartPlanFromNodes(mapID,nodes) or {}
    P:SetPreparedMap(mapID,plan,worldItemStartPlan,densitySignature)
    return true
  end

  -- Publish the open World Map zone first, then the player's current zone for
  -- the minimap. Either may be the same map. SetPreparedMap broadcasts
  -- PREPARED_MAP_READY, so both renderers immediately consume the replacement.
  if displayed and mapSet[tonumber(displayed)] then
    publishMap(tonumber(displayed))
  end
  if current and tonumber(current)~=tonumber(displayed) and mapSet[tonumber(current)] then
    publishMap(tonumber(current))
  end

  local pos=1
  local function step()
    if generation~=P.generation then return end

    local requested=QuestieOcto.ZoneBootstrap and QuestieOcto.ZoneBootstrap.requestedMapID
    if requested and not P.readyMaps[tonumber(requested)] and QuestieOcto.ZoneBootstrap.running then
      QuestieOcto.Scheduler:Enqueue(step,"prepare-maps-yield")
      return
    end

    local count=0
    while pos<=table.getn(ids) and count<1 do
      local mapID=ids[pos]
      pos=pos+1
      if tonumber(mapID)~=tonumber(current) and tonumber(mapID)~=tonumber(displayed) then
        publishMap(mapID)
        count=count+1
      end
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"prepare-maps")
    else
      P.running=false
      QuestieOcto:SendMessage("PREPARED_MAPS_COMPLETE")
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"prepare-maps")
end

function P:OnNodesReady()
  self:PrepareAll("nodes-ready")
end

QuestieOcto:RegisterMessage("NODES_READY",P,"OnNodesReady")

local function DescriptorKeyValue(desc)
  return desc and tostring(desc.key or "") or ""
end

local function ClonePreparedDescriptor(desc)
  if not desc then return nil end
  if desc.type~="nodeSlot" then return desc end

  -- PatchMaps removes quest entries from a descriptor. Clone the slot first so
  -- the currently published PreparedMap (which the minimap may still be using)
  -- is never mutated before its replacement is complete and published.
  local copy={}
  for key,value in pairs(desc) do
    if key~="entries" then copy[key]=value end
  end
  copy.entries={}
  for _,entry in pairs(desc.entries or {}) do table.insert(copy.entries,entry) end
  return copy
end

local function MergePreparedDescriptor(byKey,plan,desc)
  if not desc then return end
  local key=DescriptorKeyValue(desc)
  local existing=byKey[key]

  if existing and existing.type=="nodeSlot" and desc.type=="nodeSlot" then
    for _,entry in pairs(desc.entries or {}) do table.insert(existing.entries,entry) end
    return
  end

  -- Item-start areas are quest-specific and exact/full node-slot keys are
  -- canonical. A same-key non-slot descriptor is safely replaced.
  if existing then
    for i,current in ipairs(plan) do
      if current==existing then plan[i]=desc; break end
    end
    byKey[key]=desc
    return
  end

  byKey[key]=desc
  table.insert(plan,desc)
end

function P:PatchMaps(mapSet,changedQuests)
  if not QuestieOcto.Nodes.ready then return end

  local changed={}
  for questID in pairs(changedQuests or {}) do
    questID=tonumber(questID)
    if questID and questID>0 then changed[questID]=true end
  end
  if not next(changed) then
    -- Compatibility/fallback for an older producer that did not provide the
    -- reverse quest set: rebuilding just the affected maps is still bounded.
    return self:RebuildMaps(mapSet)
  end

  local ids={}
  for mapID in pairs(mapSet or {}) do
    mapID=tonumber(mapID)
    if mapID then table.insert(ids,mapID) end
  end
  table.sort(ids)
  if table.getn(ids)==0 then return end

  -- Incremental node publications may arrive close together (for example two
  -- quests completing in adjacent frames). They all read the latest canonical
  -- Nodes state and are safe to interleave. Do NOT advance dirtyGeneration here:
  -- doing so cancelled the older patch outright and could leave one quest's map
  -- state stale until an unrelated option forced a rebuild. Full PrepareAll /
  -- Invalidate still advance dirtyGeneration and therefore remain authoritative.
  local generation=self.dirtyGeneration
  local pos=1

  local function step()
    if generation~=P.dirtyGeneration then return end
    local mapID=ids[pos]
    pos=pos+1

    if mapID then
      local existing=P:Get(mapID)
      if not existing then
        -- First visit / stale cache: build the authoritative map once.
        P:BuildMap(mapID)
      else
        -- pfQuest-style reverse update: remove only the changed quests' metadata
        -- from existing coordinate slots, then merge descriptors produced by
        -- those quests' new semantic state. Unrelated coordinates/clusters are
        -- never rediscovered or reclustered.
        local plan={}
        local byKey={}
        for _,desc in pairs(existing) do
          local candidate=ClonePreparedDescriptor(desc)
          local drop=RemoveChangedFromDescriptor(candidate,changed)
          if not drop then
            table.insert(plan,candidate)
            byKey[DescriptorKeyValue(candidate)]=candidate
          end
        end

        -- Scan the affected map's canonical nodes once, regardless of how many
        -- quests changed. The old descriptor loop multiplied every descriptor
        -- by every changed quest.
        local changedNodes={}
        for _,node in pairs(QuestieOcto.Nodes:GetMapNodes(mapID) or {}) do
          if changed[tonumber(node.questID)] then table.insert(changedNodes,node) end
        end
        local delta=P:BuildPlanFromNodes(mapID,changedNodes) or {}
        for _,desc in pairs(delta) do MergePreparedDescriptor(byKey,plan,desc) end
        table.sort(plan,function(a,b) return DescriptorKeyValue(a)<DescriptorKeyValue(b) end)

        -- Item-start geographic areas are quest-specific. Patch only the
        -- changed quests here as well instead of rebuilding every item-start
        -- area on the map for a local availability/objective change.
        local worldItemStartPlan={}
        local worldByKey={}
        for _,desc in pairs(P:GetWorldItemStarts(mapID) or {}) do
          local candidate=ClonePreparedDescriptor(desc)
          local drop=RemoveChangedFromDescriptor(candidate,changed)
          if not drop then
            table.insert(worldItemStartPlan,candidate)
            worldByKey[DescriptorKeyValue(candidate)]=candidate
          end
        end
        local worldDelta=P:BuildWorldItemStartPlanFromNodes(mapID,changedNodes) or {}
        for _,desc in pairs(worldDelta) do MergePreparedDescriptor(worldByKey,worldItemStartPlan,desc) end
        table.sort(worldItemStartPlan,function(a,b) return DescriptorKeyValue(a)<DescriptorKeyValue(b) end)

        P:SetPreparedMap(mapID,plan,worldItemStartPlan,CurrentDensitySignature())
      end
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"prepare-dirty-maps")
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"prepare-dirty-maps")
end

function P:RebuildMaps(mapSet)
  if not QuestieOcto.Nodes.ready then return end

  local ids={}
  for mapID in pairs(mapSet or {}) do
    mapID=tonumber(mapID)
    if mapID then table.insert(ids,mapID) end
  end
  table.sort(ids)
  if table.getn(ids)==0 then return end

  -- Incremental node publications may arrive close together (for example two
  -- quests completing in adjacent frames). They all read the latest canonical
  -- Nodes state and are safe to interleave. Do NOT advance dirtyGeneration here:
  -- doing so cancelled the older patch outright and could leave one quest's map
  -- state stale until an unrelated option forced a rebuild. Full PrepareAll /
  -- Invalidate still advance dirtyGeneration and therefore remain authoritative.
  local generation=self.dirtyGeneration
  local pos=1

  local function step()
    if generation~=P.dirtyGeneration then return end
    local mapID=ids[pos]
    pos=pos+1
    if mapID then
      local nodes=QuestieOcto.Nodes:GetMapNodes(mapID)
      local plan=P:BuildPlanFromNodes(mapID,nodes) or {}
      local worldItemStartPlan=P:BuildWorldItemStartPlanFromNodes(mapID,nodes) or {}
      P:SetPreparedMap(mapID,plan,worldItemStartPlan,CurrentDensitySignature())
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"prepare-dirty-maps")
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"prepare-dirty-maps")
end

function P:OnNodesChanged(mapSet,changedQuests)
  self:PatchMaps(mapSet,changedQuests)
end

QuestieOcto:RegisterMessage("NODES_CHANGED",P,"OnNodesChanged")
