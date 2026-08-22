QuestieOcto.MinimapSettings = QuestieOcto.MinimapSettings or {}
local S = QuestieOcto.MinimapSettings

-- Stable defaults across supplied Questie 5.2.3, 6.0.0, 3.3.5, 7.0.0, 8.0.0.
S.defaults={
  -- Questie global map/minimap presentation defaults.

  enableMapIcons=true,
  -- Continent/world-overview-only quest-state filters. Available covers pickup
  -- and item-start markers; Completed covers turn-ins. Special quests also
  -- require their separate Special gate. Zone/city maps/objectives are unaffected.
  showAvailableQuestsWorldMap=true,
  showCompletedQuestsWorldMap=true,
  -- Restrict World Map quest-state markers to the player's current zone.
  showAvailableQuestMapCurrentZone = true,
  showTurninsCurrentZoneMap = true,
  -- Continent/world-overview-only master for special quest markers:
  -- repeatable (blue), PvP (red), and verified seasonal/event (green).
  -- Selected zone/city maps are unaffected.
  showSpecialQuestsWorldMap=false,
  enableObjectives=true,
  enableTurnins=true,
  enableAvailable=true,
  globalScale=1,

  -- Questie 5.2.3/6.0.0 mature old-Questie icon-type defaults.

  -- Questie native objective-node presentation.
  objectiveNodeDensity="clustered",

  -- Item-start quests are visually quest starters, but their source density
  -- and map/minimap visibility are independent from ordinary available NPCs.
  showItemStartQuests=true,
  showItemStartMap=true,
  showItemStartMinimap=true,
  itemStartDensity="clustered",


  enableMiniMapIcons=true,
  globalMiniMapScale=1,
  alwaysGlowMap=false,
  alwaysGlowMinimap=false,
  questObjectiveColors=false,
  questMinimapObjectiveColors=false,

  -- Questie 3.3.5 townsfolk-style service markers. Questie-Octo keeps map
  -- and minimap visibility independent so each presentation can be tuned.
  showMapRareMonsters=true,
  showMapAuctioneer=true,
  showMapBanker=true,
  showMapFlightMaster=true,
  showMapMailbox=true,
  -- Additional pfQuest service/utility tracking categories are opt-in. Keeping
  -- them disabled by default preserves Questie-Octo's lightweight baseline.
  showMapBattlemaster=false,
  showMapInnkeeper=false,
  showMapMeetingStone=false,
  showMapRepair=false,
  showMapSpiritHealer=false,
  showMapStableMaster=false,
  showMapVendor=false,
  showMinimapRareMonsters=true,
  showMinimapAuctioneer=true,
  showMinimapBanker=true,
  showMinimapFlightMaster=true,
  showMinimapMailbox=true,
  showMinimapBattlemaster=false,
  showMinimapInnkeeper=false,
  showMinimapMeetingStone=false,
  showMinimapRepair=false,
  showMinimapSpiritHealer=false,
  showMinimapStableMaster=false,
  showMinimapVendor=false,

  showLowLevelQuests=true,
  -- Maximum number of displayed quest levels below the player to expose when
  -- Show Low-Level Quests is enabled. 35 is the UI's "All" sentinel; the
  -- visible slider stops are 5/10/15/20/25/30/All.
  lowLevelQuestRange=35,
  showEventQuests=false,
  showRepeatableQuests=true,
  showPvPRelatedQuests=true,

  enableTooltips=true,
  enableTooltipsQuestLevel=true,
  enableTooltipsQuestID=false,
  enableTooltipsNPCID=false,
  enableTooltipsItemID=false,
  enableTooltipDroprates=true,

  -- Quest Log presentation. Questie provides the interaction semantics; the
  -- 1.12 title-button presentation follows the supplied pfQuest compatibility
  -- pattern where old Questie has no equivalent visual layer.
  questLogShowLevels=true,
  questLogDifficultyColors=true,

  -- Questie 3.3.5 tracker driver defaults. Rendering is a separate layer.
  trackerEnabled=true,
  trackerLocked=true,
  trackerAutoTrack=true,
  -- Native Quest Log tracked checkmarks are optional. The custom tracker owns
  -- tracking state; this toggle only controls the Blizzard/Turtle row check.
  trackerQuestLogCheckmarks=false,
  trackerShowCompleted=true,
  trackerHideCompletedObjectives=false,
  trackerSort="zone",
  -- Temporary tracker font-flag comparison options. Keep both off by default
  -- so existing profiles retain the historical Questie-Octo presentation.
  -- They are mutually exclusive when changed through Set().
  trackerOutlineText=false,
  trackerThickOutlineText=false,
  trackerFontSize=11,
  trackerMaxWidth=280,
  trackerVisibleRows=30,
  trackerBackgroundOpacity=0,
  trackerHideInCombat=false,

  -- Questie-Octo interface conveniences. Dark Theme preserves the accepted
  -- 1.0.96 Shagu-style options appearance by default. The settings minimap
  -- button is created only when enabled at login; disabling it therefore
  -- removes the frame entirely after /reload instead of merely hiding it.
  -- Optional continent-hover zone level panel, adapted from LevelRange-Turtle.
  -- It is global UI presentation, like Dark Theme and the minimap button.
  showZoneLevelRanges=true,
  useDarkTheme=true,
  showMinimapButton=true,

  -- Quest automation is character-local and opt-in. These conservative
  -- defaults mirror Questie 6's disabled-by-default automation posture while
  -- keeping repeatable quests and gray/trivial acceptance independently gated.
  autoAcceptQuests=false,
  autoTurnInQuests=false,
  autoAcceptGrayQuests=false,
  autoIncludeRepeatableQuests=false
}

local function Clamp(value,minValue,maxValue)
  value=tonumber(value)
  if not value then return nil end
  if value<minValue then value=minValue end
  if value>maxValue then value=maxValue end
  return value
end

local function IsCharacterOption(key)
  return key=="showLowLevelQuests" or key=="lowLevelQuestRange" or key=="showEventQuests" or key=="showRepeatableQuests" or key=="showPvPRelatedQuests" or
    key=="autoAcceptQuests" or key=="autoTurnInQuests" or key=="autoAcceptGrayQuests" or key=="autoIncludeRepeatableQuests"
end

-- Vanilla/Turtle can restore SavedVariables after addon files have executed.
-- Never trust an early cached table reference: rebind to the currently loaded
-- SavedVariables tables before every read/write operation.
local function SavedVariableBindingsChanged(self)
  if not QuestieOctoGlobalDB or not QuestieOctoGlobalDB.minimap then return true end
  if not QuestieOctoDB or not QuestieOctoDB.options then return true end
  return self.db~=QuestieOctoGlobalDB.minimap or self.charDB~=QuestieOctoDB.options
end

function S:Initialize()
  QuestieOctoGlobalDB=QuestieOctoGlobalDB or {}
  QuestieOctoGlobalDB.minimap=QuestieOctoGlobalDB.minimap or {}

  QuestieOctoDB=QuestieOctoDB or {}
  QuestieOctoDB.options=QuestieOctoDB.options or {}

  local db=QuestieOctoGlobalDB.minimap
  local charDB=QuestieOctoDB.options

  -- 1.0.73 splits the former continent/world-overview quest-state master into
  -- independent Available and Completed filters. Preserve the player's exact
  -- former choice on upgrade, then discard the obsolete key.
  if db.showAvailableQuestsWorldMap==nil then
    if db.showAllQuestsWorldMap==nil then
      db.showAvailableQuestsWorldMap=true
    else
      db.showAvailableQuestsWorldMap=db.showAllQuestsWorldMap and true or false
    end
  end
  if db.showCompletedQuestsWorldMap==nil then
    if db.showAllQuestsWorldMap==nil then
      db.showCompletedQuestsWorldMap=true
    else
      db.showCompletedQuestsWorldMap=db.showAllQuestsWorldMap and true or false
    end
  end
  db.showAllQuestsWorldMap=nil

  -- Discard obsolete presentation choices rather than leaving hidden stale
  -- settings in SavedVariables.
  db.databaseLocale=nil
  db.enableTooltipsObjectID=nil
  -- 1.0.66 removes Proximity tracker sorting entirely. It never had a distance
  -- producer and making it live would require recurring movement work on the
  -- old Lua client. Existing profiles that selected it return safely to Zone.
  if db.trackerSort=="proximity" then db.trackerSort="zone" end
  -- 1.0.31 replaces the experimental Thicker Text toggle with explicit WoW
  -- OUTLINE / THICKOUTLINE comparison toggles. Ignore the old saved value.
  db.trackerThickerText=nil

  -- 0.3.3: per-category size sliders were removed. Questie-Octo now has one
  -- World Map scale and one Minimap scale; discard hidden stale multipliers.
  local obsoleteScales={"availableScale","monsterScale","objectScale","lootScale","itemStartScale",
    "rareMonsterScale","auctioneerScale","bankerScale","flightMasterScale","mailboxScale"}
  for _,key in pairs(obsoleteScales) do db[key]=nil end

  for key,value in pairs(self.defaults) do
    if IsCharacterOption(key) then
      if charDB[key]==nil then
        -- Migrate 0.1.44's global value once if present.
        if db[key]~=nil then charDB[key]=db[key] else charDB[key]=value end
      end
    elseif db[key]==nil then
      db[key]=value
    end
  end

  -- 1.0.38: 30 used to be the hidden "All" sentinel. The slider now exposes
  -- a literal 30-level choice and uses 35 internally for "All". Migrate the
  -- old saved sentinel once so updating players keep the same unrestricted
  -- behavior instead of unexpectedly receiving a 30-level cutoff.
  if not charDB.lowLevelQuestRangeAll35Migrated then
    if tonumber(charDB.lowLevelQuestRange)==30 then charDB.lowLevelQuestRange=35 end
    charDB.lowLevelQuestRangeAll35Migrated=true
  end

  -- Requested 0.1.45 defaults. Migrate only exact previous defaults.
  if not db.mapScaleDefault1Migrated then
    if tonumber(db.globalScale)==0.7 then db.globalScale=1 end
    db.mapScaleDefault1Migrated=true
  end

  -- 0.2.46: OctoWoW baseline uses 1.0 for minimap and item-start scale.
  -- Migrate only the exact former default so deliberate player values survive.
  if not db.miniMapScaleDefault1Migrated then
    if tonumber(db.globalMiniMapScale)==0.7 then db.globalMiniMapScale=1 end
    db.miniMapScaleDefault1Migrated=true
  end

  -- 1.1: map objective glow is now opt-in. Migrate the former default ON
  -- once so existing profiles receive the new baseline; players can re-enable
  -- the option afterwards if they prefer the glow.
  if not db.mapIconGlowDefaultOffMigrated then
    if db.alwaysGlowMap==true then db.alwaysGlowMap=false end
    db.mapIconGlowDefaultOffMigrated=true
  end

  self.db=db
  self.charDB=charDB
end

function S:Get(key)
  if not self.db or SavedVariableBindingsChanged(self) then self:Initialize() end
  local value
  if IsCharacterOption(key) then
    value=self.charDB[key]
  else
    value=self.db[key]
  end
  if value==nil then return self.defaults[key] end
  return value
end

function S:Set(key,value)
  if not self.db or SavedVariableBindingsChanged(self) then self:Initialize() end

  if key=="enableMapIcons" or key=="showAvailableQuestsWorldMap" or key=="showCompletedQuestsWorldMap" or key=="showSpecialQuestsWorldMap" or key=="enableObjectives" or key=="enableTurnins" or
      key=="showAvailableQuestMapCurrentZone" or key=="showTurninsCurrentZoneMap" or
      key=="enableAvailable" or key=="enableMiniMapIcons" or
      key=="alwaysGlowMap" or key=="alwaysGlowMinimap" or
      key=="questObjectiveColors" or key=="questMinimapObjectiveColors" or
      key=="showLowLevelQuests" or key=="showEventQuests" or key=="showRepeatableQuests" or key=="showPvPRelatedQuests" or
      key=="showItemStartQuests" or key=="showItemStartMap" or key=="showItemStartMinimap" or
      key=="showMapRareMonsters" or key=="showMapAuctioneer" or key=="showMapBanker" or
      key=="showMapFlightMaster" or key=="showMapMailbox" or
      key=="showMapBattlemaster" or key=="showMapInnkeeper" or key=="showMapMeetingStone" or
      key=="showMapRepair" or key=="showMapSpiritHealer" or key=="showMapStableMaster" or key=="showMapVendor" or
      key=="showMinimapRareMonsters" or key=="showMinimapAuctioneer" or key=="showMinimapBanker" or
      key=="showMinimapFlightMaster" or key=="showMinimapMailbox" or
      key=="showMinimapBattlemaster" or key=="showMinimapInnkeeper" or key=="showMinimapMeetingStone" or
      key=="showMinimapRepair" or key=="showMinimapSpiritHealer" or key=="showMinimapStableMaster" or key=="showMinimapVendor" or
      key=="enableTooltips" or
      key=="enableTooltipsQuestLevel" or key=="enableTooltipsQuestID" or
      key=="enableTooltipsNPCID" or key=="enableTooltipsItemID" or
      key=="enableTooltipDroprates" or
      key=="questLogShowLevels" or key=="questLogDifficultyColors" or
      key=="trackerEnabled" or key=="trackerLocked" or key=="trackerAutoTrack" or
      key=="trackerQuestLogCheckmarks" or key=="trackerShowCompleted" or key=="trackerHideCompletedObjectives" or key=="trackerHideInCombat" or
      key=="trackerOutlineText" or key=="trackerThickOutlineText" or
      key=="showZoneLevelRanges" or key=="useDarkTheme" or key=="showMinimapButton" or
      key=="autoAcceptQuests" or key=="autoTurnInQuests" or key=="autoAcceptGrayQuests" or key=="autoIncludeRepeatableQuests" then
    value=value and true or false
  elseif key=="lowLevelQuestRange" then
    value=tonumber(value)
    if value~=5 and value~=10 and value~=15 and value~=20 and value~=25 and value~=30 and value~=35 then return false end
  elseif key=="globalScale" then
    value=Clamp(value,0.01,4)
  elseif key=="objectiveNodeDensity" or key=="itemStartDensity" then
    if value~="clustered" and value~="full" then return false end
  elseif key=="globalMiniMapScale" then
    value=Clamp(value,0.01,4)
  elseif key=="trackerSort" then
    if value~="zone" and value~="level" then return false end
  elseif key=="trackerFontSize" then
    value=Clamp(value,8,18)
  elseif key=="trackerMaxWidth" then
    value=Clamp(value,200,500)
    if value then value=math.floor(value+0.5) end
  elseif key=="trackerVisibleRows" then
    value=Clamp(value,6,60)
    if value then value=math.floor(value+0.5) end
  elseif key=="trackerBackgroundOpacity" then
    value=Clamp(value,0,1)
  else
    return false
  end

  if value==nil then return false end

  -- OUTLINE and THICKOUTLINE are comparison modes, not cumulative effects.
  -- Keep them mutually exclusive even if a caller changes settings outside
  -- the AceConfig UI.
  if value==true and key=="trackerOutlineText" then
    self.db.trackerThickOutlineText=false
  elseif value==true and key=="trackerThickOutlineText" then
    self.db.trackerOutlineText=false
  end

  if IsCharacterOption(key) then
    self.charDB[key]=value
  else
    self.db[key]=value
  end

  -- Interface-only settings do not need map/minimap data refreshes. Dark
  -- Theme can be applied immediately. The minimap button intentionally waits
  -- for /reload because OFF means the Minimap child frame must not exist at all.
  if key=="showZoneLevelRanges" then
    if QuestieOcto.ZoneLevelRange and QuestieOcto.ZoneLevelRange.Refresh then
      QuestieOcto.ZoneLevelRange:Refresh()
    end
    return true
  elseif key=="useDarkTheme" then
    if QuestieOcto.Options and QuestieOcto.Options.ApplyDarkTheme then
      QuestieOcto.Options:ApplyDarkTheme(value)
    end
    return true
  elseif key=="showMinimapButton" then
    return true
  elseif key=="autoAcceptQuests" or key=="autoTurnInQuests" or key=="autoAcceptGrayQuests" or key=="autoIncludeRepeatableQuests" then
    return true
  end

  if string.find(key,"^questLog") then
    -- Run Blizzard's normal QuestLog_Update first so disabling difficulty
    -- coloring restores the native text color before Questie reapplies its
    -- optional presentation layer.
    if QuestLogFrame and QuestLogFrame:IsShown() and QuestLog_Update then
      QuestLog_Update()
    elseif QuestieOcto.QuestLogEnhancements and QuestieOcto.QuestLogEnhancements.Refresh then
      QuestieOcto.QuestLogEnhancements:Refresh()
    end
    return true
  end

  if string.find(key,"^tracker") then
    if QuestieOcto.TrackerDriver and QuestieOcto.TrackerDriver.OnSettingChanged then
      QuestieOcto.TrackerDriver:OnSettingChanged(key,value)
    end
    return true
  end

  if key=="showLowLevelQuests" or key=="lowLevelQuestRange" or key=="showEventQuests" or key=="showRepeatableQuests" or key=="showPvPRelatedQuests" then
    if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.FastRefresh then
      QuestieOcto.AvailableQuests:FastRefresh()
    end
    -- PvP visibility applies to every PvP map/minimap marker, including
    -- accepted objectives and completed turn-ins. Refresh the renderers
    -- immediately while the available-quest service rebuilds in parallel.
    if key=="showPvPRelatedQuests" then
      if QuestieOcto.Map and QuestieOcto.Map.OnSettingChanged then
        QuestieOcto.Map:OnSettingChanged(key,value)
      end
      if QuestieOcto.Minimap and QuestieOcto.Minimap.OnSettingChanged then
        QuestieOcto.Minimap:OnSettingChanged(key,value)
      end
    end
    return true
  end

  -- Questie 11's advanced clustering option explicitly treats zero
  -- separation as "show all icons". Our two-state UI exposes that mature
  -- behavior as Clustered / Full Nodes while keeping PreparedMap shared by
  -- world map and minimap.
  if key=="objectiveNodeDensity" or key=="itemStartDensity" then
    if QuestieOcto.PreparedMap and QuestieOcto.PreparedMap.PrepareAll and
       QuestieOcto.Nodes and QuestieOcto.Nodes.ready then
      QuestieOcto.PreparedMap:PrepareAll("density:"..tostring(key))
    end
    return true
  end

  -- Questie 3.3.5 mature scale ordering:
  -- save the option first, then route every scale through the single
  -- QuestieMap:RescaleIcons-style path so world map + minimap are refreshed
  -- from the same current semantic icon data.
  if key=="globalScale" then
    if QuestieOcto.Map and QuestieOcto.Map.RescaleIcons then QuestieOcto.Map:RescaleIcons(key,value) end
    return true
  end
  if key=="globalMiniMapScale" then
    if QuestieOcto.Minimap and QuestieOcto.Minimap.RescaleIcons then QuestieOcto.Minimap:RescaleIcons(key,value) end
    return true
  end

  if key=="showItemStartQuests" or key=="showItemStartMap" or
     key=="showItemStartMinimap" then
    if QuestieOcto.Map and QuestieOcto.Map.OnSettingChanged then
      QuestieOcto.Map:OnSettingChanged(key,value)
    end
    if QuestieOcto.Minimap and QuestieOcto.Minimap.OnSettingChanged then
      QuestieOcto.Minimap:OnSettingChanged(key,value)
    end
    if key=="showItemStartQuests" and QuestieOcto.Tooltips and QuestieOcto.Tooltips.ScheduleHoverIndex then
      QuestieOcto.Tooltips:ScheduleHoverIndex()
    end
    return true
  end

  if key=="showMapRareMonsters" or key=="showMapAuctioneer" or key=="showMapBanker" or
     key=="showMapFlightMaster" or key=="showMapMailbox" or
     key=="showMapBattlemaster" or key=="showMapInnkeeper" or key=="showMapMeetingStone" or
     key=="showMapRepair" or key=="showMapSpiritHealer" or key=="showMapStableMaster" or key=="showMapVendor" then
    -- The additional pfQuest service categories are not materialized while
    -- disabled on both map surfaces. Rebuild transactionally when one changes
    -- so opt-in categories have no default startup/node cost.
    if string.find(key,"Battlemaster") or string.find(key,"Innkeeper") or string.find(key,"MeetingStone") or
       string.find(key,"Repair") or string.find(key,"SpiritHealer") or string.find(key,"StableMaster") or
       string.find(key,"Vendor") then
      if QuestieOcto.Nodes and QuestieOcto.Nodes.Rebuild then QuestieOcto.Nodes:Rebuild() end
    end
    if QuestieOcto.Map and QuestieOcto.Map.OnSettingChanged then
      QuestieOcto.Map:OnSettingChanged(key,value)
    end
    return true
  end

  if key=="showMinimapRareMonsters" or key=="showMinimapAuctioneer" or key=="showMinimapBanker" or
     key=="showMinimapFlightMaster" or key=="showMinimapMailbox" or
     key=="showMinimapBattlemaster" or key=="showMinimapInnkeeper" or key=="showMinimapMeetingStone" or
     key=="showMinimapRepair" or key=="showMinimapSpiritHealer" or key=="showMinimapStableMaster" or key=="showMinimapVendor" then
    if string.find(key,"Battlemaster") or string.find(key,"Innkeeper") or string.find(key,"MeetingStone") or
       string.find(key,"Repair") or string.find(key,"SpiritHealer") or string.find(key,"StableMaster") or
       string.find(key,"Vendor") then
      if QuestieOcto.Nodes and QuestieOcto.Nodes.Rebuild then QuestieOcto.Nodes:Rebuild() end
    end
    if QuestieOcto.Minimap and QuestieOcto.Minimap.OnSettingChanged then
      QuestieOcto.Minimap:OnSettingChanged(key,value)
    end
    return true
  end

  if key=="alwaysGlowMap" or key=="alwaysGlowMinimap" or
     key=="questObjectiveColors" or key=="questMinimapObjectiveColors" then
    if QuestieOcto.Map and QuestieOcto.Map.RefreshVisualSettings then
      QuestieOcto.Map:RefreshVisualSettings()
    end
    return true
  end

  if QuestieOcto.Minimap and QuestieOcto.Minimap.OnSettingChanged then
    QuestieOcto.Minimap:OnSettingChanged(key,value)
  end

  if QuestieOcto.Map and QuestieOcto.Map.OnSettingChanged then
    QuestieOcto.Map:OnSettingChanged(key,value)
  end

  return true
end

function S:Reset()
  if not self.db or SavedVariableBindingsChanged(self) then self:Initialize() end

  for key,value in pairs(self.defaults) do
    if IsCharacterOption(key) then
      self.charDB[key]=value
    else
      self.db[key]=value
    end
  end

  if QuestieOcto.Minimap and QuestieOcto.Minimap.ApplySettings then
    QuestieOcto.Minimap:ApplySettings()
  end
  if QuestieOcto.Map and QuestieOcto.Map.ApplySettings then
    QuestieOcto.Map:ApplySettings()
  end
  if QuestieOcto.Map and QuestieOcto.Map.RescaleIcons then
    QuestieOcto.Map:RescaleIcons()
  end
  if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.FastRefresh then
    QuestieOcto.AvailableQuests:FastRefresh()
  end
  if QuestieOcto.Options and QuestieOcto.Options.ApplyDarkTheme then
    QuestieOcto.Options:ApplyDarkTheme(self.defaults.useDarkTheme)
  end
  if QuestieOcto.ZoneLevelRange and QuestieOcto.ZoneLevelRange.Refresh then
    QuestieOcto.ZoneLevelRange:Refresh()
  end
  if QuestieOcto.MinimapButton and QuestieOcto.MinimapButton.ResetPosition then
    QuestieOcto.MinimapButton:ResetPosition()
  end
end

S:Initialize()
