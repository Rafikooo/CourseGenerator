require('include')

local p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 5), cg.Vertex(0, 10), cg.Vertex(5, 10), cg.Vertex(10, 10), cg.Vertex(15, 10), cg.Vertex(20, 10)})
local s = cg.Slider(p, 1, 0)
s:assertAlmostEquals(cg.LineSegment(0, 0, 0, 1))
s = cg.Slider(p, 1, 3)
s:assertAlmostEquals(cg.LineSegment(0, 3, 0, 4))
s = cg.Slider(p, 1, 5)
s:assertAlmostEquals(cg.LineSegment(0, 5, 0, 6))
s = cg.Slider(p, 1, 10)
s:assertAlmostEquals(cg.LineSegment(0, 10, 0, 11))
s:move(6)
s:assertAlmostEquals(cg.LineSegment(6, 10, 7, 10))
-- don't move past the end of the polyline
s:move(60)
s:assertAlmostEquals(cg.LineSegment(20, 10, 21, 10))

s = cg.Slider(p, 1, -2)
s:assertAlmostEquals(cg.LineSegment(0, 0, 0, 1))

s = cg.Slider(p, 7, 0)
s:assertAlmostEquals(cg.LineSegment(20, 10, 21, 10))
s:move(-2)
s:assertAlmostEquals(cg.LineSegment(18, 10, 19, 10))
s:move(-10)
s:assertAlmostEquals(cg.LineSegment(8, 10, 9, 10))

p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0)})
s = cg.Slider(p, 1, 6)
s:assertAlmostEquals(cg.LineSegment(1, 5, 2, 5))
s = cg.Slider(p, 1, -2)
s:assertAlmostEquals(cg.LineSegment(2, 0, 1, 0))
-- wrap around backwards
s = cg.Slider(p, 1, -20)
s:assertAlmostEquals(cg.LineSegment(0, 0, 0, 1))
-- wrap around forward
s = cg.Slider(p, 1, 20)
-- just before the last corner
s:assertAlmostEquals(cg.LineSegment(0, 0, -1, 0))
s = cg.Slider(p, 1, 20.0001)
s:assertAlmostEquals(cg.LineSegment(0, 0, 0, 1))

