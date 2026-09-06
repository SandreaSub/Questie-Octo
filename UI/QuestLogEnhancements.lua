-- Native Quest Log presentation enhancements for Vanilla/Turtle 1.12.
--
-- Backport trace:
--   Questie 5.2.3/6.0.0: quest-log title click interception for tracking.
--   Questie 3.3.5: primary compatibility semantics for quest-log/tracker state.
--   Questie 7/8: keep quest-log refresh authoritative after interactions.
--
-- Those Questie versions do not contain a transferable Vanilla visual restyle.
-- For the missing presentation mechanic only, Vanilla UI compatibility
-- references confirm the safe approach: post-process the existing Blizzard
-- QuestLogTitle1..N rows after their native update instead of skinning/replacing
-- the Quest Log. This preserves Blizzard UI, ShaguTweaks and pfUI appearance.

QuestieOcto.QuestLogEnhancements = QuestieOcto.QuestLogEnhancements or {}
local Q=QuestieOcto.QuestLogEnhancements

Q.started=false
Q.hooked=false
Q.originalUpdate=nil
Q.eventFrame=nil
Q.lastOffset=nil
Q.refreshPending=false
Q.nativeQuestColors=Q.nativeQuestColors or {}

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function GetTitleButton(i)
  if getglobal then return getglobal("QuestLogTitle"..tostring(i)) end
  if _G then return _G["QuestLogTitle"..tostring(i)] end
  return nil
end

local function GetButtonFontString(button)
  if not button then return nil end
  if button.GetFontString then
    local ok,fs=pcall(button.GetFontString,button)
    if ok and fs then return fs end
  end
  if button.GetName then
    local name=button:GetName()
    if name and getglobal then
      return getglobal(name.."NormalText") or getglobal(name.."Text")
    end
  end
  return nil
end

local function GetButtonRegion(button,suffix)
  if not button or not button.GetName or not getglobal then return nil end
  local name=button:GetName()
  if not name then return nil end
  return getglobal(name..suffix)
end

local function RefreshVoiceOverQuestOverlay()
  -- VoiceOver reserves space for its Quest Log play button by prefixing the
  -- native quest title after QuestLog_Update. Questie-Octo intentionally
  -- rebuilds that same title when adding [level], so re-run VoiceOver's own
  -- overlay pass after our rows are finished instead of guessing its spacing
  -- or moving its buttons ourselves. The lookup is dynamic so either addon
  -- may load first.
  local voiceOver=nil
  if getglobal then voiceOver=getglobal("VoiceOver") end
  if not voiceOver and _G then voiceOver=_G.VoiceOver end
  local overlay=voiceOver and voiceOver.QuestOverlayUI
  if not overlay or type(overlay.Update)~="function" then return end
  pcall(overlay.Update,overlay)
end

local function ApplyTrackerCheck(button,index,questID)
  local check=GetButtonRegion(button,"Check")
  if not check then return end

  -- Turtle's native QuestLog_Update owns this exact UI-CheckBox-Check region
  -- and normally shows it through IsQuestWatched(). Questie-Octo keeps its
  -- own tracker state to avoid Blizzard's native watch limit, so restore the
  -- native visual check after the Blizzard row has been updated instead of
  -- replacing the Quest Log skin or its artwork.
  check:Hide()
  if not Settings():Get("trackerQuestLogCheckmarks") then return end

  local driver=QuestieOcto.TrackerDriver
  if not driver or not driver.IsTracked or not questID or not driver:IsTracked(questID) then return end

  local fs=GetButtonFontString(button)
  if not fs then return end

  local textWidth=nil
  if fs.GetStringWidth then
    local ok,w=pcall(fs.GetStringWidth,fs)
    if ok then textWidth=tonumber(w) end
  end
  if not textWidth and fs.GetWidth then
    local ok,w=pcall(fs.GetWidth,fs)
    if ok then textWidth=tonumber(w) end
  end
  textWidth=textWidth or 0

  -- QuestLogTitleButtonTemplate anchors its text 20 px from the row's left
  -- edge. The native code places the check roughly four pixels after a short
  -- title and caps it near the right edge for long/tagged titles. Recompute
  -- that position after Questie-Octo adds the [level] prefix so the restored
  -- check does not sit inside the modified title.
  local x=textWidth+24
  if x>270 then x=270 end
  if x<24 then x=24 end
  if check.ClearAllPoints then check:ClearAllPoints() end
  check:SetPoint("LEFT",button,"LEFT",x,0)
  check:Show()
end


local function CacheNativeQuestColor(button,index)
  if not button or not index or index<1 then return end
  local r,g,b
  -- Vanilla QuestLog_Update stores its chosen color directly on the title
  -- button (button.r/g/b). Prefer that over the FontString so UI skins cannot
  -- accidentally become the gameplay color source.
  if tonumber(button.r) and tonumber(button.g) and tonumber(button.b) then
    r,g,b=tonumber(button.r),tonumber(button.g),tonumber(button.b)
  else
    local fs=GetButtonFontString(button)
    if fs and fs.GetTextColor then
      local ok,fr,fg,fb=pcall(fs.GetTextColor,fs)
      if ok then r,g,b=tonumber(fr),tonumber(fg),tonumber(fb) end
    end
  end
  if not r then return end
  local questID
  if QuestieOcto.API and QuestieOcto.API.GetQuestIDForLogIndex then
    questID=QuestieOcto.API:GetQuestIDForLogIndex(index)
  end
  if questID and tonumber(questID) and tonumber(questID)>0 then
    Q.nativeQuestColors[tonumber(questID)]={r=r,g=g,b=b}
  end
end

function Q:GetCachedQuestColor(questID)
  local c=self.nativeQuestColors and self.nativeQuestColors[tonumber(questID)]
  if not c then return nil,nil,nil end
  return c.r,c.g,c.b
end

local function ApplyHeaderFont(button)
  local fs=GetButtonFontString(button)
  if not fs or not fs.SetFont or not fs.GetFont then return end

  local currentFont,currentSize,currentFlags=fs:GetFont()
  currentFont=currentFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  currentSize=tonumber(currentSize) or 12
  currentFlags=currentFlags or ""

  -- Questie-Octo does not own the skin. Capture whatever Blizzard/pfUI/
  -- ShaguTweaks supplied, then change only the size by +1. If another UI
  -- addon restyles the row later, adopt that new style instead of fighting it.
  local expectedSize=fs.questieOctoBaseSize and (fs.questieOctoBaseSize+1) or nil
  local externalChange=not fs.questieOctoHeaderStyled
    or currentFont~=fs.questieOctoBaseFont
    or currentFlags~=(fs.questieOctoBaseFlags or "")
    or (expectedSize and math.abs(currentSize-expectedSize)>0.01)

  if externalChange then
    fs.questieOctoBaseFont=currentFont
    fs.questieOctoBaseSize=currentSize
    fs.questieOctoBaseFlags=currentFlags
  end

  fs:SetFont(fs.questieOctoBaseFont,fs.questieOctoBaseSize+1,fs.questieOctoBaseFlags or "")
  fs.questieOctoHeaderStyled=true
end

local function RestoreQuestFont(button)
  local fs=GetButtonFontString(button)
  if not fs or not fs.SetFont then return end

  -- Only restore a font when this pooled Blizzard row was previously used as
  -- a zone header by Questie-Octo. Otherwise leave the active UI skin alone.
  if fs.questieOctoHeaderStyled and fs.questieOctoBaseFont and fs.questieOctoBaseSize then
    fs:SetFont(fs.questieOctoBaseFont,fs.questieOctoBaseSize,fs.questieOctoBaseFlags or "")
  end
  fs.questieOctoHeaderStyled=nil
end

local function StyleButton(button,index)
  if not button or not index or index<1 or type(GetQuestLogTitle)~="function" then return end

  -- Work from the native visible log entry. This keeps the enhancement
  -- independent of whichever addon is skinning the Blizzard Quest Log rows.
  local title,level,tag,isHeader=GetQuestLogTitle(index)
  if not title then return end

  if isHeader then
    ApplyHeaderFont(button)
    local fs=GetButtonFontString(button)
    if fs then fs.questieOctoHeaderStyled=true end
    local check=GetButtonRegion(button,"Check")
    if check then check:Hide() end
    return
  end

  -- Capture Turtle/OctoWoW's native row color before Questie-Octo changes
  -- the displayed title. Do not repaint the Quest Log afterward.
  CacheNativeQuestColor(button,index)
  RestoreQuestFont(button)

  local nativeTitle=title
  local questID
  if QuestieOcto.API and QuestieOcto.API.GetQuestIDForLogIndex then
    questID=QuestieOcto.API:GetQuestIDForLogIndex(index)
  end
  if questID and QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestTitle then
    title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID) or nativeTitle
  end

  local text=title
  if Settings():Get("questLogShowLevels") then
    local numericLevel=tonumber(level)
    local levelText=numericLevel and tostring(numericLevel) or "??"
    local hasLevelPlus=(tag and tag~="") and true or false
    if QuestieOcto.QuestModel and QuestieOcto.QuestModel.HasLevelPlus then
      hasLevelPlus=QuestieOcto.QuestModel:HasLevelPlus(questID,tag)
    end
    local groupTag=hasLevelPlus and "+" or ""
    text="["..levelText..groupTag.."] "..title
  end
  if button.SetText then button:SetText(text) end

  -- Difficulty color is intentionally left untouched. The native Quest Log
  -- already painted this row according to the Turtle/OctoWoW client rules.

  -- Let Blizzard resize its own clickable row after the text change.
  if QuestLogTitleButton_Resize then
    pcall(QuestLogTitleButton_Resize,button)
  end

  ApplyTrackerCheck(button,index,questID)
end

function Q:Refresh()
  if not QuestLogFrame or not QuestLogFrame:IsShown() then return end

  local displayed=tonumber(QUESTS_DISPLAYED) or tonumber(QUESTLOG_QUESTS_DISPLAYED) or 6
  local offset=0
  if FauxScrollFrame_GetOffset and QuestLogListScrollFrame then
    offset=FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
  end

  for i=1,displayed do
    local button=GetTitleButton(i)
    if button and button:IsShown() then StyleButton(button,i+offset) end
  end

  -- Questie-Octo has now finalized its [level] text and native check state.
  -- Let VoiceOver re-apply only its own play-button spacing/placement last.
  RefreshVoiceOverQuestOverlay()
end

function Q:ScheduleRefresh()
  if self.refreshPending then return end
  self.refreshPending=true
  if QuestieOcto.Scheduler and QuestieOcto.Scheduler.After then
    QuestieOcto.Scheduler:After(0,function()
      Q.refreshPending=false
      Q:Refresh()
    end,"questlog-enhancement-refresh")
  else
    self.refreshPending=false
    self:Refresh()
  end
end

function Q:InstallVisibilityWatcher()
  if self.eventFrame then return end
  local frame=CreateFrame("Frame","QuestieOctoQuestLogEnhancementWatcher",UIParent)
  self.eventFrame=frame
  frame:RegisterEvent("QUEST_LOG_UPDATE")
  frame:SetScript("OnEvent",function()
    Q:ScheduleRefresh()
  end)

  -- Some Vanilla/Turtle quest-log scroll paths retain an older update
  -- function reference. Watch only the scroll offset while the log is open;
  -- this adds no work while the Quest Log is closed and avoids replacing
  -- Blizzard's scrolling behavior.
  frame:SetScript("OnUpdate",function()
    if not QuestLogFrame or not QuestLogFrame:IsShown() then
      Q.lastOffset=nil
      return
    end
    local offset=0
    if FauxScrollFrame_GetOffset and QuestLogListScrollFrame then
      offset=FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
    end
    if Q.lastOffset~=offset then
      Q.lastOffset=offset
      Q:ScheduleRefresh()
    end
    if not Q.hooked then Q:InstallHook() end
  end)

  if QuestLogFrame and QuestLogFrame.GetScript and QuestLogFrame.SetScript then
    local originalOnShow=QuestLogFrame:GetScript("OnShow")
    QuestLogFrame:SetScript("OnShow",function()
      if originalOnShow then originalOnShow() end
      Q:ScheduleRefresh()
    end)
  end
end

function Q:InstallHook()
  if self.hooked or type(QuestLog_Update)~="function" then return end
  local original=QuestLog_Update
  self.originalUpdate=original

  QuestLog_Update=function()
    local result=original()
    Q:ScheduleRefresh()
    return result
  end

  -- Vanilla FauxScrollFrame can retain an older update function reference.
  if QuestLogScrollFrame then QuestLogScrollFrame.update=QuestLog_Update end

  self.hooked=true
end

function Q:Start()
  if self.started then return end
  self.started=true
  self:InstallHook()
  self:InstallVisibilityWatcher()
  -- Tracker state can change without a native QUEST_LOG_UPDATE (for example
  -- when toggled from Questie-Octo settings). Keep the native row checkmarks
  -- synchronized with the addon tracker state in those cases too.
  QuestieOcto:RegisterMessage("TRACKER_STATE_CHANGED",self,"ScheduleRefresh")
  QuestieOcto:RegisterMessage("TRACKER_SETTING_CHANGED",self,"ScheduleRefresh")
  self:ScheduleRefresh()
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",Q,"Start")
