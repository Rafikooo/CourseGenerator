--- A complete fieldwork course. This contains all main parts of the course in a structured form:
--- headlands, the center with blocks, each block with a set of rows.
--- The constructor FieldworkCourse() generates the course based on the parameters passed in the context.
--- FieldworkCourse:getPath() then returns a continuous Polyline covering the entire field. This is the
--- path a vehicle would follow to complete work on the field.
--- The vertices of the path contain WaypointAttributes which provide additional navigation information
--- for the vehicle.
---@class FieldworkCourse
local FieldworkCourse = CpObject()

---@param context cg.FieldworkContext
function FieldworkCourse:init(context)
    self.logger = cg.Logger('FieldworkCourse')
    self:_setContext(context)
    self.headlandPath = cg.Polyline()
    self.circledIslands = {}

    self.logger:debug('### Generating headlands around the field perimeter ###')
    self:generateHeadlands()
    self.logger:debug('### Setting up islands ###')
    self:setupAndSortIslands()

    if self.context.bypassIslands then
        self:routeHeadlandsAroundBigIslands()
    end

    if self.context.headlandFirst then
        self.logger:debug('### Connecting headlands (%d) from the outside towards the inside ###', #self.headlands)
        self.headlandPath = cg.HeadlandConnector.connectHeadlandsFromOutside(self.headlands,
                context.startLocation, self.context.workingWidth, self.context.turningRadius)
        self:routeHeadlandsAroundSmallIslands()
        self.logger:debug('### Genera]ting up/down rows ###')
        self:generateCenter()
    else
        self.logger:debug('### Generating up/down rows ###')
        local endOfLastRow = self:generateCenter()
        self.logger:debug('### Connecting headlands (%d) from the inside towards the outside ###', #self.headlands)
        self.headlandPath = cg.HeadlandConnector.connectHeadlandsFromInside(self.headlands,
                endOfLastRow, self.context.workingWidth, self.context.turningRadius)
        self:routeHeadlandsAroundSmallIslands()
    end
    if self.context.bypassIslands then
        self:bypassIslands()
    end
end

--- Returns a continuous Polyline covering the entire field. This is the
--- path a vehicle would follow to complete work on the field.
--- The vertices of the path contain WaypointAttributes which provide additional navigation information
--- for the vehicle.
---@return cg.Polyline
function FieldworkCourse:getPath()
    if not self.path then
        self.path = cg.Polyline()
        if self.context.headlandFirst then
            self.path:appendMany(self:getHeadlandPath())
            self.path:appendMany(self:getCenterPath())
        else
            self.path:appendMany(self:getCenterPath())
            self.path:appendMany(self:getHeadlandPath())
        end
    end
    self.path:calculateProperties()
    return self.path
end

--- Reverse the course, so the vehicle drives it in the opposite direction. The only changes made
--- during reversing is flipping the attributes where applicable, for instance, row ends become row
--- starts.
--- This is for cases where someone wants to drive the exact same course, for instance baling from
--- starting on the headland and finishing on the center, and then collecting the bales starting
--- from the center towards the headland.
--- Note that reverse() guarantees it is the exact same course just backwards, whereas generating
--- a course with starting in the center instead of the headland may result in slightly different path.
function FieldworkCourse:reverse()
    -- make sure we have the forward path
    self:getPath()
    self.path:reverse()
    for _, v in ipairs(self.path) do
        v:getAttributes():_reverse()
    end
end

---@return cg.Polyline
function FieldworkCourse:getHeadlandPath()
    return self.headlandPath
end

---@return cg.Headland[]
function FieldworkCourse:getHeadlands()
    return self.headlands
end

---@return cg.Center
function FieldworkCourse:getCenter()
    return self.center
end

---@return cg.Polyline
function FieldworkCourse:getCenterPath()
    return self.center:getPath()
end

------------------------------------------------------------------------------------------------------------------------
--- Headlands
------------------------------------------------------------------------------------------------------------------------
--- Generate the headlands based on the current context or the context passed in here
function FieldworkCourse:generateHeadlands()
    self.headlands = {}
    self.logger:debug('generating %d headlands with round corners, then %d with sharp corners',
            self.nHeadlandsWithRoundCorners, self.nHeadlands - self.nHeadlandsWithRoundCorners)
    if self.nHeadlandsWithRoundCorners > 0 then
        self:generateHeadlandsFromInside()
        if self.nHeadlands > self.nHeadlandsWithRoundCorners and #self.headlands < self.nHeadlands then
            self:generateHeadlandsFromOutside(self.boundary,
                    (self.nHeadlandsWithRoundCorners + 0.5) * self.context.workingWidth,
                    #self.headlands + 1)
        end
    elseif self.nHeadlands > 0 then
        self:generateHeadlandsFromOutside(self.boundary, self.context.workingWidth / 2, 1)
    end
end

--- Generate headlands around the field, starting with the outermost one.
---@param boundary Polygon field boundary or other headland to start the generation from
---@param firstHeadlandWidth number width of the outermost headland to generate, if the boundary is the field boundary,
--- it will usually be the half working width, if the boundary is another headland, the full working width
---@param startIx number index of the first headland to generate
function FieldworkCourse:generateHeadlandsFromOutside(boundary, firstHeadlandWidth, startIx)

    self.logger:debug('generating %d sharp headlands from the outside, min radius %.1f',
            self.nHeadlands - startIx + 1, self.context.turningRadius)
    -- outermost headland is offset from the field boundary by half width
    self.headlands[startIx] = cg.Headland(boundary, self.context.headlandClockwise, startIx, firstHeadlandWidth, false, nil)
    if not self.headlands[startIx]:isValid() then
        self:_removeHeadland(startIx)
        return
    end
    if self.context.sharpenCorners then
        self.headlands[startIx]:sharpenCorners(self.context.turningRadius)
    end
    for i = startIx + 1, self.nHeadlands do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), self.context.headlandClockwise, i,
                self.context.workingWidth, false, self.headlands[1]:getPolygon())
        if self.headlands[i]:isValid() then
            if self.context.sharpenCorners then
                self.headlands[i]:sharpenCorners(self.context.turningRadius)
            end
        else
            self:_removeHeadland(i)
            break
        end
    end
end

--- Generate headlands around the field, starting with the innermost one. Generating from the inside
--- is needed when we needed a headland with corners rounded to the vehicle's turn radius, everything
--- outside of such a headland should be generated based on the innermost one with a rounded corner to
--- guarantee that none will have a corner sharper than the turn radius.
function FieldworkCourse:generateHeadlandsFromInside()
    self.logger:debug('generating %d headlands with round corners, min radius %.1f',
            self.nHeadlandsWithRoundCorners, self.context.turningRadius)
    -- start with the innermost headland, try until it can fit in the field (as the required number of
    -- headlands may be more than what actually fits into the field)
    while self.nHeadlandsWithRoundCorners > 0 do
        self.headlands[self.nHeadlandsWithRoundCorners] = cg.Headland(self.boundary, self.context.headlandClockwise,
                self.nHeadlandsWithRoundCorners, (self.nHeadlandsWithRoundCorners - 0.5) * self.context.workingWidth,
                false, self.boundary)
        if self.headlands[self.nHeadlandsWithRoundCorners]:isValid() then
            self.headlands[self.nHeadlandsWithRoundCorners]:roundCorners(self.context.turningRadius)
            break
        else
            self:_removeHeadland(self.nHeadlandsWithRoundCorners)
            self.logger:warning('no room for innermost headland, reducing headlands to %d, rounded %d',
                    self.nHeadlands, self.nHeadlandsWithRoundCorners)
        end
    end
    for i = self.nHeadlandsWithRoundCorners - 1, 1, -1 do
        self.headlands[i] = cg.Headland(self.headlands[i + 1]:getPolygon(), self.context.headlandClockwise, i,
                self.context.workingWidth, true, self.boundary)
        self.headlands[i]:roundCorners(self.context.turningRadius)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Up/down rows
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourse:generateCenter()
    -- if there are no headlands, or there are, but we start working in the middle, then use the
    -- designated start location, otherwise the point where the innermost headland ends.
    if #self.headlands == 0 then
        self.center = cg.Center(self.context, self.boundary, nil, self.context.startLocation, self.bigIslands)
    else
        local innerMostHeadlandPolygon = self.headlands[#self.headlands]:getPolygon()
        self.center = cg.Center(self.context, self.boundary, self.headlands[#self.headlands],
                self.context.headlandFirst and
                        innerMostHeadlandPolygon[#innerMostHeadlandPolygon] or
                        self.context.startLocation,
                self.bigIslands)
    end
    return self.center:generate()
end

------------------------------------------------------------------------------------------------------------------------
--- Islands
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourse:setupAndSortIslands()
    self.bigIslands, self.smallIslands = {}, {}
    for _, island in pairs(self.context.field:getIslands()) do
        island:generateHeadlands(self.context, (self.nHeadlands > 0 and self.headlands[1]) and
                self.headlands[1]:getPolygon() or self.boundary)
        -- for some weird cases we may not have been able to generate island headlands, so ignore those islands
        if island:getInnermostHeadland() then
            if island:isTooBigToBypass(self.context.workingWidth) then
                table.insert(self.bigIslands, island)
            else
                table.insert(self.smallIslands, island)
            end
        else
            self.logger:warning('Could not generate headlands for island %d', island:getId())
        end
    end
end

function FieldworkCourse:routeHeadlandsAroundBigIslands()

    self.logger:debug('### Bypassing big islands: headlands ###')
    for _, headland in ipairs(self.headlands) do
        headland:bypassBigIslands(self.bigIslands)
    end
end

function FieldworkCourse:routeHeadlandsAroundSmallIslands()

    self.logger:debug('### Bypassing small islands ###')
    for _, island in pairs(self.smallIslands) do
        local startIx, circled = 1, false
        while startIx ~= nil do
            self.logger:debug('Bypassing island %d on the headland, at %d', island:getId(), startIx)
            --- Remember the islands we circled already, as even if multiple tracks cross it, we only want to
            --- circle once.
            circled, startIx = self.headlandPath:goAround(
                    island:getHeadlands()[1]:getPolygon(), startIx, not self.circledIslands[island])
            self.circledIslands[island] = circled or self.circledIslands[island]
        end
    end
end

function FieldworkCourse:bypassIslands()
    self.logger:debug('### Bypassing small islands ###')
    for _, island in pairs(self.smallIslands) do
        self.logger:debug('Bypassing small island %d on the center', island:getId())
        self.center:bypassSmallIsland(island:getInnermostHeadland():getPolygon(), not self.circledIslands[island])
    end
    self.logger:debug('### Bypassing big islands: create path around them ###')
    self:circleBigIslands()
end

-- Once we have the whole course laid out, we add the headland passes around the big islands
function FieldworkCourse:circleBigIslands()
    for _, i in ipairs(self.context.field:getIslands()) do
        self.logger:debug('Island %d: circled %s, big %s',
                i:getId(), self.circledIslands[i], i:isTooBigToBypass(self.context.workingWidth))
    end
    -- if we are harvesting (headlandFirst = true) we want to take care of the island headlands
    -- when we first get to them. For other field works it is the opposite, we want all the up/down rows
    -- done before working on the island headlands.
    local path = self:getPath()
    local first = self.context.headlandFirst and 1 or #path
    local step = self.context.headlandFirst and 1 or -1
    local last = self.context.headlandFirst and #path or 1
    local i = first
    local found = false
    while i ~= last and not found do
        local island = path[i]:getAttributes():_getAtIsland()
        if island and not self.circledIslands[island] and path[i]:getAttributes():isRowEnd() then
            self.logger:debug('Found island %s at %d', island:getId(), i)
            -- we bumped upon an island which the path does not circle yet and we are at the end of a row.
            -- so now work on the island's headlands and then continue with the next row.
            local outermostHeadlandPolygon = island:getOutermostHeadland():getPolygon()
            -- find a vertex on the outermost headland to start working on the island headlands,
            -- far enough that we can generate a Dubins path to it
            local slider = cg.Slider(outermostHeadlandPolygon,
                    outermostHeadlandPolygon:findClosestVertexToPoint(path[i]).ix, 3 * self.context.turningRadius)

            -- 'inside' since with islands, everything is backwards
            local headlandPath = cg.HeadlandConnector.connectHeadlandsFromInside(island:getHeadlands(),
                    slider.ix, self.context.workingWidth, self.context.turningRadius)

            -- from the row end to the start of the headland, we instruct the driver to use
            -- the pathfinder.
            path:setAttributes(i, i, cg.WaypointAttributes.setUsePathfinderToNextWaypoint)
            headlandPath:setAttributes(#headlandPath, #headlandPath, cg.WaypointAttributes.setUsePathfinderToNextWaypoint)
            headlandPath:setAttributes(nil, nil, cg.WaypointAttributes.setIslandHeadland)

            self.logger:debug('Added headland path around island %d with %d points', island:getId(), #headlandPath)
            for j = #headlandPath, 1, -1 do
                table.insert(path, i + 1, headlandPath[j])
            end

            path:calculateProperties()
            self.circledIslands[island] = true
            -- if we are iterating backwards, we still want to stop at the first vertex.
            last = self.context.headlandFirst and last + #headlandPath or 1
        end
        i = i + step
    end

end

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourse:_setContext(context)
    self.context = context
    self.context:log()
    self.nHeadlands = self.context.nHeadlands
    self.nHeadlandsWithRoundCorners = self.context.nHeadlandsWithRoundCorners
    ---@type cg.Polygon
    self.boundary = cg.FieldworkCourseHelper.createUsableBoundary(context.field:getBoundary(), self.context.headlandClockwise)
    if self.context.fieldCornerRadius > 0 then
        self.logger:debug('sharpening field boundary corners')
        self.boundary:ensureMinimumRadius(self.context.fieldCornerRadius, true)
    end
end

function FieldworkCourse:_removeHeadland(n)
    -- If this is invalid, all above it (generated from this) must be invalid, remove them all so
    -- #self.headlands is not confused.
    for i = n, #self.headlands do
        self.headlands[i] = nil
    end
    self.nHeadlands = n - 1
    self.nHeadlandsWithRoundCorners = math.min(self.nHeadlands, self.nHeadlandsWithRoundCorners)
    self.logger:error('could not generate headland %d, course has %d headlands, %d rounded',
            n, self.nHeadlands, self.nHeadlandsWithRoundCorners)
end

---@class cg.FieldworkCourse
cg.FieldworkCourse = FieldworkCourse