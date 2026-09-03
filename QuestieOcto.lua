-- Questie-Octo
QuestieOcto = QuestieOcto or {}
local QO = QuestieOcto

QO.version = "1.0.94"
QO.enabled = false
QO.ready = false
-- Release packages use Questie-Octo's private compiled runtime database.
-- Set false only in an explicit developer/source build that loads Data/pfDB.
QO.useCompiledRuntime = true
QO.messages = {}
QO.startedAt = 0
QO.fileLoadStartedAt = GetTime and GetTime() or 0
QO.fileLoadFinishedAt = 0
QO.foundationReadyAt = 0

-- Turtle/Vanilla is authoritative for quest difficulty colors.  Questie-Octo
-- deliberately does not reproduce Questie level-band thresholds here.
local function RGBFromDifficultyFunction(level)
  local fn=GetDifficultyColor or GetQuestDifficultyColor
  if type(fn)~="function" then return nil,nil,nil end
  local ok,a,b,c=pcall(fn,tonumber(level) or 0)
  if not ok then return nil,nil,nil end
  if type(a)=="table" then
    return tonumber(a.r),tonumber(a.g),tonumber(a.b)
  end
  if tonumber(a) and tonumber(b) and tonumber(c) then
    return tonumber(a),tonumber(b),tonumber(c)
  end
  return nil,nil,nil
end

local function SameRGB(r,g,b,color)
  if not color then return false end
  local cr,cg,cb=tonumber(color.r),tonumber(color.g),tonumber(color.b)
  if not r or not g or not b or not cr or not cg or not cb then return false end
  return math.abs(r-cr)<0.01 and math.abs(g-cg)<0.01 and math.abs(b-cb)<0.01
end

function QO:GetNativeQuestDifficultyColor(level,questID)
  -- First authority: the actual color Turtle's native QuestLog_Update stored on
  -- this quest's Blizzard title button. QuestLogEnhancements caches that value
  -- before it changes the displayed text. This remains independent of skins.
  local qle=self.QuestLogEnhancements
  if qle and qle.GetCachedQuestColor and questID then
    local r,g,b=qle:GetCachedQuestColor(questID)
    if r then return r,g,b end
  end

  local r,g,b=RGBFromDifficultyFunction(level)
  if not r then return nil,nil,nil end

  -- Turtle/Octo keeps quests in the easy/green presentation instead of letting
  -- the stock trivial band turn gray. ClassicAPI can expose stock 1.12's
  -- GetDifficultyColor(), so normalize only that one band as a fallback until
  -- the native Quest Log color for this quest has been observed and cached.
  if QuestDifficultyColor and SameRGB(r,g,b,QuestDifficultyColor["trivial"]) then
    local standard=QuestDifficultyColor["standard"]
    if standard and standard.r then
      return tonumber(standard.r),tonumber(standard.g),tonumber(standard.b)
    end
  end
  return r,g,b
end

function QO:Print(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccQuestie-Octo|r: "..tostring(text))
  end
end

function QO:Error(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Questie-Octo ERROR|r: "..tostring(text))
  end
end

function QO:RegisterMessage(name, owner, method)
  if not name or not owner or not method then return end
  self.messages[name] = self.messages[name] or {}
  table.insert(self.messages[name], { owner=owner, method=method })
end

function QO:SendMessage(name, ...)
  local list = self.messages[name]
  if not list then return end

  -- Lua 5.0 exposes varargs through the implicit 'arg' table.
  for _,entry in pairs(list) do
    local fn = entry.owner[entry.method]
    if fn then
      fn(entry.owner, unpack(arg))
    end
  end
end
