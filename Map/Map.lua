QuestieOcto.Map = QuestieOcto.Map or {}
local M = QuestieOcto.Map

local function DisplaySettings()
  return QuestieOcto.MinimapSettings
end

local function IsPermanentRole(role)
  return role=="flightMaster" or role=="auctioneer" or role=="banker"
      or role=="mailbox" or role=="battlemaster" or role=="innkeeper"
      or role=="meetingStone" or role=="repair" or role=="spiritHealer"
      or role=="stableMaster" or role=="vendor" or role=="rareMob"
end

local function IsSpecialQuestNode(node)
  return node and (node.pvp or node.repeatable or node.event) and true or false
end

local function IsQuestMarkerNodeEnabled(node)
  local settings=DisplaySettings()
  -- Available/Completed are the broad continent quest-state gates. Special
  -- Quests remains an additional category gate, so disabling Available really
  -- removes every pickup `!` (including special ones) while leaving turn-ins.
  if node and node.role == "turnin" then
    if not settings:Get("showCompletedQuestsWorldMap") then return false end
    if settings:Get("showTurninsCurrentZoneMap") and not M.displayingPlayerZone then
      return false
    end
  else
    if not settings:Get("showAvailableQuestsWorldMap") then return false end
    if settings:Get("showAvailableQuestMapCurrentZone") and not M.displayingPlayerZone then
      return false
    end
  end
  if IsSpecialQuestNode(node) then
    return settings:Get("showSpecialQuestsWorldMap") and true or false
  end
  return true
end

local function IsDisplayedMapPlayerCurrentZone(mapID)
  mapID = tonumber(mapID)
  if not mapID or not QuestieOcto.API or not QuestieOcto.API.GetBestMapForPlayer then
    return false
  end

  local playerMapID = QuestieOcto.API:GetBestMapForPlayer()
  if not playerMapID and QuestieOcto.Minimap then
    playerMapID = QuestieOcto.Minimap.physicalMapID
  end

  return tonumber(playerMapID) == mapID
end

local function IsPvPQuestNodeEnabled(node)
  if node and node.pvp then
    return DisplaySettings():Get("showPvPRelatedQuests") and true or false
  end
  return true
end

local function IsRoleEnabled(role)
  local settings=DisplaySettings()
  if role=="auctioneer" then return settings:Get("showMapAuctioneer") and true or false end
  if role=="banker" then return settings:Get("showMapBanker") and true or false end
  if role=="flightMaster" then return settings:Get("showMapFlightMaster") and true or false end
  if role=="mailbox" then return settings:Get("showMapMailbox") and true or false end
  if role=="battlemaster" then return settings:Get("showMapBattlemaster") and true or false end
  if role=="innkeeper" then return settings:Get("showMapInnkeeper") and true or false end
  if role=="meetingStone" then return settings:Get("showMapMeetingStone") and true or false end
  if role=="repair" then return settings:Get("showMapRepair") and true or false end
  if role=="spiritHealer" then return settings:Get("showMapSpiritHealer") and true or false end
  if role=="stableMaster" then return settings:Get("showMapStableMaster") and true or false end
  if role=="vendor" then return settings:Get("showMapVendor") and true or false end
  if role=="rareMob" then return settings:Get("showMapRareMonsters") and true or false end
  if not settings:Get("enableMapIcons") then return false end

  if role=="itemStart" then
    return settings:Get("enableAvailable")
       and settings:Get("showItemStartQuests")
       and settings:Get("showItemStartMap")
       and true or false
  elseif role=="available" then
    return settings:Get("enableAvailable") and true or false
  elseif role=="turnin" then
    return settings:Get("enableTurnins") and true or false
  else
    return settings:Get("enableObjectives") and true or false
  end
end


M.enabled=true
M.mapID=nil
M.generation=0
M.displayingPlayerZone = false
M.syncing=false
M.resync=false
M.prune=false
M.frames={}
M.activeFrames={}
M.buildActiveFrames=nil
M.renderedPreparedPlan=nil
M.syncPreparedPlan=nil
M.renderedNodeRevision=0
M.syncNodeRevision=nil
M.stats={active=0,created=0,reused=0,hidden=0,exact=0,objectiveAreas=0,itemStartAreas=0,syncs=0,visibleAvailable=0,visibleItemStart=0,visibleObjective=0,visibleTurnin=0,inputNodes=0,multiEntryPins=0,itemStartRawNodes=0,itemStartAreaPins=0,preparedHits=0,preparedMisses=0,preparedDescriptors=0,mapPriorityRequests=0}

local ICON_ROOT="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\"
local TEX_AVAILABLE=ICON_ROOT.."available"
local TEX_AVAILABLE_GRAY=ICON_ROOT.."available_gray"
local TEX_MOBDROP=ICON_ROOT.."available_mobdrop"
local TEX_OBJECTSTART=ICON_ROOT.."available_object"
local TEX_COMPLETE=ICON_ROOT.."complete"
local TEX_EVENT_AVAILABLE=ICON_ROOT.."eventquest"
local TEX_EVENT_COMPLETE=ICON_ROOT.."eventquest_complete"
local TEX_REPEATABLE_AVAILABLE=ICON_ROOT.."repeatable"
local TEX_PVP_AVAILABLE=ICON_ROOT.."pvp_available"
local TEX_PVP_COMPLETE=ICON_ROOT.."pvp_complete"
local TEX_INCOMPLETE=ICON_ROOT.."incomplete"
local TEX_SLAY=ICON_ROOT.."slay"
local TEX_LOOT=ICON_ROOT.."loot"
local TEX_OBJECT=ICON_ROOT.."object"
local TEX_EVENT=ICON_ROOT.."event"
local TEX_INTERACT=ICON_ROOT.."interact"
local TEX_FLIGHT=ICON_ROOT.."flight"
local TEX_AUCTIONEER=ICON_ROOT.."auctioneer"
local TEX_BANKER=ICON_ROOT.."banker"
local TEX_MAILBOX=ICON_ROOT.."mailbox"
local TEX_BATTLEMASTER=ICON_ROOT.."battlemaster"
local TEX_INNKEEPER=ICON_ROOT.."innkeeper"
local TEX_MEETINGSTONE=ICON_ROOT.."meetingstone"
local TEX_REPAIR=ICON_ROOT.."repair"
local TEX_SPIRITHEALER=ICON_ROOT.."spirithealer"
local TEX_STABLEMASTER=ICON_ROOT.."stablemaster"
local TEX_VENDOR=ICON_ROOT.."vendor"
local TEX_RARE=ICON_ROOT.."rares"

-- Turtle deliberately keeps full quest XP through 25 levels above the quest
-- (Tortoise src/game/QuestDef.cpp). The server file is XP logic rather than a
-- client icon-color function, but it matches the observed Turtle native quest
-- presentation and is the project's accepted low-level gray-marker boundary.
-- Exactly +25 stays normal; +26 and beyond becomes gray.
local TURTLE_GRAY_QUEST_DELTA=25

local function IsGrayAvailableQuest(node)
  if not node or (node.role~="available" and node.role~="itemStart") then return false end
  local questID=tonumber(node.questID)
  if not questID then return false end

  local q=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
  if not q or q.presentationAlwaysNormal then return false end

  local questLevel=tonumber(q.level)
  local playerLevel=UnitLevel and tonumber(UnitLevel("player")) or nil
  if not questLevel or questLevel<=0 or not playerLevel or playerLevel<=0 then return false end

  return playerLevel>questLevel+TURTLE_GRAY_QUEST_DELTA
end

local function TextureForNode(node)
  if node.role=="flightMaster" then return TEX_FLIGHT end
  if node.role=="auctioneer" then return TEX_AUCTIONEER end
  if node.role=="banker" then return TEX_BANKER end
  if node.role=="mailbox" then return TEX_MAILBOX end
  if node.role=="battlemaster" then return TEX_BATTLEMASTER end
  if node.role=="innkeeper" then return TEX_INNKEEPER end
  if node.role=="meetingStone" then return TEX_MEETINGSTONE end
  if node.role=="repair" then return TEX_REPAIR end
  if node.role=="spiritHealer" then return TEX_SPIRITHEALER end
  if node.role=="stableMaster" then return TEX_STABLEMASTER end
  if node.role=="vendor" then return TEX_VENDOR end
  if node.role=="rareMob" then return TEX_RARE end
  if node.role=="itemStart" then
    -- Presentation priority: PvP > Repeatable > Event > Turtle low-level gray > Normal.
    if node.pvp then return TEX_PVP_AVAILABLE end
    if node.repeatable then return TEX_REPEATABLE_AVAILABLE end
    if node.event then return TEX_EVENT_AVAILABLE end
    if IsGrayAvailableQuest(node) then return TEX_AVAILABLE_GRAY end
    return TEX_AVAILABLE
  end
  if node.role=="available" then
    if node.pvp then return TEX_PVP_AVAILABLE end
    if node.repeatable then return TEX_REPEATABLE_AVAILABLE end
    if node.event then return TEX_EVENT_AVAILABLE end
    if IsGrayAvailableQuest(node) then return TEX_AVAILABLE_GRAY end
    return TEX_AVAILABLE
  end
  if node.role=="turnin" then
    if node.pvp then return TEX_PVP_COMPLETE end
    -- Questie 6 uses its ordinary completion question mark for repeatable
    -- turn-ins. Repeatability therefore wins over event presentation here too.
    if node.repeatable then return TEX_COMPLETE end
    if node.event then return TEX_EVENT_COMPLETE end
    return TEX_COMPLETE
  end
  if node.role=="objectiveItemSource" then
    if node.sourceKind=="gameObject" then return TEX_OBJECT end
    return TEX_LOOT
  end
  if node.role=="objectiveObject" then return TEX_OBJECT end
  if node.role=="objectiveCreature" then return TEX_SLAY end
  if node.role=="objectiveArea" then return TEX_EVENT end
  return TEX_INCOMPLETE
end
local function RolePriority(role)
  if IsPermanentRole(role) then return role=="rareMob" and 6 or 5 end
  -- A quest that can be picked up should be visually dominant when the
  -- exact same source/area also participates in active objective/loot data.
  if role=="turnin" then return 50 end
  if role=="available" or role=="itemStart" then return 40 end
  -- At a shared Full Nodes coordinate, a direct objective should own the
  -- displayed quest color over an indirect item-drop source. The merged pin
  -- still retains every quest/objective entry for its tooltip.
  if role=="objectiveObject" or role=="objectiveCreature" or role=="objectiveArea" then return 20 end
  if role=="objectiveItemSource" then return 15 end
  return 10
end

local function VariantPriority(node)
  if node and node.pvp then return 3 end
  if node and node.repeatable then return 2 end
  if node and node.event then return 1 end
  return 0
end

local function VisualPriority(node)
  return RolePriority(node.role)*10+VariantPriority(node)
end

local function ScaleKeyForRole(role)
  return nil
end

local function DrawSublevelForRole(role)
  if IsPermanentRole(role) then return role=="rareMob" and 2 or 1 end
  -- Questie 5.2.3/6.0.0/3.3.5 map utils:
  -- available = OVERLAY 5, complete = OVERLAY 6, objectives = OVERLAY 0.
  if role=="turnin" then return 6 end
  if role=="available" or role=="itemStart" then return 5 end
  return 0
end

local function ApplyVisualRole(pin,node)
  local priority=VisualPriority(node)
  if not pin.visualPriority or priority>pin.visualPriority then
    pin.visualPriority=priority
    pin.role=node.role
    pin.questID=node.questID
    pin.event=node.event
    pin.pvp=node.pvp and true or false
    pin.repeatable=node.repeatable and true or false
    pin.sourceKind=node.sourceKind
    pin.sourceID=node.sourceID
    pin.displayName=node.sourceName or pin.displayName or "Quest source"
    pin.iconScaleKey=node.iconScaleKey or ScaleKeyForRole(node.role)
    pin.texture:SetTexture(TextureForNode(node))
    pin.texture:SetDrawLayer("OVERLAY",DrawSublevelForRole(node.role))
    -- Miscellaneous/rare markers stay below quest pins so an overlapping
    -- quest objective, starter or turn-in remains visible and clickable.
    if pin.SetFrameLevel and WorldMapButton then
      if IsPermanentRole(node.role) then
        pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+7)
      else
        pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)
      end
    end
    if QuestieOcto.Visuals then QuestieOcto.Visuals:ApplyPin(pin,node,false,1) end
  end
end


function M:GetTextureForNode(node)
  return TextureForNode(node)
end

function M:IsGrayAvailableQuest(node)
  return IsGrayAvailableQuest(node)
end

function M:GetRolePriority(role)
  return RolePriority(role)
end

function M:GetVisualPriority(node)
  return VisualPriority(node)
end

function M:GetDrawSublevelForRole(role)
  return DrawSublevelForRole(role)
end

function M:GetScaleKeyForRole(role)
  return ScaleKeyForRole(role)
end

function M:GetIconTypeScale(node)
  return 1
end

function M:GetPinScale(pin)
  -- Keep every townsfolk/service marker on the same compact footprint.
  -- Rare Monsters intentionally stay on their dedicated 12px footprint below.
  -- The player-facing global map/minimap scale remains unchanged.
  if pin and (pin.role=="auctioneer" or pin.role=="banker" or pin.role=="flightMaster" or
              pin.role=="mailbox" or pin.role=="battlemaster" or pin.role=="innkeeper" or
              pin.role=="meetingStone" or pin.role=="repair" or pin.role=="spiritHealer" or
              pin.role=="stableMaster" or pin.role=="vendor") then
    return 0.9
  end
  return 1
end

function M:ResizePin(pin)
  if not pin then return end
  local globalScale=tonumber(DisplaySettings():Get("globalScale")) or 1
  local typeScale=self:GetPinScale(pin)
  -- pfQuest renders tracking/rares.tga inside a 14px node with a 1px inset,
  -- leaving a 12px visible star.  Our texture fills the pin, so use 12px
  -- for the miscellaneous rare marker to match that less-intrusive footprint.
  local baseSize=pin.fullNode and 14 or ((pin.role=="rareMob") and 12 or 16)
  local size=baseSize*globalScale*typeScale
  pin:SetWidth(size)
  pin:SetHeight(size)
  if QuestieOcto.Visuals then QuestieOcto.Visuals:ResizeGlow(pin) end
  pin.questieOctoScaleSize=size
  self.stats.scaleResizes=(self.stats.scaleResizes or 0)+1
  self.stats.lastScaleSize=size
end


local function IsExactRole(role)
  return role=="available" or role=="turnin" or IsPermanentRole(role)
end

local function EntryKey(node)
  return tostring(node.questID)..":"..tostring(node.role)..":"..
    tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..tostring(node.itemID or 0)
end

local function AddEntry(pin,node)
  pin.entries=pin.entries or {}
  local key=EntryKey(node)
  if not pin.entries[key] then
    pin.entries[key]={node=node}
  end
  ApplyVisualRole(pin,node)
end

local function UpdatePosition(pin,x,y,offsetX,offsetY)
  offsetX=offsetX or 0
  offsetY=offsetY or 0

  if pin.x==x and pin.y==y and pin.offsetX==offsetX and pin.offsetY==offsetY then
    return
  end

  pin.x=x
  pin.y=y
  pin.offsetX=offsetX
  pin.offsetY=offsetY

  pin:ClearAllPoints()
  pin:SetPoint(
    "CENTER",WorldMapButton,"TOPLEFT",
    WorldMapButton:GetWidth()*(x/100)+offsetX,
    -WorldMapButton:GetHeight()*(y/100)+offsetY
  )
end

local function DisplayedMapID()
  local cid=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  local zid=GetCurrentMapZone and GetCurrentMapZone() or 0

  -- ClassicAPI exposes WorldMapArea.dbc as texture-dir -> AreaTable ID. This is
  -- the authoritative way to distinguish custom instances/wings that share the
  -- same localized display name, and it also covers instance/city maps that
  -- GetMapZones() does not enumerate.
  local textureMapID=QuestieOcto.API and QuestieOcto.API.GetDisplayedMapAreaID
    and QuestieOcto.API:GetDisplayedMapAreaID() or nil

  -- A continent overview also has a map texture. Do not mistake that texture
  -- for a selected zone; preserve the dedicated continent projection path.
  if cid and cid>0 and (not zid or zid<=0) then
    local continentMapID=QuestieOcto.ContinentProjection
      and QuestieOcto.ContinentProjection:GetClientContinentMapID(cid) or nil
    if textureMapID and continentMapID~=nil and tonumber(textureMapID)~=tonumber(continentMapID) then
      return tonumber(textureMapID)
    end
    return nil
  end

  if textureMapID then return tonumber(textureMapID) end

  -- Vanilla selected-zone fallback: localized zone name -> canonical DB map ID.
  if not cid or cid<=0 or not zid or zid<=0 or not GetMapZones then return nil end
  local zones={GetMapZones(cid)}
  local name=zones[zid]
  if not name then return nil end
  if QuestieOcto.DatabaseAPI.GetMapIDByName then
    return QuestieOcto.DatabaseAPI:GetMapIDByName(name)
  end
  return nil
end

local function DisplayedContinentMapID()
  local cid=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  local zid=GetCurrentMapZone and GetCurrentMapZone() or 0
  if not cid or cid<=0 or (zid and zid>0) then return nil end
  if not QuestieOcto.ContinentProjection then return nil end
  return QuestieOcto.ContinentProjection:GetClientContinentMapID(cid)
end

local function DisplayedContextKey()
  local mapID=DisplayedMapID()
  if mapID then return tonumber(mapID) end
  local continentMapID=DisplayedContinentMapID()
  if continentMapID~=nil then return -1000-tonumber(continentMapID) end
  return nil
end

local function DisplayedSpecialMapContext(mapID)
  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(mapID) then
    return karazhan:GetDisplayedContext(mapID)
  end
  return nil
end

local function NodeAllowedOnDisplayedMap(node)
  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(M.mapID) then
    return karazhan:NodeAllowed(node,M.specialMapContext)
  end
  return true
end

local function ItemAreaAllowedOnDisplayedMap(area)
  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(M.mapID) then
    return karazhan:ItemAreaAllowed(area,M.specialMapContext)
  end
  return true
end

local function OpenContinentZoneForPin(pin)
  if not pin or not pin.continentZoneMapID or not SetMapZoom or not GetMapZones then return false end
  local continent=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  if not continent or continent<=0 then return false end

  local target=tonumber(pin.continentZoneMapID)
  if not target then return false end
  local zones={GetMapZones(continent)}
  local index,name
  for index,name in ipairs(zones) do
    if QuestieOcto.DatabaseAPI:GetMapIDByName(name)==target then
      if QuestieOcto.Tooltips then QuestieOcto.Tooltips:Hide(pin) end
      SetMapZoom(continent,index)
      return true
    end
  end
  return false
end

-- Tracker "Show on Map" support, adapted from Questie 5/6's tracker intent
-- to the native Vanilla/Turtle World Map API. Modern Questie can call
-- WorldMapFrame:SetMapID(); Interface 11200 instead selects ordinary zones
-- through SetMapZoom(continent, zoneIndex), while the player's current
-- custom/instance map is reached through SetMapToCurrentZone().
local function TrackerObjectiveRole(role)
  return role=="objectiveCreature" or role=="objectiveObject"
      or role=="objectiveItemSource" or role=="objectiveArea"
end

local function AddTrackerTargetCoords(targets,seen,coords,sourceKind,sourceID)
  for _,coord in pairs(coords or {}) do
    if type(coord)=="table" then
      local x=tonumber(coord[1])
      local y=tonumber(coord[2])
      local mapID=tonumber(coord[3])
      if x and y and mapID then
        local karazhanContext=nil
        local karazhan=QuestieOcto.KarazhanContext
        if karazhan and karazhan:IsSharedArea(mapID) then
          karazhanContext=karazhan:GetSourceContext(sourceKind,sourceID)
        end
        local key=tostring(mapID)..":"..tostring(karazhanContext or "")..":"..
          string.format("%.3f",x)..":"..string.format("%.3f",y)
        if not seen[key] then
          seen[key]=true
          table.insert(targets,{
            x=x,y=y,mapID=mapID,karazhanContext=karazhanContext,
            sourceKind=sourceKind,sourceID=tonumber(sourceID) or sourceID
          })
        end
      end
    end
  end
end

local function AddTrackerAreaTarget(targets,seen,src)
  if not src then return end
  local x=tonumber(src.x)
  local y=tonumber(src.y)
  local mapID=tonumber(src.mapID)
  if not x or not y or not mapID then return end
  AddTrackerTargetCoords(targets,seen,{{x,y,mapID}},"areaTrigger",src.id)
end

local function UnfinishedObjectiveCount(questID)
  local state=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active
    and QuestieOcto.QuestLog.active[tonumber(questID)] or nil
  if not state then return 0 end
  local count=0
  for _,objective in pairs(state.objectives or {}) do
    if not objective.complete then count=count+1 end
  end
  return count
end

local function CollectTrackerObjectiveTargets(questID,objectiveIndex)
  questID=tonumber(questID)
  objectiveIndex=tonumber(objectiveIndex)
  if not questID or not objectiveIndex then return {} end

  local targets={}
  local seen={}
  -- First use the canonical active node set. This preserves presentation-only
  -- source corrections and scripted encounter coordinates exactly as the map
  -- itself renders them.
  for _,node in pairs((QuestieOcto.Nodes and QuestieOcto.Nodes.nodes) or {}) do
    if tonumber(node.questID)==questID and TrackerObjectiveRole(node.role)
       and tonumber(node.objectiveIndex)==objectiveIndex then
      AddTrackerTargetCoords(targets,seen,node.coords,node.sourceKind,node.sourceID)
    end
  end

  -- The objective resolver is the fallback when the tracker becomes clickable
  -- before the asynchronous Nodes rebuild has finished. It also keeps this
  -- interaction independent from map render timing.
  local resolved=QuestieOcto.Objectives and QuestieOcto.Objectives.byQuest
    and QuestieOcto.Objectives.byQuest[questID] or nil
  local db=QuestieOcto.DatabaseAPI
  if resolved and db then
    for _,src in pairs(resolved.creature or {}) do
      if tonumber(src.objectiveIndex)==objectiveIndex then
        AddTrackerTargetCoords(targets,seen,db:GetCreatureCoords(src.id),"creature",src.id)
        end
    end
    for _,src in pairs(resolved.gameObject or {}) do
      if tonumber(src.objectiveIndex)==objectiveIndex then
        AddTrackerTargetCoords(targets,seen,db:GetObjectCoords(src.id),"gameObject",src.id)
        end
    end
    for _,item in pairs(resolved.item or {}) do
      if tonumber(item.objectiveIndex)==objectiveIndex then
        for _,src in pairs(item.sources or {}) do
          if src.kind=="creature" then
            AddTrackerTargetCoords(targets,seen,db:GetCreatureCoords(src.id),"creature",src.id)
          else
            AddTrackerTargetCoords(targets,seen,db:GetObjectCoords(src.id),"gameObject",src.id)
          end
        end
        end
    end
    for _,src in pairs(resolved.areaTrigger or {}) do
      if tonumber(src.objectiveIndex)==objectiveIndex then
        AddTrackerAreaTarget(targets,seen,src)
        end
    end
  end

  -- Vanilla does not expose a reliable leaderboard index for quest-bound area
  -- triggers. When a quest has exactly one unfinished objective, an unindexed
  -- objective-area node is unambiguous and can safely serve that objective's
  -- Show on Map action without changing canonical objective truth.
  if table.getn(targets)==0 and UnfinishedObjectiveCount(questID)==1 then
    for _,node in pairs((QuestieOcto.Nodes and QuestieOcto.Nodes.nodes) or {}) do
      if tonumber(node.questID)==questID and TrackerObjectiveRole(node.role)
         and not tonumber(node.objectiveIndex) then
        AddTrackerTargetCoords(targets,seen,node.coords,node.sourceKind,node.sourceID)
      end
    end
    if resolved then
      for _,src in pairs(resolved.areaTrigger or {}) do
        if not tonumber(src.objectiveIndex) then AddTrackerAreaTarget(targets,seen,src) end
      end
    end
  end

  return targets
end

local function CollectTrackerFinisherTargets(questID)
  questID=tonumber(questID)
  if not questID then return {} end

  local targets={}
  local seen={}
  for _,node in pairs((QuestieOcto.Nodes and QuestieOcto.Nodes.nodes) or {}) do
    if tonumber(node.questID)==questID and node.role=="turnin" then
      AddTrackerTargetCoords(targets,seen,node.coords,node.sourceKind,node.sourceID)
    end
  end

  -- Fallback for the short window before the node rebuild publishes the
  -- completed quest's turn-in markers.
  local q=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
  local db=QuestieOcto.DatabaseAPI
  if q and db then
    for _,id in pairs(q.finishes.creature or {}) do
      AddTrackerTargetCoords(targets,seen,db:GetCreatureCoords(id),"creature",id)
    end
    for _,id in pairs(q.finishes.gameObject or {}) do
      AddTrackerTargetCoords(targets,seen,db:GetObjectCoords(id),"gameObject",id)
    end
  end
  return targets
end

local function ClientAreaName(mapID)
  local areas=QuestieOcto.API and QuestieOcto.API.GetClientAreas
    and QuestieOcto.API:GetClientAreas() or nil
  return areas and areas[tonumber(mapID)] or nil
end

local function FindSelectableWorldMapZone(mapID)
  mapID=tonumber(mapID)
  if not mapID or not GetMapZones or not SetMapZoom then return nil,nil end

  local targetName=ClientAreaName(mapID)
  local fallbackContinent=nil
  local fallbackZone=nil
  local fallbackCount=0
  local continents={}
  if GetMapContinents then continents={GetMapContinents()} end
  local count=table.getn(continents)
  if count<1 then count=2 end

  for continent=1,count do
    local zones={GetMapZones(continent)}
    for zoneIndex,zoneName in ipairs(zones) do
      local resolved=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetMapIDByName
        and QuestieOcto.DatabaseAPI:GetMapIDByName(zoneName) or nil
      if tonumber(resolved)==mapID then return continent,zoneIndex end

      -- Current client area names are localized and can recover a selectable
      -- dropdown zone even when the packaged reverse lookup marked that name
      -- ambiguous. Only use this fallback when it identifies one zone entry.
      if targetName and zoneName==targetName then
        fallbackContinent=continent
        fallbackZone=zoneIndex
        fallbackCount=fallbackCount+1
      end
    end
  end

  if fallbackCount==1 then return fallbackContinent,fallbackZone end
  return nil,nil
end

local function TrackerTargetMatches(target,mapID,specialContext)
  if not target or tonumber(target.mapID)~=tonumber(mapID) then return false end
  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(mapID) then
    return specialContext~=nil and target.karazhanContext==specialContext
  end
  return true
end

local function TrackerTargetCount(targets,mapID,specialContext)
  local count=0
  for _,target in pairs(targets or {}) do
    if TrackerTargetMatches(target,mapID,specialContext) then count=count+1 end
  end
  return count
end

local function TrackerTargetMapCounts(targets)
  local counts={}
  local karazhan=QuestieOcto.KarazhanContext
  for _,target in pairs(targets or {}) do
    local mapID=tonumber(target.mapID)
    if mapID and (not karazhan or not karazhan:IsSharedArea(mapID)) then
      counts[mapID]=(counts[mapID] or 0)+1
    end
  end
  return counts
end

local function VisibleTrackerMapContext()
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return nil,nil end
  local mapID=tonumber(DisplayedMapID())
  return mapID,DisplayedSpecialMapContext(mapID)
end

-- Vanilla has no arbitrary "set World Map to area ID" API. Dungeon/city maps
-- that are not enumerated by GetMapZones() are selectable only when they are
-- already displayed or when SetMapToCurrentZone() can select the player's
-- physical instance. Resolve that hidden current-instance texture here without
-- touching a World Map the player is actively browsing.
local function HiddenCurrentInstanceMapContext()
  if not WorldMapFrame or WorldMapFrame:IsVisible() then return nil,nil end
  if not QuestieOcto.API or not QuestieOcto.API.IsInDungeonOrRaid
     or not QuestieOcto.API:IsInDungeonOrRaid() then return nil,nil end
  if not SetMapToCurrentZone then return nil,nil end
  SetMapToCurrentZone()
  local mapID=tonumber(DisplayedMapID())
  return mapID,DisplayedSpecialMapContext(mapID)
end

local function PhysicalTrackerMapContext()
  local mapID=QuestieOcto.API and QuestieOcto.API.GetBestMapForPlayer
    and tonumber(QuestieOcto.API:GetBestMapForPlayer()) or nil
  if not mapID then return nil,nil end

  local specialContext=nil
  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(mapID) then
    specialContext=karazhan:GetPhysicalContext(mapID)
  end
  return mapID,specialContext
end

local function IsTrackerMapSelectable(mapID,specialContext)
  mapID=tonumber(mapID)
  if not mapID then return false end

  local displayed,displayedContext=VisibleTrackerMapContext()
  if displayed and displayed==mapID then
    local karazhan=QuestieOcto.KarazhanContext
    if not karazhan or not karazhan:IsSharedArea(mapID) then return true end
    if specialContext and displayedContext==specialContext then return true end
  end

  local physical,physicalContext=PhysicalTrackerMapContext()
  if physical and physical==mapID then
    local karazhan=QuestieOcto.KarazhanContext
    if not karazhan or not karazhan:IsSharedArea(mapID) then return true end
    if specialContext and physicalContext==specialContext then return true end
  end

  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(mapID) then
    -- Interface 11200 cannot select Lower vs Upper Karazhan by AreaTable ID.
    -- Only an already displayed or physically current context is safe.
    return false
  end

  local continent,zoneIndex=FindSelectableWorldMapZone(mapID)
  return continent and zoneIndex and true or false
end

local function ChooseTrackerTargetMap(targets,zoneGroup)
  local karazhan=QuestieOcto.KarazhanContext

  -- Respect a dungeon/detail map already being shown, including maps opened by
  -- another addon. For AreaTable 3457, texture context must also match so a
  -- Lower target can never be accepted merely because Upper is visible.
  local displayed,displayedContext=VisibleTrackerMapContext()
  if displayed and TrackerTargetCount(targets,displayed,displayedContext)>0 then
    return displayed,displayedContext
  end

  local physical,physicalContext=PhysicalTrackerMapContext()
  if physical and TrackerTargetCount(targets,physical,physicalContext)>0 then
    return physical,physicalContext
  end

  -- Some instance contexts resolve more precisely through GetMapInfo() after
  -- SetMapToCurrentZone() than through GetBestMapForUnit(). This keeps tracker
  -- Show on Map usable for the player's current dungeon without inventing an
  -- outdoor entrance projection.
  local currentInstance,currentInstanceContext=HiddenCurrentInstanceMapContext()
  if currentInstance and TrackerTargetCount(targets,currentInstance,currentInstanceContext)>0 then
    return currentInstance,currentInstanceContext
  end

  local counts=TrackerTargetMapCounts(targets)
  local zoneMapID=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetMapIDByName
    and QuestieOcto.DatabaseAPI:GetMapIDByName(zoneGroup) or nil
  zoneMapID=tonumber(zoneMapID)
  if zoneMapID and counts[zoneMapID] and IsTrackerMapSelectable(zoneMapID,nil) then
    return zoneMapID,nil
  end

  local best=nil
  local bestCount=-1
  for mapID,count in pairs(counts) do
    if IsTrackerMapSelectable(mapID,nil) then
      if count>bestCount or (count==bestCount and (not best or mapID<best)) then
        best=mapID
        bestCount=count
      end
    end
  end
  return best,nil
end

local function OpenTrackerTargetMap(mapID,specialContext)
  mapID=tonumber(mapID)
  if not mapID or not WorldMapFrame then return false end

  -- If another addon/native action already has the dungeon/detail map open, do
  -- not retarget it through a zone-name fallback. Karazhan's shared numeric ID
  -- additionally requires the exact Lower/Upper texture context.
  local displayed,displayedContext=VisibleTrackerMapContext()
  if displayed and displayed==mapID then
    local karazhan=QuestieOcto.KarazhanContext
    if not karazhan or not karazhan:IsSharedArea(mapID)
       or (specialContext and displayedContext==specialContext) then
      if M.RequestSync then M:RequestSync(true) end
      return true
    end
  end

  local physical,physicalContext=PhysicalTrackerMapContext()
  local currentInstance,currentInstanceContext=HiddenCurrentInstanceMapContext()
  local currentPhysical=false
  if physical and physical==mapID then
    local karazhan=QuestieOcto.KarazhanContext
    currentPhysical=(not karazhan or not karazhan:IsSharedArea(mapID))
      or (specialContext and physicalContext==specialContext)
  end
  if not currentPhysical and currentInstance and currentInstance==mapID then
    local karazhan=QuestieOcto.KarazhanContext
    currentPhysical=(not karazhan or not karazhan:IsSharedArea(mapID))
      or (specialContext and currentInstanceContext==specialContext)
  end

  local continent=nil
  local zoneIndex=nil
  if not currentPhysical then
    local karazhan=QuestieOcto.KarazhanContext
    if karazhan and karazhan:IsSharedArea(mapID) then return false end
    continent,zoneIndex=FindSelectableWorldMapZone(mapID)
    if not continent or not zoneIndex then return false end
  end

  if not WorldMapFrame:IsVisible() then
    if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end
  end

  if currentPhysical then
    if SetMapToCurrentZone then SetMapToCurrentZone() end
  else
    SetMapZoom(continent,zoneIndex)
  end

  if M.RequestSync then M:RequestSync(true) end
  return true
end

function M:CanShowTrackerObjective(questID,objectiveIndex,zoneGroup)
  local targets=CollectTrackerObjectiveTargets(questID,objectiveIndex)
  return ChooseTrackerTargetMap(targets,zoneGroup) and true or false
end

function M:ShowTrackerObjective(questID,objectiveIndex,zoneGroup)
  local targets=CollectTrackerObjectiveTargets(questID,objectiveIndex)
  local mapID,specialContext=ChooseTrackerTargetMap(targets,zoneGroup)
  if not mapID then return false end
  return OpenTrackerTargetMap(mapID,specialContext)
end

function M:CanShowTrackerFinisher(questID,zoneGroup)
  local targets=CollectTrackerFinisherTargets(questID)
  return ChooseTrackerTargetMap(targets,zoneGroup) and true or false
end

function M:ShowTrackerFinisher(questID,zoneGroup)
  local targets=CollectTrackerFinisherTargets(questID)
  local mapID,specialContext=ChooseTrackerTargetMap(targets,zoneGroup)
  if not mapID then return false end
  return OpenTrackerTargetMap(mapID,specialContext)
end

local function AttachWorldMapPinInput(pin)
  if not pin then return end
  pin:EnableMouse(true)
  pin:RegisterForClicks("LeftButtonUp")
  pin:SetScript("OnEnter",function() QuestieOcto.Tooltips:Show(this) end)
  pin:SetScript("OnLeave",function() QuestieOcto.Tooltips:Hide(this) end)
  -- Continent-map markers should behave as zone-entry targets instead of
  -- swallowing the click that would otherwise select the zone underneath.
  pin:SetScript("OnClick",function() OpenContinentZoneForPin(this) end)
end

function M:GetOrCreate(key,node,x,y,clusterCount,generation,kind)
  if not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) then return nil end

  local pin=self.frames[key]

  if not pin then
    pin=CreateFrame("Button",nil,WorldMapButton)
    pin:SetWidth(16)
    pin:SetHeight(16)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)

    local tex=pin:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints(pin)
    pin.texture=tex

    AttachWorldMapPinInput(pin)

    self.frames[key]=pin
    self.stats.created=self.stats.created+1
  else
    self.stats.reused=self.stats.reused+1
  end

  pin.itemStartArea=nil
  if pin.seenGeneration~=generation then
    pin.seenGeneration=generation
    if self.buildActiveFrames then table.insert(self.buildActiveFrames,pin) end
  end

  if pin.entryGeneration~=generation then
    pin.entryGeneration=generation
    pin.entries={}
    pin.displayName=nil
    pin.clusterCount=1
    pin.visualPriority=nil
    pin.role=nil
    pin.event=nil
    pin.pvp=nil
    pin.repeatable=nil
    pin.fullNode=nil
    pin.fullNodeNode=nil
    pin.iconScaleKey=nil
    pin.sourceKind=node.sourceKind
    pin.continentZoneMapID=nil
    if QuestieOcto.Visuals then QuestieOcto.Visuals:ClearPin(pin,1) end
  end

  pin.clusterCount=math.max(pin.clusterCount or 1,clusterCount or 1)

  -- Place at canonical coordinates first. Final layout resolves overlap
  -- after the complete visible pin set is known.
  UpdatePosition(pin,x,y,0,0)
  AddEntry(pin,node)
  if kind=="objectiveFull" or kind=="itemStartFull" then
    local current=pin.fullNodeNode
    if not current or self:GetVisualPriority(node)>self:GetVisualPriority(current) then
      pin.fullNodeNode=node
    end
    if QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
      QuestieOcto.Visuals:ApplyFullNode(pin,pin.fullNodeNode,false,1)
    end
  end
  self:ResizePin(pin)

  if not pin:IsShown() then pin:Show() end

  if kind=="exact" then
    self.stats.exact=self.stats.exact+1
  elseif kind=="itemStart" then
    self.stats.itemStartAreas=self.stats.itemStartAreas+1
  else
    self.stats.objectiveAreas=self.stats.objectiveAreas+1
  end

  return pin
end

local function RefreshPinVisual(pin)
  local wasFull=pin.fullNode and true or false
  pin.visualPriority=nil
  pin.role=nil
  pin.questID=nil
  pin.sourceID=nil
  pin.iconScaleKey=nil
  pin.fullNode=nil

  local fullNode=nil
  for _,entry in pairs(pin.entries or {}) do
    if entry.node then
      ApplyVisualRole(pin,entry.node)
      if wasFull and (not fullNode or M:GetVisualPriority(entry.node)>M:GetVisualPriority(fullNode)) then
        fullNode=entry.node
      end
    end
  end
  pin.fullNodeNode=fullNode
  if fullNode and QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
    QuestieOcto.Visuals:ApplyFullNode(pin,fullNode,false,1)
  end
  M:ResizePin(pin)
end

function M:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return 0 end

  local removed=0

  for _,pin in pairs(self.activeFrames or {}) do
    local changed=false

    if pin.itemStartArea and tonumber(pin.itemStartArea.questID)==questID then
      pin.itemStartArea=nil
      pin.entries={}
      changed=true
    else
      for key,entry in pairs(pin.entries or {}) do
        if entry.node and tonumber(entry.node.questID)==questID then
          pin.entries[key]=nil
          removed=removed+1
          changed=true
        end
      end
    end

    if changed then
      if pin.itemStartArea or next(pin.entries or {}) then
        RefreshPinVisual(pin)
      else
        if pin:IsShown() then
          pin:Hide()
          self.stats.hidden=self.stats.hidden+1
        end
      end
    end
  end

  -- Questie 5.2.3/6.0.0 UnloadQuestFrames removes every frame belonging
  -- to the quest, including both world-map and minimap copies.
  if QuestieOcto.Minimap and QuestieOcto.Minimap.RemoveQuest then
    removed=removed+QuestieOcto.Minimap:RemoveQuest(questID)
  end

  return removed
end

function M:HideAll()
  for _,pin in pairs(self.activeFrames or {}) do
    if pin:IsShown() then
      pin:Hide()
      self.stats.hidden=self.stats.hidden+1
    end
  end
  self.activeFrames={}
  self.buildActiveFrames=nil
  self.stats.active=0
end

function M:GetDisplayedMapID()
  return DisplayedMapID()
end

function M:GetDisplayedSpecialMapContext()
  local mapID=DisplayedMapID()
  return DisplayedSpecialMapContext(mapID)
end

function M:GetNearbyQuestTooltipPins(pin,maxPixels)
  local result={}
  if not pin or not pin:IsShown() then return result end

  maxPixels=tonumber(maxPixels) or 5
  local width=WorldMapButton and WorldMapButton:GetWidth() or 0
  local height=WorldMapButton and WorldMapButton:GetHeight() or 0
  if width<=0 or height<=0 then
    result[1]=pin
    return result
  end

  local px=(tonumber(pin.x) or 0)*width/100+(tonumber(pin.offsetX) or 0)
  local py=(tonumber(pin.y) or 0)*height/100+(tonumber(pin.offsetY) or 0)

  local _,other
  for _,other in pairs(self.activeFrames or {}) do
    if other and other:IsShown() and not IsPermanentRole(other.role) and (other.itemStartArea or next(other.entries or {})) then
      local ox=(tonumber(other.x) or 0)*width/100+(tonumber(other.offsetX) or 0)
      local oy=(tonumber(other.y) or 0)*height/100+(tonumber(other.offsetY) or 0)
      local dx=px-ox
      local dy=py-oy
      if dx*dx+dy*dy<=maxPixels*maxPixels then
        result[table.getn(result)+1]=other
      end
    end
  end

  if table.getn(result)==0 then result[1]=pin end

  table.sort(result,function(a,b)
    local ay=tonumber(a.y) or 0
    local by=tonumber(b.y) or 0
    if ay==by then return (tonumber(a.x) or 0)<(tonumber(b.x) or 0) end
    return ay<by
  end)

  return result
end

function M:SetMap(mapID,specialContext)
  mapID=tonumber(mapID)
  local karazhan=QuestieOcto.KarazhanContext
  if not karazhan or not karazhan:IsSharedArea(mapID) then specialContext=nil end
  if tonumber(self.mapID)==mapID and self.specialMapContext==specialContext then return end
  self.mapID=mapID
  self.specialMapContext=specialContext
  self.generation=self.generation+1
  self.syncing=false
  self.resync=false
  self.prune=false
  self.renderedPreparedPlan=nil
  self.syncPreparedPlan=nil
  self.continentPhysicalRegistry=nil
  self.continentItemAreaRegistry=nil
  self:HideAll()
end

function M:RenderItemStartArea(area,generation,continentZoneMapID)
  if not IsRoleEnabled("itemStart") then return end
  if not continentZoneMapID and not ItemAreaAllowedOnDisplayedMap(area) then return end
  local itemQuest=QuestieOcto.QuestModel:Get(area.questID)
  if itemQuest and itemQuest.pvp and not DisplaySettings():Get("showPvPRelatedQuests") then return end
  local itemEvent=itemQuest and itemQuest.eventID and QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:IsPresentationEvent(itemQuest.eventID) or false
  local itemPvP=itemQuest and itemQuest.pvp or false
  local itemRepeatable=itemQuest and itemQuest.presentationRepeatable or false

  local key="itemarea:"..tostring(area.key)
  local pin=self.frames[key]

  if not pin then
    pin=CreateFrame("Button",nil,WorldMapButton)
    pin:SetWidth(16)
    pin:SetHeight(16)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)

    local tex=pin:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints(pin)
    pin.texture=tex

    AttachWorldMapPinInput(pin)

    self.frames[key]=pin
    self.stats.created=self.stats.created+1
  else
    self.stats.reused=self.stats.reused+1
  end

  if pin.seenGeneration~=generation then
    pin.seenGeneration=generation
    if self.buildActiveFrames then table.insert(self.buildActiveFrames,pin) end
  end
  pin.itemStartArea=area
  pin.entries={}
  pin.continentZoneMapID=tonumber(continentZoneMapID)
  pin.visualPriority=40
  pin.role="itemStart"
  pin.questID=area.questID
  pin.event=itemEvent
  pin.pvp=itemPvP
  pin.repeatable=itemRepeatable
  pin.iconScaleKey=nil
  pin.sourceKind="area"
  pin.displayName=area.displayName
  pin.clusterCount=area.n
  pin.texture:SetTexture(TextureForNode({role="itemStart",questID=area.questID,event=pin.event,pvp=pin.pvp,repeatable=pin.repeatable}))
  pin.texture:SetDrawLayer("OVERLAY",5)
  if QuestieOcto.Visuals then
    QuestieOcto.Visuals:ApplyPin(pin,{role="itemStart",questID=area.questID,pvp=pin.pvp,repeatable=pin.repeatable},false,1)
  end
  self:ResizePin(pin)

  UpdatePosition(pin,area.x,area.y,0,0)

  if not pin:IsShown() then pin:Show() end
  self.stats.itemStartAreaPins=self.stats.itemStartAreaPins+1
  return pin
end

function M:RenderNode(node,generation)
  if not self.mapID then return end
  if not NodeAllowedOnDisplayedMap(node) then return end

  -- Clustered item-start sources are represented by geographic area pins.
  -- Full Nodes intentionally renders their raw spawn coordinates.
  if node.role=="itemStart" and DisplaySettings():Get("itemStartDensity")~="full" then return end

  local radius=QuestieOcto.Clustering.objectiveRadius
  local kind="objective"

  if node.role=="itemStart" then
    radius=QuestieOcto.Clustering.itemStartRadius
    kind="itemStart"
  end

  if IsExactRole(node.role) then
    local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,self.mapID)
    for _,p in pairs(points) do
      local key="exact:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
        string.format("%.2f",p.x)..":"..string.format("%.2f",p.y)
      self:GetOrCreate(key,node,p.x,p.y,1,generation,"exact")
    end
    return
  end

  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,self.mapID)
  local areas=QuestieOcto.Clustering:BuildAreas(points,radius)

  for _,area in pairs(areas) do
    local key="area:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..tostring(area.key)
    self:GetOrCreate(key,node,area.x,area.y,area.n,generation,kind)
  end
end

local function ResetVisibleOffsets(generation,frames)
  local groups={}

  for _,pin in pairs(frames or {}) do
    if pin:IsShown() and pin.seenGeneration==generation and pin.x and pin.y then
      local key=string.format("%.2f:%.2f",tonumber(pin.x) or 0,tonumber(pin.y) or 0)
      groups[key]=groups[key] or {}
      table.insert(groups[key],pin)
    end
  end

  local offsets={{0,0},{10,0},{-10,0},{0,10},{0,-10},{8,8},{-8,8},{8,-8},{-8,-8}}
  for _,group in pairs(groups) do
    table.sort(group,function(a,b)
      local ap=IsPermanentRole(a.role) and 1 or 0
      local bp=IsPermanentRole(b.role) and 1 or 0
      if ap~=bp then return ap<bp end
      if tostring(a.role)~=tostring(b.role) then return tostring(a.role)<tostring(b.role) end
      return tonumber(a.sourceID or 0)<tonumber(b.sourceID or 0)
    end)

    for index,pin in ipairs(group) do
      local off=offsets[math.mod(index-1,table.getn(offsets))+1]
      UpdatePosition(pin,pin.x,pin.y,off[1],off[2])
    end
  end
end

function M:Finish(generation,doPrune)
  if generation~=self.generation then return end

  local nextActive=self.buildActiveFrames or {}
  local seen={}
  for _,pin in pairs(nextActive) do seen[pin]=true end

  -- A completed sync is authoritative for the displayed map. Hide only frames
  -- from the previous active set that are no longer used; never scan the entire
  -- historical frame cache accumulated across zones.
  for _,pin in pairs(self.activeFrames or {}) do
    if not seen[pin] and pin:IsShown() then
      pin:Hide()
      self.stats.hidden=self.stats.hidden+1
    end
  end

  self.activeFrames=nextActive
  self.buildActiveFrames=nil
  ResetVisibleOffsets(generation,self.activeFrames)

  local active=0
  local visibleAvailable=0
  local visibleItemStart=0
  local visibleObjective=0
  local visibleTurnin=0
  local multiEntryPins=0

  for _,pin in pairs(self.activeFrames) do
    if pin:IsShown() then
      active=active+1
      if pin.role=="available" then visibleAvailable=visibleAvailable+1
      elseif pin.role=="itemStart" then visibleItemStart=visibleItemStart+1
      elseif pin.role=="turnin" then visibleTurnin=visibleTurnin+1
      else visibleObjective=visibleObjective+1 end

      local entries=0
      for _ in pairs(pin.entries or {}) do entries=entries+1 end
      if entries>1 then multiEntryPins=multiEntryPins+1 end
    end
  end

  self.stats.active=active
  self.stats.visibleAvailable=visibleAvailable
  self.stats.visibleItemStart=visibleItemStart
  self.stats.visibleObjective=visibleObjective
  self.stats.visibleTurnin=visibleTurnin
  self.stats.multiEntryPins=multiEntryPins
  self.stats.syncs=self.stats.syncs+1
  self.renderedPreparedPlan=self.syncPreparedPlan
  if self.syncNodeRevision~=nil then
    self.renderedNodeRevision=self.syncNodeRevision
  end
  self.syncPreparedPlan=nil
  self.syncNodeRevision=nil
  self.syncing=false

  if self.resync then
    local p=self.prune
    self.resync=false
    self.prune=false
    self:RequestSync(p)
  end
end

function M:RenderPreparedDescriptor(desc,generation,renderItemStarts)
  if desc.type=="itemStartArea" then
    if renderItemStarts and ItemAreaAllowedOnDisplayedMap(desc.area) then
      M:RenderItemStartArea(desc.area,generation)
    end
    return
  end

  if desc.type=="nodeSlot" then
    for _,entry in pairs(desc.entries or {}) do
      if entry.node and NodeAllowedOnDisplayedMap(entry.node)
         and (renderItemStarts or entry.node.role~="itemStart") then
        M:GetOrCreate(
          desc.key,
          entry.node,
          desc.x,
          desc.y,
          entry.clusterCount or 1,
          generation,
          entry.kind or "objective"
        )
      end
    end
    return
  end

  -- Backward compatibility for a prepared map published by an older cache
  -- during an in-session update/reload boundary.
  if desc.type=="node" and desc.node and NodeAllowedOnDisplayedMap(desc.node)
     and (renderItemStarts or desc.node.role~="itemStart") then
    M:GetOrCreate(desc.key,desc.node,desc.x,desc.y,desc.clusterCount or 1,generation,desc.kind or "objective")
  end
end

local function IsContinentQuestRole(role)
  return role=="available" or role=="turnin" or role=="itemStart"
end

-- Continent maps combine several independent zone coordinate systems. Turtle
-- data can legitimately describe the same physical source through two adjacent
-- zone maps, so mapID itself must not make those representations distinct once
-- they have been converted back to world coordinates.
local CONTINENT_SOURCE_DEDUPE_DISTANCE=20
local CONTINENT_ITEM_AREA_DEDUPE_DISTANCE=40
local CONTINENT_ITEM_AREA_ALT_MAP_DISTANCE=350

local function ContinentPinKey(node,mapID,x,y)
  if IsContinentQuestRole(node.role) then
    return "continent:quest-source:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
      tostring(mapID)..":"..string.format("%.2f",x)..":"..string.format("%.2f",y)
  end
  return "continent:"..tostring(node.role)..":"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
    tostring(mapID)..":"..string.format("%.2f",x)..":"..string.format("%.2f",y)
end

local function ContinentSourceSemanticKey(node)
  local sourceIdentity=tostring(node.sourceKind)..":"..tostring(node.sourceID)
  if node.sourceID==nil then
    -- Fail safe for synthetic/scripted sources that have no stable DB ID.
    sourceIdentity=sourceIdentity..":"..tostring(node.questID or 0)..":"..tostring(node.sourceName or "")
  end
  if IsContinentQuestRole(node.role) then
    -- Keep the established behavior where all quest relationships on one
    -- physical giver/source share one continent pin.
    return "continent:quest-source:"..sourceIdentity
  end
  return "continent:"..tostring(node.role)..":"..sourceIdentity
end

local function ClaimContinentPhysicalKey(registry,semanticKey,worldX,worldY,maxDistance)
  if not registry or not semanticKey or not worldX or not worldY then return nil,nil end
  local entries=registry[semanticKey]
  if not entries then
    entries={}
    registry[semanticKey]=entries
  end

  local limit=tonumber(maxDistance) or CONTINENT_SOURCE_DEDUPE_DISTANCE
  local limitSquared=limit*limit
  for _,entry in pairs(entries) do
    local dx=worldX-entry.worldX
    local dy=worldY-entry.worldY
    if dx*dx+dy*dy<=limitSquared then
      return entry.key,entry
    end
  end

  local key=semanticKey..":"..string.format("%.1f",worldX)..":"..string.format("%.1f",worldY)
  local entry={key=key,worldX=worldX,worldY=worldY}
  table.insert(entries,entry)
  return key,entry
end

local function CopyContinentItemSource(source)
  return {
    id=source.id,
    name=source.name,
    count=tonumber(source.count) or 0,
    chance=source.chance,
    rank=source.rank,
    respawnSeconds=source.respawnSeconds
  }
end

local function ItemSourceKey(source)
  if source and source.id~=nil then return "id:"..tostring(source.id) end
  return "name:"..tostring(source and source.name or "")
end

local function SortContinentItemSources(list)
  table.sort(list,function(a,b)
    local ac=tonumber(a.count) or 0
    local bc=tonumber(b.count) or 0
    if ac==bc then return tostring(a.name)<tostring(b.name) end
    return ac>bc
  end)
end

local function ContinentItemAreaSourceOverlap(a,b)
  local aSources={}
  local aCount=0
  for _,source in pairs((a and a.sourceList) or {}) do
    local key=ItemSourceKey(source)
    if not aSources[key] then aSources[key]=true; aCount=aCount+1 end
  end

  local bCount=0
  local common=0
  local seen={}
  for _,source in pairs((b and b.sourceList) or {}) do
    local key=ItemSourceKey(source)
    if not seen[key] then
      seen[key]=true
      bCount=bCount+1
      if aSources[key] then common=common+1 end
    end
  end

  local smaller=aCount
  if bCount<smaller then smaller=bCount end
  if smaller<=0 then return 0 end
  return common/smaller
end

local function ClaimContinentItemAreaKey(registry,semanticKey,worldX,worldY,area)
  if not registry or not semanticKey or not worldX or not worldY then return nil,nil end
  local entries=registry[semanticKey]
  if not entries then
    entries={}
    registry[semanticKey]=entries
  end

  local exactSquared=CONTINENT_ITEM_AREA_DEDUPE_DISTANCE*CONTINENT_ITEM_AREA_DEDUPE_DISTANCE
  local alternateSquared=CONTINENT_ITEM_AREA_ALT_MAP_DISTANCE*CONTINENT_ITEM_AREA_ALT_MAP_DISTANCE
  for _,entry in pairs(entries) do
    local dx=worldX-entry.worldX
    local dy=worldY-entry.worldY
    local distanceSquared=dx*dx+dy*dy
    if distanceSquared<=exactSquared then
      return entry.key,entry
    end

    -- Adjacent zone maps can partition the same physical hunting population
    -- differently, shifting the two area centroids even though their creature
    -- source sets clearly describe the same border population. Merge only when
    -- the source overlap is strong; proximity alone is never enough here.
    if distanceSquared<=alternateSquared and entry.area
       and ContinentItemAreaSourceOverlap(entry.area,area)>=0.75 then
      return entry.key,entry
    end
  end

  local key=semanticKey..":"..string.format("%.1f",worldX)..":"..string.format("%.1f",worldY)
  local entry={key=key,worldX=worldX,worldY=worldY}
  table.insert(entries,entry)
  return key,entry
end

local function CopyContinentItemArea(area,x,y,key)
  local copy={
    x=x,y=y,n=0,
    questID=area.questID,itemID=area.itemID,itemName=area.itemName,
    sourceList={},displayName=area.displayName,key=key,
    zoneWideRare=area.zoneWideRare and true or nil,
    rareThreshold=area.rareThreshold
  }
  local byKey={}
  for _,source in pairs(area.sourceList or {}) do
    local sourceCopy=CopyContinentItemSource(source)
    local sourceKey=ItemSourceKey(sourceCopy)
    byKey[sourceKey]=sourceCopy
    table.insert(copy.sourceList,sourceCopy)
  end
  copy._continentSourceByKey=byKey
  SortContinentItemSources(copy.sourceList)
  for _,source in pairs(copy.sourceList) do copy.n=copy.n+(tonumber(source.count) or 0) end
  local first=copy.sourceList[1]
  if first then copy.displayName=first.name end
  return copy
end

local function MergeContinentItemArea(target,incoming)
  if not target or not incoming then return end
  target._continentSourceByKey=target._continentSourceByKey or {}

  for _,source in pairs(incoming.sourceList or {}) do
    local sourceKey=ItemSourceKey(source)
    local current=target._continentSourceByKey[sourceKey]
    if not current then
      current=CopyContinentItemSource(source)
      target._continentSourceByKey[sourceKey]=current
      table.insert(target.sourceList,current)
    elseif (tonumber(source.count) or 0)>(tonumber(current.count) or 0) then
      -- Neighboring map representations can contain the same physical spawn
      -- set. Keep the larger representation instead of double-counting it.
      current.count=tonumber(source.count) or current.count
    end
  end

  SortContinentItemSources(target.sourceList)
  target.n=0
  for _,source in pairs(target.sourceList) do target.n=target.n+(tonumber(source.count) or 0) end
  local first=target.sourceList[1]
  if first then target.displayName=first.name end
end

function M:RenderContinentNode(node,mapID,generation,physicalRegistry)
  if not node or not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) then return 0 end
  -- Continent item starts are rendered later from quest+item hunting areas for
  -- both Clustered and Full Nodes. Full Nodes remains a zone/minimap detail mode.
  if node.role=="itemStart" then return 0 end
  -- World Map Visibility toggles apply only to continent/world overviews.
  -- Selected zone and city maps keep normal/special quest markers visible and
  -- are controlled by Enable Available/Completed Quest Icons instead.
  if IsContinentQuestRole(node.role) and not IsQuestMarkerNodeEnabled(node) then return 0 end
  -- The continent overview intentionally shows only quest start/turn-in markers
  -- plus Flight Masters. Objective/slay/full-node/cluster data remains zone-only.
  if not IsContinentQuestRole(node.role) and node.role~="flightMaster" then return 0 end

  local projection=QuestieOcto.ContinentProjection
  if not projection then return 0 end
  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,mapID)
  if not points or table.getn(points)==0 then return 0 end

  local rendered=0
  for _,point in pairs(points) do
    local x,y=projection:Project(mapID,point.x,point.y)
    if x and y then
      local worldX,worldY=projection:ToWorld(mapID,point.x,point.y)
      local key=nil
      if worldX and worldY then
        key=ClaimContinentPhysicalKey(
          physicalRegistry,
          ContinentSourceSemanticKey(node),
          worldX,worldY,
          CONTINENT_SOURCE_DEDUPE_DISTANCE
        )
      end
      if not key then key=ContinentPinKey(node,mapID,x,y) end
      local pin=self:GetOrCreate(key,node,x,y,1,generation,"exact")
      -- Keep the first/canonical zone representation for click-through rather
      -- than letting a duplicate neighboring-map representation replace it.
      if pin and not pin.continentZoneMapID then pin.continentZoneMapID=mapID end
      rendered=rendered+1
    end
  end
  return rendered
end

local function ContinentItemStartNodeEnabled(node)
  if not node or node.role~="itemStart" then return false end
  if QuestieOcto.ItemStartAreas:IsZoneWideRareChance(node.chance) then return false end
  if not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) then return false end
  return IsQuestMarkerNodeEnabled(node) and true or false
end

local function RenderContinentItemStartAreas(nodes,mapID,generation,areaRegistry,questFilter)
  if not IsRoleEnabled("itemStart") then return end
  local projection=QuestieOcto.ContinentProjection
  local itemAreas=QuestieOcto.ItemStartAreas
  if not projection or not itemAreas then return end

  -- Intentionally ignore itemStartDensity here. The continent never shows raw
  -- monster spawn nodes; both Clustered and Full Nodes therefore use the same
  -- quest+starter-item geographic areas on the overview map.
  local function includeNode(node)
    if questFilter and not questFilter[tonumber(node and node.questID)] then return false end
    return ContinentItemStartNodeEnabled(node)
  end
  local areas=itemAreas:BuildForMap(nodes or {},mapID,includeNode)
  for _,area in pairs(areas or {}) do
    local x,y=projection:Project(mapID,area.x,area.y)
    local worldX,worldY=projection:ToWorld(mapID,area.x,area.y)
    if x and y then
      local semanticKey="continent:item-area:"..tostring(area.questID)..":"..tostring(area.itemID or 0)
      local key,entry=nil,nil
      if worldX and worldY then
        key,entry=ClaimContinentItemAreaKey(
          areaRegistry,semanticKey,worldX,worldY,area
        )
      end
      if not key then
        key=semanticKey..":"..tostring(mapID)..":"..string.format("%.2f",x)..":"..string.format("%.2f",y)
      end

      if entry and entry.area then
        MergeContinentItemArea(entry.area,area)
        M:RenderItemStartArea(entry.area,generation,entry.zoneMapID)
      else
        local displayArea=CopyContinentItemArea(area,x,y,key)
        if entry then
          entry.area=displayArea
          entry.zoneMapID=mapID
        end
        M:RenderItemStartArea(displayArea,generation,mapID)
      end
    end
  end
end

local function AddContinentRareItemStart(groups,node,mapID)
  if not node or node.role~="itemStart" or not QuestieOcto.ItemStartAreas:IsZoneWideRareChance(node.chance) then return false end
  -- Consume ultra-rare nodes even when their world-map category is disabled so
  -- they do not fall back to an ordinary continent renderer.
  if not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) or not IsQuestMarkerNodeEnabled(node) then return true end
  local projection=QuestieOcto.ContinentProjection
  if not projection then return false end
  local key=tostring(node.questID)..":"..tostring(node.itemID or 0)
  local group=groups[key]
  if not group then
    group={
      questID=node.questID,itemID=node.itemID,itemName=node.itemName,
      sx=0,sy=0,n=0,worldSX=0,worldSY=0,worldN=0,sources={}
    }
    groups[key]=group
  end

  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,mapID)
  for _,point in pairs(points or {}) do
    local x,y=projection:Project(mapID,point.x,point.y)
    if x and y then
      group.sx=group.sx+x
      group.sy=group.sy+y
      group.n=group.n+1
      local worldX,worldY=projection:ToWorld(mapID,point.x,point.y)
      if worldX and worldY then
        group.worldSX=group.worldSX+worldX
        group.worldSY=group.worldSY+worldY
        group.worldN=group.worldN+1
      end
      local source=group.sources[node.sourceID]
      if not source then
        source={
          id=node.sourceID,name=node.sourceName,count=0,chance=node.chance,
          rank=node.sourceRank,respawnSeconds=node.respawnSeconds
        }
        group.sources[node.sourceID]=source
      end
      source.count=source.count+1
    end
  end
  return true
end

local function RenderContinentRareItemStarts(groups,mapID,generation,areaRegistry)
  for _,group in pairs(groups or {}) do
    if group.n and group.n>0 then
      local sourceList={}
      for _,source in pairs(group.sources or {}) do table.insert(sourceList,source) end
      table.sort(sourceList,function(a,b)
        if a.count==b.count then return tostring(a.name)<tostring(b.name) end
        return a.count>b.count
      end)
      local first=sourceList[1]
      local x=group.sx/group.n
      local y=group.sy/group.n
      local area={
        x=x,y=y,n=group.n,
        questID=group.questID,itemID=group.itemID,itemName=group.itemName,
        sourceList=sourceList,zoneWideRare=true,
        rareThreshold=QuestieOcto.ItemStartAreas.zoneWideRareThreshold,
        displayName=first and first.name or "Rare item-start source"
      }

      local semanticKey="continent:item-rare:"..tostring(group.questID)..":"..tostring(group.itemID or 0)
      local key,entry=nil,nil
      if group.worldN and group.worldN>0 then
        key,entry=ClaimContinentItemAreaKey(
          areaRegistry,semanticKey,
          group.worldSX/group.worldN,group.worldSY/group.worldN,
          area
        )
      end
      if not key then
        key=semanticKey..":"..tostring(mapID)..":"..string.format("%.2f",x)..":"..string.format("%.2f",y)
      end

      if entry and entry.area then
        MergeContinentItemArea(entry.area,area)
        M:RenderItemStartArea(entry.area,generation,entry.zoneMapID)
      else
        local displayArea=CopyContinentItemArea(area,x,y,key)
        if entry then
          entry.area=displayArea
          entry.zoneMapID=mapID
        end
        M:RenderItemStartArea(displayArea,generation,mapID)
      end
    end
  end
end

local function ClearChangedContinentItemAreas(registry,changed)
  if not registry or not changed then return end
  for semanticKey,entries in pairs(registry) do
    local keep={}
    for _,entry in pairs(entries or {}) do
      if not (entry.area and changed[tonumber(entry.area.questID)]) then
        table.insert(keep,entry)
      end
    end
    if table.getn(keep)>0 then registry[semanticKey]=keep else registry[semanticKey]=nil end
  end
end

function M:StartContinentSync(continentMapID,doPrune)
  self.displayingPlayerZone = false
  continentMapID=tonumber(continentMapID)
  if continentMapID==nil or not QuestieOcto.ContinentProjection then return end

  local contextKey=-1000-continentMapID
  if tonumber(self.mapID)~=contextKey or self.specialMapContext~=nil then self:SetMap(contextKey,nil) end
  if not QuestieOcto.Nodes.ready then self.syncing=false; return end

  self.generation=self.generation+1
  local generation=self.generation
  self.syncing=true
  self.syncPreparedPlan=nil
  self.syncNodeRevision=QuestieOcto.Nodes.stateRevision or 0
  self.buildActiveFrames={}
  self.stats.reused=0
  self.stats.exact=0
  self.stats.objectiveAreas=0
  self.stats.itemStartAreas=0
  self.stats.inputNodes=0

  local mapIDs=QuestieOcto.ContinentProjection:GetZoneMapIDs(continentMapID)
  local mapPos=1
  local nodePos=1
  local nodes=nil
  local rareGroups={}
  local physicalRegistry={}
  local itemAreaRegistry={}
  self.continentPhysicalRegistry=physicalRegistry
  self.continentItemAreaRegistry=itemAreaRegistry

  local function step()
    if generation~=M.generation then return end

    local budget=96
    while budget>0 and mapPos<=table.getn(mapIDs) do
      if not nodes then
        nodes=QuestieOcto.Nodes:GetMapNodes(mapIDs[mapPos]) or {}
        nodePos=1
        rareGroups={}
        M.stats.inputNodes=M.stats.inputNodes+table.getn(nodes)
      end

      if nodePos<=table.getn(nodes) then
        local node=nodes[nodePos]
        if not AddContinentRareItemStart(rareGroups,node,mapIDs[mapPos]) then
          M:RenderContinentNode(node,mapIDs[mapPos],generation,physicalRegistry)
        end
        nodePos=nodePos+1
        budget=budget-1
      else
        RenderContinentItemStartAreas(nodes,mapIDs[mapPos],generation,itemAreaRegistry)
        RenderContinentRareItemStarts(rareGroups,mapIDs[mapPos],generation,itemAreaRegistry)
        nodes=nil
        rareGroups={}
        mapPos=mapPos+1
        -- Item-start geographic aggregation is deliberately done one zone at a
        -- time. Yield here so opening a continent map never turns the cleanup
        -- pass into one large synchronous frame.
        budget=0
      end
    end

    if mapPos<=table.getn(mapIDs) then
      QuestieOcto.Scheduler:Enqueue(step,"map-continent-render")
    else
      M:Finish(generation,doPrune)
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"map-continent-render")
end

function M:StartSync(doPrune)
  if not self.enabled or not WorldMapButton then return end

  -- Quest icon visibility is separate from townsfolk/service markers.
  -- Always build the map pass; IsRoleEnabled filters each semantic role.
  local mapID=DisplayedMapID()
  if not mapID then
    local continentMapID=DisplayedContinentMapID()
    if continentMapID~=nil then
      self:StartContinentSync(continentMapID,doPrune)
      return
    end
    self:SetMap(nil,nil)
    return
  end

  local specialContext = DisplayedSpecialMapContext(mapID)
  if tonumber(self.mapID) ~= tonumber(mapID) or self.specialMapContext ~= specialContext then
    self:SetMap(mapID, specialContext)
  end

  self.displayingPlayerZone = IsDisplayedMapPlayerCurrentZone(mapID)

  if not QuestieOcto.PreparedMap:Get(mapID) then
    -- Any map the player actually opens becomes top priority immediately.
    -- This works even before the global Nodes build has completed.
    if QuestieOcto.ZoneBootstrap then
      QuestieOcto.ZoneBootstrap:Request(mapID,0.01)
      self.stats.mapPriorityRequests=(self.stats.mapPriorityRequests or 0)+1
    end

    if not QuestieOcto.Nodes.ready then
      return
    end
  end

  self.generation=self.generation+1
  local generation=self.generation
  self.syncing=true
  self.buildActiveFrames={}
  self.stats.reused=0
  self.stats.exact=0
  self.stats.objectiveAreas=0
  self.stats.itemStartAreas=0

  local nodes=QuestieOcto.Nodes:GetMapNodes(mapID)
  self.stats.inputNodes=table.getn(nodes)
  self.stats.itemStartRawNodes=0
  self.stats.itemStartAreaPins=0

  for _,node in pairs(nodes) do
    if node.role=="itemStart" then
      self.stats.itemStartRawNodes=self.stats.itemStartRawNodes+1
    end
  end

  local prepared=QuestieOcto.PreparedMap:Get(mapID)
  self.syncPreparedPlan=prepared

  if prepared then
    self.stats.preparedHits=self.stats.preparedHits+1
    self.stats.preparedDescriptors=table.getn(prepared)

    -- Prepared descriptors contain no DB discovery or clustering work.
    -- Typical zone maps can therefore appear in one rendering tick.
    local worldItemStarts=QuestieOcto.PreparedMap:GetWorldItemStarts(mapID) or {}
    local pos=1
    local itemPos=1
    local function preparedStep()
      if generation~=M.generation then return end

      local count=0
      while pos<=table.getn(prepared) and count<128 do
        M:RenderPreparedDescriptor(prepared[pos],generation,false)
        pos=pos+1
        count=count+1
      end
      while pos>table.getn(prepared) and itemPos<=table.getn(worldItemStarts) and count<128 do
        M:RenderPreparedDescriptor(worldItemStarts[itemPos],generation,true)
        itemPos=itemPos+1
        count=count+1
      end

      if pos<=table.getn(prepared) or itemPos<=table.getn(worldItemStarts) then
        QuestieOcto.Scheduler:Enqueue(preparedStep,"map-prepared-render")
      else
        M:Finish(generation,doPrune)
      end
    end

    QuestieOcto.Scheduler:Enqueue(preparedStep,"map-prepared-render")
    return
  end

  self.stats.preparedMisses=self.stats.preparedMisses+1

  -- First visit before background preparation reached this zone:
  -- prepare just this map, then render it on the next scheduler turn.
  QuestieOcto.Scheduler:Enqueue(function()
    if generation~=M.generation then return end

    QuestieOcto.PreparedMap:BuildMap(mapID)
    local ready=QuestieOcto.PreparedMap:Get(mapID)
    M.syncPreparedPlan=ready

    if not ready then
      M.syncing=false
      return
    end

    local worldItemStarts=QuestieOcto.PreparedMap:GetWorldItemStarts(mapID) or {}
    local pos=1
    local itemPos=1
    local function fallbackPreparedStep()
      if generation~=M.generation then return end

      local count=0
      while pos<=table.getn(ready) and count<128 do
        M:RenderPreparedDescriptor(ready[pos],generation,false)
        pos=pos+1
        count=count+1
      end
      while pos>table.getn(ready) and itemPos<=table.getn(worldItemStarts) and count<128 do
        M:RenderPreparedDescriptor(worldItemStarts[itemPos],generation,true)
        itemPos=itemPos+1
        count=count+1
      end

      if pos<=table.getn(ready) or itemPos<=table.getn(worldItemStarts) then
        QuestieOcto.Scheduler:Enqueue(fallbackPreparedStep,"map-first-prepare-render")
      else
        M:Finish(generation,doPrune)
      end
    end

    fallbackPreparedStep()
  end,"map-first-prepare")
end

function M:RefreshVisualSettings()
  for _,pin in pairs(self.activeFrames or {}) do
    if pin.itemStartArea then
      if QuestieOcto.Visuals then QuestieOcto.Visuals:ClearPin(pin,1) end
    elseif pin.entries and next(pin.entries) then
      pin.visualPriority=nil
      pin.role=nil
      pin.iconScaleKey=nil
      RefreshPinVisual(pin)
      if QuestieOcto.Visuals then QuestieOcto.Visuals:SetAlpha(pin,1) end
    end
  end

  if QuestieOcto.Minimap and QuestieOcto.Minimap.RefreshVisualSettings then
    QuestieOcto.Minimap:RefreshVisualSettings()
  end
end

function M:RescaleIcons(changedKey,changedValue)
  self.stats.rescalePasses=(self.stats.rescalePasses or 0)+1

  -- Scaling is presentation-only. Do not rebuild a pin's semantic visual here:
  -- doing so used to replace Full Nodes with the normal Questie objective
  -- texture until the next map sync. The global slider now changes size only.
  for _,pin in pairs(self.activeFrames or {}) do
    self:ResizePin(pin)
  end
end

function M:ApplySettings()
  self:RescaleIcons()
  self:RequestSync(true)
end

function M:OnSettingChanged(key,value)
  if key=="enableMapIcons" or key=="showAvailableQuestsWorldMap" or key=="showCompletedQuestsWorldMap" or key=="showSpecialQuestsWorldMap" or key=="showPvPRelatedQuests" or key=="enableObjectives" or key=="enableTurnins" or
     key == "showAvailableQuestMapCurrentZone" or key == "showTurninsCurrentZoneMap" or
     key=="enableAvailable" or key=="showItemStartQuests" or key=="showItemStartMap" or
     key=="showMapAuctioneer" or key=="showMapBanker" or
     key=="showMapFlightMaster" or key=="showMapMailbox" or
     key=="showMapBattlemaster" or key=="showMapInnkeeper" or key=="showMapMeetingStone" or
     key=="showMapRepair" or key=="showMapSpiritHealer" or key=="showMapStableMaster" or key=="showMapVendor" or
     key=="showMapRareMonsters" then
    self:RequestSync(true)
  end
end

function M:RequestSync(doPrune)
  if self.syncing then
    self.resync=true
    if doPrune then self.prune=true end
    return
  end

  QuestieOcto.Scheduler:After(0.01,function()
    M:StartSync(doPrune and true or false)
  end,"map-sync")
end

function M:PatchContinentQuests(changedQuests)
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return false end
  local continentMapID=DisplayedContinentMapID()
  if continentMapID==nil or not QuestieOcto.ContinentProjection then return false end

  -- If a full continent render is already in flight, let it finish against the
  -- newest canonical Nodes snapshot rather than mutating its frame set midway.
  if self.syncing then
    self.resync=true
    self.prune=true
    return true
  end

  local changed={}
  for questID in pairs(changedQuests or {}) do
    questID=tonumber(questID)
    if questID and questID>0 then changed[questID]=true end
  end
  if not next(changed) then return true end

  local contextKey=-1000-tonumber(continentMapID)
  if tonumber(self.mapID)~=contextKey then return false end

  -- Remove only changed quest relationships from the currently visible pins,
  -- but do not hide them yet. A quest can disappear and reappear on the same
  -- physical source key during a filter change; deferring visibility decisions
  -- until after additions prevents an off/on frame flash.
  local touched={}
  for _,pin in pairs(self.activeFrames or {}) do
    if pin.itemStartArea and changed[tonumber(pin.itemStartArea.questID)] then
      pin.itemStartArea=nil
      touched[pin]=true
    end

    for key,entry in pairs(pin.entries or {}) do
      if entry and entry.node and changed[tonumber(entry.node.questID)] then
        pin.entries[key]=nil
        touched[pin]=true
      end
    end
  end

  -- A pin hidden by an earlier incremental filter patch can be reused later in
  -- this same continent generation. Reset only those empty hidden frames so a
  -- stale visual priority cannot prevent a newly visible quest from owning it.
  for _,pin in pairs(self.frames or {}) do
    if pin.seenGeneration==self.generation and not pin:IsShown()
       and not pin.itemStartArea and not next(pin.entries or {}) then
      pin.visualPriority=nil
      pin.role=nil
      pin.questID=nil
      pin.sourceID=nil
      pin.event=nil
      pin.pvp=nil
      pin.repeatable=nil
      pin.fullNode=nil
      pin.fullNodeNode=nil
      pin.iconScaleKey=nil
    end
  end

  -- Add only the new semantic state for the changed quests. Unrelated continent
  -- icons never get rebound, cleared or recreated when Low-Level Quest range
  -- changes, so they remain visually stable throughout the update.
  self.continentPhysicalRegistry=self.continentPhysicalRegistry or {}
  self.continentItemAreaRegistry=self.continentItemAreaRegistry or {}
  ClearChangedContinentItemAreas(self.continentItemAreaRegistry,changed)

  local mapIDs=QuestieOcto.ContinentProjection:GetZoneMapIDs(continentMapID)
  for _,mapID in ipairs(mapIDs or {}) do
    local rareGroups={}
    local mapNodes=QuestieOcto.Nodes:GetMapNodes(mapID) or {}
    for _,node in pairs(mapNodes) do
      if changed[tonumber(node.questID)] then
        if not AddContinentRareItemStart(rareGroups,node,mapID) then
          self:RenderContinentNode(node,mapID,self.generation,self.continentPhysicalRegistry)
        end
      end
    end
    RenderContinentItemStartAreas(mapNodes,mapID,self.generation,self.continentItemAreaRegistry,changed)
    RenderContinentRareItemStarts(rareGroups,mapID,self.generation,self.continentItemAreaRegistry)
  end

  -- Re-evaluate only pins that lost old relationships. AddEntry already handles
  -- newly added relationships, but a removed high-priority entry can otherwise
  -- leave its old visual owner cached on a shared coordinate.
  for pin in pairs(touched) do
    if pin.itemStartArea then
      -- RenderItemStartArea already refreshed this pin's complete visual state.
    elseif next(pin.entries or {}) then
      RefreshPinVisual(pin)
    else
      if pin:IsShown() then
        pin:Hide()
        self.stats.hidden=self.stats.hidden+1
      end
    end
  end

  -- Rebuild the small active-frame index from already-bound frames. Frames from
  -- older map contexts have a different generation and stay excluded.
  local active={}
  for _,pin in pairs(self.frames or {}) do
    if pin.seenGeneration==self.generation and (pin.itemStartArea or next(pin.entries or {})) then
      if not pin:IsShown() then pin:Show() end
      table.insert(active,pin)
    end
  end
  self.activeFrames=active
  ResetVisibleOffsets(self.generation,self.activeFrames)

  local visibleAvailable,visibleItemStart,visibleObjective,visibleTurnin=0,0,0,0
  for _,pin in pairs(self.activeFrames) do
    if pin.role=="available" then visibleAvailable=visibleAvailable+1
    elseif pin.role=="itemStart" then visibleItemStart=visibleItemStart+1
    elseif pin.role=="turnin" then visibleTurnin=visibleTurnin+1
    else visibleObjective=visibleObjective+1 end
  end
  self.stats.active=table.getn(self.activeFrames)
  self.stats.visibleAvailable=visibleAvailable
  self.stats.visibleItemStart=visibleItemStart
  self.stats.visibleObjective=visibleObjective
  self.stats.visibleTurnin=visibleTurnin
  self.stats.incrementalContinentPatches=(self.stats.incrementalContinentPatches or 0)+1
  self.renderedNodeRevision=QuestieOcto.Nodes.stateRevision or self.renderedNodeRevision
  return true
end

function M:EnsureDisplayedContextCurrent()
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end

  local contextKey=DisplayedContextKey()
  local displayedMapID=DisplayedMapID()
  local specialContext=DisplayedSpecialMapContext(displayedMapID)
  if tonumber(contextKey)~=tonumber(self.mapID) or self.specialMapContext~=specialContext then
    self:SetMap(contextKey,specialContext)
    self:RequestSync(false)
    return
  end

  local mapID=displayedMapID
  if mapID then
    local prepared=QuestieOcto.PreparedMap:Get(mapID)
    -- PREPARED_MAP_READY can fire while the World Map is hidden. Comparing the
    -- actual published plan makes reopening the SAME zone self-healing even
    -- when WORLD_MAP_UPDATE does not change the map context. Do not queue a
    -- duplicate redraw if this exact plan is already the one being rendered.
    if prepared and prepared~=self.renderedPreparedPlan and prepared~=self.syncPreparedPlan then
      self:RequestSync(true)
    end
  elseif DisplayedContinentMapID()~=nil then
    -- NODES_CHANGED is intentionally ignored while the World Map is hidden.
    -- Remember the canonical Nodes revision rendered by the continent view so
    -- reopening the SAME continent after a quest completes self-heals just like
    -- selected zone maps already do through PreparedMap identity.
    local revision=QuestieOcto.Nodes and QuestieOcto.Nodes.stateRevision or 0
    if tonumber(self.renderedNodeRevision or 0)~=tonumber(revision) then
      self:RequestSync(true)
    end
  end
end

function M:OnNodesChanged(mapSet,changedQuests)
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end

  -- Zone maps consume PreparedMap's transactional replacement and refresh on
  -- PREPARED_MAP_READY. Continent maps do not use PreparedMap, so patch their
  -- changed quest relationships directly instead of starting a full re-render.
  if DisplayedMapID() then return end
  if DisplayedContinentMapID()~=nil then
    if not self:PatchContinentQuests(changedQuests) then self:RequestSync(true) end
  end
end

function M:OnNodesReady()
  -- Full node publications still drive continent maps directly. Selected zone
  -- maps must wait for PREPARED_MAP_READY; syncing here would consume the old
  -- prepared plan once and then the replacement plan moments later, producing
  -- an unnecessary visible rebind.
  if WorldMapFrame and WorldMapFrame:IsVisible()
     and not DisplayedMapID() and DisplayedContinentMapID()~=nil then
    self:RequestSync(true)
  end
end

QuestieOcto:RegisterMessage("NODES_CHANGED",M,"OnNodesChanged")
QuestieOcto:RegisterMessage("NODES_READY",M,"OnNodesReady")

function M:OnPreparedMapReady(mapID)
  if WorldMapFrame and WorldMapFrame:IsVisible()
     and tonumber(mapID)==tonumber(DisplayedMapID()) then
    self:RequestSync(true)
  end
end

QuestieOcto:RegisterMessage("PREPARED_MAP_READY",M,"OnPreparedMapReady")

local f=CreateFrame("Frame","QuestieOctoWorldMapEvents",UIParent)
f:RegisterEvent("WORLD_MAP_UPDATE")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent",function()
  if event == "WORLD_MAP_UPDATE" then
    if WorldMapFrame and WorldMapFrame:IsVisible() then
      M:EnsureDisplayedContextCurrent()
    end
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    if WorldMapFrame and WorldMapFrame:IsVisible() then
      M:RequestSync(true)
    end
  elseif event == "PLAYER_LEVEL_UP" then
    -- Gray classification depends only on the current player/quest levels.
    -- Rebind the visible map presentation; do not rebuild geometry or quest truth.
    QuestieOcto.Scheduler:After(0.01,function()
      if WorldMapFrame and WorldMapFrame:IsVisible() then M:RequestSync(true) end
    end,"map-gray-level-refresh")
  end
end)

-- WORLD_MAP_UPDATE is not guaranteed to change context when the map is reopened
-- after a density change made while hidden. Revalidate the published prepared
-- plan on every show as a second, deterministic refresh boundary.
if WorldMapFrame and not M.worldMapShowHooked then
  M.worldMapShowHooked=true
  local function OnWorldMapShow()
    QuestieOcto.Scheduler:After(0.01,function()
      M:EnsureDisplayedContextCurrent()
    end,"map-show-density-sync")
  end

  -- HookScript is additive: UI replacements can keep their own OnShow handler
  -- without taking ownership away from Questie-Octo (and vice versa). Keep a
  -- forwarding SetScript fallback for older clients that do not expose it.
  if WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow",OnWorldMapShow)
  else
    local previousOnShow=WorldMapFrame:GetScript("OnShow")
    WorldMapFrame:SetScript("OnShow",function()
      if previousOnShow then previousOnShow() end
      OnWorldMapShow()
    end)
  end
end

