QuestieOcto.API = QuestieOcto.API or {}
local A = QuestieOcto.API

A.valid = false
A.missing = {}
A.optional = {}

local function Has(tableValue, functionName)
  return tableValue and type(tableValue[functionName])=="function"
end

function A:Validate()
  self.missing = {}

  local required = {
    { "C_QuestLog.GetQuestIDForLogIndex", C_QuestLog, "GetQuestIDForLogIndex" },
    { "C_QuestLog.GetLogIndexForQuestID", C_QuestLog, "GetLogIndexForQuestID" },
    { "C_QuestLog.IsOnQuest", C_QuestLog, "IsOnQuest" },
    { "C_Map.GetBestMapForUnit", C_Map, "GetBestMapForUnit" },
    { "C_GossipInfo.GetAvailableQuests", C_GossipInfo, "GetAvailableQuests" },
    { "C_CreatureInfo.GetCreatureID", C_CreatureInfo, "GetCreatureID" },
    { "C_GameObjectInfo.GetGameObjectInfoByID", C_GameObjectInfo, "GetGameObjectInfoByID" },
    { "C_Item.GetItemNameByID", C_Item, "GetItemNameByID" },
  }

  for _,req in pairs(required) do
    if not Has(req[2],req[3]) then table.insert(self.missing,req[1]) end
  end

  self.valid = table.getn(self.missing)==0

  self.optional = {
    coroutines = coroutine and type(coroutine.create)=="function",
    hooksecurefunc = type(hooksecurefunc)=="function",
    tooltipUnit = GameTooltip and type(GameTooltip.GetUnitGUID)=="function",
    tooltipObject = GameTooltip and type(GameTooltip.GetGameObject)=="function",
    tooltipItem = GameTooltip and type(GameTooltip.GetItem)=="function",
    gossipActive = Has(C_GossipInfo,"GetActiveQuests"),
    questDetails = Has(C_QuestLog,"GetQuestDetails"),
    questObjectives = Has(C_QuestLog,"GetQuestObjectives"),
    questHeaderIndex = Has(C_QuestLog,"GetHeaderIndexForQuest"),
    questsCompleted = type(GetQuestsCompleted)=="function" or Has(C_QuestLog,"GetQuestsCompleted"),
    queryQuestsCompleted = type(QueryQuestsCompleted)=="function",
    questFlaggedCompleted = type(IsQuestFlaggedCompleted)=="function" or Has(C_QuestLog,"IsQuestFlaggedCompleted"),
    mapWorldSize = Has(C_Map,"GetMapWorldSize"),
    mapAreas = Has(C_Map,"GetAreas"),
    mapAreaIDs = Has(C_Map,"GetMapAreaIDs"),
    instanceInfo = type(GetInstanceInfo)=="function",
    leaderboardObjectiveID = type(GetQuestLogLeaderBoardID)=="function",
    areaTriggerInfo = Has(C_Map,"GetAreaTriggerInfo"),
  }

  return self.valid
end

function A:GetQuestIDForLogIndex(index)
  if not self.valid then return nil end
  -- Some ClassicAPI lookups return no Lua values when the quest/index no
  -- longer exists. Capture the result first so callers always receive one
  -- explicit value (nil when absent), which is safe for Lua 5.0 tonumber().
  local questID=C_QuestLog.GetQuestIDForLogIndex(index)
  return questID
end

-- Questie-facing normalized quest-log info.
--
-- Questie 5.2.3/6.0.0 and Questie 3.3.5 all consume the normalized fields
--   title, level, tag, isHeader, isCollapsed, isComplete, frequency, questID.
--
-- The raw client signature differs by expansion. For our actual target
-- Interface 11200, the supplied pfQuest Vanilla compatibility layer confirms:
--   title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(index)
-- There is NO suggestedGroup return on Vanilla 1.12.
--
-- Questie 3.3.5's raw suggestedGroup handling is a WotLK-era compatibility
-- detail, so applying it directly to Turtle 11200 shifts completion by one
-- field and makes completed quests look incomplete.
function A:GetQuestLogInfo(index)
  if not GetQuestLogTitle then return nil end

  local _,_,_,client=GetBuildInfo()
  client=tonumber(client) or 11200

  local title,level,tag,isHeader,isCollapsed,isComplete,isDaily,rawQuestID

  if client<=11200 then
    title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(index)
  else
    local suggestedGroup
    title,level,tag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily,rawQuestID=GetQuestLogTitle(index)
  end

  local questID=self:GetQuestIDForLogIndex(index) or tonumber(rawQuestID)

  return {
    title=title,
    level=level,
    tag=tag,
    isHeader=isHeader and true or false,
    isCollapsed=isCollapsed and true or false,
    isComplete=isComplete,
    isDaily=isDaily,
    questID=questID
  }
end

function A:GetLogIndexForQuestID(questID)
  if not self.valid then return nil end
  -- See GetQuestIDForLogIndex above: normalize a C-side no-return result to
  -- one explicit nil so Lua 5.0 callers never invoke tonumber() with 0 args.
  local index=C_QuestLog.GetLogIndexForQuestID(questID)
  return index
end

-- ClassicAPI exposes the quest's native zone-header index even when that
-- header is collapsed. This avoids assigning a hidden quest to a neighbouring
-- visible header after Vanilla removes the collapsed child rows.
function A:GetHeaderIndexForQuest(questID)
  questID=tonumber(questID)
  if not questID or not C_QuestLog or type(C_QuestLog.GetHeaderIndexForQuest)~="function" then return nil end
  local ok,index=pcall(C_QuestLog.GetHeaderIndexForQuest,questID)
  index=ok and tonumber(index) or nil
  if not index or index<=0 then return nil end
  return index
end

function A:IsOnQuest(questID)
  if not self.valid then return false end
  return C_QuestLog.IsOnQuest(questID) and true or false
end


-- Current Octo/ClassicAPI exposes AreaTable.dbc and WorldMapArea.dbc directly.
-- Use these live client tables for map identity instead of assuming English
-- packaged zone names are unique/current. This is especially important for
-- custom instances where several AreaTable rows can share one display name.
function A:GetClientAreas()
  if self.clientAreasLoaded then
    return self.clientAreas or nil
  end
  self.clientAreasLoaded=true
  if not C_Map or type(C_Map.GetAreas)~="function" then return nil end
  local ok,areas=pcall(C_Map.GetAreas)
  if ok and type(areas)=="table" then self.clientAreas=areas end
  return self.clientAreas or nil
end

function A:GetMapAreaIDs()
  if self.mapAreaIDsLoaded then
    return self.mapAreaIDs or nil
  end
  self.mapAreaIDsLoaded=true
  if not C_Map or type(C_Map.GetMapAreaIDs)~="function" then return nil end
  local ok,ids=pcall(C_Map.GetMapAreaIDs)
  if ok and type(ids)=="table" then self.mapAreaIDs=ids end
  return self.mapAreaIDs or nil
end

function A:GetMapAreaIDForTexture(textureName)
  if not textureName or textureName=="" then return nil end
  local ids=self:GetMapAreaIDs()
  return ids and tonumber(ids[textureName]) or nil
end

-- Resolve a localized World Map zone label through WorldMapArea.dbc rather
-- than through every AreaTable row. Some dungeon names legitimately exist in
-- AreaTable more than once (for example Razorfen Kraul is both the instance
-- area 491 and an outdoor Barrens sub-area 1717), so a generic name lookup
-- must remain ambiguous. The World Map art table is narrower: when exactly one
-- map-backed AreaTable ID owns that localized name it is safe to select it.
-- Build this tiny reverse index lazily from ClassicAPI's already-cached live
-- client tables; no packaged English names or hardcoded dungeon IDs are used.
function A:GetWorldMapAreaIDByName(name)
  if type(name)~="string" or name=="" then return nil end

  if not self.worldMapAreaNameIndexLoaded then
    self.worldMapAreaNameIndexLoaded=true
    local index={}
    local areas=self:GetClientAreas() or {}
    local mapAreaIDs=self:GetMapAreaIDs() or {}

    for _,rawAreaID in pairs(mapAreaIDs) do
      local areaID=tonumber(rawAreaID)
      local areaName=areaID and areas[areaID] or nil
      if type(areaName)=="string" and areaName~="" then
        local previous=index[areaName]
        if previous==nil then
          index[areaName]=areaID
        elseif previous~=areaID then
          index[areaName]=false
        end
      end
    end

    self.worldMapAreaNameIndex=index
  end

  local areaID=self.worldMapAreaNameIndex and self.worldMapAreaNameIndex[name] or nil
  if type(areaID)=="number" then return areaID end
  return nil
end

function A:GetDisplayedMapTextureName()
  if type(GetMapInfo)~="function" then return nil end
  local ok,textureName=pcall(GetMapInfo)
  if not ok or type(textureName)~="string" or textureName=="" then return nil end
  return textureName
end

function A:GetDisplayedMapAreaID()
  return self:GetMapAreaIDForTexture(self:GetDisplayedMapTextureName())
end

function A:GetBestMapForPlayer()
  if not self.valid then return nil end
  return C_Map.GetBestMapForUnit("player")
end

-- ClassicAPI backports the modern GetInstanceInfo() tuple to Vanilla 1.12.
-- Keep instance classification behind the API contract instead of teaching
-- presentation modules about DLL/global availability details.
function A:GetInstanceType()
  if type(GetInstanceInfo)~="function" then return "none" end
  local ok,name,instanceType=pcall(GetInstanceInfo)
  if not ok or type(instanceType)~="string" then return "none" end
  return instanceType
end

function A:GetInstanceMapID()
  if type(GetInstanceInfo)~="function" then return nil end
  local ok,name,instanceType,difficultyID,difficultyName,maxPlayers,dynamicDifficulty,isDynamic,instanceMapID=pcall(GetInstanceInfo)
  if not ok then return nil end
  return tonumber(instanceMapID)
end

function A:IsInDungeonOrRaid()
  local instanceType=self:GetInstanceType()
  return instanceType=="party" or instanceType=="raid"
end

-- pfQuest-classicAPI resolves quest-bound exploration objectives directly from
-- ClassicAPI's AreaTrigger.dbc bridge. Keep this behind the API contract so
-- generic map code never needs to know whether the DLL/global exists.
function A:GetAreaTriggerInfo(areaTriggerID)
  areaTriggerID=tonumber(areaTriggerID)
  if not areaTriggerID or not C_Map or type(C_Map.GetAreaTriggerInfo)~="function" then return nil end

  local ok,info=pcall(C_Map.GetAreaTriggerInfo,areaTriggerID)
  if not ok or type(info)~="table" then return nil end

  local mapID=tonumber(info.areaID)
  local x=tonumber(info.mapX)
  local y=tonumber(info.mapY)
  if not mapID or not x or not y then return nil end

  return {
    id=areaTriggerID,
    areaID=mapID,
    mapX=x,
    mapY=y
  }
end


function A:GetQuestLogLeaderBoardID(objectiveIndex,questLogIndex)
  if type(GetQuestLogLeaderBoardID)~="function" then return nil end
  local ok,id=pcall(GetQuestLogLeaderBoardID,objectiveIndex,questLogIndex)
  if not ok then return nil end
  return tonumber(id)
end

function A:GetQuestObjectives(questID,questLogIndex)
  if C_QuestLog and type(C_QuestLog.GetQuestObjectives)=="function" then
    -- Questie 3.3.5's Vanilla compatibility implementation accepts the log
    -- index as a second argument; modern-style implementations ignore extras.
    return C_QuestLog.GetQuestObjectives(questID,questLogIndex)
  end
  return nil
end


function A:QueryQuestsCompleted()
  if type(QueryQuestsCompleted)~="function" then return false end
  local ok=pcall(QueryQuestsCompleted)
  return ok and true or false
end

function A:GetQuestsCompleted()
  if type(GetQuestsCompleted)=="function" then
    local ok,result=pcall(GetQuestsCompleted)
    if ok and type(result)=="table" then return result end

    -- Some compatibility layers use the older "fill table" form.
    local target={}
    ok=pcall(GetQuestsCompleted,target)
    if ok and next(target) then return target end
  end

  if C_QuestLog and type(C_QuestLog.GetQuestsCompleted)=="function" then
    local ok,result=pcall(C_QuestLog.GetQuestsCompleted)
    if ok and type(result)=="table" then return result end
  end

  return nil
end

function A:IsQuestFlaggedCompleted(questID)
  if type(IsQuestFlaggedCompleted)=="function" then
    local ok,result=pcall(IsQuestFlaggedCompleted,questID)
    if ok then return result and true or false end
  end

  if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted)=="function" then
    local ok,result=pcall(C_QuestLog.IsQuestFlaggedCompleted,questID)
    if ok then return result and true or false end
  end

  return nil
end
