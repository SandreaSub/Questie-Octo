QuestieOcto.Minimap = QuestieOcto.Minimap or {}
local MM = QuestieOcto.Minimap

MM.enabled=true
MM.mapID=nil
MM.karazhanContext=nil
MM.plan=nil
MM.planRevision=nil
MM.frames={}
MM.activeFrames={}
MM.trackerHoverQuestID=nil
MM.trackerHoverFadeAlpha=0.30
MM.bindRevision=1
MM.elapsed=0
MM.updateInterval=0.05
MM.globalScale=1
-- Keep smooth 20 Hz movement for nearby pins, but do not rescan the full
-- prepared zone plan at that rate. A discovery pass keeps a generous ring of
-- nearby candidates and is repeated only after the player has moved far enough
-- that a new pin could enter the real minimap without already being a candidate.
MM.discoveryMargin=1.5
MM.rediscoverFraction=0.25
MM.shapeCheckInterval=1
MM.mapIdentityCheckInterval=0.5
MM.stats={
  active=0,created=0,reused=0,hidden=0,
  refreshes=0,positionUpdates=0,discoveryScans=0,fastPositionUpdates=0,mapChanges=0,
  candidateFrames=0,scannedDescriptors=0,indoorProbes=0,zoomEvents=0,
  mapContextRestores=0,lastMapContextReason="none",
  visibleAvailable=0,visibleItemStart=0,visibleObjective=0,visibleTurnin=0
}


local function Settings()
  return QuestieOcto.MinimapSettings
end

local function ClearTable(tbl)
  if not tbl then return {} end
  for key in pairs(tbl) do tbl[key]=nil end
  return tbl
end

local OVERLAP_OFFSETS={
  {0,0},{10,0},{-10,0},{0,10},{0,-10},{8,8},{-8,8},{8,-8},{-8,-8}
}

-- Lua 5.0 compatibility: RefreshVisualSettings/RescaleIcons are defined
-- before the implementations below, so forward-declare both locals explicitly.
local RefreshPinVisual
local ResizePin

local function IsPermanentRole(role)
  return role=="flightMaster" or role=="auctioneer" or role=="banker"
      or role=="mailbox" or role=="battlemaster" or role=="innkeeper"
      or role=="meetingStone" or role=="repair" or role=="spiritHealer"
      or role=="stableMaster" or role=="vendor" or role=="rareMob"
end

local function IsRoleEnabled(role)
  local settings=Settings()
  if role=="auctioneer" then return settings:Get("showMinimapAuctioneer") and true or false end
  if role=="banker" then return settings:Get("showMinimapBanker") and true or false end
  if role=="flightMaster" then return settings:Get("showMinimapFlightMaster") and true or false end
  if role=="mailbox" then return settings:Get("showMinimapMailbox") and true or false end
  if role=="battlemaster" then return settings:Get("showMinimapBattlemaster") and true or false end
  if role=="innkeeper" then return settings:Get("showMinimapInnkeeper") and true or false end
  if role=="meetingStone" then return settings:Get("showMinimapMeetingStone") and true or false end
  if role=="repair" then return settings:Get("showMinimapRepair") and true or false end
  if role=="spiritHealer" then return settings:Get("showMinimapSpiritHealer") and true or false end
  if role=="stableMaster" then return settings:Get("showMinimapStableMaster") and true or false end
  if role=="vendor" then return settings:Get("showMinimapVendor") and true or false end
  if role=="rareMob" then return settings:Get("showMinimapRareMonsters") and true or false end
  if not settings:Get("enableMiniMapIcons") then return false end

  if role=="itemStart" then
    return settings:Get("enableAvailable")
       and settings:Get("showItemStartQuests")
       and settings:Get("showItemStartMinimap")
       and true or false
  elseif role=="available" then
    return settings:Get("enableAvailable") and true or false
  elseif role=="turnin" then
    return settings:Get("enableTurnins") and true or false
  else
    return settings:Get("enableObjectives") and true or false
  end
end

local function SetTextureAlpha(pin,alpha)
  alpha=tonumber(alpha) or 1
  if alpha<0 then alpha=0 end
  if alpha>1 then alpha=1 end

  if pin.lastAlpha==alpha then return end
  pin.lastAlpha=alpha

  if QuestieOcto.Visuals then
    QuestieOcto.Visuals:SetAlpha(pin,alpha)
  elseif pin.texture and pin.texture.SetVertexColor then
    pin.texture:SetVertexColor(1,1,1,alpha)
  end
end

function MM:RefreshVisualSettings()
  -- Visible minimap frames are a small recyclable pool. Force a rebind on the
  -- next position pass instead of walking/rebuilding every coordinate in the
  -- zone just because a presentation option changed.
  self.bindRevision=(self.bindRevision or 0)+1
  self:UpdatePositions(true)
end

function MM:RescaleIcons(changedKey,changedValue)
  self.stats.rescalePasses=(self.stats.rescalePasses or 0)+1
  if changedKey=="globalMiniMapScale" and tonumber(changedValue) then
    self.globalScale=tonumber(changedValue)
  else
    self.globalScale=tonumber(Settings():Get("globalMiniMapScale")) or 1
  end

  for _,pin in pairs(self.activeFrames or {}) do ResizePin(pin) end
  self:UpdatePositions(true)
end

function MM:ApplySettings()
  local settings=Settings()
  self.enabled=true
  self.globalScale=tonumber(settings:Get("globalMiniMapScale")) or 1
  self.bindRevision=(self.bindRevision or 0)+1
  self:RefreshPlan()
end

function MM:OnSettingChanged(key,value)
  if key=="globalMiniMapScale" then
    self:RescaleIcons(key,value)
    return
  end

  self.bindRevision=(self.bindRevision or 0)+1
  if key=="enableMiniMapIcons" or key=="enableObjectives" or key=="enableTurnins" or
     key=="enableAvailable" or key=="showPvPRelatedQuests" or
     key=="showItemStartQuests" or key=="showItemStartMinimap" or
     key=="showMinimapAuctioneer" or key=="showMinimapBanker" or
     key=="showMinimapFlightMaster" or key=="showMinimapMailbox" or
     key=="showMinimapBattlemaster" or key=="showMinimapInnkeeper" or key=="showMinimapMeetingStone" or
     key=="showMinimapRepair" or key=="showMinimapSpiritHealer" or key=="showMinimapStableMaster" or key=="showMinimapVendor" or
     key=="showMinimapRareMonsters" then
    self:UpdatePositions(true)
    return
  end

  self:UpdatePositions(true)
end

-- pfQuest compatibility reference for Vanilla 1.12 minimap world span.
-- Questie 3.3.5/7/8 delegate this projection to HereBeDragons; Turtle does not
-- ship that library, so only the coordinate projection is adapted from pfQuest.
local MINIMAP_ZOOM={
  [0]={
    [0]=300,[1]=240,[2]=180,[3]=120,[4]=80,[5]=50
  },
  [1]={
    [0]=466.6666667,[1]=400,[2]=333.3333333,
    [3]=266.3333333,[4]=200,[5]=133.3333333
  }
}

local function RestoreCurrentZoneMapContext(reason)
  if not SetMapToCurrentZone then return end
  if WorldMapFrame and WorldMapFrame:IsShown() then return end

  SetMapToCurrentZone()
  MM.stats.mapContextRestores=(MM.stats.mapContextRestores or 0)+1
  MM.stats.lastMapContextReason=reason or "unknown"
end

local function CurrentMapID()
  -- ClassicAPI's GetBestMapForUnit is tied to the player's physical location
  -- and returns the current AreaTable ID directly. Prefer it over a zone-name
  -- reverse lookup so duplicate/custom/localized dungeon names cannot select an
  -- arbitrary map row. This also remains independent from the World Map zone
  -- the player may be browsing.
  local id=QuestieOcto.API:GetBestMapForPlayer()
  if id then
    MM.physicalMapID=tonumber(id)
    return MM.physicalMapID
  end

  -- Fallback for an unexpected API failure: use the physical zone text only
  -- when it maps unambiguously.
  if GetRealZoneText and QuestieOcto.DatabaseAPI.GetMapIDByName then
    local zoneName=GetRealZoneText()
    id=zoneName and QuestieOcto.DatabaseAPI:GetMapIDByName(zoneName)
    if id then
      MM.physicalMapID=tonumber(id)
      return MM.physicalMapID
    end
  end

  -- If the World Map is currently browsing somewhere else and physical map
  -- identity could not be resolved, keep the last known physical map rather
  -- than adopting the browsed map context.
  if WorldMapFrame and WorldMapFrame:IsShown() and MM.physicalMapID then
    return MM.physicalMapID
  end

  return MM.physicalMapID
end

local function ReadMinimapIndoorPassive()
  if not Minimap or not Minimap.GetZoom or not GetCVar then return nil end

  local zoom=tonumber(Minimap:GetZoom())
  local outdoorZoom=tonumber(GetCVar("minimapZoom"))
  local indoorZoom=tonumber(GetCVar("minimapInsideZoom"))
  if zoom==nil or outdoorZoom==nil or indoorZoom==nil then return nil end

  -- When the two saved zoom values differ, the current zoom tells us the
  -- projection state without touching the native minimap at all. Preserve the
  -- pfQuest/Turtle state mapping: 0 uses the 300-yard table, 1 the 466.67-yard
  -- table.
  if outdoorZoom~=indoorZoom then
    if zoom==indoorZoom then return 0 end
    if zoom==outdoorZoom then return 1 end
  end

  return nil
end

local function ProbeMinimapIndoor()
  if not Minimap or not Minimap.GetZoom or not Minimap.SetZoom or not GetCVar then
    return MM.indoorState or 1
  end

  local passive=ReadMinimapIndoorPassive()
  if passive~=nil then
    MM.indoorState=passive
    return passive
  end

  if MM.indoorProbeActive then return MM.indoorState or 1 end

  -- Vanilla only exposes which zoom CVar is active indirectly when the indoor
  -- and outdoor values are identical. The historical pfQuest-compatible test
  -- briefly changes the native Minimap zoom to reveal that state. Doing this
  -- from every movement rediscovery also forces Blizzard's own minimap
  -- children (notably moving party markers) to redraw and visibly blink.
  -- Keep the compatibility probe, but only for explicit minimap/zone context
  -- settlement; normal movement discovery never calls it.
  local originalZoom=tonumber(Minimap:GetZoom()) or 0
  local probeZoom
  if originalZoom>=3 then probeZoom=originalZoom-1 else probeZoom=originalZoom+1 end

  MM.indoorProbeActive=true
  MM.indoorProbeIgnoreUntil=(GetTime and GetTime() or 0)+0.25
  Minimap:SetZoom(probeZoom)

  local state=1
  if (tonumber(GetCVar("minimapInsideZoom")) or -1)==tonumber(Minimap:GetZoom()) then
    state=0
  end

  Minimap:SetZoom(originalZoom)
  MM.indoorProbeActive=false
  MM.indoorState=state
  MM.stats.indoorProbes=(MM.stats.indoorProbes or 0)+1
  return state
end

function MM:RefreshIndoorState(allowProbe)
  local previous=self.indoorState
  local state=ReadMinimapIndoorPassive()
  if state==nil and allowProbe then state=ProbeMinimapIndoor() end
  if state~=nil then self.indoorState=state end
  return state~=nil and state~=previous
end

local function MinimapIndoor()
  -- Discovery must be read-only with respect to Blizzard's Minimap. Resolve a
  -- non-ambiguous state passively, otherwise use the context state settled by
  -- startup/zone/minimap events. This is what keeps continuous movement from
  -- making native teammate markers blink.
  local state=ReadMinimapIndoorPassive()
  if state~=nil then
    MM.indoorState=state
    return state
  end
  return MM.indoorState or 1
end

local function MaskTextureSquareHint()
  -- Prefer the minimap's actual mask when the client/API exposes a getter.
  -- This keeps Questie-Octo independent from whichever UI addon supplied it.
  if not Minimap or type(Minimap.GetMaskTexture)~="function" then return nil end

  local ok,mask=pcall(Minimap.GetMaskTexture,Minimap)
  if not ok or type(mask)~="string" then return nil end

  local lower=string.lower(mask)
  lower=string.gsub(lower,"/","\\")

  -- WHITE8X8 is the common Vanilla square-mask technique (ShaguTweaks and
  -- DragonflightUI use it). Custom square masks commonly identify themselves
  -- as a minimap/square texture; pfUI ships its own minimap mask texture.
  if string.find(lower,"white8x8") then return true end
  if string.find(lower,"minimap") and string.find(lower,"square") then return true end
  if string.find(lower,"pfui") and string.find(lower,"minimap") then return true end

  -- Blizzard's stock circular minimap mask.
  if string.find(lower,"textures\\minimapmask") then return false end
  if string.find(lower,"interface\\minimap\\minimapmask") then return false end

  return nil
end

local function PfUISquareMinimap()
  -- pfUI reparents the active Minimap into pfUI.minimap and applies its own
  -- square mask. Checking the live parent avoids relying on a saved setting.
  if not pfUI or not pfUI.minimap or not Minimap or type(Minimap.GetParent)~="function" then
    return false
  end
  local ok,parent=pcall(Minimap.GetParent,Minimap)
  return ok and parent==pfUI.minimap and true or false
end

local function ShaguTweaksSquareMinimap()
  -- ShaguTweaks' MiniMap Square module creates this border only when the
  -- square-mask module is active. Its option requires a UI reload to change.
  return ShaguTweaks and Minimap and Minimap.border and true or false
end

local function DragonflightUISquareMinimap()
  -- DragonflightUI can switch its map mask from round to square at runtime.
  if not DFRL or type(DFRL.GetTempDB)~="function" then return false end
  local okEnabled,enabled=pcall(DFRL.GetTempDB,DFRL,"Map","enabled")
  if not okEnabled or not enabled then return false end
  local okSquare,square=pcall(DFRL.GetTempDB,DFRL,"Map","mapSquare")
  return okSquare and square and true or false
end

local function UsesSquareMinimap()
  local maskHint=MaskTextureSquareHint()
  if maskHint~=nil then return maskHint end

  -- Vanilla/Turtle clients may not expose GetMaskTexture(). Fall back to
  -- concrete live-state signals from UIs known to replace the minimap mask.
  if PfUISquareMinimap() then return true end
  if ShaguTweaksSquareMinimap() then return true end
  if DragonflightUISquareMinimap() then return true end

  return false
end

-- Reuse the same live square-minimap compatibility decision for Questie-Octo's
-- optional settings button. Keeping one detector avoids pfUI/DragonflightUI/
-- ShaguTweaks disagreement between quest pins and the button's drag geometry.
function MM:UsesSquareMinimap()
  return UsesSquareMinimap()
end

local function WorldMapBrowsingAwayFromPlayer(mapID)
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return false end
  if not QuestieOcto.Map or not QuestieOcto.Map.GetDisplayedMapID then return true end

  local displayed=QuestieOcto.Map:GetDisplayedMapID()
  -- Continent/world views have no zone map ID and therefore cannot provide
  -- physical-zone player coordinates through Vanilla's global map context.
  if not displayed then return true end
  if tonumber(displayed)~=tonumber(mapID) then return true end

  -- Lower and Upper Karazhan first floor share numeric AreaTable ID 3457. If
  -- the player browses the opposite texture, GetPlayerMapPosition() belongs to
  -- the browsed context even though the numeric ID still matches. Keep the last
  -- reliable physical position just as we do when browsing another zone.
  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(mapID) then
    local displayedContext=QuestieOcto.Map.GetDisplayedSpecialMapContext
      and QuestieOcto.Map:GetDisplayedSpecialMapContext() or nil
    return displayedContext~=MM.karazhanContext
  end

  return false
end

local function PlayerPosition(physicalMapID)
  -- Questie owns minimap refresh timing/state. Never retarget the World Map
  -- every 0.05s just to obtain player coordinates: that would fight the user
  -- while they browse. Instead, keep the last physical-zone position while the
  -- World Map is displaying another zone/continent, then resume live reads as
  -- soon as the physical map context is available again.
  if not GetPlayerMapPosition then return nil,nil end

  physicalMapID=physicalMapID or CurrentMapID()
  if WorldMapBrowsingAwayFromPlayer(physicalMapID) then
    return MM.physicalPlayerX,MM.physicalPlayerY
  end

  local x,y=GetPlayerMapPosition("player")
  x=tonumber(x)
  y=tonumber(y)

  if not x or not y or (x==0 and y==0) then
    if WorldMapFrame and WorldMapFrame:IsShown() then
      return MM.physicalPlayerX,MM.physicalPlayerY
    end
    return nil,nil
  end

  MM.physicalPlayerX=x*100
  MM.physicalPlayerY=y*100
  return MM.physicalPlayerX,MM.physicalPlayerY
end

local function IsTrackerHoverObjectiveRole(role)
  return role=="objectiveCreature" or role=="objectiveObject"
      or role=="objectiveItemSource" or role=="objectiveArea"
end

local function TrackerHoverAlphaForPin(pin,questID)
  questID=tonumber(questID)
  if not pin or not questID then return 1 end
  if pin.itemStartArea then return 1 end

  local hasObjective=false
  local hasProtected=false
  local containsHovered=false
  for _,entry in pairs(pin.entries or {}) do
    local node=entry and entry.node
    if node then
      if IsTrackerHoverObjectiveRole(node.role) then
        hasObjective=true
        if tonumber(node.questID)==questID then containsHovered=true end
      else
        hasProtected=true
      end
    end
  end

  if containsHovered or hasProtected or not hasObjective then return 1 end
  return MM.trackerHoverFadeAlpha or 0.30
end

function MM:ApplyTrackerHoverToPin(pin)
  if not pin then return end
  SetTextureAlpha(pin,TrackerHoverAlphaForPin(pin,self.trackerHoverQuestID))
end

function MM:RefreshTrackerHoverFocus()
  for _,pin in pairs(self.activeFrames or {}) do self:ApplyTrackerHoverToPin(pin) end
end

function MM:SetTrackerHoverQuest(questID)
  questID=tonumber(questID)
  if self.trackerHoverQuestID==questID then return end
  self.trackerHoverQuestID=questID
  self:RefreshTrackerHoverFocus()
end

local function EntryKey(node)
  return tostring(node.questID)..":"..tostring(node.role)..":"..
    tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
    tostring(node.itemID or 0)
end

local function ResetPin(pin)
  pin.itemStartArea=nil
  pin.entries=ClearTable(pin.entries)
  pin.visualPriority=nil
  pin.role=nil
  pin.questID=nil
  pin.event=nil
  pin.pvp=nil
  pin.repeatable=nil
  pin.fullNode=nil
  pin.fullNodeNode=nil
  pin.sourceID=nil
  pin.iconScaleKey=nil
  pin.sourceKind=nil
  pin.displayName=nil
  pin.clusterCount=1
  pin.mapX=nil
  pin.mapY=nil
  pin.coordKey=nil
  pin.lastAlpha=nil
  if QuestieOcto.Visuals then QuestieOcto.Visuals:ClearPin(pin,1) end
  SetTextureAlpha(pin,1)
end

local function ApplyVisual(pin,node)
  local priority=QuestieOcto.Map:GetVisualPriority(node)

  if not pin.visualPriority or priority>pin.visualPriority then
    pin.visualPriority=priority
    pin.role=node.role
    pin.questID=node.questID
    pin.event=node.event
    pin.pvp=node.pvp and true or false
    pin.repeatable=node.repeatable and true or false
    pin.sourceKind=node.sourceKind
    pin.sourceID=node.sourceID
    pin.displayName=node.sourceName or pin.displayName or "Quest source"
    pin.iconScaleKey=node.iconScaleKey or QuestieOcto.Map:GetScaleKeyForRole(node.role)
    pin.texture:SetTexture(QuestieOcto.Map:GetTextureForNode(node))
    pin.texture:SetDrawLayer("OVERLAY",QuestieOcto.Map:GetDrawSublevelForRole(node.role))
    -- Keep townsfolk/rare markers below quest pins at identical coordinates.
    if pin.SetFrameLevel and Minimap then
      pin:SetFrameLevel(Minimap:GetFrameLevel()+6+QuestieOcto.Map:GetFrameLevelBandForRole(node.role))
    end
    if QuestieOcto.Visuals then
      QuestieOcto.Visuals:ApplyPin(pin,node,true,pin.lastAlpha or 1)
    end
  end
end



ResizePin=function(pin)
  if not pin then return end

  local typeScale=QuestieOcto.Map:GetPinScale(pin)
  -- Keep miscellaneous rare stars proportionally smaller on the minimap too.
  -- This mirrors pfQuest's 12px visible rare icon footprint.
  local baseSize=pin.fullNode and 14 or ((pin.role=="rareMob") and 12 or 16)
  local size=baseSize*(MM.globalScale or 1)*typeScale
  pin:SetWidth(size)
  pin:SetHeight(size)
  if QuestieOcto.Visuals then QuestieOcto.Visuals:ResizeGlow(pin) end
  pin.questieOctoScaleSize=size
  MM.stats.scaleResizes=(MM.stats.scaleResizes or 0)+1
  MM.stats.lastScaleSize=size
end

local function AddEntry(pin,node)
  local key=EntryKey(node)
  if not pin.entries[key] then pin.entries[key]={node=node} end
  ApplyVisual(pin,node)
  ResizePin(pin)
  MM:ApplyTrackerHoverToPin(pin)
end

function MM:GetOrCreate(index)
  index=tonumber(index)
  if not index then return nil end

  local pin=self.frames[index]
  if not pin then
    pin=CreateFrame("Button",nil,Minimap)
    pin:SetWidth(16)
    pin:SetHeight(16)
    pin:SetFrameStrata(Minimap:GetFrameStrata())
    pin:SetFrameLevel(Minimap:GetFrameLevel()+7)
    pin:EnableMouse(true)

    local tex=pin:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints(pin)
    pin.texture=tex

    pin:SetScript("OnEnter",function() QuestieOcto.Tooltips:Show(this) end)
    pin:SetScript("OnLeave",function() QuestieOcto.Tooltips:Hide(this) end)

    self.frames[index]=pin
    self.stats.created=self.stats.created+1
  else
    self.stats.reused=self.stats.reused+1
  end

  return pin
end

RefreshPinVisual=function(pin)
  local wasFull=pin.fullNode and true or false
  pin.visualPriority=nil
  pin.role=nil
  pin.questID=nil
  pin.event=nil
  pin.pvp=nil
  pin.repeatable=nil
  pin.fullNode=nil
  pin.fullNodeNode=nil
  pin.sourceID=nil
  pin.iconScaleKey=nil

  local fullNode=nil
  for _,entry in pairs(pin.entries or {}) do
    if entry.node then
      ApplyVisual(pin,entry.node)
      if wasFull and (not fullNode or QuestieOcto.Map:GetVisualPriority(entry.node)>QuestieOcto.Map:GetVisualPriority(fullNode)) then
        fullNode=entry.node
      end
    end
  end
  if fullNode and QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
    QuestieOcto.Visuals:ApplyFullNode(pin,fullNode,true,pin.lastAlpha or 1)
  end
  ResizePin(pin)
  MM:ApplyTrackerHoverToPin(pin)
end

local function PvPNodeVisible(node)
  if not node or not node.pvp then return true end
  return Settings():Get("showPvPRelatedQuests") and true or false
end

-- Map and Minimap share the same item-start presentation plan. The regular
-- prepared plan still contains raw item-start descriptors because Full Nodes
-- can share physical slots with active objectives, so the minimap explicitly
-- ignores item-start entries from that base plan and consumes the dedicated
-- World Map item-start plan instead. This gives both displays the same <1.00%
-- zone-wide representative marker without changing the underlying source data.
-- Inside dungeons/raids, only those ultra-rare representative markers are
-- hidden; meaningful >=1.00% item starters remain visible.
local function MinimapNodeVisible(node,allowItemStart)
  if not node or not IsRoleEnabled(node.role) or not PvPNodeVisible(node) then return false end

  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(MM.mapID)
     and not karazhan:NodeAllowed(node,MM.karazhanContext) then
    return false
  end

  if node.role=="itemStart" then
    if not allowItemStart then return false end
    if MM.inDungeonOrRaid and QuestieOcto.ItemStartAreas
       and QuestieOcto.ItemStartAreas:IsZoneWideRareChance(node.chance) then
      return false
    end
  end

  return true
end

local function ItemAreaVisible(area,allowItemStart)
  if not allowItemStart or not area or not IsRoleEnabled("itemStart") then return false end
  if MM.inDungeonOrRaid and area.zoneWideRare then return false end

  local karazhan=QuestieOcto.KarazhanContext
  if karazhan and karazhan:IsSharedArea(MM.mapID)
     and not karazhan:ItemAreaAllowed(area,MM.karazhanContext) then
    return false
  end

  local q=QuestieOcto.QuestModel:Get(area.questID)
  if q and q.pvp and not Settings():Get("showPvPRelatedQuests") then return false end
  return true
end

local function DescriptorCoordinates(desc)
  if not desc then return nil,nil end
  if desc.type=="itemStartArea" and desc.area then
    return tonumber(desc.area.x),tonumber(desc.area.y)
  end
  if desc.type=="nodeSlot" then return tonumber(desc.x),tonumber(desc.y) end
  if desc.type=="node" then return tonumber(desc.x),tonumber(desc.y) end
  return nil,nil
end

local function DescriptorHasVisibleEntry(desc,revision,allowItemStart)
  if not desc then return false end
  local visibilityRevision=(tonumber(revision) or 0)*2+(allowItemStart and 1 or 0)
  if desc.minimapVisibilityRevision==visibilityRevision then return desc.minimapVisible and true or false end

  local visible=false
  if desc.type=="itemStartArea" then
    visible=ItemAreaVisible(desc.area,allowItemStart)
  elseif desc.type=="nodeSlot" then
    for _,entry in pairs(desc.entries or {}) do
      local node=entry.node
      if MinimapNodeVisible(node,allowItemStart) then visible=true; break end
    end
  elseif desc.type=="node" and desc.node then
    visible=MinimapNodeVisible(desc.node,allowItemStart)
  end

  desc.minimapVisibilityRevision=visibilityRevision
  desc.minimapVisible=visible and true or false
  return visible
end

local function BindDescriptor(pin,desc,revision,allowItemStart)
  ResetPin(pin)
  pin.boundDescriptor=desc
  pin.boundRevision=revision

  if desc.type=="itemStartArea" and desc.area then
    if not ItemAreaVisible(desc.area,allowItemStart) then return false end
    local area=desc.area
    pin.itemStartArea=area
    pin.displayName=area.displayName
    pin.clusterCount=area.n or 1
    pin.mapX=tonumber(area.x)
    pin.mapY=tonumber(area.y)
    pin.coordKey=string.format("%.2f:%.2f",pin.mapX or 0,pin.mapY or 0)
    pin.role="itemStart"
    pin.questID=area.questID
    local q=QuestieOcto.QuestModel:Get(area.questID)
    pin.event=q and q.eventID and QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:IsPresentationEvent(q.eventID) or false
    pin.pvp=q and q.pvp or false
    pin.repeatable=q and q.presentationRepeatable or false
    pin.visualPriority=40
    pin.texture:SetTexture(QuestieOcto.Map:GetTextureForNode({role="itemStart",questID=area.questID,event=pin.event,pvp=pin.pvp,repeatable=pin.repeatable}))
    pin.texture:SetDrawLayer("OVERLAY",5)
    if QuestieOcto.Visuals then
      QuestieOcto.Visuals:ApplyPin(pin,{role="itemStart",questID=area.questID,pvp=pin.pvp,repeatable=pin.repeatable},true,pin.lastAlpha or 1)
    end
    ResizePin(pin)
    return true
  end

  local x,y=DescriptorCoordinates(desc)
  pin.mapX=x
  pin.mapY=y
  pin.coordKey=desc.coordKey or (x and y and string.format("%.2f:%.2f",x,y)) or nil

  local visible=false
  local entries=desc.entries
  if desc.type=="node" and desc.node then
    entries={{node=desc.node,clusterCount=desc.clusterCount or 1,kind=desc.kind}}
  end

  local fullNode=nil
  for _,entry in pairs(entries or {}) do
    local node=entry.node
    if MinimapNodeVisible(node,allowItemStart) then
      visible=true
      pin.clusterCount=math.max(pin.clusterCount or 1,entry.clusterCount or 1)
      AddEntry(pin,node)
      if entry.kind=="objectiveFull" or entry.kind=="itemStartFull" then
        if not fullNode or QuestieOcto.Map:GetVisualPriority(node)>QuestieOcto.Map:GetVisualPriority(fullNode) then
          fullNode=node
        end
      end
    end
  end

  if not visible then return false end

  if fullNode and QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
    QuestieOcto.Visuals:ApplyFullNode(pin,fullNode,true,pin.lastAlpha or 1)
    pin.fullNodeNode=fullNode
    ResizePin(pin)
  end
  MM:ApplyTrackerHoverToPin(pin)

  return true
end

function MM:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return 0 end

  local removed=0
  for _,pin in pairs(self.activeFrames or {}) do
    local changed=false
    if pin.itemStartArea and tonumber(pin.itemStartArea.questID)==questID then
      pin.itemStartArea=nil
      pin.entries={}
      changed=true
      removed=removed+1
    else
      for key,entry in pairs(pin.entries or {}) do
        if entry.node and tonumber(entry.node.questID)==questID then
          pin.entries[key]=nil
          removed=removed+1
          changed=true
        end
      end
    end

    if changed then
      -- PreparedMap.RemoveQuest mutates the shared prepared descriptor before
      -- this immediate visual removal, so keep the binding but refresh content.
      if pin.itemStartArea or next(pin.entries or {}) then
        RefreshPinVisual(pin)
      else
        if pin:IsShown() then pin:Hide(); self.stats.hidden=self.stats.hidden+1 end
      end
    end
  end
  return removed
end

function MM:HideAll()
  for _,pin in pairs(self.activeFrames or {}) do
    if pin:IsShown() then pin:Hide(); self.stats.hidden=self.stats.hidden+1 end
  end
  self.activeFrames=ClearTable(self.activeFrames)
  self.stats.active=0
  self.stats.candidateFrames=0
end

function MM:RefreshPlan(mapID)
  mapID=tonumber(mapID) or CurrentMapID()
  if not mapID then
    self.mapID=nil
    self.karazhanContext=nil
    self.plan=nil
    self.itemStartPlan=nil
    self.planRevision=nil
    self.mapWidth=nil
    self.mapHeight=nil
    self:HideAll()
    return
  end

  local karazhan=QuestieOcto.KarazhanContext
  local newKarazhanContext=nil
  if karazhan and karazhan:IsSharedArea(mapID) then
    newKarazhanContext=karazhan:GetPhysicalContext(mapID)
  end

  local mapChanged=tonumber(self.mapID)~=mapID
  local contextChanged=self.karazhanContext~=newKarazhanContext
  if mapChanged or contextChanged then
    self.mapID=mapID
    self.karazhanContext=newKarazhanContext
    if mapChanged then self.stats.mapChanges=self.stats.mapChanges+1 end
    self.bindRevision=(self.bindRevision or 0)+1
    self.lastPlayerX=nil
    self.lastPlayerY=nil
    self.lastZoom=nil
    self.discoveryPlayerX=nil
    self.discoveryPlayerY=nil
    self.physicalPlayerX=nil
    self.physicalPlayerY=nil
    self.cachedIndoor=nil
    self.cachedSquareMinimap=nil
    self.nextShapeCheck=nil
    self.nextMapIdentityCheck=nil
    self:HideAll()
  end

  -- Instance type changes at the same lifecycle boundaries that refresh the
  -- minimap plan (entering world / zone changes). Evaluate it here rather
  -- than polling GetInstanceInfo every 0.05 seconds.
  local inDungeonOrRaid=QuestieOcto.API and QuestieOcto.API:IsInDungeonOrRaid() or false
  if self.inDungeonOrRaid~=inDungeonOrRaid then
    self.inDungeonOrRaid=inDungeonOrRaid
    self.bindRevision=(self.bindRevision or 0)+1
  end

  local plan=QuestieOcto.PreparedMap:Get(mapID)
  local itemStartPlan=QuestieOcto.PreparedMap:GetWorldItemStarts(mapID)
  if not plan or not itemStartPlan then
    self.plan=nil
    self.itemStartPlan=nil
    self.planRevision=nil
    self.mapWidth=nil
    self.mapHeight=nil
    self:HideAll()
    if QuestieOcto.ZoneBootstrap then QuestieOcto.ZoneBootstrap:Request(mapID,0.01) end
    return
  end

  self.plan=plan
  self.itemStartPlan=itemStartPlan
  self.planRevision=QuestieOcto.PreparedMap.stateRevision

  if karazhan and karazhan:IsSharedArea(mapID) then
    -- Numeric map ID 3457 alone cannot identify Lower vs Upper Karazhan. If
    -- ClassicAPI cannot prove the physical server-map context, fail closed.
    self.mapWidth,self.mapHeight=karazhan:GetMinimapSize(self.karazhanContext)
    if not self.mapWidth or not self.mapHeight then
      self:HideAll()
      return
    end
  else
    self.mapWidth,self.mapHeight=QuestieOcto.DatabaseAPI:GetMinimapSize(mapID)
  end

  self.stats.refreshes=self.stats.refreshes+1
  self:UpdatePositions(true,mapID)
end

local function ResetVisibleStats()
  MM.stats.visibleAvailable=0
  MM.stats.visibleItemStart=0
  MM.stats.visibleObjective=0
  MM.stats.visibleTurnin=0
end

local function CountVisible(pin)
  if pin.role=="itemStart" then
    MM.stats.visibleItemStart=MM.stats.visibleItemStart+1
  elseif pin.role=="available" then
    MM.stats.visibleAvailable=MM.stats.visibleAvailable+1
  elseif pin.role=="turnin" then
    MM.stats.visibleTurnin=MM.stats.visibleTurnin+1
  else
    MM.stats.visibleObjective=MM.stats.visibleObjective+1
  end
end

local function PinDiscoverySort(a,b)
  local ak=tostring(a and a.coordKey or "")
  local bk=tostring(b and b.coordKey or "")
  if ak~=bk then return ak<bk end

  local ap=IsPermanentRole(a and a.role) and 1 or 0
  local bp=IsPermanentRole(b and b.role) and 1 or 0
  if ap~=bp then return ap<bp end
  if tostring(a and a.role or "")~=tostring(b and b.role or "") then
    return tostring(a and a.role or "")<tostring(b and b.role or "")
  end
  return tonumber(a and a.sourceID or 0)<tonumber(b and b.sourceID or 0)
end

local function AssignCandidateOffsets(frames)
  table.sort(frames,PinDiscoverySort)
  local previousKey=nil
  local groupIndex=0
  local offsetCount=table.getn(OVERLAP_OFFSETS)

  for index=1,table.getn(frames) do
    local pin=frames[index]
    local key=tostring(pin and pin.coordKey or "")
    if key~=previousKey then
      previousKey=key
      groupIndex=1
    else
      groupIndex=groupIndex+1
    end
    local off=OVERLAP_OFFSETS[math.mod(groupIndex-1,offsetCount)+1]
    pin.questieOctoOffsetX=off[1]
    pin.questieOctoOffsetY=off[2]
  end
end

function MM:PositionCandidates(px,py,fromDiscovery)
  local xDraw=tonumber(self.cachedXDraw)
  local yDraw=tonumber(self.cachedYDraw)
  local width=tonumber(self.cachedMinimapWidth)
  local height=tonumber(self.cachedMinimapHeight)
  local radiusSquared=tonumber(self.cachedRadiusSquared)
  if not xDraw or not yDraw or not width or not height or not radiusSquared then return end

  ResetVisibleStats()
  local visibleCount=0
  local squareMinimap=self.cachedSquareMinimap and true or false
  local frames=self.activeFrames or {}

  for index=1,table.getn(frames) do
    local pin=frames[index]
    local x=tonumber(pin and pin.mapX)
    local y=tonumber(pin and pin.mapY)
    local inside=false
    local xPos=nil
    local yPos=nil

    if x and y then
      xPos=(x-px)*xDraw
      yPos=(y-py)*yDraw
      if squareMinimap then
        inside=math.abs(xPos)<(width/2) and math.abs(yPos)<(height/2)
      else
        inside=xPos*xPos+yPos*yPos<radiusSquared
      end
    end

    if inside then
      visibleCount=visibleCount+1
      local targetX=xPos+(pin.questieOctoOffsetX or 0)
      local targetY=-yPos+(pin.questieOctoOffsetY or 0)
      if pin.lastDrawX~=targetX or pin.lastDrawY~=targetY then
        pin.lastDrawX=targetX
        pin.lastDrawY=targetY
        pin:ClearAllPoints()
        pin:SetPoint("CENTER",Minimap,"CENTER",targetX,targetY)
      end
      if not pin:IsShown() then pin:Show() end
      CountVisible(pin)
    elseif pin and pin:IsShown() then
      pin:Hide()
      self.stats.hidden=self.stats.hidden+1
    end
  end

  self.stats.active=visibleCount
  self.stats.positionUpdates=self.stats.positionUpdates+1
  if not fromDiscovery then
    self.stats.fastPositionUpdates=(self.stats.fastPositionUpdates or 0)+1
  end
end

function MM:DiscoverCandidates(px,py,zoom,squareMinimap,width,height)
  local mapWidth=tonumber(self.mapWidth)
  local mapHeight=tonumber(self.mapHeight)
  if not mapWidth or not mapHeight or mapWidth<=0 or mapHeight<=0 then self:HideAll(); return end

  local indoor=MinimapIndoor()
  local mapZoom=MINIMAP_ZOOM[indoor] and MINIMAP_ZOOM[indoor][zoom]
  if not mapZoom or mapZoom<=0 then self:HideAll(); return end

  local xScale=mapZoom/mapWidth
  local yScale=mapZoom/mapHeight
  local xDraw=width/xScale/100
  local yDraw=height/yScale/100
  local radius=math.min(width,height)/2
  local radiusSquared=radius*radius
  local margin=tonumber(self.discoveryMargin) or 1.5
  local expandedRadiusSquared=radiusSquared*margin*margin
  local expandedHalfWidth=(width/2)*margin
  local expandedHalfHeight=(height/2)*margin

  self.cachedIndoor=indoor
  self.cachedXDraw=xDraw
  self.cachedYDraw=yDraw
  self.cachedMinimapWidth=width
  self.cachedMinimapHeight=height
  self.cachedRadius=radius
  self.cachedRadiusSquared=radiusSquared
  self.cachedSquareMinimap=squareMinimap and true or false
  self.lastZoom=zoom
  self.discoveryPlayerX=px
  self.discoveryPlayerY=py

  local frames=ClearTable(self.activeFrames)
  self.activeFrames=frames
  local frameIndex=0
  local revision=self.bindRevision or 1

  -- Full descriptor discovery is deliberately separate from the 20 Hz movement
  -- pass. Keep candidates in a 1.5x minimap envelope so newly-visible pins can
  -- be shown smoothly while the player moves; rescan the complete plan only
  -- after the player moves a meaningful fraction of the minimap radius.
  local planPass=1
  while planPass<=2 do
    local scanPlan=planPass==1 and self.plan or self.itemStartPlan
    local allowItemStart=planPass==2
    local bindRevision=(tonumber(revision) or 0)*2+(allowItemStart and 1 or 0)

    for _,desc in ipairs(scanPlan or {}) do
      if DescriptorHasVisibleEntry(desc,revision,allowItemStart) then
        local x,y=DescriptorCoordinates(desc)
        if x and y then
          local xPos=(x-px)*xDraw
          local yPos=(y-py)*yDraw
          local insideEnvelope=false
          if squareMinimap then
            insideEnvelope=math.abs(xPos)<expandedHalfWidth and math.abs(yPos)<expandedHalfHeight
          else
            insideEnvelope=xPos*xPos+yPos*yPos<expandedRadiusSquared
          end

          if insideEnvelope then
            frameIndex=frameIndex+1
            local pin=self:GetOrCreate(frameIndex)
            local bound=(pin.boundDescriptor==desc and pin.boundRevision==bindRevision)
            if not bound then bound=BindDescriptor(pin,desc,bindRevision,allowItemStart) end
            if bound then
              frames[frameIndex]=pin
            else
              frameIndex=frameIndex-1
            end
          end
        end
      end
    end
    planPass=planPass+1
  end

  for index=frameIndex+1,table.getn(self.frames) do
    local pin=self.frames[index]
    if pin and pin:IsShown() then pin:Hide(); self.stats.hidden=self.stats.hidden+1 end
  end

  AssignCandidateOffsets(frames)
  self.stats.discoveryScans=(self.stats.discoveryScans or 0)+1
  self.stats.candidateFrames=table.getn(frames)
  self.stats.scannedDescriptors=table.getn(self.plan or {})+table.getn(self.itemStartPlan or {})
  self:RefreshTrackerHoverFocus()
  self:PositionCandidates(px,py,true)
end

function MM:NeedsDiscovery(px,py)
  if not self.discoveryPlayerX or not self.discoveryPlayerY then return true end
  local xDraw=tonumber(self.cachedXDraw)
  local yDraw=tonumber(self.cachedYDraw)
  local radius=tonumber(self.cachedRadius)
  if not xDraw or not yDraw or not radius then return true end

  local dx=(px-self.discoveryPlayerX)*xDraw
  local dy=(py-self.discoveryPlayerY)*yDraw
  local fraction=tonumber(self.rediscoverFraction) or 0.25
  local threshold=radius*fraction

  if self.cachedSquareMinimap then
    local width=tonumber(self.cachedMinimapWidth) or radius*2
    local height=tonumber(self.cachedMinimapHeight) or radius*2
    return math.abs(dx)>((width/2)*fraction) or math.abs(dy)>((height/2)*fraction)
  end
  return dx*dx+dy*dy>threshold*threshold
end

function MM:UpdatePositions(force,currentMapID)
  if not self.enabled or not Minimap or not self.plan or not self.mapID then
    self:HideAll()
    return
  end

  local current=tonumber(currentMapID) or CurrentMapID()
  if tonumber(current)~=tonumber(self.mapID) then self:RefreshPlan(current); return end
  if self.planRevision~=QuestieOcto.PreparedMap.stateRevision then self:RefreshPlan(current); return end

  local px,py=PlayerPosition(current)
  if not px or not py then self:HideAll(); return end

  local zoom=Minimap.GetZoom and Minimap:GetZoom() or 0
  local width=Minimap:GetWidth()
  local height=Minimap:GetHeight()
  if not width or width<=0 or not height or height<=0 then return end

  local now=GetTime and GetTime() or 0
  local squareMinimap=self.cachedSquareMinimap
  if force or squareMinimap==nil or not self.nextShapeCheck or now>=self.nextShapeCheck then
    local currentShape=UsesSquareMinimap()
    self.nextShapeCheck=now+(tonumber(self.shapeCheckInterval) or 1)
    if squareMinimap==nil or currentShape~=squareMinimap then force=true end
    squareMinimap=currentShape
  end

  if self.lastZoom~=zoom or self.cachedMinimapWidth~=width or self.cachedMinimapHeight~=height then
    force=true
  end

  if not force and self.lastPlayerX==px and self.lastPlayerY==py then
    return
  end

  self.lastPlayerX=px
  self.lastPlayerY=py

  if force or self:NeedsDiscovery(px,py) then
    self:DiscoverCandidates(px,py,zoom,squareMinimap,width,height)
  else
    self:PositionCandidates(px,py,false)
  end
end

function MM:OnUpdate(elapsed)
  self.elapsed=self.elapsed+(tonumber(elapsed) or 0)
  if self.elapsed<self.updateInterval then return end
  self.elapsed=0

  -- Zone/minimap events already refresh the physical map immediately. Keep a
  -- low-frequency safety check for unusual client transitions instead of
  -- crossing C_Map.GetBestMapForUnit on every 0.05-second movement tick.
  local now=GetTime and GetTime() or 0
  local current=self.mapID
  if not self.nextMapIdentityCheck or now>=self.nextMapIdentityCheck then
    self.nextMapIdentityCheck=now+(tonumber(self.mapIdentityCheckInterval) or 0.5)
    current=CurrentMapID()
    if tonumber(current)~=tonumber(self.mapID) then
      self:RefreshPlan(current)
      return
    end

    local karazhan=QuestieOcto.KarazhanContext
    if karazhan and karazhan:IsSharedArea(current)
       and karazhan:GetPhysicalContext(current)~=self.karazhanContext then
      self:RefreshPlan(current)
      return
    end
  end

  self:UpdatePositions(false,current)
end

function MM:OnPreparedMapReady(mapID)
  if tonumber(mapID)==tonumber(CurrentMapID()) then
    self:RefreshPlan()
  end
end

function MM:OnNodesReady()
  local current=CurrentMapID()
  if current and QuestieOcto.ZoneBootstrap then
    QuestieOcto.ZoneBootstrap:Request(current,0.01)
  end
end

function MM:Start()
  if self.frame then return end

  self.enabled=true
  self.globalScale=tonumber(Settings():Get("globalMiniMapScale")) or 1

  local f=CreateFrame("Frame","QuestieOctoMinimapUpdater",Minimap)
  self.frame=f

  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("ZONE_CHANGED")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("MINIMAP_ZONE_CHANGED")
  f:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  f:RegisterEvent("PLAYER_LEVEL_UP")

  f:SetScript("OnEvent",function()
    local eventName=event
    if eventName=="MINIMAP_UPDATE_ZOOM" then
      MM.stats.zoomEvents=(MM.stats.zoomEvents or 0)+1
      local now=GetTime and GetTime() or 0
      if MM.indoorProbeActive or (MM.indoorProbeIgnoreUntil and now<MM.indoorProbeIgnoreUntil) then
        return
      end

      -- Normal zoom changes can be resolved passively and UpdatePositions will
      -- rebuild geometry because lastZoom changed. If the client reports a
      -- minimap context transition without changing the visible zoom and both
      -- CVars are ambiguous, allow one compatibility probe outside the movement
      -- hot path.
      local currentZoom=Minimap and Minimap.GetZoom and tonumber(Minimap:GetZoom()) or nil
      local passive=ReadMinimapIndoorPassive()
      if passive~=nil then MM.indoorState=passive end

      if passive==nil and currentZoom~=nil and tonumber(MM.lastZoom)==currentZoom then
        QuestieOcto.Scheduler:After(0.01,function()
          MM:RefreshIndoorState(true)
          MM:UpdatePositions(true)
        end,"minimap-indoor-context-refresh")
      else
        MM:UpdatePositions(true)
      end
      return
    end

    if eventName=="PLAYER_LEVEL_UP" then
      -- Force descriptor rebinding so +25/+26 gray presentation changes as
      -- soon as the player levels, without touching the prepared map geometry.
      QuestieOcto.Scheduler:After(0.01,function()
        MM.bindRevision=(MM.bindRevision or 0)+1
        MM:RefreshPlan()
      end,"minimap-gray-level-refresh")
      return
    end

    QuestieOcto.Scheduler:After(0.01,function()
      RestoreCurrentZoneMapContext(eventName)
      MM:RefreshIndoorState(true)
      MM:RefreshPlan()
    end,"minimap-zone-refresh")
  end)

  f:SetScript("OnUpdate",function()
    MM:OnUpdate(arg1)
  end)

  if WorldMapFrame and not self.worldMapHideHooked then
    self.worldMapHideHooked=true
    local function OnWorldMapHide()
      QuestieOcto.Scheduler:After(0.01,function()
        RestoreCurrentZoneMapContext("WORLD_MAP_HIDE")
        MM:RefreshPlan()
      end,"minimap-worldmap-close")
    end

    -- Use an additive script hook when available so map UI addons can install
    -- or replace their own OnHide behavior without erasing the minimap refresh.
    if WorldMapFrame.HookScript then
      WorldMapFrame:HookScript("OnHide",OnWorldMapHide)
    else
      local previousOnHide=WorldMapFrame:GetScript("OnHide")
      WorldMapFrame:SetScript("OnHide",function()
        if previousOnHide then previousOnHide() end
        OnWorldMapHide()
      end)
    end
  end

  QuestieOcto.Scheduler:After(0.01,function()
    RestoreCurrentZoneMapContext("START")
    MM:RefreshIndoorState(true)
    MM:RefreshPlan()
  end,"minimap-start")
end

QuestieOcto:RegisterMessage("PREPARED_MAP_READY",MM,"OnPreparedMapReady")
QuestieOcto:RegisterMessage("NODES_READY",MM,"OnNodesReady")

MM:Start()
