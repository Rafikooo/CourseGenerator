require('include')

-- epsilon for assertAlmostEquals
lu.EPS = 0.01

local v = cg.Vertex(0, 0)
local prev = nil
local next = cg.Vertex(1, 1)
v:calculateProperties(nil, next)
next:calculateProperties(v, nil)
lu.assertEquals(v:getDistance(), 0)
lu.assertAlmostEquals(v:getEntryHeading(), math.pi / 4)
lu.assertAlmostEquals(v:getExitHeading(), math.pi / 4)
lu.assertIsNil(v:getEntryEdge())
v:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 1, 1))
lu.assertEquals(v:getRadius(), math.huge)

v = cg.Vertex(0, 0)
prev = cg.Vertex(1, 1)
prev:calculateProperties(nil, v)
lu.assertEquals(prev:getDistance(), 0)
v:calculateProperties(prev, nil)
lu.assertAlmostEquals(v:getDistance(), math.sqrt(2))
lu.assertAlmostEquals(v:getEntryHeading(), - 3 * math.pi / 4)
lu.assertAlmostEquals(v:getExitHeading(), - 3 * math.pi / 4)
lu.assertIsNil(v:getExitEdge())
v:getEntryEdge():assertAlmostEquals(cg.LineSegment(1, 1, 0, 0))
lu.assertEquals(v:getRadius(), math.huge)

v = cg.Vertex(0, 0)
v:calculateProperties(cg.Vertex(-1, 0), cg.Vertex(1, 0))
lu.assertAlmostEquals(v:getEntryHeading(), 0)
lu.assertAlmostEquals(v:getExitHeading(), 0)
v:getEntryEdge():assertAlmostEquals(cg.LineSegment(-1, 0, 0, 0))
v:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 1, 0))
lu.assertEquals(v:getRadius(), math.huge)

v = cg.Vertex(0, 0)
v:calculateProperties(cg.Vertex(-1, 0), cg.Vertex(1, 1))
lu.assertAlmostEquals(v:getEntryHeading(), 0)
lu.assertAlmostEquals(v:getExitHeading(), math.pi / 4)
v:getEntryEdge():assertAlmostEquals(cg.LineSegment(-1, 0, 0, 0))
v:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 1, 1))
lu.assertAlmostEquals(v:getRadius(), 1.84)
v:calculateProperties(cg.Vertex(-1, 0), cg.Vertex(1, -1))
lu.assertAlmostEquals(v:getRadius(), -1.84)

v = cg.Vertex(0, 0)
v:calculateProperties(cg.Vertex(-5, 0), cg.Vertex(5, 5))
lu.assertAlmostEquals(v:getRadius(), 9.23)
v:calculateProperties(cg.Vertex(-5, 0), cg.Vertex(0, 5))
lu.assertAlmostEquals(v:getRadius(), 2.5 * math.sqrt(2))
