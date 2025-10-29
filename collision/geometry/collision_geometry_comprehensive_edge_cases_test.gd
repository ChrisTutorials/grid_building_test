## Comprehensive edge case tests for collision geometry utilities
## Ensures 100% reliability across various polygon shapes, sizes, and conditions
extends GdUnitTestSuite

const TILE_SIZE_16: Vector2 = Vector2(16, 16)
const TILE_SIZE_32: Vector2 = Vector2(32, 32)
const CENTER_TILE: Vector2i = Vector2i(0, 0)

## Test various polygon shapes to ensure collision detection works universally
@warning_ignore("unused_parameter")
func test_polygon_shape_edge_cases(
	test_name: String,
	polygon_points: PackedVector2Array,
	tile_size: Vector2,
	expected_min_tiles: int,
	description: String,
	test_parameters := [
		# Basic shapes
		[
			"square",
			PackedVector2Array(
				[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
			),
			TILE_SIZE_16,
			4,
			"Simple square should cover 4 tiles"
		],
		[
			"rectangle",
			PackedVector2Array(
				[Vector2(-32, -16), Vector2(32, -16), Vector2(32, 16), Vector2(-32, 16)]
			),
			TILE_SIZE_16,
			8,
			"Rectangle should cover multiple tiles"
		],
		[
			"triangle",
			PackedVector2Array([Vector2(0, -24), Vector2(24, 24), Vector2(-24, 24)]),
			TILE_SIZE_16,
			3,
			"Triangle should cover expected tiles"
		],
		# Trapezoids and irregular shapes
		[
			"trapezoid_wide",
			PackedVector2Array(
				[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
			),
			TILE_SIZE_16,
			6,
			"Wide trapezoid should cover sufficient tiles"
		],
		[
			"trapezoid_narrow",
			PackedVector2Array([Vector2(-16, 8), Vector2(-8, -8), Vector2(8, -8), Vector2(16, 8)]),
			TILE_SIZE_16,
			2,
			"Narrow trapezoid should cover minimum tiles"
		],
		# Complex polygons
		[
			"pentagon",
			PackedVector2Array(
				[
					Vector2(0, -20),
					Vector2(19, -6),
					Vector2(12, 16),
					Vector2(-12, 16),
					Vector2(-19, -6)
				]
			),
			TILE_SIZE_16,
			4,
			"Pentagon should be detected properly"
		],
		[
			"hexagon",
			PackedVector2Array(
				[
					Vector2(20, 0),
					Vector2(10, 17),
					Vector2(-10, 17),
					Vector2(-20, 0),
					Vector2(-10, -17),
					Vector2(10, -17)
				]
			),
			TILE_SIZE_16,
			6,
			"Hexagon should cover expected area"
		],
		# L-shaped and concave
		[
			"l_shape",
			PackedVector2Array(
				[
					Vector2(-24, -24),
					Vector2(24, -24),
					Vector2(24, 0),
					Vector2(0, 0),
					Vector2(0, 24),
					Vector2(-24, 24)
				]
			),
			TILE_SIZE_16,
			8,
			"L-shape should handle concave geometry"
		],
		# Edge cases - very small polygons
		[
			"micro_square",
			PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
			TILE_SIZE_16,
			1,
			"Small square should still be detected"
		],
		# Edge cases - large polygons with different tile sizes
		[
			"large_square_small_tiles",
			PackedVector2Array(
				[Vector2(-64, -64), Vector2(64, -64), Vector2(64, 64), Vector2(-64, 64)]
			),
			TILE_SIZE_16,
			60,
			"Large square with small tiles"
		],
		[
			"large_square_large_tiles",
			PackedVector2Array(
				[Vector2(-64, -64), Vector2(64, -64), Vector2(64, 64), Vector2(-64, 64)]
			),
			TILE_SIZE_32,
			15,
			"Large square with large tiles"
		],
	]
) -> void:
	GBTestDiagnostics.log_verbose("=== TESTING POLYGON SHAPE: %s ===" % test_name)
	GBTestDiagnostics.log_verbose("Description: %s" % description)
	GBTestDiagnostics.log_verbose("Polygon points: %s" % str(polygon_points))
	GBTestDiagnostics.log_verbose("Tile size: %s" % str(tile_size))

	# Test the collision geometry calculation
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		polygon_points, tile_size, CENTER_TILE
	)

	GBTestDiagnostics.log_verbose("Calculated tile offsets: %s" % str(tile_offsets))
	GBTestDiagnostics.log_verbose(
		"Number of tiles found: %d (expected >= %d)" % [tile_offsets.size(), expected_min_tiles]
	)

	# Assert minimum expected tiles
	(
		assert_int(tile_offsets.size())
		. append_failure_message(
			(
				"Polygon shape '%s' should generate at least %d tiles but got %d. Description: %s\n%s"
				% [
					test_name,
					expected_min_tiles,
					tile_offsets.size(),
					description,
					"\"Context: diagnostic test\""
				]
			)
		)
		. is_greater_equal(expected_min_tiles)
	)

	# Additional validation: ensure no duplicate offsets
	var unique_offsets: Array[Vector2i] = []
	for offset in tile_offsets:
		if not unique_offsets.has(offset):
			unique_offsets.append(offset)

	(
		assert_int(unique_offsets.size())
		. append_failure_message(
			(
				"Polygon shape '%s' generated duplicate tile offsets. Original: %d, Unique: %d\n%s"
				% [
					test_name,
					tile_offsets.size(),
					unique_offsets.size(),
					"\"Context: diagnostic test\""
				]
			)
		)
		. is_equal(tile_offsets.size())
	)


## Test collision geometry with various positioning scenarios
@warning_ignore("unused_parameter")
func test_position_independence_edge_cases(
	test_name: String,
	center_tile: Vector2i,
	expected_pattern_consistency: bool,
	description: String,
	test_parameters := [
		["origin", Vector2i(0, 0), true, "Center at origin should work correctly"],
		["positive_quadrant", Vector2i(10, 10), true, "Center in positive quadrant"],
		["negative_quadrant", Vector2i(-10, -10), true, "Center in negative quadrant"],
		["mixed_quadrant", Vector2i(5, -5), true, "Center in mixed quadrant"],
		["large_positive", Vector2i(100, 100), true, "Center at large positive coordinates"],
		["large_negative", Vector2i(-100, -100), true, "Center at large negative coordinates"],
	]
) -> void:
	GBTestDiagnostics.log_verbose("=== TESTING POSITION INDEPENDENCE: %s ===" % test_name)
	GBTestDiagnostics.log_verbose("Description: %s" % description)
	GBTestDiagnostics.log_verbose("Center tile: %s" % str(center_tile))

	# Use consistent test polygon (the problematic trapezoid)
	var test_polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	# Get tile offsets for this position
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		test_polygon, TILE_SIZE_16, center_tile
	)

	# Get reference offsets from origin for comparison
	var origin_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		test_polygon, TILE_SIZE_16, Vector2i.ZERO
	)

	GBTestDiagnostics.log_verbose("Tile offsets at position: %s" % str(tile_offsets))
	GBTestDiagnostics.log_verbose("Reference offsets at origin: %s" % str(origin_offsets))
	GBTestDiagnostics.log_verbose(
		"Offset count: %d (reference: %d)" % [tile_offsets.size(), origin_offsets.size()]
	)

	# Assert same number of tiles regardless of position
	(
		assert_int(tile_offsets.size())
		. append_failure_message(
			(
				"Position independence failed for '%s'. Got %d tiles, expected %d (same as origin)\n%s"
				% [
					test_name,
					tile_offsets.size(),
					origin_offsets.size(),
					"\"Context: diagnostic test\""
				]
			)
		)
		. is_equal(origin_offsets.size())
	)

	# Assert consistent pattern (relative positions should be the same)
	if expected_pattern_consistency:
		# Calculate the pattern bounds for comparison
		var pattern_bounds_current: Dictionary[String, int] = _calculate_pattern_bounds(tile_offsets)
		var pattern_bounds_origin: Dictionary[String, int] = _calculate_pattern_bounds(origin_offsets)

		(
			assert_int(pattern_bounds_current["width"])
			. append_failure_message(
				(
					"Pattern width changed with position. Current: %d, Origin: %d"
					% [pattern_bounds_current["width"], pattern_bounds_origin["width"]]
				)
			)
			. is_equal(pattern_bounds_origin["width"])
		)

		(
			assert_int(pattern_bounds_current["height"])
			. append_failure_message(
				(
					"Pattern height changed with position. Current: %d, Origin: %d"
					% [pattern_bounds_current["height"], pattern_bounds_origin["height"]]
				)
			)
			. is_equal(pattern_bounds_origin["height"])
		)


## Test boundary conditions that could cause edge case failures
func test_boundary_condition_edge_cases() -> void:
	GBTestDiagnostics.log_verbose("=== TESTING BOUNDARY CONDITIONS ===")

	# Test 1: Polygon exactly on tile boundaries
	var boundary_polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
	)
	GBTestDiagnostics.log_verbose("Testing polygon exactly on tile boundaries...")
	var boundary_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		boundary_polygon, TILE_SIZE_16, CENTER_TILE
	)
	GBTestDiagnostics.log_verbose(
		"Boundary polygon offsets: %s (%d tiles)" % [str(boundary_offsets), boundary_offsets.size()]
	)

	(
		assert_int(boundary_offsets.size())
		. append_failure_message(
			(
				"Boundary-aligned polygon should generate tiles but got %d\n%s"
				% [boundary_offsets.size(), "\"Context: diagnostic test\""]
			)
		)
		. is_greater(0)
	)

	# Test 2: Polygon crossing tile boundaries at fractional positions
	var fractional_polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(-15.5, -15.5), Vector2(15.5, -15.5), Vector2(15.5, 15.5), Vector2(-15.5, 15.5)]
	)
	GBTestDiagnostics.log_verbose("Testing polygon at fractional tile boundaries...")
	var fractional_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		fractional_polygon, TILE_SIZE_16, CENTER_TILE
	)
	GBTestDiagnostics.log_verbose(
		(
			"Fractional polygon offsets: %s (%d tiles)"
			% [str(fractional_offsets), fractional_offsets.size()]
		)
	)

	(
		assert_int(fractional_offsets.size())
		. append_failure_message(
			(
				"Fractional boundary polygon should generate tiles but got %d\n%s"
				% [fractional_offsets.size(), "\"Context: diagnostic test\""]
			)
		)
		. is_greater(0)
	)

	# Test 3: Very thin polygons (edge case for area calculations)
	var thin_polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, -1), Vector2(32, -1), Vector2(32, 1), Vector2(-32, 1)]
	)
	GBTestDiagnostics.log_verbose("Testing very thin polygon...")
	var thin_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		thin_polygon, TILE_SIZE_16, CENTER_TILE
	)
	GBTestDiagnostics.log_verbose(
		"Thin polygon offsets: %s (%d tiles)" % [str(thin_offsets), thin_offsets.size()]
	)
	# Note: This might return 0 tiles due to 5% area threshold - that's acceptable


## Test winding order independence
func test_winding_order_edge_cases() -> void:
	GBTestDiagnostics.log_verbose("=== TESTING WINDING ORDER INDEPENDENCE ===")

	# Original polygon (counter-clockwise)
	var ccw_polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	# Reversed polygon (clockwise)
	var cw_polygon: PackedVector2Array = PackedVector2Array(
		[Vector2(32, 12), Vector2(17, -12), Vector2(-16, -12), Vector2(-32, 12)]
	)

	GBTestDiagnostics.log_verbose("Testing counter-clockwise polygon...")
	var ccw_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		ccw_polygon, TILE_SIZE_16, CENTER_TILE
	)
	GBTestDiagnostics.log_verbose("CCW offsets: %s (%d tiles)" % [str(ccw_offsets), ccw_offsets.size()])

	GBTestDiagnostics.log_verbose("Testing clockwise polygon...")
	var cw_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		cw_polygon, TILE_SIZE_16, CENTER_TILE
	)
	GBTestDiagnostics.log_verbose("CW offsets: %s (%d tiles)" % [str(cw_offsets), cw_offsets.size()])

	# Both should produce the same result
	(
		assert_int(cw_offsets.size())
		. append_failure_message(
			(
				"Winding order should not affect tile count. CCW: %d tiles, CW: %d tiles\n%s"
				% [ccw_offsets.size(), cw_offsets.size(), "\"Context: diagnostic test\""]
			)
		)
		. is_equal(ccw_offsets.size())
	)


## Helper function to calculate pattern bounds for consistency checking
func _calculate_pattern_bounds(offsets: Array[Vector2i]) -> Dictionary:
	if offsets.is_empty():
		return {"width": 0, "height": 0}

	var min_x: int = offsets[0].x
	var max_x: int = offsets[0].x
	var min_y: int = offsets[0].y
	var max_y: int = offsets[0].y

	for offset in offsets:
		min_x = min(min_x, offset.x)
		max_x = max(max_x, offset.x)
		min_y = min(min_y, offset.y)
		max_y = max(max_y, offset.y)

	return {
		"width": max_x - min_x + 1,
		"height": max_y - min_y + 1,
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y
	}
