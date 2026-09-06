QuestieOcto.MapCandidateIndex = QuestieOcto.MapCandidateIndex or {}
local X = QuestieOcto.MapCandidateIndex

X.byMap=QuestieOcto.RuntimeMapCandidateIndex or {}
X.compiled=QuestieOcto.RuntimeMapCandidateIndex and true or false
X.ready=false
X.running=false
X.generation=0
X.stats={scanned=0,maps=0,links=0,currentReady=false,currentMap=nil}

local function Add(mapID,questID)
  mapID=tonumber(mapID)
  if not mapID then return end

  local bucket=X.byMap[mapID]
  if not bucket then
    bucket={}
    X.byMap[mapID]=bucket
    X.stats.maps=X.stats.maps+1
  end

  if not bucket[questID] then
    bucket[questID]=true
    X.stats.links=X.stats.links+1
  end
end

local function IndexCoords(coords,questID)
  local seen={}
  for _,coord in pairs(coords or {}) do
    if type(coord)=="table" and tonumber(coord[3]) then
      local mapID=tonumber(coord[3])
      if not seen[mapID] then
        seen[mapID]=true
        Add(mapID,questID)
      end
    end
  end
end

local function HasCoords(coords)
  for _,coord in pairs(coords or {}) do
    if type(coord)=="table" and tonumber(coord[1]) and tonumber(coord[2]) and tonumber(coord[3]) then
      return true
    end
  end
  return false
end

local function StarterCreatureCoords(q,creatureID)
  local marker=q and q.conditionalMapMarker or nil
  if marker and tonumber(marker.creatureID)==tonumber(creatureID) then
    return marker.coords
  end
  local coords=QuestieOcto.DatabaseAPI:GetCreatureCoords(creatureID)
  if HasCoords(coords) then return coords end
  local scripted=QuestieOcto.ScriptedEncounterData and QuestieOcto.ScriptedEncounterData[tonumber(creatureID)] or nil
  if scripted and (not scripted.roles or scripted.roles.available) then
    return scripted.coords or coords
  end
  return coords
end

local function IndexQuest(q)
  if not q then return end

  for _,id in pairs(q.starts.creature or {}) do
    IndexCoords(StarterCreatureCoords(q,id),q.id)
  end

  for _,id in pairs(q.starts.gameObject or {}) do
    IndexCoords(QuestieOcto.DatabaseAPI:GetObjectCoords(id),q.id)
  end

  for _,itemID in pairs(q.starts.item or {}) do
    local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)

    if sources then
      for id in pairs(sources.Creature or {}) do
        IndexCoords(QuestieOcto.DatabaseAPI:GetCreatureCoords(id),q.id)
      end
      for id in pairs(sources.GameObject or {}) do
        IndexCoords(QuestieOcto.DatabaseAPI:GetObjectCoords(id),q.id)
      end
    end
  end
end

function X:Get(mapID)
  local bucket=self.byMap[tonumber(mapID)]
  if self.compiled then
    -- Build-time candidate buckets are already sorted arrays and are read-only
    -- for all current consumers, so return them directly without allocating and
    -- sorting a fresh list every zone visit.
    return bucket or {}
  end

  local ids={}
  if bucket then
    for questID in pairs(bucket) do table.insert(ids,questID) end
    table.sort(ids)
  end
  return ids
end

function X:HasMap(mapID)
  return self.byMap[tonumber(mapID)] and true or false
end

function X:Build()
  if not QuestieOcto.DatabaseAPI:IsReady() then return end

  if self.compiled then
    local stats=QuestieOcto.RuntimeDatabaseStats or {}
    self.running=false
    self.ready=true
    self.stats={
      scanned=QuestieOcto.DatabaseAPI:GetQuestCount(),
      maps=tonumber(stats.maps) or 0,
      links=tonumber(stats.links) or 0,
      currentReady=true,
      currentMap=QuestieOcto.API:GetBestMapForPlayer()
    }
    if self.stats.currentMap then QuestieOcto:SendMessage("MAP_CANDIDATE_INDEX_CURRENT",self.stats.currentMap) end
    QuestieOcto:SendMessage("MAP_CANDIDATE_INDEX_READY")
    return
  end

  self.generation=self.generation+1
  local generation=self.generation

  self.byMap={}
  self.ready=false
  self.running=true
  self.stats={scanned=0,maps=0,links=0,currentReady=false,currentMap=QuestieOcto.API:GetBestMapForPlayer()}

  local ids=QuestieOcto.DatabaseAPI:GetQuestIDs()
  local current=self.stats.currentMap

  -- Current map receives a direct synchronous-ish first slice so the initial
  -- zone remains fast even before the whole index exists.
  local pos=1

  local function step()
    if generation~=X.generation then return end

    local count=0
    while pos<=table.getn(ids) and count<256 do
      local questID=ids[pos]
      pos=pos+1
      X.stats.scanned=X.stats.scanned+1

      IndexQuest(QuestieOcto.QuestModel:Get(questID))
      count=count+1
    end

    if current and X.byMap[tonumber(current)] then
      X.stats.currentReady=true
      QuestieOcto:SendMessage("MAP_CANDIDATE_INDEX_CURRENT",current)
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"map-candidate-index")
    else
      X.running=false
      X.ready=true
      X.stats.currentReady=true
      QuestieOcto:SendMessage("MAP_CANDIDATE_INDEX_READY")
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"map-candidate-index")
end

function X:OnDatabaseReady()
  self:Build()
end

QuestieOcto:RegisterMessage("DATABASE_API_READY",X,"OnDatabaseReady")
