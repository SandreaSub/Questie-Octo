QuestieOcto.Completion = QuestieOcto.Completion or {}
local C = QuestieOcto.Completion

C.ready=false
C.receiving=false
C.querying=false
C.queryStartedAt=0
C.history={}
C.current={}
C.sessionLocks={}
C.dailyReset={}
-- Session cache for per-quest completion verification. This supplements the
-- bulk completion query when that cache is incomplete for a character. Both
-- true and false are cached; normal quest turn-in events update the true state.
C.flaggedCompletionCache={}
C.receivedPackets=0
C.startedAt=0
C.source="none"
C.nextResetCheck=0
C.stats={refreshes=0,localRefreshes=0,serverRefreshes=0,turnIns=0}

local function SplitWords(text)
  local result={}
  if not text then return result end
  string.gsub(text,"([^%s]+)",function(v) table.insert(result,v) end)
  return result
end

local function CopyTrueSet(src,dst)
  if type(src)~="table" then return end
  for questID,value in pairs(src) do
    if value then dst[tonumber(questID) or questID]=true end
  end
end

local function LoadSaved()
  QuestieOctoDB=QuestieOctoDB or {}
  C.history={}
  C.dailyReset={}
  CopyTrueSet(QuestieOctoDB.completed,C.history)
  if type(QuestieOctoDB.dailyReset)=="table" then
    for questID,epoch in pairs(QuestieOctoDB.dailyReset) do
      questID=tonumber(questID) or questID
      epoch=tonumber(epoch)
      if epoch then C.dailyReset[questID]=epoch end
    end
  end
end

local function Save()
  QuestieOctoDB=QuestieOctoDB or {}
  QuestieOctoDB.completed=C.history
  QuestieOctoDB.dailyReset=C.dailyReset
end

-- Character-specific SavedVariables can survive a Hardcore fresh-life reset or
-- a delete/recreate that reuses the same character name. pfQuest protects the
-- same Vanilla case by treating level 1 with exactly 0 XP as an unequivocally
-- fresh character. Do that before asking the server for completion state so old
-- quest history cannot suppress the new character's starting quests.
--
-- Only quest-completion bookkeeping is cleared. Character options, tracker
-- placement/state, Quest Log collapse preferences, and other settings remain.
local function ResetCompletionForFreshCharacter()
  if type(UnitLevel)~="function" or type(UnitXP)~="function" then return false end
  local level=tonumber(UnitLevel("player"))
  local xp=tonumber(UnitXP("player"))
  if level~=1 or xp~=0 then return false end

  C.history={}
  C.current={}
  C.sessionLocks={}
  C.dailyReset={}
  C.flaggedCompletionCache={}

  QuestieOctoDB=QuestieOctoDB or {}
  QuestieOctoDB.completed={}
  QuestieOctoDB.dailyReset={}
  return true
end

local function Publish(source)
  C.ready=true
  C.source=source or C.source
  C.stats.refreshes=(C.stats.refreshes or 0)+1
  Save()
  QuestieOcto:SendMessage("COMPLETION_READY")
end

local function NextRealmMidnight()
  if type(time)~="function" or type(GetGameTime)~="function" then return nil end
  local hour,minute=GetGameTime()
  hour=tonumber(hour)
  minute=tonumber(minute)
  if not hour or not minute then return nil end
  local remaining=1440-(hour*60+minute)
  if remaining<=0 then remaining=1440 end
  return time()+(remaining*60)
end

function C:IsDailyLocked(questID)
  local epoch=tonumber(self.dailyReset[questID])
  if not epoch then return false end
  if type(time)=="function" and epoch<=time() then
    self.dailyReset[questID]=nil
    return false
  end
  return true
end

function C:IsEverComplete(questID)
  return self.history[questID] and true or false
end

local function StaticQuestFlags(questID,q)
  if q then
    return q.daily and true or false,q.yearly and true or false,q.repeatable and true or false,q.hideAfterFirstCompletion and true or false
  end
  local raw=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestRaw and QuestieOcto.DatabaseAPI:GetQuestRaw(questID) or nil
  if not raw then return false,false,false,false end
  local repeatable=QuestieOcto.QuestModel and QuestieOcto.QuestModel.IsRepeatableRaw and QuestieOcto.QuestModel:IsRepeatableRaw(questID,raw)
  return raw["daily"] and true or false,raw["yearly"] and true or false,repeatable and true or false,raw["hideAfterFirstCompletion"] and true or false
end

function C:IsCurrentComplete(questID)
  if self.current[questID] or self.sessionLocks[questID] then return true end
  local daily=StaticQuestFlags(questID,nil)
  if daily and self:IsDailyLocked(questID) then return true end
  return false
end

-- Backward-compatible name used by UI/diagnostics. "Complete" here means the
-- character has rewarded the quest at least once, not necessarily that a
-- repeatable/daily quest is currently locked.
function C:IsComplete(questID)
  return self:IsEverComplete(questID)
end

function C:IsQuestBlockedByCompletion(questID,q)
  local daily,yearly,repeatable,hideAfterFirst=StaticQuestFlags(questID,q)
  if daily or yearly then return self:IsCurrentComplete(questID) end
  if repeatable then
    if hideAfterFirst then
      return self:IsEverComplete(questID) or self:IsCurrentComplete(questID)
    end
    return false
  end
  return self:IsEverComplete(questID) or self:IsCurrentComplete(questID)
end

-- Final safety check for ordinary one-time quests. Turtle/ClassicAPI's bulk
-- completion cache can occasionally be incomplete for a character even though
-- the direct per-quest flag already knows the quest was rewarded. Only use the
-- direct flag for non-repeatable, non-daily, non-yearly quests so resettable
-- quest semantics are never collapsed into permanent completion.
--
-- Returns:
--   blocked  - true when the direct client flag says the quest is completed.
--   learned  - true only when this call repaired previously-missing history.
function C:VerifyOrdinaryCompletionFlag(questID,q)
  questID=tonumber(questID)
  if not questID then return false,false end

  local daily,yearly,repeatable=StaticQuestFlags(questID,q)
  if daily or yearly or repeatable then return false,false end

  if not QuestieOcto.API or not QuestieOcto.API.optional
     or not QuestieOcto.API.optional.questFlaggedCompleted
     or not QuestieOcto.API.IsQuestFlaggedCompleted then
    return false,false
  end

  local cached=self.flaggedCompletionCache[questID]
  if cached~=nil then return cached and true or false,false end

  local flagged=QuestieOcto.API:IsQuestFlaggedCompleted(questID)
  if flagged==nil then return false,false end

  self.flaggedCompletionCache[questID]=flagged and true or false
  if not flagged then return false,false end

  local learned=not self.history[questID]
  self.history[questID]=true

  -- A repeatable-after-first-completion quest is ordinary only until this
  -- character has completed it once. A direct completion flag can therefore
  -- both repair missing history and unlock the quest's repeatable state in the
  -- same pass; do not suppress its newly valid repeatable availability.
  local afterFirst=QuestieOcto.QuestModel and QuestieOcto.QuestModel.IsRepeatableAfterFirstCompletionRaw
    and QuestieOcto.QuestModel:IsRepeatableAfterFirstCompletionRaw(questID,nil)
  if afterFirst then
    self.current[questID]=nil
  else
    self.current[questID]=true
  end

  if learned then Save() end
  if afterFirst then return false,learned end
  return true,learned
end

function C:IsRewardedForPrerequisite(questID)
  local daily,yearly=StaticQuestFlags(questID,nil)
  if daily or yearly then return self:IsCurrentComplete(questID) end
  return self:IsEverComplete(questID) or self:IsCurrentComplete(questID)
end

function C:HasBlockingStatus(questID)
  local state=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]
  if state and not state.failed then return true end

  local daily,yearly,repeatable=StaticQuestFlags(questID,nil)
  if repeatable and not daily and not yearly then return false end
  return self:IsRewardedForPrerequisite(questID)
end

function C:Count()
  local n=0
  for _ in pairs(self.history) do n=n+1 end
  return n
end

function C:OnQuestTurnedIn(questID)
  questID=tonumber(questID)
  if not questID then return end

  self.stats.turnIns=(self.stats.turnIns or 0)+1
  local q=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil

  -- Always remember that the quest was rewarded at least once. Ordinary
  -- repeatables are still allowed to reappear by IsQuestBlockedByCompletion;
  -- this persistent history is needed when another quest uses them as a
  -- historical prerequisite.
  self.history[questID]=true
  self.flaggedCompletionCache[questID]=true

  if q and q.daily then
    self.current[questID]=true
    local reset=NextRealmMidnight()
    if reset then self.dailyReset[questID]=reset end
  elseif q and q.yearly then
    -- No trustworthy client-side yearly calendar is available. Keep a
    -- same-session lock and let the authoritative server completion query
    -- establish state after a relog.
    self.current[questID]=true
    self.sessionLocks[questID]=true
  elseif q and (q.repeatable or q.repeatableAfterFirstCompletion) then
    -- For repeatable-after-first-completion quests, q.repeatable is still false
    -- at the instant of the first turn-in because history is written just above.
    -- The explicit semantic therefore participates in this branch so the first
    -- completion does not leave an ordinary-quest lock behind. Future QuestModel
    -- reads immediately see history and present the quest as repeatable.
    if q.hideAfterFirstCompletion then
      self.current[questID]=true
    else
      self.current[questID]=nil
    end
  else
    self.current[questID]=true
  end

  Save()

  if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.RemoveQuest then
    QuestieOcto.AvailableQuests:RemoveQuest(questID)
  end

  self.ready=true
  self.source="QUEST_TURNED_IN"
  QuestieOcto:SendMessage("COMPLETION_READY")

  -- COMPLETION_READY already schedules availability through the keyed
  -- available-recalc timer. Replace that delayed normal refresh with the fast
  -- one instead of launching a second full 6,701-quest generation.
  if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.Schedule then
    QuestieOcto.AvailableQuests:Schedule(true,0.01)
  end
end

function C:RefreshFromQuestieAPI()
  if not QuestieOcto.API then return false end

  local completed=QuestieOcto.API:GetQuestsCompleted()
  if type(completed)~="table" then return false end

  local nextCurrent={}
  for questID,value in pairs(completed) do
    if value then
      questID=tonumber(questID) or questID
      nextCurrent[questID]=true
      self.history[questID]=true
    end
  end

  -- Session-only yearly locks survive an in-session API refresh. They are
  -- intentionally not SavedVariables because the reset date is server policy.
  for questID in pairs(self.sessionLocks) do nextCurrent[questID]=true end

  self.current=nextCurrent
  self.flaggedCompletionCache={}
  self.receiving=false
  self.stats.localRefreshes=(self.stats.localRefreshes or 0)+1
  Publish("GetQuestsCompleted")
  return true
end

function C:StartCompletionQuery()
  if self.querying then return true end
  if not QuestieOcto.API or not QuestieOcto.API.QueryQuestsCompleted then return false end
  if not QuestieOcto.API.optional or not QuestieOcto.API.optional.queryQuestsCompleted then return false end

  self.ready=false
  self.querying=true
  self.queryStartedAt=GetTime()
  self.source="QueryQuestsCompleted"
  self.frame:RegisterEvent("QUEST_QUERY_COMPLETE")

  if not QuestieOcto.API:QueryQuestsCompleted() then
    self.querying=false
    self.frame:UnregisterEvent("QUEST_QUERY_COMPLETE")
    return false
  end
  return true
end

function C:FinishCompletionQuery()
  if not self.querying then return false end
  self.querying=false
  self.frame:UnregisterEvent("QUEST_QUERY_COMPLETE")
  return self:RefreshFromQuestieAPI()
end

function C:StartServerFallback()
  if self.receiving then return end

  self.ready=false
  self.receiving=true
  self.current={}
  self.receivedPackets=0
  self.startedAt=GetTime()
  self.source="TWQUEST"

  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  SendChatMessage(".queststatus","GUILD")
end

function C:Start()
  LoadSaved()
  ResetCompletionForFreshCharacter()

  -- pfQuest's /db query protocol is important on Vanilla/Turtle: first ask the
  -- server to populate the completion cache, then wait for QUEST_QUERY_COMPLETE
  -- before reading GetQuestsCompleted(). Reading it immediately can be stale.
  if self:StartCompletionQuery() then return end
  if self:RefreshFromQuestieAPI() then return end
  self:StartServerFallback()
end

function C:FinishServerFallback()
  if not self.receiving then return end
  self.receiving=false
  self.frame:UnregisterEvent("CHAT_MSG_ADDON")
  self.flaggedCompletionCache={}
  self.stats.serverRefreshes=(self.stats.serverRefreshes or 0)+1
  Publish("TWQUEST")
end

function C:RefreshAfterQuestStateChange()
  if QuestieOcto.API and QuestieOcto.API.optional and QuestieOcto.API.optional.questsCompleted then
    QuestieOcto.Scheduler:After(0.20,function()
      if not C:StartCompletionQuery() then C:RefreshFromQuestieAPI() end
    end,"completion-local-refresh")
  end
end

function C:ScheduleStart()
  QuestieOcto.Scheduler:After(0.01,function() C:Start() end,"completion-start")
end

local f=CreateFrame("Frame","QuestieOctoCompletionEvents",UIParent)
C.frame=f
f:RegisterEvent("QUEST_TURNED_IN")

f:SetScript("OnEvent",function()
  if event=="QUEST_QUERY_COMPLETE" then
    if not C:FinishCompletionQuery() then C:StartServerFallback() end
    return
  end

  if event=="QUEST_TURNED_IN" then
    C:OnQuestTurnedIn(arg1)
    return
  end

  if event=="CHAT_MSG_ADDON" and arg1=="TWQUEST" then
    C.receivedPackets=C.receivedPackets+1
    for _,word in pairs(SplitWords(arg2)) do
      local id=tonumber(word)
      if id then
        C.current[id]=true
        C.history[id]=true
      end
    end
  end
end)

f:SetScript("OnUpdate",function()
  if C.querying and GetTime()>(C.queryStartedAt or 0)+3.0 then
    C.querying=false
    C.frame:UnregisterEvent("QUEST_QUERY_COMPLETE")
    C:StartServerFallback()
  end

  if C.receiving and GetTime()>C.startedAt+3.0 then
    C:FinishServerFallback()
  end

  -- Re-evaluate saved daily locks shortly after realm midnight even if the
  -- player is standing idle and no quest event fires at the reset boundary.
  if GetTime()>(C.nextResetCheck or 0) then
    C.nextResetCheck=GetTime()+30
    local expired=false
    if type(time)=="function" then
      local now=time()
      for questID,epoch in pairs(C.dailyReset) do
        if tonumber(epoch) and tonumber(epoch)<=now then
          C.dailyReset[questID]=nil
          C.current[questID]=nil
          expired=true
        end
      end
    end
    if expired then
      Save()
      if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.Schedule then
        QuestieOcto.AvailableQuests:Schedule(true,0.01)
      end
    end
  end
end)

QuestieOcto:RegisterMessage("QUEST_ELIGIBILITY_STATE_CHANGED",C,"RefreshAfterQuestStateChange")
