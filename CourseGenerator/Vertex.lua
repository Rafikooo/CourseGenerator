--- Vertex of a polyline or a polygon. Besides the coordinates (as a Vector) it holds
--- all kinds of other information in the line/polygon context.

local Vertex = CpObject(cg.Vector)

function Vertex:init(x, y, ix)
    cg.Vector.init(self, x, y)
    self.ix = ix or 0
    --- public properties (wish lua was a proper language...)
    --- This is a corner vertex, and should remain a sharp corner
    self.isCorner = nil
    --- This is a vertex leading to a corner (there could be a few)
    self.isCornerLead = nil
    --- This is a vertex after a corner (there could be a few)
    self.isCornerTail = nil
    --- Delta angle at this vertex, angle between the entry and exit edges
    self.dA = nil
    self.attributes = cg.WaypointAttributes()
end

function Vertex.fromVector(v, ix)
    return Vertex(v.x, v.y, ix)
end

function Vertex:set(x, y, ix)
    self.x = x
    self.y = y
    self.ix = ix or 0
end

--- Clone the vertex, meaning to create a copy with all the non-calculated properties (which make sense
--- only within the polyline/polygon context)
function Vertex:clone()
    local v = Vertex(self.x, self.y)
    v.isCorner = self.isCorner
    v.isCornerLead = self.isCornerLead
    v.isCornerTail = self.isCornerTail
    v.oldIx = self.oldIx
    v.attributes = self.attributes:clone()
    return v
end

---@return cg.LineSegment
function Vertex:getEntryEdge()
    return self.entryEdge
end

function Vertex:getEntryHeading()
    return self.entryHeading
end

---@return cg.LineSegment
function Vertex:getExitEdge()
    return self.exitEdge
end

function Vertex:getExitHeading()
    return self.exitHeading
end

--- The radius at this vertex, calculated from the direction of the entry/exit edges as unit vectors.
--- Positive values are left turns, negative values right turns
---@return number radius
function Vertex:getUnitRadius()
    return self.unitRadius
end

--- The radius at this vertex, calculated from the direction of the entry/exit edges and the length of
--- the exit edge. This is the radius a vehicle would need to drive to reach the next waypoint.
--- Positive values are left turns, negative values right turns
---@return number radius
function Vertex:getSignedRadius()
    return self.unitRadius * (self.exitEdge and self.exitEdge:getLength() or math.huge)
end

function Vertex:getRadius()
    return math.abs(self:getSignedRadius())
end

--- cross track error for a unit circle. This is how far away a unit circle drawn
--- between the entry and exit edges would be from the vertex along the line between the
--- circle's center and the vertex. We use this to decide if we can make this turn
---@param r number to use, default 1
---@return number cross track error with radius 1, multiply with
function Vertex:getXte(r)
    return self.xte * (r or 1)
end

---@return number distance from the first vertex
function Vertex:getDistance()
    return self.d
end

---@return cg.WaypointAttributes
function Vertex:getAttributes()
    return self.attributes
end

--- Add info related to the neighbouring vertices
---@param entry cg.Vertex the previous vertex in the polyline/polygon
---@param exit cg.Vertex the next vertex in the polyline/polygon
function Vertex:calculateProperties(entry, exit)
    if entry then
        self.entryEdge = cg.LineSegment.fromVectors(entry, self)
        self.entryHeading = self.entryEdge:getHeading()
        self.d = (entry.d or 0) + self.entryEdge:getLength()
    else
        -- first vertex
        self.d = 0
    end
    if exit then
        self.exitEdge = cg.LineSegment.fromVectors(self, exit)
        self.exitHeading = self.exitEdge:getHeading()
    end

    -- if there is no previous vertex, use the exit heading
    if not self.entryHeading then
        self.entryHeading = self.exitHeading
    end

    -- if there is no next vertex, use the entry heading (one of exit/entry must be given)
    if not self.exitHeading then
        self.exitHeading = self.entryHeading
    end
    if self.entryHeading and self.exitHeading then
        -- This is the radius of the unit circle written between
        -- entryEdge and exitEdge, which are tangents of the circle
        self.dA = cg.Math.getDeltaAngle(self.entryHeading, self.exitHeading)
        self.unitRadius = 1 / (2 * math.sin(self.dA / 2))
        self.curvature = 1 / self.unitRadius
        self.xte = math.abs(1 / math.cos(self.dA / 2)) - 1
    end
end

function Vertex:__tostring()
    return cg.Vector.__tostring(self) .. ' ' .. self.attributes:__tostring()
end

---@class cg.Vertex:cg.Vector
cg.Vertex = Vertex