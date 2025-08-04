## GdUnit TestSuite for GBGeometryMath internal helpers
extends GdUnitTestSuite

## Parameterized test for get_tile_polygon
func test_get_tile_polygon_param(tile_pos: Vector2, tile_size: Vector2, tile_type: int, expected: PackedVector2Array, test_parameters := [
	[Vector2(0,0), Vector2(2,2), 0, PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)])],
	[Vector2(1,1), Vector2(2,2), 1, PackedVector2Array([
		Vector2(1+1,1), Vector2(1+2,1+1), Vector2(1+1,1+2), Vector2(1,1+1)
	])],
  # Isometric tile at origin, size 16
  [Vector2(0,0), Vector2(16,16), 1, PackedVector2Array([
	Vector2(8,0), Vector2(16,8), Vector2(8,16), Vector2(0,8)
  ])],
  # Isometric tile at (16,16), size 16
  [Vector2(16,16), Vector2(16,16), 1, PackedVector2Array([
	Vector2(24,16), Vector2(32,24), Vector2(24,32), Vector2(16,24)
  ])],
]):
	## Tests tile polygon generation for square and isometric tiles
	assert_array(GBGeometryMath.get_tile_polygon(tile_pos, tile_size, tile_type)).is_equal(expected)

## Parameterized test for intersection_area_with_tile
func test_intersection_area_with_tile_param(polygon: PackedVector2Array, tile_pos: Vector2, tile_size: Vector2, tile_type: int, expected: float, test_parameters := [
	[PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)]), Vector2(0,0), Vector2(2,2), 0, 4.0], # Full overlap
	[PackedVector2Array([Vector2(1,1), Vector2(3,1), Vector2(3,3), Vector2(1,3)]), Vector2(0,0), Vector2(2,2), 0, 1.0], # Partial overlap
	[PackedVector2Array([Vector2(3,3), Vector2(4,3), Vector2(4,4), Vector2(3,4)]), Vector2(0,0), Vector2(2,2), 0, 0.0], # No overlap
  # Isometric tile, polygon matches tile
  [PackedVector2Array([Vector2(8,0), Vector2(16,8), Vector2(8,16), Vector2(0,8)]), Vector2(0,0), Vector2(16,16), 1, 128.0],
  # Isometric tile, polygon partially overlaps tile
  [PackedVector2Array([Vector2(12,4), Vector2(20,12), Vector2(12,20), Vector2(4,12)]), Vector2(8,0), Vector2(16,16), 1, 64.0],
  # Isometric tile, polygon outside tile
  [PackedVector2Array([Vector2(24,0), Vector2(32,8), Vector2(24,16), Vector2(16,8)]), Vector2(0,0), Vector2(16,16), 1, 0.0],
  # Isometric tile, polygon edge contact only
  [PackedVector2Array([Vector2(8,0), Vector2(16,8), Vector2(8,16), Vector2(0,8)]), Vector2(16,16), Vector2(16,16), 1, 0.0],
]):
	## Tests intersection area calculation between polygon and tile
	assert_float(GBGeometryMath.intersection_area_with_tile(polygon, tile_pos, tile_size, tile_type)).is_equal(expected)

## Parameterized test for does_polygon_overlap_tile
func test_does_polygon_overlap_tile_param(polygon: PackedVector2Array, tile_pos: Vector2, tile_size: Vector2, tile_type: int, epsilon: float, expected: bool, test_parameters := [
	[PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)]), Vector2(0,0), Vector2(2,2), 0, 0.01, true], # Full overlap
	[PackedVector2Array([Vector2(1,1), Vector2(3,1), Vector2(3,3), Vector2(1,3)]), Vector2(0,0), Vector2(2,2), 0, 0.5, true], # Partial overlap above epsilon
	[PackedVector2Array([Vector2(1,1), Vector2(3,1), Vector2(3,3), Vector2(1,3)]), Vector2(0,0), Vector2(2,2), 0, 1.5, false], # Partial overlap below epsilon
	[PackedVector2Array([Vector2(3,3), Vector2(4,3), Vector2(4,4), Vector2(3,4)]), Vector2(0,0), Vector2(2,2), 0, 0.01, false], # No overlap
  # Isometric tile, full overlap
  [PackedVector2Array([Vector2(8,0), Vector2(16,8), Vector2(8,16), Vector2(0,8)]), Vector2(0,0), Vector2(16,16), 1, 0.01, true],
  # Isometric tile, partial overlap above epsilon
  [PackedVector2Array([Vector2(12,4), Vector2(20,12), Vector2(12,20), Vector2(4,12)]), Vector2(8,0), Vector2(16,16), 1, 10.0, true],
  # Isometric tile, partial overlap below epsilon
  [PackedVector2Array([Vector2(12,4), Vector2(20,12), Vector2(12,20), Vector2(4,12)]), Vector2(8,0), Vector2(16,16), 1, 100.0, false],
  # Isometric tile, edge contact only
  [PackedVector2Array([Vector2(8,0), Vector2(16,8), Vector2(8,16), Vector2(0,8)]), Vector2(16,16), Vector2(16,16), 1, 0.01, false],
  # Isometric tile, floating-point tolerance
  [PackedVector2Array([Vector2(8.00001,0), Vector2(16.00001,8), Vector2(8.00001,16), Vector2(0.00001,8)]), Vector2(0,0), Vector2(16,16), 1, 0.01, true],
]):
	## Tests strict overlap detection with epsilon threshold
	assert_bool(GBGeometryMath.does_polygon_overlap_tile(polygon, tile_pos, tile_size, tile_type, epsilon)).is_equal(expected)

## Parameterized test for intersection_polygon_area
# Note: For identical polygons, the intersection area is the polygon's area, not 0.0.
# This test expects the true area for identical polygons and 0.0 for degenerate/no overlap cases.
func test_intersection_polygon_area_param(poly_a: PackedVector2Array, poly_b: PackedVector2Array, expected: float, test_parameters := [
	[PackedVector2Array([Vector2(0,0), Vector2(4,0), Vector2(4,3)]), PackedVector2Array([Vector2(0,0), Vector2(4,0), Vector2(4,3)]), 6.0], # Right triangle, area = 0.5*4*3 = 6
	[PackedVector2Array([Vector2(0,0), Vector2(4,0), Vector2(4,3), Vector2(0,3)]), PackedVector2Array([Vector2(0,0), Vector2(4,0), Vector2(4,3), Vector2(0,3)]), 12.0], # Rectangle, area = 4*3 = 12
	[PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(0,1)]), PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(0,1)]), 0.5], # Small triangle
	[PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(2,0)]), PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(2,0)]), 0.0], # Degenerate (colinear)
	[PackedVector2Array([Vector2(0,0), Vector2(0,0), Vector2(0,0)]), PackedVector2Array([Vector2(0,0), Vector2(0,0), Vector2(0,0)]), 0.0], # All points same
	[PackedVector2Array([Vector2(0,0), Vector2(1,0)]), PackedVector2Array([Vector2(0,0), Vector2(1,0)]), 0.0], # Less than 3 points
	[PackedVector2Array([]), PackedVector2Array([]), 0.0], # Empty
]):
	var area := GBGeometryMath.polygon_intersection_area(poly_a, poly_b)
	assert_float(area).is_equal_approx(expected, 0.01)
	
## Parameterized test for polygon_intersection_area
# Note: For overlapping polygons, the intersection area is the area of the overlap, not 0.0.
# This test expects the true overlap area for partial overlaps and 0.0 for no overlap.
func test_polygon_intersection_area_param(poly_a: PackedVector2Array, poly_b: PackedVector2Array, expected: float, test_parameters := [
	[PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)]), PackedVector2Array([Vector2(1,1), Vector2(3,1), Vector2(3,3), Vector2(1,3)]), 1.0], # Partial overlap (rectangle inside rectangle)
	[PackedVector2Array([Vector2(0,0), Vector2(2,0), Vector2(2,2), Vector2(0,2)]), PackedVector2Array([Vector2(3,3), Vector2(4,3), Vector2(4,4), Vector2(3,4)]), 0.0], # No overlap
]):
	var area := GBGeometryMath.polygon_intersection_area(poly_a, poly_b)
	assert_float(area).is_equal_approx(expected, 0.01)
