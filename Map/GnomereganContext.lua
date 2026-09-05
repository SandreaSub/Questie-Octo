-- Questie-Octo Gnomeregan shared-map compatibility.
--
-- Current Turtle/Octo client data reuses AreaTable ID 721 for two distinct
-- World Map contexts:
--   server map 0  / texture GnomereganEntrance -> exterior/entrance complex
--   server map 90 / texture Gnomeregan         -> dungeon interior
--
-- The old pfQuest-style database stores both contexts under numeric map 721.
-- Keep the normal numeric-map architecture everywhere else and split only this
-- proven collision at presentation time. Current server-backed source identity
-- separates the two populations; the Mechanical Mailbox (144112) exists in
-- both and is disambiguated by its corrected map coordinate.

QuestieOcto.GnomereganContext = QuestieOcto.GnomereganContext or {}
local G = QuestieOcto.GnomereganContext

G.sharedAreaID=721
G.entranceServerMapID=0
G.interiorServerMapID=90
G.entranceTexture="gnomereganentrance"
G.interiorTexture="gnomeregan"

-- Current WorldMapArea.dbc bounds:
--   GnomereganEntrance: 571.19 x 379.14
--   Gnomeregan:         1125.00 x 740.00
G.entranceMinimapWidth=571.19
G.entranceMinimapHeight=379.14
G.interiorMinimapWidth=1125
G.interiorMinimapHeight=740

local function AddIDs(target,list)
  local _,id
  for _,id in pairs(list or {}) do target[tonumber(id)]=true end
end

G.entranceCreatures={}
AddIDs(G.entranceCreatures,{
  1211,2683,4081,6169,6208,6209,6210,6213,6221,6231,6569,7732,7843,7937,
  7944,7950,8320,50637,61428,61429,61430,61431,61432,61434,61435,61436,
  61437,61438,61440,61441,61442,61443,61444,61445,61446,61456,61644,
  62009,62100,80940
})

G.interiorCreatures={}
AddIDs(G.interiorCreatures,{
  6206,6207,6211,6218,6219,6220,6222,6223,6225,6230,6233,6329,6391,6392,
  6407,7079,7603,7850,7897,7998,9676
})

G.entranceObjects={}
AddIDs(G.entranceObjects,{1731,3658,23305,106318,144112,2010914,2020021})

G.interiorObjects={}
AddIDs(G.interiorObjects,{19020,74448,142344,142487,144112,175084,175085,2020020})

G.entranceAreaTriggers={}
AddIDs(G.entranceAreaTriggers,{324,523,1104})

G.interiorAreaTriggers={}
AddIDs(G.interiorAreaTriggers,{322,1105})

-- Mechanical Mailbox exists in both Gnomeregan contexts. Runtime coordinates
-- are rounded to one decimal place, so key the corrected points the same way.
G.sharedObjectPoints={
  [144112]={
    entrance={ ["68.7:4.5"]=true, ["70.0:3.2"]=true },
    interior={ ["61.8:40.9"]=true },
  },
}

function G:IsSharedArea(mapID)
  return tonumber(mapID)==self.sharedAreaID
end

local function NormalizeTexture(textureName)
  if type(textureName)~="string" or textureName=="" then return nil end
  local value=string.lower(textureName)
  value=string.gsub(value,"/","\\")
  local entranceLength=string.len(G.entranceTexture)
  if string.len(value)>=entranceLength and string.sub(value,-entranceLength)==G.entranceTexture then
    return G.entranceTexture
  end
  local interiorLength=string.len(G.interiorTexture)
  if string.len(value)>=interiorLength and string.sub(value,-interiorLength)==G.interiorTexture then
    return G.interiorTexture
  end
  return value
end

function G:GetDisplayedContext(mapID)
  if not self:IsSharedArea(mapID) then return nil end
  local api=QuestieOcto.API
  local texture=api and api.GetDisplayedMapTextureName and api:GetDisplayedMapTextureName() or nil
  texture=NormalizeTexture(texture)
  if texture==self.entranceTexture then return "entrance" end
  if texture==self.interiorTexture then return "interior" end
  return nil
end

function G:GetPhysicalContext(mapID)
  if not self:IsSharedArea(mapID) then return nil end
  local api=QuestieOcto.API
  local serverMapID=api and api.GetInstanceMapID and tonumber(api:GetInstanceMapID()) or nil
  if serverMapID==self.interiorServerMapID then return "interior" end
  if serverMapID==self.entranceServerMapID then return "entrance" end

  -- Outside instances, physical AreaTable 721 is necessarily the entrance
  -- WorldMapArea on server map 0. Inside an unknown party/raid context, fail
  -- closed rather than guessing and projecting the entrance geometry.
  if api and api.IsInDungeonOrRaid and api:IsInDungeonOrRaid() then return nil end
  return "entrance"
end

function G:GetMinimapSize(context)
  if context=="entrance" then return self.entranceMinimapWidth,self.entranceMinimapHeight end
  if context=="interior" then return self.interiorMinimapWidth,self.interiorMinimapHeight end
  return nil,nil
end

local function PointKey(x,y)
  x=tonumber(x); y=tonumber(y)
  if not x or not y then return nil end
  return string.format("%.1f:%.1f",x,y)
end

function G:GetSourceContext(sourceKind,sourceID,x,y)
  sourceID=tonumber(sourceID)
  if not sourceID then return nil end

  local kind=type(sourceKind)=="string" and string.lower(sourceKind) or ""
  if kind=="creature" or kind=="unit" then
    if self.entranceCreatures[sourceID] then return "entrance" end
    if self.interiorCreatures[sourceID] then return "interior" end
    return nil
  end

  if kind=="gameobject" or kind=="object" then
    local shared=self.sharedObjectPoints[sourceID]
    if shared then
      local key=PointKey(x,y)
      if key and shared.entrance[key] then return "entrance" end
      if key and shared.interior[key] then return "interior" end
      return nil
    end
    if self.entranceObjects[sourceID] then return "entrance" end
    if self.interiorObjects[sourceID] then return "interior" end
    return nil
  end

  if kind=="areatrigger" then
    if self.entranceAreaTriggers[sourceID] then return "entrance" end
    if self.interiorAreaTriggers[sourceID] then return "interior" end
    return nil
  end

  return nil
end

function G:GetAnySourceContext(sourceID,x,y)
  sourceID=tonumber(sourceID)
  if not sourceID then return nil end

  local shared=self.sharedObjectPoints[sourceID]
  if shared then
    local key=PointKey(x,y)
    if key and shared.entrance[key] then return "entrance" end
    if key and shared.interior[key] then return "interior" end
    return nil
  end

  local entrance=(self.entranceCreatures[sourceID] or self.entranceObjects[sourceID]
    or self.entranceAreaTriggers[sourceID]) and true or false
  local interior=(self.interiorCreatures[sourceID] or self.interiorObjects[sourceID]
    or self.interiorAreaTriggers[sourceID]) and true or false
  if entrance and not interior then return "entrance" end
  if interior and not entrance then return "interior" end
  return nil
end

function G:NodeAllowed(node,context,x,y)
  if context~="entrance" and context~="interior" then return false end
  if not node then return false end

  -- Most source IDs belong to exactly one Gnomeregan context, so the source
  -- identity alone is enough. Mechanical Mailbox (144112) is the one proven
  -- shared source and must be resolved from the individual prepared/rendered
  -- coordinate instead. With no coordinate yet, allow the node to reach the
  -- point-level filter rather than hiding the source outright.
  local shared=self.sharedObjectPoints[tonumber(node.sourceID)]
  if shared and (x==nil or y==nil) then return true end
  return self:GetSourceContext(node.sourceKind,node.sourceID,x,y)==context
end

function G:ItemAreaAllowed(area,context)
  if context~="entrance" and context~="interior" then return false end
  if not area then return false end

  local found=false
  local _,source
  for _,source in pairs(area.sourceList or {}) do
    local sourceContext=self:GetAnySourceContext(source and source.id,area.x,area.y)
    if not sourceContext or sourceContext~=context then return false end
    found=true
  end
  return found
end
