-- Questie-Octo build-time validator for the reachability-pruned runtime DB.
-- Reconstructs the legacy final database, derives every record reachable by
-- Questie-Octo's runtime API/presentation paths, then verifies the generated
-- Data/runtime representation is lossless for that contract.
if not table.getn then table.getn=function(t) return #t end end

local function load(path)
  local f,err=loadfile(path); if not f then error(err) end; return f()
end
local function merge(target,patch,mode)
  if not target or not patch then return end
  for key,value in pairs(patch) do
    if type(value)=="string" and value=="_" then target[key]=nil
    elseif (mode=="fields" or mode=="locale") and type(value)=="table" and type(target[key])=="table" then
      for field,fieldValue in pairs(value) do
        if type(fieldValue)=="string" and fieldValue=="_" then target[key][field]=nil else target[key][field]=fieldValue end
      end
    else target[key]=value end
  end
end
local function equal(a,b,path,seen)
  local ta,tb=type(a),type(b)
  if ta~=tb then return false,path.." type "..ta.." != "..tb end
  if ta~="table" then if a~=b then return false,path.." value mismatch" end; return true end
  seen=seen or {}; if seen[a] and seen[a]==b then return true end; seen[a]=b
  for k,v in pairs(a) do
    if b[k]==nil and v~=nil then return false,path.." missing key "..tostring(k) end
    local ok,err=equal(v,b[k],path.."["..tostring(k).."]",seen); if not ok then return false,err end
  end
  for k,v in pairs(b) do if a[k]==nil and v~=nil then return false,path.." extra key "..tostring(k) end end
  return true
end
local function assertEqual(a,b,path) local ok,err=equal(a,b,path); if not ok then error(err) end end
local function count(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end
local function sortedKeys(t)
  local r={}; for k in pairs(t or {}) do r[#r+1]=k end
  table.sort(r,function(a,b)
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
  return r
end

-- Reconstruct the legacy final state.
QuestieOcto={}
load("Data/pfDB/init.lua")
for _,n in ipairs({"items","units","objects","refloot","quests-itemreq","quests","zones","minimap","areatrigger","meta"}) do load("Data/pfDB/"..n..".lua") end
for _,n in ipairs({"items","units","objects","quests","zones","professions"}) do load("Data/pfDB/enUS/"..n..".lua") end
for _,n in ipairs({"items","units","objects","refloot","quests-itemreq","quests","patches","zones","minimap","areatrigger","meta"}) do load("Data/pfDB/"..n.."-turtle.lua") end
for _,n in ipairs({"items","units","objects","quests","zones","professions"}) do load("Data/pfDB/enUS/"..n.."-turtle.lua") end
load("Data/pfDB/overwrites-octo.lua")
load("Data/PvPQuestTypes.lua")
load("Data/EliteQuestTypes.lua")
load("Data/pfDB/enrichment.lua")
local field={items=true,quests=true,objects=true,units=true}
for _,n in ipairs({"items","quests","quests-itemreq","objects","units","zones","professions","areatrigger","refloot","minimap","meta"}) do
  local b=pfDB[n]; if b and b.data and b["data-turtle"] then merge(b.data,b["data-turtle"],field[n] and "fields" or "replace") end
end
for _,n in ipairs({"items","quests","objects","units","zones","professions"}) do local b=pfDB[n]; if b then merge(b.enUS,b["enUS-turtle"],"locale") end end
merge(pfDB.minimap,pfDB["minimap-turtle"],"replace")
merge(pfDB.meta,pfDB["meta-turtle"],"replace")
assert(QuestieOcto.Enrichment:Apply())
local legacy=pfDB

-- Derive the runtime reachability contract independently from the generated DB.
local items,units,objects,refs,itemreq={},{},{},{},{}
local itemNames,unitNames,objectNames={},{},{}
local sourceItems={}
local function mark(set,id) id=tonumber(id); if id and id>0 then set[id]=true end end
local function markU(id) mark(units,id); mark(unitNames,id) end
local function markO(id) mark(objects,id); mark(objectNames,id) end
local function markI(id,sources) mark(items,id); mark(itemNames,id); if sources then mark(sourceItems,id) end end
local function each(values,fn,arg) for _,id in pairs(values or {}) do fn(id,arg) end end

for _,q in pairs(legacy.quests.data) do
  local s=q.start or {}; local e=q["end"] or {}; local o=q.obj or {}
  each(s.U,markU); each(s.O,markO); each(s.I,markI,true)
  each(e.U,markU); each(e.O,markO)
  each(o.U,markU); each(o.O,markO); each(o.I,markI,true); each(o.IR,markI,false)
  for _,iid in pairs(o.IR or {}) do
    iid=tonumber(iid); if iid then
      itemreq[iid]=true
      for signed in pairs(legacy["quests-itemreq"].data[iid] or {}) do
        signed=tonumber(signed)
        if signed and signed<0 then markO(math.abs(signed)) elseif signed and signed>0 then markU(signed) end
      end
    end
  end
end

-- Creature diagnostics/live objective IDs can query any known creature, so the
-- complete final creature table/name set is intentionally retained.
for id in pairs(legacy.units.data or {}) do markU(id) end

-- Source overrides are runtime behavior not necessarily represented by formal quest rows.
markU(2164); markU(8519); markO(2010824); markO(2010834); markU(61512)

for iid in pairs(sourceItems) do
  local r=legacy.items.data[iid] or {}
  for id in pairs(r.U or {}) do markU(id) end
  for id in pairs(r.O or {}) do markO(id) end
  for id in pairs(r.V or {}) do markU(id) end
  for rid in pairs(r.R or {}) do
    rid=tonumber(rid); if rid then
      refs[rid]=true
      local rr=legacy.refloot.data[rid] or {}
      for id in pairs(rr.U or {}) do markU(id) end
      for id in pairs(rr.O or {}) do markO(id) end
    end
  end
end

-- Every tracking-meta target stays reachable, even if its toggle is currently off.
for _,bucket in pairs(legacy.meta or {}) do
  if type(bucket)=="table" then
    for rawID in pairs(bucket) do
      local id=math.abs(tonumber(rawID) or 0)
      if id>0 then
        if legacy.units.data[id] then markU(id) end
        if legacy.objects.data[id] then markO(id) end
      end
    end
  end
end

-- Reward item names must remain immediate even before the client item cache fills.
QuestieOcto.QuestRewardsData=nil
load("Data/QuestRewards.lua")
for _,reward in pairs(QuestieOcto.QuestRewardsData or {}) do
  for _,entry in pairs(reward.items or {}) do mark(itemNames,entry[1]) end
  for _,entry in pairs(reward.choices or {}) do mark(itemNames,entry[1]) end
end

load("Data/ScriptedEncounters.lua")

-- Build the legacy candidate index before replacing pfDB.
local legacyCandidates={}
local function addMap(mapID,qid)
  mapID=tonumber(mapID); if not mapID then return end
  local b=legacyCandidates[mapID]; if not b then b={}; legacyCandidates[mapID]=b end; b[qid]=true
end
local function indexCoords(coords,qid)
  local seen={}
  for _,c in pairs(coords or {}) do if type(c)=="table" and tonumber(c[3]) and not seen[tonumber(c[3])] then seen[tonumber(c[3])]=true; addMap(c[3],qid) end end
end
for qid,q in pairs(legacy.quests.data) do
  local s=q.start or {}
  for _,id in pairs(s.U or {}) do
    if tonumber(qid)==3861 and tonumber(id)==620 then
      indexCoords({{55.6,30.9,40,300}},qid)
    else
      local coords=legacy.units.data[id] and legacy.units.data[id].coords or nil
      if not coords or not next(coords) then
        local scripted=QuestieOcto.ScriptedEncounterData and QuestieOcto.ScriptedEncounterData[tonumber(id)] or nil
        if scripted and (not scripted.roles or scripted.roles.available) then
          coords=scripted.coords or coords
        end
      end
      indexCoords(coords,qid)
    end
  end
  for _,id in pairs(s.O or {}) do indexCoords(legacy.objects.data[id] and legacy.objects.data[id].coords,qid) end
  for _,iid in pairs(s.I or {}) do
    local it=legacy.items.data[iid] or {}
    for id in pairs(it.U or {}) do indexCoords(legacy.units.data[id] and legacy.units.data[id].coords,qid) end
    for id in pairs(it.O or {}) do indexCoords(legacy.objects.data[id] and legacy.objects.data[id].coords,qid) end
  end
end
local legacyCandidateArrays={}; for mapID,b in pairs(legacyCandidates) do legacyCandidateArrays[mapID]=sortedKeys(b) end

-- Load generated pruned runtime into a fresh database.
QuestieOcto={}; pfDB=nil
for _,path in ipairs({
  "init.lua","quests.lua","items.lua","units.lua","objects.lua","refloot.lua","quests-itemreq.lua",
  "zones.lua","areatrigger.lua","minimap.lua","meta.lua","enUS.lua","quest-ids.lua","map-candidates.lua","runtime-stats.lua","finalize.lua"
}) do load("Data/runtime/"..path) end
local runtime=QuestieOcto.RuntimePFDB

-- Full-authority datasets stay recursively identical.
assertEqual(legacy.quests.data,runtime.quests.data,"quests.data")
assertEqual(legacy.zones.data,runtime.zones.data,"zones.data")
assertEqual(legacy.areatrigger.data,runtime.areatrigger.data,"areatrigger.data")
assertEqual(legacy.minimap,runtime.minimap,"minimap")
assertEqual(legacy.meta,runtime.meta,"meta")
assertEqual(legacy.quests.enUS,runtime.quests.enUS,"quests.enUS")
assertEqual(legacy.zones.enUS,runtime.zones.enUS,"zones.enUS")
assertEqual(legacy.professions.enUS,runtime.professions.enUS,"professions.enUS")
print("PASS complete quest/global datasets")

local function verifySubset(label,expected,legacyData,runtimeData)
  local expectedPresent=0
  for id in pairs(expected) do if legacyData[id]~=nil then expectedPresent=expectedPresent+1 end end
  if count(runtimeData)~=expectedPresent then error(label.." count "..count(runtimeData).." != expected-present "..expectedPresent) end
  for id in pairs(expected) do
    if legacyData[id]==nil then
      -- A relationship can legitimately name an entity/item absent from this
      -- historical pfDB family. The runtime must not invent a record for it.
      if runtimeData[id]~=nil then error(label.." unexpected generated record "..tostring(id)) end
    else
      assertEqual(legacyData[id],runtimeData[id],label.."["..tostring(id).."]")
    end
  end
  for id in pairs(runtimeData) do if not expected[id] then error(label.." extra record "..tostring(id)) end end
  print("PASS "..label.." "..count(runtimeData))
end
verifySubset("items.data",items,legacy.items.data,runtime.items.data)
verifySubset("units.data",units,legacy.units.data,runtime.units.data)
verifySubset("objects.data",objects,legacy.objects.data,runtime.objects.data)
verifySubset("refloot.data",refs,legacy.refloot.data,runtime.refloot.data)
verifySubset("quests-itemreq.data",itemreq,legacy["quests-itemreq"].data,runtime["quests-itemreq"].data)
verifySubset("items.enUS",itemNames,legacy.items.enUS,runtime.items.enUS)
verifySubset("units.enUS",unitNames,legacy.units.enUS,runtime.units.enUS)
verifySubset("objects.enUS",objectNames,legacy.objects.enUS,runtime.objects.enUS)

local ids=sortedKeys(legacy.quests.data)
assertEqual(ids,QuestieOcto.RuntimeQuestIDs,"questIDs")
assertEqual(legacyCandidateArrays,QuestieOcto.RuntimeMapCandidateIndex,"mapCandidates")
print("PASS quest IDs/candidate index "..#ids.." quests")

local stats=QuestieOcto.RuntimeDatabaseStats or {}
assert(stats.pruned==true)
assert(tonumber(stats.quests)==count(legacy.quests.data))
assert(tonumber(stats.items)==count(runtime.items.data))
assert(tonumber(stats.units)==count(runtime.units.data))
assert(tonumber(stats.objects)==count(runtime.objects.data))
assert(tonumber(stats.refloot)==count(runtime.refloot.data))
assert(tonumber(stats.itemreq)==count(runtime["quests-itemreq"].data))
assert(runtime["octo-compiled-runtime"]==true and runtime["octo-enrichment-complete"]==true)
print("PASS compiled/pruned flags and stats")
print("ALL PRUNED RUNTIME DATABASE CHECKS PASSED")
