-- Questie-Octo lightweight Quests browser.
--
-- Quest data/search truth comes from the bundled pfQuest database. The browser
-- intentionally avoids AceGUI TreeGroup: on Vanilla/Turtle, rebuilding a large
-- AceGUI tree is expensive enough to freeze the client. This UI recycles a
-- fixed set of native rows and scans the already-cached pfQuest title index directly.

QuestieOcto.QuestResearch = QuestieOcto.QuestResearch or {}
local R=QuestieOcto.QuestResearch

R.query=R.query or ""
R.statusFilter=R.statusFilter or "all"
R.selectedQuestID=R.selectedQuestID
R.matches=R.matches or {}
R.maxResults=100
R.resultCount=R.resultCount or 0
R.searching=R.searching or false
R.searchGeneration=R.searchGeneration or 0
R.rowCount=18
R.rowHeight=19

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

local function QuestFlags(questID)
  local completed=QuestieOcto.Completion and QuestieOcto.Completion.history and QuestieOcto.Completion.history[questID] and true or false
  local active=QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID] and true or false
  local available=QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.available and QuestieOcto.AvailableQuests.available[questID] and true or false
  return completed,active,available
end

local function QuestStatus(questID)
  local completed,active,available=QuestFlags(questID)
  if active then return "active" end
  if available then return "available" end
  if completed then return "completed" end
  return "unavailable"
end

local function StatusMatches(id,wanted)
  local completed,active,available=QuestFlags(id)
  if wanted=="all" then return true end
  if wanted=="completed" then return completed end
  if wanted=="active" then return active end
  if wanted=="available" then return available end
  return false
end

local function StatusColor(status)
  if status=="completed" then return "|cff35cc59" end
  if status=="active" then return "|cffffff00" end
  if status=="available" then return "|cff00ff00" end
  return "|cff808080"
end

local function StatusLabel(status)
  if status=="completed" then return "Completed" end
  if status=="active" then return "Active" end
  if status=="available" then return "Available" end
  return "Unavailable"
end

local function AddDisplayNames(result,ids,getName)
  if not ids then return end
  for _,id in pairs(ids) do
    local name=getName(id)
    if name and name~="" then table.insert(result,name) end
  end
end

local function JoinDisplayNames(ids,getName)
  local result={}
  AddDisplayNames(result,ids,getName)
  if table.getn(result)==0 then return nil end
  table.sort(result)
  return table.concat(result,", ")
end

local function ObjectiveName(row)
  if not row then return nil end
  if row.kind=="creature" then return QuestieOcto.DatabaseAPI:GetCreatureName(row.id) end
  if row.kind=="gameObject" then return QuestieOcto.DatabaseAPI:GetObjectName(row.id) end
  if row.kind=="item" then return QuestieOcto.DatabaseAPI:GetItemName(row.id) end
  return nil
end

local function ObjectiveText(row)
  local name=ObjectiveName(row)
  if not name or name=="" then return nil end
  if row.kind=="creature" then return "Defeat "..name end
  if row.kind=="gameObject" then return "Interact with "..name end
  if row.kind=="item" then return "Collect "..name end
  return name
end

local function FinalizeMatches(self,matches,total,generation)
  if generation~=self.searchGeneration then return end
  table.sort(matches,function(a,b)
    local an=string.lower(a.title or "")
    local bn=string.lower(b.title or "")
    if an==bn then return a.id<b.id end
    return an<bn
  end)
  self.matches=matches
  self.resultCount=total or table.getn(matches)
  self.searching=false
  local found=false
  if self.selectedQuestID then
    for i=1,table.getn(matches) do if matches[i].id==self.selectedQuestID then found=true break end end
  end
  if not found then self.selectedQuestID=matches[1] and matches[1].id or nil end
  self:RefreshWindow(false)
end

function R:RebuildResults()
  -- The quest browser is an explicit user lookup tool. pfQuest's proven
  -- browser model performs a bounded direct database search; chaining a search
  -- through Questie-Octo's shared frame scheduler could leave the UI stuck on
  -- "Searching..." if unrelated scheduled work was interrupted. The database
  -- title index is already built before DATABASE_API_READY, so scan it directly
  -- and stop after the visible result cap.
  self.searchGeneration=(self.searchGeneration or 0)+1
  local generation=self.searchGeneration
  self.matches={}
  self.resultCount=0
  self.searchTruncated=false
  self.searching=false

  if not QuestieOcto.DatabaseAPI or not QuestieOcto.DatabaseAPI:IsReady() then self:RefreshWindow(false); return end
  if not QuestieOcto.Completion or not QuestieOcto.Completion.ready then self:RefreshWindow(false); return end

  local query=string.lower(self.query or "")
  local wanted=self.statusFilter or "all"

  if query=="" and wanted=="all" then
    self.selectedQuestID=nil
    self:RefreshWindow(false)
    return
  end

  -- Exact numeric IDs bypass all title searching.
  local exactID=(query~="" and tonumber(query)) or nil
  if exactID and exactID==math.floor(exactID) and tostring(exactID)==query then
    local title=QuestieOcto.DatabaseAPI:GetQuestTitle(exactID)
    local raw=QuestieOcto.DatabaseAPI:GetQuestRaw(exactID)
    local matches={}
    if raw and title and StatusMatches(exactID,wanted) then
      table.insert(matches,{id=exactID,title=title,status=QuestStatus(exactID)})
    end
    FinalizeMatches(self,matches,table.getn(matches),generation)
    return
  end

  local matches={}
  local total=0

  local function AddMatch(id)
    if not id or not StatusMatches(id,wanted) then return false end
    total=total+1
    if table.getn(matches)<R.maxResults then
      local title=QuestieOcto.DatabaseAPI:GetQuestTitle(id) or ("Quest "..tostring(id))
      table.insert(matches,{id=id,title=title,status=QuestStatus(id)})
    end
    if table.getn(matches)>=R.maxResults then
      R.searchTruncated=true
      return true
    end
    return false
  end

  if query=="" then
    local source={}
    if wanted=="available" then source=(QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.available) or {}
    elseif wanted=="active" then source=(QuestieOcto.QuestLog and QuestieOcto.QuestLog.active) or {}
    elseif wanted=="completed" then source=(QuestieOcto.Completion and QuestieOcto.Completion.history) or {}
    end
    for id in pairs(source) do
      if AddMatch(tonumber(id)) then break end
    end
  else
    local searchIndex=QuestieOcto.DatabaseAPI.GetQuestSearchIndex and QuestieOcto.DatabaseAPI:GetQuestSearchIndex() or {}
    local ids=QuestieOcto.DatabaseAPI:GetQuestIDs()
    local numericQuery=tonumber(query)
    for i=1,table.getn(ids) do
      local id=tonumber(ids[i])
      if id then
        local searchTitle=searchIndex[id] or QuestieOcto.DatabaseAPI:GetQuestSearchTitle(id) or ""
        local matched=string.find(searchTitle,query,1,true) and true or false
        if (not matched) and numericQuery then
          matched=string.find(tostring(id),query,1,true) and true or false
        end
        if matched and AddMatch(id) then break end
      end
    end
  end

  FinalizeMatches(self,matches,R.searchTruncated and (R.maxResults+1) or total,generation)
end

function R:SetQuery(value)
  self.query=value or ""
  self:RebuildResults()
end

function R:SetStatusFilter(value)
  self.statusFilter=value or "all"
  self:RebuildResults()
end

function R:GetStatusText()
  if not QuestieOcto.DatabaseAPI or not QuestieOcto.DatabaseAPI:IsReady() then return "Quest database is still loading." end
  if not QuestieOcto.Completion or not QuestieOcto.Completion.ready then return "Completed-quest history is still loading." end
  if self.searching then return "Searching quest database..." end
  if (self.query or "")=="" and (self.statusFilter or "all")=="all" then return "Type a quest name/ID, or choose Available / Active / Completed." end
  if self.searchTruncated or self.resultCount>self.maxResults then return "Matching quests: "..self.maxResults.."+ (showing first "..self.maxResults..")." end
  return "Matching quests: "..self.resultCount.."."
end

function R:GetQuestDetails()
  local id=self.selectedQuestID
  if not id then return "Select a quest to view its details." end
  local q=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(id)
  if not q then return "Quest details are unavailable for quest ID "..tostring(id).."." end

  local lines={}
  table.insert(lines,"|cffffd100"..tostring(q.title or ("Quest "..id)).."|r")
  if q.level and q.level>0 then
    local levelLine="Level "..tostring(q.level)
    if q.requiredLevel and q.requiredLevel>0 then levelLine=levelLine.."  |cff888888·|r  Requires "..tostring(q.requiredLevel) end
    table.insert(lines,levelLine)
  end
  local status=QuestStatus(id)
  local st=StatusColor(status)..StatusLabel(status).."|r"
  if q.pvp then st=st.."  |cff888888·|r  |cffff4040PvP|r" end
  if q.repeatable then st=st.."  |cff888888·|r  |cff5599ffRepeatable|r" end
  if q.eventID and QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:IsPresentationEvent(q.eventID) then st=st.."  |cff888888·|r  Event" end
  table.insert(lines,st)
  if status=="unavailable" and QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.GetUnavailableReason then
    local reason=QuestieOcto.AvailableQuests:GetUnavailableReason(id)
    if reason then table.insert(lines,"\n|cffff8040Why unavailable|r\n"..reason) end
  end

  local givers={}
  local n=JoinDisplayNames(q.starts and q.starts.creature,function(v) return QuestieOcto.DatabaseAPI:GetCreatureName(v) end)
  local o=JoinDisplayNames(q.starts and q.starts.gameObject,function(v) return QuestieOcto.DatabaseAPI:GetObjectName(v) end)
  local it=JoinDisplayNames(q.starts and q.starts.item,function(v) return QuestieOcto.DatabaseAPI:GetItemName(v) end)
  if n then table.insert(givers,n) end; if o then table.insert(givers,o) end; if it then table.insert(givers,it) end
  if table.getn(givers)>0 then table.insert(lines,"\n|cffffd100Quest Giver|r\n"..table.concat(givers,"\n")) end

  local desc=FormatQuestText(q.descriptionText)
  if desc then table.insert(lines,"\n|cffffd100Description|r\n"..desc) end
  local obj=FormatQuestText(q.objectiveText)
  if obj then
    table.insert(lines,"\n|cffffd100Objectives|r\n"..obj)
  elseif q.objectiveData and table.getn(q.objectiveData)>0 then
    local rows={}
    for i=1,table.getn(q.objectiveData) do local text=ObjectiveText(q.objectiveData[i]); if text then table.insert(rows,"• "..text) end end
    if table.getn(rows)>0 then table.insert(lines,"\n|cffffd100Objectives|r\n"..table.concat(rows,"\n")) end
  end

  local turnins={}
  n=JoinDisplayNames(q.finishes and q.finishes.creature,function(v) return QuestieOcto.DatabaseAPI:GetCreatureName(v) end)
  o=JoinDisplayNames(q.finishes and q.finishes.gameObject,function(v) return QuestieOcto.DatabaseAPI:GetObjectName(v) end)
  if n then table.insert(turnins,n) end; if o then table.insert(turnins,o) end
  if table.getn(turnins)>0 then table.insert(lines,"\n|cffffd100Turn In|r\n"..table.concat(turnins,"\n")) end
  return table.concat(lines,"\n")
end

local ITEM_SUFFIX=":0:0:0"

local function FormatMoney(copper)
  copper=math.max(0,tonumber(copper) or 0)
  local gold=math.floor(copper/10000)
  local silver=math.floor(math.mod(copper,10000)/100)
  local coin=math.mod(copper,100)
  local out={}
  if gold>0 then table.insert(out,tostring(gold).."g") end
  if silver>0 or gold>0 then table.insert(out,tostring(silver).."s") end
  table.insert(out,tostring(coin).."c")
  return table.concat(out," ")
end

local function RewardLinkText(button)
  local color=button.itemColor or "|cffffffff"
  local name=button.itemName or ("Item "..tostring(button.itemID or "?"))
  local prefix=(tonumber(button.itemCount) or 1)>1 and (tostring(button.itemCount).."x ") or ""
  return prefix..color.."|Hitem:"..tostring(button.itemID)..ITEM_SUFFIX.."|h["..name.."]|h|r"
end

local function UpdateRewardButtonText(button)
  if button and button.text then button.text:SetText(RewardLinkText(button)) end
end

local function RewardButtonUpdate()
  this.refreshCount=(this.refreshCount or 0)+1
  if not this.itemColor and this.itemID then
    GameTooltip:SetHyperlink("item:"..tostring(this.itemID)..ITEM_SUFFIX)
    GameTooltip:Hide()
    local name,_,quality=GetItemInfo(this.itemID)
    if name and name~="" then this.itemName=name end
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
      local c=ITEM_QUALITY_COLORS[quality]
      local r=math.ceil((c.r or 1)*255); local g=math.ceil((c.g or 1)*255); local b=math.ceil((c.b or 1)*255)
      this.itemColor="|c"..string.format("ff%02x%02x%02x",r,g,b)
    end
    UpdateRewardButtonText(this)
  end
  if (this.refreshCount or 0)>10 or this.itemColor then this:SetScript("OnUpdate",nil) end
end

local function ConfigureRewardButton(button,itemID,count)
  button.itemID=tonumber(itemID)
  button.itemCount=tonumber(count) or 1
  button.itemName=QuestieOcto.DatabaseAPI:GetItemName(button.itemID)
  button.itemColor=nil
  button.refreshCount=0
  UpdateRewardButtonText(button)
  button:SetScript("OnUpdate",RewardButtonUpdate)
  button:Show()
end

function R:RefreshDetails()
  if not self.detailText then return end
  self.detailText:SetText(self:GetQuestDetails())

  for i=1,table.getn(self.rewardRows or {}) do
    local row=self.rewardRows[i]
    row:Hide(); row:SetScript("OnUpdate",nil)
  end
  if self.rewardHeading then self.rewardHeading:Hide() end
  if self.rewardMoney then self.rewardMoney:Hide() end
  if self.choiceHeading then self.choiceHeading:Hide() end
  if self.rewardPanel then self.rewardPanel:Hide() end

  local id=self.selectedQuestID
  if self.detailScroll and self.lastDetailQuestID~=id then
    self.detailScroll:SetVerticalScroll(0)
    self.lastDetailQuestID=id
  end

  local rewardHeight=0
  local rewards=id and QuestieOcto.DatabaseAPI.GetQuestRewards and QuestieOcto.DatabaseAPI:GetQuestRewards(id) or nil
  if rewards and self.rewardPanel then
    local money=math.max(0,tonumber(rewards.money) or 0)
    local maxBonus=math.max(0,tonumber(rewards.maxLevelMoney) or 0)
    local playerLevel=UnitLevel("player") or 1
    local maxLevel=tonumber(MAX_PLAYER_LEVEL) or 60
    if playerLevel>=maxLevel then money=money+maxBonus end
    local hasItems=rewards.items and table.getn(rewards.items)>0
    local hasChoices=rewards.choices and table.getn(rewards.choices)>0

    if money>0 or hasItems or hasChoices then
      local y=-2
      self.rewardHeading:ClearAllPoints(); self.rewardHeading:SetPoint("TOPLEFT",self.rewardPanel,"TOPLEFT",0,y); self.rewardHeading:Show(); y=y-20
      if money>0 then
        self.rewardMoney:SetText("Money: "..FormatMoney(money)); self.rewardMoney:ClearAllPoints(); self.rewardMoney:SetPoint("TOPLEFT",self.rewardPanel,"TOPLEFT",0,y); self.rewardMoney:Show(); y=y-18
      end
      local rowIndex=1
      for i=1,table.getn(rewards.items or {}) do
        local entry=rewards.items[i]
        local row=self.rewardRows[rowIndex]
        if row and entry then
          row:ClearAllPoints(); row:SetPoint("TOPLEFT",self.rewardPanel,"TOPLEFT",0,y); ConfigureRewardButton(row,entry[1],entry[2]); y=y-18; rowIndex=rowIndex+1
        end
      end
      if hasChoices then
        self.choiceHeading:ClearAllPoints(); self.choiceHeading:SetPoint("TOPLEFT",self.rewardPanel,"TOPLEFT",0,y-2); self.choiceHeading:Show(); y=y-22
        for i=1,table.getn(rewards.choices or {}) do
          local entry=rewards.choices[i]
          local row=self.rewardRows[rowIndex]
          if row and entry then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",self.rewardPanel,"TOPLEFT",0,y); ConfigureRewardButton(row,entry[1],entry[2]); y=y-18; rowIndex=rowIndex+1
          end
        end
      end
      rewardHeight=math.max(28,-y+4)
      self.rewardPanel:SetHeight(rewardHeight)
      self.rewardPanel:Show()
    end
  end

  if self.detailScroll and self.detailBG then
    self.detailScroll:ClearAllPoints()
    self.detailScroll:SetPoint("TOPLEFT",self.detailBG,"TOPLEFT",8,-8)
    self.detailScroll:SetPoint("BOTTOMRIGHT",self.detailBG,"BOTTOMRIGHT",-27,8)
  end

  if self.detailContent then
    -- Vanilla/Turtle's FontString API does not reliably expose GetStringHeight().
    -- GetHeight() is the compatible Region measurement and is updated after SetText.
    -- Anchor Rewards directly below the quest text so moving them into this shared
    -- scroll child cannot leave the panel unpositioned if text measurement differs.
    local baseHeight=self.detailText:GetHeight() or 0
    if self.rewardPanel and rewardHeight>0 then
      self.rewardPanel:ClearAllPoints()
      self.rewardPanel:SetPoint("TOPLEFT",self.detailText,"BOTTOMLEFT",0,-14)
      self.rewardPanel:Show()
    end
    local totalHeight=baseHeight+20
    if rewardHeight>0 then totalHeight=baseHeight+rewardHeight+34 end
    -- Keep the scroll child at least as tall as the visible pane, while allowing
    -- long quest text plus rewards to extend it naturally for scrolling.
    self.detailContent:SetHeight(math.max(470,totalHeight))
    if self.detailScroll and self.detailScroll.UpdateScrollChildRect then self.detailScroll:UpdateScrollChildRect() end
  end
end

function R:RefreshRows()
  if not self.frame or not self.frame:IsShown() then return end
  if self.statusText then self.statusText:SetText(self:GetStatusText()) end
  local offset=0
  if self.scroll and FauxScrollFrame_GetOffset then offset=FauxScrollFrame_GetOffset(self.scroll) or 0 end
  if self.scroll and FauxScrollFrame_Update then FauxScrollFrame_Update(self.scroll,table.getn(self.matches),self.rowCount,self.rowHeight) end

  for i=1,self.rowCount do
    local row=self.rows[i]
    local data=self.matches[offset+i]
    if data then
      row.questID=data.id
      row.text:SetText(StatusColor(data.status).."["..StatusLabel(data.status).."]|r "..data.title.."  |cff777777["..data.id.."]|r")
      if data.id==self.selectedQuestID then row.highlight:Show() else row.highlight:Hide() end
      row:Show()
    else
      row.questID=nil
      row:Hide()
    end
  end
  self:RefreshDetails()
end

function R:RefreshWindow(rebuild)
  if rebuild then self:RebuildResults(); return end
  self:RefreshRows()
end

local function MakeFilterButton(parent,label,value,x)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetWidth(82); b:SetHeight(22); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-64)
  b:SetText(label)
  b.value=value
  b:SetScript("OnClick",function() R:SetStatusFilter(this.value) end)
  return b
end

function R:OpenWindowNow()
  if self.frame then
    -- WorldMapFrame lives on FULLSCREEN. Keep the browser above it when opened
    -- from a map/minimap Shift-click, while remaining below TOOLTIP strata.
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:SetFrameLevel(100)
    self.frame:Show(); self.frame:Raise(); self:RefreshRows(); return
  end

  local f=CreateFrame("Frame","QuestieOctoQuestBrowser",UIParent)
  f:SetWidth(800); f:SetHeight(590); f:SetPoint("CENTER",UIParent,"CENTER",0,20)
  f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(100); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function() this:StartMoving() end); f:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
  f:SetBackdropColor(0.04,0.04,0.04,0.97)
  self.frame=f
  if UISpecialFrames then
    local registered=false
    for i=1,table.getn(UISpecialFrames) do if UISpecialFrames[i]=="QuestieOctoQuestBrowser" then registered=true break end end
    if not registered then table.insert(UISpecialFrames,"QuestieOctoQuestBrowser") end
  end

  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  title:SetPoint("TOP",f,"TOP",0,-18); title:SetText("Quests")
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5); close:SetScript("OnClick",function() R:CloseWindow() end)

  local search=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
  search:SetWidth(285); search:SetHeight(20); search:SetPoint("TOPLEFT",f,"TOPLEFT",24,-40); search:SetAutoFocus(false); search:SetText(self.query or "")
  search:SetScript("OnEnterPressed",function() this:ClearFocus(); R:SetQuery(this:GetText() or "") end)
  self.searchBox=search
  local searchButton=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
  searchButton:SetWidth(70); searchButton:SetHeight(22); searchButton:SetPoint("LEFT",search,"RIGHT",8,0); searchButton:SetText("Search")
  searchButton:SetScript("OnClick",function() R:SetQuery(R.searchBox:GetText() or "") end)

  self.filterButtons={
    MakeFilterButton(f,"All","all",24), MakeFilterButton(f,"Available","available",110),
    MakeFilterButton(f,"Active","active",196), MakeFilterButton(f,"Completed","completed",282)
  }

  local status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  status:SetPoint("TOPLEFT",f,"TOPLEFT",24,-94); status:SetWidth(355); status:SetJustifyH("LEFT")
  self.statusText=status

  local listBG=CreateFrame("Frame",nil,f); listBG:SetPoint("TOPLEFT",f,"TOPLEFT",20,-114); listBG:SetWidth(360); listBG:SetHeight(420)
  listBG:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}); listBG:SetBackdropColor(0,0,0,0.72)

  self.rows={}
  for i=1,self.rowCount do
    local row=CreateFrame("Button",nil,listBG)
    row:SetHeight(self.rowHeight); row:SetWidth(330); row:SetPoint("TOPLEFT",listBG,"TOPLEFT",8,-8-(i-1)*self.rowHeight)
    local hl=row:CreateTexture(nil,"BACKGROUND"); hl:SetAllPoints(row); hl:SetTexture(0.25,0.25,0.25,0.65); hl:Hide(); row.highlight=hl
    local text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",row,"LEFT",2,0); text:SetWidth(326); text:SetJustifyH("LEFT"); row.text=text
    row:SetScript("OnClick",function() if this.questID then R.selectedQuestID=this.questID; R:RefreshRows() end end)
    self.rows[i]=row
  end
  local scroll=CreateFrame("ScrollFrame","QuestieOctoQuestBrowserScroll",listBG,"FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",listBG,"TOPLEFT",0,-6); scroll:SetPoint("BOTTOMRIGHT",listBG,"BOTTOMRIGHT",-24,6)
  scroll:SetScript("OnVerticalScroll",function() FauxScrollFrame_OnVerticalScroll(R.rowHeight,function() R:RefreshRows() end) end)
  self.scroll=scroll

  local detailBG=CreateFrame("Frame",nil,f); detailBG:SetPoint("TOPLEFT",f,"TOPLEFT",395,-40); detailBG:SetWidth(380); detailBG:SetHeight(494)
  detailBG:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}); detailBG:SetBackdropColor(0,0,0,0.72)
  self.detailBG=detailBG
  local detailScroll=CreateFrame("ScrollFrame","QuestieOctoQuestBrowserDetailScroll",detailBG,"UIPanelScrollFrameTemplate")
  detailScroll:SetPoint("TOPLEFT",detailBG,"TOPLEFT",8,-8); detailScroll:SetPoint("BOTTOMRIGHT",detailBG,"BOTTOMRIGHT",-27,8)
  local detailContent=CreateFrame("Frame",nil,detailScroll); detailContent:SetWidth(337); detailContent:SetHeight(470); detailScroll:SetScrollChild(detailContent)
  self.detailScroll=detailScroll; self.detailContent=detailContent
  local detail=detailContent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); detail:SetPoint("TOPLEFT",detailContent,"TOPLEFT",0,0); detail:SetWidth(337); detail:SetJustifyH("LEFT"); detail:SetJustifyV("TOP"); detail:SetText("")
  self.detailText=detail
  local rewardPanel=CreateFrame("Frame",nil,detailContent); rewardPanel:SetWidth(337); rewardPanel:SetHeight(1); rewardPanel:Hide(); self.rewardPanel=rewardPanel
  local rewardHeading=rewardPanel:CreateFontString(nil,"OVERLAY","GameFontNormal"); rewardHeading:SetText("Rewards"); rewardHeading:SetJustifyH("LEFT"); rewardHeading:Hide(); self.rewardHeading=rewardHeading
  local rewardMoney=rewardPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); rewardMoney:SetJustifyH("LEFT"); rewardMoney:Hide(); self.rewardMoney=rewardMoney
  local choiceHeading=rewardPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); choiceHeading:SetText("Choose one:"); choiceHeading:SetJustifyH("LEFT"); choiceHeading:Hide(); self.choiceHeading=choiceHeading
  self.rewardRows={}
  for i=1,10 do
    local row=CreateFrame("Button",nil,rewardPanel); row:SetWidth(330); row:SetHeight(18); row:Hide()
    local text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",row,"LEFT",0,0); text:SetWidth(328); text:SetJustifyH("LEFT"); row.text=text
    row:SetScript("OnEnter",function() if this.itemID then GameTooltip:SetOwner(this,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..tostring(this.itemID)..ITEM_SUFFIX); GameTooltip:Show() end end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    row:SetScript("OnClick",function()
      if this.itemID and SetItemRef then
        local link="item:"..tostring(this.itemID)..ITEM_SUFFIX
        local color=this.itemColor or "|cffffffff"
        local name=this.itemName or ("Item "..tostring(this.itemID))
        local text=color.."|H"..link.."|h["..name.."]|h|r"
        SetItemRef(link,text,arg1)
      end
    end)
    self.rewardRows[i]=row
  end

  self:RefreshRows()
end

-- Open the Quest Browser directly on one known quest. Map/minimap Shift-click
-- uses an exact numeric search so the selected quest is unambiguous even when
-- several quests share the same localized title.
function R:OpenQuest(questID)
  questID=tonumber(questID)
  if not questID or questID<=0 then return false end
  if not QuestieOcto.QuestModel or not QuestieOcto.QuestModel:Get(questID) then return false end

  self.query=tostring(questID)
  self.statusFilter="all"
  self.selectedQuestID=questID

  QuestieOcto.Scheduler:After(0.03,function()
    local options=QuestieOcto.Options
    if options then
      options.openedFromGameMenu=false
      if options.Hide then options:Hide() end
      if options.configFrame and options.configFrame.frame then options.configFrame.frame:Hide() end
    end
    if GameMenuFrame and GameMenuFrame:IsShown() then
      if HideUIPanel then HideUIPanel(GameMenuFrame) else GameMenuFrame:Hide() end
    end

    R:OpenWindowNow()
    if R.searchBox then R.searchBox:SetText(R.query or "") end
    R:RebuildResults()
  end,"quest-browser-open-quest")
  return true
end

function R:OpenWindow()
  -- AceConfig refreshes the options frame after an execute callback returns.
  -- Defer the entire handoff, suppress GameMenu return, then close Options.
  QuestieOcto.Scheduler:After(0.03,function()
    local options=QuestieOcto.Options
    if options then
      options.openedFromGameMenu=false
      if options.Hide then options:Hide() end
      if options.configFrame and options.configFrame.frame then options.configFrame.frame:Hide() end
    end
    if GameMenuFrame and GameMenuFrame:IsShown() then
      if HideUIPanel then HideUIPanel(GameMenuFrame) else GameMenuFrame:Hide() end
    end
    R:OpenWindowNow()
  end,"quest-browser-open")
end

function R:CloseWindow()
  -- Invalidate any stale selection/search generation. Searches are direct and
  -- bounded now, so there is no background database walk to cancel.
  self.searchGeneration=(self.searchGeneration or 0)+1
  self.searching=false
  if self.frame then self.frame:Hide() end
end

function R:GetOptionsTab()
  return {
    name="Quests",type="group",order=14,
    args={},
  }
end

function R:OnStateChanged()
  if self.frame and self.frame:IsShown() then
    -- Do not rebuild full searches on every quest-state signal. Existing rows
    -- simply update their current status; explicit user search/filter rebuilds.
    for i=1,table.getn(self.matches) do self.matches[i].status=QuestStatus(self.matches[i].id) end
    self:RefreshRows()
  end
end

QuestieOcto:RegisterMessage("COMPLETION_READY",R,"OnStateChanged")
QuestieOcto:RegisterMessage("DATABASE_API_READY",R,"OnStateChanged")
QuestieOcto:RegisterMessage("AVAILABLE_QUESTS_READY",R,"OnStateChanged")
QuestieOcto:RegisterMessage("QUEST_LOG_CHANGED",R,"OnStateChanged")
