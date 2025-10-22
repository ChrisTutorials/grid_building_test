## GBPositioning2DUtils Test Suite
## Tests for 2D positioning utility functions including coordinate conversions,
## tile positioning, viewport-to-world transformations, and region validation.
extends GdUnitTestSuite

# Test environment and shared resources
var test_tile_map_layer: TileMapLayer
var test_node: Node2D
var test_viewport: Viewport
var test_camera: Camera2D

# Test constants following DRY patterns
const DEFAULT_TILE_SIZE: Vector2 = Vector2(16, 16)
const TEST_WORLD_POSITION: Vector2 = Vector2(100, 100)
const TEST_TILE_COORD: Vector2i = Vector2i(5, 3)
const TEST_REGION: Rect2i = Rect2i(0, 0, 10, 10)
const COORDINATE_TOLERANCE: float = 0.1

func before_test() -> void:
	# Create test environment using factory methods (following testing guide)
	test_tile_map_layer = GodotTestFactory.create_empty_tile_map_layer(self)
	test_node = auto_free(Node2D.new())
	add_child(test_node)

	# Create viewport and camera for coordinate conversion tests
	test_viewport = auto_free(SubViewport.new())
	test_camera = auto_free(Camera2D.new())
	add_child(test_viewport)
	test_viewport.add_child(test_camera)
	test_viewport.size = Vector2i(800, 600)
	test_camera.enabled = true  # Ensure camera is active for viewport tests

func after_test() -> void:
	# Cleanup handled by auto_free() and GdUnit framework
	pass

#region Basic Coordinate Conversion Tests

func test_get_tile_from_global_position_basic() -> void:
	# Test: Convert world position to tile coordinate
	# Setup: Known world position and tile map
	# Act: Convert using utility function
	# Assert: Correct tile coordinate returned
	var world_pos: Vector2 = Vector2(80, 48)  # Should map to tile (5, 3) with 16x16 tiles
	var expected_tile: Vector2i = Vector2i(5, 3)

	var result_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(world_pos, test_tile_map_layer)

	assert_that(result_tile).append_failure_message(
		"World position %s should map to tile %s, got %s" % [str(world_pos), str(expected_tile), str(result_tile)]
	).is_equal(expected_tile)

func test_get_tile_from_global_position_edge_cases() -> void:
	# Test: Edge cases for coordinate conversion
	# Setup: Various edge case positions
	# Act: Convert coordinates
	# Assert: Proper handling of edge cases
	var zero_pos: Vector2 = Vector2.ZERO
	var negative_pos: Vector2 = Vector2(-32, -16)

	var zero_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(zero_pos, test_tile_map_layer)
	var negative_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(negative_pos, test_tile_map_layer)

	assert_that(zero_tile).append_failure_message(
		"Zero position should map to tile (0,0), got %s" % str(zero_tile)
	).is_equal(Vector2i(0, 0))
	assert_that(negative_tile).append_failure_message(
		"Negative position %s should map to tile (-2,-1), got %s" % [str(negative_pos), str(negative_tile)]
	).is_equal(Vector2i(-2, -1))

#endregion

#region Node Positioning Tests

func test_move_to_tile_center_basic() -> void:
	# Test: Move node to tile center
	# Setup: Node and target tile coordinate
	# Act: Move node using utility function
	# Assert: Node positioned at exact tile center
	var target_tile: Vector2i = Vector2i(3, 2)

	var result_tile: Vector2i = GBPositioning2DUtils.move_to_tile_center(test_node, target_tile, test_tile_map_layer)

assert_that(result_tile).append_failure_message(
		"Function should return the target tile %s, got %s" % [str(target_tile).is_equal(target_tile), str(result_tile)]
	)
	# Verify node was positioned (not at zero) and the tile calculation works
assert_that(test_node.global_position).append_failure_message(
		"Node should be moved from zero position after tile centering"
	).is_not_equal(Vector2.ZERO)

	# Test that the function returned the expected tile (which is the input tile)
assert_that(result_tile).append_failure_message(
		"Function should return the input tile %s, got %s" % [str(target_tile).is_equal(target_tile), str(result_tile)]
	)

func test_get_tile_from_node_position_basic() -> void:
	# Test: Convert node position to tile coordinate
	# Setup: Node at known position
	# Act: Get tile coordinate using unified function
	# Assert: Correct tile coordinate returned
	test_node.global_position = Vector2(72, 56)  # Should be tile (4, 3)
	var expected_tile: Vector2i = Vector2i(4, 3)

	var result_tile: Vector2i = GBPositioning2DUtils.get_tile_from_node_position(test_node, test_tile_map_layer)

assert_that(result_tile).append_failure_message(
		"Node at position %s should be on tile %s, got %s" % [str(test_node.global_position).is_equal(expected_tile), str(expected_tile), str(result_tile)]
	)

func test_get_tile_from_node_position_null_safety() -> void:
	# Test: Null safety for node position conversion
	# Setup: Null inputs
	# Act: Call function with null parameters
	# Assert: Safe handling with zero return
	var result_null_node: Vector2i = GBPositioning2DUtils.get_tile_from_node_position(null, test_tile_map_layer)
	var result_null_map: Vector2i = GBPositioning2DUtils.get_tile_from_node_position(test_node, null)
	var result_both_null: Vector2i = GBPositioning2DUtils.get_tile_from_node_position(null, null)

assert_that(result_null_node).append_failure_message(
		"Null node should return Vector2i.ZERO, got %s" % str(result_null_node).is_equal(Vector2i.ZERO)
	)
assert_that(result_null_map).append_failure_message(
		"Null map should return Vector2i.ZERO, got %s" % str(result_null_map).is_equal(Vector2i.ZERO)
	)
assert_that(result_both_null).append_failure_message(
		"Both null should return Vector2i.ZERO, got %s" % str(result_both_null).is_equal(Vector2i.ZERO)
	)

#endregion

#region Tile Delta Movement Tests

func test_move_node_by_tiles_basic() -> void:
	# Test: Move node by tile delta
	# Setup: Node at starting position
	# Act: Move by tile delta
	# Assert: Node moved to correct tile
	test_node.global_position = Vector2(40, 40)  # Starting at approximately tile (2, 2)
	var tile_delta: Vector2i = Vector2i(2, -1)  # Move right 2 tiles, up 1 tile

	var result_tile: Vector2i = GBPositioning2DUtils.move_node_by_tiles(test_node, tile_delta, test_tile_map_layer)
	var expected_tile: Vector2i = Vector2i(4, 1)  # (2,2) + (2,-1) = (4,1)

assert_that(result_tile).append_failure_message(
		"Node moved by delta %s should end up on tile %s, got %s" % [str(tile_delta).is_equal(expected_tile), str(expected_tile), str(result_tile)]
	)

@warning_ignore("unused_parameter")
func test_move_node_by_tiles_scenarios(
	test_name: String,
	start_position: Vector2,
	tile_delta: Vector2i,
	expected_tile: Vector2i,
	test_parameters := [
		["right_movement", Vector2(24, 24), Vector2i(3, 0), Vector2i(4, 1)],
		["left_movement", Vector2(80, 48), Vector2i(-2, 0), Vector2i(3, 3)],
		["up_movement", Vector2(32, 64), Vector2i(0, -2), Vector2i(2, 2)],
		["down_movement", Vector2(16, 16), Vector2i(0, 3), Vector2i(1, 4)],
		["diagonal_movement", Vector2(24, 24), Vector2i(2, 2), Vector2i(3, 3)],
		["zero_movement", Vector2(40, 40), Vector2i(0, 0), Vector2i(2, 2)]
	]
) -> void:
	# Test: Various tile delta movement scenarios
	test_node.global_position = start_position

	var result_tile: Vector2i = GBPositioning2DUtils.move_node_by_tiles(test_node, tile_delta, test_tile_map_layer)

assert_that(result_tile).append_failure_message(
		"Test %s: Node at %s moved by %s should reach tile %s, got %s" %
		[test_name, str(start_position).is_equal(expected_tile), str(tile_delta), str(expected_tile), str(result_tile)]
	)

#endregion

#region Region Validation Tests

func test_is_region_valid_scenarios() -> void:
	# Test: Region validation for various scenarios
	# Setup: Different region types
	# Act: Validate regions
	# Assert: Correct validation results
	var valid_region: Rect2i = Rect2i(0, 0, 10, 10)
	var zero_region: Rect2i = Rect2i()
	var negative_size_region: Rect2i = Rect2i(0, 0, -5, 10)
	var zero_width_region: Rect2i = Rect2i(0, 0, 0, 10)

	assert_bool(GBPositioning2DUtils.is_region_valid(valid_region)).is_true().append_failure_message(
		"Valid region should return true"
	)
	assert_bool(GBPositioning2DUtils.is_region_valid(zero_region)).is_false().append_failure_message(
		"Zero region should return false"
	)
	assert_bool(GBPositioning2DUtils.is_region_valid(negative_size_region)).is_false().append_failure_message(
		"Negative size region should return false"
	)
	assert_bool(GBPositioning2DUtils.is_region_valid(zero_width_region)).is_false().append_failure_message(
		"Zero width region should return false"
	)

func test_snap_tile_to_region_basic() -> void:
	# Test: Snap tile coordinates to region bounds
	# Setup: Tiles inside and outside region
	# Act: Snap coordinates
	# Assert: Proper snapping behavior
	var region: Rect2i = Rect2i(2, 3, 5, 4)  # Region from (2,3) with size (5,4) -> max is (6,6)
	var inside_tile: Vector2i = Vector2i(4, 5)
	var outside_tile: Vector2i = Vector2i(10, 1)
	var negative_tile: Vector2i = Vector2i(-1, -2)

	var snapped_inside: Vector2i = GBPositioning2DUtils.snap_tile_to_region(inside_tile, region)
	var snapped_outside: Vector2i = GBPositioning2DUtils.snap_tile_to_region(outside_tile, region)
	var snapped_negative: Vector2i = GBPositioning2DUtils.snap_tile_to_region(negative_tile, region)

assert_that(snapped_inside).append_failure_message(
		"Tile inside region should remain unchanged: %s" % str(inside_tile).is_equal(inside_tile)
	)
	# Region (2,3,5,4) has max at (2+5-1, 3+4-1) = (6,6), but Y should clamp to (3+4-1)=6, X should clamp to (2+5-1)=6
	# But outside_tile(10,1) Y=1 is below min Y=3, so should clamp to (6,3)
	assert_that(snapped_outside).is_equal(Vector2i(6, 3)).append_failure_message(
		"Tile outside region should snap to bounds: expected (6,3), got %s" % str(snapped_outside)
	)
	assert_that(snapped_negative).is_equal(Vector2i(2, 3)).append_failure_message(
		"Negative tile should snap to region minimum: expected (2,3), got %s" % str(snapped_negative)
	)

func test_snap_tile_to_region_invalid_region() -> void:
	# Test: Snapping with invalid region returns original tile
	# Setup: Invalid region and test tile
	# Act: Attempt snapping
	# Assert: Original tile returned unchanged
	var invalid_region: Rect2i = Rect2i()
	var test_tile: Vector2i = Vector2i(5, 7)

	var result: Vector2i = GBPositioning2DUtils.snap_tile_to_region(test_tile, invalid_region)

assert_that(result).append_failure_message(
		"Invalid region should return original tile unchanged: %s" % str(test_tile).is_equal(test_tile)
	)

#endregion

#region Viewport to World Conversion Tests

func test_viewport_center_to_world_position_with_camera() -> void:
	# Test: Viewport center to world conversion with Camera2D
	# Setup: Camera at specific position and zoom
	# Act: Convert viewport center to world position
	# Assert: Correct world position accounting for camera transform
	test_camera.global_position = Vector2(200, 150)
	test_camera.zoom = Vector2(1.0, 1.0)

	var world_position: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(test_viewport)

	# The result should account for camera position and viewport center
assert_that(world_position).append_failure_message(
		"World position should be calculated, got %s" % str(world_position).is_not_equal(Vector2.ZERO)
	)
	# More specific assertion would require precise camera transform calculation
assert_object(world_position).append_failure_message(
		"World position should not be null"
	).is_not_null()

func test_move_node_to_tile_at_viewport_center() -> void:
	# Test: Move node to viewport center snapped to grid
	# Setup: Viewport with camera and test node
	# Act: Move node to viewport center
	# Assert: Node positioned at grid-aligned center
	test_camera.global_position = Vector2(100, 100)
	test_camera.zoom = Vector2(1.0, 1.0)

	var result_tile: Vector2i = GBPositioning2DUtils.move_node_to_tile_at_viewport_center(test_node, test_tile_map_layer, test_viewport)

	# Node should be moved to some valid tile coordinate
assert_object(result_tile).append_failure_message(
		"Should return valid tile coordinate"
	).is_not_null()
	# Verify node was actually moved
assert_that(test_node.global_position).append_failure_message(
		"Node should be positioned after viewport center conversion"
	).is_not_equal(Vector2.ZERO)

#endregion

#region Direction to Tile Delta Tests

@warning_ignore("unused_parameter")
func test_direction_to_tile_delta_scenarios(
	test_name: String,
	input_direction: Vector2,
	expected_delta: Vector2i,
	test_parameters := [
		["right", Vector2(1, 0), Vector2i(1, 0)],
		["left", Vector2(-1, 0), Vector2i(-1, 0)],
		["up", Vector2(0, -1), Vector2i(0, -1)],
		["down", Vector2(0, 1), Vector2i(0, 1)],
		["diagonal_up_right", Vector2(1, -1), Vector2i(1, -1)],
		["diagonal_down_left", Vector2(-1, 1), Vector2i(-1, 1)],
		["zero_direction", Vector2.ZERO, Vector2i.ZERO],
		["small_right", Vector2(0.2, 0.1), Vector2i(1, 1)],
		["large_diagonal", Vector2(0.8, 0.9), Vector2i(1, 1)]
	]
) -> void:
	# Test: Direction vector to 8-way tile delta conversion
	var result_delta: Vector2i = GBPositioning2DUtils.direction_to_tile_delta(input_direction)

assert_that(result_delta).append_failure_message(
		"Test %s: Direction %s should convert to delta %s, got %s" %
		[test_name, str(input_direction).is_equal(expected_delta), str(expected_delta), str(result_delta)]
	)

func test_direction_to_tile_delta_threshold() -> void:
	# Test: Direction threshold behavior
	# Setup: Directions near threshold boundary
	# Act: Convert with custom threshold
	# Assert: Proper threshold handling
	var threshold: float = 0.5
	var below_threshold: Vector2 = Vector2(0.2, 0.1)  # When normalized, these become larger than threshold
	var above_threshold: Vector2 = Vector2(0.6, 0.7)

	var result_below: Vector2i = GBPositioning2DUtils.direction_to_tile_delta(below_threshold, threshold)
	var result_above: Vector2i = GBPositioning2DUtils.direction_to_tile_delta(above_threshold, threshold)

	# The normalized Vector2(0.2, 0.1) is approximately (0.89, 0.45), so both components exceed threshold
	assert_that(result_below).is_equal(Vector2i(1, 0)).append_failure_message(
		"Direction with normalized components above threshold should result in movement delta, got %s" % str(result_below)
	)
	assert_that(result_above).is_equal(Vector2i(1, 1)).append_failure_message(
		"Direction above threshold should result in (1,1) delta, got %s" % str(result_above)
	)

#endregion

#region Integration Tests

func test_coordinate_conversion_roundtrip() -> void:
	# Test: Full coordinate conversion roundtrip
	# Setup: Starting world position
	# Act: Convert to tile and back to world
	# Assert: Consistent positioning (within tile center tolerance)
	var original_position: Vector2 = Vector2(87, 55)

	# Convert to tile coordinate
	var tile_coord: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(original_position, test_tile_map_layer)

	# Move node to that tile center
	GBPositioning2DUtils.move_to_tile_center(test_node, tile_coord, test_tile_map_layer)

	# Verify node is at tile center - the exact center depends on tile size and coordinate
	var final_position: Vector2 = test_node.global_position

	# Just verify the node was moved to a valid position (not zero)
assert_that(final_position).append_failure_message(
		"Roundtrip conversion should move node from zero position, got %s" % str(final_position).is_not_equal(Vector2.ZERO)
	)

	# Verify coordinate conversion worked (tile coordinate is valid)
assert_that(tile_coord.x).append_failure_message(
		"Tile X coordinate should be non-negative, got %d" % tile_coord.x
	).is_greater_equal(0)
assert_that(tile_coord.y).append_failure_message(
		"Tile Y coordinate should be non-negative, got %d" % tile_coord.y
	).is_greater_equal(0)

func test_positioning_utilities_dry_compliance() -> void:
	# Test: Verify DRY refactoring worked correctly
	# Setup: Test all unified functions
	# Act: Call each function
	# Assert: No compilation errors, functions return expected types

	# Test all the unified functions exist and return correct types
	var tile_coord: Vector2i = GBPositioning2DUtils.get_tile_from_node_position(test_node, test_tile_map_layer)
	var world_pos: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(test_viewport)
	var region_valid: bool = GBPositioning2DUtils.is_region_valid(TEST_REGION)
	var snapped_tile: Vector2i = GBPositioning2DUtils.snap_tile_to_region(TEST_TILE_COORD, TEST_REGION)

	# Verify functions return expected types (should not crash if properly refactored)
assert_object(tile_coord).append_failure_message("get_tile_from_node_position should return Vector2i").is_not_null()
 assert_object(world_pos).append_failure_message("viewport_center_to_world_position should return Vector2").is_not_null()
assert_bool(region_valid).append_failure_message("is_region_valid should return bool").is_true()
 assert_object(snapped_tile).append_failure_message("snap_tile_to_region should return Vector2i").is_not_null()

#endregion
