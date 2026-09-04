QuestieOcto.Tooltips = QuestieOcto.Tooltips or {}
local T = QuestieOcto.Tooltips

-- World/target tooltip augmentation uses the already-resolved canonical node
-- graph instead of searching the database on every mouse movement. This is the
-- same separation used by pfQuest: map preparation establishes which quest
-- relationships exist, while GameTooltip hover only performs indexed lookups.
T.hoverIndex=T.hoverIndex or { unitByName={}, objectByID={}, itemByID={} }
T.hoverQuestBuckets=T.hoverQuestBuckets or {}
T.hoverIndexReady=T.hoverIndexReady or false
T.hoverIndexPending=T.hoverIndexPending or false
T.hoverIndexNeedsFull=T.hoverIndexNeedsFull or false
T.hoverPendingChanged=T.hoverPendingChanged or {}
T.worldTooltipState=T.worldTooltipState or { signature=nil, afterLines=0 }
T.initialized=T.initialized or false

local function Settings()
  return QuestieOcto.MinimapSettings
end

-- Keep the stock Blizzard GameTooltip path for normal clients. Questie-Octo
-- historically appended its map/minimap information to that native tooltip,
-- which preserves the normal Vanilla frame sizing and appearance.
--
-- pfUI is the exception: it attaches child OnShow handlers to GameTooltip and
-- mutates/re-shows that frame as part of its tooltip lifecycle. For pfUI only,
-- use a private GameTooltipTemplate so pin hovers cannot recurse through pfUI.
-- That private tooltip is then skinned through pfUI's own backdrop helpers.
local function GetPfUI()
  local ui=nil
  if getglobal then ui=getglobal("pfUI") end
  if not ui then ui=pfUI end
  if type(ui)=="table" then return ui end
  return nil
end

local function ApplyPfUISkin(tooltip)
  if not tooltip or tooltip.questieOctoPfUISkinned then return end

  local ui=GetPfUI()
  if type(ui)~="table" or type(ui.api)~="table" then return end
  if type(ui.api.CreateBackdrop)~="function" then return end

  local config=nil
  if getglobal then config=getglobal("pfUI_config") end
  if not config then config=pfUI_config end

  local alpha=nil
  if type(config)=="table" and type(config.tooltip)=="table" then
    alpha=tonumber(config.tooltip.alpha)
  end

  -- Match pfUI's own skins/blizzard/tooltips.lua path. pcall keeps pfUI an
  -- optional compatibility integration: a pfUI fork/API mismatch must never
  -- prevent Questie-Octo's tooltip from working with its default appearance.
  local ok=pcall(ui.api.CreateBackdrop,tooltip,nil,nil,alpha)
  if not ok then return end

  if type(ui.api.CreateBackdropShadow)=="function" then
    pcall(ui.api.CreateBackdropShadow,tooltip)
  end

  tooltip.questieOctoPfUISkinned=true
end

local function IsWorldMapPin(pin)
  return pin and pin.GetParent and WorldMapButton and pin:GetParent()==WorldMapButton
end

local function MapTooltip(pin)
  -- The native fullscreen World Map hides UIParent, and GameTooltip is a
  -- UIParent child. WorldMapTooltip is instead a WorldMapFrame child and is
  -- Blizzard's own tooltip for interactive World Map elements. Route only
  -- World Map pins through that native map tooltip; minimap/world hovers keep
  -- their existing GameTooltip/pfUI-private paths. pfQuest uses the same
  -- WorldMapButton -> WorldMapTooltip split on this client family.
  if IsWorldMapPin(pin) and WorldMapTooltip then return WorldMapTooltip end

  -- Non-pfUI users keep the exact native Blizzard tooltip frame. This also
  -- means other ordinary tooltip skins/addons can style GameTooltip normally.
  if not GetPfUI() then return GameTooltip end

  if T.mapTooltip then
    -- Re-check until successful so addon load order cannot leave an early-created
    -- Questie-Octo tooltip permanently unskinned when pfUI becomes available.
    ApplyPfUISkin(T.mapTooltip)
    return T.mapTooltip
  end

  if CreateFrame then
    local ok,tooltip=pcall(
      CreateFrame,
      "GameTooltip",
      "QuestieOctoMapTooltip",
      UIParent,
      "GameTooltipTemplate"
    )
    if ok and tooltip then
      if tooltip.SetClampedToScreen then tooltip:SetClampedToScreen(true) end
      T.mapTooltip=tooltip
      ApplyPfUISkin(tooltip)
      return tooltip
    end
  end

  -- Extremely defensive fallback for clients where GameTooltipTemplate cannot
  -- be created. ClassicAPI/pfUI themselves create this template successfully.
  return GameTooltip
end

function T:Hide(pin)
  local tooltip=MapTooltip(pin)
  if not tooltip then return end

  if not pin or not tooltip.GetOwner or tooltip:GetOwner()==pin then
    tooltip:Hide()
  end
end

local function IsEliteQuestType(questType)
  questType=tonumber(questType)
  return questType==1 or questType==62 or questType==81
end

local function QuestHasEliteMarker(q)
  if not q then return false end

  -- For active quests the native Quest Log tag is the strongest authority and
  -- matches the tracker exactly.
  local questID=tonumber(q.id)
  local active=questID and QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID] or nil
  if active and active.tag then return true end

  -- Available quests can be cache-cold, so ClassicAPI GetQuestDetails() may
  -- return nil until the client has loaded that quest. The compiled quest model
  -- therefore preserves the server's canonical Type 1/62/81 for this purpose.
  return IsEliteQuestType(q.questType)
end

local function QuestTitle(q)
  local title=tostring(q.title or ("Quest "..tostring(q.id or "")))
  if Settings():Get("enableTooltipsQuestLevel") then
    title="["..tostring(q.level or 0)..(QuestHasEliteMarker(q) and "+" or "").."] "..title
  end
  if Settings():Get("enableTooltipsQuestID") then
    title=title.." ("..tostring(q.id or 0)..")"
  end
  return title
end

local function FormatDropRate(rate)
  rate=tonumber(rate)
  if not rate then return nil end
  if rate>=10 then return string.format("%.0f",rate) end
  if rate>=2 then return string.format("%.1f",rate) end
  if rate>=0.01 then return string.format("%.2f",rate) end
  return string.format("%.3f",rate)
end

local function ItemStartAreaDropRateText(area)
  local minimum=nil
  local maximum=nil

  for _,source in pairs((area and area.sourceList) or {}) do
    local chance=tonumber(source.chance)
    if chance and chance>0 then
      if not minimum or chance<minimum then minimum=chance end
      if not maximum or chance>maximum then maximum=chance end
    end
  end

  if not minimum or not maximum then return nil end

  local minText=FormatDropRate(minimum)
  local maxText=FormatDropRate(maximum)
  if not minText or not maxText then return nil end

  if minText==maxText then return minText.."%" end
  return minText.."%",maxText.."%"
end

local function DifficultyColor(level,questID)
  -- Use the same authority as the native Quest Log.  Octo/Turtle modifies the
  -- low-level/easy band, so reproducing stock Classic thresholds makes map
  -- tooltips disagree with the Quest Log (green there, gray here).
  if QuestieOcto.GetNativeQuestDifficultyColor then
    local r,g,b=QuestieOcto:GetNativeQuestDifficultyColor(level,questID)
    if r then return r,g,b end
  end
  return 1,1,0
end

local function RoleText(role)
  if role=="available" or role=="itemStart" then return "(Available)" end
  if role=="turnin" then return "(Complete)" end
  return "(Active)"
end
local function RareRankText(rank)
  rank=tonumber(rank)
  if rank==4 then return "Rare" end
  if rank==2 then return "Rare Elite" end
  return nil
end

local function RespawnText(seconds)
  seconds=tonumber(seconds)
  if not seconds or seconds<=0 then return nil end

  -- Seconds are only useful for very short rare respawns. At five minutes and
  -- above, keep the tooltip compact and show whole minutes/hours only.
  if seconds<300 then
    if seconds<60 then return tostring(seconds).."s" end
    local minutes=math.floor(seconds/60)
    local secs=math.mod(seconds,60)
    if secs==0 then return tostring(minutes).." min" end
    return tostring(minutes).."m"..tostring(secs).."s"
  end

  if seconds>3600 then
    local hours=math.floor(seconds/3600)
    local minutes=math.floor(math.mod(seconds,3600)/60)
    local text=tostring(hours).."h"
    if minutes>0 then text=text..tostring(minutes).."m" end
    return text
  end

  return tostring(math.floor(seconds/60)).." min"
end

-- The stock GameTooltipText font is FRIZQT__.TTF and renders ASCII `~`
-- visibly high.  The current Turtle/Octo FrameXML also exposes the native
-- Fonts\\ARIALN.TTF family.  Keep every surrounding tooltip character in the
-- normal tooltip font, reserve one ordinary space for the separator, and draw
-- only the ASCII tilde in ARIALN at that slot.  This avoids unsupported Unicode
-- and texture escapes while limiting the font change to the one requested
-- glyph.  The marker is nudged down one pixel relative to the line center.
local function ResetCenteredTildes(tooltip)
  if not tooltip then return end
  tooltip.questieOctoCenteredTildeCount=0
  for _,fs in pairs(tooltip.questieOctoCenteredTildes or {}) do
    if fs and fs.Hide then fs:Hide() end
  end
end

-- Centered tildes are separate child FontStrings, not native GameTooltip text.
-- Hiding their parent makes them invisible but does not clear their own shown
-- state, so a reused GameTooltip can otherwise resurrect an old marker over an
-- unrelated item/unit tooltip.  Clear on both lifecycle boundaries: OnHide
-- covers ordinary leave/reopen, while OnTooltipCleared covers addons/FrameXML
-- that reuse a still-shown GameTooltip by replacing its contents in place.
local function EnsureCenteredTildeCleanup(tooltip)
  if not tooltip or tooltip.questieOctoCenteredTildeCleanupInstalled then return end
  tooltip.questieOctoCenteredTildeCleanupInstalled=true

  local function CleanupCenteredTildes()
    ResetCenteredTildes(tooltip)
  end

  -- Prefer additive hooks so Blizzard, pfUI/ShaguTweaks, and other tooltip
  -- addons keep ownership of their existing scripts.  Keep the same forwarding
  -- fallback used elsewhere in Questie-Octo for older Vanilla clients.
  if tooltip.HookScript then
    tooltip:HookScript("OnHide",CleanupCenteredTildes)
    tooltip:HookScript("OnTooltipCleared",CleanupCenteredTildes)
  elseif tooltip.GetScript and tooltip.SetScript then
    local previousOnHide=tooltip:GetScript("OnHide")
    tooltip:SetScript("OnHide",function()
      if previousOnHide then previousOnHide() end
      CleanupCenteredTildes()
    end)

    local previousOnTooltipCleared=tooltip:GetScript("OnTooltipCleared")
    tooltip:SetScript("OnTooltipCleared",function()
      if previousOnTooltipCleared then previousOnTooltipCleared() end
      CleanupCenteredTildes()
    end)
  end
end

local function TooltipLeftLine(tooltip,lineNumber)
  if not tooltip or not getglobal then return nil end
  local name=tooltip.GetName and tooltip:GetName() or nil
  if not name or name=="" then return nil end
  return getglobal(tostring(name).."TextLeft"..tostring(lineNumber))
end

local function CurrentTooltipLineNumber(tooltip)
  if tooltip and type(tooltip.NumLines)=="function" then
    local count=tonumber(tooltip:NumLines())
    if count then return count end
  end
  local name=tooltip and tooltip.GetName and tooltip:GetName() or nil
  if not name or not getglobal then return nil end
  local count=0
  for i=1,30 do
    local left=getglobal(tostring(name).."TextLeft"..tostring(i))
    local text=left and left.GetText and left:GetText() or nil
    if text then count=i end
  end
  if count>0 then return count end
  return nil
end

local function PositionCenteredTilde(tooltip,marker)
  if not tooltip or not marker then return end
  local lineNumber=tonumber(marker.questieOctoLineNumber)
  local line=TooltipLeftLine(tooltip,lineNumber)
  if not line or not line.GetFont then return end

  local _,size=line:GetFont()
  size=tonumber(size) or tonumber(marker.questieOctoFontSize) or 12

  local measure=tooltip.questieOctoCenteredTildeMeasure
  if not measure then
    measure=tooltip:CreateFontString(nil,"OVERLAY")
    tooltip.questieOctoCenteredTildeMeasure=measure
  end
  if not measure then return end

  local font,lineSize,flags=line:GetFont()
  if font and lineSize and measure.SetFont then measure:SetFont(font,lineSize,flags) end
  measure:SetText(tostring(marker.questieOctoPrefix or ""))
  local prefixWidth=measure.GetStringWidth and tonumber(measure:GetStringWidth()) or 0
  measure:SetText(" ")
  local spaceWidth=measure.GetStringWidth and tonumber(measure:GetStringWidth()) or 4
  local spaceIndex=tonumber(marker.questieOctoSpaceIndex) or 1
  local markerOffset=prefixWidth+((spaceIndex-0.5)*spaceWidth)

  marker:ClearAllPoints()
  -- GameTooltip finalizes line wrapping only when it is shown.  Before Show(),
  -- GetHeight() can still report a one-row height even though the final line
  -- will wrap.  Always run this positioning once more after tooltip:Show().
  -- For a finalized wrapped row, anchor from TOPLEFT to the center of the first
  -- visual row; single-line rows keep the already accepted 1.0.93 placement.
  local lineHeight=line.GetHeight and tonumber(line:GetHeight()) or nil
  if lineHeight and lineHeight>(size*1.5) then
    marker:SetPoint("CENTER",line,"TOPLEFT",markerOffset,-(size/2)-1)
  else
    marker:SetPoint("CENTER",line,"LEFT",markerOffset,-1)
  end
  marker:Show()
end

local function PlaceCenteredTilde(tooltip,prefix,r,g,b,spaceIndex)
  if not tooltip or not tooltip.CreateFontString then return end
  EnsureCenteredTildeCleanup(tooltip)
  local lineNumber=CurrentTooltipLineNumber(tooltip)
  local line=TooltipLeftLine(tooltip,lineNumber)
  if not line or not line.GetFont then return end

  local _,size=line:GetFont()
  size=tonumber(size) or 12

  tooltip.questieOctoCenteredTildes=tooltip.questieOctoCenteredTildes or {}
  local index=(tonumber(tooltip.questieOctoCenteredTildeCount) or 0)+1
  tooltip.questieOctoCenteredTildeCount=index

  local marker=tooltip.questieOctoCenteredTildes[index]
  if not marker then
    marker=tooltip:CreateFontString(nil,"OVERLAY")
    tooltip.questieOctoCenteredTildes[index]=marker
  end
  if not marker then return end

  -- ARIALN.TTF is a native Turtle/Octo font (used by NumberFont/ChatFont).
  -- Do not alter the surrounding tooltip font; only this one ASCII glyph uses
  -- ARIALN.  The font exists in the client source, so no addon font is bundled.
  if marker.SetFont then marker:SetFont("Fonts\\ARIALN.TTF",size) end
  marker:SetText("~")
  marker:SetTextColor(r or 1,g or 1,b or 1)
  marker.questieOctoLineNumber=lineNumber
  marker.questieOctoPrefix=tostring(prefix or "")
  marker.questieOctoFontSize=size
  marker.questieOctoSpaceIndex=tonumber(spaceIndex) or 1

  -- Initial placement handles ordinary rows immediately.  A second pass after
  -- tooltip:Show() below uses the *final* wrapped height for long rows.
  PositionCenteredTilde(tooltip,marker)
end

local function FinalizeCenteredTildes(tooltip)
  if not tooltip then return end
  local count=tonumber(tooltip.questieOctoCenteredTildeCount) or 0
  for i=1,count do
    local marker=tooltip.questieOctoCenteredTildes and tooltip.questieOctoCenteredTildes[i]
    if marker then PositionCenteredTilde(tooltip,marker) end
  end
end

local function AddCenteredTildeLine(tooltip,prefix,suffix,r,g,b,wrap,spaceAroundTilde)
  if not tooltip then return end
  local spacer=" "
  local spaceIndex=1
  if spaceAroundTilde then
    spacer="   "
    spaceIndex=2
  end
  tooltip:AddLine(tostring(prefix or "")..spacer..tostring(suffix or ""),r,g,b,wrap)
  PlaceCenteredTilde(tooltip,prefix,r,g,b,spaceIndex)
end

local function SourceDisplayName(source)
  local name=tostring(source.name or "Creature")
  local rank=RareRankText(source.rank)
  if rank then name=name.." ["..rank.."]" end
  if Settings():Get("enableTooltipsNPCID") and source.id then
    name=name.." (NPC "..tostring(source.id)..")"
  end
  return name
end

local function NormalizeFirstRowFont(tooltip)
  -- WoW 1.12 gives a GameTooltipTemplate's first left row a larger title font.
  -- Copy the normal second-row font onto line 1 for item-start source lists.
  tooltip=tooltip or GameTooltip
  local name=tooltip and tooltip.GetName and tooltip:GetName() or "GameTooltip"
  local first=getglobal and getglobal(tostring(name).."TextLeft1") or nil
  local normal=getglobal and getglobal(tostring(name).."TextLeft2") or nil

  if first and normal and normal.GetFont and first.SetFont then
    local font,size,flags=normal:GetFont()
    if font and size then
      first:SetFont(font,size,flags)
    end
  end
end


-- Map/minimap node geometry intentionally ignores numeric objective progress
-- (for example 3/10 -> 4/10) so a simple kill/loot counter does not rebuild
-- thousands of pins. Tooltips must therefore resolve the current quest-log row
-- at hover time instead of trusting the objective text snapshot stored on the
-- node when its geometry was last published.
local function LiveObjectiveText(node)
  local questID=tonumber(node and node.questID)
  local objectiveIndex=tonumber(node and node.objectiveIndex)
  local state=questID and QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[questID] or nil

  if state and objectiveIndex then
    for _,row in pairs(state.objectives or {}) do
      if tonumber(row.index)==objectiveIndex then
        return row.text or row.rawText or node.objectiveText
      end
    end
  end

  return node and node.objectiveText or nil
end

local function Extra(node)
  if node.role=="available" and node.conditionalOffer then
    return tostring(node.conditionalOffer)
  end
  if node.role=="itemStart" and node.itemName then
    local text
    if node.vendor then text="Sells ["..tostring(node.itemName).."]"
    else text="Drops ["..tostring(node.itemName).."]" end
    if node.chance and Settings():Get("enableTooltipDroprates") then text=text.." ("..(FormatDropRate(node.chance) or tostring(node.chance)).."%)" end
    return text.." - item starts quest"
  end
  if node.role=="objectiveCreature"
     or node.role=="objectiveObject"
     or node.role=="objectiveItemSource"
     or node.role=="objectiveArea" then
    local liveText=LiveObjectiveText(node)
    if liveText and liveText~="" then
      local text=liveText
      if node.role=="objectiveItemSource" and node.chance and Settings():Get("enableTooltipDroprates") then
        local rate=FormatDropRate(node.chance)
        if rate then text=text.." |cff999999["..rate.."%]|r" end
      end
      return text
    end
    if node.role=="objectiveItemSource" and node.itemName then
      local text="["..tostring(node.itemName).."]"
      if node.vendor then text=text.." (Vendor)" end
      if node.chance and Settings():Get("enableTooltipDroprates") then text=text.." ("..(FormatDropRate(node.chance) or tostring(node.chance)).."%)" end
      return text
    end
    return nil
  end
  return nil
end

local function AddSourceIDLine(pin,tooltip)
  tooltip=tooltip or MapTooltip()
  if pin.sourceKind=="creature" and pin.sourceID and Settings():Get("enableTooltipsNPCID") then
    tooltip:AddLine("NPC ID: "..tostring(pin.sourceID),.65,.65,.65)
  end
end

local function SortedEntries(pin)
  local rows={}
  for _,entry in pairs(pin.entries or {}) do
    rows[table.getn(rows)+1]=entry
  end

  table.sort(rows,function(a,b)
    local qa=QuestieOcto.QuestModel:Get(a.node.questID)
    local qb=QuestieOcto.QuestModel:Get(b.node.questID)
    local la=qa and qa.level or 0
    local lb=qb and qb.level or 0
    if la==lb then
      return tonumber(a.node.questID or 0)<tonumber(b.node.questID or 0)
    end
    return la<lb
  end)

  return rows
end

local function AddQuestEntries(pin,seen,tooltip)
  tooltip=tooltip or MapTooltip()
  local rows=SortedEntries(pin)
  local _,entry

  for _,entry in pairs(rows) do
    local node=entry.node
    local unique=tostring(node.questID)..":"..tostring(node.role)..":"..
      tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
      tostring(node.itemID or 0)

    if not seen[unique] then
      seen[unique]=true

      local q=QuestieOcto.QuestModel:Get(node.questID)
      if q then
        local r,g,b=DifficultyColor(q.level,q.id)
        tooltip:AddDoubleLine(
          QuestTitle(q),
          RoleText(node.role),
          r,g,b,1,.82,0
        )
        local extra=Extra(node)
        if extra then tooltip:AddLine("  "..extra,.82,.82,.82,true) end
        if node.scriptedEncounterNote then
          tooltip:AddLine("  "..tostring(node.scriptedEncounterNote),1,.72,.2,true)
        end
        if node.itemID and Settings():Get("enableTooltipsItemID") then
          tooltip:AddLine("  Item ID: "..tostring(node.itemID),.65,.65,.65)
        end
      end
    end
  end
end

local function RareSourceInfo(pin)
  for _,entry in pairs(pin.entries or {}) do
    local node=entry.node
    if node and node.sourceKind=="creature" then
      local rank=RareRankText(node.sourceRank)
      if rank then return rank,node.respawnSeconds end
    end
  end
  return nil,nil
end

local function QuestSourceTitle(pin)
  local title=pin.displayName or "Quest source"
  local rank=RareSourceInfo(pin)
  if rank then title=title.." ["..rank.."]" end
  return title
end

local function AddRareSourceRespawn(pin,tooltip)
  tooltip=tooltip or MapTooltip()
  local rank,respawnSeconds=RareSourceInfo(pin)
  if not rank then return end
  local respawn=RespawnText(respawnSeconds)
  if respawn then AddCenteredTildeLine(tooltip,"Respawn: ",respawn,.75,.75,.75) end
end

local function TooltipRelationshipSignature(pin)
  -- Full Nodes pins can merge several canonical nodes at one exact physical
  -- coordinate. Build the semantic signature from the actual entries rather
  -- than from the visual-owner source on the pin. Otherwise a mixed exact
  -- coordinate can accidentally look equivalent to a nearby single-source pin
  -- simply because the same creature happened to win visual priority.
  local rows={}
  local seen={}
  for _,entry in pairs(pin.entries or {}) do
    local node=entry.node
    if node then
      local source=tostring(node.sourceKind or "")..":"..tostring(node.sourceID or "")
      if not node.sourceID then source=source..":"..tostring(node.sourceName or "") end

      local row=source.."|"..
        tostring(node.questID or 0)..":"..tostring(node.role or "")..":"..
        tostring(node.itemID or 0)..":"..tostring(node.objectiveIndex or 0)..":"..
        tostring(node.objectiveText or "")

      if not seen[row] then
        seen[row]=true
        rows[table.getn(rows)+1]=row
      end
    end
  end
  table.sort(rows)
  return table.concat(rows,",")
end

local function AddFullNodeQuestEntries(pins,tooltip)
  tooltip=tooltip or MapTooltip()

  -- Exact-coordinate deduplication can put several source records on one pin.
  -- Those records may point at the same player-visible quest relationship.
  -- Group by quest + displayed status, then print each unique objective/drop
  -- line once. This preserves distinct objectives (for example two different
  -- People's Militia kill targets) without repeating the quest header or an
  -- identical Red Leather Bandana / item-start line for each internal source.
  local groups={}
  local order={}

  for _,near in pairs(pins or {}) do
    for _,entry in pairs(near.entries or {}) do
      local node=entry.node
      local q=node and QuestieOcto.QuestModel:Get(node.questID) or nil
      if node and q then
        local status=RoleText(node.role)
        local key=tostring(node.questID or 0)..":"..tostring(status)
        local group=groups[key]
        if not group then
          group={
            quest=q,
            status=status,
            lines={},
            seenLines={},
            itemIDs={},
            seenItemIDs={}
          }
          groups[key]=group
          order[table.getn(order)+1]=group
        end

        local extra=Extra(node)
        if extra and extra~="" and not group.seenLines[extra] then
          group.seenLines[extra]=true
          group.lines[table.getn(group.lines)+1]=extra
        end

        if node.itemID and Settings():Get("enableTooltipsItemID") then
          local itemID=tonumber(node.itemID) or node.itemID
          local itemKey=tostring(itemID)
          if not group.seenItemIDs[itemKey] then
            group.seenItemIDs[itemKey]=true
            group.itemIDs[table.getn(group.itemIDs)+1]=itemID
          end
        end
      end
    end
  end

  table.sort(order,function(a,b)
    local la=tonumber(a.quest.level) or 0
    local lb=tonumber(b.quest.level) or 0
    if la==lb then
      local ia=tonumber(a.quest.id or 0) or 0
      local ib=tonumber(b.quest.id or 0) or 0
      if ia==ib then return tostring(a.status)<tostring(b.status) end
      return ia<ib
    end
    return la<lb
  end)

  for _,group in pairs(order) do
    local q=group.quest
    local r,g,b=DifficultyColor(q.level,q.id)
    tooltip:AddDoubleLine(QuestTitle(q),group.status,r,g,b,1,.82,0)

    for _,line in pairs(group.lines) do
      tooltip:AddLine("  "..tostring(line),.82,.82,.82,true)
    end
    for _,itemID in pairs(group.itemIDs) do
      tooltip:AddLine("  Item ID: "..tostring(itemID),.65,.65,.65)
    end
  end
end

local function SemanticallyRelatedNearbyFullNodePins(pin,pins)
  local result={}
  local signature=TooltipRelationshipSignature(pin)
  result[1]=pin

  for _,near in pairs(pins or {}) do
    if near~=pin and near.fullNode and TooltipRelationshipSignature(near)==signature then
      result[table.getn(result)+1]=near
    end
  end

  return result
end

local function ShowCombinedNearbyFullNodeTooltip(pin,pins)
  local tooltip=MapTooltip(pin)
  tooltip:SetOwner(pin,"ANCHOR_CURSOR")
  tooltip:ClearLines()
  ResetCenteredTildes(tooltip)

  -- Full Nodes can place several coordinates of the same source within only a
  -- few screen pixels. Collapse only semantically identical source/relationship
  -- markers. Spatial proximity by itself must never concatenate unrelated mobs
  -- or quest relationships into one giant tooltip. No map/node data is removed.
  local title=QuestSourceTitle(pin)
  if table.getn(pins)>1 then
    title=title.." |cffaaaaaa("..tostring(table.getn(pins)).." nearby)|r"
  end

  tooltip:AddLine(title,.2,1,.35)
  AddSourceIDLine(pin,tooltip)
  AddRareSourceRespawn(pin,tooltip)

  AddFullNodeQuestEntries(pins,tooltip)

  NormalizeFirstRowFont(tooltip)
  tooltip:Show()
  FinalizeCenteredTildes(tooltip)
end

local function ShowCombinedNearbyQuestTooltip(pin,pins)
  local tooltip=MapTooltip(pin)
  tooltip:SetOwner(pin,"ANCHOR_CURSOR")
  tooltip:ClearLines()
  ResetCenteredTildes(tooltip)

  local seen={}
  local first=true
  local _,near

  for _,near in pairs(pins) do
    if near.itemStartArea then
      -- Existing item-start area formatting stays self-contained. Nearby
      -- ordinary quest markers are still included below it.
      local area=near.itemStartArea
      if not first then tooltip:AddLine(" ",1,1,1) end
      first=false

      tooltip:AddLine(tostring(area.displayName or "Item-start source"),.2,1,.35)
      local q=QuestieOcto.QuestModel:Get(area.questID)
      if q then
        local key="itemstart:"..tostring(area.questID)
        if not seen[key] then
          seen[key]=true
          local r,g,b=DifficultyColor(q.level,q.id)
          tooltip:AddDoubleLine(QuestTitle(q),"(Available)",r,g,b,1,.82,0)
        end
      end
    elseif near.entries and next(near.entries) then
      if not first then tooltip:AddLine(" ",1,1,1) end
      first=false

      local title=QuestSourceTitle(near)
      if near.clusterCount and near.clusterCount>1 then
        title=title.." |cffaaaaaa("..tostring(near.clusterCount).." nearby spawns)|r"
      end

      tooltip:AddLine(title,.2,1,.35)
      AddSourceIDLine(near,tooltip)
      AddRareSourceRespawn(near,tooltip)
      AddQuestEntries(near,seen,tooltip)
    end
  end

  NormalizeFirstRowFont(tooltip)
  tooltip:Show()
  FinalizeCenteredTildes(tooltip)
end

local function IsQuestHoverRole(role)
  return role=="available" or role=="itemStart" or role=="turnin" or
    role=="objectiveCreature" or role=="objectiveObject" or role=="objectiveItemSource"
end

local function AppendIndexed(index,key,node)
  if key==nil then return end
  index[key]=index[key] or {}
  table.insert(index[key],node)
end

local function AppendQuestIndexed(index,questBuckets,kind,key,node)
  if key==nil or not node then return end
  AppendIndexed(index[kind],key,node)
  local questID=tonumber(node.questID)
  if not questID or questID<=0 then return end
  questBuckets[questID]=questBuckets[questID] or {}
  local bucketKey=tostring(kind)..":"..tostring(key)
  if not questBuckets[questID][bucketKey] then
    questBuckets[questID][bucketKey]={kind=kind,key=key}
  end
end

local function UnitNameKey(name)
  name=tostring(name or "")
  if name=="" then return nil end
  return string.lower(name)
end

local function IndexHoverNode(index,questBuckets,node,showItemStarts)
  local questID=tonumber(node and node.questID)
  if not questID or questID<=0 or not IsQuestHoverRole(node.role)
     or (node.role=="itemStart" and not showItemStarts) then return end

  if node.sourceKind=="creature" and node.sourceName then
    AppendQuestIndexed(index,questBuckets,"unitByName",UnitNameKey(node.sourceName),node)
  elseif node.sourceKind=="gameObject" and tonumber(node.sourceID) then
    AppendQuestIndexed(index,questBuckets,"objectByID",tonumber(node.sourceID),node)
  end
end

local function IndexQuestItemEntries(index,questBuckets,questID,showItemStarts)
  questID=tonumber(questID)
  if not questID then return end

  local resolved=QuestieOcto.Objectives and QuestieOcto.Objectives.byQuest
    and QuestieOcto.Objectives.byQuest[questID] or nil
  if resolved and QuestieOcto.QuestLog.active[questID] then
    for _,item in pairs(resolved.item or {}) do
      local itemID=tonumber(item.itemID)
      if itemID then
        AppendQuestIndexed(index,questBuckets,"itemByID",itemID,{
          questID=questID,
          role="objectiveItemSource",
          itemID=itemID,
          itemName=item.name,
          objectiveIndex=item.objectiveIndex,
          objectiveText=item.objectiveText,
          current=item.current,
          required=item.required,
          objectiveComplete=item.complete and true or false,
        })
      end
    end
  end

  if showItemStarts then
    local starter=QuestieOcto.ItemStarts and QuestieOcto.ItemStarts.byQuest
      and QuestieOcto.ItemStarts.byQuest[questID] or nil
    if starter and QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.available[questID] then
      for _,item in pairs(starter.items or {}) do
        local itemID=tonumber(item.itemID)
        if itemID then
          AppendQuestIndexed(index,questBuckets,"itemByID",itemID,{
            questID=questID,
            role="itemStart",
            itemID=itemID,
            itemName=item.name,
          })
        end
      end
    end
  end
end

local function RemoveQuestHoverEntries(self,questID)
  questID=tonumber(questID)
  local refs=questID and self.hoverQuestBuckets[questID] or nil
  if not refs then return end

  for _,ref in pairs(refs) do
    local source=self.hoverIndex[ref.kind]
    local bucket=source and source[ref.key] or nil
    if bucket then
      local kept={}
      for _,node in pairs(bucket) do
        if tonumber(node.questID)~=questID then table.insert(kept,node) end
      end
      if table.getn(kept)>0 then source[ref.key]=kept else source[ref.key]=nil end
    end
  end
  self.hoverQuestBuckets[questID]=nil
end

function T:RebuildHoverIndex()
  local nextIndex={ unitByName={}, objectByID={}, itemByID={} }
  local nextQuestBuckets={}
  local showItemStarts=Settings():Get("showItemStartQuests") and true or false

  for _,node in pairs((QuestieOcto.Nodes and QuestieOcto.Nodes.nodes) or {}) do
    IndexHoverNode(nextIndex,nextQuestBuckets,node,showItemStarts)
  end

  for questID in pairs((QuestieOcto.QuestLog and QuestieOcto.QuestLog.active) or {}) do
    IndexQuestItemEntries(nextIndex,nextQuestBuckets,questID,showItemStarts)
  end
  if showItemStarts then
    for questID in pairs((QuestieOcto.ItemStarts and QuestieOcto.ItemStarts.byQuest) or {}) do
      IndexQuestItemEntries(nextIndex,nextQuestBuckets,questID,showItemStarts)
    end
  end

  self.hoverIndex=nextIndex
  self.hoverQuestBuckets=nextQuestBuckets
  self.hoverIndexReady=true
  self.hoverIndexPending=false
  self.hoverIndexNeedsFull=false
  self.hoverPendingChanged={}
end

function T:PatchHoverIndex(changedQuests)
  if not self.hoverIndexReady or not QuestieOcto.Nodes or not QuestieOcto.Nodes.ready then
    self:RebuildHoverIndex()
    return
  end

  local showItemStarts=Settings():Get("showItemStartQuests") and true or false
  for rawQuestID in pairs(changedQuests or {}) do
    local questID=tonumber(rawQuestID)
    if questID and questID>0 then
      RemoveQuestHoverEntries(self,questID)
      for _,node in pairs(QuestieOcto.Nodes:GetQuestNodes(questID) or {}) do
        IndexHoverNode(self.hoverIndex,self.hoverQuestBuckets,node,showItemStarts)
      end
      IndexQuestItemEntries(self.hoverIndex,self.hoverQuestBuckets,questID,showItemStarts)
    end
  end

  self.hoverIndexReady=true
  self.hoverIndexPending=false
end

function T:ScheduleHoverIndex(mapSet,changedQuests)
  if changedQuests and next(changedQuests) and self.hoverIndexReady then
    for questID in pairs(changedQuests) do self.hoverPendingChanged[questID]=true end
  else
    self.hoverIndexNeedsFull=true
  end

  if self.hoverIndexPending then return end
  self.hoverIndexPending=true
  QuestieOcto.Scheduler:After(0.05,function()
    if T.hoverIndexNeedsFull then
      T:RebuildHoverIndex()
      return
    end

    local changed=T.hoverPendingChanged
    T.hoverPendingChanged={}
    T:PatchHoverIndex(changed)
  end,"tooltip-hover-index")
end

local function HoverExtra(node,subjectKind)
  if not node then return nil end

  if node.role=="itemStart" then
    if subjectKind=="item" then return "Item starts quest" end

    local text
    if node.vendor then text="Sells ["..tostring(node.itemName or "Quest item").."]"
    else text="Drops ["..tostring(node.itemName or "Quest item").."]" end
    if node.chance and Settings():Get("enableTooltipDroprates") then
      local rate=FormatDropRate(node.chance)
      if rate then text=text.." ("..rate.."%)" end
    end
    return text.." - item starts quest"
  end

  if node.role=="objectiveCreature" or node.role=="objectiveObject" or node.role=="objectiveItemSource" then
    local text=LiveObjectiveText(node)
    if not text or text=="" then
      if node.itemName then text="["..tostring(node.itemName).."]" end
    end

    -- A source-specific drop rate is useful while hovering the creature/object
    -- that drops the item, but it would be misleading on the item's own tooltip
    -- because the item can have many sources with different rates.
    if text and subjectKind~="item" and node.role=="objectiveItemSource" and node.chance and Settings():Get("enableTooltipDroprates") then
      local rate=FormatDropRate(node.chance)
      if rate then text=text.." |cff999999["..rate.."%]|r" end
    end
    return text
  end

  return nil
end

local function HoverStatusPriority(role)
  if role=="turnin" then return 3 end
  if role=="available" or role=="itemStart" then return 2 end
  return 1
end

local function HoverStatusText(priority)
  if priority==3 then return "(Complete)" end
  if priority==2 then return "(Available)" end
  return "(Active)"
end

local function BuildHoverGroups(nodes,subjectKind)
  local groups={}

  for _,node in pairs(nodes or {}) do
    local questID=tonumber(node.questID)
    local q=questID and QuestieOcto.QuestModel:Get(questID) or nil
    local itemStartHidden=node.role=="itemStart" and not Settings():Get("showItemStartQuests")
    if q and not itemStartHidden then
      local group=groups[questID]
      if not group then
        group={ quest=q, status=0, lines={}, seenLines={}, sourceIDs={} }
        groups[questID]=group
      end

      local priority=HoverStatusPriority(node.role)
      if priority>group.status then group.status=priority end

      local extra=HoverExtra(node,subjectKind)
      if extra and extra~="" and not group.seenLines[extra] then
        group.seenLines[extra]=true
        table.insert(group.lines,extra)
      end

      if subjectKind=="unit" and tonumber(node.sourceID) then
        group.sourceIDs[tonumber(node.sourceID)]=true
      end
    end
  end

  local ordered={}
  for _,group in pairs(groups) do table.insert(ordered,group) end
  table.sort(ordered,function(a,b)
    local la=tonumber(a.quest.level) or 0
    local lb=tonumber(b.quest.level) or 0
    if la==lb then return tonumber(a.quest.id or 0)<tonumber(b.quest.id or 0) end
    return la<lb
  end)
  return ordered
end

local function UniqueUnitSourceID(nodes)
  local ids={}
  local count=0
  local only=nil
  for _,node in pairs(nodes or {}) do
    local id=tonumber(node.sourceID)
    if id and not ids[id] then
      ids[id]=true
      count=count+1
      only=id
      if count>1 then return nil end
    end
  end
  return only
end

local function TooltipLineCount()
  if GameTooltip and type(GameTooltip.NumLines)=="function" then
    local count=tonumber(GameTooltip:NumLines())
    if count then return count end
  end

  -- Vanilla fallback for replacement UIs that do not expose NumLines cleanly.
  local count=0
  if getglobal then
    for i=1,128 do
      local left=getglobal("GameTooltipTextLeft"..tostring(i))
      local right=getglobal("GameTooltipTextRight"..tostring(i))
      local leftText=left and left.GetText and left:GetText() or nil
      local rightText=right and right.GetText and right:GetText() or nil
      if leftText or rightText then count=i end
    end
  end
  return count
end

local function WorldTooltipSignature(subjectKind,subjectID)
  return tostring(subjectKind or "")..":"..tostring(subjectID or "")
end

local function ShouldAppendWorldTooltip(signature)
  local state=T.worldTooltipState or {}
  local lines=TooltipLineCount()

  -- pfUI and other replacement interfaces may hide/show or restyle the same
  -- GameTooltip several times for one hover. If our previously appended block
  -- is still present, never append it again. If the tooltip was rebuilt/cleared,
  -- its line count drops below our recorded end and it is safe to append anew.
  if state.signature==signature
     and tonumber(state.afterLines or 0)>0
     and lines>=tonumber(state.afterLines or 0) then
    return false
  end

  return true
end

local function MarkWorldTooltipAppended(signature)
  T.worldTooltipState=T.worldTooltipState or {}
  T.worldTooltipState.signature=signature
  T.worldTooltipState.afterLines=TooltipLineCount()
end

-- pfUI owns the global GameTooltip and performs its normal size/layout pass
-- from its own OnShow lifecycle. Questie-Octo cannot safely call Show() again
-- after appending world-hover quest lines because that can re-enter pfUI and
-- duplicate tooltip content. Instead, when pfUI is present, resize the already
-- visible GameTooltip directly from its rendered FontStrings. pfUI's backdrop
-- is anchored to the tooltip edges, so it follows this size change immediately.
local function ResizePfUIWorldTooltip(beforeLines,beforeWidth,beforeHeight,beforeBottomPadding)
  if not GetPfUI() or not GameTooltip then return end

  local afterLines=TooltipLineCount()
  if afterLines<=tonumber(beforeLines or 0) then return end

  local currentWidth=tonumber(GameTooltip.GetWidth and GameTooltip:GetWidth()) or tonumber(beforeWidth) or 0
  local desiredWidth=math.max(currentWidth,tonumber(beforeWidth) or 0)
  local maxWidth=desiredWidth

  -- Preserve pfUI's existing width unless the new Questie rows actually need
  -- more room. AddDoubleLine rows need both left and right strings plus a gap;
  -- wrapped objective rows report their rendered line width on this client.
  if getglobal then
    for i=1,afterLines do
      local left=getglobal("GameTooltipTextLeft"..tostring(i))
      local right=getglobal("GameTooltipTextRight"..tostring(i))
      local leftText=left and left.GetText and left:GetText() or nil
      local rightText=right and right.GetText and right:GetText() or nil
      local leftWidth=0
      local rightWidth=0
      if leftText and left.GetStringWidth then leftWidth=tonumber(left:GetStringWidth()) or 0 end
      if rightText and right.GetStringWidth then rightWidth=tonumber(right:GetStringWidth()) or 0 end

      local rowWidth=leftWidth
      if rightText and rightText~="" then rowWidth=leftWidth+rightWidth+18 end
      if rowWidth+20>maxWidth then maxWidth=rowWidth+20 end
    end
  end

  -- Keep world-hover tooltips readable without allowing a very long localized
  -- quest string to turn them into a screen-wide panel. Objective text already
  -- wraps, so 420px is a presentation ceiling rather than a data truncation.
  desiredWidth=math.min(math.max(desiredWidth,maxWidth),420)
  if GameTooltip.SetWidth and desiredWidth>currentWidth+0.5 then
    GameTooltip:SetWidth(desiredWidth)
  end

  local tooltipTop=GameTooltip.GetTop and tonumber(GameTooltip:GetTop()) or nil
  local lowestBottom=nil
  if getglobal then
    for i=1,afterLines do
      local left=getglobal("GameTooltipTextLeft"..tostring(i))
      local right=getglobal("GameTooltipTextRight"..tostring(i))
      local leftText=left and left.GetText and left:GetText() or nil
      local rightText=right and right.GetText and right:GetText() or nil
      if leftText and left.GetBottom then
        local bottom=tonumber(left:GetBottom())
        if bottom and (not lowestBottom or bottom<lowestBottom) then lowestBottom=bottom end
      end
      if rightText and right.GetBottom then
        local bottom=tonumber(right:GetBottom())
        if bottom and (not lowestBottom or bottom<lowestBottom) then lowestBottom=bottom end
      end
    end
  end

  local currentHeight=tonumber(GameTooltip.GetHeight and GameTooltip:GetHeight()) or tonumber(beforeHeight) or 0
  local desiredHeight=currentHeight
  if tooltipTop and lowestBottom then
    local padding=tonumber(beforeBottomPadding) or 8
    if padding<4 then padding=4 elseif padding>24 then padding=24 end
    desiredHeight=tooltipTop-lowestBottom+padding
  else
    -- Defensive Vanilla fallback if a replacement client does not expose
    -- FontString screen coordinates. This still encloses every appended row.
    local added=afterLines-tonumber(beforeLines or 0)
    desiredHeight=math.max(currentHeight,(tonumber(beforeHeight) or currentHeight)+(added*14))
  end

  if GameTooltip.SetHeight and desiredHeight>currentHeight+0.5 then
    GameTooltip:SetHeight(desiredHeight)
  end
end

-- pfUI world/unit tooltips often start intentionally compact. Measure the
-- Questie quest header before appending it so the single-row pfUI compatibility
-- layout has enough room in normal cases; very long localized text can still
-- wrap naturally. Native clients continue to use Blizzard AddDoubleLine rows.
local function PfUIWorldTooltipTextWidth(text)
  if not GetPfUI() or not UIParent then return 0 end

  if not T.pfUIWorldMeasureText then
    local measure=UIParent:CreateFontString(nil,"ARTWORK","GameTooltipText")
    if not measure then return 0 end
    measure:Hide()
    T.pfUIWorldMeasureText=measure
  end

  local measure=T.pfUIWorldMeasureText
  measure:SetText(tostring(text or ""))
  if measure.GetStringWidth then return tonumber(measure:GetStringWidth()) or 0 end
  return 0
end

local function PreSizePfUIWorldTooltip(groups)
  if not GetPfUI() or not GameTooltip or not GameTooltip.SetWidth then return end

  local currentWidth=tonumber(GameTooltip.GetWidth and GameTooltip:GetWidth()) or 0
  local desiredWidth=currentWidth

  for _,group in pairs(groups or {}) do
    local q=group.quest
    local leftWidth=PfUIWorldTooltipTextWidth(QuestTitle(q))
    local rightWidth=PfUIWorldTooltipTextWidth(HoverStatusText(group.status))
    local rowWidth=leftWidth+rightWidth+38
    if rowWidth>desiredWidth then desiredWidth=rowWidth end
  end

  -- Keep the same presentation ceiling used by the post-append resize pass.
  -- This establishes a comfortable width before pfUI's single-row quest header
  -- is added; objective text remains wrapped and no quest information is lost.
  if desiredWidth>420 then desiredWidth=420 end
  if desiredWidth>currentWidth+0.5 then GameTooltip:SetWidth(desiredWidth) end
end

local function AddWorldHoverEntries(nodes,subjectKind,subjectID,signature)
  local groups=BuildHoverGroups(nodes,subjectKind)
  if table.getn(groups)==0 then return false end

  local beforeLines=TooltipLineCount()
  local beforeWidth=GameTooltip and GameTooltip.GetWidth and tonumber(GameTooltip:GetWidth()) or 0
  local beforeHeight=GameTooltip and GameTooltip.GetHeight and tonumber(GameTooltip:GetHeight()) or 0
  local beforeBottomPadding=nil
  -- pfUI is widened before Questie rows are added so its single-row compatibility
  -- header normally fits without wrapping; the post-pass still encloses all rows.
  PreSizePfUIWorldTooltip(groups)

  if GetPfUI() and GameTooltip and GameTooltip.GetBottom and getglobal then
    local tooltipBottom=tonumber(GameTooltip:GetBottom())
    local lowestBottom=nil
    for i=1,beforeLines do
      local left=getglobal("GameTooltipTextLeft"..tostring(i))
      local right=getglobal("GameTooltipTextRight"..tostring(i))
      local leftText=left and left.GetText and left:GetText() or nil
      local rightText=right and right.GetText and right:GetText() or nil
      if leftText and left.GetBottom then
        local bottom=tonumber(left:GetBottom())
        if bottom and (not lowestBottom or bottom<lowestBottom) then lowestBottom=bottom end
      end
      if rightText and right.GetBottom then
        local bottom=tonumber(right:GetBottom())
        if bottom and (not lowestBottom or bottom<lowestBottom) then lowestBottom=bottom end
      end
    end
    if tooltipBottom and lowestBottom then beforeBottomPadding=lowestBottom-tooltipBottom end
  end

  GameTooltip:AddLine(" ",1,1,1)

  if subjectKind=="unit" and Settings():Get("enableTooltipsNPCID") then
    local npcID=UniqueUnitSourceID(nodes)
    if npcID then GameTooltip:AddLine("NPC ID: "..tostring(npcID),.65,.65,.65) end
  elseif subjectKind=="item" and Settings():Get("enableTooltipsItemID") and subjectID then
    GameTooltip:AddLine("Item ID: "..tostring(subjectID),.65,.65,.65)
  end

  for _,group in pairs(groups) do
    local q=group.quest
    local r,g,b=DifficultyColor(q.level,q.id)

    -- pfUI's compact unit tooltip can keep stale left/right anchors for
    -- AddDoubleLine rows even when Questie-Octo pre-sizes the frame.  The
    -- result is the right-side status being drawn through the quest title.
    -- Keep the native Blizzard two-column row for normal clients, but use one
    -- wrapped row under pfUI so there are no competing column anchors.  The
    -- status retains the same gold presentation via an inline color escape.
    if GetPfUI() then
      GameTooltip:AddLine(
        QuestTitle(q).."  |cffffd100"..HoverStatusText(group.status).."|r",
        r,g,b,true
      )
    else
      GameTooltip:AddDoubleLine(QuestTitle(q),HoverStatusText(group.status),r,g,b,1,.82,0)
    end

    for _,line in pairs(group.lines) do
      GameTooltip:AddLine("  "..tostring(line),.82,.82,.82,true)
    end
  end

  MarkWorldTooltipAppended(signature)

  -- Stock Vanilla recalculates the GameTooltip backdrop after Show(). The old
  -- Questie-Octo 1.0.15 path deliberately re-showed the tooltip here so newly
  -- appended quest lines were enclosed by the Blizzard tooltip background.
  -- Keep that exact native behavior for normal clients. pfUI is resized
  -- directly instead: re-showing its globally managed GameTooltip can re-enter
  -- its OnShow lifecycle and was the source of the earlier duplicate blocks.
  if GetPfUI() then
    ResizePfUIWorldTooltip(beforeLines,beforeWidth,beforeHeight,beforeBottomPadding)
  elseif GameTooltip and type(GameTooltip.Show)=="function" then
    GameTooltip:Show()
  end
  return true
end

local function ItemIDFromTooltipLink(link)
  if not link then return nil end
  local _,_,id=string.find(link,"item:(%d+)")
  return tonumber(id)
end

function T:AugmentWorldTooltip()
  if not Settings():Get("enableTooltips") then return end
  if not self.hoverIndexReady then return end

  -- Map/minimap pins already render their own richer tooltip through T:Show().
  -- Do not append the world-hover index to those same tooltips a second time.
  local owner=nil
  if GameTooltip and type(GameTooltip.GetOwner)=="function" then owner=GameTooltip:GetOwner() end
  if owner and owner.questieOctoTooltipPin then return end

  if GameTooltip and type(GameTooltip.GetUnitGUID)=="function" then
    local unitName=GameTooltip:GetUnitGUID()
    local key=UnitNameKey(unitName)
    local nodes=key and self.hoverIndex.unitByName[key] or nil
    local signature=key and WorldTooltipSignature("unit",key) or nil
    if nodes and signature and ShouldAppendWorldTooltip(signature)
       and AddWorldHoverEntries(nodes,"unit",nil,signature) then
      return
    end
  end

  if GameTooltip and type(GameTooltip.GetGameObject)=="function" then
    local objectName,objectID=GameTooltip:GetGameObject()
    objectID=tonumber(objectID)
    local nodes=objectID and self.hoverIndex.objectByID[objectID] or nil
    local signature=objectID and WorldTooltipSignature("object",objectID) or nil
    if nodes and signature and ShouldAppendWorldTooltip(signature)
       and AddWorldHoverEntries(nodes,"object",objectID,signature) then
      return
    end
  end

  if GameTooltip and type(GameTooltip.GetItem)=="function" then
    local itemName,itemLink=GameTooltip:GetItem()
    local itemID=ItemIDFromTooltipLink(itemLink)
    local nodes=itemID and self.hoverIndex.itemByID[itemID] or nil
    local signature=itemID and WorldTooltipSignature("item",itemID) or nil
    if nodes and signature and ShouldAppendWorldTooltip(signature) then
      AddWorldHoverEntries(nodes,"item",itemID,signature)
    end
  end
end

function T:Initialize()
  if self.initialized then return end
  self.initialized=true

  -- pfQuest's ClassicAPI build uses a child frame's OnShow rather than modern
  -- OnTooltipSetUnit/OnTooltipSetItem hooks, which are not reliable APIs on the
  -- Vanilla 1.12 target. ClassicAPI supplies GetUnitGUID/GetGameObject.
  if GameTooltip then
    local watcher=CreateFrame("Frame","QuestieOctoWorldTooltipWatcher",GameTooltip)
    watcher:SetScript("OnShow",function()
      T:AugmentWorldTooltip()
    end)
    self.worldWatcher=watcher
  end

  if QuestieOcto.Nodes and QuestieOcto.Nodes.ready then self:RebuildHoverIndex() end
end

QuestieOcto:RegisterMessage("NODES_READY",T,"ScheduleHoverIndex")
QuestieOcto:RegisterMessage("NODES_CHANGED",T,"ScheduleHoverIndex")

function T:Show(pin)
  if not pin then return end
  pin.questieOctoTooltipPin=true

  local tooltip=MapTooltip(pin)
  if not tooltip then return end

  local permanentLabels={
    flightMaster="Flight Master",
    auctioneer="Auctioneer",
    banker="Banker",
    mailbox="Mailbox",
    battlemaster="Battlemaster",
    innkeeper="Innkeeper",
    meetingStone="Meeting Stone",
    repair="Repair",
    spiritHealer="Spirit Healer",
    stableMaster="Stable Master",
    vendor="Vendor",
    rareMob="[Rare]"
  }
  local permanentLabel=permanentLabels[pin.role]
  if permanentLabel then
    tooltip:SetOwner(pin,"ANCHOR_CURSOR")
    tooltip:ClearLines()
    ResetCenteredTildes(tooltip)
    local title=pin.displayName or permanentLabel
    if pin.role=="rareMob" then
      tooltip:SetText(tostring(title),1,.82,0)
      local level=nil
      local respawnSeconds=nil
      for _,entry in pairs(pin.entries or {}) do
        if entry.node and entry.node.role=="rareMob" then
          level=entry.node.rareLevel
          respawnSeconds=entry.node.respawnSeconds
          break
        end
      end
      if level then
        tooltip:AddLine("[Rare] - Level "..tostring(level),1,.82,0)
      else
        tooltip:AddLine("[Rare]",1,.82,0)
      end
      local respawn=RespawnText(respawnSeconds)
      if respawn then
        AddCenteredTildeLine(tooltip,"Respawn: ",respawn,.75,.75,.75)
      end
    else
      tooltip:SetText(tostring(title),.2,1,.35)
      tooltip:AddLine(permanentLabel,1,.82,0)
    end
    tooltip:Show()
    FinalizeCenteredTildes(tooltip)
    return
  end

  if not Settings():Get("enableTooltips") then return end

  if pin:GetParent()==WorldMapButton and
     QuestieOcto.Map and QuestieOcto.Map.GetNearbyQuestTooltipPins then
    local nearby=QuestieOcto.Map:GetNearbyQuestTooltipPins(pin,5)
    if pin.fullNode then
      local related=SemanticallyRelatedNearbyFullNodePins(pin,nearby)
      if table.getn(related)>1 then
        ShowCombinedNearbyFullNodeTooltip(pin,related)
        return
      end
    elseif table.getn(nearby)>1 then
      -- Clustered/item-start presentation keeps its established behavior.
      ShowCombinedNearbyQuestTooltip(pin,nearby)
      return
    end
  end

  tooltip:SetOwner(pin,"ANCHOR_CURSOR")
  tooltip:ClearLines()
  ResetCenteredTildes(tooltip)

  if pin.itemStartArea then
    local area=pin.itemStartArea

    if area.zoneWideRare then
      -- A zone-wide representative exists specifically to make enormous
      -- world-drop source sets readable. Do not undo that simplification by
      -- dumping every represented creature into the tooltip (Pendant of
      -- Myzrael can have dozens of source types in a single zone). Keep the
      -- full source list in the data and present only a compact aggregate.
      local sourceCount=table.getn(area.sourceList or {})
      local spawnCount=tonumber(area.n) or 0
      tooltip:SetText("Rare item-start sources",.2,1,.35)
      tooltip:AddLine(
        tostring(sourceCount).." creature types, "..tostring(spawnCount).." zone spawns",
        .65,.65,.65
      )
    else
      -- Ordinary clustered item-start areas still list their nearby sources.
      -- Use AddDoubleLine with an empty right column for every source row so
      -- the first source does not inherit the tooltip's title-sized font.
      for _,source in pairs(area.sourceList or {}) do
        local sourceText=SourceDisplayName(source).." ("..tostring(source.count).." nearby spawns)"
        tooltip:AddDoubleLine(
          sourceText,
          "",
          .2,1,.35,
          .2,1,.35
        )

        local rank=RareRankText(source.rank)
        local respawn=rank and RespawnText(source.respawnSeconds) or nil
        if respawn then
          local rareTag=RareRankText(source.rank) or "Rare"
          AddCenteredTildeLine(tooltip,"["..rareTag.."] Respawn: ",respawn,.75,.75,.75)
        end
      end
    end

    local q=QuestieOcto.QuestModel:Get(area.questID)
    if q then
      local r,g,b=DifficultyColor(q.level,q.id)
      tooltip:AddDoubleLine(
        QuestTitle(q),
        "(Available)",
        r,g,b,
        1,.82,0
      )
    end

    local dropRateText,dropRateMaxText=ItemStartAreaDropRateText(area)

    local itemLabel=tostring(area.itemName or ("Item "..tostring(area.itemID)))
    if Settings():Get("enableTooltipsItemID") and area.itemID then
      itemLabel=itemLabel.." (Item "..tostring(area.itemID)..")"
    end
    local line="Drops ["..itemLabel.."]"
    if dropRateText and Settings():Get("enableTooltipDroprates") then
      if dropRateMaxText then
        AddCenteredTildeLine(
          tooltip,
          line.." ("..dropRateText,
          dropRateMaxText..") - item starts quest",
          .82,.82,.82,true,true
        )
        line=nil
      else
        line=line.." ("..dropRateText..")"
      end
    end
    if line then tooltip:AddLine(line.." - item starts quest",.82,.82,.82,true) end

    if not area.zoneWideRare then NormalizeFirstRowFont(tooltip) end
    tooltip:Show()
    FinalizeCenteredTildes(tooltip)
    return
  end

  if not pin.entries then return end

  local title=QuestSourceTitle(pin)
  if pin.clusterCount and pin.clusterCount>1 then
    title=title.." |cffaaaaaa("..tostring(pin.clusterCount).." nearby spawns)|r"
  end
  tooltip:SetText(title,.2,1,.35)

  AddSourceIDLine(pin,tooltip)
  AddRareSourceRespawn(pin,tooltip)
  if pin.fullNode then
    AddFullNodeQuestEntries({pin},tooltip)
  else
    AddQuestEntries(pin,{},tooltip)
  end

  tooltip:Show()
  FinalizeCenteredTildes(tooltip)
end

