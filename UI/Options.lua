QuestieOcto.Options = QuestieOcto.Options or {}
local O = QuestieOcto.Options

O.configFrame=nil
O.initialized=false
O.openedFromGameMenu=false
O.stats={
  initializes=0,opens=0,closes=0,changes=0,
  lastSetKey="none",lastSetValue="none",
  aceGUI=false,aceRegistry=false,aceDialog=false
}

local APP_NAME="Questie Options"

-- ShaguTweaks' Darkened UI is the Vanilla compatibility reference here.
-- Keep the original Questie outer-shell tint, but treat the AceConfig content
-- like ShaguTweaks' Advanced Options: dark translucent backdrops instead of a
-- recursive gray vertex-color wash over every descendant texture.
local SHELL_R,SHELL_G,SHELL_B,SHELL_A=0.30,0.30,0.30,0.90
local INNER_R,INNER_G,INNER_B,INNER_A=0.035,0.035,0.035,0.84
local INNER_BORDER_R,INNER_BORDER_G,INNER_BORDER_B,INNER_BORDER_A=0.20,0.20,0.20,0.95
local TAB_R,TAB_G,TAB_B,TAB_A=0.28,0.28,0.28,1.0

-- Capture colors before Questie-Octo changes them so Dark Theme can be toggled
-- without guessing what AceGUI, pfUI, DragonflightUI, or another UI skin used.
-- Frames/regions are Lua objects on this client, so the small per-object cache
-- stays local to the Questie-Octo options tree and does not touch global UI.
local function CaptureBackdropColors(frame)
  if not frame or frame.questieOctoThemeCaptured then return end
  frame.questieOctoThemeCaptured=true

  if frame.GetBackdropColor then
    local r,g,b,a=frame:GetBackdropColor()
    frame.questieOctoBgR,frame.questieOctoBgG,frame.questieOctoBgB,frame.questieOctoBgA=r or 1,g or 1,b or 1,a or 1
  end
  if frame.GetBackdropBorderColor then
    local r,g,b,a=frame:GetBackdropBorderColor()
    frame.questieOctoBdR,frame.questieOctoBdG,frame.questieOctoBdB,frame.questieOctoBdA=r or 1,g or 1,b or 1,a or 1
  end
end

local function CaptureVertexColor(region)
  if not region or region.questieOctoVertexCaptured then return end
  region.questieOctoVertexCaptured=true
  if region.GetVertexColor then
    local r,g,b,a=region:GetVertexColor()
    region.questieOctoVR,region.questieOctoVG,region.questieOctoVB,region.questieOctoVA=r or 1,g or 1,b or 1,a or 1
  end
end

local function RestoreBackdropColors(frame)
  if not frame or not frame.questieOctoThemeCaptured then return end
  if frame.SetBackdropColor and frame.questieOctoBgR then
    frame:SetBackdropColor(frame.questieOctoBgR,frame.questieOctoBgG,frame.questieOctoBgB,frame.questieOctoBgA or 1)
  end
  if frame.SetBackdropBorderColor and frame.questieOctoBdR then
    frame:SetBackdropBorderColor(frame.questieOctoBdR,frame.questieOctoBdG,frame.questieOctoBdB,frame.questieOctoBdA or 1)
  end
end

local function RestoreVertexColor(region)
  if not region or not region.questieOctoVertexCaptured then return end
  if region.SetVertexColor and region.questieOctoVR then
    region:SetVertexColor(region.questieOctoVR,region.questieOctoVG,region.questieOctoVB,region.questieOctoVA or 1)
  end
end

local function RestoreDefaultTheme(frame)
  if not frame then return end
  RestoreBackdropColors(frame)

  if frame.GetRegions then
    local regions={frame:GetRegions()}
    for _,region in pairs(regions) do
      if region and region.GetObjectType and region:GetObjectType()=="Texture" then
        RestoreVertexColor(region)
      end
    end
  end

  if frame.GetChildren then
    local children={frame:GetChildren()}
    for _,child in pairs(children) do
      RestoreDefaultTheme(child)
    end
  end
end

local function ShouldSkipShellTexture(region)
  if not region or not region.GetTexture then return true end
  local texture=region:GetTexture()
  if not texture then return true end

  local name=region.GetName and region:GetName() or nil
  if name then
    if string.find(name,"Button",1,true) or string.find(name,"Icon",1,true) then return true end
  end

  if type(texture)=="string" then
    if string.find(texture,"Button",1,true)
       or string.find(texture,"Icon",1,true)
       or string.find(texture,"WHITE8X8",1,true)
       or string.find(texture,"StatusBar",1,true)
       or string.find(texture,"BarFill",1,true)
       or string.find(texture,"Portrait",1,true) then
      return true
    end
  end

  if region.GetBlendMode and region:GetBlendMode()=="ADD" then return true end
  return false
end

-- Only tint the physical AceGUI Frame itself. This preserves the successful
-- outer-frame look from 0.1.81 without washing the entire options contents gray.
local function DarkenOuterShell(frame)
  if not frame then return end

  CaptureBackdropColors(frame)
  if frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(SHELL_R,SHELL_G,SHELL_B,SHELL_A)
  end

  if frame.GetRegions then
    local regions={frame:GetRegions()}
    for _,region in pairs(regions) do
      if region and region.GetObjectType and region:GetObjectType()=="Texture"
         and region.SetVertexColor and not ShouldSkipShellTexture(region) then
        CaptureVertexColor(region)
        region:SetVertexColor(SHELL_R,SHELL_G,SHELL_B,SHELL_A)
      end
    end
  end
end

local function IsTabTexture(region)
  if not region or not region.GetTexture then return false end
  local texture=region:GetTexture()
  return type(texture)=="string" and string.find(texture,"ChatFrameTab",1,true) and true or false
end

-- AceGUI's ScrollFrame places a UIPanelScrollBarTemplate just outside the
-- scrolling viewport. Keep that native Vanilla control above Questie's dark
-- content panels and do not recolor it as if it were a backdrop container.
local function IsAceConfigScrollbar(frame)
  if not frame or not frame.GetName then return false end
  local name=frame:GetName()
  return name and string.find(name,"AceConfigDialogScrollFrame",1,true)
              and string.find(name,"ScrollBar",1,true) and true or false
end

local function RaiseScrollbar(frame)
  if not frame then return end

  if IsAceConfigScrollbar(frame) then
    local parent=frame.GetParent and frame:GetParent() or nil
    local base=(parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
    if frame.SetFrameLevel then frame:SetFrameLevel(base+20) end

    -- Vanilla's UIPanelScrollBarTemplate thumb artwork is wider than the
    -- 16-pixel Slider frame used by AceGUI. On the 1.12 client that narrow
    -- slider can crop the outer edge of the native thumb texture even though
    -- the control is correctly positioned in the right gutter. Give the
    -- slider its native visual width instead of moving it inward; this lets the
    -- full thumb render at the same right-side location.
    if frame.SetWidth and (not frame.questieOctoFullThumbWidth) then
      frame:SetWidth(20)
      frame.questieOctoFullThumbWidth=true
    end

    -- UIPanelScrollBarTemplate's arrow buttons and thumb artwork are children/
    -- regions of the slider. Raising them too avoids client-specific 1.12
    -- ordering where the thumb can otherwise appear partly behind the panel.
    if frame.GetChildren then
      local children={frame:GetChildren()}
      for _,child in pairs(children) do
        if child and child.SetFrameLevel then child:SetFrameLevel(base+21) end
      end
    end
    return
  end

  if frame.GetChildren then
    local children={frame:GetChildren()}
    for _,child in pairs(children) do
      RaiseScrollbar(child)
    end
  end
end

-- ShaguTweaks' own config builds dark panels by coloring frame backdrops
-- (.1/.1/.1) rather than painting a gray vertex color over all child regions.
-- Do the same for Questie's AceGUI content tree. Backdrop-less controls remain
-- untouched; their native checkbox/slider/button artwork therefore stays crisp.
local function DarkenInnerContent(frame)
  if not frame then return end

  -- Leave the native Vanilla scrollbar completely untouched by the panel
  -- darkening pass. It is a control, not a content backdrop.
  if IsAceConfigScrollbar(frame) then return end

  CaptureBackdropColors(frame)
  if frame.SetBackdropColor then
    frame:SetBackdropColor(INNER_R,INNER_G,INNER_B,INNER_A)
  end
  if frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(INNER_BORDER_R,INNER_BORDER_G,INNER_BORDER_B,INNER_BORDER_A)
  end

  -- The top Questie tabs use ChatFrameTab textures instead of a backdrop.
  -- Tint only that known decorative texture; do not touch checkbox, slider,
  -- icon, highlight or status-bar artwork.
  if frame.GetRegions then
    local regions={frame:GetRegions()}
    for _,region in pairs(regions) do
      if region and region.GetObjectType and region:GetObjectType()=="Texture"
         and region.SetVertexColor and IsTabTexture(region) then
        CaptureVertexColor(region)
        region:SetVertexColor(TAB_R,TAB_G,TAB_B,TAB_A)
      end
    end
  end

  if frame.GetChildren then
    local children={frame:GetChildren()}
    for _,child in pairs(children) do
      DarkenInnerContent(child)
    end
  end
end

function O:ApplyDarkTheme(apply)
  if not self.configFrame or not self.configFrame.frame then return end

  -- Initial opens and AceConfig's post-refresh callback use the saved setting.
  if apply==nil then
    apply=(QuestieOcto.MinimapSettings and QuestieOcto.MinimapSettings:Get("useDarkTheme")) and true or false
  end

  local shell=self.configFrame.frame
  if apply then
    DarkenOuterShell(shell)

    -- Apply the inner treatment only below the outer shell. Keeping the shell
    -- separate is important because its DialogFrame textures need vertex tinting,
    -- while AceConfig's content containers look better with dark backdrops.
    if shell.GetChildren then
      local children={shell:GetChildren()}
      for _,child in pairs(children) do
        DarkenInnerContent(child)
      end
    end
  else
    -- Restore the exact colors captured before our dark pass. New AceConfig
    -- widgets that were never darkened are already at their native/skin values.
    RestoreDefaultTheme(shell)
  end

  -- Keep the native Vanilla scrollbar above the content in either theme.
  RaiseScrollbar(shell)
end

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function ClearSavedConfigPosition()
  local Dialog=LibStub and LibStub("QuestieOcto-AceConfigDialog-3.0",true)
  if not Dialog or not Dialog.GetStatusTable then return end

  local status=Dialog:GetStatusTable(APP_NAME)
  if status then
    status.top=nil
    status.left=nil
  end
end

local function GetValue(info)
  local key=info[table.getn(info)]
  return Settings():Get(key)
end

local function SetValue(info,value)
  local key=info[table.getn(info)]
  O.stats.lastSetKey=tostring(key or "nil")
  O.stats.lastSetValue=tostring(value)
  local changed=Settings():Set(key,value)
  if changed then
    O.stats.changes=O.stats.changes+1
  end
  if O.configFrame and O.configFrame.SetStatusText then
    O.configFrame:SetStatusText(nil)
  end

  -- AceConfigDialog refreshes the custom frame immediately after setters.
  -- Clear AceGUI's persisted drag coordinates before that refresh happens.
  ClearSavedConfigPosition()
end

local function SetMinimapButtonValue(info,value)
  local before=Settings():Get("showMinimapButton") and true or false
  SetValue(info,value)
  local after=Settings():Get("showMinimapButton") and true or false
  if before~=after then
    QuestieOcto:Print("Minimap Button change will apply after /reload. When disabled, its minimap frame is not created.")
  end
end

local function EnabledMinimap()
  return Settings():Get("enableMiniMapIcons") and true or false
end

local function CreateQuestBrowserFooterButton(configFrame)
  if not configFrame or not configFrame.frame or configFrame.questieOctoQuestBrowserButton then return end

  local shell=configFrame.frame
  local statusbg=configFrame.statustext and configFrame.statustext:GetParent()
  -- UIPanelButtonTemplate stretches its complete artwork at wide widths, which
  -- distorts the footer button. Template2 keeps fixed left/right caps and only
  -- expands the middle section, matching AceGUI's normal wide button behavior.
  -- Template2's XML scripts resolve $parentLeft/Middle/Right through the global
  -- button name, so this frame must be named rather than anonymous.
  local button=CreateFrame("Button","QuestieOctoQuestBrowserFooterButton",shell,"UIPanelButtonTemplate2")
  button:SetPoint("BOTTOMLEFT",shell,"BOTTOMLEFT",15,17)
  button:SetWidth(170)
  button:SetHeight(20)
  button:SetText("Quest Browser")
  button:SetScript("OnClick",function()
    QuestieOcto.QuestResearch:OpenWindow()
  end)

  configFrame.questieOctoQuestBrowserButton=button
  configFrame.questieOctoStatusBackground=statusbg

  -- AceGUI normally reserves this exact bottom-left strip as a validation
  -- status area. Use it for Quest Browser during normal operation, but keep
  -- SetStatusText functional: a real validation message temporarily replaces
  -- the button instead of being hidden behind it.
  local originalSetStatusText=configFrame.SetStatusText
  if originalSetStatusText then
    configFrame.questieOctoOriginalSetStatusText=originalSetStatusText
    configFrame.SetStatusText=function(self,message)
      originalSetStatusText(self,message)
      if message and tostring(message)~="" then
        button:Hide()
        if statusbg then statusbg:Show() end
      else
        if statusbg then statusbg:Hide() end
        button:Show()
      end
    end
  else
    if statusbg then statusbg:Hide() end
    button:Show()
  end

  if configFrame.SetStatusText then
    configFrame:SetStatusText(nil)
  end
end


local function CreateGeneralTab()
  return {
    name="General", type="group", order=1,
    args={
      world_map_visibility_header={type="header",order=2,name="World Map Visibility"},
      enableMapIcons={type="toggle",order=2.1,name="Show Quests",desc="Show quest icons on the main map.",width="full",get=GetValue,set=SetValue},
      showAvailableQuestsWorldMap={type="toggle",order=2.2,name="Show Available Quests on the World Map",desc="Show available quest pickup icons on continent maps.",width="full",get=GetValue,set=SetValue},
      showCompletedQuestsWorldMap={type="toggle",order=2.3,name="Show Completed Quests on the World Map",desc="Show completed quest turn-in icons on continent maps.",width="full",get=GetValue,set=SetValue},
      showSpecialQuestsWorldMap={type="toggle",order=2.4,name="Show Special Quests on the World Map",desc="Show repeatable, PvP, and active event quest icons on continent maps.",width="full",get=GetValue,set=SetValue},
      showMapFlightMaster={type="toggle",order=2.5,name="Show Flight Master on the World Map",desc="Show Flight Master icons on the map.",width="full",get=GetValue,set=SetValue},
      enableMiniMapIcons={type="toggle",order=3,name="Enable Minimap Icons",desc="Show quest icons on the minimap.",width="full",get=GetValue,set=SetValue},
      enableObjectives={type="toggle",order=4,name="Enable Objective Icons",desc="Show active quest objectives on the map and minimap.",width="full",get=GetValue,set=SetValue},
      enableTurnins={type="toggle",order=5,name="Enable Completed Quest Icons",desc="Show completed quest turn-ins on the map and minimap.",width="full",get=GetValue,set=SetValue},
      enableAvailable={type="toggle",order=6,name="Enable Available Quest Icons",desc="Show available quests on the map and minimap.",width="full",get=GetValue,set=SetValue},

      showAvailableQuestMapCurrentZone = {
        type = "toggle",
        order = 2.21,
        name = "Limit Available Quests to Current Zone",
        desc = "Only show available quest-giver and item-start icons on the World Map while viewing your current zone.",
        width = "full",
        disabled = function()
          return not Settings():Get("showAvailableQuestsWorldMap")
        end,
        get = GetValue,
        set = SetValue
      },
      showTurninsCurrentZoneMap = {
        type = "toggle",
        order = 2.31,
        name = "Limit Turn-Ins to Current Zone",
        desc = "Only show completed quest ? icons on the World Map while viewing your current zone.",
        width = "full",
        disabled = function()
          return not Settings():Get("showCompletedQuestsWorldMap")
        end,
        get = GetValue,
        set = SetValue
      },

      objective_density_label={type="description",order=8,name="Objective",fontSize="medium",width="normal"},
      objectiveNodeDensity={type="select",order=8.1,name="",desc="Clustered groups nearby spawns. Full Nodes shows every known spawn.",width="normal",values={clustered="Clustered",full="Full Nodes"},get=GetValue,set=SetValue},

      item_start_header={type="header",order=9,name="Item-Start Quests"},
      showItemStartQuests={type="toggle",order=9.1,name="Show Item-Start Quests",desc="Show quests started by dropped or looted items.",width="full",get=GetValue,set=SetValue},
      showItemStartMap={type="toggle",order=9.2,name="Show on World Map",desc="Show item-start quest sources on the World Map.",width="full",disabled=function() return not Settings():Get("showItemStartQuests") end,get=GetValue,set=SetValue},
      showItemStartMinimap={type="toggle",order=9.3,name="Show on Minimap",desc="Show item-start quest sources on the minimap.",width="normal",disabled=function() return not Settings():Get("showItemStartQuests") end,get=GetValue,set=SetValue},
      itemStartDensity={type="select",order=9.4,name="",desc="Clustered groups nearby sources. Full Nodes shows every known source.",width="normal",values={clustered="Clustered",full="Full Nodes"},disabled=function() return not Settings():Get("showItemStartQuests") end,get=GetValue,set=SetValue},

      quest_options_header={type="header",order=10,name="Quest Options"},
      showLowLevelQuests={type="toggle",order=10.2,name="Show Low-Level Quests",desc="Show quests below the normal green quest range.",get=GetValue,set=SetValue},
      lowLevelQuestRange={type="range",order=10.21,name=function()
        local value=tonumber(Settings():Get("lowLevelQuestRange")) or 35
        if value>=35 then return "Levels Below: All" end
        return "Levels Below: "..tostring(value)
      end,desc="Limit how many levels below you are shown. All removes the limit.",width="normal",min=5,max=35,step=5,arg={questieHideEditBox=true,questieMaxLabel="All",questieCommitOnMouseUp=true,questieLiveLabelPrefix="Levels Below: "},disabled=function() return not Settings():Get("showLowLevelQuests") end,get=GetValue,set=SetValue},
      showRepeatableQuests={type="toggle",order=10.3,name="Show Repeatable Quests",desc="Show available repeatable quests.",width="full",get=GetValue,set=SetValue},
      showEventQuests={type="toggle",order=10.4,name="Show Event Quests",desc="Show available event quests.",width="full",get=GetValue,set=SetValue},
      showPvPRelatedQuests={type="toggle",order=10.5,name="Show PVP Related Quests",desc="Show PvP quest icons on the map and minimap.",width="full",get=GetValue,set=SetValue},
    },
  }
end

local function CreateMapTab()
  return {
    name="Map", type="group", order=10,
    args={
      map_options={type="header",order=1,name="Map Options"},
      alwaysGlowMap={type="toggle",order=1.1,name="Enable Map Icon Glow",desc="Add a colored glow behind objective icons.",width="full",get=GetValue,set=SetValue},
      questObjectiveColors={type="toggle",order=1.2,name="Enable Different Map Icon Color for Each Quest",desc="Use a different color for each quest's objective icons.",width="full",get=GetValue,set=SetValue},
      globalScale={type="range",order=2.2,name="Global Scale for Map Icons",desc="Adjust map icon size.",width="double",min=0.01,max=4,step=0.01,disabled=function() return not Settings():Get("enableMapIcons") end,get=GetValue,set=SetValue},

      miscellaneous_icons={type="header",order=20,name="Miscellaneous icons"},
      showMapRareMonsters={type="toggle",order=20.1,name="Rare Monsters",desc="Show Rare Monster icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapAuctioneer={type="toggle",order=20.2,name="Auctioneer",desc="Show Auctioneer icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapBanker={type="toggle",order=20.3,name="Banker",desc="Show Banker icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapFlightMaster={type="toggle",order=20.4,name="Flight Master",desc="Show Flight Master icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapMailbox={type="toggle",order=20.5,name="Mailbox",desc="Show Mailbox icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapBattlemaster={type="toggle",order=20.6,name="Battlemaster",desc="Show Battlemaster icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapInnkeeper={type="toggle",order=20.7,name="Innkeeper",desc="Show Innkeeper icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapMeetingStone={type="toggle",order=20.8,name="Meeting Stones",desc="Show Meeting Stone icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapRepair={type="toggle",order=20.9,name="Repair",desc="Show Repair icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapSpiritHealer={type="toggle",order=21.0,name="Spirit Healer",desc="Show Spirit Healer icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapStableMaster={type="toggle",order=21.1,name="Stable Master",desc="Show Stable Master icons on the map.",width="full",get=GetValue,set=SetValue},
      showMapVendor={type="toggle",order=21.2,name="Vendor",desc="Show Vendor icons on the map.",width="full",get=GetValue,set=SetValue},
    },
  }
end

local function CreateMinimapTab()
  return {
    name="Minimap", type="group", order=11,
    args={
      options_header={type="header",order=1,name="Minimap Options"},
      alwaysGlowMinimap={type="toggle",order=1.1,name="Enable Minimap Icon Glow",desc="Add a colored glow behind objective icons.",width="full",disabled=function() return not EnabledMinimap() end,get=GetValue,set=SetValue},
      questMinimapObjectiveColors={type="toggle",order=1.2,name="Enable Different Minimap Icon Color for Each Quest",desc="Use a different color for each quest's objective icons.",width="full",disabled=function() return not EnabledMinimap() end,get=GetValue,set=SetValue},
      globalMiniMapScale={type="range",order=2.2,name="Global Scale for Minimap Icons",desc="Adjust minimap icon size.",width="double",min=0.01,max=4,step=0.01,disabled=function() return not EnabledMinimap() end,get=GetValue,set=SetValue},

      miscellaneous_icons={type="header",order=20,name="Miscellaneous icons"},
      showMinimapRareMonsters={type="toggle",order=20.1,name="Rare Monsters",desc="Show Rare Monster icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapAuctioneer={type="toggle",order=20.2,name="Auctioneer",desc="Show Auctioneer icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapBanker={type="toggle",order=20.3,name="Banker",desc="Show Banker icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapFlightMaster={type="toggle",order=20.4,name="Flight Master",desc="Show Flight Master icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapMailbox={type="toggle",order=20.5,name="Mailbox",desc="Show Mailbox icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapBattlemaster={type="toggle",order=20.6,name="Battlemaster",desc="Show Battlemaster icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapInnkeeper={type="toggle",order=20.7,name="Innkeeper",desc="Show Innkeeper icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapMeetingStone={type="toggle",order=20.8,name="Meeting Stones",desc="Show Meeting Stone icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapRepair={type="toggle",order=20.9,name="Repair",desc="Show Repair icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapSpiritHealer={type="toggle",order=21.0,name="Spirit Healer",desc="Show Spirit Healer icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapStableMaster={type="toggle",order=21.1,name="Stable Master",desc="Show Stable Master icons on the minimap.",width="full",get=GetValue,set=SetValue},
      showMinimapVendor={type="toggle",order=21.2,name="Vendor",desc="Show Vendor icons on the minimap.",width="full",get=GetValue,set=SetValue},
    },
  }
end

local function CreateTrackerTab()
  return {
    name="Tracker", type="group", order=12,
    args={
      tracker_header={type="header",order=1,name="Tracker Options"},
      trackerEnabled={type="toggle",order=2,name="Enable Quest Tracker",desc="Show or hide the quest tracker.",width="full",get=GetValue,set=SetValue},
      resetTracker={type="execute",order=30.1,name="Reset Tracker Position",desc="Return the tracker to its default position.",func=function()
        if QuestieOcto.TrackerFrame and QuestieOcto.TrackerFrame.ResetLocation then QuestieOcto.TrackerFrame:ResetLocation() end
      end},
      trackerLocked={type="toggle",order=3,name="Lock Tracker",desc="Prevent the tracker from being moved.",width="full",get=GetValue,set=SetValue},
      trackerAutoTrack={type="toggle",order=4,name="Auto Track Quests",desc="Automatically track accepted quests.",width="full",get=GetValue,set=SetValue},
      questLogShowLevels={type="toggle",order=4.4,name="Show Quest Levels in the Quest Log",desc="Show quest levels in the Quest Log.",width="full",get=GetValue,set=SetValue},
      trackerQuestLogCheckmarks={type="toggle",order=4.5,name="Show Quest Log Checkmarks",desc="Show the native checkmark beside quests tracked by Questie-Octo.",width="full",get=GetValue,set=SetValue},
      trackerShowCompleted={type="toggle",order=5,name="Show Completed Quests",desc="Keep completed quests visible until turned in.",width="full",get=GetValue,set=SetValue},
      trackerHideCompletedObjectives={type="toggle",order=6,name="Hide Completed Objectives",desc="Hide completed objective lines.",width="full",get=GetValue,set=SetValue},
      trackerHideInCombat={type="toggle",order=7,name="Hide Tracker in Combat",desc="Hide the tracker while in combat.",width="full",get=GetValue,set=SetValue},
      appearance_header={type="header",order=20,name="Appearance"},
      trackerSortLabel={type="description",order=20.05,name="Sort Quests",fontSize="medium",width="normal"},
      trackerSort={type="select",order=20.06,name="",desc="Choose how quests are sorted.",width="normal",values={zone="Zone",level="Level"},get=GetValue,set=SetValue},
      trackerOutlineText={type="toggle",order=20.1,name="Outline",desc="Add an outline to tracker text.",width="full",get=GetValue,set=SetValue},
      trackerThickOutlineText={type="toggle",order=20.2,name="Thick Outline",desc="Add a thicker outline to tracker text.",width="full",get=GetValue,set=SetValue},
      trackerFontSize={type="range",order=21,name="Font Size",desc="Adjust tracker text size.",width="double",min=8,max=18,step=1,get=GetValue,set=SetValue},
      trackerMaxWidth={type="range",order=22,name="Width",desc="Set the maximum tracker width.",width="double",min=200,max=500,step=10,get=GetValue,set=SetValue},
      trackerVisibleRows={type="range",order=23,name="Visible Rows",desc="Set the maximum number of visible rows.",width="double",min=6,max=60,step=1,get=GetValue,set=SetValue},
      trackerBackgroundOpacity={type="range",order=24,name="Background Opacity",desc="Adjust tracker background opacity.",width="double",min=0,max=1,step=0.05,get=GetValue,set=SetValue},
      manual_hint={type="description",order=30,name="Shift + Left Click a quest in the Quest Log to track or untrack it manually.",fontSize="medium"},
    },
  }
end

local function CreateTooltipTab()
  return {
    name="Tooltips", type="group", order=13,
    args={
      header={type="header",order=1,name="Tooltip Options"},
      enableTooltips={type="toggle",order=2,name="Enable Questie Tooltips",desc="Show quest information on map markers and world tooltips.",width="full",get=GetValue,set=SetValue},
      enableTooltipsQuestLevel={type="toggle",order=3,name="Show Quest Levels",desc="Show quest levels in tooltips.",width="full",disabled=function() return not Settings():Get("enableTooltips") end,get=GetValue,set=SetValue},
      enableTooltipDroprates={type="toggle",order=4,name="Show Drop Rates",desc="Show item drop rates.",width="full",disabled=function() return not Settings():Get("enableTooltips") end,get=GetValue,set=SetValue},
      id_header={type="header",order=10,name="Tooltip IDs"},
      enableTooltipsQuestID={type="toggle",order=11,name="Show Quest IDs",desc="Show quest IDs.",width="full",disabled=function() return not Settings():Get("enableTooltips") end,get=GetValue,set=SetValue},
      enableTooltipsNPCID={type="toggle",order=12,name="Show NPC IDs",desc="Show NPC IDs.",width="full",disabled=function() return not Settings():Get("enableTooltips") end,get=GetValue,set=SetValue},
      enableTooltipsItemID={type="toggle",order=13,name="Show Item IDs",desc="Show item IDs.",width="full",disabled=function() return not Settings():Get("enableTooltips") end,get=GetValue,set=SetValue},
    },
  }
end


local function CreateQuestTab()
  local tab=QuestieOcto.QuestResearch:GetOptionsTab()
  tab.name="Other"
  tab.args=tab.args or {}

  tab.args.automation_header={type="header",order=1,name="Quest Automation"}
  tab.args.autoAcceptQuests={type="toggle",order=2,name="Auto Accept Quests",desc="Automatically accept eligible quests from NPCs. Hold Shift while talking to an NPC to keep that conversation manual.",width="full",get=GetValue,set=SetValue}
  tab.args.autoTurnInQuests={type="toggle",order=3,name="Auto Turn In Quests",desc="Automatically advance and turn in completed quests when no manual reward choice or money confirmation is required. Hold Shift to keep that NPC conversation manual.",width="full",get=GetValue,set=SetValue}
  tab.args.autoAcceptGrayQuests={type="toggle",order=4,name="Auto Accept Gray Quests",desc="Allow Auto Accept Quests to accept gray/trivial quests.",width="full",disabled=function() return not Settings():Get("autoAcceptQuests") end,get=GetValue,set=SetValue}
  tab.args.autoIncludeRepeatableQuests={type="toggle",order=5,name="Include Repeatable Quests",desc="Allow quest automation to accept and turn in repeatable quests. The same repeatable quest is processed at most once per NPC conversation.",width="full",disabled=function() return not Settings():Get("autoAcceptQuests") and not Settings():Get("autoTurnInQuests") end,get=GetValue,set=SetValue}

  tab.args.interface_header={type="header",order=9,name="Interface"}
  tab.args.showZoneLevelRanges={type="toggle",order=10,name="Show Zone Level Ranges",desc="Show the recommended level range and Friendly, Hostile, or Contested status when hovering a zone on the continent World Map.",width="full",get=GetValue,set=SetValue}
  tab.args.useDarkTheme={type="toggle",order=11,name="Enable Dark Theme",desc="Use Questie-Octo's dark Shagu-style options appearance. This only skins the Questie-Octo settings window.",width="full",get=GetValue,set=SetValue}
  tab.args.showMinimapButton={type="toggle",order=12,name="Show Minimap Button",desc="Show the Questie-Octo settings button. Minimap-button panels can manage it like a normal addon button. Requires /reload when changed. When disabled, the button frame is not created at all.",width="full",get=GetValue,set=SetMinimapButtonValue}
  tab.args.reset_header={type="header",order=20,name="Reset Questie Options"}
  tab.args.reset_text={type="description",order=21,name="Quest data and completed-quest history are not deleted.",fontSize="medium"}
  tab.args.resetOptions={type="execute",order=22,name="Reset Options",desc="Restore option defaults.",func=function()
    local beforeMinimapButton=Settings():Get("showMinimapButton") and true or false
    Settings():Reset()
    if beforeMinimapButton~=(Settings():Get("showMinimapButton") and true or false) then
      QuestieOcto:Print("Minimap Button reset will apply after /reload.")
    end
    ClearSavedConfigPosition()
    local Registry=LibStub and LibStub("QuestieOcto-AceConfigRegistry-3.0",true)
    if Registry and Registry.NotifyChange then Registry:NotifyChange(APP_NAME) end
  end}

  return tab
end

local function CreateOptionsTable()
  return {
    name="Questie Options",
    type="group",
    childGroups="tab",
    args={
      general_tab=CreateGeneralTab(),
      map_tab=CreateMapTab(),
      minimap_tab=CreateMinimapTab(),
      tracker_tab=CreateTrackerTab(),
      tooltip_tab=CreateTooltipTab(),
      quests_tab=CreateQuestTab(),
    },
  }
end

function O:Initialize()
  if self.initialized then return true end

  local AceGUI=LibStub and LibStub("AceGUI-3.0",true)
  local Registry=LibStub and LibStub("QuestieOcto-AceConfigRegistry-3.0",true)
  local Dialog=LibStub and LibStub("QuestieOcto-AceConfigDialog-3.0",true)

  self.stats.aceGUI=AceGUI and true or false
  self.stats.aceRegistry=Registry and true or false
  self.stats.aceDialog=Dialog and true or false

  if not AceGUI or not Registry or not Dialog then
    QuestieOcto:Error("Questie-style AceConfig runtime unavailable")
    return false
  end

  -- Equivalent to Questie 5/6 RegisterOptionsTable(), without AceConfigCmd.
  -- We intentionally avoid Blizzard InterfaceOptions registration on 1.12.
  Registry:RegisterOptionsTable(APP_NAME,CreateOptionsTable())

  -- Questie 5.2.3/6.0.0/3.3.5 create a standalone AceGUI Frame, then feed
  -- AceConfigDialog into that frame and keep it for later toggling.
  local configFrame=AceGUI:Create("Frame")
  configFrame:Hide()

  Dialog:SetDefaultSize(APP_NAME,625,700)
  Dialog:Open(APP_NAME,configFrame)
  configFrame:SetLayout("Fill")

  -- Questie 5/6/3.3.5 use one persistent AceGUI frame as the options shell.
  -- On this Vanilla/Ace3v runtime, AceConfigDialog calls SetStatusTable() on
  -- that same custom root frame after every option activation. AceGUI Frame's
  -- SetStatusTable() immediately runs ApplyStatus(), which clears/reanchors the
  -- physical frame. Turtle's 1.12 layout path can therefore visibly jump the
  -- window even when status.top/status.left are nil.
  --
  -- The mature Questie behavior we need is simpler: refresh the option widgets,
  -- not the already-open outer shell. The frame is non-resizable here, so after
  -- its initial Questie size has been applied there is no legitimate refresh
  -- reason to re-run outer-frame geometry. Preserve the status table for Ace3
  -- semantics, but deliberately do not call ApplyStatus() on later refreshes.
  if configFrame.SetStatusTable then
    configFrame.SetStatusTable=function(self,status)
      if status then
        status.top=nil
        status.left=nil
        self.status=status
      end
    end
  end

  if configFrame.EnableResize then
    configFrame:EnableResize(false)
  end

  configFrame:Hide()
  self.configFrame=configFrame
  CreateQuestBrowserFooterButton(configFrame)

  -- Questie 5.2.3/6.0.0/3.3.5/7/8 register the actual standalone
  -- AceGUI config object in UISpecialFrames through a global name. The widget
  -- already exposes IsShown()/Hide(), so Vanilla ESC can close the real shell
  -- directly; no hidden proxy frame is required.
  QuestieOctoConfigFrame=configFrame
  local registered=false
  for _,name in pairs(UISpecialFrames or {}) do
    if name=="QuestieOctoConfigFrame" then registered=true break end
  end
  if not registered then
    table.insert(UISpecialFrames,"QuestieOctoConfigFrame")
  end

  -- Vanilla GameMenu compatibility: when Questie Options was opened from ESC,
  -- closing it returns to the Game Menu, matching ShaguTweaks' proven 1.12 flow.
  -- Slash-command opens do not trigger this behavior.
  configFrame:SetCallback("OnClose",function()
    O.stats.closes=O.stats.closes+1
    if O.openedFromGameMenu then
      local origin=O.openedFromGameMenu
      O.openedFromGameMenu=false
      if origin=="dragonflight" and DFRL and DFRL.menuframe then
        DFRL.menuframe:Show()
      elseif GameMenuFrame and ShowUIPanel then
        ShowUIPanel(GameMenuFrame)
      end
      if UpdateMicroButtons then UpdateMicroButtons() end
    end
  end)

  self.initialized=true
  self.stats.initializes=self.stats.initializes+1

  -- QuestieOctoConfigFrame above is the UISpecialFrames participant, matching
  -- the supplied Questie options architecture.

  return true
end

local function RecenterConfigFrame(configFrame)
  ClearSavedConfigPosition()

  if not configFrame or not configFrame.frame then return end
  local frame=configFrame.frame

  -- Keep Questie's persistent AceGUI frame architecture, but make drag
  -- placement temporary: every explicit open returns to the default center.
  if frame.ClearAllPoints then frame:ClearAllPoints() end
  if frame.SetPoint then frame:SetPoint("CENTER",UIParent,"CENTER",0,0) end
end

function O:Show()
  if not self:Initialize() then return end

  local Dialog=LibStub("QuestieOcto-AceConfigDialog-3.0")
  -- Questie 3.3.5 refreshes the existing standalone frame through Open().
  Dialog:Open(APP_NAME,self.configFrame)
  RecenterConfigFrame(self.configFrame)
  if self.configFrame.SetStatusText then self.configFrame:SetStatusText(nil) end
  self:ApplyDarkTheme()
  self.stats.opens=self.stats.opens+1
end

function O:Hide()
  if self.configFrame and self.configFrame:IsShown() then
    self.configFrame:Hide()
  end
end

function O:ShowFromGameMenu(origin)
  self.openedFromGameMenu=origin or true
  self:Show()
end

function O:Toggle()
  if not self:Initialize() then return end
  if self.configFrame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

-- Deliberately lazy: the full AceConfig/AceGUI tree is created only when the
-- player actually opens settings. Building a hidden 625x700 options tree during
-- login added avoidable allocations and layout work to the busiest startup window.
