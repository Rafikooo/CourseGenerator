local Headland = CpObject()

--- Create a headland from a base polygon. The headland is a new polygon, offset by width, that is, inside
--- of the base polygon.
---@param basePolygon cg.Polygon
---@param clockwise boolean the direction of the headland. We want this explicitly stated and not derived from
--- basePolygon as on fields with odd shapes (complex polygons) headlands may intersect themselves making
--- a clear definition of clockwise/counterclockwise impossible. This is the required direction for all headlands.
---@param passNumber number of the headland pass, the outermost is 1
---@param width number
---@param outward boolean if true, the generated headland will be outside of the basePolygon, inside otherwise
function Headland:init(basePolygon, clockwise, passNumber, width, outward)
    self.logger = cg.Logger('Headland ' .. passNumber or '')
    self.clockwise = clockwise
    self.passNumber = passNumber
    self.logger:debug('start generating, base clockwise %s, desired clockwise %s, width %.1f, outward: %s',
            basePolygon:isClockwise(), self.clockwise, width, outward)
    if self.clockwise then
        -- to generate headland inside the polygon we need to offset the polygon to the right if
        -- the polygon is clockwise
        self.offsetVector = cg.Vector(0, -1)
        -- Dubins path types to use when changing to the next headland
        self.transitionPathTypes = { DubinsSolver.PathType.RSL, DubinsSolver.PathType.RSR }
    else
        self.offsetVector = cg.Vector(0, 1)
        self.transitionPathTypes = { DubinsSolver.PathType.LSR, DubinsSolver.PathType.LSL }
    end
    if outward then
        self.offsetVector = -self.offsetVector
    end
    ---@type cg.Polygon
    self.polygon = cg.Offset.generate(basePolygon, self.offsetVector, width)
    if self.polygon then
        self.polygon:calculateProperties()
        self.polygon:ensureMaximumEdgeLength(cg.cMaxEdgeLength, cg.cMaxDeltaAngleForMaxEdgeLength)
        self.polygon:calculateProperties()
        -- TODO: when removing loops, we may end up not covering the entire field on complex polygons
        -- consider making the headland invalid if it has loops, instead of removing them
        local removed, startIx = true, 1
        repeat
            removed, startIx = self.polygon:removeLoops(clockwise, startIx)
        until not removed
        self.logger:debug('polygon with %d vertices generated, area %.1f, cw %s, desired cw %s',
                #self.polygon, self.polygon:getArea(), self.polygon:isClockwise(), clockwise)
        if #self.polygon < 3 then
            self.logger:warning('invalid headland, polygon too small (%d vertices)', #self.polygon)
            self.polygon = nil
        elseif self.polygon:isClockwise() ~= nil and self.polygon:isClockwise() ~= clockwise and clockwise ~= nil then
            self.polygon = nil
            self.logger:warning('no room left for this headland')
        end
    else
        self.logger:error('could not generate headland')
    end
end

---@return cg.Polyline Headland vertices with waypoint attributes
function Headland:getPath()
    -- make sure all attributes are set correctly
    self.polygon:setAttributes(nil, nil, cg.WaypointAttributes.setHeadlandPassNumber, self.passNumber)
    return self.polygon
end

---@return number which headland is it? 1 is the outermost.
function Headland:getPassNumber()
    return self.passNumber
end

--- Make sure all corners are rounded to have at least minimumRadius radius.
function Headland:roundCorners(minimumRadius)
    self.logger:debug('applying minimum radius %.1f', minimumRadius)
    self.polygon:ensureMinimumRadius(minimumRadius, false)
    self.polygon:calculateProperties()
end

--- Make sure all corners are rounded to have at least minimumRadius radius.
function Headland:sharpenCorners(minimumRadius)
    self.logger:debug('sharpen corners under radius %.1f', minimumRadius)
    self.polygon:ensureMinimumRadius(minimumRadius, true)
    self.polygon:calculateProperties()
end

function Headland:isValid()
    return self.polygon ~= nil
end

function Headland:getPolygon()
    return self.polygon
end

--- Vertices with coordinates unpacked, to draw with love.graphics.polygon
function Headland:getUnpackedVertices()
    if not self.unpackedVertices then
        self.unpackedVertices = self.polygon:getUnpackedVertices()
    end
    return self.unpackedVertices
end

function Headland:bypassIsland(island, circle)
    return self.polygon:goAround(island:getHeadlands()[1]:getPolygon(), nil, circle)
end

--- Generate a path to switch from this headland to the other, starting as close as possible to the
--- given vertex on this headland and append this path to headland
---@param other cg.Headland
---@param ix number vertex index to start the transition at
---@param workingWidth number
---@param turningRadius number
---@param headlandFirst boolean if true, work on headlands first and then transition to the middle of the field
--- for the up/down rows, if false start in the middle and work the headlands from the inside out
---@return number index of the vertex on other where the transition ends
function Headland:connectTo(other, ix, workingWidth, turningRadius, headlandFirst)
    local function ignoreIslandBypass(v)
        return not v:getAttributes():getIslandBypass()
    end

    if (self.clockwise and headlandFirst) or (not self.clockwise and not headlandFirst) then
        -- Dubins path types to use when changing to the next headland
        self.transitionPathTypes = { DubinsSolver.PathType.RSL, DubinsSolver.PathType.RSR }
    else
        self.transitionPathTypes = { DubinsSolver.PathType.LSR, DubinsSolver.PathType.LSL }
    end


    -- determine the theoretical minimum length of the transition (depending on the width and radius)
    local transitionLength = Headland._getTransitionLength(workingWidth, turningRadius)
    local transition = self:_continueUntilStraightSection(ix, transitionLength)
    -- index on the other polygon closest to the location where the transition will start
    local otherClosest = other:getPolygon():findClosestVertexToPoint(self.polygon:at(ix + #transition), ignoreIslandBypass)
    -- index on the other polygon where the transition will approximately end
    local transitionEndIx = other:getPolygon():moveForward(otherClosest.ix, transitionLength, ignoreIslandBypass)
    if transitionEndIx then
        -- try a few times to generate a Dubins path as depending on the orientation of the waypoints on
        -- the own headland and the next, we may need more room than the calculated, ideal transition length.
        -- In that case, the Dubins path generated will end up in a loop, so we use a target further ahead on the next headland.
        local tries = 5
        for i = 1, tries do
            cg.addDebugPoint(self.polygon:at(ix + #transition))
            cg.addDebugPoint(other.polygon:at(transitionEndIx))
            local connector, length = cg.AnalyticHelper.getDubinsSolutionAsVertices(
                    self.polygon:at(ix + #transition):getExitEdge():getBaseAsState3D(),
                    other.polygon:at(transitionEndIx):getExitEdge():getBaseAsState3D(),
                    -- enable any path type on the very last try
                    turningRadius, i < tries and self.transitionPathTypes or nil)
            cg.addDebugPolyline(cg.Polyline(connector))
            -- maximum length without loops
            local maxPlausiblePathLength = workingWidth + 4 * turningRadius
            if length < maxPlausiblePathLength or i == tries then
                -- the whole transition is the straight section on the current headland and the actual connector between
                -- the current and the next
                transition:appendMany(connector)
                self.polygon:appendMany(transition)
                self.polygon:setAttributes(#self.polygon - #transition, #self.polygon,
                        cg.WaypointAttributes.setHeadlandTransition, true)
                self.polygon:calculateProperties()
                self.logger:debug('Transition to next headland added, length %.1f, ix on next %d, try %d.',
                        length, transitionEndIx, i)
                return transitionEndIx
            else
                self.logger:warning('Generated path to next headland too long (%.1f > %.1f), try %d.',
                        length, maxPlausiblePathLength, i)
            end
            transitionEndIx = transitionEndIx + 1
        end
        self.logger:error('Could not connect to next headland after %d tries, giving up', tries)
    else
        self.logger:warning('Could not connect to next headland, can\'t find transition end')
    end
    return nil
end

---@param ix number the vertex to start the search
---@param straightSectionLength number how long at the minimum the straight section should be
---@param searchRange number how far should the search for the straight section should go
---@return cg.Polyline array of vectors (can be empty) from ix to the start of the straight section
function Headland:_continueUntilStraightSection(ix, straightSectionLength, searchRange)
    local dTotal = 0
    local count = 0
    local waypoints = cg.Polyline()
    searchRange = searchRange or 100
    while dTotal < searchRange do
        dTotal = dTotal + self.polygon:at(ix):getExitEdge():getLength()
        local r = self.polygon:getSmallestRadiusWithinDistance(ix, straightSectionLength, 0)
        if r > NewCourseGenerator.headlandChangeMinRadius then
            self.logger:debug('Added %d waypoint(s) to reach a straight section for the headland change after %.1f m, r = %.1f',
                    count, dTotal, r)
            return waypoints
        end
        waypoints:append((self.polygon:at(ix)):clone())
        ix = ix + 1
        count = count + 1
    end
    -- no straight section found, bail out here
    self.logger:debug('No straight section found after %1.f m for headland change to next', dTotal)
    return waypoints
end

--- determine the theoretical minimum length of the transition from one headland to another
---(depending on the width and radius)
function Headland._getTransitionLength(workingWidth, turningRadius)
    local transitionLength
    if turningRadius - workingWidth / 2 < 0.1 then
        -- can make two half turns within the working width
        transitionLength = 2 * turningRadius
    else
        local alpha = math.abs(math.acos((turningRadius - workingWidth / 2) / turningRadius) / 2)
        transitionLength = 2 * workingWidth / 2 / math.tan(alpha)
    end
    return transitionLength
end

---@class cg.Headland
cg.Headland = Headland