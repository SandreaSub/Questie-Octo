-- Questie-Octo item-start geographic aggregation.
--
-- Item-start quests are presented as one marker per meaningful hunting area,
-- even when several different creature IDs can drop the same starter item.
-- Active quest objectives are NOT affected by this layer.

QuestieOcto.ItemStartAreas = QuestieOcto.ItemStartAreas or {}
local A = QuestieOcto.ItemStartAreas

A.radius=14.0
A.zoneWideRareThreshold=1.0

function A:IsZoneWideRareChance(chance)
  chance=tonumber(chance) or 0
  return chance>0 and chance<A.zoneWideRareThreshold
end

local function Distance(x1,y1,x2,y2)
  local dx=x1-x2
  local dy=y1-y2
  return math.sqrt(dx*dx+dy*dy)
end

local function AddPointToArea(area,point)
  area.sx=area.sx+point.x
  area.sy=area.sy+point.y
  area.n=area.n+1

  local source=area.sources[point.sourceID]
  if not source then
    source={
      id=point.sourceID,
      name=point.sourceName,
      count=0,
      chance=point.chance,
      rank=point.sourceRank,
      respawnSeconds=point.respawnSeconds
    }
    area.sources[point.sourceID]=source
  end
  source.count=source.count+1

  if point.x<area.anchorX or (point.x==area.anchorX and point.y<area.anchorY) then
    area.anchorX=point.x
    area.anchorY=point.y
  end
end

local function NewArea(point)
  local area={
    sx=0,
    sy=0,
    n=0,
    sources={},
    anchorX=point.x,
    anchorY=point.y
  }
  AddPointToArea(area,point)
  return area
end

local function SortPoints(points)
  table.sort(points,function(a,b)
    if a.x==b.x then
      if a.y==b.y then return tostring(a.sourceID)<tostring(b.sourceID) end
      return a.y<b.y
    end
    return a.x<b.x
  end)
end

local function SortSources(area)
  local result={}
  for _,source in pairs(area.sources) do
    table.insert(result,source)
  end

  table.sort(result,function(a,b)
    if a.count==b.count then return tostring(a.name)<tostring(b.name) end
    return a.count>b.count
  end)

  return result
end

function A:BuildForMap(nodes,mapID,includeNode,pointContext)
  local groups={}

  -- Group by quest + starter item first. Different starter quests never merge.
  for _,node in pairs(nodes or {}) do
    if node.role=="itemStart" and tonumber(node.itemID) and node.coords
       and (not includeNode or includeNode(node)) then
      for _,coord in pairs(node.coords) do
        if type(coord)=="table" and tonumber(coord[3])==tonumber(mapID) then
          local x=tonumber(coord[1])
          local y=tonumber(coord[2])

          if x and y then
            local preparedMapContext=pointContext and pointContext(node,x,y) or nil
            if not pointContext or preparedMapContext then
              local groupKey=tostring(node.questID)..":"..tostring(node.itemID)
              if preparedMapContext then
                groupKey=groupKey..":context:"..tostring(preparedMapContext)
              end
              local group=groups[groupKey]

              if not group then
                group={
                  questID=node.questID,
                  itemID=node.itemID,
                  itemName=node.itemName,
                  preparedMapContext=preparedMapContext,
                  points={}
                }
                groups[groupKey]=group
              end

              table.insert(group.points,{
                x=x,
                y=y,
                sourceID=node.sourceID,
                sourceName=node.sourceName,
                sourceRank=node.sourceRank,
                respawnSeconds=node.respawnSeconds,
                chance=node.chance
              })
            end
          end
        end
      end
    end
  end

  local result={}

  for _,group in pairs(groups) do
    SortPoints(group.points)
    local areas={}

    -- Greedy geographic clustering around the evolving area centroid.
    -- This intentionally merges different mob types only when they truly share
    -- a hunting area. A mob population on the other side of the zone remains
    -- a separate marker.
    for _,point in pairs(group.points) do
      local best=nil
      local bestDistance=nil

      for _,area in pairs(areas) do
        local cx=area.sx/area.n
        local cy=area.sy/area.n
        local d=Distance(point.x,point.y,cx,cy)

        if d<=A.radius and (not bestDistance or d<bestDistance) then
          best=area
          bestDistance=d
        end
      end

      if best then
        AddPointToArea(best,point)
      else
        table.insert(areas,NewArea(point))
      end
    end

    for _,area in pairs(areas) do
      area.x=area.sx/area.n
      area.y=area.sy/area.n
      area.questID=group.questID
      area.itemID=group.itemID
      area.itemName=group.itemName
      area.sourceList=SortSources(area)
      area.preparedMapContext=group.preparedMapContext
      area.key=tostring(group.questID)..":"..tostring(group.itemID)..":"..
        string.format("%.1f",area.anchorX)..":"..string.format("%.1f",area.anchorY)
      if area.preparedMapContext then
        area.key=area.key..":context:"..tostring(area.preparedMapContext)
      end

      -- Use the first/largest source as the display-name fallback.
      local first=area.sourceList[1]
      area.displayName=first and first.name or "Quest item source"

      table.insert(result,area)
    end
  end

  table.sort(result,function(a,b)
    if a.questID~=b.questID then return a.questID<b.questID end
    if a.x==b.x then return a.y<b.y end
    return a.x<b.x
  end)

  return result
end


-- Shared zone-wide presentation helper for extremely low-rate starter items.
-- These drops are often spread across many unrelated creatures throughout a
-- zone. Keep every source in the underlying data, but represent all <1.00%
-- sources for the same quest/item with one zone marker on Map and Minimap.
function A:BuildZoneWideRareForMap(nodes,mapID,pointContext)
  local groups={}

  for _,node in pairs(nodes or {}) do
    if node.role=="itemStart" and tonumber(node.itemID) and node.coords
       and self:IsZoneWideRareChance(node.chance) then
      for _,coord in pairs(node.coords) do
        if type(coord)=="table" and tonumber(coord[3])==tonumber(mapID) then
          local x=tonumber(coord[1])
          local y=tonumber(coord[2])
          if x and y then
            local preparedMapContext=pointContext and pointContext(node,x,y) or nil
            if not pointContext or preparedMapContext then
              local groupKey=tostring(node.questID)..":"..tostring(node.itemID)
              if preparedMapContext then
                groupKey=groupKey..":context:"..tostring(preparedMapContext)
              end
              local group=groups[groupKey]
              if not group then
                group={
                  questID=node.questID,
                  itemID=node.itemID,
                  itemName=node.itemName,
                  preparedMapContext=preparedMapContext,
                  points={}
                }
                groups[groupKey]=group
              end

              table.insert(group.points,{
                x=x,
                y=y,
                sourceID=node.sourceID,
                sourceName=node.sourceName,
                sourceRank=node.sourceRank,
                respawnSeconds=node.respawnSeconds,
                chance=node.chance
              })
            end
          end
        end
      end
    end
  end

  local result={}
  for _,group in pairs(groups) do
    if table.getn(group.points)>0 then
      SortPoints(group.points)
      local area=NewArea(group.points[1])
      local i
      for i=2,table.getn(group.points) do AddPointToArea(area,group.points[i]) end

      local cx=area.sx/area.n
      local cy=area.sy/area.n
      local best=group.points[1]
      local bestDistance=Distance(best.x,best.y,cx,cy)
      for _,point in pairs(group.points) do
        local d=Distance(point.x,point.y,cx,cy)
        if d<bestDistance then best=point; bestDistance=d end
      end

      -- Keep the marker on a real source coordinate rather than an arbitrary
      -- geometric centroid, while still choosing a representative central point.
      area.x=best.x
      area.y=best.y
      area.questID=group.questID
      area.itemID=group.itemID
      area.itemName=group.itemName
      area.sourceList=SortSources(area)
      area.preparedMapContext=group.preparedMapContext
      area.zoneWideRare=true
      area.rareThreshold=self.zoneWideRareThreshold
      area.key=tostring(group.questID)..":"..tostring(group.itemID)..":zone-rare:"..tostring(mapID)
      if area.preparedMapContext then
        area.key=area.key..":context:"..tostring(area.preparedMapContext)
      end

      local first=area.sourceList[1]
      area.displayName=first and first.name or "Rare item-start source"
      table.insert(result,area)
    end
  end

  table.sort(result,function(a,b)
    if a.questID~=b.questID then return a.questID<b.questID end
    return tonumber(a.itemID or 0)<tonumber(b.itemID or 0)
  end)

  return result
end
