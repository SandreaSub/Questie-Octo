-- Quest-progress visibility only. Never mark skipped quests complete and never
-- modify server-side eligibility, quest log, or completion/SavedVariables.
-- The compact forward links were audited offline against two reciprocal SQL
-- fields and the current compiled prerequisite. Unsafe branches are omitted.
QuestieOcto.Progression = QuestieOcto.Progression or {}
local P = QuestieOcto.Progression
local MAX_CHAIN_DEPTH = 16  -- audited longest chain is shorter; cycle guard below.

function P:IsChainOnlyPredecessor(questID,predecessorID)
  questID=tonumber(questID)
  predecessorID=tonumber(predecessorID)
  local set=questID and self.chainOnlyPrevByQuest and self.chainOnlyPrevByQuest[questID] or nil
  return set and predecessorID and set[predecessorID] and true or false
end

function P:IsBlockedByPrevChain(questID)
  questID=tonumber(questID)
  local set=questID and self.chainOnlyPrevByQuest and self.chainOnlyPrevByQuest[questID] or nil
  if not set then return false end

  local active=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active or nil
  for predecessorID in pairs(set) do
    local state=active and active[predecessorID] or nil
    -- Mirrors Player::IsCurrentQuest() for the states Questie-Octo keeps in
    -- its live Quest Log cache: incomplete or complete-but-unrewarded blocks;
    -- a failed quest does not. Rewarded quests are no longer in the active log.
    if state and not state.failed then return true end
  end
  return false
end

local function HasDirectNextChainBlockingStatus(self,completion,questID)
  -- Server NextQuestInChain checks the immediate successor's live quest status.
  -- A repeatable successor returns to NONE after reward, so its old completion
  -- history must not permanently hide the preceding quest.
  local state=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]
  if state and not state.failed then return true end
  if self.directRepeatableQuest and self.directRepeatableQuest[questID] then return false end
  return completion:HasBlockingStatus(questID)
end

function P:HasProgressedPast(questID, explicitNext, raw)
  local completion = QuestieOcto.Completion

  -- These links mirror only the server's immediate NextQuestInChain lock. They
  -- were excluded from recursive inference precisely because their surrounding
  -- chains include branches, resettable quests, exclusivity, events or other
  -- semantics that cannot safely be flattened into one path.
  local directOnly = (not explicitNext) and self.directOnlyNextByQuest and self.directOnlyNextByQuest[questID] or nil
  if directOnly then
    return HasDirectNextChainBlockingStatus(self,completion,directOnly),false
  end

  local nextID = explicitNext or (self.nextByQuest and self.nextByQuest[questID])
  if not nextID then return false, false end

  -- A newly observed repeatable must not be permanently suppressed by an
  -- ordinary successor. Hand-authored nextChain fields retain prior semantics.
  if not explicitNext and QuestieOcto.QuestModel and QuestieOcto.QuestModel.IsRepeatableRaw
      and QuestieOcto.QuestModel:IsRepeatableRaw(questID,raw) then
    return false, false
  end

  local visited = {[questID]=true}
  local learned = false
  local depth = 0
  while nextID and not visited[nextID] and depth < MAX_CHAIN_DEPTH do
    visited[nextID]=true
    depth=depth+1
    if completion:HasBlockingStatus(nextID) then return true, learned end

    -- Preserve the narrow 1.37 direct-flag fallback for its *existing* authored
    -- successor only. Querying direct flags for 1,487 inferred links on every
    -- map refresh would be a significant performance regression on Vanilla.
    -- Historical bulk completion and the active Quest Log drive the projection.
    if depth==1 and explicitNext and completion.VerifyOrdinaryCompletionFlag then
      local flagged, repaired=completion:VerifyOrdinaryCompletionFlag(nextID,nil)
      if repaired then learned=true end
      if flagged then return true, learned end
    end

    -- After the first explicit authored edge, recurse ONLY through the strict
    -- projection. An authored NextQuestInChain can be an optional breadcrumb,
    -- so allowing a strict path to enter another authored edge would silently
    -- turn immediate-only server semantics into recursive inference.
    nextID = self.nextByQuest and self.nextByQuest[nextID] or nil
  end
  return false, learned
end
