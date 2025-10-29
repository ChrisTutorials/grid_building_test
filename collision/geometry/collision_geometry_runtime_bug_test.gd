## Unit test specifically targeting the CollisionGeometryUtils.compute_polygon_tile_offsets issue
## discovered through integration testing. This test reproduces the exact conditions
## from the runtime where tile offset calculation returns 0 results.
extends GdUnitTestSuite


func before_test() -> void:
	# Enable detailed polygon overlap debug so calculator prints diagnostics for "no tiles" cases
	CollisionGeometryCalculator.debug_polygon_overlap = true


func after_test() -> void:
	# Reset the debug gate to avoid noisy output in other tests
	CollisionGeometryCalculator.debug_polygon_overlap = false


## Test the exact runtime trapezoid issue in isolation
func test_runtime_trapezoid_collision_calculation_bug() -> void:
	var diag: PackedStringArray = PackedStringArray()

	# These are the EXACT values from the runtime that are failing
	var runtime_trapezoid: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)
	var runtime_position: Vector2 = Vector2(440, 552)
	var tile_size: Vector2 = Vector2(16, 16)

	# Convert runtime position to center tile coordinate
	var center_tile: Vector2i = Vector2i(
		int(runtime_position.x / tile_size.x), int(runtime_position.y / tile_size.y)
	)

	diag.append("[BUG_REPRODUCTION] === RUNTIME TRAPEZOID CALCULATION BUG ===")
	diag.append("[BUG_REPRODUCTION] Trapezoid polygon: %s" % [str(runtime_trapezoid)])
	diag.append("[BUG_REPRODUCTION] Position: %s" % [str(runtime_position)])
	diag.append("[BUG_REPRODUCTION] Tile size: %s" % [str(tile_size)])
	diag.append("[BUG_REPRODUCTION] Center tile: %s" % [str(center_tile)])

	# This is the call that's failing in the runtime integration - FIXED parameter order
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		runtime_trapezoid, tile_size, center_tile
	)

	diag.append("[BUG_REPRODUCTION] Calculated tile offsets: %s" % [str(tile_offsets)])
	diag.append("[BUG_REPRODUCTION] Number of offsets: %d" % [tile_offsets.size()])

	# The bug: This should return > 0 tiles but currently returns 0
	if tile_offsets.size() == 0:
		diag.append("[BUG_REPRODUCTION] >>> BUG CONFIRMED: No tile offsets calculated!")
		diag.append("[BUG_REPRODUCTION] >>> This explains why bottom corner indicators are missing")
	else:
		diag.append("[BUG_REPRODUCTION] >>> Tile offsets found, checking for missing extensions:")
		var expected_missing: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1)]
		for missing_tile in expected_missing:
			if not tile_offsets.has(missing_tile):
				diag.append(
					"[BUG_REPRODUCTION] >>> Missing expected tile: %s" % [str(missing_tile)]
				)

	# Let's also test with position at origin to see if it's a position offset issue
	diag.append("[BUG_REPRODUCTION] Testing with origin position...")
	var origin_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		runtime_trapezoid, tile_size, Vector2i.ZERO
	)
	diag.append("[BUG_REPRODUCTION] Origin position offsets: %s" % [str(origin_offsets)])
	diag.append("[BUG_REPRODUCTION] Origin position count: %d" % [origin_offsets.size()])

	# Test with different tile sizes
	diag.append("[BUG_REPRODUCTION] Testing with different tile sizes...")
	var different_tile_sizes: Array[Vector2] = [Vector2(8, 8), Vector2(32, 32), Vector2(1, 1)]  # Smaller tiles  # Larger tiles  # Tiny tiles for maximum coverage

	for test_tile_size in different_tile_sizes:
		var size_test_offsets: Array[Vector2i] = (
			CollisionGeometryUtils
			. compute_polygon_tile_offsets(runtime_trapezoid, test_tile_size, Vector2i.ZERO)
		)
		diag.append(
			(
				"[BUG_REPRODUCTION] Tile size %s: %d offsets"
				% [str(test_tile_size), size_test_offsets.size()]
			)
		)

	# This test should expose the root cause of the runtime issue
	(
		assert_int(tile_offsets.size())
		. append_failure_message(
			(
				"Runtime trapezoid should generate tile offsets but returned 0. "
				+ (
					"This is the root cause of missing bottom corner indicators in the demo.\n\nDiagnostics:\n%s"
					% "\n".join(diag)
				)
			)
		)
		. is_greater(0)
	)


## Test if the issue is coordinate system or transformation related
func test_coordinate_system_analysis() -> void:
	var diag: PackedStringArray = PackedStringArray()
	diag.append("[COORD_ANALYSIS] === COORDINATE SYSTEM ANALYSIS ===")

	# Test with the exact runtime trapezoid
	var runtime_trapezoid: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	# Test various positions to see if it's position-dependent
	var test_positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(100, 100),
		Vector2(440, 552),  # Runtime position
		Vector2(-440, -552),  # Negative runtime position
	]

	for pos in test_positions:
		# Convert position to center tile
		var test_center_tile: Vector2i = Vector2i(int(pos.x / 16), int(pos.y / 16))
		var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
			runtime_trapezoid, Vector2(16, 16), test_center_tile
		)
		diag.append("[COORD_ANALYSIS] Position %s: %d tiles" % [str(pos), offsets.size()])
		# continue collecting diagnostics

	# After analyzing all positions, assert we observed at least one tile offset
	var total_offsets: int = 0
	for pos in test_positions:
		var center_tile: Vector2i = Vector2i(int(pos.x / 16), int(pos.y / 16))
		var offsets_here: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
			runtime_trapezoid, Vector2(16, 16), center_tile
		)
		total_offsets += offsets_here.size()

	(
		assert_int(total_offsets)
		. append_failure_message(
			(
				"Coordinate system analysis produced no tile offsets.\nDiagnostics:\n%s"
				% "\n".join(diag)
			)
		)
		. is_greater(0)
	)


## Test if the issue is polygon winding or shape validity
func test_polygon_validity_analysis() -> void:
	var diag: PackedStringArray = PackedStringArray()
	diag.append("[POLYGON_ANALYSIS] === POLYGON VALIDITY ANALYSIS ===")

	var runtime_trapezoid: PackedVector2Array = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	diag.append("[POLYGON_ANALYSIS] Polygon points: %s" % [str(runtime_trapezoid)])

	# Check polygon winding order
	var area: float = 0.0
	var n: int = runtime_trapezoid.size()
	for i in range(n):
		var j: int = (i + 1) % n
		area += runtime_trapezoid[i].x * runtime_trapezoid[j].y
		area -= runtime_trapezoid[j].x * runtime_trapezoid[i].y
	area /= 2.0

	diag.append("[POLYGON_ANALYSIS] Polygon area: %f" % [area])
	diag.append(
		"[POLYGON_ANALYSIS] Winding order: %s" % ["counter-clockwise" if area > 0 else "clockwise"]
	)

	# Test if reversing winding fixes the issue
	var reversed_trapezoid: PackedVector2Array = PackedVector2Array()
	for i in range(runtime_trapezoid.size() - 1, -1, -1):
		reversed_trapezoid.append(runtime_trapezoid[i])

	diag.append("[POLYGON_ANALYSIS] Testing reversed winding: %s" % [str(reversed_trapezoid)])
	var reversed_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		reversed_trapezoid, Vector2(16, 16), Vector2i.ZERO
	)
	diag.append("[POLYGON_ANALYSIS] Reversed polygon offsets: %d tiles" % [reversed_offsets.size()])

	if reversed_offsets.size() > 0:
		diag.append("[POLYGON_ANALYSIS] >>> WINDING ORDER ISSUE: Reversed polygon works!")
		diag.append("[POLYGON_ANALYSIS] Reversed tiles: %s" % [str(reversed_offsets)])

	# Check if the polygon is self-intersecting or malformed
	diag.append("[POLYGON_ANALYSIS] Checking polygon bounds...")
	var min_x: float = runtime_trapezoid[0].x
	var max_x: float = runtime_trapezoid[0].x
	var min_y: float = runtime_trapezoid[0].y
	var max_y: float = runtime_trapezoid[0].y

	for point in runtime_trapezoid:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	diag.append(
		"[POLYGON_ANALYSIS] Polygon bounds: x=[%f, %f], y=[%f, %f]" % [min_x, max_x, min_y, max_y]
	)
	diag.append("[POLYGON_ANALYSIS] Polygon dimensions: %f x %f" % [max_x - min_x, max_y - min_y])

	# Expected tile coverage with 16x16 tiles
	var expected_tiles_x: int = int((max_x - min_x) / 16.0) + 1
	var expected_tiles_y: int = int((max_y - min_y) / 16.0) + 1
	diag.append(
		(
			"[POLYGON_ANALYSIS] Expected tile coverage: ~%d x %d = %d tiles"
			% [expected_tiles_x, expected_tiles_y, expected_tiles_x * expected_tiles_y]
		)
	)

	# Final assertion: polygon area should be non-zero (sanity check) and include diagnostics on failure
	(
		assert_float(area)
		. append_failure_message(
			(
				"Polygon validity analysis failed or produced unexpected area.\nDiagnostics:\n%s"
				% "\n".join(diag)
			)
		)
		. is_not_equal(0.0)
	)
