QuestieOcto.Visuals = QuestieOcto.Visuals or {}
local V = QuestieOcto.Visuals

local ICON_ROOT="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\"
local TEX_GLOW=ICON_ROOT.."glow"

local function Settings()
  return QuestieOcto.MinimapSettings
end

local hashColorCache={}
local questPaletteCache={}

local function HashColor(text)
  text=tostring(text or "")
  local cached=hashColorCache[text]
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

  hashColorCache[text]={r,g,b}
  return r,g,b
end

-- Quest IDs created together are commonly sequential. Feeding their decimal
-- strings directly into the old pfQuest-style RGB hash kept the leading bytes
-- identical, which made batches such as Grim Reaches collapse into near-copy
-- purple/pink/blue colors. Use the numeric quest ID as the stable identity and
-- spread adjacent IDs around the hue wheel with a bitless integer permutation.
-- 65521 is prime and 40494/65521 is a close rational approximation of the
-- golden-ratio conjugate, so neighboring IDs are deliberately far apart. A
-- later per-quest tie-break handles distant rational returns of this sequence.
local function HSVToRGB(h,s,v)
  h=math.mod(tonumber(h) or 0,1)
  s=tonumber(s) or 0
  v=tonumber(v) or 0

  local scaled=h*6
  local sector=math.floor(scaled)
  local f=scaled-sector
  local p=v*(1-s)
  local q=v*(1-s*f)
  local t=v*(1-s*(1-f))
  sector=math.mod(sector,6)

  if sector==0 then return v,t,p end
  if sector==1 then return q,v,p end
  if sector==2 then return p,v,t end
  if sector==3 then return p,q,v end
  if sector==4 then return t,p,v end
  return v,p,q
end

local function Clamp01(v)
  if v<0 then return 0 end
  if v>1 then return 1 end
  return v
end

local function QuestPaletteTieBreak(id,r,g,b)
  -- Keep the 1.12 hue/saturation/value palette visually intact, but give each
  -- quest a tiny independent RGB signature. The old secondary bands repeat
  -- every 30 IDs and the hue sequence has close rational returns, so some
  -- distant quest IDs could quantize to the exact same visible RGB value even
  -- though their full-precision HSV values differed. The independent 65519
  -- modular sequence changes each channel by at most two 8-bit steps.
  local tone=math.mod(id*26367,65519)
  local rStep=math.mod(tone,5)-2
  local gStep=math.mod(math.floor(tone/5),5)-2
  local bStep=math.mod(math.floor(tone/25),5)-2
  return Clamp01(r+rStep/255),Clamp01(g+gStep/255),Clamp01(b+bStep/255)
end

local function AccessibilityTieBreak(id,r,g,b)
  -- Accessibility remaps can collapse different base colors onto one display
  -- RGB value after dark-color lifting and 8-bit output. A second, smaller
  -- independent signature preserves map-local separation without changing the
  -- character of the selected accessibility palette.
  local tone=math.mod(id*58788,65519)
  local rStep=math.mod(tone,5)-2
  local gStep=math.mod(math.floor(tone/5),5)-2
  local bStep=math.mod(math.floor(tone/25),5)-2
  return Clamp01(r+rStep/510),Clamp01(g+gStep/510),Clamp01(b+bStep/510)
end

local function QuestPaletteColor(questID)
  local id=tonumber(questID) or 0
  id=math.floor(id)

  local cached=questPaletteCache[id]
  if cached then return cached[1],cached[2],cached[3] end

  local hueIndex=math.mod(id*40494,65521)
  local hue=hueIndex/65521

  -- Small deterministic saturation/value bands add a second visual cue when
  -- two non-neighboring IDs happen to land near one another on the hue wheel,
  -- while keeping Full Nodes bright enough for dark World Map backgrounds.
  local saturation=0.72+0.04*math.mod(id*17+3,6)
  local value=0.88+0.03*math.mod(id*23+1,5)
  local r,g,b=HSVToRGB(hue,saturation,value)
  r,g,b=QuestPaletteTieBreak(id,r,g,b)

  questPaletteCache[id]={r,g,b}
  return r,g,b
end

-- Accessibility modes are deliberate color remaps, not simulations. The
-- deterministic quest palette remains the identity source, so every quest keeps
-- one stable color across map surfaces. The remaps route channel differences
-- toward combinations intended for the selected color-vision family, then
-- gently lift only very dark results.
local function LiftDarkColor(r,g,b)
  -- Simple sRGB luma is sufficient here: this is a tiny presentation guard,
  -- not a contrast claim against every possible World Map background.
  local y=0.299*r+0.587*g+0.114*b
  if y>=0.37 then return r,g,b end
  if y>=1 then return r,g,b end

  local t=(0.37-y)/(1-y)
  return r+(1-r)*t,g+(1-g)*t,b+(1-b)*t
end

local function AccessibleQuestColor(mode,r,g,b)
  if mode=="protan" then
    -- Red-deficient: preserve wide variation by moving the original channels
    -- onto a blue/yellow-friendly ordering and inverting the two ambiguous
    -- channels. Offline severe-protan validation selected this mapping.
    r,g,b=b,1-g,1-r
  elseif mode=="deutan" then
    -- Green-deficient: rotate red into blue while retaining green directly.
    r,g,b=b,g,r
  elseif mode=="tritan" then
    -- Blue-deficient: move the original blue/red information onto the
    -- red/green-visible axes and invert the remaining green component.
    r,g,b=b,r,1-g
  elseif mode=="highContrast" then
    -- General high-contrast mode keeps the full deterministic variety while
    -- separating the original channels from the Default ordering.
    r,g,b=r,b,1-g
  else
    return r,g,b
  end

  return LiftDarkColor(r,g,b)
end

function V:GetQuestColor(questID)
  local id=math.floor(tonumber(questID) or 0)
  local r,g,b=QuestPaletteColor(id)
  local mode=Settings() and Settings():Get("objectiveColorVisionMode") or "default"
  if mode=="default" then return r,g,b end
  r,g,b=AccessibleQuestColor(mode,r,g,b)
  return AccessibilityTieBreak(id,r,g,b)
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
