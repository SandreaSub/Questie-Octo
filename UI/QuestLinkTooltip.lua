-- Quest hyperlink details for Vanilla/Turtle chat links.
--
-- pfQuest-classicAPI historically replaced the tiny native quest-link popup
-- with a full ItemRefTooltip containing the quest title, status, objective,
-- description and level requirements. Questie-Octo restores that presentation
-- while preserving Questie-Octo's Quest Log interaction contract:
--   * Shift + left-click on a Quest Log quest tracks/untracks it normally.
--   * If the chat edit box is open, the same Shift + left-click inserts a
--     clickable quest hyperlink instead, matching pfQuest's Vanilla behavior.
--
-- ItemRefTooltip is intentional: pfUI already skins that native tooltip frame,
-- while non-pfUI users retain the normal Blizzard ItemRefTooltip appearance.

QuestieOcto.QuestLinkTooltip = QuestieOcto.QuestLinkTooltip or {}
local Q=QuestieOcto.QuestLinkTooltip

Q.started=Q.started or false
Q.hooked=Q.hooked or false
Q.originalSetItemRef=Q.originalSetItemRef
Q.lastQuestLink=Q.lastQuestLink

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function FormatQuestText(text)
  if not text or text=="" then return nil end
  local player=(UnitName and UnitName("player")) or "adventurer"
  local race=(UnitRace and UnitRace("player")) or ""
  local class=(UnitClass and UnitClass("player")) or ""
  text=string.gsub(text,"%$N",player); text=string.gsub(text,"%$n",player)
  text=string.gsub(text,"%$R",race); text=string.gsub(text,"%$r",race)
  text=string.gsub(text,"%$C",class); text=string.gsub(text,"%$c",class)
  text=string.gsub(text,"%$B","\n"); text=string.gsub(text,"%$b","\n")
  return text
end

-- Vanilla GameTooltip can retain an oversized width while it is rebuilt in
-- place. The 1.18 tracker implementation exposed that by switching between
-- short and full quest text without first hiding the tooltip. Keep hover-only
-- quest prose bounded with explicit line breaks so GameTooltip, WorldMapTooltip
-- and pfUI's private map tooltip all receive the same safe text layout. Chat
-- ItemRefTooltip keeps its native wrapping because wrapChars is omitted there.
local function WrapQuestHoverText(text,wrapChars)
  local limit=tonumber(wrapChars)
  if not text or not limit or limit<20 then return text end

  local out={}
  local function AddWrappedLine(line)
    if line=="" then
      table.insert(out,"")
      return
    end

    local current=""
    for word in string.gfind(line,"%S+") do
      if current=="" then
        current=word
      elseif string.len(current)+1+string.len(word)<=limit then
        current=current.." "..word
      else
        table.insert(out,current)
        current=word
      end
    end
    if current~="" then table.insert(out,current) end
  end

  for line in string.gfind(text.."\n","(.-)\n") do
    AddWrappedLine(line)
  end

  return table.concat(out,"\n")
end

local function LinkTitle(text)
  if not text then return nil end
  local _,_,title=string.find(text,"|h%[(.-)%]|h")
  return title
end

local function ResolveQuestID(link,text)
  if type(link)~="string" then return nil end

  local _,_,id=string.find(link,"^quest:(%d+)")
  id=tonumber(id)
  if id and id>0 then return id end

  -- Older pfQuest/Turtle link formats can carry only a title (quest2:*).
  -- Resolve those by exact localized title, matching pfQuest's old behavior.
  local isQuest2=string.find(link,"^quest2:")
  if not isQuest2 then return nil end
  local wanted=LinkTitle(text)
  if not wanted or not QuestieOcto.DatabaseAPI or not QuestieOcto.DatabaseAPI:IsReady() then return nil end
  local ids=QuestieOcto.DatabaseAPI:GetQuestIDs()
  for i=1,table.getn(ids) do
    local questID=tonumber(ids[i])
    if questID and QuestieOcto.DatabaseAPI:GetQuestTitle(questID)==wanted then return questID end
  end
  return nil
end

local function IsQuestLink(link)
  if type(link)~="string" then return false end
  if string.find(link,"^quest:") then return true end
  if string.find(link,"^quest2:") then return true end
  return false
end

local function AnyModifierDown()
  if IsShiftKeyDown and IsShiftKeyDown() then return true end
  if IsControlKeyDown and IsControlKeyDown() then return true end
  if IsAltKeyDown and IsAltKeyDown() then return true end
  return false
end

local function DifficultyColor(level,questID)
  if QuestieOcto.GetNativeQuestDifficultyColor then
    local r,g,b=QuestieOcto:GetNativeQuestDifficultyColor(level,questID)
    if r then return r,g,b end
  end
  return 1,1,0
end

local function ClampByte(value)
  value=tonumber(value) or 0
  if value<0 then value=0 elseif value>1 then value=1 end
  return math.floor(value*255+0.5)
end

local function DifficultyHex(level,questID)
  local r,g,b=DifficultyColor(level,questID)
  return string.format("|cff%02x%02x%02x",ClampByte(r),ClampByte(g),ClampByte(b))
end

function Q:BuildQuestLink(questID,title,level)
  questID=tonumber(questID)
  if not questID or questID<=0 then return nil end

  level=tonumber(level) or 0
  if not title or title=="" then
    if QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:IsReady() then
      title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID)
    end
  end
  if not title or title=="" then title="Quest "..tostring(questID) end

  return DifficultyHex(level,questID).."|Hquest:"..tostring(questID)..":"..tostring(level).."|h["..tostring(title).."]|h|r"
end

function Q:InsertQuestLink(questID,title,level)
  if not ChatFrameEditBox or not ChatFrameEditBox.IsVisible or not ChatFrameEditBox:IsVisible() then return false end
  local link=self:BuildQuestLink(questID,title,level)
  if not link then return false end
  ChatFrameEditBox:Insert(link)
  return true
end

local function QuestStatus(questID)
  local active=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]
  if active then
    if active.complete then return "complete" end
    return "active"
  end

  -- Current availability must beat historical completion. A repeatable quest can
  -- legitimately be rewarded already and available again at the same time.
  -- 1.19 checked completion first, making those offers read as permanently
  -- completed in detailed quest tooltips.
  local available=QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.available and QuestieOcto.AvailableQuests.available[questID]
  if available then return "available" end

  local quest=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
  if quest and quest.repeatable then return "repeatable" end

  local completed=QuestieOcto.Completion and QuestieOcto.Completion.history and QuestieOcto.Completion.history[questID]
  if completed then return "completed" end
  return "unavailable"
end

local function AddStatusLine(tooltip,status,questID)
  local quest=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
  local repeatable=quest and quest.repeatable and true or false
  if status=="active" then
    tooltip:AddLine(repeatable and "You are on this repeatable quest." or "You are on this quest.",1,1,0.5)
  elseif status=="complete" then
    tooltip:AddLine(repeatable and "This repeatable quest is ready to turn in." or "This quest is ready to turn in.",0.5,1,0.5)
  elseif status=="completed" then
    tooltip:AddLine("You already completed this quest.",0.5,1,0.5)
  elseif status=="available" then
    tooltip:AddLine(repeatable and "This repeatable quest is available." or "This quest is available.",0.3,1,0.3)
  elseif status=="repeatable" then
    tooltip:AddLine("Repeatable quest.",0.35,0.65,1)
  else
    tooltip:AddLine("You don't have this quest.",1,0.5,0.5)
  end
end

local function AddLevelLine(tooltip,label,level,questID)
  level=tonumber(level)
  if not level or level<=0 then return end
  local r,g,b=DifficultyColor(level,questID)
  tooltip:AddLine(label..": "..tostring(level),r,g,b)
end

local function ObjectiveName(row)
  if not row or not QuestieOcto.DatabaseAPI then return nil end
  if row.kind=="creature" then return QuestieOcto.DatabaseAPI:GetCreatureName(row.id) end
  if row.kind=="gameObject" then return QuestieOcto.DatabaseAPI:GetObjectName(row.id) end
  if row.kind=="item" then return QuestieOcto.DatabaseAPI:GetItemName(row.id) end
  return nil
end

local function ObjectiveFallbackText(row)
  local name=ObjectiveName(row)
  if not name or name=="" then return nil end
  if row.kind=="creature" then return "Defeat "..name end
  if row.kind=="gameObject" then return "Interact with "..name end
  if row.kind=="item" then return "Collect "..name end
  return name
end

local function IsUsefulObjectiveName(name)
  if not name or name=="" then return false end
  local lower=string.lower(tostring(name))
  if string.find(lower,"dummy",1,true) or string.find(lower,"trigger",1,true)
     or string.find(lower,"triger",1,true) or string.find(lower,"quest_",1,true) then
    return false
  end
  if string.find(name,"^Creature %d+$") or string.find(name,"^Object %d+$")
     or string.find(name,"^Item %d+$") then return false end
  return true
end

local function FormatMoney(copper)
  copper=math.max(0,tonumber(copper) or 0)
  local gold=math.floor(copper/10000)
  local silver=math.floor(math.mod(copper,10000)/100)
  local coin=math.mod(copper,100)
  local out={}
  if gold>0 then table.insert(out,tostring(gold).."g") end
  if silver>0 or gold>0 then table.insert(out,tostring(silver).."s") end
  if coin>0 or table.getn(out)==0 then table.insert(out,tostring(coin).."c") end
  return table.concat(out," ")
end

-- Match the tracker objective presentation for active quests. The native
-- leaderboard text is authoritative once complete; if ClassicAPI reports the
-- numeric counters separately, synthesize them only when the text omitted them.
local function ActiveObjectiveText(objective)
  if not objective then return nil end
  local text=nil
  if objective.rawTextIncomplete then
    text=objective.text
    if not text or text=="" or text==objective.rawText then
      local current=tonumber(objective.current)
      local required=tonumber(objective.required)
      if current and required and required>0 then
        text=tostring(current).."/"..tostring(required)
      end
    end
  else
    text=objective.rawText or objective.text
  end
  if not text or text=="" then return nil end

  local current=tonumber(objective.current)
  local required=tonumber(objective.required)
  if current and required and required>0 and not string.find(text,"%d+%s*/%s*%d+") then
    text=tostring(current).."/"..tostring(required).." "..text
  end
  text=FormatQuestText(text) or text
  text=string.gsub(text,"^%-%s*","")
  return text
end

local function StructuredObjectiveRows(quest)
  local rows={}
  local hasRequired=false
  for i=1,table.getn(quest.objectiveData or {}) do
    local objective=quest.objectiveData[i]
    local name=ObjectiveName(objective)
    if IsUsefulObjectiveName(name) then
      local required=tonumber(objective.required)
      if required and required>0 then
        rows[table.getn(rows)+1]=tostring(name)..": "..tostring(required).." required"
        hasRequired=true
      else
        local fallback=ObjectiveFallbackText(objective)
        if fallback then rows[table.getn(rows)+1]=fallback end
      end
    end
  end
  return rows,hasRequired
end

local function TrackerObjectiveLine(text,wrapChars)
  local wrapped=WrapQuestHoverText(text,wrapChars) or ""
  -- Preserve a hanging indent when our explicit safe wrap is needed. Without
  -- this, continuation lines start at the tooltip edge instead of underneath
  -- the objective text, which is what made long 1.21 travel objectives look
  -- uneven on the World Map.
  wrapped=string.gsub(wrapped,"\n","\n  ")
  return "- "..wrapped
end

local function AddCompactObjectives(tooltip,questID,quest,wrapChars)
  local rows={}
  local active=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]
  if active and active.objectives and table.getn(active.objectives)>0 then
    for i=1,table.getn(active.objectives) do
      local text=ActiveObjectiveText(active.objectives[i])
      if text and text~="" then rows[table.getn(rows)+1]=text end
    end
  else
    -- Available/non-active quests do not have live leaderboard counters. Prefer
    -- structured objective rows when the supplied server quest_template gives
    -- authoritative required amounts (e.g. Fashion Demands Sacrifices). This
    -- avoids inventing 0/N progress before the quest has actually been accepted.
    local structured,hasRequired=StructuredObjectiveRows(quest)
    local authored=FormatQuestText(quest.objectiveText)
    if hasRequired then
      rows=structured
    elseif table.getn(structured)>0 then
      if not authored or authored=="" then rows=structured else rows[1]=authored end
    else
      -- Keep the authored objective wording for travel/talk quests as well.
      -- The immersive quest sentence is more useful than reducing it to a
      -- generic "Speak with <NPC>" destination; layout is handled below.
      if authored and authored~="" then rows[1]=authored end
    end
  end

  if table.getn(rows)==0 then return false end
  for i=1,table.getn(rows) do
    -- TrackerObjectiveLine already inserts explicit safe line breaks and a
    -- hanging indent. Do not ask GameTooltip to wrap that text a second time:
    -- Vanilla can reflow an already-wrapped continuation into short fragments
    -- (for example "wife on" / "Balor ..."), which caused the awkward
    -- travel-objective layout reported against 1.21/1.22.
    tooltip:AddLine(TrackerObjectiveLine(rows[i],wrapChars),1,1,1,false)
  end
  return true
end

local function AddRewardItemLine(tooltip,entry,prefix)
  if not entry then return false end
  local itemID=tonumber(entry[1])
  local count=math.max(1,tonumber(entry[2]) or 1)
  if not itemID then return false end
  local name=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:GetItemName(itemID) or nil
  if not name or name=="" then name="Item "..tostring(itemID) end
  local suffix=count>1 and (" x"..tostring(count)) or ""
  tooltip:AddLine((prefix or "- ")..name..suffix,0.3,1,0.3,true)
  return true
end

local function AddCompactRewards(tooltip,questID,rewards)
  if not rewards then
    if not QuestieOcto.DatabaseAPI or not QuestieOcto.DatabaseAPI.GetQuestRewards then return false end
    rewards=QuestieOcto.DatabaseAPI:GetQuestRewards(questID)
  end
  if not rewards then return false end

  local money=math.max(0,tonumber(rewards.money) or 0)
  local maxBonus=math.max(0,tonumber(rewards.maxLevelMoney) or 0)
  local playerLevel=(UnitLevel and UnitLevel("player")) or 1
  local maxLevel=tonumber(MAX_PLAYER_LEVEL) or 60
  if playerLevel>=maxLevel then money=money+maxBonus end
  local items=rewards.items or {}
  local choices=rewards.choices or {}
  local hasItems=table.getn(items)>0
  local hasChoices=table.getn(choices)>0
  if money<=0 and not hasItems and not hasChoices then return false end

  tooltip:AddLine("Rewards",1,0.82,0)
  if money>0 then tooltip:AddLine("- Money: "..FormatMoney(money),1,1,1) end
  for i=1,table.getn(items) do AddRewardItemLine(tooltip,items[i],nil) end
  if hasChoices then
    tooltip:AddLine("Choose one:",0.8,0.8,0.8)
    for i=1,table.getn(choices) do AddRewardItemLine(tooltip,choices[i],"- ") end
  end
  return true
end

local function HoverQuestTitle(questID,quest,text)
  local title=quest.title or LinkTitle(text) or ("Quest "..tostring(questID))
  local settings=Settings()
  if not settings or not settings.Get or not settings:Get("enableTooltipsQuestLevel") then return title end
  local level=tonumber(quest.level) or 0
  if level<=0 then return title end
  local active=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]
  local nativeTag=active and active.tag or nil
  local plus=QuestieOcto.QuestModel and QuestieOcto.QuestModel.HasLevelPlus
    and QuestieOcto.QuestModel:HasLevelPlus(questID,nativeTag) or false
  return "["..tostring(level)..(plus and "+" or "").."] "..title
end

-- Compact transient view for World Map/minimap Shift-hover. Tracker rows already
-- show live objectives and deliberately keep their ordinary interaction tooltip.
-- Chat hyperlinks keep PopulateQuestTooltip() below, which remains more verbose.
function Q:PopulateQuestHoverTooltip(tooltip,questID,text,wrapChars)
  questID=tonumber(questID)
  if not tooltip or not questID or questID<=0 or not QuestieOcto.QuestModel then return false end
  local quest=QuestieOcto.QuestModel:Get(questID)
  if not quest then return false end

  local title=HoverQuestTitle(questID,quest,text)
  local r,g,b=DifficultyColor(quest.level,questID)
  tooltip:AddLine(title,r,g,b)

  local hasObjectives=AddCompactObjectives(tooltip,questID,quest,wrapChars)
  local rewards=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestRewards and QuestieOcto.DatabaseAPI:GetQuestRewards(questID) or nil
  local hasRewardData=false
  if rewards then
    local money=math.max(0,tonumber(rewards.money) or 0)
    local maxBonus=math.max(0,tonumber(rewards.maxLevelMoney) or 0)
    local playerLevel=(UnitLevel and UnitLevel("player")) or 1
    local maxLevel=tonumber(MAX_PLAYER_LEVEL) or 60
    if playerLevel>=maxLevel then money=money+maxBonus end
    hasRewardData=money>0 or table.getn(rewards.items or {})>0 or table.getn(rewards.choices or {})>0
  end

  if hasObjectives and hasRewardData then tooltip:AddLine(" ",0,0,0) end
  if hasRewardData then AddCompactRewards(tooltip,questID,rewards) end

  return true
end

function Q:PopulateQuestTooltip(tooltip,questID,text,wrapChars)
  questID=tonumber(questID)
  if not tooltip or not questID or questID<=0 then return false end
  if not QuestieOcto.QuestModel then return false end

  local quest=QuestieOcto.QuestModel:Get(questID)
  if not quest then return false end

  local title=quest.title or LinkTitle(text) or ("Quest "..tostring(questID))
  local r,g,b=DifficultyColor(quest.level,questID)
  tooltip:AddLine(title,r,g,b)
  AddStatusLine(tooltip,QuestStatus(questID),questID)

  local objective=WrapQuestHoverText(FormatQuestText(quest.objectiveText),wrapChars)
  local description=WrapQuestHoverText(FormatQuestText(quest.descriptionText),wrapChars)
  if objective then
    tooltip:AddLine(" ",0,0,0)
    tooltip:AddLine(objective,1,1,1,true)
  end
  if description then
    tooltip:AddLine(" ",0,0,0)
    tooltip:AddLine(description,0.8,0.8,0.8,true)
  end

  if (quest.requiredLevel and tonumber(quest.requiredLevel)>0) or (quest.level and tonumber(quest.level)>0) then
    tooltip:AddLine(" ",0,0,0)
    AddLevelLine(tooltip,"Required Level",quest.requiredLevel,questID)
    AddLevelLine(tooltip,"Quest Level",quest.level,questID)
  end

  if Settings() and Settings().Get and Settings():Get("enableTooltipsQuestID") then
    tooltip:AddLine("Quest ID: "..tostring(questID),0.65,0.65,0.65)
  end

  return true
end

function Q:ShowQuest(questID,text)
  questID=tonumber(questID)
  if not questID or questID<=0 or not ItemRefTooltip then return false end
  if not QuestieOcto.QuestModel or not QuestieOcto.QuestModel:Get(questID) then return false end

  local signature="quest:"..tostring(questID)
  if ItemRefTooltip:IsShown() and self.lastQuestLink==signature then
    if HideUIPanel then HideUIPanel(ItemRefTooltip) else ItemRefTooltip:Hide() end
    self.lastQuestLink=nil
    return true
  end

  if ItemRefTooltip.ClearLines then ItemRefTooltip:ClearLines() end
  if ShowUIPanel then ShowUIPanel(ItemRefTooltip) end
  if ItemRefTooltip.SetOwner then ItemRefTooltip:SetOwner(UIParent,"ANCHOR_PRESERVE") end
  if not self:PopulateQuestTooltip(ItemRefTooltip,questID,text) then return false end

  ItemRefTooltip:Show()
  self.lastQuestLink=signature
  return true
end

-- The stock Vanilla ItemRefTooltip:SetHyperlink() does not accept quest: or
-- quest2: links. A hooksecurefunc("SetItemRef", ...) callback runs *after* the
-- stock function, which already throws "Unknown link type" on those links.
-- Own just quest-link clicks before the stock handler; forward every other
-- hyperlink unchanged to the existing Blizzard/pfUI/other-addon wrapper chain.
function Q:ShowUnavailableQuest(link,text)
  if not ItemRefTooltip then return end
  self.lastQuestLink=nil
  if ItemRefTooltip.ClearLines then ItemRefTooltip:ClearLines() end
  if ShowUIPanel then ShowUIPanel(ItemRefTooltip) end
  if ItemRefTooltip.SetOwner then ItemRefTooltip:SetOwner(UIParent,"ANCHOR_PRESERVE") end
  local title=LinkTitle(text) or "Quest"
  ItemRefTooltip:AddLine(title,1,0.82,0)
  ItemRefTooltip:AddLine("Quest details are not available in Questie-Octo.",0.8,0.8,0.8,true)
  local _,_,rawID=string.find(link,"^quest:(%d+)")
  local questID=tonumber(rawID)
  if questID then ItemRefTooltip:AddLine("Quest ID: "..tostring(questID),0.65,0.65,0.65) end
  ItemRefTooltip:Show()
end

function Q:HandleSetItemRef(link,text,button)
  if not IsQuestLink(link) then
    -- A normal item/player/etc. hyperlink replaces ItemRefTooltip ownership.
    self.lastQuestLink=nil
    return false
  end

  -- Never send a quest hyperlink into the stock ItemRefTooltip:SetHyperlink,
  -- even when the quest isn't in our DB or a modifier is held.
  if IsControlKeyDown and IsControlKeyDown() then return true end
  if IsShiftKeyDown and IsShiftKeyDown() then
    if ChatFrameEditBox and ChatFrameEditBox.IsVisible and ChatFrameEditBox:IsVisible() then
      ChatFrameEditBox:Insert(text or "")
    end
    return true
  end

  if button and button~="LeftButton" and button~="RightButton" then return true end
  local questID=ResolveQuestID(link,text)
  if questID and self:ShowQuest(questID,text) then return true end
  self:ShowUnavailableQuest(link,text)
  return true
end

function Q:InstallHook()
  if self.hooked or type(SetItemRef)~="function" then return end

  -- Pre-dispatch wrapper is required, not a secure post-hook: the latter cannot
  -- prevent the native "Unknown link type" exception. Capturing the current
  -- function preserves earlier pfUI wrappers; later pfUI wrappers also preserve
  -- us because they forward to the captured SetItemRef function.
  local original=SetItemRef
  self.originalSetItemRef=original
  SetItemRef=function(link,text,button)
    if Q:HandleSetItemRef(link,text,button) then return end
    return original(link,text,button)
  end
  self.hookMode="wrapper"
  self.hooked=true
end

function Q:Start()
  if self.started then return end
  self.started=true
  self:InstallHook()
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",Q,"Start")
