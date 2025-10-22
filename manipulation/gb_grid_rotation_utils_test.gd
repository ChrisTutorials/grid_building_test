## Unit tests for GBGridRotationUtils
## Tests grid-aware rotation utilities for cardinal direction rotation
##
## Note: These utilities are used by ManipulationParent for grid-aware object rotation.
## GridPositioner2D no longer handles rotation - it focuses strictly on tile targeting.
extends GdUnitTestSuite

# Preload the utility class for testing
const GridRotationUtils = preload("res://addons/grid_building/utils/gb_grid_rotation_utils.gd")

# Test constants
const ROTATION_TOLERANCE: float = 0.1  # Degrees tolerance for rotation assertions
const DEFAULT_INCREMENT: float = 90.0  # Default 4-direction rotation

# Test environment setup
var test_map: TileMapLayer
var test_node: Node2D

func before_test() -> void:
	# Create test tilemap with proper TileSet
	test_map = TileMapLayer.new()
	test_map.tile_set = TileSet.new()
	test_map.tile_set.tile_size = Vector2i(16, 16)
	add_child(test_map)

	# Create test node to rotate (positioned at grid center)
	test_node = Node2D.new()
	test_node.global_position = Vector2(100, 100)
	test_node.global_rotation = 0.0  # Start at North (0 degrees)
	add_child(test_node)

func after_test() -> void:
	if test_map:
		test_map.queue_free()
	if test_node:
		test_node.queue_free()

#region HELPER METHODS

## Helper: Normalize degrees to 0-360 range (matches GBGridRotationUtils._normalize_degrees)
func _normalize_degrees(degrees: float) -> float:
	var normalized: float = fmod(degrees, 360.0)
	if normalized < 0:
		normalized += 360.0
	# Handle 360° edge case - treat as 0°
	if abs(normalized - 360.0) < 0.01:
		normalized = 0.0
	return normalized

## Helper: Assert rotation in degrees with detailed failure message
func _assert_rotation_degrees(actual_deg: float, expected_deg: float, context: String) -> void:
	# Normalize both values before comparison
	var normalized_actual: float = _normalize_degrees(actual_deg)
	var normalized_expected: float = _normalize_degrees(expected_deg)

	assert_float(normalized_actual).append_failure_message(
		"%s - Expected: %.2f°, Actual: %.2f° (raw: %.2f°), Difference: %.2f°" % [context, normalized_expected, normalized_actual, actual_deg, abs(normalized_actual - normalized_expected)]
	).is_equal_approx(normalized_expected, ROTATION_TOLERANCE)

## Helper: Set node rotation and verify
func _set_and_verify_rotation(rotation_deg: float) -> void:
	test_node.global_rotation = deg_to_rad(rotation_deg)
	var actual_deg: float = _normalize_degrees(rad_to_deg(test_node.global_rotation))
	var expected_normalized: float = _normalize_degrees(rotation_deg)
	assert_float(actual_deg).append_failure_message(
		"Failed to set initial rotation. Expected: %.2f°, Actual: %.2f°" % [expected_normalized, actual_deg]
	).is_equal_approx(expected_normalized, ROTATION_TOLERANCE)

#endregion

## Test cardinal direction conversion from degrees
func test_degrees_to_cardinal_conversion() -> void:
	assert_int(GridRotationUtils.degrees_to_cardinal(0)).append_failure_message("0 degrees should convert to NORTH direction").is_equal(GridRotationUtils.CardinalDirection.NORTH)
	assert_int(GridRotationUtils.degrees_to_cardinal(90)).append_failure_message("90 degrees should convert to EAST direction").is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(GridRotationUtils.degrees_to_cardinal(180)).append_failure_message("180 degrees should convert to SOUTH direction").is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(GridRotationUtils.degrees_to_cardinal(270)).append_failure_message("270 degrees should convert to WEST direction").is_equal(GridRotationUtils.CardinalDirection.WEST)

## Test cardinal direction conversion to degrees
func test_cardinal_to_degrees_conversion() -> void:
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.NORTH)).append_failure_message("NORTH direction should convert to 0 degrees").is_equal(0.0)
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.EAST)).append_failure_message("EAST direction should convert to 90 degrees").is_equal(90.0)
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.SOUTH)).append_failure_message("SOUTH direction should convert to 180 degrees").is_equal(180.0)
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.WEST)).append_failure_message("WEST direction should convert to 270 degrees").is_equal(270.0)

## Test clockwise rotation sequence
func test_clockwise_rotation_sequence() -> void:
	var north := GridRotationUtils.CardinalDirection.NORTH
	var east := GridRotationUtils.rotate_clockwise(north)
	var south := GridRotationUtils.rotate_clockwise(east)
	var west := GridRotationUtils.rotate_clockwise(south)
	var back_to_north := GridRotationUtils.rotate_clockwise(west)

	assert_int(east).append_failure_message("Rotating clockwise from NORTH: expected EAST (1), got %d" % east)\
		.is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(south).append_failure_message("Rotating clockwise from EAST: expected SOUTH (2), got %d" % south)\
		.is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(west).append_failure_message("Rotating clockwise from SOUTH: expected WEST (3), got %d" % west)\
		.is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(back_to_north).append_failure_message("Rotating clockwise from WEST: expected NORTH (0), got %d" % back_to_north)\
		.is_equal(GridRotationUtils.CardinalDirection.NORTH)

## Test counter-clockwise rotation sequence
func test_counter_clockwise_rotation_sequence() -> void:
	var north := GridRotationUtils.CardinalDirection.NORTH
	var west := GridRotationUtils.rotate_counter_clockwise(north)
	var south := GridRotationUtils.rotate_counter_clockwise(west)
	var east := GridRotationUtils.rotate_counter_clockwise(south)
	var back_to_north := GridRotationUtils.rotate_counter_clockwise(east)

	assert_int(west).append_failure_message("Rotating counter-clockwise from NORTH: expected WEST (3), got %d" % west)\
		.is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(south).append_failure_message("Rotating counter-clockwise from WEST: expected SOUTH (2), got %d" % south)\
		.is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(east).append_failure_message("Rotating counter-clockwise from SOUTH: expected EAST (1), got %d" % east)\
		.is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(back_to_north).append_failure_message("Rotating counter-clockwise from EAST: expected NORTH (0), got %d" % back_to_north)\
		.is_equal(GridRotationUtils.CardinalDirection.NORTH)

## Test node rotation with grid snapping
func test_node_rotation_with_grid_snapping() -> void:
	# Setup: Start at North (0 degrees)
	test_node.global_rotation = 0.0
	var initial_rotation_deg: float = _normalize_degrees(rad_to_deg(test_node.global_rotation))

	# Act: Rotate clockwise by 90 degrees (North -> East)
	var new_rotation_deg: float = GridRotationUtils.rotate_node_clockwise(test_node, test_map, DEFAULT_INCREMENT)
	var actual_rotation_deg: float = _normalize_degrees(rad_to_deg(test_node.global_rotation))

	# Assert: Function returns degrees (not CardinalDirection enum)
	assert_float(new_rotation_deg).append_failure_message(
		"rotate_node_clockwise should return rotation in degrees. Got: %s (type: %s)" % [str(new_rotation_deg), type_string(typeof(new_rotation_deg))]
	).is_equal_approx(90.0, ROTATION_TOLERANCE)

	# Assert: Node's actual rotation matches expected
	_assert_rotation_degrees(
		actual_rotation_deg,
		90.0,
		"Node rotation after first clockwise rotation (North -> East). Initial: %.2f°" % initial_rotation_deg
	)

	# Act: Rotate clockwise again (East -> South)
	new_rotation_deg = GridRotationUtils.rotate_node_clockwise(test_node, test_map, DEFAULT_INCREMENT)
	actual_rotation_deg = _normalize_degrees(rad_to_deg(test_node.global_rotation))

	# Assert: Should be at 180 degrees (South)
	assert_float(new_rotation_deg).append_failure_message(
		"Second clockwise rotation should return 180° (South). Got: %.2f°" % new_rotation_deg
	).is_equal_approx(180.0, ROTATION_TOLERANCE)

	_assert_rotation_degrees(
		actual_rotation_deg,
		180.0,
		"Node rotation after second clockwise rotation (East -> South)"
	)

## Test direction tile delta calculations
func test_direction_tile_deltas() -> void:
	var north_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.NORTH)
	var east_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.EAST)
	var south_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.SOUTH)
	var west_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.WEST)

	assert_vector(north_delta).append_failure_message("NORTH delta: expected (0, -1), got %s" % north_delta).is_equal(Vector2i(0, -1))
	assert_vector(east_delta).append_failure_message("EAST delta: expected (1, 0), got %s" % east_delta).is_equal(Vector2i(1, 0))
	assert_vector(south_delta).append_failure_message("SOUTH delta: expected (0, 1), got %s" % south_delta).is_equal(Vector2i(0, 1))
	assert_vector(west_delta).append_failure_message("WEST delta: expected (-1, 0), got %s" % west_delta).is_equal(Vector2i(-1, 0))

## Test opposite direction calculation
func test_opposite_directions() -> void:
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.NORTH))\
		.append_failure_message("Opposite of NORTH should be SOUTH (2), got %d" % GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.NORTH))\
		.is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.EAST))\
		.append_failure_message("Opposite of EAST should be WEST (3)")\
		.is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.SOUTH))\
		.append_failure_message("Opposite of SOUTH should be NORTH (0)")\
		.is_equal(GridRotationUtils.CardinalDirection.NORTH)
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.WEST))\
		.append_failure_message("Opposite of WEST should be EAST (1)")\
		.is_equal(GridRotationUtils.CardinalDirection.EAST)

## Test horizontal/vertical direction classification
func test_direction_classification() -> void:
	# Test horizontal directions
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.EAST))\
		.append_failure_message("EAST should be horizontal")\
		.is_true()
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.WEST))\
		.append_failure_message("WEST should be horizontal")\
		.is_true()
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.NORTH))\
		.append_failure_message("NORTH should NOT be horizontal")\
		.is_false()
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.SOUTH)).append_failure_message("SOUTH should NOT be horizontal").is_false()

	# Test vertical directions
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.NORTH)).append_failure_message("NORTH should be vertical").is_true()
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.SOUTH)).append_failure_message("SOUTH should be vertical").is_true()
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.EAST)).append_failure_message("EAST should NOT be vertical").is_false()
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.WEST)).append_failure_message("WEST should NOT be vertical").is_false()

## Test string representation of directions
func test_direction_to_string() -> void:
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.NORTH)).append_failure_message("NORTH direction should convert to 'North' string").is_equal("North")
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.EAST)).append_failure_message("EAST direction should convert to 'East' string").is_equal("East")
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.SOUTH)).append_failure_message("SOUTH direction should convert to 'South' string").is_equal("South")
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.WEST)).append_failure_message("WEST direction should convert to 'West' string").is_equal("West")

## Test comprehensive rotation cycle (360 degrees)
func test_full_rotation_cycle() -> void:
	# Start at North (0°)
	_set_and_verify_rotation(0.0)

	# Rotate through full cycle: North -> East -> South -> West -> North
	var expected_rotations: Array[float] = [90.0, 180.0, 270.0, 0.0]  # Normalized to 0-360

	for i in range(4):
		var new_rotation_deg: float = GridRotationUtils.rotate_node_clockwise(test_node, test_map, DEFAULT_INCREMENT)
		var actual_rotation_deg: float = _normalize_degrees(rad_to_deg(test_node.global_rotation))

		var direction_name: String = ["East", "South", "West", "North"][i]
		_assert_rotation_degrees(
			new_rotation_deg,
			expected_rotations[i],
			"Rotation cycle step %d (%s) - return value" % [i + 1, direction_name]
		)
		_assert_rotation_degrees(
			actual_rotation_deg,
			expected_rotations[i],
			"Rotation cycle step %d (%s) - node.global_rotation" % [i + 1, direction_name]
		)

## Test counter-clockwise rotation cycle
func test_counter_clockwise_full_cycle() -> void:
	# Start at North (0°)
	_set_and_verify_rotation(0.0)

	# Rotate counter-clockwise: North -> West -> South -> East -> North
	var expected_rotations: Array[float] = [270.0, 180.0, 90.0, 0.0]  # Normalized to 0-360

	for i in range(4):
		var new_rotation_deg: float = GridRotationUtils.rotate_node_counter_clockwise(test_node, test_map, DEFAULT_INCREMENT)
		var actual_rotation_deg: float = _normalize_degrees(rad_to_deg(test_node.global_rotation))

		var direction_name: String = ["West", "South", "East", "North"][i]
		_assert_rotation_degrees(
			new_rotation_deg,
			expected_rotations[i],
			"Counter-clockwise cycle step %d (%s) - return value" % [i + 1, direction_name]
		)
		_assert_rotation_degrees(
			actual_rotation_deg,
			expected_rotations[i],
			"Counter-clockwise cycle step %d (%s) - node.global_rotation" % [i + 1, direction_name]
		)
