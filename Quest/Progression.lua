-- Quest-progress visibility only. Never mark skipped quests complete and never
-- modify server-side eligibility, quest log, or completion/SavedVariables.
-- The compact forward links were audited offline against two reciprocal SQL
-- fields and the current compiled prerequisite. Unsafe branches are omitted.
QuestieOcto.Progression = QuestieOcto.Progression or {}
local P = QuestieOcto.Progression
local MAX_CHAIN_DEPTH = 16  -- audited longest chain is shorter; cycle guard below.

function P:HasProgressedPast(questID, explicitNext, raw)
  local nextID = explicitNext or (self.nextByQuest and self.nextByQuest[questID])
  if not nextID then return false, false end

  -- A newly observed repeatable must not be permanently suppressed by an
  -- ordinary successor. Hand-authored nextChain fields retain prior semantics.
  if not explicitNext and QuestieOcto.QuestModel and QuestieOcto.QuestModel.IsRepeatableRaw
      and QuestieOcto.QuestModel:IsRepeatableRaw(questID,raw) then
    return false, false
  end

  local completion = QuestieOcto.Completion
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

    -- Only walk vetted links or existing authored nextChain fields. Do not
    -- traverse generic OR prerequisites; a later branch is not proof that an
    -- unrelated introductory quest became unavailable.
    local nextRaw = QuestieOcto.DatabaseAPI:GetQuestRaw(nextID)
    nextID = nextRaw and (tonumber(nextRaw["nextChain"])
      or (self.nextByQuest and self.nextByQuest[nextID])) or nil
  end
  return false, learned
end
