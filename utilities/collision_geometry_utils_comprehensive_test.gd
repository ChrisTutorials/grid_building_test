## Comprehensive tests for CollisionGeometryUtils with consolidated parameterization.
##
## Tests core utility functions including:
## - Transform calculations (build_shape_transform)
## - Polygon-to-world conversion (to_world_polygon)
## - Tile offset computation (compute_polygon_tile_offsets)
## - Polygon analysis (is_polygon_convex)
##
## Consolidates existing patterns while adding coverage for new functionality.
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var tile_map_layer: TileMapLayer

func before_test():
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2(16, 16)

## Test build_shape_transform with comprehensive transform scenarios
@warning_ignore("unused_parameter")
func test_build_shape_transform_comprehensive_scenarios(
	col_obj_rot: float,
	col_obj_scale: Vector2,
	shape_rot: float,
	shape_scale: Vector2,
	shape_local_pos: Vector2,
	expected_origin: Vector2,
	tolerance: float,
	test_description: String,
	test_parameters := [
		# Basic cases - no transforms
		[0.0, Vector2.ONE, 0.0, Vector2.ONE, Vector2.ZERO, Vector2.ZERO, 0.001, "identity transform"],
		[0.0, Vector2.ONE, 0.0, Vector2.ONE, Vector2(8, 4), Vector2(8, 4), 0.001, "simple offset"],
		
		# Rotation cases
		[PI/2.0, Vector2.ONE, 0.0, Vector2.ONE, Vector2(16, 0), Vector2(0, 16), 0.001, "90deg rotation"],
		[PI, Vector2.ONE, 0.0, Vector2.ONE, Vector2(8, 8), Vector2(-8, -8), 0.001, "180deg rotation"],
		
		# Scaling cases
		[0.0, Vector2(2, 2), 0.0, Vector2.ONE, Vector2(4, 4), Vector2(8, 8), 0.001, "uniform 2x scaling"],
		[0.0, Vector2(2, 1), 0.0, Vector2.ONE, Vector2(4, 8), Vector2(8, 8), 0.001, "non-uniform scaling"],
		
		# Complex transforms
		[PI/4.0, Vector2(1.5, 1.5), PI/4.0, Vector2(0.5, 0.5), Vector2(8, 0), Vector2(8.485, 8.485), 0.01, "complex rotation+scale"],
	]
):
	# Setup: Create test objects with specified transforms
	var obj: Node2D = auto_free(Node2D.new())
	add_child(obj)
	obj.global_position = Vector2.ZERO
	obj.rotation = col_obj_rot
	obj.scale = col_obj_scale
	
	var shape_owner: Node2D = auto_free(Node2D.new())
	obj.add_child(shape_owner)
	shape_owner.position = shape_local_pos
	shape_owner.rotation = shape_rot
	shape_owner.scale = shape_scale
	
	# Act: Build transform
	var xform = CollisionGeometryUtils.build_shape_transform(obj, shape_owner)
	
	# Assert: Verify transform accuracy within tolerance
	if tolerance > 0.0:
		# Use component-wise comparison for floating point precision
		assert_float(xform.origin.x).append_failure_message(
			"Transform origin X mismatch for %s: expected %s, got %s" % [test_description, expected_origin.x, xform.origin.x]
		).is_equal_approx(expected_origin.x, tolerance)
		assert_float(xform.origin.y).append_failure_message(
			"Transform origin Y mismatch for %s: expected %s, got %s" % [test_description, expected_origin.y, xform.origin.y]
		).is_equal_approx(expected_origin.y, tolerance)
	else:
		# Exact comparison for perfect matches
		assert_vector(xform.origin).append_failure_message(
			"Transform origin mismatch for %s: expected %s, got %s" % [test_description, expected_origin, xform.origin]
		).is_equal(expected_origin)

## Test polygon-to-world conversion with various parent hierarchies
@warning_ignore("unused_parameter") 
func test_to_world_polygon_scenarios(
	polygon_local: PackedVector2Array,
	parent_pos: Vector2,
	parent_rot: float,
	parent_scale: Vector2,
	child_pos: Vector2,
	child_rot: float,
	expected_world_bounds_min: Vector2,
	expected_world_bounds_max: Vector2,
	test_description: String,
	test_parameters := [
		# Simple cases
		[
			PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]),
			Vector2.ZERO, 0.0, Vector2.ONE, Vector2.ZERO, 0.0,
			Vector2(-4, -4), Vector2(4, 4),
			"8x8 square at origin"
		],
		[
			PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]),
			Vector2(16, 16), 0.0, Vector2.ONE, Vector2.ZERO, 0.0,
			Vector2(12, 12), Vector2(20, 20),
			"8x8 square offset parent"
		],
		# Transform cases
		[
			PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]),
			Vector2.ZERO, PI/2.0, Vector2.ONE, Vector2.ZERO, 0.0,
			Vector2(-4, -4), Vector2(4, 4),
			"8x8 square parent rotated 90deg"
		],
		[
			PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]),
			Vector2.ZERO, 0.0, Vector2(2, 2), Vector2.ZERO, 0.0,
			Vector2(-4, -4), Vector2(4, 4),
			"4x4 square parent scaled 2x"
		]
	]
):
	# Setup: Create polygon hierarchy with specified transforms
	var parent: Node2D = auto_free(Node2D.new())
	add_child(parent)
	parent.global_position = parent_pos
	parent.rotation = parent_rot
	parent.scale = parent_scale
	
	var polygon_node: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	parent.add_child(polygon_node)
	polygon_node.position = child_pos
	polygon_node.rotation = child_rot
	polygon_node.polygon = polygon_local
	
	# Act: Convert to world coordinates
	var world_points = CollisionGeometryUtils.to_world_polygon(polygon_node)
	
	# Assert: Verify world bounds are correct
	assert_int(world_points.size()).is_greater(0).append_failure_message(
		"Expected non-empty world points for %s" % test_description
	)
	
	var actual_bounds = _compute_bounds(world_points)
	# Use component-wise comparison for floating point precision
	assert_float(actual_bounds.position.x).append_failure_message(
		"World bounds min X mismatch for %s: expected %s, got %s" % [test_description, expected_world_bounds_min.x, actual_bounds.position.x]
	).is_equal_approx(expected_world_bounds_min.x, 0.1)
	assert_float(actual_bounds.position.y).append_failure_message(
		"World bounds min Y mismatch for %s: expected %s, got %s" % [test_description, expected_world_bounds_min.y, actual_bounds.position.y]
	).is_equal_approx(expected_world_bounds_min.y, 0.1)
	
	var actual_max = actual_bounds.position + actual_bounds.size
	assert_float(actual_max.x).append_failure_message(
		"World bounds max X mismatch for %s: expected %s, got %s" % [test_description, expected_world_bounds_max.x, actual_max.x]
	).is_equal_approx(expected_world_bounds_max.x, 0.1)
	assert_float(actual_max.y).append_failure_message(
		"World bounds max Y mismatch for %s: expected %s, got %s" % [test_description, expected_world_bounds_max.y, actual_max.y]
	).is_equal_approx(expected_world_bounds_max.y, 0.1)

## Test compute_polygon_tile_offsets with comprehensive coverage scenarios
@warning_ignore("unused_parameter")
func test_compute_polygon_tile_offsets_comprehensive_scenarios(
	world_points: PackedVector2Array,
	tile_size: Vector2,
	center_tile: Vector2i,
	tile_type: int,
	expected_offsets: Array[Vector2i],
	test_description: String,
	test_parameters := [
		# Basic coverage cases
		[
			PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
			Vector2(16, 16), Vector2i(0, 0), 0,
			[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)],
			"16x16 square centered at origin, 2x2 tiles"
		],
		[
			PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]),
			Vector2(16, 16), Vector2i(1, 1), 0,
			[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)],
			"32x32 square offset from center tile"
		],
		# Edge cases - small polygons that cross tile boundaries
		[
			PackedVector2Array([Vector2(12, 12), Vector2(20, 12), Vector2(20, 20), Vector2(12, 20)]),
			Vector2(16, 16), Vector2i(1, 1), 0,
			[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)],
			"8x8 square at tile boundaries (exceeds 5% threshold)"
		],
		# L-shaped polygon (concave) - Only tiles with significant overlap (>5% area)
		[
			PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 16), Vector2(16, 16), Vector2(16, 32), Vector2(0, 32)]),
			Vector2(16, 16), Vector2i(1, 1), 0,
			[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1)],
			"L-shaped concave polygon"
		],
		# Empty polygon edge case
		[
			PackedVector2Array(),
			Vector2(16, 16), Vector2i(0, 0), 0,
			[],
			"empty polygon"
		]
	]
):
	# Act: Compute tile offsets
	var actual_offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, tile_type)
	
	# Assert: Verify offset counts and contents
	assert_int(actual_offsets.size()).is_equal(expected_offsets.size()).append_failure_message(
		"Offset count mismatch for %s: expected %d, got %d. Expected: %s, Actual: %s" % [
			test_description, expected_offsets.size(), actual_offsets.size(), expected_offsets, actual_offsets
		]
	)
	
	for expected_offset in expected_offsets:
		assert_bool(actual_offsets.has(expected_offset)).is_true().append_failure_message(
			"Missing expected offset %s for %s. Got offsets: %s" % [expected_offset, test_description, actual_offsets]
		)

## Test polygon convexity detection with various shapes
@warning_ignore("unused_parameter")
func test_is_polygon_convex_scenarios(
	polygon_points: PackedVector2Array,
	expected_convex: bool,
	test_description: String,
	test_parameters := [
		# Convex shapes
		[PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]), true, "square"],
		[PackedVector2Array([Vector2(0, 0), Vector2(5, -3), Vector2(10, 0), Vector2(5, 10)]), true, "diamond"],
		[PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 10)]), true, "triangle"],
		
		# Concave shapes
		[PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5), Vector2(5, 5), Vector2(5, 10), Vector2(0, 10)]), false, "L-shape"],
		[PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 5), Vector2(10, 10), Vector2(0, 10)]), false, "indented rectangle"],
		
		# Edge cases
		[PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]), true, "line (degenerate - always convex)"],
		[PackedVector2Array([Vector2(0, 0)]), true, "single point (always convex)"],
		[PackedVector2Array(), true, "empty polygon (trivially convex)"]
	]
):
	# Act: Test convexity detection
	var actual_convex = CollisionGeometryUtils.is_polygon_convex(polygon_points)
	
	# Assert: Verify convexity detection
	assert_bool(actual_convex).is_equal(expected_convex).append_failure_message(
		"Convexity detection failed for %s: expected %s, got %s" % [test_description, expected_convex, actual_convex]
	)

## Test tile type parameter behavior for different tilemap configurations
@warning_ignore("unused_parameter")
func test_tile_type_parameter_scenarios(
	tile_type: int,
	tile_size: Vector2,
	polygon_points: PackedVector2Array,
	expected_min_offsets: int,
	test_description: String,
	test_parameters := [
		# Square tiles (type 0)
		[0, Vector2(16, 16), PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]), 4, "square tiles 16x16"],
		[0, Vector2(32, 32), PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]), 4, "square tiles 32x32"],
		
		# Isometric tiles (type 1) - should still work with rectangular bounds
		[1, Vector2(16, 16), PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]), 4, "isometric tiles 16x16"],
	]
):
	# Act: Test with different tile types
	var offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(polygon_points, tile_size, Vector2i.ZERO, tile_type)
	
	# Assert: Verify tile type handling doesn't break functionality
	assert_int(offsets.size()).is_greater_equal(expected_min_offsets).append_failure_message(
		"Expected at least %d offsets for %s, got %d" % [expected_min_offsets, test_description, offsets.size()]
	)

## Test error handling and edge cases
func test_error_handling_edge_cases():
	# Test with very small tile size
	var tiny_offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(
		PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]),
		Vector2(0.1, 0.1),
		Vector2i.ZERO
	)
	assert_int(tiny_offsets.size()).is_greater_equal(0).append_failure_message(
		"Should handle tiny tile size gracefully"
	)
	
	# Test with very large center tile offset
	var large_offset = CollisionGeometryUtils.compute_polygon_tile_offsets(
		PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
		Vector2(16, 16),
		Vector2i(1000, 1000)
	)
	assert_int(large_offset.size()).is_greater_equal(0).append_failure_message(
		"Should handle large center tile offset gracefully"
	)

## Test area threshold consistency with PolygonTileMapper expectations
func test_area_threshold_consistency():
	# Test polygon that should pass 5% threshold (used by PolygonTileMapper for convex polygons)
	var polygon_8x8 = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	var offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(polygon_8x8, Vector2(16, 16), Vector2i.ZERO)
	
	# 8x8 = 64 sq units, 16x16 tile = 256 sq units, 64/256 = 25% > 5% threshold
	assert_int(offsets.size()).is_greater(0).append_failure_message(
		"8x8 polygon should pass 5% area threshold on 16x16 tiles (25% coverage)"
	)
	
	# Test very small polygon that should be filtered out
	var tiny_polygon = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	var tiny_offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(tiny_polygon, Vector2(16, 16), Vector2i.ZERO)
	
	# 1x1 = 1 sq unit, 16x16 tile = 256 sq units, 1/256 = 0.39% < 5% threshold
	assert_int(tiny_offsets.size()).is_equal(0).append_failure_message(
		"1x1 polygon should be filtered out by 5% area threshold (0.39% coverage)"
	)

## Helper function to compute polygon bounds
func _compute_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	
	var min_x = points[0].x
	var max_x = points[0].x
	var min_y = points[0].y
	var max_y = points[0].y
	
	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
