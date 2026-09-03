QuestieOcto.Visuals = QuestieOcto.Visuals or {}
local V = QuestieOcto.Visuals

local ICON_ROOT="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\"
local TEX_GLOW=ICON_ROOT.."glow"

local function Settings()
  return QuestieOcto.MinimapSettings
end

local questColorCache={}

local function HashColor(text)
  text=tostring(text or "")
  local cached=questColorCache[text]
  if cached then return cached[1],cached[2],cached[3] end

  -- pfQuest-style full-range deterministic RGB hash. Questie-Octo keys this
  -- from the numeric quest ID rather than the localized quest title, so the
  -- same quest keeps the same color on every client language.
  local counter=1
  local length=string.len(text)
  local i
  for i=1,length,3 do
    counter=math.mod(counter*8161,4294967279)
      +(string.byte(text,i)*16776193)
      +((string.byte(text,i+1) or (length-i+256))*8372226)
      +((string.byte(text,i+2) or (length-i+256))*3932164)
  end

  local hash=math.mod(math.mod(counter,4294967291),16777216)
  local r=(hash-math.mod(hash,65536))/65536
  local remainder=hash-r*65536
  local g=(remainder-math.mod(remainder,256))/256
  local b=remainder-g*256
  r,g,b=r/255,g/255,b/255

  questColorCache[text]={r,g,b}
  return r,g,b
end

function V:GetQuestColor(questID)
  return HashColor("quest"..tostring(tonumber(questID) or 0))
end

function V:GetObjectiveColor(questID,objectiveIndex)
  -- Retained for compatibility with older internal callers. Current objective
  -- presentation intentionally uses GetQuestColor so one quest = one color.
  return HashColor("objective"..tostring(tonumber(questID) or 0)..":"..tostring(tonumber(objectiveIndex) or 0))
end

function V:IsObjectiveRole(role)
  return role=="objectiveCreature" or role=="objectiveObject" or role=="objectiveItemSource"
end

function V:EnsureGlow(pin)
  if not pin or pin.glowTexture then return end

  -- Questie 3.3.5 compatibility bridge:
  -- glow = same icon frame, ARTWORK sublevel -1
  -- icon = same icon frame, OVERLAY
  local tex=pin:CreateTexture(nil,"ARTWORK")
  if tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK",-1) end
  tex:SetTexture(TEX_GLOW)
  tex:SetWidth(18)
  tex:SetHeight(18)
  tex:SetPoint("CENTER",pin,"CENTER",0,0)
  tex:Hide()
  pin.glowTexture=tex
end

function V:ResizeGlow(pin)
  if not pin or not pin.glowTexture then return end
  local width=pin:GetWidth() or 16
  local height=pin:GetHeight() or 16
  pin.glowTexture:SetWidth(width*1.13)
  pin.glowTexture:SetHeight(height*1.13)
  pin.glowTexture:ClearAllPoints()
  pin.glowTexture:SetPoint("CENTER",pin,"CENTER",0,0)
end

function V:ClearPin(pin,alpha)
  if not pin then return end
  alpha=tonumber(alpha) or 1
  pin.iconR,pin.iconG,pin.iconB=1,1,1
  pin.glowR,pin.glowG,pin.glowB=1,1,1
  if pin.texture then pin.texture:SetVertexColor(1,1,1,alpha) end
  if pin.glowTexture then pin.glowTexture:Hide() end
end

function V:ApplyPin(pin,node,isMinimap,alpha)
  if not pin or not node then return end
  alpha=tonumber(alpha) or 1

  self:EnsureGlow(pin)

  local objective=self:IsObjectiveRole(node.role)
  local colorEnabled
  local glowEnabled

  if isMinimap then
    colorEnabled=Settings():Get("questMinimapObjectiveColors") and true or false
    glowEnabled=Settings():Get("alwaysGlowMinimap") and true or false
  else
    colorEnabled=Settings():Get("questObjectiveColors") and true or false
    glowEnabled=Settings():Get("alwaysGlowMap") and true or false
  end

  local r,g,b=1,1,1
  -- Quest pickup/turn-in presentation priority is PvP > Repeatable > Event >
  -- Turtle low-level gray > Normal. Gray uses dedicated artwork like the other
  -- quest-start variants; objective tinting never recolors pickup/turn-in icons.
  if (node.pvp or node.repeatable) and (node.role=="available" or node.role=="itemStart" or node.role=="turnin") then
    r,g,b=1,1,1
  elseif objective and colorEnabled then
    r,g,b=self:GetQuestColor(node.questID)
  end
  pin.iconR,pin.iconG,pin.iconB=r,g,b
  if pin.texture then pin.texture:SetVertexColor(r,g,b,alpha) end

  if objective and glowEnabled and pin.glowTexture then
    -- Clustered glow/contour follows the quest color too: one quest keeps
    -- one stable color across every objective, on map and minimap.
    local gr,gg,gb=self:GetQuestColor(node.questID)
    pin.glowR,pin.glowG,pin.glowB=gr,gg,gb
    pin.glowTexture:SetVertexColor(gr,gg,gb,alpha)
    self:ResizeGlow(pin)
    pin.glowTexture:Show()
  elseif pin.glowTexture then
    pin.glowTexture:Hide()
  end
end


function V:ApplyFullNode(pin,node,isMinimap,alpha)
  if not pin or not node or not pin.texture then return end
  -- pfQuest's ordinary spawn nodes are deliberately compact and subdued.
  -- Full Nodes use pfQuest's native 14px baseline and 15% transparency;
  -- the user's only size control is the global map/minimap scale.
  alpha=(tonumber(alpha) or 1)*0.85
  -- Full Nodes use the same wide per-quest color directly. Do not darken
  -- it again: pfQuest already relies on alpha/texture shape for subduing the
  -- node, and multiplying the wider palette would make dark colors vanish.
  local r,g,b=self:GetQuestColor(node.questID)
  pin.iconR,pin.iconG,pin.iconB=r,g,b
  pin.texture:SetTexture("Interface\\AddOns\\Questie-Octo\\UI\\Icons\\pfquest_node")
  pin.texture:SetVertexColor(r,g,b,alpha)
  if pin.glowTexture then pin.glowTexture:Hide() end
  pin.fullNode=true
  pin.fullNodeNode=node
end

function V:SetAlpha(pin,alpha)
  if not pin then return end
  alpha=tonumber(alpha) or 1
  if pin.fullNode then alpha=alpha*0.85 end
  if alpha<0 then alpha=0 end
  if alpha>1 then alpha=1 end

  if pin.texture then
    pin.texture:SetVertexColor(pin.iconR or 1,pin.iconG or 1,pin.iconB or 1,alpha)
  end
  if pin.glowTexture and pin.glowTexture:IsShown() then
    pin.glowTexture:SetVertexColor(pin.glowR or 1,pin.glowG or 1,pin.glowB or 1,alpha)
  end
end
