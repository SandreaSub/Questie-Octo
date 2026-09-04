-- Questie-Octo AvailableQuests service.
-- pfQuest/Tortoise defines quest truth; Questie-Octo only presents the result.

QuestieOcto.AvailableQuests = QuestieOcto.AvailableQuests or {}
local A = QuestieOcto.AvailableQuests

A.ready=false
A.running=false
A.available={}
A.queue={}
A.pos=1
A.generation=0
A.stats={}
A.reputationCache={}
A.hardcoreCache=nil
A.dependencyIndex=A.dependencyIndex or {skill={},reputation={},hardcore={}}
A.pendingDependencyIndex=nil

local function NewStats()
  return {
    scanned=0,available=0,completed=0,active=0,disabled=0,
    level=0,prerequisite=0,exclusive=0,race=0,class=0,starterFaction=0,
    hardcore=0,skill=0,reputation=0,timed=0,event=0,repeatable=0,pvp=0,noStarter=0
  }
end

local function ResetStats()
  A.stats=NewStats()
end

local RACE_BITS={
  Human=1,Orc=2,Dwarf=4,NightElf=8,Scourge=16,
  Tauren=32,Gnome=64,Troll=128,Goblin=256,HighElf=512
}

local CLASS_BITS={
  WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,
  SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024
}

local function MaskContains(mask,flag)
  mask=tonumber(mask or 0) or 0
  flag=tonumber(flag or 0) or 0
  if mask==0 then return true end
  if flag==0 then return false end
  return math.mod(math.floor(mask/flag),2)==1
end

local function PlayerRaceBit()
  local _,token=UnitRace("player")
  if token=="BloodElf" then
    -- Turtle-derived clients can expose the High Elf slot through the old
    -- BloodElf token. On Octo that token means High Elf only on Alliance.
    return UnitFactionGroup("player")=="Alliance" and 512 or 0
  end
  return RACE_BITS[token] or 0
end

local function PlayerClassBit()
  local _,token=UnitClass("player")
  return CLASS_BITS[token] or 0
end

local function PlayerSkillRank(skillID)
  skillID=tonumber(skillID)
  if not skillID then return nil end

  if C_SpellBook and type(C_SpellBook.GetSkillLineRank)=="function" then
    local ok,rank=pcall(C_SpellBook.GetSkillLineRank,skillID)
    rank=ok and tonumber(rank) or nil
    if rank then return rank end
  end

  local skillName=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetProfessionName and QuestieOcto.DatabaseAPI:GetProfessionName(skillID)
  if not skillName or not GetNumSkillLines or not GetSkillLineInfo then return nil end

  for i=1,(GetNumSkillLines() or 0) do
    local name,_,_,rank=GetSkillLineInfo(i)
    if name==skillName then return tonumber(rank) or 1 end
  end
  return nil
end

function A:ClearReputationCache()
  for id in pairs(self.reputationCache) do self.reputationCache[id]=nil end
end

function A:GetPlayerReputation(factionID)
  factionID=tonumber(factionID)
  if not factionID then return nil end
  local cached=self.reputationCache[factionID]
  if cached~=nil then return cached end

  local value=nil
  if type(GetFactionInfoByID)=="function" then
    local ok,_,_,_,_,_,v=pcall(GetFactionInfoByID,factionID)
    if ok then value=tonumber(v) end
  end

  if value==nil and C_Reputation and type(C_Reputation.GetFactionDataByID)=="function" then
    local ok,data=pcall(C_Reputation.GetFactionDataByID,factionID)
    if ok and data and data.currentStanding~=nil then value=tonumber(data.currentStanding) end
  end

  if value==nil and GetNumFactions and GetFactionInfo then
    if ExpandFactionHeader then pcall(ExpandFactionHeader,0) end
    for i=1,(GetNumFactions() or 0) do
      local _,_,_,_,_,v,_,_,_,_,_,_,_,id=GetFactionInfo(i)
      if tonumber(id)==factionID then value=tonumber(v) break end
    end
  end

  if value~=nil then self.reputationCache[factionID]=value end
  return value
end

function A:ClearChallengeCache()
  self.hardcoreCache=nil
end

function A:IsHardcorePlayer()
  if self.hardcoreCache~=nil then return self.hardcoreCache end
  if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellName) then return nil end

  local tabs=GetNumSpellTabs()
  if not tabs or tabs<1 then return nil end
  local bookType=BOOKTYPE_SPELL or "spell"

  for tab=1,tabs do
    local _,_,offset,numSpells=GetSpellTabInfo(tab)
    if offset and numSpells then
      for slot=offset+1,offset+numSpells do
        local name=GetSpellName(slot,bookType)
        if name=="Hardcore" then
          self.hardcoreCache=true
          return true
        end
      end
    end
  end

  self.hardcoreCache=false
  return false
end

local function RawStarts(raw,kind)
  return raw and raw["start"] and raw["start"][kind] or nil
end

local function HasStarterRaw(raw)
  return
    (RawStarts(raw,"U") and next(RawStarts(raw,"U"))) or
    (RawStarts(raw,"O") and next(RawStarts(raw,"O"))) or
    (RawStarts(raw,"I") and next(RawStarts(raw,"I")))
end

local function StarterFactionAllowsPlayerRaw(raw)
  local db=QuestieOcto.DatabaseAPI
  if not db then return true end

  local itemStarts=RawStarts(raw,"I")
  if itemStarts and next(itemStarts) then return true end

  local sawDirectStarter=false
  for _,id in pairs(RawStarts(raw,"U") or {}) do
    sawDirectStarter=true
    if not db.CreatureAllowsPlayerFaction or db:CreatureAllowsPlayerFaction(id) then return true end
  end
  for _,id in pairs(RawStarts(raw,"O") or {}) do
    sawDirectStarter=true
    if not db.ObjectAllowsPlayerFaction or db:ObjectAllowsPlayerFaction(id) then return true end
  end

  return not sawDirectStarter
end

local function PrerequisitesSatisfiedRaw(raw)
  local pre=raw and raw["pre"] or nil
  local preActive=raw and raw["preActive"] or nil
  local preAll=raw and raw["preAll"] or nil
  if not pre and not preActive and not preAll then return true end

  local satisfied=false
  local activeSet=nil
  local allSet=nil

  if preActive then
    activeSet={}
    for _,id in pairs(preActive) do
      activeSet[id]=true
      if QuestieOcto.QuestLog:IsOnQuest(id) then satisfied=true end
    end
  end

  if preAll then
    allSet={}
    for _,group in pairs(preAll) do
      local groupComplete=true
      for _,id in pairs(group) do
        allSet[id]=true
        if not QuestieOcto.Completion:IsRewardedForPrerequisite(id) then groupComplete=false end
      end
      if groupComplete then satisfied=true end
    end
  end

  if pre then
    for _,id in pairs(pre) do
      if (not activeSet or not activeSet[id]) and (not allSet or not allSet[id]) then
        if QuestieOcto.Completion:IsRewardedForPrerequisite(id) then satisfied=true end
      end
    end
  end

  return satisfied
end

local function BlockedByExclusiveRaw(raw,questID)
  if not raw or not raw["exclusive"] or not raw["close"] then return false end
  for _,id in pairs(raw["close"]) do
    if id~=questID and QuestieOcto.Completion:HasBlockingStatus(id) then return true end
  end
  return false
end

local function HasOtherTimedQuest(questID)
  for activeID in pairs(QuestieOcto.QuestLog.active or {}) do
    if activeID~=questID then
      local active=QuestieOcto.QuestModel:Get(activeID)
      if active and active.timed then return true end
    end
  end
  return false
end

local function IndexQuestDependencies(self,questID,raw)
  local index=self.pendingDependencyIndex or self.dependencyIndex
  if not index or not raw then return end
  if raw["skill"] then index.skill[questID]=true end
  if raw["repMinFaction"] or raw["repMaxFaction"] then index.reputation[questID]=true end
  if raw["hardcore"] then index.hardcore[questID]=true end
end

local function Track(self,name,enabled)
  if not enabled then return end
  local stats=self.scanStats or self.stats
  stats[name]=(stats[name] or 0)+1
end

function A:EvaluateQuest(questID,trackStats)
  questID=tonumber(questID)
  local raw=questID and QuestieOcto.DatabaseAPI:GetQuestRaw(questID) or nil
  if not raw then return false,"noModel" end
  IndexQuestDependencies(self,questID,raw)

  if raw["disabled"] then
    Track(self,"disabled",trackStats)
    return false,"disabled"
  end

  local rawEventID=tonumber(raw["event"])
  local eventID=(rawEventID==5 and 4 or rawEventID)
  local eventService=QuestieOcto.EventAvailability
  local verifiedDarkmoon=eventService and eventService.IsVerifiedDarkmoonRaw
      and eventService:IsVerifiedDarkmoonRaw(raw) and eventService:IsDarkmoonFaireActive() and true or false

  if QuestieOcto.QuestLog:IsOnQuest(questID) then
    Track(self,"active",trackStats)
    return false,"active"
  end

  if QuestieOcto.Completion:IsQuestBlockedByCompletion(questID,nil) then
    Track(self,"completed",trackStats)
    return false,"completed"
  end

  local nextChain=tonumber(raw["nextChain"])
  if not verifiedDarkmoon and nextChain and QuestieOcto.Completion:HasBlockingStatus(nextChain) then
    Track(self,"prerequisite",trackStats)
    return false,"nextChain"
  end

  if not verifiedDarkmoon and BlockedByExclusiveRaw(raw,questID) then
    Track(self,"exclusive",trackStats)
    return false,"exclusive"
  end

  if not verifiedDarkmoon and not PrerequisitesSatisfiedRaw(raw) then
    Track(self,"prerequisite",trackStats)
    return false,"prerequisite"
  end

  if raw["race"] and not MaskContains(raw["race"],PlayerRaceBit()) then
    Track(self,"race",trackStats)
    return false,"race"
  end

  if raw["class"] and not MaskContains(raw["class"],PlayerClassBit()) then
    Track(self,"class",trackStats)
    return false,"class"
  end

  if not StarterFactionAllowsPlayerRaw(raw) then
    Track(self,"starterFaction",trackStats)
    return false,"starterFaction"
  end

  if raw["hardcore"] then
    local hardcore=self:IsHardcorePlayer()
    if not hardcore then
      Track(self,"hardcore",trackStats)
      return false,"hardcore"
    end
  end

  local requiredSkill=raw["skill"]
  if requiredSkill then
    local requiredSkillValue=tonumber(raw["skillValue"] or 1) or 1
    local rank=PlayerSkillRank(requiredSkill)
    if not rank or rank<requiredSkillValue then
      Track(self,"skill",trackStats)
      return false,"skill"
    end
  end

  local repMinFaction=tonumber(raw["repMinFaction"])
  if repMinFaction and not verifiedDarkmoon then
    local rep=self:GetPlayerReputation(repMinFaction)
    local repMinValue=tonumber(raw["repMinValue"] or 0) or 0
    if rep==nil or rep<repMinValue then
      Track(self,"reputation",trackStats)
      return false,"repMin"
    end
  end

  local repMaxFaction=tonumber(raw["repMaxFaction"])
  if repMaxFaction and not verifiedDarkmoon then
    local rep=self:GetPlayerReputation(repMaxFaction)
    local repMaxValue=tonumber(raw["repMaxValue"] or 0) or 0
    if rep==nil or rep>=repMaxValue then
      Track(self,"reputation",trackStats)
      return false,"repMax"
    end
  end

  local conditional=QuestieOcto.QuestModel and QuestieOcto.QuestModel.GetConditionalOffer and QuestieOcto.QuestModel:GetConditionalOffer(questID) or nil
  local conditionalMarker=QuestieOcto.QuestModel and QuestieOcto.QuestModel.GetConditionalMapMarker and QuestieOcto.QuestModel:GetConditionalMapMarker(questID) or nil
  if conditional and not conditionalMarker then return false,"conditional" end

  if eventID then
    eventService=eventService or QuestieOcto.EventAvailability
    local gated=eventService and eventService:ShouldGateQuest(eventID) or true
    if gated then
      local settings=QuestieOcto.MinimapSettings
      if not settings:Get("showEventQuests") then
        Track(self,"event",trackStats)
        return false,"eventHidden"
      end
      if eventService and eventService:IsStandbyEvent(eventID) then
        Track(self,"event",trackStats)
        return false,"eventStandby"
      end
      if not (eventService and eventService:IsActiveForQuestID(questID,eventID)) then
        Track(self,"event",trackStats)
        return false,"eventInactive"
      end
    end
  end

  local settings=QuestieOcto.MinimapSettings
  local level=UnitLevel("player") or 1
  local showLowLevel=settings:Get("showLowLevelQuests") and true or false
  local questLevel=tonumber(raw["lvl"] or 0) or 0

  if questLevel>0 then
    if not showLowLevel and questLevel<level-4 then
      Track(self,"level",trackStats)
      return false,"lowLevel"
    elseif showLowLevel then
      local below=tonumber(settings:Get("lowLevelQuestRange")) or 35
      if below<35 and questLevel<level-below then
        Track(self,"level",trackStats)
        return false,"lowLevel"
      end
    end
  end

  local requiredLevel=tonumber(raw["min"] or 0) or 0
  if requiredLevel>level then
    Track(self,"level",trackStats)
    return false,"minLevel"
  end

  if (tonumber(raw["type"] or 0) or 0)==41 and not settings:Get("showPvPRelatedQuests") then
    Track(self,"pvp",trackStats)
    return false,"pvpHidden"
  end

  local repeatable=QuestieOcto.QuestModel and QuestieOcto.QuestModel:IsRepeatableRaw(questID,raw) or (raw["repeatable"] and true or false)
  if repeatable and not settings:Get("showRepeatableQuests") then
    Track(self,"repeatable",trackStats)
    return false,"repeatable"
  end

  local maximumLevel=tonumber(raw["max"] or 0) or 0
  if maximumLevel>0 and level>maximumLevel then
    Track(self,"level",trackStats)
    return false,"maxLevel"
  end

  if raw["timed"] and HasOtherTimedQuest(questID) then
    Track(self,"timed",trackStats)
    return false,"timed"
  end

  if not HasStarterRaw(raw) then
    Track(self,"noStarter",trackStats)
    return false,"noStarter"
  end

  -- The bulk completed-quest cache can be stale/incomplete on some clients.
  -- Before publishing an otherwise-eligible ordinary quest, ask ClassicAPI for
  -- its direct completion flag. Repeatable/daily/yearly quests are deliberately
  -- excluded by Completion:VerifyOrdinaryCompletionFlag().
  if QuestieOcto.Completion and QuestieOcto.Completion.VerifyOrdinaryCompletionFlag then
    local blocked,learned=QuestieOcto.Completion:VerifyOrdinaryCompletionFlag(questID,nil)
    if blocked then
      if learned then self.learnedCompletionFlag=true end
      Track(self,"completed",trackStats)
      return false,"completed"
    end
  end

  if conditional and conditionalMarker then return true,"conditional" end

  return true,"available"
end

local RACE_LABELS={
  {1,"Human"},{2,"Orc"},{4,"Dwarf"},{8,"Night Elf"},{16,"Undead"},
  {32,"Tauren"},{64,"Gnome"},{128,"Troll"},{256,"Goblin"},{512,"High Elf"}
}
local CLASS_LABELS={
  {1,"Warrior"},{2,"Paladin"},{4,"Hunter"},{8,"Rogue"},{16,"Priest"},
  {64,"Shaman"},{128,"Mage"},{256,"Warlock"},{1024,"Druid"}
}

local function MaskLabels(mask,labels)
  local out={}
  for i=1,table.getn(labels) do
    if MaskContains(mask,labels[i][1]) then table.insert(out,labels[i][2]) end
  end
  return table.concat(out,", ")
end

local function QuestLabel(id)
  id=tonumber(id)
  local title=id and QuestieOcto.DatabaseAPI:GetQuestTitle(id) or nil
  if title then return "["..tostring(id).."] "..title end
  return "Quest "..tostring(id or "?")
end

local function FactionLabel(id)
  id=tonumber(id)
  if id and type(GetFactionInfoByID)=="function" then
    local ok,name=pcall(GetFactionInfoByID,id)
    if ok and name then return name end
  end
  return "faction "..tostring(id or "?")
end

local function PrerequisiteSummary(q)
  local alternatives={}
  local activeAlternatives={}

  local activeSet={}
  for _,id in pairs(q.preQuestActive or {}) do
    activeSet[id]=true
    if not QuestieOcto.QuestLog:IsOnQuest(id) then
      table.insert(activeAlternatives,QuestLabel(id))
    end
  end

  local allSet={}
  for _,group in pairs(q.preQuestAll or {}) do
    local missing={}
    for _,id in pairs(group or {}) do
      allSet[id]=true
      if not QuestieOcto.Completion:IsRewardedForPrerequisite(id) then
        table.insert(missing,QuestLabel(id))
      end
    end
    if table.getn(missing)>0 then
      table.insert(alternatives,table.concat(missing," + "))
    end
  end

  for _,id in pairs(q.preQuestSingle or {}) do
    if not activeSet[id] and not allSet[id] and not QuestieOcto.Completion:IsRewardedForPrerequisite(id) then
      table.insert(alternatives,QuestLabel(id))
    end
  end

  -- pfQuest pre is OR semantics: any listed single quest, active predecessor,
  -- or complete all-of group can satisfy the prerequisite. Keep that meaning
  -- while using concise player-facing wording.
  local combined={}
  for i=1,table.getn(alternatives) do table.insert(combined,alternatives[i]) end
  for i=1,table.getn(activeAlternatives) do table.insert(combined,activeAlternatives[i].." (active)") end

  if table.getn(combined)==0 then return "Prerequisite not met." end
  if table.getn(combined)==1 then return "Requires: "..combined[1].."." end
  return "Requires one of: "..table.concat(combined,"; ").."."
end

local function ReputationStanding(value)
  value=tonumber(value) or 0
  if value>=42000 then return "Exalted" end
  if value>=21000 then return "Revered" end
  if value>=9000 then return "Honored" end
  if value>=3000 then return "Friendly" end
  if value>=0 then return "Neutral" end
  if value>=-3000 then return "Unfriendly" end
  if value>=-6000 then return "Hostile" end
  return "Hated"
end

function A:GetUnavailableReason(questID)
  questID=tonumber(questID)
  local q=questID and QuestieOcto.QuestModel:Get(questID) or nil
  if not q then return "Not present in the current quest database." end

  local ok,code=self:EvaluateQuest(questID,false)
  if ok then return nil end
  if code=="disabled" then return "Not available in game." end
  if code=="active" then return "Already active." end
  if code=="completed" then return "Already completed." end
  if code=="nextChain" then return "Already progressed past this quest." end
  if code=="exclusive" then
    local blocked={}
    for _,id in pairs(q.exclusiveTo or {}) do
      if id~=q.id and QuestieOcto.Completion:HasBlockingStatus(id) then table.insert(blocked,QuestLabel(id)) end
    end
    if table.getn(blocked)>0 then return "Blocked by: "..table.concat(blocked,", ").."." end
    return "Blocked by another quest choice."
  end
  if code=="prerequisite" then return PrerequisiteSummary(q) end
  if code=="race" then
    local allowed=MaskLabels(q.raceMask,RACE_LABELS)
    return allowed~="" and ("Requires race: "..allowed..".") or "Race requirement not met."
  end
  if code=="class" then
    local allowed=MaskLabels(q.classMask,CLASS_LABELS)
    return allowed~="" and ("Requires class: "..allowed..".") or "Class requirement not met."
  end
  if code=="hardcore" then return "Requires Hardcore." end
  if code=="skill" then
    local name=QuestieOcto.DatabaseAPI.GetProfessionName and QuestieOcto.DatabaseAPI:GetProfessionName(q.requiredSkill) or nil
    return "Requires "..tostring(name or ("skill "..tostring(q.requiredSkill))).." "..tostring(q.requiredSkillValue or 1).."."
  end
  if code=="repMin" then
    return "Requires "..ReputationStanding(q.repMinValue).." with "..FactionLabel(q.repMinFaction).."."
  end
  if code=="repMax" then
    return "Requires below "..ReputationStanding(q.repMaxValue).." with "..FactionLabel(q.repMaxFaction).."."
  end
  if code=="conditional" then return tostring(q.conditionalOffer or "Requires a world interaction.") end
  if code=="eventHidden" then
    local name=QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:GetEventName(q.eventID) or ("event "..tostring(q.eventID))
    return "Event quests are hidden."
  end
  if code=="eventStandby" then
    local name=QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:GetEventName(q.eventID) or ("event "..tostring(q.eventID))
    return "Event availability is not verified."
  end
  if code=="eventInactive" then
    local name=QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:GetEventName(q.eventID) or ("event "..tostring(q.eventID))
    return tostring(name).." is not active."
  end
  if code=="lowLevel" then return "Hidden as a low-level quest." end
  if code=="minLevel" then return "Requires level "..tostring(q.requiredLevel or 0).."." end
  if code=="maxLevel" then return "Maximum level "..tostring(q.maximumLevel or 0).."." end
  if code=="repeatable" then return "Repeatable quests are hidden." end
  if code=="pvpHidden" then return "PVP related quests are hidden." end
  if code=="timed" then return "Another timed quest is active." end
  if code=="starterFaction" then return "The known quest starter is not friendly to your faction." end
  if code=="noStarter" then return "No quest starter is known." end
  if code=="noModel" then return "Not present in the current quest database." end
  return "Unavailable — exact server-side requirement unknown ("..tostring(code or "unknown")..")."
end

function A:IsQuestAvailable(questID)
  local ok=self:EvaluateQuest(questID,true)
  return ok
end

function A:Recalculate(fastRefresh)
  if not QuestieOcto.DatabaseAPI:IsReady()
     or not QuestieOcto.Completion.ready
     or not QuestieOcto.QuestLog.snapshot then
    return
  end

  self.generation=self.generation+1
  local generation=self.generation

  -- Transactional refresh: keep the currently published availability set
  -- visible while the replacement is scanned. The old implementation cleared
  -- the live table before the async scan completed, which made map pins blink
  -- off/on whenever a filtering option changed.
  self.pendingAvailable={}
  self.pendingDependencyIndex={skill={},reputation={},hardcore={}}
  self.learnedCompletionFlag=false
  self.queue=QuestieOcto.DatabaseAPI:GetQuestIDs()
  self.pos=1
  self.running=true
  if not self.ready then self.ready=false end
  self.scanStats=NewStats()

  local function step()
    if generation~=A.generation then return end
    if not QuestieOcto.Completion.ready then
      A.running=false
      A.ready=false
      A.pendingDependencyIndex=nil
      return
    end

    local count=0
    local batch=fastRefresh and 100 or 60
    while A.pos<=table.getn(A.queue) and count<batch do
      local id=A.queue[A.pos]
      A.pos=A.pos+1
      A.scanStats.scanned=A.scanStats.scanned+1

      if A:IsQuestAvailable(id) then
        A.pendingAvailable[id]=true
        A.scanStats.available=A.scanStats.available+1
      end

      count=count+1
    end

    if A.pos<=table.getn(A.queue) then
      QuestieOcto.Scheduler:Enqueue(step,"available-scan")
      return
    end

    -- Publish once, atomically, only after the complete scan is ready.
    -- Also publish the exact availability delta. Filter-only changes (such as
    -- Low-Level Quest range) can then patch only quests that actually crossed
    -- the visibility boundary instead of rebuilding/rebinding every map pin.
    local previous=A.available or {}
    local replacement=A.pendingAvailable or {}
    local changed={}
    local id
    for id in pairs(previous) do
      if not replacement[id] then changed[id]=true end
    end
    for id in pairs(replacement) do
      if not previous[id] then changed[id]=true end
    end

    A.available=replacement
    A.dependencyIndex=A.pendingDependencyIndex or A.dependencyIndex
    A.stats=A.scanStats or A.stats
    A.pendingAvailable=nil
    A.pendingDependencyIndex=nil
    A.scanStats=nil
    A.running=false
    A.ready=true
    local learnedCompletionFlag=A.learnedCompletionFlag and true or false
    A.learnedCompletionFlag=false
    QuestieOcto:SendMessage("AVAILABLE_QUESTS_READY",changed)

    -- A repaired completion can unlock a follow-up that happened to be scanned
    -- earlier in this pass. One fast follow-up scan is enough; the repaired
    -- quest is now in persistent history and cannot trigger this again.
    if learnedCompletionFlag then A:Schedule(true,0.01) end
  end

  QuestieOcto.Scheduler:Enqueue(step,"available-scan")
end

function A:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return end

  if self.available[questID] then
    self.available[questID]=nil
    if self.stats.available and self.stats.available>0 then
      self.stats.available=self.stats.available-1
    end
  end
  if self.pendingAvailable then self.pendingAvailable[questID]=nil end

  if QuestieOcto.ItemStarts and QuestieOcto.ItemStarts.byQuest then
    QuestieOcto.ItemStarts.byQuest[questID]=nil
  end

  if QuestieOcto.PreparedMap and QuestieOcto.PreparedMap.RemoveQuest then
    QuestieOcto.PreparedMap:RemoveQuest(questID)
  elseif QuestieOcto.PreparedMap then
    QuestieOcto.PreparedMap:BumpStateRevision("quest-remove")
  end

  if QuestieOcto.Map and QuestieOcto.Map.RemoveQuest then
    QuestieOcto.Map:RemoveQuest(questID)
  end
end

function A:RecalculateDependency(kind)
  local set=self.dependencyIndex and self.dependencyIndex[kind] or nil
  if not self.ready or self.running or not set then
    self:Schedule(true,0.01)
    return
  end

  local changed={}
  local learnedBefore=self.learnedCompletionFlag and true or false
  self.learnedCompletionFlag=false
  local scanned=0

  for questID in pairs(set) do
    local was=self.available[questID] and true or false
    local now=self:EvaluateQuest(questID,false) and true or false
    if now~=was then
      changed[questID]=true
      if now then
        self.available[questID]=true
        self.stats.available=(self.stats.available or 0)+1
      else
        self.available[questID]=nil
        self.stats.available=math.max(0,(self.stats.available or 0)-1)
      end
    end
    scanned=scanned+1
  end

  self.stats.dependencyScans=(self.stats.dependencyScans or 0)+1
  self.stats.lastDependencyKind=kind
  self.stats.lastDependencyCount=scanned

  if next(changed) then QuestieOcto:SendMessage("AVAILABLE_QUESTS_READY",changed) end

  local learned=self.learnedCompletionFlag and true or false
  self.learnedCompletionFlag=learnedBefore
  if learned then self:Schedule(true,0.01) end
end

function A:ScheduleDependency(kind,delay)
  QuestieOcto.Scheduler:After(delay or 0.01,function()
    A:RecalculateDependency(kind)
  end,"available-dependency-"..tostring(kind))
end

function A:FastRefresh()
  self:Recalculate(true)
end

function A:Schedule(fastRefresh,delay)
  QuestieOcto.Scheduler:After(delay or (fastRefresh and 0.01 or 0.10),function()
    A:Recalculate(fastRefresh and true or false)
  end,"available-recalc")
end

function A:GetAvailableSet()
  return self.available
end

function A:OnFoundationInputChanged()
  if not self.ready then self:Schedule(true,0.01) else self:Schedule(false,0.10) end
end

QuestieOcto:RegisterMessage("DATABASE_API_READY",A,"OnFoundationInputChanged")
QuestieOcto:RegisterMessage("COMPLETION_READY",A,"OnFoundationInputChanged")
QuestieOcto:RegisterMessage("QUEST_ELIGIBILITY_STATE_CHANGED",A,"OnFoundationInputChanged")

local stateFrame=CreateFrame("Frame","QuestieOctoQuestEligibilityEvents",UIParent)
stateFrame:RegisterEvent("PLAYER_LEVEL_UP")
stateFrame:RegisterEvent("SKILL_LINES_CHANGED")
stateFrame:RegisterEvent("UPDATE_FACTION")
stateFrame:RegisterEvent("SPELLS_CHANGED")
stateFrame:SetScript("OnEvent",function()
  if event=="PLAYER_LEVEL_UP" then
    -- Level changes can affect a large fraction of the quest database, so keep
    -- the existing immediate full refresh and settled follow-up.
    A:FastRefresh()
    QuestieOcto.Scheduler:After(0.30,function() A:FastRefresh() end,"questie-level-stable-refresh")
    return
  end

  if event=="UPDATE_FACTION" then
    A:ClearReputationCache()
    A:ScheduleDependency("reputation",0.01)
  elseif event=="SKILL_LINES_CHANGED" then
    A:ScheduleDependency("skill",0.01)
  elseif event=="SPELLS_CHANGED" then
    A:ClearChallengeCache()
    A:ScheduleDependency("hardcore",0.01)
  end
end)
