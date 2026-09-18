QuestieOcto.Scheduler = QuestieOcto.Scheduler or {}
local S = QuestieOcto.Scheduler

-- O(1) FIFO queue. Vanilla's Lua table.remove(t,1) shifts every remaining
-- element and becomes disproportionately expensive when several incremental
-- startup jobs are queued together. Keep a monotonically advancing head/tail
-- instead, then reset the table when drained.
S.queue = {}
S.queueHead = 1
S.queueTail = 0
S.delayed = {}
S.dueKeys = {}
S.latestTimerToken = {}
S.nextTimerToken = 0
S.elapsed = 0
S.interval = 0
S.executed = 0

S.maxJobsPerFrame = 2
S.maxSecondsPerFrame = 0.004
S.stats = {
  frames=0, maxQueue=0, maxJobsInFrame=0, maxFrameSeconds=0,
  slowestLabel="none", slowestSeconds=0, lastLabel="none"
}

function S:PendingCount()
  local n=(self.queueTail or 0)-(self.queueHead or 1)+1
  if n<0 then return 0 end
  return n
end

function S:Enqueue(fn, label, timerKey, timerToken)
  if not fn then return end
  self.queueTail=(self.queueTail or 0)+1
  self.queue[self.queueTail]={fn=fn,label=label,timerKey=timerKey,timerToken=timerToken}
  local n=self:PendingCount()
  if n>(self.stats.maxQueue or 0) then self.stats.maxQueue=n end
end

function S:After(delay, fn, key)
  if not fn then return end
  if key then
    self.nextTimerToken=(self.nextTimerToken or 0)+1
    local token=self.nextTimerToken
    self.latestTimerToken[key]=token
    self.delayed[key] = { remaining=delay or 0, fn=fn, label=tostring(key), key=key, token=token }
  else
    table.insert(self.delayed, { remaining=delay or 0, fn=fn, label="delayed" })
  end
end

local function RunDelayed(self, delta)
  -- Reuse one persistent due-key array instead of allocating a fresh table on
  -- every OnUpdate, including frames where no delayed timer expires.
  local due=self.dueKeys
  local dueCount=0
  for k,v in pairs(self.delayed) do
    v.remaining = v.remaining - delta
    if v.remaining <= 0 then
      dueCount=dueCount+1
      due[dueCount]=k
    end
  end

  -- Due timers enter the same bounded FIFO as every other continuation. Keyed
  -- timers carry a monotonic token into the queue so a newer schedule can also
  -- invalidate an older callback that has already left the delayed table.
  local i
  for i=1,dueCount do
    local k=due[i]
    due[i]=nil
    local entry = self.delayed[k]
    self.delayed[k] = nil
    if entry and entry.fn then
      self:Enqueue(entry.fn,"timer:"..tostring(entry.label or k),entry.key,entry.token)
    end
  end
end

function S:Tick()
  local count=self:PendingCount()
  if count<=0 then return end

  local start=(GetTime and GetTime()) or 0
  local ran=0
  local limit=math.min(count,self.maxJobsPerFrame or 2)

  while ran<limit and self.queueHead<=self.queueTail do
    local index=self.queueHead
    local entry=self.queue[index]
    self.queue[index]=nil
    self.queueHead=index+1

    -- A missing/cancelled slot must never trap the scheduler in a while loop.
    -- Continue advancing the head even if an entry was somehow cleared.
    if entry and entry.fn then
      local stale=entry.timerKey and self.latestTimerToken[entry.timerKey]~=entry.timerToken
      if not stale then
        local jobStart=(GetTime and GetTime()) or start
        entry.fn()
        local jobEnd=(GetTime and GetTime()) or jobStart
        local elapsed=jobEnd-jobStart
        self.executed=self.executed+1
        ran=ran+1
        self.stats.lastLabel=entry.label or "unlabelled"
        if elapsed>(self.stats.slowestSeconds or 0) then
          self.stats.slowestSeconds=elapsed
          self.stats.slowestLabel=entry.label or "unlabelled"
        end
      end
    end

    if ran>=1 and GetTime and ((GetTime()-start)>=(self.maxSecondsPerFrame or 0.004)) then break end
  end

  if self.queueHead>self.queueTail then
    self.queue={}
    self.queueHead=1
    self.queueTail=0
  end

  local total=(GetTime and (GetTime()-start)) or 0
  self.stats.frames=(self.stats.frames or 0)+1
  if ran>(self.stats.maxJobsInFrame or 0) then self.stats.maxJobsInFrame=ran end
  if total>(self.stats.maxFrameSeconds or 0) then self.stats.maxFrameSeconds=total end
end

-- Native fullscreen World Map hides UIParent. Keep the logic scheduler under
-- WorldFrame so bounded queued/delayed work continues while full UI panels are shown.
local f=CreateFrame("Frame","QuestieOctoSchedulerFrame",WorldFrame)
f:SetScript("OnUpdate",function()
  local delta=arg1 or 0
  RunDelayed(S,delta)
  S.elapsed=0
  S:Tick()
end)
