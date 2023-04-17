local Polygon = CpObject(cg.Polyline)

function Polygon:init(vertices)
    cg.Polyline.init(self, vertices)
    self.logger = cg.Logger('Polygon', cg.Logger.level.debug)
end

function Polygon:clone()
    local clone = Polygon({})
    for _, v in ipairs(self) do
        clone:append(v:clone())
    end
    clone:calculateProperties()
    return clone
end

--- Rebase the polygon so that vertex at index 'base' becomes the first vertex
---@param base number the index where the polygon should start
---@param reverse boolean reverse the order of vertices after rebasing, that is,
--- convert between clockwise and counterclockwise
function Polygon:rebase(base, reverse)
    local temp = {}
    for i = 0, #self - 1 do
        table.insert(temp, self:at(i + base))
        -- preserve old index for debugs
        temp[#temp].oldIx = temp[#temp].ix
    end

    for i = 1, #self do
        if reverse then
            self:set(2 - i, temp[i])
        else
            self[i] = temp[i]
        end
    end
    self:calculateProperties()
end

function Polygon:getRawIndex(n)
    -- whoever came up with the idea of 1 based indexing in lua, was terribly wrong,
    -- so for now we just wrap around once so we don't need a division
    if n > #self then
        return n - #self
    elseif n < 1 then
        return n + #self
    else
        return n
    end
end

--- Upper limit when iterating through the vertices, starting with 1 to fwdIterationLimit() (inclusive)
--- using i and i + 1 vertex in the loop. This will wrap around the end to make sure the polygon is closed.
function Polygon:fwdIterationLimit()
    return #self
end

--- Vertex iterator. If no end index (to) given, it'll wrap around until it reaches from again. Examples with
--- a 5 vertex polygon, first and last current vertex returned, depending on from, to:
--- (nil, nil) -> 1, 2, 3, 4, 5
--- (  3, nil) -> 3, 4, 5, 1, 2
--- (  3,   1) -> 3, 4, 5, 1
--- (  1,   3) -> 1, 2, 3
---@param from number index of first vertex
---@param to number index of last vertex
---@param step number step (1 or -1 only), direction of iteration
---@return number, cg.Vertex, cg.Vertex, cg.Vertex the index, the vertex at index, the previous, and the next vertex.
--- previous and next may be nil
function Polygon:vertices(from, to, step)
    step = (step == nil or step > 0) and 1 or -1
    local i, stop
    if step > 0 then
        i = cg.WrapAroundIndex(self, (from or 1) - 1)
        -- if there is a start index and no end given, we stop after we wrapped around, that is,
        -- we are again at the starting point. If there is no start index (from) given, then we
        -- start at 1 and stop at 1 after wrapping around the end
        stop = cg.WrapAroundIndex(self, (to and (to + 1) or (from or 1)))
    else
        i = cg.WrapAroundIndex(self, (from or #self) + 1)
        stop = cg.WrapAroundIndex(self, (to and (to - 1) or (from or #self)))
    end
    local firstIteration = true
    return function()
        i:inc(step or 1)
        -- since we may wrap around the end, we must check for equality (not > or <)
        if (i:get() == stop:get() and not firstIteration) or #self == 0 then
            return nil, nil, nil, nil
        else
            firstIteration = false
            local ix = i:get()
            return ix, self:at(ix), self:at(ix - 1), self:at(ix + 1)
        end
    end
end

--- edge iterator, will wrap through the end to close the polygon
---@return number, cg.LineSegment, cg.Vertex
function Polygon:edges(startIx)
    local i = startIx and startIx - 1 or 0
    return function()
        i = i + 1
        if i > #self then
            return nil, nil
        else
            return i, cg.LineSegment.fromVectors(self[i], self[(i + 1) > #self and 1 or i + 1]), self[i]
        end
    end
end

--- edge iterator backwards
---@return number, cg.LineSegment, cg.Vertex
function Polygon:edgesBackwards(startIx)
    local i = startIx and (startIx + 1) or (#self + 1)
    return function()
        i = i - 1
        if i <= 2 then
            return nil, nil
        else
            return i, cg.LineSegment.fromVectors(self[i], self[(i - 1) < 1 and #self or (i - 1)]), self[i]
        end
    end
end

--- Is a point at (x, y) inside of the polygon?
--- We use Dan Sunday's algorithm and his convention that a point
--- on a left or bottom edge is inside, and a point on a right or top edge is outside
---@param x number
---@param y number
function Polygon:isInside(x, y)
    -- TODO: this obviously limits the size of polygons and position of the point relative to
    -- the polygon but for our practical purposes should be fine
    local ray = cg.LineSegment(x, y, 10000000, y)
    local nIntersections = 0
    local windingNumber = 0
    for i = 1, #self do
        local current = self:at(i)
        local next = self:at(i + 1)
        local is = ray:intersects(current:getExitEdge())
        if is then
            if current.y <= y and y < next.y and x < is.x then
                -- edge upwards
                windingNumber = windingNumber + 1
            elseif current.y > y and y >= next.y and x < is.x then
                -- edge downwards
                windingNumber = windingNumber - 1
            end
            nIntersections = nIntersections + 1
        end
    end
    return windingNumber ~= 0
end

--- Is his polygon clockwise?
--- Returns nil if it is not possible to determine, for instance an 8 shape.
---@return boolean or nil
function Polygon:isClockwise()
    self:_getDeltaAngle()
    if self.deltaAngle > 6.2 and self.deltaAngle < 6.4 then
        return true
    elseif self.deltaAngle < -6.2 and self.deltaAngle > -6.4 then
        return false
    else
        -- delta angle must be around 2*pi, otherwise there are multiple loops or knots
        -- (2*pi isn't a guarantee that there are no knots
        return nil
    end
end

function Polygon:getArea()
    if not self.area then
        self.area = 0
        for i = 1, #self do
            self.area = self.area + (self:at(i).x * self:at(i + 1).y - self:at(i).y * self:at(i + 1).x)
        end
        self.area = math.abs(self.area / 2)
    end
    return self.area
end

function Polygon:calculateProperties(from, to)
    cg.Polyline.calculateProperties(self, from, to)
    -- dirty flag to trigger clockwise/area recalculation
    self.deltaAngle, self.area, self.length = nil, nil, nil
end

function Polygon:ensureMinimumEdgeLength(minimumLength)
    cg.Polyline.ensureMinimumEdgeLength(self, minimumLength)
    if (self[1] - self[#self]):length() < minimumLength then
        table.remove(self, #self)
    end
end

--- Make sure the edges are properly connected, their ends touch nicely without gaps and never
--- extend beyond the vertex
---@param edges cg.LineSegment[]
function Polygon:cleanEdges(edges, minEdgeLength, preserveCorners)
    return self:_cleanEdges(edges, 1, {}, edges[#edges], minEdgeLength, preserveCorners)
end

--- Generate a polygon parallel to this one, offset by the offsetVector.
---@param offsetVector cg.Vector offset to move the edges, relative to the edge's direction
---@param minEdgeLength number see LineSegment.connect()
---@param preserveCorners number see LineSegment.connect()
function Polygon:createOffset(offsetVector, minEdgeLength, preserveCorners)
    local offsetEdges = self:generateOffsetEdges(offsetVector)
    local cleanOffsetEdges = self:cleanEdges(offsetEdges, minEdgeLength, preserveCorners)
    if #offsetEdges < 2 or #cleanOffsetEdges < 2 then
        self.logger:error('Could not create offset polygon')
        return nil
    end
    -- So far, same as the polyline, but now we need to take care of the connection between the
    -- last and the first edge.
    local gapFiller = cg.LineSegment.connect(cleanOffsetEdges[#cleanOffsetEdges], cleanOffsetEdges[1],
            minEdgeLength, preserveCorners)
    if gapFiller then
        table.insert(cleanOffsetEdges, gapFiller)
    end
    local offsetPolygon = cg.Polygon()
    for _, e in ipairs(cleanOffsetEdges) do
        offsetPolygon:append(e:getBase())
    end
    -- unlike to the polyline, no need to append the end of the last edge here as it is the same
    -- as the start of the first edge
    return offsetPolygon
end

---@param isValidFunc function optional function accepting a cg.Vertex and returning bool to determine if this
--- vertex should be considered at all
---@return number index of the first vertex which is at least d distance from ix
---(can be nil if the end of line reached before d)
function Polygon:moveForward(ix, d, isValidFunc)
    local i, n, dElapsed = self:getRawIndex(ix), 1, 0
    -- wrap around once only
    while n <= #self do
        if not isValidFunc or isValidFunc(self:at(i)) then
            if dElapsed >= d then
                return self:getRawIndex(i)
            end
            dElapsed = dElapsed + self:at(i):getExitEdge():getLength()
        end
        i = i + 1
        n = n + 1
    end
    return nil
end

---@param point Vector
---@param isValidFunc function optional function accepting a cg.Vertex and returning bool to determine if this
--- vertex should be considered at all
---@return cg.Vertex
function Polygon:findClosestVertexToPoint(point, isValidFunc)
    local d, closestVertex = math.huge, nil
    for _, v in self:vertices() do
        if not isValidFunc or isValidFunc(v) then
            local dFromV = (point - v):length()
            if dFromV < d then
                d = dFromV
                closestVertex = v
            end
        end
    end
    local projection = closestVertex and closestVertex:getExitEdge():getScalarProjection(point)
    return closestVertex, projection
end

function Polygon:getSmallestRadiusWithinDistance(ix, dForward, dBackward)
    local i, dElapsed, minRadius = ix, 0, math.huge
    while dElapsed < dBackward do
        dElapsed = dElapsed + self:at(i):getEntryEdge():getLength()
        local r = self:at(i):getRadius()
        minRadius = r < minRadius and r or minRadius
        i = i - 1
    end
    i, dElapsed = ix, 0
    while dElapsed < dForward do
        dElapsed = dElapsed + self:at(i):getExitEdge():getLength()
        local r = self:at(i):getRadius()
        minRadius = r < minRadius and r or minRadius
        i = i + 1
    end
    return minRadius
end

--- Try cleaning up unwanted loops in the generated offset polygon.
--- With concave polygons (you know, the ones you can hide in) the offset polygon may end up
--- intersecting it self at multiple points. This is a simple
--- NOTE: this works correctly only if there is exactly one loop (one intersecting edge)
---@return boolean loop found and removed.
function Polygon:removeLoops(baseClockwise, startIx)
    self.logger:debug('Removing loops')
    local exitIx, entryIx
    for i, this, _, _ in self:vertices(startIx or 1) do
        for j = 1, i > 1 and #self or (#self - 1) do
            if j ~= self:getRawIndex(i - 1) and j ~= i and j ~= self:getRawIndex(i + 1) then
                local is = this:getExitEdge():intersects(self:at(j):getExitEdge())
                if is then
                    if this:getExitEdge():isEntering(baseClockwise, self:at(j):getExitEdge()) then
                        -- entering back into the polygon
                        if exitIx and exitIx == j then
                            self.logger:debug('Removing loop between %d and %d', exitIx, i)
                            local pathFromExitToEntry, pathFromEntryToExit = self:_getPathBetween(exitIx, i)
                            self:_reset()
                            self:init(pathFromEntryToExit)
                            -- make sure the end remains pointy
                            self:append(cg.Vertex.fromVector(is))
                            self:reverse()
                            self:calculateProperties()
                            return true
                        elseif not exitIx then
                            self.logger:debug('Entering polygon at %d but have not exited, restart', i)
                            return true, i + 1
                        end
                        entryIx = i
                    else
                        -- exiting, meaning that now we are outside of the area normally surrounded by
                        -- the polygon

                        exitIx = i
                    end
                end
            end
        end
    end
    return false
end

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------

--- Get all vertices between fromIx and toIx (non inclusive), in form of two polylines/polygons,
--- one in each direction (cw/ccw)
---@param fromIx number index of first vertex in the segment, not including
---@param toIx number index of last vertex in the segment, not including
---@return Polyline, Polyline
function Polygon:_getPathBetween(fromIx, toIx, asPolygon)
    local forward = asPolygon and cg.Polygon() or cg.Polyline()
    local fwdIx = cg.WrapAroundIndex(self, fromIx)
    while fwdIx:get() ~= toIx do
        fwdIx = fwdIx + 1
        forward:append(self:at(fwdIx:get()))
    end
    local backward = asPolygon and cg.Polygon() or cg.Polyline()
    local bwdIx = cg.WrapAroundIndex(self, fromIx)
    while bwdIx:get() ~= toIx do
        backward:append(self:at(bwdIx:get()))
        bwdIx = bwdIx - 1
    end
    return forward, backward
end

function Polygon:_getDeltaAngle()
    if not self.deltaAngle then
        self.deltaAngle = 0
        for i = 1, #self do
            self.deltaAngle = self.deltaAngle + cg.Math.getDeltaAngle(self:at(i):getExitHeading(), self:at(i):getEntryHeading())
        end
    end
    return self.deltaAngle
end


---@class cg.Polygon:cg.Polyline
cg.Polygon = Polygon