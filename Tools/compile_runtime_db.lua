-- Questie-Octo build-time runtime database compiler.
-- Run from the addon root with texlua/lua. The generated files contain the
-- already-merged base + Turtle + Octo + enrichment state so players do not
-- parse both source databases or perform the merge during login/reload.

if not table.getn then table.getn=function(t) return #t end end
QuestieOcto = QuestieOcto or {}

local function load(path)
  local f,err=loadfile(path)
  if not f then error(err) end
  return f()
end

load("Data/pfDB/init.lua")
local core={"items","units","objects","refloot","quests-itemreq","quests","zones","minimap","areatrigger","meta"}
for _,name in ipairs(core) do load("Data/pfDB/"..name..".lua") end
local en={"items","units","objects","quests","zones","professions"}
for _,name in ipairs(en) do load("Data/pfDB/enUS/"..name..".lua") end
local turtle={"items","units","objects","refloot","quests-itemreq","quests","patches","zones","minimap","areatrigger","meta"}
for _,name in ipairs(turtle) do load("Data/pfDB/"..name.."-turtle.lua") end
for _,name in ipairs(en) do load("Data/pfDB/enUS/"..name.."-turtle.lua") end
load("Data/pfDB/overwrites-octo.lua")
load("Data/PvPQuestTypes.lua")
load("Data/EliteQuestTypes.lua")
load("Data/pfDB/enrichment.lua")
load("Data/ScriptedEncounters.lua")

local DATASETS={"items","quests","quests-itemreq","objects","units","zones","professions","areatrigger","refloot","minimap","meta"}
local TEXT_DATASETS={"items","quests","objects","units","zones","professions"}
local FIELD_MERGE={items=true,quests=true,objects=true,units=true}

local function merge(target,patch,mode)
  if not target or not patch then return end
  for key,value in pairs(patch) do
    if type(value)=="string" and value=="_" then
      target[key]=nil
    elseif (mode=="fields" or mode=="locale") and type(value)=="table" and type(target[key])=="table" then
      local base=target[key]
      for field,fieldValue in pairs(value) do
        if type(fieldValue)=="string" and fieldValue=="_" then base[field]=nil else base[field]=fieldValue end
      end
    else
      target[key]=value
    end
  end
end

for _,name in ipairs(DATASETS) do
  local bucket=pfDB[name]
  if bucket and bucket["data-turtle"] and bucket["data"] then
    merge(bucket["data"],bucket["data-turtle"],FIELD_MERGE[name] and "fields" or "replace")
  end
end
for _,name in ipairs(TEXT_DATASETS) do
  local bucket=pfDB[name]
  if bucket then merge(bucket.enUS,bucket["enUS-turtle"],"locale") end
end
merge(pfDB.minimap,pfDB["minimap-turtle"],"replace")
merge(pfDB.meta,pfDB["meta-turtle"],"replace")

if not QuestieOcto.Enrichment:Apply() then error("enrichment failed") end

-- Final runtime aliases. Source/patch tables are intentionally not serialized.
for _,name in ipairs(TEXT_DATASETS) do
  local bucket=pfDB[name]
  if bucket then bucket.loc=bucket.enUS end
end

local function sortedKeys(t)
  local keys={}
  for k in pairs(t or {}) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)
    local ta,tb=type(a),type(b)
    if ta==tb then
      if ta=="number" or ta=="string" then return a<b end
      return tostring(a)<tostring(b)
    end
    if ta=="number" then return true end
    if tb=="number" then return false end
    if ta=="string" then return true end
    return false
  end)
  return keys
end

local function isArray(t)
  local n=0
  for k in pairs(t) do
    if type(k)~="number" or k<1 or k~=math.floor(k) then return false,0 end
    if k>n then n=k end
  end
  for i=1,n do if rawget(t,i)==nil then return false,0 end end
  return true,n
end

local function writeValue(f,v,depth,prettyDepth)
  depth=depth or 0
  prettyDepth=prettyDepth or 0
  local typ=type(v)
  if typ=="nil" then f:write("nil")
  elseif typ=="boolean" or typ=="number" then f:write(tostring(v))
  elseif typ=="string" then f:write(string.format("%q",v))
  elseif typ=="table" then
    local arr,n=isArray(v)
    f:write("{")
    local multiline=depth<prettyDepth
    if multiline then f:write("\n") end
    if arr then
      for i=1,n do
        if i>1 then f:write(multiline and ",\n" or ",") end
        writeValue(f,v[i],depth+1,prettyDepth)
      end
    else
      local keys=sortedKeys(v)
      for i,k in ipairs(keys) do
        if i>1 then f:write(multiline and ",\n" or ",") end
        f:write("["); writeValue(f,k,depth+1,prettyDepth); f:write("]=")
        writeValue(f,v[k],depth+1,prettyDepth)
      end
    end
    if multiline then f:write("\n") end
    f:write("}")
  else error("unsupported value type "..typ) end
end

local header="-- GENERATED FILE - DO NOT EDIT BY HAND.\n-- Built from Questie-Octo's packaged pfQuest/Turtle/Octo source data.\n-- Regenerate with Tools/compile_runtime_db.lua.\n"
local function writeAssignment(path,lhs,value,prettyDepth)
  local f=assert(io.open(path,"wb"))
  f:write(header,lhs,"=")
  writeValue(f,value,0,prettyDepth or 1)
  f:write("\n")
  f:close()
end

-- 1.0.11+: serialize only the final records Questie-Octo can actually reach.
-- The source database remains packaged under Data/pfDB/ for provenance and
-- regeneration; this affects only the TOC-loaded runtime representation.
--
-- Reachability contract:
--   * every quest row and every quest locale row remains available;
--   * quest starter/finisher/objective entities are retained;
--   * quest item records retain every direct/reference/vendor source needed by
--     ItemStarts/Objectives, including reference-loot owners;
--   * IR interaction targets and every entity referenced by tracking meta are
--     retained;
--   * reward item names are retained even when the reward item has no other
--     quest relationship;
--   * small global tables (zones, AreaTriggers, minimap, meta) stay complete.
local neededItems,neededUnits,neededObjects,neededRefs,neededItemReq={},{},{},{},{}
local neededItemNames,neededUnitNames,neededObjectNames={},{},{}
local sourceItems={}

local function mark(set,id)
  id=tonumber(id)
  if id and id>0 then set[id]=true end
end

local function markUnit(id) mark(neededUnits,id); mark(neededUnitNames,id) end
local function markObject(id) mark(neededObjects,id); mark(neededObjectNames,id) end
local function markItem(id,wantSources)
  mark(neededItems,id); mark(neededItemNames,id)
  if wantSources then mark(sourceItems,id) end
end

local function markArray(setter,values,...)
  for _,id in pairs(values or {}) do setter(id,...) end
end

-- All quests remain runtime-authoritative. Mark every entity relationship that
-- QuestModel and the map/tracker presentation can expose.
for questID,q in pairs(pfDB.quests.data or {}) do
  local start=q and q.start or nil
  local finish=q and q["end"] or nil
  local obj=q and q.obj or nil

  markArray(markUnit,start and start.U)
  markArray(markObject,start and start.O)
  markArray(markItem,start and start.I,true)

  markArray(markUnit,finish and finish.U)
  markArray(markObject,finish and finish.O)

  markArray(markUnit,obj and obj.U)
  markArray(markObject,obj and obj.O)
  markArray(markItem,obj and obj.I,true)
  markArray(markItem,obj and obj.IR,false)

  -- IR relationships map an interaction item to signed creature/object targets.
  for _,itemID in pairs(obj and obj.IR or {}) do
    itemID=tonumber(itemID)
    if itemID and itemID>0 then
      neededItemReq[itemID]=true
      local req=pfDB["quests-itemreq"].data[itemID]
      for signedID in pairs(req or {}) do
        signedID=tonumber(signedID)
        if signedID and signedID<0 then markObject(math.abs(signedID))
        elseif signedID and signedID>0 then markUnit(signedID) end
      end
    end
  end
end

-- Preserve the complete creature table. Unlike items/objects, creatures have a
-- public manual diagnostic (`/qo creature <id>`) and can also arrive from live
-- ClassicAPI objective IDs before a static relationship has been visited. The
-- creature table is therefore part of the diagnostic/live-ID contract rather
-- than a safe reachability-pruning target. Items/objects remain pruned below.
for unitID in pairs(pfDB.units.data or {}) do markUnit(unitID) end

-- Presentation-only actionable source corrections that intentionally differ
-- from the formal quest objective entity. These are already covered by the full
-- creature retention above, but keep them documented beside the build contract.
markUnit(2164) -- Plagued Lands: Rabid Thistle Bear source for captured 11836
markUnit(8519) -- Poisoned Water: Blighted Surge guidance for item 17309
markObject(2010824) -- Attack from the Inside: Grain Sack -> hidden credit 60323
markObject(2010834) -- A Cannon's Misfortune: Blast Powder Keg -> hidden credit 60328
markUnit(61512) -- Wisdom of Ur: Dreamwind dialogue -> hidden credit 60056

-- Resolve every source relation that ItemStarts/Objectives can traverse.
for itemID in pairs(sourceItems) do
  local item=pfDB.items.data[itemID]
  if item then
    for unitID in pairs(item.U or {}) do markUnit(unitID) end
    for objectID in pairs(item.O or {}) do markObject(objectID) end
    for unitID in pairs(item.V or {}) do markUnit(unitID) end
    for refID in pairs(item.R or {}) do
      refID=tonumber(refID)
      if refID and refID>0 then
        neededRefs[refID]=true
        local ref=pfDB.refloot.data[refID]
        for unitID in pairs(ref and ref.U or {}) do markUnit(unitID) end
        for objectID in pairs(ref and ref.O or {}) do markObject(objectID) end
      end
    end
  end
end

-- Tracking/service/rare metadata is intentionally kept complete. Retain any
-- entity it names so present and future enabled service toggles never point at
-- a pruned record. Some meta IDs are signed object IDs, hence abs().
for _,bucket in pairs(pfDB.meta or {}) do
  if type(bucket)=="table" then
    for rawID in pairs(bucket) do
      local id=math.abs(tonumber(rawID) or 0)
      if id>0 then
        if pfDB.units.data[id] then markUnit(id) end
        if pfDB.objects.data[id] then markObject(id) end
      end
    end
  end
end

-- Quest browser rewards use pfDB item names as the immediate display fallback.
-- Keep those names even if the item has no starter/objective relationship.
load("Data/QuestRewards.lua")
for _,reward in pairs(QuestieOcto.QuestRewardsData or {}) do
  for _,entry in pairs(reward.items or {}) do mark(neededItemNames,entry[1]) end
  for _,entry in pairs(reward.choices or {}) do mark(neededItemNames,entry[1]) end
end
QuestieOcto.QuestRewardsData=nil

local function subset(source,set)
  local out={}
  for id in pairs(set or {}) do
    if source and source[id]~=nil then out[id]=source[id] end
  end
  return out
end

local runtimeItems=subset(pfDB.items.data,neededItems)
local runtimeUnits=subset(pfDB.units.data,neededUnits)
local runtimeObjects=subset(pfDB.objects.data,neededObjects)
local runtimeRefs=subset(pfDB.refloot.data,neededRefs)
local runtimeItemReq=subset(pfDB["quests-itemreq"].data,neededItemReq)

writeAssignment("Data/runtime/quests.lua",'QuestieOcto.RuntimePFDB["quests"]["data"]',pfDB.quests.data)
writeAssignment("Data/runtime/items.lua",'QuestieOcto.RuntimePFDB["items"]["data"]',runtimeItems)
writeAssignment("Data/runtime/units.lua",'QuestieOcto.RuntimePFDB["units"]["data"]',runtimeUnits)
writeAssignment("Data/runtime/objects.lua",'QuestieOcto.RuntimePFDB["objects"]["data"]',runtimeObjects)
writeAssignment("Data/runtime/refloot.lua",'QuestieOcto.RuntimePFDB["refloot"]["data"]',runtimeRefs)
writeAssignment("Data/runtime/quests-itemreq.lua",'QuestieOcto.RuntimePFDB["quests-itemreq"]["data"]',runtimeItemReq)
writeAssignment("Data/runtime/zones.lua",'QuestieOcto.RuntimePFDB["zones"]["data"]',pfDB.zones.data)
writeAssignment("Data/runtime/areatrigger.lua",'QuestieOcto.RuntimePFDB["areatrigger"]["data"]',pfDB.areatrigger.data)
writeAssignment("Data/runtime/minimap.lua",'QuestieOcto.RuntimePFDB["minimap"]',pfDB.minimap)
writeAssignment("Data/runtime/meta.lua",'QuestieOcto.RuntimePFDB["meta"]',pfDB.meta)

local locales={
  quests=pfDB.quests.enUS or {},
  zones=pfDB.zones.enUS or {},
  professions=pfDB.professions.enUS or {},
  items=subset(pfDB.items.enUS,neededItemNames),
  units=subset(pfDB.units.enUS,neededUnitNames),
  objects=subset(pfDB.objects.enUS,neededObjectNames),
}
writeAssignment("Data/runtime/enUS.lua",'QuestieOcto.RuntimeLocales',locales,2)

local questIDs=sortedKeys(pfDB.quests.data)
writeAssignment("Data/runtime/quest-ids.lua",'QuestieOcto.RuntimeQuestIDs',questIDs)

-- Build the same starter/source map candidate index as Map/CandidateIndex.lua,
-- using the pruned runtime entity tables to prove the generated runtime still
-- contains every source required by the candidate algorithm.
local byMap={}
local function addMap(mapID,questID)
  mapID=tonumber(mapID)
  if not mapID then return end
  local bucket=byMap[mapID]
  if not bucket then bucket={}; byMap[mapID]=bucket end
  bucket[questID]=true
end
local function indexCoords(coords,questID)
  local seen={}
  for _,coord in pairs(coords or {}) do
    if type(coord)=="table" and tonumber(coord[3]) then
      local mapID=tonumber(coord[3])
      if not seen[mapID] then seen[mapID]=true; addMap(mapID,questID) end
    end
  end
end
for _,questID in ipairs(questIDs) do
  local q=pfDB.quests.data[questID]
  local start=q and q.start or nil
  for _,id in pairs(start and start.U or {}) do
    if questID==3861 and tonumber(id)==620 then
      indexCoords({{55.6,30.9,40,300}},questID)
    else
      local coords=runtimeUnits[id] and runtimeUnits[id].coords or nil
      if not coords or not next(coords) then
        local scripted=QuestieOcto.ScriptedEncounterData and QuestieOcto.ScriptedEncounterData[tonumber(id)] or nil
        if scripted and (not scripted.roles or scripted.roles.available) then
          coords=scripted.coords or coords
        end
      end
      indexCoords(coords,questID)
    end
  end
  for _,id in pairs(start and start.O or {}) do indexCoords(runtimeObjects[id] and runtimeObjects[id].coords,questID) end
  for _,itemID in pairs(start and start.I or {}) do
    local item=runtimeItems[itemID]
    if item then
      for id in pairs(item.U or {}) do indexCoords(runtimeUnits[id] and runtimeUnits[id].coords,questID) end
      for id in pairs(item.O or {}) do indexCoords(runtimeObjects[id] and runtimeObjects[id].coords,questID) end
    end
  end
end
local candidateArrays={}
local maps=sortedKeys(byMap)
local links=0
for _,mapID in ipairs(maps) do
  local ids=sortedKeys(byMap[mapID]); candidateArrays[mapID]=ids; links=links+#ids
end
writeAssignment("Data/runtime/map-candidates.lua",'QuestieOcto.RuntimeMapCandidateIndex',candidateArrays)
writeAssignment("Data/runtime/runtime-stats.lua",'QuestieOcto.RuntimeDatabaseStats',{
  quests=#questIDs,maps=#maps,links=links,
  items=#sortedKeys(runtimeItems),units=#sortedKeys(runtimeUnits),objects=#sortedKeys(runtimeObjects),
  refloot=#sortedKeys(runtimeRefs),itemreq=#sortedKeys(runtimeItemReq),
  itemNames=#sortedKeys(locales.items),unitNames=#sortedKeys(locales.units),objectNames=#sortedKeys(locales.objects),
  pruned=true,
})

local init=assert(io.open("Data/runtime/init.lua","wb"))
init:write([[-- GENERATED RUNTIME DATABASE INITIALIZER.
-- Release builds keep the compiled DB private so pfQuest-family addons cannot
-- replace or clear Questie-Octo's runtime state through the shared pfDB global.
QuestieOcto.RuntimePFDB = {
  ["areatrigger"]={data={}}, ["items"]={data={},enUS={}}, ["meta"]={}, ["minimap"]={},
  ["objects"]={data={},enUS={}}, ["professions"]={enUS={}}, ["quests"]={data={},enUS={}},
  ["quests-itemreq"]={data={}}, ["refloot"]={data={}}, ["units"]={data={},enUS={}}, ["zones"]={data={},enUS={}},
}
QuestieOcto.RuntimePFDB["octo-compiled-runtime"]=true
]])
init:close()

local finalize=assert(io.open("Data/runtime/finalize.lua","wb"))
finalize:write([[-- GENERATED RUNTIME DATABASE FINALIZER.
local db=QuestieOcto.RuntimePFDB
local L=QuestieOcto.RuntimeLocales or {}
if db then
  for _,name in pairs({"items","quests","objects","units","zones","professions"}) do
    if db[name] then
      db[name].enUS=L[name] or {}
      db[name].loc=db[name].enUS
    end
  end
  db["octo-enrichment-complete"]=true
end
QuestieOcto.RuntimeLocales=nil
]])
finalize:close()

print("compiled quests="..#questIDs.." maps="..#maps.." links="..links)
