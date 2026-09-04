-- Questie-Octo visual quest/objective tracker.
--
-- Backport lineage:
--   Questie 5.2.3/6.0.0: simple tracker presentation and quest title interactions.
--   Questie 3.3.5: TrackerBaseFrame/Header/QuestFrame separation, movable/resizable
--   shell, zone grouping and saved geometry. This is the primary implementation bridge.
--   Questie 7/8: renderer consumes cached quest state and rebuilds presentation only.
--
-- Vanilla/Turtle adaptation: native 1.12 frames/scrollframe only; no modern mixins.

QuestieOcto.TrackerFrame = QuestieOcto.TrackerFrame or {}
local T=QuestieOcto.TrackerFrame

T.started=false
T.frame=nil
T.header=nil
T.scroll=nil
T.content=nil
T.rows={}
T.rowCount=0
T.topRow=1
T.timerRows={}
T.timerElapsed=0
T.defaultWidth=280
T.defaultHeight=420
T.defaultVisibleRows=18
T.minVisibleRows=6
T.maxVisibleRows=60
T.frameVerticalChrome=38
T.minWidth=100
T.minHeight=100
T.maxWidth=2000
T.maxHeight=2000
T.padding=8
T.autoFitMinWidth=100
T.autoFitMaxWidth=280
T.contextMenu=nil
T.contextQuest=nil
T.contextObjectives={}

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function CharacterDB()
  QuestieOctoDB=QuestieOctoDB or {}
  QuestieOctoDB.tracker=QuestieOctoDB.tracker or {}
  local db=QuestieOctoDB.tracker
  db.window=db.window or {}
  if db.expanded==nil then db.expanded=true end
  if db.topRow==nil then db.topRow=1 end
  return db
end

local function Clamp(v,minv,maxv)
  v=tonumber(v) or minv
  if v<minv then return minv end
  if v>maxv then return maxv end
  return v
end

local function GetScreenBounds()
  local width=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1024
  local height=(UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
  return math.max(T.minWidth,width-20),math.max(T.minHeight,height-20)
end

function T:AnchorTopRightAtCurrentPosition()
  if not self.frame or not UIParent then return end
  local right=self.frame.GetRight and self.frame:GetRight()
  local top=self.frame.GetTop and self.frame:GetTop()
  local parentRight=UIParent.GetRight and UIParent:GetRight()
  local parentTop=UIParent.GetTop and UIParent:GetTop()
  if not right or not top or not parentRight or not parentTop then return end

  local x=right-parentRight
  local y=top-parentTop
  self.frame:ClearAllPoints()
  self.frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",x,y)
end

function T:SaveGeometry()
  if not self.frame then return end
  -- The tracker is intentionally normalized to TOPRIGHT after user movement.
  -- This keeps its right/top edge fixed when auto-fit changes width later.
  self:AnchorTopRightAtCurrentPosition()

  local db=CharacterDB()
  local point,relativeTo,relativePoint,x,y=self.frame:GetPoint(1)
  db.window.point=point or "TOPRIGHT"
  db.window.relativePoint=relativePoint or point or "TOPRIGHT"
  db.window.x=tonumber(x) or -30
  db.window.y=tonumber(y) or -180
  -- Width and height are content/settings-driven; placement stores only anchor offsets.
end

function T:RestoreGeometry()
  if not self.frame then return end
  local db=CharacterDB()
  local window=db.window
  self.frame:SetWidth(self.defaultWidth)
  self.frame:SetHeight(self.defaultHeight)
  self.frame:ClearAllPoints()

  -- New tracker placement is always TOPRIGHT so content-driven width changes
  -- expand to the left and never move the player's chosen right/top edge.
  -- Existing TOPRIGHT saves carry over directly; other legacy anchors fall
  -- back to the normal Questie placement once and are then saved canonically.
  local x=tonumber(window.x)
  local y=tonumber(window.y)
  if window.point~="TOPRIGHT" or window.relativePoint~="TOPRIGHT" then
    x=-30
    y=-180
  end
  if x==nil then x=-30 end
  if y==nil then y=-180 end
  self.frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",x,y)
end

-- Tracker scrolling is row-based rather than pixel-based on Vanilla. Persist the
-- first visible row per character so /reload and login restore the same page.
-- Keeping this state beside the existing tracker geometry/expanded state also
-- avoids a second SavedVariables path that could disagree with the renderer.
function T:SaveScrollPosition()
  local db=CharacterDB()
  local top=tonumber(self.topRow) or 1
  if top<1 then top=1 end
  db.topRow=math.floor(top+0.5)
end

function T:RestoreScrollPosition()
  local db=CharacterDB()
  local top=tonumber(db.topRow) or 1
  if top<1 then top=1 end
  self.topRow=math.floor(top+0.5)
end

local function SetFont(fs,size,r,g,b)
  if not fs then return end
  local font=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  local flags=""
  if Settings():Get("trackerThickOutlineText") then
    flags="THICKOUTLINE"
  elseif Settings():Get("trackerOutlineText") then
    flags="OUTLINE"
  end
  fs:SetFont(font,size or 10,flags)
  if r then fs:SetTextColor(r,g,b) end
end

function T:AutoFitWidth()
  if not self.frame then return self.defaultWidth,self.defaultWidth-16 end

  -- pfQuest's proven Vanilla technique: measure the actual FontStrings that
  -- are already being rendered at their natural one-line width. Questie-Octo
  -- then applies the player-selected practical tracker cap (280px by default).
  -- Long quest/objective text is wrapped during the second layout pass instead
  -- of being allowed to stretch the entire tracker across the screen.
  local longest=0
  for i=1,self.rowCount do
    local row=self.rows[i]
    if row and row:IsShown() and row.text and row.text.GetStringWidth then
      local indent=tonumber(row.textIndent) or 0
      local width=tonumber(row.text:GetStringWidth()) or 0
      width=width+indent
      if width>longest then longest=width end
    end
  end

  local screenW=GetScreenBounds()
  -- Scroll area begins 8px inside the frame. Add another 8px of breathing
  -- room after the longest rendered line. The fixed TOPRIGHT anchor means
  -- this width change grows/shrinks leftward without moving the right edge.
  local frameWidth=longest+16
  local configuredMax=tonumber(Settings():Get("trackerMaxWidth")) or self.autoFitMaxWidth or 280
  configuredMax=Clamp(configuredMax,200,500)
  local maxWidth=math.min(configuredMax,screenW)
  frameWidth=Clamp(frameWidth,self.autoFitMinWidth,maxWidth)
  local scrollWidth=math.max(1,frameWidth-16)
  local contentWidth=scrollWidth

  self.frame:SetWidth(frameWidth)
  if self.scroll and self.scroll.SetWidth then self.scroll:SetWidth(scrollWidth) end
  if self.content and self.content.SetWidth then self.content:SetWidth(contentWidth) end
  return frameWidth,contentWidth
end

function T:GetVisibleRowsSetting()
  local value=tonumber(Settings():Get("trackerVisibleRows")) or self.defaultVisibleRows
  return math.floor(Clamp(value,self.minVisibleRows,self.maxVisibleRows)+0.5)
end

function T:ApplyVisibleRowsHeight()
  if not self.frame or not self.scroll then return end

  local wanted=self:GetVisibleRowsSetting()
  local available=math.min(wanted,self.rowCount)
  if available<1 then available=1 end

  -- Use the tallest actual consecutive page of up to the requested row count.
  -- The frame therefore has one stable, safe pixel height for every scroll page
  -- without exposing raw pixel resizing to the player.
  local maxPageHeight=0
  if self.rowCount>0 then
    for first=1,self.rowCount do
      local pageHeight=0
      local last=math.min(self.rowCount,first+available-1)
      for i=first,last do
        local row=self.rows[i]
        local h=(row and row.GetHeight and row:GetHeight()) or 1
        if h<1 then h=1 end
        pageHeight=pageHeight+h
      end
      if pageHeight>maxPageHeight then maxPageHeight=pageHeight end
    end
  end
  if maxPageHeight<1 then
    local size=tonumber(Settings():Get("trackerFontSize")) or 10
    maxPageHeight=(size+5)*available
  end

  local _,maxH=GetScreenBounds()
  local frameHeight=Clamp(maxPageHeight+self.frameVerticalChrome,self.minHeight,math.min(self.maxHeight,maxH))
  self.frame:SetHeight(frameHeight)

  -- Vanilla does not always resolve a TOP/BOTTOM anchored child to its new
  -- height synchronously after the parent changes size. Whole-row paging must
  -- use the new viewport during this same render pass, so make it explicit.
  local scrollHeight=math.max(1,frameHeight-self.frameVerticalChrome)
  -- Keep the viewport height we just calculated as the authoritative value for
  -- this render pass. Vanilla can briefly report the previous ScrollFrame
  -- height immediately after SetHeight(), which can clip the final whole row
  -- until the next mouse-wheel/input event.
  self.currentViewportHeight=scrollHeight
  if self.scroll.SetHeight then self.scroll:SetHeight(scrollHeight) end
end

function T:GetVisibleRowRange()
  if self.rowCount<=0 then return 1,0,0 end

  local first=tonumber(self.topRow) or 1
  if first<1 then first=1 end
  if first>self.rowCount then first=self.rowCount end

  local viewHeight=tonumber(self.currentViewportHeight) or 0
  if viewHeight<=0 then
    viewHeight=(self.scroll and self.scroll.GetHeight and self.scroll:GetHeight()) or 0
  end
  local maxRows=self:GetVisibleRowsSetting()
  local used=0
  local count=0
  local last=first-1
  for i=first,self.rowCount do
    if count>=maxRows then break end
    local row=self.rows[i]
    local h=(row and row.GetHeight and row:GetHeight()) or 0
    if h<=0 then h=1 end
    if used+h>viewHeight then break end
    used=used+h
    count=count+1
    last=i
  end
  return first,last,used
end

function T:ClampTopRow()
  -- Do not destroy a restored scroll position during the brief startup window
  -- where the tracker can render before the quest cache has populated. Once
  -- rows exist, clamp the saved row normally against the current content.
  if self.rowCount<=0 then return end

  local top=tonumber(self.topRow) or 1
  if top<1 then top=1 end
  if top>self.rowCount then top=self.rowCount end
  self.topRow=top

  -- On the final page, walk upward while the entire remainder still fits.
  -- This prevents an unnecessary blank area at the bottom while preserving
  -- the rule that every visible tracker row is shown completely.
  local first,last=self:GetVisibleRowRange()
  if last==self.rowCount then
    while self.topRow>1 do
      local old=self.topRow
      self.topRow=old-1
      local prevFirst,prevLast=self:GetVisibleRowRange()
      if prevLast~=self.rowCount then
        self.topRow=old
        break
      end
    end
  end
end

function T:LayoutVisibleRows()
  if not self.scroll or not self.content then return end

  self:ClampTopRow()
  local first,last=self:GetVisibleRowRange()
  local y=0
  local contentWidth=math.max(1,self.scroll:GetWidth())

  for i=1,self.rowCount do
    local row=self.rows[i]
    if i>=first and i<=last then
      row:Show()
      row:SetWidth(contentWidth)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT",self.content,"TOPLEFT",0,-y)
      y=y+row:GetHeight()
    else
      row:Hide()
    end
  end

  self.content:SetWidth(contentWidth)
  self.content:SetHeight(math.max(1,y))
  if self.scroll.SetVerticalScroll then self.scroll:SetVerticalScroll(0) end
  self:SaveScrollPosition()
end

function T:ScrollBy(delta)
  if not self.scroll or not self.scroll:IsShown() then return end
  local wheel=tonumber(delta) or 0
  if wheel==0 or self.rowCount<=0 then return end

  if wheel<0 then
    self.topRow=(tonumber(self.topRow) or 1)+1
  else
    self.topRow=(tonumber(self.topRow) or 1)-1
  end
  self:ClampTopRow()
  self:LayoutVisibleRows()
end

function T:SetTrackerHoverQuest(questID)
  questID=tonumber(questID)
  if questID and not (QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]) then
    questID=nil
  end
  if self.hoverQuestID==questID then return end
  self.hoverQuestID=questID

  if QuestieOcto.Map and QuestieOcto.Map.SetTrackerHoverQuest then
    QuestieOcto.Map:SetTrackerHoverQuest(questID)
  end
  if QuestieOcto.Minimap and QuestieOcto.Minimap.SetTrackerHoverQuest then
    QuestieOcto.Minimap:SetTrackerHoverQuest(questID)
  end
end

local function EnsureRow(index,parent)
  local row=T.rows[index]
  if row then
    row:Show()
    return row
  end

  row=CreateFrame("Button",nil,parent)
  row:SetHeight(14)
  row:EnableMouse(true)

  local text=row:CreateFontString(nil,"ARTWORK","GameFontNormal")
  text:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  row.text=text

  row:SetScript("OnEnter",function()
    if this.questID then
      T:SetTrackerHoverQuest(this.questID)
      GameTooltip:SetOwner(this,"ANCHOR_LEFT")
      GameTooltip:SetText(this.questTitle or "Quest",1,0.82,0)
      GameTooltip:AddLine("Click to open this quest in the Quest Log.",1,1,1)
      GameTooltip:AddLine("Right click for quest options.",1,1,1)
      GameTooltip:AddLine("Shift + Click to stop tracking it.",0.7,0.7,0.7)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave",function()
    T:SetTrackerHoverQuest(nil)
    if GameTooltip then GameTooltip:Hide() end
  end)
  row:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row:SetScript("OnClick",function()
    if not this.questID then return end
    local click=arg1 or "LeftButton"
    if click=="RightButton" then
      T:ShowQuestMenu(this.questID)
      return
    end
    if click~="LeftButton" then return end
    if IsShiftKeyDown and IsShiftKeyDown() then
      if QuestieOcto.TrackerDriver then QuestieOcto.TrackerDriver:Toggle(this.questID) end
      return
    end
    T:OpenQuest(this.questID)
  end)
  if row.EnableMouseWheel then row:EnableMouseWheel(true) end
  row:SetScript("OnMouseWheel",function() T:ScrollBy(arg1) end)

  T.rows[index]=row
  return row
end

function T:ClearRows()
  for i=1,table.getn(self.rows) do
    local row=self.rows[i]
    row:Hide()
    row.questID=nil
    row.questTitle=nil
    row.kind=nil
    row.displayText=nil
    row.timerQuestID=nil
    row.timerLogIndex=nil
    row.failed=nil
    row.textIndent=nil
  end
  self.rowCount=0
  -- Preserve topRow across presentation rebuilds. LayoutVisibleRows clamps it
  -- once the refreshed rows exist, so ordinary quest updates and /reload do
  -- not bounce a player back to the top of the tracker.
  self.timerRows={}
end

local function WrapTextToWidth(fs,text,maxWidth)
  text=tostring(text or "")
  maxWidth=tonumber(maxWidth) or 0
  if text=="" or maxWidth<=0 or not fs or not fs.SetText or not fs.GetStringWidth then
    return text,1
  end

  -- Do not rely on Vanilla/Turtle FontString auto-wrapping. Some client/UI
  -- combinations keep drawing a constrained FontString at its natural one-line
  -- width. Build the line breaks explicitly from the exact rendered font width
  -- so long event/exploration objectives are deterministic on every client.
  local lines={}
  local line=""
  local pos=1
  while true do
    local s,e=string.find(text,"%S+",pos)
    if not s then break end
    local word=string.sub(text,s,e)
    local candidate=(line=="") and word or (line.." "..word)
    fs:SetText(candidate)
    local candidateWidth=tonumber(fs:GetStringWidth()) or 0
    if line~="" and candidateWidth>maxWidth then
      table.insert(lines,line)
      line=word
    else
      line=candidate
    end
    pos=e+1
  end

  if line~="" then table.insert(lines,line) end
  local count=table.getn(lines)
  if count<1 then return text,1 end
  return table.concat(lines,"\n"),count
end

local function ZoneSpacerHeight(fontSize)
  -- Keep zone groups visually separated without consuming a full text row.
  -- The spacer scales with the configured tracker font and adds a small amount
  -- for OUTLINE/THICKOUTLINE so heavier glyph edges do not feel crowded.
  local height=(tonumber(fontSize) or 10)-4
  if height<4 then height=4 end
  if height>13 then height=13 end

  if Settings():Get("trackerThickOutlineText") then
    height=height+2
  elseif Settings():Get("trackerOutlineText") then
    height=height+1
  end

  if height>15 then height=15 end
  return height
end

local function ApplyRowStyle(row, contentWidth, constrainWidth)
  local size=tonumber(Settings():Get("trackerFontSize")) or 10
  local left=0
  local r,g,b=1,1,1
  local kind=row.kind

  if kind=="zone" then
    size=size+1
    r,g,b=0.88,0.69,0.24
    left=0
  elseif kind=="quest" then
    -- Match the classic Questie/Quest Log presentation: completion is shown
    -- by appending "(Complete)" to the title, not by replacing difficulty color.
    if row.failed then
      r,g,b=1,0.35,0.35
    elseif QuestieOcto.GetNativeQuestDifficultyColor then
      local nr,ng,nb=QuestieOcto:GetNativeQuestDifficultyColor(row.questLevel,row.questID)
      if nr then r,g,b=nr,ng,nb else r,g,b=1,0.82,0 end
    else
      r,g,b=1,0.82,0
    end
    left=6
  elseif kind=="objective" then
    r,g,b=row.complete and 0.35 or 0.82, row.complete and 0.80 or 0.82, row.complete and 0.35 or 0.82
    left=18
  elseif kind=="timer" then
    r,g,b=0.35,0.75,1
    left=18
  end

  row:SetWidth(math.max(1,contentWidth or 1))
  row.text:ClearAllPoints()
  row.text:SetPoint("TOPLEFT",row,"TOPLEFT",left,0)

  -- Measure before adding a right-side constraint. GetStringWidth() must see
  -- each candidate at its natural width so explicit wrapping is deterministic.
  SetFont(row.text,size,r,g,b)
  if kind=="zone" and row.text.SetFont then
    local font=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local flags=""
    if Settings():Get("trackerThickOutlineText") then
      flags="THICKOUTLINE"
    elseif Settings():Get("trackerOutlineText") then
      flags="OUTLINE"
    end
    row.text:SetFont(font,size,flags)
    row.text:SetTextColor(r,g,b)
  end

  local displayText=row.displayText or ""
  local lineCount=1
  if constrainWidth and kind=="objective" then
    local available=math.max(1,(tonumber(contentWidth) or 1)-left)
    displayText,lineCount=WrapTextToWidth(row.text,displayText,available)
  end

  -- Preserve the normal right boundary too, but explicit newlines above are
  -- what guarantee the visual wrap on old clients where anchors alone do not.
  if constrainWidth then
    row.text:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,0)
  end
  row.text:SetText(displayText)
  row.textIndent=left

  local baseHeight=size+4
  local height
  if kind=="spacer" then
    height=ZoneSpacerHeight(size)
  else
    height=baseHeight*math.max(1,lineCount)
  end
  row:SetHeight(height)
end

function T:AddRow(text,kind,questID,complete,questLevel,failed)
  self.rowCount=self.rowCount+1
  local row=EnsureRow(self.rowCount,self.content)
  row.questID=questID
  row.questTitle=(kind=="quest") and text or nil
  row.kind=kind
  row.complete=complete and true or false
  row.failed=failed and true or false
  row.questLevel=questLevel
  row.displayText=text or ""
  row:EnableMouse(questID and true or false)
  -- First render pass: create the exact visible text at natural width. The
  -- subsequent AutoFitWidth() measures this same FontString via GetStringWidth().
  ApplyRowStyle(row, math.max(1,(self.scroll and self.scroll:GetWidth()) or self.defaultWidth))
  return row
end

local function FormatTimer(seconds)
  seconds=tonumber(seconds)
  if not seconds then return nil end
  if seconds<0 then seconds=0 end
  if SecondsToTime then
    local ok,value=pcall(SecondsToTime,seconds)
    if ok and value and value~="" then return value end
  end
  local total=math.floor(seconds+0.5)
  local minutes=math.floor(total/60)
  local secs=math.mod(total,60)
  if minutes>=60 then
    local hours=math.floor(minutes/60)
    minutes=math.mod(minutes,60)
    return tostring(hours).."h "..tostring(minutes).."m"
  end
  if minutes>0 then return tostring(minutes).."m "..tostring(secs).."s" end
  return tostring(secs).."s"
end

function T:GetQuestTimerSeconds(quest)
  if not quest then return nil end
  local index=tonumber(quest.logIndex)
  if not index or type(GetQuestLogTimeLeft)~="function" then return nil end

  -- Collapse/expand changes native quest-log indices. Validate the cached slot
  -- before selecting it so a hidden timed quest can never interrogate another
  -- quest after the log has been reindexed.
  local questID=tonumber(quest.id)
  if questID and QuestieOcto.API then
    local rawIndexedID=QuestieOcto.API.GetQuestIDForLogIndex and QuestieOcto.API:GetQuestIDForLogIndex(index) or nil
    local indexedID=tonumber(rawIndexedID)
    if indexedID~=questID then
      local rawFreshIndex=QuestieOcto.API.GetLogIndexForQuestID and QuestieOcto.API:GetLogIndexForQuestID(questID) or nil
      local freshIndex=tonumber(rawFreshIndex)
      local rawFreshID=freshIndex and QuestieOcto.API.GetQuestIDForLogIndex and QuestieOcto.API:GetQuestIDForLogIndex(freshIndex) or nil
      local freshID=tonumber(rawFreshID)
      if not freshIndex or freshID~=questID then return nil end
      index=freshIndex
      quest.logIndex=freshIndex
    end
  end

  -- Questie 3.3.5 compatibility path: GetQuestLogTimeLeft is tied to the
  -- selected quest on old clients. Temporarily select this quest, read the
  -- timer, then restore the player's previous selection immediately.
  if type(GetQuestLogSelection)=="function" and type(SelectQuestLogEntry)=="function" then
    local selected=GetQuestLogSelection()
    SelectQuestLogEntry(index)
    local ok,value=pcall(GetQuestLogTimeLeft,index)
    if selected and selected>0 then SelectQuestLogEntry(selected) end
    if ok and tonumber(value) then return tonumber(value) end
    return nil
  end

  -- Compatibility fallback for ClassicAPI implementations that accept the
  -- quest-log index directly.
  local ok,value=pcall(GetQuestLogTimeLeft,index)
  if ok and tonumber(value) then return tonumber(value) end
  return nil
end

function T:AddTimerRow(quest)
  local seconds=self:GetQuestTimerSeconds(quest)
  if not seconds then return end
  local text=FormatTimer(seconds)
  if not text then return end
  local row=self:AddRow(text,"timer",nil,false)
  row.timerQuestID=quest.id
  row.timerLogIndex=quest.logIndex
  self.timerRows[quest.id]=row
end

function T:UpdateTimerRows()
  if not self.frame or not self.frame:IsShown() or not CharacterDB().expanded then return end
  local expired=false
  for questID,row in pairs(self.timerRows or {}) do
    if row then
      local seconds=nil
      local quest=QuestieOcto.TrackerDriver and QuestieOcto.TrackerDriver.tracked and QuestieOcto.TrackerDriver.tracked[questID]
      if quest then seconds=self:GetQuestTimerSeconds(quest) end
      if seconds then
        local value=FormatTimer(seconds)
        if value and row.displayText~=value then
          row.displayText=value
          row.text:SetText(value)
        end
      else
        expired=true
      end
    end
  end
  if expired then self:Render() end
end

local function ObjectiveTextForDisplay(objective)
  if not objective then return "" end

  -- Keep native Turtle leaderboard wording whenever it is complete. During the
  -- login cache race, however, rawText can temporarily be only ": 0/10". If
  -- QuestLog already resolved a safe database/previous label, use that; until
  -- then show only the counter rather than caching/displaying a nameless colon.
  if objective.rawTextIncomplete then
    local repaired=objective.text
    if repaired and repaired~="" and repaired~=objective.rawText then return repaired end
    local current=tonumber(objective.current)
    local required=tonumber(objective.required)
    if current and required and required>0 then
      return tostring(current).."/"..tostring(required)
    end
    return ""
  end

  return objective.rawText or objective.text or ""
end

local function ObjectiveDisplayText(objective)
  local text=ObjectiveTextForDisplay(objective)
  if not text then text="" end

  -- The native Vanilla leaderboard text already contains the desired 5/10 form.
  -- Only synthesize amounts when the compatibility API supplied numeric progress
  -- separately and the text itself omitted it. Never display percentages.
  local current=objective and tonumber(objective.current)
  local required=objective and tonumber(objective.required)
  if current and required and required>0 and not string.find(text,"%d+%s*/%s*%d+") then
    if text~="" then
      text=tostring(current).."/"..tostring(required).." "..text
    else
      text=tostring(current).."/"..tostring(required)
    end
  end
  if text~="" then
    text="- "..text
  end
  return text
end

function T:Render()
  if not self.frame or not self.content then return end

  if not Settings():Get("trackerEnabled") or (Settings():Get("trackerHideInCombat") and self.inCombat) then
    self.frame:Hide()
    return
  end

  local ordered=(QuestieOcto.TrackerDriver and QuestieOcto.TrackerDriver.ordered) or {}
  if table.getn(ordered)==0 then
    -- An empty tracker has no actionable content. Hide the whole frame instead
    -- of leaving a permanent "No tracked quests." panel on the player's UI.
    self:ClearRows()
    self.frame:Hide()
    return
  end

  self.frame:Show()
  self:ApplyLockState()

  local db=CharacterDB()
  local expanded=db.expanded and true or false
  self.minimize:SetText(expanded and "-" or "+")

  self.headerText:SetText("")

  if not expanded then
    self.scroll:Hide()
    if self.resizeGrip then self.resizeGrip:Hide() end
    self.frame:SetHeight(30)
    return
  end

  self.scroll:Show()

  self:ClearRows()
  local sortMode=Settings():Get("trackerSort")
  local lastZone=nil

  for i=1,table.getn(ordered) do
    local quest=ordered[i]
    if sortMode=="zone" then
      local zone=quest.zoneGroup or "Other"
      if zone~=lastZone then
        if self.rowCount>0 then self:AddRow("","spacer",nil,false) end
        self:AddRow(zone,"zone",nil,false)
        lastZone=zone
      end
    end

    local prefix=""
    if quest.level and tonumber(quest.level) and tonumber(quest.level)>0 then
      -- Match pfQuest's Vanilla tracker convention: the native quest-log tag
      -- adds a '+' inside the level brackets, e.g. [40+].
      prefix="["..tostring(quest.level)..(quest.tag and "+" or "").."] "
    end
    local title=tostring(quest.title or "Quest")
    if quest.failed then
      title=title.." (Failed)"
    elseif quest.complete then
      title=title.." ("..tostring(_G["COMPLETE"] or "Complete")..")"
    end
    self:AddRow(prefix..title,"quest",quest.id,quest.complete,quest.level,quest.failed)
    self:AddTimerRow(quest)

    -- TrackerDriver already applies the Hide Completed Objectives setting to
    -- quest.objectives. Render whatever survives that filter even when the
    -- whole quest is complete, so OFF means completed objective rows remain
    -- visible and ON hides them consistently for partial and fully-complete
    -- quests alike.
    for j=1,table.getn(quest.objectives or {}) do
      local objective=quest.objectives[j]
      self:AddRow(ObjectiveDisplayText(objective),"objective",nil,objective.complete)
    end
  end

  -- First pass has already created the visible FontStrings at natural width.
  -- Measure those exact strings and choose a tracker width capped like pfQuest.
  -- Then perform one constrained pass so only text that exceeds the available
  -- width wraps, and row heights expand to keep every wrapped line visible.
  local frameWidth,contentWidth=self:AutoFitWidth()

  for i=1,self.rowCount do
    ApplyRowStyle(self.rows[i],contentWidth,true)
  end
  self:ApplyVisibleRowsHeight()
  self:LayoutVisibleRows()
end

local function MenuObjectiveText(objective)
  local text=ObjectiveTextForDisplay(objective)
  if not text or text=="" then text="Objective" end
  text=tostring(text or "Objective")
  text=string.gsub(text,"^%-%s*","")
  if string.len(text)>72 then text=string.sub(text,1,69).."..." end
  return text
end

local function AddTrackerMenuButton(text,func,arg1,arg2,hasArrow,value,isTitle,disabled)
  if not UIDropDownMenu_CreateInfo or not UIDropDownMenu_AddButton then return end
  local info=UIDropDownMenu_CreateInfo()
  info.text=text
  info.func=func
  info.arg1=arg1
  info.arg2=arg2
  info.hasArrow=hasArrow and 1 or nil
  info.value=value
  info.isTitle=isTitle and 1 or nil
  info.disabled=disabled and 1 or nil
  info.notCheckable=1
  UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL)
end

local function CloseTrackerMenu()
  if CloseDropDownMenus then CloseDropDownMenus() end
end

function T:ContextShowQuestLog(questID)
  CloseTrackerMenu()
  self:OpenQuest(questID)
end

function T:ContextUntrackQuest(questID)
  CloseTrackerMenu()
  if QuestieOcto.TrackerDriver then QuestieOcto.TrackerDriver:Untrack(questID) end
end

function T:ContextShowObjective(questID,objectiveIndex)
  CloseTrackerMenu()
  local quest=self.contextQuest
  local zoneGroup=quest and quest.zoneGroup or nil
  if QuestieOcto.Map and QuestieOcto.Map.ShowTrackerObjective
     and QuestieOcto.Map:ShowTrackerObjective(questID,objectiveIndex,zoneGroup) then
    return
  end
  if QuestieOcto.Print then QuestieOcto:Print("No selectable World Map location was found for this objective.") end
end

function T:ContextShowFinisher(questID)
  CloseTrackerMenu()
  local quest=self.contextQuest
  local zoneGroup=quest and quest.zoneGroup or nil
  if QuestieOcto.Map and QuestieOcto.Map.ShowTrackerFinisher
     and QuestieOcto.Map:ShowTrackerFinisher(questID,zoneGroup) then
    return
  end
  if QuestieOcto.Print then QuestieOcto:Print("No selectable World Map location was found for this quest turn-in.") end
end

function T:InitializeQuestMenu(level)
  local quest=self.contextQuest
  if not quest then return end
  level=tonumber(level) or UIDROPDOWNMENU_MENU_LEVEL or 1

  if level==1 then
    AddTrackerMenuButton(quest.title or "Quest",nil,nil,nil,false,nil,true,false)

    if quest.complete then
      local canShow=QuestieOcto.Map and QuestieOcto.Map.CanShowTrackerFinisher
        and QuestieOcto.Map:CanShowTrackerFinisher(quest.id,quest.zoneGroup)
      AddTrackerMenuButton("Show on Map",function(qid) T:ContextShowFinisher(qid) end,quest.id,nil,false,nil,false,not canShow)
    elseif table.getn(self.contextObjectives or {})>0 then
      AddTrackerMenuButton("Objectives",nil,nil,nil,true,"objectives",false,false)
    end

    AddTrackerMenuButton("Show in Quest Log",function(qid) T:ContextShowQuestLog(qid) end,quest.id,nil,false,nil,false,false)
    AddTrackerMenuButton("Untrack Quest",function(qid) T:ContextUntrackQuest(qid) end,quest.id,nil,false,nil,false,false)
    AddTrackerMenuButton("Cancel",function() CloseTrackerMenu() end,nil,nil,false,nil,false,false)
    return
  end

  if level==2 and UIDROPDOWNMENU_MENU_VALUE=="objectives" then
    for _,entry in pairs(self.contextObjectives or {}) do
      AddTrackerMenuButton(entry.text,nil,nil,nil,true,"objective:"..tostring(entry.index),false,false)
    end
    return
  end

  if level==3 then
    local value=tostring(UIDROPDOWNMENU_MENU_VALUE or "")
    local _,_,objectiveValue=string.find(value,"^objective:(%d+)$")
    local objectiveIndex=tonumber(objectiveValue)
    if objectiveIndex then
      local canShow=QuestieOcto.Map and QuestieOcto.Map.CanShowTrackerObjective
        and QuestieOcto.Map:CanShowTrackerObjective(quest.id,objectiveIndex,quest.zoneGroup)
      AddTrackerMenuButton("Show on Map",function(qid,index) T:ContextShowObjective(qid,index) end,quest.id,objectiveIndex,false,nil,false,not canShow)
    end
  end
end

function T:EnsureQuestMenu()
  if self.contextMenu then return self.contextMenu end
  if not UIDropDownMenu_Initialize or not ToggleDropDownMenu then return nil end
  local frame=CreateFrame("Frame","QuestieOctoTrackerDropDown",UIParent,"UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(frame,function(level) T:InitializeQuestMenu(level) end,"MENU")
  self.contextMenu=frame
  return frame
end

function T:ShowQuestMenu(questID)
  questID=tonumber(questID)
  if not questID then return end
  local quest=QuestieOcto.TrackerDriver and QuestieOcto.TrackerDriver.tracked
    and QuestieOcto.TrackerDriver.tracked[questID] or nil
  if not quest then return end

  local objectives={}
  if not quest.complete then
    for i=1,table.getn(quest.objectives or {}) do
      local objective=quest.objectives[i]
      if not objective.complete then
        local index=tonumber(objective.index) or i
        table.insert(objectives,{index=index,text=MenuObjectiveText(objective)})
      end
    end
  end

  self.contextQuest=quest
  self.contextObjectives=objectives
  local menu=self:EnsureQuestMenu()
  if not menu then return end
  if GameTooltip then GameTooltip:Hide() end
  ToggleDropDownMenu(1,nil,menu,"cursor",0,0)
end

function T:OpenQuest(questID)
  questID=tonumber(questID)
  local state=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID]
  if not state then return end

  if QuestLogFrame and ShowUIPanel then
    ShowUIPanel(QuestLogFrame)
  elseif ToggleQuestLog and (not QuestLogFrame or not QuestLogFrame:IsShown()) then
    ToggleQuestLog()
  end

  -- Native header collapse/expand reindexes the Quest Log immediately. The
  -- cached tracker state is refreshed asynchronously, so validate the stored
  -- slot by quest ID before selecting it. This mirrors the existing timed-
  -- quest safety above and fails closed rather than opening a neighbouring
  -- quest during the brief reindex window.
  local index=tonumber(state.logIndex)
  if index and questID and QuestieOcto.API then
    local rawIndexedID=QuestieOcto.API.GetQuestIDForLogIndex and QuestieOcto.API:GetQuestIDForLogIndex(index) or nil
    if tonumber(rawIndexedID)~=questID then
      local rawFreshIndex=QuestieOcto.API.GetLogIndexForQuestID and QuestieOcto.API:GetLogIndexForQuestID(questID) or nil
      local freshIndex=tonumber(rawFreshIndex)
      local rawFreshID=freshIndex and QuestieOcto.API.GetQuestIDForLogIndex and QuestieOcto.API:GetQuestIDForLogIndex(freshIndex) or nil
      if freshIndex and tonumber(rawFreshID)==questID then
        index=freshIndex
        state.logIndex=freshIndex
      else
        index=nil
      end
    end
  end

  if QuestLog_SetSelection and index then
    QuestLog_SetSelection(index)
  end
  if QuestLog_Update then QuestLog_Update() end
  if QuestLog_UpdateQuestDetails then QuestLog_UpdateQuestDetails() end
end

function T:ApplyLockState()
  if not self.frame then return end
  local locked=Settings():Get("trackerLocked") and true or false
  self.frame:SetMovable(not locked)
  -- Height is controlled exclusively by the discrete Visible Rows option.
  -- Do not expose pixel resizing, which can reintroduce partial-row clipping.
  self.frame:SetResizable(false)
  if self.resizeGrip then self.resizeGrip:Hide() end
end

function T:ToggleExpanded()
  local db=CharacterDB()
  if db.expanded then
    self:SaveGeometry()
    db.expanded=false
  else
    db.expanded=true
  end
  self:Render()
end

function T:ResetLocation()
  if not self.frame then return end
  local db=CharacterDB()
  db.window.point="TOPRIGHT"
  db.window.relativePoint="TOPRIGHT"
  db.window.x=-30
  db.window.y=-180
  db.expanded=true
  self:RestoreGeometry()
  self:Render()
  self:SaveGeometry()
end

function T:HideNativeQuestTimer()
  if not QuestTimerFrame then return end
  if not QuestTimerFrame.IsShown or QuestTimerFrame:IsShown() then
    QuestTimerFrame:Hide()
  end
end

function T:InstallNativeTimerSuppression()
  if self.nativeTimerSuppressionInstalled then return end
  self.nativeTimerSuppressionInstalled=true

  if type(QuestTimerFrame_Update)=="function" then
    local secureHook=hooksecurefunc
    if type(secureHook)~="function" and LibStub then
      local aceCore=LibStub("AceCore-3.0",true)
      secureHook=aceCore and aceCore.hooksecurefunc
    end

    if type(secureHook)=="function" then
      secureHook("QuestTimerFrame_Update",function()
        if Settings():Get("trackerEnabled") then T:HideNativeQuestTimer() end
      end)
    else
      -- Last-resort Vanilla compatibility only if neither the client nor Ace3v
      -- provides Questie's normal post-hook primitive.
      local original=QuestTimerFrame_Update
      QuestTimerFrame_Update=function()
        local result=original()
        if Settings():Get("trackerEnabled") then T:HideNativeQuestTimer() end
        return result
      end
    end
  end

  if QuestTimerFrame and QuestTimerFrame.SetScript then
    local previous=QuestTimerFrame:GetScript("OnShow")
    QuestTimerFrame:SetScript("OnShow",function()
      if previous then previous() end
      if Settings():Get("trackerEnabled") then T:HideNativeQuestTimer() end
    end)
  end
end

function T:ApplyNativeTrackerVisibility()
  local enabled=Settings():Get("trackerEnabled") and true or false
  self:InstallNativeTimerSuppression()

  -- Questie 5.2.3/6.0.0 replace Vanilla's QuestWatchFrame while the Questie
  -- tracker is enabled. Turtle may expose this frame depending on its UI build.
  if QuestWatchFrame then
    if enabled then QuestWatchFrame:Hide() else QuestWatchFrame:Show() end
  end

  -- Questie-Octo renders timed quests inside its own tracker. Hide Blizzard's
  -- duplicate timer while that tracker is enabled, but never move or replace
  -- QuestTimerFrame positioning methods. UI replacements such as pfUI own that
  -- frame's movable position and may clamp it to the screen.
  if QuestTimerFrame then
    if enabled then
      self:HideNativeQuestTimer()
    elseif QuestTimerFrame.numTimers and QuestTimerFrame.numTimers>0 then
      -- Native QUEST_LOG_UPDATE continues maintaining numTimers while hidden.
      -- Showing the frame resumes its normal OnUpdate on the next frame, so its
      -- countdown text immediately catches up without Questie touching anchors.
      QuestTimerFrame:Show()
    else
      QuestTimerFrame:Hide()
    end
  end
end

function T:ApplyBackgroundOpacity()
  if not self.frame or not self.frame.SetBackdropColor then return end
  local alpha=tonumber(Settings():Get("trackerBackgroundOpacity")) or 0
  alpha=Clamp(alpha,0,1)
  self.frame:SetBackdropColor(0.03,0.03,0.03,alpha)
  -- Old Questie's transparent tracker is genuinely frameless. Tie the border
  -- to the optional background so the default 0 opacity has no chrome.
  if self.frame.SetBackdropBorderColor then
    self.frame:SetBackdropBorderColor(0.45,0.45,0.45,0.75*alpha)
  end
end

function T:CreateFrame()
  if self.frame then return end
  local frame=CreateFrame("Frame","QuestieOctoTrackerFrame",UIParent)
  self.frame=frame
  frame:SetFrameStrata("MEDIUM")
  if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
  frame:SetMovable(true)
  frame:SetResizable(false)
  if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
  frame:SetScript("OnMouseWheel",function() T:ScrollBy(arg1) end)
  frame:SetScript("OnHide",function() T:SetTrackerHoverQuest(nil) end)
  frame:SetScript("OnUpdate",function()
    T.timerElapsed=(T.timerElapsed or 0)+(arg1 or 0)
    if T.timerElapsed>=1 then
      T.timerElapsed=0
      T:UpdateTimerRows()
    end
  end)
  frame:EnableMouse(true)
  frame:SetBackdrop({
    bgFile="Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,tileSize=16,edgeSize=12,
    insets={left=3,right=3,top=3,bottom=3}
  })
  frame:SetBackdropColor(0.03,0.03,0.03,0)
  frame:SetBackdropBorderColor(0.45,0.45,0.45,0)


  local header=CreateFrame("Frame",nil,frame)
  self.header=header
  header:SetPoint("TOPLEFT",frame,"TOPLEFT",5,-5)
  header:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-5,-5)
  header:SetHeight(20)
  header:EnableMouse(true)
  if header.EnableMouseWheel then header:EnableMouseWheel(true) end
  header:SetScript("OnMouseWheel",function() T:ScrollBy(arg1) end)
  header:SetScript("OnMouseDown",function()
    if arg1=="LeftButton" and not Settings():Get("trackerLocked") then
      frame:StartMoving()
    end
  end)
  header:SetScript("OnMouseUp",function()
    frame:StopMovingOrSizing()
    T:SaveGeometry()
  end)

  local title=header:CreateFontString(nil,"ARTWORK","GameFontNormal")
  self.headerText=title
  title:SetJustifyH("RIGHT")
  SetFont(title,12,1,0.82,0)
  title:SetText("(0)")

  -- Old Questie/pfQuest-style lightweight expand control: keep the hit area,
  -- but render only a +/- glyph with no button chrome.
  local minimize=CreateFrame("Button",nil,header)
  self.minimize=minimize
  minimize:SetWidth(16)
  minimize:SetHeight(16)
  minimize:SetPoint("RIGHT",header,"RIGHT",0,0)
  local minimizeText=minimize:CreateFontString(nil,"OVERLAY","GameFontNormal")
  minimize.text=minimizeText
  minimizeText:SetAllPoints(minimize)
  minimizeText:SetJustifyH("CENTER")
  minimizeText:SetJustifyV("MIDDLE")
  SetFont(minimizeText,13,1,0.82,0)
  minimizeText:SetText("-")
  minimize.SetText=function(self,value) self.text:SetText(value or "") end
  title:SetPoint("RIGHT",minimize,"LEFT",-2,0)
  minimize:SetScript("OnClick",function() T:ToggleExpanded() end)

  -- Questie 3.3.5-style tracker scrolling does not need visible scrollbar
  -- chrome on Vanilla. Keep a plain ScrollFrame and use the mouse wheel.
  local scroll=CreateFrame("ScrollFrame","QuestieOctoTrackerScrollFrame",frame)
  self.scroll=scroll
  -- Keep vertical anchors, but make width explicit. A TOPLEFT+BOTTOMRIGHT
  -- horizontal anchor pair would override SetWidth() on Vanilla and leave the
  -- scroll/content region one render behind the auto-fit frame width.
  scroll:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-29)
  -- Height is explicit rather than derived from a second vertical anchor.
  -- This prevents Vanilla from keeping the previous viewport height until the
  -- next input event after a row-count driven frame resize.
  scroll:SetWidth(math.max(1,self.defaultWidth-16))
  self.currentViewportHeight=math.max(1,self.defaultHeight-self.frameVerticalChrome)
  scroll:SetHeight(self.currentViewportHeight)
  if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
  scroll:SetScript("OnMouseWheel",function() T:ScrollBy(arg1) end)

  local content=CreateFrame("Frame","QuestieOctoTrackerScrollChild",scroll)
  self.content=content
  content:SetWidth(220)
  content:SetHeight(1)
  if content.EnableMouseWheel then content:EnableMouseWheel(true) end
  content:SetScript("OnMouseWheel",function() T:ScrollBy(arg1) end)
  scroll:SetScrollChild(content)

  -- No mouse resize grip: tracker height is row-count driven.
  self.resizeGrip=nil

  -- Keep Blizzard's native watch/timer UI from duplicating Questie while
  -- enabled. Re-apply when those native frames try to show later.
  if QuestWatchFrame and QuestWatchFrame.HookScript then
    QuestWatchFrame:HookScript("OnShow",function()
      if Settings():Get("trackerEnabled") then this:Hide() end
    end)
  end
  if QuestTimerFrame and QuestTimerFrame.HookScript then
    QuestTimerFrame:HookScript("OnShow",function()
      if Settings():Get("trackerEnabled") then T:ApplyNativeTrackerVisibility() end
    end)
  end

  self:RestoreGeometry()
  self:RestoreScrollPosition()
  self:ApplyLockState()
  self:ApplyBackgroundOpacity()
  self:ApplyNativeTrackerVisibility()
  frame:Hide()
end

function T:OnTrackerStateChanged()
  self:Render()
end

function T:OnTrackerSettingChanged(key,value)
  if key=="trackerEnabled" then
    self:ApplyNativeTrackerVisibility()
    self:Render()
  elseif key=="trackerLocked" then
    self:ApplyLockState()
    self:Render()
  elseif key=="trackerBackgroundOpacity" then
    self:ApplyBackgroundOpacity()
  elseif key=="trackerFontSize" or key=="trackerMaxWidth" or key=="trackerVisibleRows" or key=="trackerSort" or
         key=="trackerOutlineText" or key=="trackerThickOutlineText" or
         key=="trackerShowCompleted" or key=="trackerHideCompletedObjectives" or
         key=="trackerAutoTrack" or key=="trackerHideInCombat" then
    self:Render()
  end
end

function T:OnCombatEvent(eventName)
  if eventName=="PLAYER_REGEN_DISABLED" then self.inCombat=true else self.inCombat=false end
  self:Render()
end

function T:Start()
  if self.started then return end
  self.started=true
  self:CreateFrame()
  if self.frame and self.frame.RegisterEvent then
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("PLAYER_LEVEL_UP")
    local previous=self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent",function()
      if previous then previous() end
      if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_REGEN_ENABLED" then
        T:OnCombatEvent(event)
      elseif event=="PLAYER_LEVEL_UP" then
        -- Tracker difficulty colors depend on player level even when no quest
        -- field changes, so repaint immediately at the level boundary.
        T:Render()
      end
    end)
  end
  QuestieOcto:RegisterMessage("TRACKER_STATE_CHANGED",self,"OnTrackerStateChanged")
  QuestieOcto:RegisterMessage("TRACKER_SETTING_CHANGED",self,"OnTrackerSettingChanged")
  self:Render()
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",T,"Start")
