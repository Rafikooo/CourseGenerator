--- Vertex of a polyline or a polygon. Besides the coordinates (as a Vector) it holds
--- all kinds of other information in the line/polygon context.

local Vertex = CpObject(cg.Vector)

function Vertex:init(x, y, ix)
    cg.Vector.init(self, x, y)
    self.ix = ix or 0
end

function Vertex:clone()
    local v = Vertex(self.x, self.y)
    v.entryHeading = self:getEntryHeading()
    v.exitHeading = self:getExitHeading()
    v.entryEdge = self.entryEdge and self.entryEdge:clone()
    v.exitEdge = self.exitEdge and self.exitEdge:clone()
    v.unitRadius = self.unitRadius
    v.d = self.d
    return v
end

function Vertex:getEntryEdge()
    return self.entryEdge
end

function Vertex:getEntryHeading()
    return self.entryHeading
end

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
function Vertex:getRadius()
    return self.unitRadius * (self.exitEdge and self.exitEdge:getLength() or math.huge)
end


---@return number distance from the first vertex
function Vertex:getDistance()
    return self.d
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
    -- This is the radius of the unit circle written between
    -- entryEdge and exitEdge, which are tangents of the circle
    local dA = cg.Math.getDeltaAngle(self.entryHeading, self.exitHeading)
    self.unitRadius = 1 / (2 * math.sin(dA / 2))
    self.curvature = 1 / self.unitRadius
end

---@class cg.Vertex:cg.Vector
cg.Vertex = Vertex