--- A container to hold waypoint and fieldwork related attributes
--- for a vertex.
--- These attributes contain information to help the vehicle navigate the course, while
--- the vertex is strictly a geometric concept.
local WaypointAttributes = CpObject()

function WaypointAttributes:clone()
    local a = cg.WaypointAttributes()
    for attribute, value in pairs(self) do
        a[attribute] = value
    end
    return a
end

function WaypointAttributes:setIslandBypass()
    self.islandBypass = true
end

function WaypointAttributes:isIslandBypass()
    return self.islandBypass
end

function WaypointAttributes:setHeadlandTransition()
    self.headlandTransition = true
end

function WaypointAttributes:isHeadlandTransition()
    return self.headlandTransition
end

function WaypointAttributes:setHeadlandPassNumber(n)
    self.headlandPassNumber = n
end

---@return number | nil number of the headland, starting at 1 on the outermost headland. The section leading
--- to the next headland (isHeadlandTransition() == true) has the same pass number as the headland where the
--- section starts (transition from 1 -> 2 has pass number 1)
function WaypointAttributes:getHeadlandPassNumber()
    return self.headlandPassNumber
end

function WaypointAttributes:setBlockNumber(n)
    self.blockNumber = n
end

function WaypointAttributes:getBlockNumber()
    return self.blockNumber
end

function WaypointAttributes:setRowNumber(n)
    self.rowNumber = n
end

function WaypointAttributes:getRowNumber()
    return self.rowNumber
end

---@return boolean true if this is the last waypoint of an up/down row. It is either time to switch to the next
--- row (by starting a turn) of the same block, the first row of the next block, or, to the headland if we
--- started working on the center of the field
function WaypointAttributes:setRowEnd()
    self.rowEnd = true
end

function WaypointAttributes:isRowEnd()
    return self.rowEnd
end

function WaypointAttributes:setRowStart()
    self.rowStart = true
end

---@return boolean true if this is the first waypoint of an up/down row.
function WaypointAttributes:isRowStart()
    return self.rowStart
end

function WaypointAttributes:__tostring()
    local str = '[ '
    for attribute, value in pairs(self) do
        str = str .. string.format('%s: %s ', attribute, value)
    end
    str = str .. ']'
    return str
end

---@class cg.WaypointAttributes
cg.WaypointAttributes = WaypointAttributes