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
	# These are the EXACT values from the runtime that are failing
	var runtime_trapezoid: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12),
		Vector2(-16, -12),
		Vector2(17, -12),
		Vector2(32, 12)
	])
	var runtime_position: Vector2 = Vector2(440, 552)
	var tile_size: Vector2 = Vector2(16, 16)

	# Convert runtime position to center tile coordinate
	var center_tile: Vector2i = Vector2i(
		int(runtime_position.x / tile_size.x),
		int(runtime_position.y / tile_size.y)
	)

	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] === RUNTIME TRAPEZOID CALCULATION BUG ===")
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Trapezoid polygon: %s" % [str(runtime_trapezoid)])
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Position: %s" % [str(runtime_position)])
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Tile size: %s" % [str(tile_size)])
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Center tile: %s" % [str(center_tile)])

	# This is the call that's failing in the runtime integration - FIXED parameter order
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		runtime_trapezoid, tile_size, center_tile
	)

	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Calculated tile offsets: %s" % [str(tile_offsets)])
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Number of offsets: %d" % [tile_offsets.size()])

	# The bug: This should return > 0 tiles but currently returns 0
	if tile_offsets.size() == 0:
		GBTestDiagnostics.buffer("[BUG_REPRODUCTION] >>> BUG CONFIRMED: No tile offsets calculated!")
		GBTestDiagnostics.buffer("[BUG_REPRODUCTION] >>> This explains why bottom corner indicators are missing")
	else:
		GBTestDiagnostics.buffer("[BUG_REPRODUCTION] >>> Tile offsets found, checking for missing extensions:")
		var expected_missing: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1)]
		for missing_tile in expected_missing:
			if not tile_offsets.has(missing_tile):
				GBTestDiagnostics.buffer("[BUG_REPRODUCTION] >>> Missing expected tile: %s" % [str(missing_tile)])

	# Let's also test with position at origin to see if it's a position offset issue
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Testing with origin position...")
	var origin_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		runtime_trapezoid, tile_size, Vector2i.ZERO
	)
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Origin position offsets: %s" % [str(origin_offsets)])
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Origin position count: %d" % [origin_offsets.size()])

	# Test with different tile sizes
	GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Testing with different tile sizes...")
	var different_tile_sizes: Array[Vector2] = [
		Vector2(8, 8),    # Smaller tiles
		Vector2(32, 32),  # Larger tiles
		Vector2(1, 1)     # Tiny tiles for maximum coverage
	]

	for test_tile_size in different_tile_sizes:
		var size_test_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
			runtime_trapezoid, test_tile_size, Vector2i.ZERO
		)
		GBTestDiagnostics.buffer("[BUG_REPRODUCTION] Tile size %s: %d offsets" % [str(test_tile_size), size_test_offsets.size()])

	# This test should expose the root cause of the runtime issue
	assert_int(tile_offsets.size()).append_failure_message(
		"Runtime trapezoid should generate tile offsets but returned 0. " +
		"This is the root cause of missing bottom corner indicators in the demo."
	).is_greater(0)

## Test if the issue is coordinate system or transformation related
func test_coordinate_system_analysis() -> void:
	GBTestDiagnostics.buffer("[COORD_ANALYSIS] === COORDINATE SYSTEM ANALYSIS ===")

	# Test with the exact runtime trapezoid
	var runtime_trapezoid: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12),
		Vector2(-16, -12),
		Vector2(17, -12),
		Vector2(32, 12)
	])

	# Test various positions to see if it's position-dependent
	var test_positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(100, 100),
		Vector2(440, 552),  # Runtime position
		Vector2(-440, -552),  # Negative runtime position
	]

	for pos in test_positions:
		# Convert position to center tile
		var test_center_tile: Vector2i = Vector2i(
			int(pos.x / 16), int(pos.y / 16)
		)
		var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
			runtime_trapezoid, Vector2(16, 16), test_center_tile
		)
		GBTestDiagnostics.buffer("[COORD_ANALYSIS] Position %s: %d tiles" % [str(pos), offsets.size()])

		if offsets.size() > 0:
			# Find the bounds of calculated tiles
			var min_x: int = offsets[0].x
			var max_x: int = offsets[0].x
			var min_y: int = offsets[0].y
			var max_y: int = offsets[0].y

			for offset in offsets:
				min_x = min(min_x, offset.x)
				max_x = max(max_x, offset.x)
				min_y = min(min_y, offset.y)
				max_y = max(max_y, offset.y)

				GBTestDiagnostics.buffer("[COORD_ANALYSIS]   Tile bounds: x=[%d, %d], y=[%d, %d]" % [min_x, max_x, min_y, max_y])
				GBTestDiagnostics.buffer("[COORD_ANALYSIS]   Expected missing tiles (-2,1), (2,1) in bounds? x_check=%s, y_check=%s" % [
					str(min_x <= -2 and max_x >= 2),
					str(min_y <= 1 and max_y >= 1)
				])

## Test if the issue is polygon winding or shape validity
func test_polygon_validity_analysis() -> void:
	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] === POLYGON VALIDITY ANALYSIS ===")

	var runtime_trapezoid: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12),
		Vector2(-16, -12),
		Vector2(17, -12),
		Vector2(32, 12)
	])

	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Polygon points: %s" % [str(runtime_trapezoid)])

	# Check polygon winding order
	var area: float = 0.0
	var n: int = runtime_trapezoid.size()
	for i in range(n):
		var j: int = (i + 1) % n
		area += runtime_trapezoid[i].x * runtime_trapezoid[j].y
		area -= runtime_trapezoid[j].x * runtime_trapezoid[i].y
	area /= 2.0

	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Polygon area: %f" % [area])
	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Winding order: %s" % [("counter-clockwise" if area > 0 else "clockwise")])

	# Test if reversing winding fixes the issue
	var reversed_trapezoid: PackedVector2Array = PackedVector2Array()
	for i in range(runtime_trapezoid.size() - 1, -1, -1):
		reversed_trapezoid.append(runtime_trapezoid[i])

	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Testing reversed winding: %s" % [str(reversed_trapezoid)])
	var reversed_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		reversed_trapezoid, Vector2(16, 16), Vector2i.ZERO
	)
	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Reversed polygon offsets: %d tiles" % [reversed_offsets.size()])

	if reversed_offsets.size() > 0:
		GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] >>> WINDING ORDER ISSUE: Reversed polygon works!")
		GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Reversed tiles: %s" % [str(reversed_offsets)])

	# Check if the polygon is self-intersecting or malformed
	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Checking polygon bounds...")
	var min_x: float = runtime_trapezoid[0].x
	var max_x: float = runtime_trapezoid[0].x
	var min_y: float = runtime_trapezoid[0].y
	var max_y: float = runtime_trapezoid[0].y

	for point in runtime_trapezoid:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Polygon bounds: x=[%f, %f], y=[%f, %f]" % [min_x, max_x, min_y, max_y])
	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Polygon dimensions: %f x %f" % [max_x - min_x, max_y - min_y])

	# Expected tile coverage with 16x16 tiles
	var expected_tiles_x: int = int((max_x - min_x) / 16.0) + 1
	var expected_tiles_y: int = int((max_y - min_y) / 16.0) + 1
	GBTestDiagnostics.buffer("[POLYGON_ANALYSIS] Expected tile coverage: ~%d x %d = %d tiles" % [
		expected_tiles_x, expected_tiles_y, expected_tiles_x * expected_tiles_y
	])

	# Ensure diagnostics are attached to failing assertions
	assert_bool(true).is_true().append_failure_message(GBTestDiagnostics.flush_for_assert())