require('include')

local p = cg.Polygon({ cg.Vector(0, 0), cg.Vector(0, 1), cg.Vector(0, 2), cg.Vector(1, 2) })
local e = {}
for _, edge in p:edges() do
    table.insert(e, edge)
end
lu.assertEquals(e[1], cg.LineSegment(0, 0, 0, 1))
lu.assertEquals(e[2], cg.LineSegment(0, 1, 0, 2))
lu.assertEquals(e[3], cg.LineSegment(0, 2, 1, 2))
lu.assertEquals(e[4], cg.LineSegment(1, 2, 0, 0))

lu.assertEquals(p:getLength(), 3 + e[4]:getLength())

-- inside
p = cg.Polygon({ cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0) })
local o = p:createOffset(cg.Vector(0, -1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(1, 1))
o[2]:assertAlmostEquals(cg.Vector(1, 4))
o[3]:assertAlmostEquals(cg.Vector(4, 4))
o[4]:assertAlmostEquals(cg.Vector(4, 1))

-- wrap around case
p = cg.Polygon({ cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0), cg.Vector(4, 0) })
p:ensureMinimumEdgeLength(2)
lu.assertEquals(#p, 4)
p[4]:assertAlmostEquals(cg.Vector(5, 0))

-- outside, cut corner
p = cg.Polygon({ cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0) })
o = p:createOffset(cg.Vector(0, 1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(-1, 0))
o[2]:assertAlmostEquals(cg.Vector(-1, 5))
o[3]:assertAlmostEquals(cg.Vector(0, 6))
o[4]:assertAlmostEquals(cg.Vector(5, 6))
o[5]:assertAlmostEquals(cg.Vector(6, 5))
o[6]:assertAlmostEquals(cg.Vector(6, 0))
o[7]:assertAlmostEquals(cg.Vector(5, -1))
o[8]:assertAlmostEquals(cg.Vector(0, -1))

-- outside, preserve corner
p = cg.Polygon({ cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0) })
o = p:createOffset(cg.Vector(0, 1), 1, true)
o[1]:assertAlmostEquals(cg.Vector(-1, -1))
o[2]:assertAlmostEquals(cg.Vector(-1, 6))
o[3]:assertAlmostEquals(cg.Vector(6, 6))
o[4]:assertAlmostEquals(cg.Vector(6, -1))
lu.assertIsTrue(p:isClockwise())

p = cg.Polygon({ cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0), cg.Vector(0.3, 0), cg.Vector(0.1, 0) })
p:ensureMinimumEdgeLength(1)
p[1]:assertAlmostEquals(cg.Vector(0, 0))
p[2]:assertAlmostEquals(cg.Vector(0, 5))
p[3]:assertAlmostEquals(cg.Vector(5, 5))
p[4]:assertAlmostEquals(cg.Vector(5, 0))

-- wrap around
p = cg.Polygon({ cg.Vector(5, 0), cg.Vector(5, 5), cg.Vector(0, 5), cg.Vector(0, 0) })
lu.assertIsFalse(p:isClockwise())
p:calculateProperties()
p[1]:getEntryEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(5, 0, 5, 5))
p[4]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))

-- point in polygon
p = cg.Polygon({ cg.Vector(-10, -10), cg.Vector(10, -10), cg.Vector(10, 10), cg.Vector(-10, 10) })
lu.assertIsTrue(p:isInside(0, 0))
lu.assertIsTrue(p:isInside(5, 5))
lu.assertIsTrue(p:isInside(-5, -5))
lu.assertIsTrue(p:isInside(-10, -5))
lu.assertIsTrue(p:isInside(-9.99, -10))
lu.assertIsFalse(p:isInside(-9.99, 10))

lu.assertIsFalse(p:isInside(-10.01, -5))
lu.assertIsFalse(p:isInside(10.01, 50))

p = cg.Polygon({ cg.Vector(-10, -10), cg.Vector(10, -10), cg.Vector(0, 0), cg.Vector(10, 10), cg.Vector(-10, 10) })

lu.assertIsFalse(p:isInside(0, 0))
lu.assertIsFalse(p:isInside(5, 5))
lu.assertIsTrue(p:isInside(-5, -5))
lu.assertIsTrue(p:isInside(-10, -5))
lu.assertIsFalse(p:isInside(-10, 10))

lu.assertIsFalse(p:isInside(0.01, 0))
lu.assertIsFalse(p:isInside(10, 0))
lu.assertIsFalse(p:isInside(5, 2))
lu.assertIsFalse(p:isInside(5, -2))
lu.assertIsFalse(p:isInside(-10.01, -5))
lu.assertIsFalse(p:isInside(10.01, 50))

p = cg.Polygon({ cg.Vector(-10, -10), cg.Vector(10, -10), cg.Vector(10, 10), cg.Vector(-10, 10) })
lu.assertAlmostEquals(p:getArea(), 400)
lu.assertIsFalse(p:isClockwise())
p:reverse()
lu.assertAlmostEquals(p:getArea(), 400)
lu.assertIsTrue(p:isClockwise())

-- getPathBetween()
local pCw = cg.Polygon({ cg.Vector(-10, -10), cg.Vector(-10, -7), cg.Vector(-10, 7), cg.Vector(-10, 10),
                         cg.Vector(10, 10), cg.Vector(10, 7), cg.Vector(10, -7), cg.Vector(10, -10) })
local pCcw = cg.Polygon({ cg.Vector(10, -10), cg.Vector(10, -7), cg.Vector(10, 7), cg.Vector(10, 10),
                          cg.Vector(-10, 10), cg.Vector(-10, 7), cg.Vector(-10, -7), cg.Vector(-10, -10) })
local o1, o2 = pCw:getPathBetween(1, 3)
lu.assertEquals(#o1, 2)
o1[1]:assertAlmostEquals(pCw[2])
o1[2]:assertAlmostEquals(pCw[3])
lu.assertEquals(#o2, 6)
o2[1]:assertAlmostEquals(pCw[1])
o2[6]:assertAlmostEquals(pCw[4])

o2, o1 = pCw:getPathBetween(3, 1)
lu.assertEquals(#o1, 2)
o1[1]:assertAlmostEquals(pCw[3])
o1[2]:assertAlmostEquals(pCw[2])
lu.assertEquals(#o2, 6)
o2[1]:assertAlmostEquals(pCw[4])
o2[6]:assertAlmostEquals(pCw[1])

-- goAround()
local function assertGoAroundTop(line)
    lu.EPS = 0.01
    line[1]:assertAlmostEquals(cg.Vector(-12, 8))
    line[2]:assertAlmostEquals(cg.Vector(-10, 8))
    line[3]:assertAlmostEquals(cg.Vector(-10.00, 10.00))
    line[4]:assertAlmostEquals(cg.Vector(10.00, 10.00))
    line[5]:assertAlmostEquals(cg.Vector(10.00, 9.00))
    line[6]:assertAlmostEquals(cg.Vector(12.00, 9.00))
end

pCw = cg.Polygon({ cg.Vector(-10, -10), cg.Vector(-10, -7), cg.Vector(-10, 7), cg.Vector(-10, 10),
                         cg.Vector(10, 10), cg.Vector(10, 7), cg.Vector(10, -7), cg.Vector(10, -10) })
pCcw = cg.Polygon({ cg.Vector(10, -10), cg.Vector(10, -7), cg.Vector(10, 7), cg.Vector(10, 10),
                          cg.Vector(-10, 10), cg.Vector(-10, 7), cg.Vector(-10, -7), cg.Vector(-10, -10) })
o = cg.Polyline({ cg.Vector(-12, 8), cg.Vector(-9, 8), cg.Vector(0, 9), cg.Vector(9, 9), cg.Vector(12, 9) })
o:goAround(pCw)
assertGoAroundTop(o)
o = cg.Polyline({ cg.Vector(-12, 8), cg.Vector(-9, 8), cg.Vector(0, 9), cg.Vector(9, 9), cg.Vector(12, 9) })
o:goAround(pCcw)
assertGoAroundTop(o)

local function assertGoAroundBottom(line)
    lu.EPS = 0.01
    line[1]:assertAlmostEquals(cg.Vector(-12, -8))
    line[2]:assertAlmostEquals(cg.Vector(-10, -8))
    line[3]:assertAlmostEquals(cg.Vector(-10.00, -10.00))
    line[4]:assertAlmostEquals(cg.Vector(10.00, -10.00))
    line[5]:assertAlmostEquals(cg.Vector(10.00, -9.00))
    line[6]:assertAlmostEquals(cg.Vector(12.00, -9.00))
end

o = cg.Polyline({ cg.Vector(-12, -8), cg.Vector(-9, -8), cg.Vector(0, -9), cg.Vector(9, -9), cg.Vector(12, -9) })
o:goAround(pCw)
assertGoAroundBottom(o)
o = cg.Polyline({ cg.Vector(-12, -8), cg.Vector(-9, -8), cg.Vector(0, -9), cg.Vector(9, -9), cg.Vector(12, -9) })
o:goAround(pCcw)
assertGoAroundBottom(o)