-- Questie-Octo shared entrance/interior instance-map compatibility.
--
-- Several current Turtle/Octo WorldMapArea rows deliberately reuse one
-- AreaTable ID for two selectable maps: an outdoor entrance/detail map and the
-- actual dungeon/raid interior. The runtime database remains keyed by the
-- stable AreaTable ID, so split only these proven collisions at presentation
-- time. Source IDs that legitimately exist in both contexts are resolved from
-- their individual one-decimal runtime coordinates.
--
-- Audited against the current client WorldMapArea.dbc and current server spawn
-- data on 2026-09-05. Gnomeregan (721) and Karazhan (3457) retain their
-- dedicated modules; this module covers the five remaining collisions.

QuestieOcto.SharedInstanceContext = QuestieOcto.SharedInstanceContext or {}
local S = QuestieOcto.SharedInstanceContext

local function AddIDs(target,list)
  local _,id
  for _,id in pairs(list or {}) do target[tonumber(id)]=true end
end

local function ContextKey(areaID,side)
  return tostring(tonumber(areaID) or 0)..":"..tostring(side or "")
end

local function ContextParts(context)
  if type(context)~="string" then return nil,nil end
  local _,_,area,side=string.find(context,"^(%d+):(%a+)$")
  return tonumber(area),side
end

local function PointKey(x,y)
  x=tonumber(x); y=tonumber(y)
  if not x or not y then return nil end
  return string.format("%.1f:%.1f",x,y)
end

local function NormalizeTexture(textureName)
  if type(textureName)~="string" or textureName=="" then return nil end
  local value=string.lower(textureName)
  return string.gsub(value,"/","\\")
end

S.definitions={}

do -- Wailing Caverns (718)
  local D={
    areaID=718,
    entranceServerMapID=1,
    interiorServerMapID=43,
    entranceTexture="wailingcavernsentrance",
    interiorTexture="wailingcaverns",
    entranceMinimapWidth=572.77991,
    entranceMinimapHeight=381.84998,
    interiorMinimapWidth=1170.00000,
    interiorMinimapHeight=785.00000,
    entranceCreatures={}, interiorCreatures={},
    entranceObjects={}, interiorObjects={},
    entranceAreaTriggers={}, interiorAreaTriggers={},
    sharedPoints={ creature={}, object={} },
  }
  AddIDs(D.entranceCreatures,{
      3242,3246,3255,3273,3415,3630,3631,3632,3633,3634,3638,3655,
      3672,4166,5767,5768,5783,5784,8418,12296
    })
  AddIDs(D.interiorCreatures,{
      2914,3636,3637,3640,3653,3669,3670,3671,3673,3674,3678,3679,
      3840,5048,5053,5055,5056,5755,5756,5761,5775,5912,8886,61964,
      61965,61966,61967,61968
    })
  AddIDs(D.entranceObjects,{
      1617,1620,1621,3705,178884
    })
  AddIDs(D.interiorObjects,{
      1619,1732,2041,75293,180055
    })
  AddIDs(D.entranceAreaTriggers,{
      228
    })
  AddIDs(D.interiorAreaTriggers,{
      226,3766
    })
  AddIDs(D.entranceCreatures,{
      3641,3835,61218
    })
  AddIDs(D.interiorCreatures,{
      3641,3835,61218
    })
  AddIDs(D.entranceObjects,{
      1622,1624,1731,13891
    })
  AddIDs(D.interiorObjects,{
      1622,1624,1731,13891
    })
  D.sharedPoints.creature[3641]={
    entrance={ ["37.0:25.3"]=true, ["37.2:22.8"]=true, ["58.1:41.1"]=true, ["60.0:44.7"]=true, ["61.1:36.0"]=true, ["64.3:42.3"]=true, ["65.7:36.1"]=true, ["69.0:41.2"]=true },
    interior={ ["77.7:93.5"]=true, ["77.7:94.9"]=true },
  }
  D.sharedPoints.creature[3835]={
    entrance={ ["24.5:47.9"]=true, ["25.7:58.6"]=true, ["28.5:53.9"]=true, ["33.6:20.8"]=true, ["53.0:19.5"]=true, ["57.0:53.2"]=true, ["61.8:20.4"]=true, ["64.1:58.3"]=true, ["69.1:13.0"]=true, ["75.9:47.2"]=true, ["80.1:27.6"]=true },
    interior={ ["36.4:36.0"]=true, ["46.0:29.6"]=true, ["50.2:37.8"]=true, ["55.4:30.7"]=true, ["63.2:46.8"]=true, ["63.9:32.6"]=true, ["65.5:47.3"]=true, ["66.3:85.9"]=true, ["66.5:52.2"]=true, ["67.1:59.4"]=true, ["68.0:14.7"]=true, ["68.2:62.2"]=true, ["68.3:57.4"]=true, ["70.6:16.2"]=true, ["76.2:94.1"]=true, ["79.4:92.7"]=true, ["84.2:81.5"]=true, ["84.9:78.7"]=true, ["86.7:78.4"]=true },
  }
  D.sharedPoints.creature[61218]={
    entrance={ ["22.9:89.5"]=true, ["39.0:63.3"]=true },
    interior={ ["86.0:77.4"]=true },
  }
  D.sharedPoints.object[1622]={
    entrance={ ["12.9:88.1"]=true, ["19.5:42.7"]=true, ["19.8:75.0"]=true, ["21.8:27.2"]=true, ["30.6:93.1"]=true, ["35.1:52.7"]=true, ["39.8:64.7"]=true, ["59.0:81.0"]=true, ["69.3:64.0"]=true, ["8.2:86.8"]=true, ["81.4:33.1"]=true },
    interior={ ["77.4:34.6"]=true },
  }
  D.sharedPoints.object[1624]={
    entrance={ ["28.4:21.4"]=true, ["28.5:23.7"]=true, ["52.2:20.0"]=true, ["56.9:60.0"]=true, ["62.7:24.7"]=true, ["70.9:15.8"]=true, ["76.4:50.9"]=true, ["78.9:30.5"]=true },
    interior={ ["28.1:22.7"]=true, ["89.7:36.3"]=true },
  }
  D.sharedPoints.object[1731]={
    entrance={ ["22.1:29.6"]=true, ["31.0:62.5"]=true, ["37.6:27.1"]=true, ["38.1:56.4"]=true, ["55.7:34.9"]=true, ["76.3:1.1"]=true, ["83.3:37.4"]=true, ["86.1:22.9"]=true },
    interior={ ["32.4:47.9"]=true, ["79.1:38.6"]=true, ["83.8:50.3"]=true },
  }
  D.sharedPoints.object[13891]={
    entrance={ ["18.4:48.2"]=true, ["25.2:29.1"]=true, ["27.7:64.1"]=true, ["33.1:79.0"]=true, ["35.8:59.9"]=true, ["40.0:28.8"]=true, ["50.4:32.2"]=true, ["52.7:48.7"]=true, ["53.4:19.8"]=true, ["60.4:14.1"]=true, ["60.8:56.7"]=true, ["61.0:23.2"]=true, ["74.5:20.3"]=true, ["78.0:54.2"]=true, ["78.5:42.6"]=true },
    interior={ ["27.9:32.0"]=true, ["28.2:19.6"]=true, ["31.4:39.6"]=true, ["32.3:27.0"]=true, ["44.0:21.5"]=true, ["44.6:31.4"]=true, ["55.0:23.8"]=true, ["62.1:33.3"]=true, ["62.2:35.6"]=true, ["63.8:73.3"]=true, ["65.0:52.4"]=true, ["65.9:14.5"]=true, ["67.6:86.0"]=true, ["68.9:23.9"]=true, ["70.8:41.6"]=true, ["71.0:77.5"]=true, ["71.1:27.4"]=true, ["71.8:94.9"]=true, ["71.9:55.8"]=true, ["76.1:76.1"]=true, ["76.2:50.1"]=true, ["80.0:46.1"]=true, ["80.2:57.0"]=true, ["81.7:21.3"]=true, ["82.8:89.7"]=true, ["84.4:76.4"]=true, ["86.7:49.0"]=true, ["90.1:39.4"]=true, ["91.6:32.0"]=true, ["94.8:64.8"]=true, ["96.4:48.3"]=true },
  }
  S.definitions[D.areaID]=D
end

do -- Uldaman (1337)
  local D={
    areaID=1337,
    entranceServerMapID=0,
    interiorServerMapID=70,
    entranceTexture="uldamanentrance",
    interiorTexture="uldaman",
    entranceMinimapWidth=563.31006,
    entranceMinimapHeight=376.09961,
    interiorMinimapWidth=893.67000,
    interiorMinimapHeight=595.78000,
    entranceCreatures={}, interiorCreatures={},
    entranceObjects={}, interiorObjects={},
    entranceAreaTriggers={}, interiorAreaTriggers={},
    sharedPoints={ creature={}, object={} },
  }
  AddIDs(D.entranceCreatures,{
      1161,1162,1163,1164,1166,1197,1205,1206,1207,2723,2742,2743,
      2909,2932,4844,4845,4846,4856,4872,7057,60907,60908,60920,60921,
      73102
    })
  AddIDs(D.interiorCreatures,{
      2748,4847,4848,4849,4850,4852,4853,4854,4855,4857,4860,4861,
      4863,6906,6907,6908,6910,6912,7011,7012,7022,7023,7030,7076,
      7077,7078,7172,7175,7206,7228,7290,7291,7309,7320,7321,7396,
      7397,7405,10120,11073,15384
    })
  AddIDs(D.entranceObjects,{
      1617,1731,1732,1734,2046,2743,2857,106319,124388,124389,126260,142140,
      178833,179490
    })
  AddIDs(D.interiorObjects,{
      19903,113757,125477,131474,131978,142088,2010828
    })
  AddIDs(D.entranceAreaTriggers,{
      286
    })
  AddIDs(D.interiorAreaTriggers,{
      288,822,882
    })
  AddIDs(D.entranceCreatures,{
      4851
    })
  AddIDs(D.interiorCreatures,{
      4851
    })
  AddIDs(D.entranceObjects,{
      1735,2040,126049,128293
    })
  AddIDs(D.interiorObjects,{
      1735,2040,126049,128293
    })
  D.sharedPoints.creature[4851]={
    entrance={ ["24.9:52.9"]=true, ["29.5:61.7"]=true, ["29.6:56.9"]=true, ["30.2:63.6"]=true, ["31.1:80.3"]=true, ["33.8:82.9"]=true, ["35.6:83.5"]=true, ["44.0:64.0"]=true, ["45.9:61.6"]=true, ["48.5:59.5"]=true },
    interior={ ["52.3:72.6"]=true, ["53.2:64.3"]=true, ["53.3:80.6"]=true, ["53.9:81.6"]=true, ["56.1:63.9"]=true, ["56.7:66.4"]=true, ["56.8:63.5"]=true, ["56.8:73.2"]=true, ["56.9:80.7"]=true, ["57.7:73.0"]=true, ["58.6:69.9"]=true, ["62.1:75.3"]=true, ["62.2:70.0"]=true, ["62.3:63.6"]=true, ["62.9:82.5"]=true, ["63.0:61.9"]=true, ["63.2:81.4"]=true, ["65.4:63.9"]=true, ["65.5:81.3"]=true },
  }
  D.sharedPoints.object[1735]={
    entrance={ ["29.4:46.6"]=true, ["51.8:61.9"]=true, ["52.3:34.5"]=true, ["59.1:44.6"]=true, ["61.9:37.4"]=true, ["84.7:90.1"]=true, ["88.8:62.0"]=true },
    interior={ ["35.6:38.3"]=true, ["61.6:64.5"]=true },
  }
  D.sharedPoints.object[2040]={
    entrance={ ["22.8:52.3"]=true, ["51.8:51.5"]=true },
    interior={ ["48.8:29.9"]=true, ["56.3:94.8"]=true },
  }
  D.sharedPoints.object[126049]={
    entrance={ ["31.7:90.7"]=true, ["41.3:38.2"]=true, ["47.3:50.3"]=true, ["48.3:28.8"]=true, ["50.2:58.1"]=true },
    interior={ ["29.2:56.0"]=true, ["34.4:50.3"]=true, ["36.1:24.7"]=true, ["45.7:34.0"]=true, ["46.4:53.2"]=true, ["48.2:68.5"]=true },
  }
  D.sharedPoints.object[128293]={
    entrance={ ["29.2:44.0"]=true, ["47.3:50.3"]=true, ["48.3:28.8"]=true, ["50.2:58.1"]=true, ["61.1:29.4"]=true, ["62.5:49.2"]=true },
    interior={ ["38.4:61.9"]=true, ["60.9:94.5"]=true },
  }
  S.definitions[D.areaID]=D
end

do -- Maraudon (2100)
  local D={
    areaID=2100,
    entranceServerMapID=1,
    interiorServerMapID=349,
    entranceTexture="maraudonentrance",
    interiorTexture="maraudon",
    entranceMinimapWidth=824.00000,
    entranceMinimapHeight=550.00000,
    interiorMinimapWidth=2112.09006,
    interiorMinimapHeight=1410.89001,
    entranceCreatures={}, interiorCreatures={},
    entranceObjects={}, interiorObjects={},
    entranceAreaTriggers={}, interiorAreaTriggers={},
    sharedPoints={ creature={}, object={} },
  }
  AddIDs(D.entranceCreatures,{
      4654,4655,4656,4657,4658,4659,11105,11106,11578,11624,11685,11686,
      11687,11688,11777,11778,11781,11782,11785,11786,11787,11788,12030,12033,
      12239,12240,12241,12277,12338,13697,13718,15760
    })
  AddIDs(D.interiorCreatures,{
      2914,4076,6145,11783,11784,11789,11790,11791,11792,11793,11794,12201,
      12203,12206,12207,12216,12217,12218,12219,12220,12221,12222,12223,12224,
      12225,12236,12237,12242,12243,12258,13141,13142,13282,13321,13323,13533,
      13596,13599,13601,13716,13743,15556
    })
  AddIDs(D.entranceObjects,{
      1622,1735,2857,138497,178827,178907,179895
    })
  AddIDs(D.interiorObjects,{
      1734,2045,142143
    })
  AddIDs(D.entranceAreaTriggers,{
      2267,3133,3134
    })
  AddIDs(D.interiorAreaTriggers,{
      3126,3131
    })
  AddIDs(D.entranceObjects,{
      2040,2047,142144
    })
  AddIDs(D.interiorObjects,{
      2040,2047,142144
    })
  D.sharedPoints.object[2040]={
    entrance={ ["23.6:35.5"]=true, ["34.3:54.2"]=true, ["34.8:32.8"]=true, ["35.0:25.1"]=true, ["35.5:37.1"]=true, ["36.0:56.7"]=true, ["37.5:44.1"]=true, ["39.2:41.8"]=true, ["40.2:36.2"]=true, ["43.7:7.1"]=true, ["45.7:57.5"]=true, ["47.5:42.4"]=true, ["49.4:74.0"]=true, ["49.6:72.9"]=true, ["51.5:2.7"]=true, ["55.6:54.5"]=true, ["56.0:8.7"]=true, ["57.3:76.2"]=true, ["65.7:46.5"]=true, ["73.6:48.3"]=true },
    interior={ ["22.4:62.4"]=true, ["33.2:18.2"]=true, ["42.2:60.3"]=true },
  }
  D.sharedPoints.object[2047]={
    entrance={ ["34.2:35.3"]=true, ["50.5:39.5"]=true },
    interior={ ["41.1:69.0"]=true },
  }
  D.sharedPoints.object[142144]={
    entrance={ ["25.8:32.7"]=true, ["28.7:18.8"]=true, ["30.4:65.3"]=true, ["33.4:17.2"]=true, ["34.5:13.3"]=true, ["35.5:37.1"]=true, ["39.0:76.4"]=true, ["40.0:50.0"]=true, ["40.3:48.9"]=true, ["41.7:63.1"]=true, ["51.1:63.3"]=true, ["51.7:60.2"]=true },
    interior={ ["11.2:60.4"]=true, ["18.9:28.2"]=true, ["25.9:22.7"]=true, ["28.4:33.2"]=true, ["35.7:95.4"]=true, ["36.8:19.4"]=true, ["40.8:41.2"]=true, ["47.1:34.3"]=true },
  }
  S.definitions[D.areaID]=D
end

do -- Dire Maul (2557)
  local D={
    areaID=2557,
    entranceServerMapID=1,
    interiorServerMapID=429,
    entranceTexture="diremaulentrance",
    interiorTexture="diremaul",
    entranceMinimapWidth=1324.00000,
    entranceMinimapHeight=869.00000,
    interiorMinimapWidth=1919.00000,
    interiorMinimapHeight=1250.00000,
    entranceCreatures={}, interiorCreatures={},
    entranceObjects={}, interiorObjects={},
    entranceAreaTriggers={}, interiorAreaTriggers={},
    sharedPoints={ creature={}, object={} },
  }
  AddIDs(D.entranceCreatures,{
      2914,5262,5274,5276,5288,5296,5297,5299,7725,7726,7727,11440,
      11442,11443,11447,11497,11498,12418,14395,15587,61598
    })
  AddIDs(D.interiorCreatures,{
      11441,11444,11445,11446,11448,11450,11501,13021,13036,13160,14321,14322,
      14323,14324,14325,14326,14338,14386
    })
  AddIDs(D.entranceObjects,{
      324,2040,2041,2043,2046,2047,142140,142142,176583,178225,2010869,2020095
    })
  AddIDs(D.interiorObjects,{
      153469,179485,179499,179501,179548,179564,181346,300400,300401,300402,300403,300404,
      300405
    })
  AddIDs(D.entranceAreaTriggers,{
      3183,3184,3186,3187,3189
    })
  AddIDs(D.interiorAreaTriggers,{
      3193,3506,3507,3508,3509
    })
  AddIDs(D.entranceObjects,{
      175404
    })
  AddIDs(D.interiorObjects,{
      175404
    })
  D.sharedPoints.object[175404]={
    entrance={ ["84.4:24.3"]=true, ["88.5:21.1"]=true },
    interior={ ["66.4:55.3"]=true, ["66.4:58.5"]=true, ["66.5:56.7"]=true, ["67.4:54.0"]=true, ["67.4:54.8"]=true, ["68.6:53.3"]=true, ["69.3:54.2"]=true },
  }
  S.definitions[D.areaID]=D
end

do -- Timbermaw Hold (5640)
  local D={
    areaID=5640,
    entranceServerMapID=1,
    interiorServerMapID=819,
    entranceTexture="timbermawentrance",
    interiorTexture="timbermaw",
    entranceMinimapWidth=1347.00000,
    entranceMinimapHeight=971.00000,
    interiorMinimapWidth=1425.00000,
    interiorMinimapHeight=962.00000,
    entranceCreatures={}, interiorCreatures={},
    entranceObjects={}, interiorObjects={},
    entranceAreaTriggers={}, interiorAreaTriggers={},
    sharedPoints={ creature={}, object={} },
  }
  AddIDs(D.entranceCreatures,{})
  AddIDs(D.interiorCreatures,{
      62867,62870,62871,62872,62873,62875,62876,62877,62878,62879,62880,62881,
      62882,62883,62884,62885,62934,62935,62936,62938,62940,62941,62942,62946
    })
  AddIDs(D.entranceObjects,{})
  AddIDs(D.interiorObjects,{})
  AddIDs(D.entranceAreaTriggers,{})
  AddIDs(D.interiorAreaTriggers,{})
  S.definitions[D.areaID]=D
end

function S:IsSharedArea(mapID)
  return self.definitions[tonumber(mapID)]~=nil
end

local function TextureMatches(value,suffix)
  if not value or not suffix then return false end
  local n=string.len(suffix)
  return string.len(value)>=n and string.sub(value,-n)==suffix
end

function S:GetDisplayedContext(mapID)
  local D=self.definitions[tonumber(mapID)]
  if not D then return nil end
  local api=QuestieOcto.API
  local texture=api and api.GetDisplayedMapTextureName and api:GetDisplayedMapTextureName() or nil
  texture=NormalizeTexture(texture)
  if TextureMatches(texture,D.entranceTexture) then return ContextKey(D.areaID,"entrance") end
  if TextureMatches(texture,D.interiorTexture) then return ContextKey(D.areaID,"interior") end
  return nil
end

function S:GetPhysicalContext(mapID)
  local D=self.definitions[tonumber(mapID)]
  if not D then return nil end
  local api=QuestieOcto.API
  local serverMapID=api and api.GetInstanceMapID and tonumber(api:GetInstanceMapID()) or nil
  if serverMapID==D.interiorServerMapID then return ContextKey(D.areaID,"interior") end
  if serverMapID==D.entranceServerMapID then return ContextKey(D.areaID,"entrance") end

  -- A shared AreaTable ID outside an instance can only refer to its entrance
  -- WorldMapArea. Inside an unknown party/raid context, fail closed instead of
  -- projecting entrance geometry onto a dungeon floor.
  if api and api.IsInDungeonOrRaid and api:IsInDungeonOrRaid() then return nil end
  return ContextKey(D.areaID,"entrance")
end

function S:GetMinimapSize(context)
  local areaID,side=ContextParts(context)
  local D=self.definitions[areaID]
  if not D then return nil,nil end
  if side=="entrance" then return D.entranceMinimapWidth,D.entranceMinimapHeight end
  if side=="interior" then return D.interiorMinimapWidth,D.interiorMinimapHeight end
  return nil,nil
end

local function SharedPointContext(D,kind,sourceID,x,y)
  local byKind=D.sharedPoints[kind]
  local shared=byKind and byKind[sourceID] or nil
  if not shared then return nil,false end
  local key=PointKey(x,y)
  if not key then return nil,true end
  if shared.entrance[key] then return "entrance",true end
  if shared.interior[key] then return "interior",true end
  return nil,true
end

local function SourceContextForDef(D,sourceKind,sourceID,x,y)
  sourceID=tonumber(sourceID)
  if not sourceID then return nil end
  local kind=type(sourceKind)=="string" and string.lower(sourceKind) or ""

  if kind=="creature" or kind=="unit" then
    local pointContext,isShared=SharedPointContext(D,"creature",sourceID,x,y)
    if isShared then return pointContext end
    if D.entranceCreatures[sourceID] then return "entrance" end
    if D.interiorCreatures[sourceID] then return "interior" end
    return nil
  end

  if kind=="gameobject" or kind=="object" then
    local pointContext,isShared=SharedPointContext(D,"object",sourceID,x,y)
    if isShared then return pointContext end
    if D.entranceObjects[sourceID] then return "entrance" end
    if D.interiorObjects[sourceID] then return "interior" end
    return nil
  end

  if kind=="areatrigger" then
    if D.entranceAreaTriggers[sourceID] then return "entrance" end
    if D.interiorAreaTriggers[sourceID] then return "interior" end
    return nil
  end

  return nil
end

function S:GetSourceContext(sourceKind,sourceID,x,y,mapID)
  local D=self.definitions[tonumber(mapID)]
  if not D then return nil end
  local side=SourceContextForDef(D,sourceKind,sourceID,x,y)
  if not side then return nil end
  return ContextKey(D.areaID,side)
end

local function AnySourceContextForDef(D,sourceID,x,y)
  sourceID=tonumber(sourceID)
  if not sourceID then return nil end

  local found=nil
  local function Consider(side)
    if not side then return true end
    if found and found~=side then return false end
    found=side
    return true
  end

  local pointContext,isShared=SharedPointContext(D,"creature",sourceID,x,y)
  if isShared then
    if not Consider(pointContext) then return nil end
  else
    if D.entranceCreatures[sourceID] and not Consider("entrance") then return nil end
    if D.interiorCreatures[sourceID] and not Consider("interior") then return nil end
  end

  pointContext,isShared=SharedPointContext(D,"object",sourceID,x,y)
  if isShared then
    if not Consider(pointContext) then return nil end
  else
    if D.entranceObjects[sourceID] and not Consider("entrance") then return nil end
    if D.interiorObjects[sourceID] and not Consider("interior") then return nil end
  end

  if D.entranceAreaTriggers[sourceID] and not Consider("entrance") then return nil end
  if D.interiorAreaTriggers[sourceID] and not Consider("interior") then return nil end
  return found
end

function S:GetAnySourceContext(sourceID,x,y,mapID)
  local D=self.definitions[tonumber(mapID)]
  if not D then return nil end
  local side=AnySourceContextForDef(D,sourceID,x,y)
  if not side then return nil end
  return ContextKey(D.areaID,side)
end

function S:NodeAllowed(node,context,x,y)
  local areaID,side=ContextParts(context)
  local D=self.definitions[areaID]
  if not D or (side~="entrance" and side~="interior") or not node then return false end

  local sourceID=tonumber(node.sourceID)
  local kind=type(node.sourceKind)=="string" and string.lower(node.sourceKind) or ""
  local pointKind=(kind=="creature" or kind=="unit") and "creature"
      or ((kind=="gameobject" or kind=="object") and "object" or nil)
  local shared=pointKind and D.sharedPoints[pointKind] and D.sharedPoints[pointKind][sourceID] or nil
  if shared and (x==nil or y==nil) then
    -- Prepared descriptors may be checked once before their individual points
    -- are expanded. Keep a proven shared source alive until the point-level
    -- pass can choose its entrance/interior coordinate.
    return true
  end

  local sourceSide=SourceContextForDef(D,node.sourceKind,node.sourceID,x,y)
  return sourceSide==side
end

function S:ItemAreaAllowed(area,context)
  local areaID,side=ContextParts(context)
  local D=self.definitions[areaID]
  if not D or (side~="entrance" and side~="interior") or not area then return false end

  local found=false
  local _,source
  for _,source in pairs(area.sourceList or {}) do
    local sourceSide=AnySourceContextForDef(D,source and source.id,area.x,area.y)
    if not sourceSide or sourceSide~=side then return false end
    found=true
  end
  return found
end
