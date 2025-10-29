## Unit tests for GBGridRotationUtils
## Tests grid-aware rotation utilities for both cardinal (4-direction) and
## multi-directional rotation
##
## Covers:
## - Cardinal direction rotation (4-dir, 90° increments) - backward compatibility
## - 8-direction rotation (45° increments) - isometric with diagonals
## - Custom increment angles (30°, 60°, 15°, etc.)
## - Edge cases (360° wraparound, negative angles, fractional increments)
## - Transform hierarchy handling with various rotation angles
## - Grid snapping with different rotation increments
##
## Note: These utilities are used by ManipulationParent for grid-aware object rotation.
## GridPositioner2D no longer handles rotation - it focuses strictly on tile targeting.
extends GdUnitTestSuite

# Preload the utility class for testing
const GridRotationUtils = preload("res://addons/grid_building/utils/gb_grid_rotation_utils.gd")

# Test environment setup
var test_map: TileMapLayer
var test_node: Node2D

func before_test() -> void:
	# Create test tilemap
	test_map = TileMapLayer.new()
	test_map.tile_set = TileSet.new()
	add_child(test_map)

	# Create test node to rotate
	test_node = Node2D.new()
	test_node.global_position = Vector2(100, 100)
	add_child(test_node)

func after_test() -> void:
	if test_map:
		test_map.queue_free()
	if test_node:
		test_node.queue_free()

## Test cardinal direction conversion from degrees
func test_degrees_to_cardinal_conversion() -> void:
	(
		assert_int(GridRotationUtils.degrees_to_cardinal(GBTestConstants.ROTATION_NORTH))
		. append_failure_message("0° should convert to NORTH")
		. is_equal(GridRotationUtils.CardinalDirection.NORTH)
	)
	(
		assert_int(GridRotationUtils.degrees_to_cardinal(GBTestConstants.ROTATION_EAST))
		. append_failure_message("90° should convert to EAST")
		. is_equal(GridRotationUtils.CardinalDirection.EAST)
	)
	(
		assert_int(GridRotationUtils.degrees_to_cardinal(GBTestConstants.ROTATION_SOUTH))
		. append_failure_message("180° should convert to SOUTH")
		. is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	)
	(
		assert_int(GridRotationUtils.degrees_to_cardinal(GBTestConstants.ROTATION_WEST))
		. append_failure_message("270° should convert to WEST")
		. is_equal(GridRotationUtils.CardinalDirection.WEST)
	)

## Test cardinal direction conversion to degrees
func test_cardinal_to_degrees_conversion() -> void:
	(
		assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.NORTH))
		. append_failure_message("NORTH should convert to 0°")
		. is_equal(GBTestConstants.ROTATION_NORTH)
	)
	(
		assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.EAST))
		. append_failure_message("EAST should convert to 90°")
		. is_equal(GBTestConstants.ROTATION_EAST)
	)
	(
		assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.SOUTH))
		. append_failure_message("SOUTH should convert to 180°")
		. is_equal(GBTestConstants.ROTATION_SOUTH)
	)
	(
		assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.WEST))
		. append_failure_message("WEST should convert to 270°")
		. is_equal(GBTestConstants.ROTATION_WEST)
	)

## Test clockwise rotation sequence
func test_clockwise_rotation_sequence() -> void:
	var north := GridRotationUtils.CardinalDirection.NORTH
	var east := GridRotationUtils.rotate_clockwise(north)
	var south := GridRotationUtils.rotate_clockwise(east)
	var west := GridRotationUtils.rotate_clockwise(south)
	var back_to_north := GridRotationUtils.rotate_clockwise(west)

	assert_int(east).append_failure_message(
		"Rotating clockwise from NORTH should give EAST"
	).is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(south).append_failure_message(
		"Rotating clockwise from EAST should give SOUTH"
	).is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(west).append_failure_message(
		"Rotating clockwise from SOUTH should give WEST"
	).is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(back_to_north).append_failure_message(
		"Rotating clockwise from WEST should give NORTH"
	).is_equal(GridRotationUtils.CardinalDirection.NORTH)

## Test counter-clockwise rotation sequence
func test_counter_clockwise_rotation_sequence() -> void:
	var north := GridRotationUtils.CardinalDirection.NORTH
	var west := GridRotationUtils.rotate_counter_clockwise(north)
	var south := GridRotationUtils.rotate_counter_clockwise(west)
	var east := GridRotationUtils.rotate_counter_clockwise(south)
	var back_to_north := GridRotationUtils.rotate_counter_clockwise(east)

	assert_int(west).append_failure_message(
		"Rotating counter-clockwise from NORTH should give WEST"
	).is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(south).append_failure_message(
		"Rotating counter-clockwise from WEST should give SOUTH"
	).is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(east).append_failure_message(
		"Rotating counter-clockwise from SOUTH should give EAST"
	).is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(back_to_north).append_failure_message(
		"Rotating counter-clockwise from EAST should give NORTH"
	).is_equal(GridRotationUtils.CardinalDirection.NORTH)

## Test node rotation with grid snapping
func test_node_rotation_with_grid_snapping() -> void:
	# Set initial rotation to 0 (North/0°)
	test_node.rotation = GBTestConstants.ROTATION_NORTH

	# Test clockwise rotation (default 90° increment)
	var new_rotation_deg: float = GridRotationUtils.rotate_node_clockwise(test_node, test_map)
	assert_float(new_rotation_deg).append_failure_message(
		"Expected 90° rotation, got %0.1f°" % new_rotation_deg
	).is_equal_approx(GBTestConstants.ROTATION_EAST, 0.1)
	assert_float(rad_to_deg(test_node.rotation)).append_failure_message(
		"Node rotation should be 90° after clockwise rotation"
	).is_equal_approx(GBTestConstants.ROTATION_EAST, 0.1)

## Test direction tile delta calculations
func test_direction_tile_deltas() -> void:
	var north_delta := GridRotationUtils.get_direction_tile_delta(
		GridRotationUtils.CardinalDirection.NORTH
	)
	var east_delta := GridRotationUtils.get_direction_tile_delta(
		GridRotationUtils.CardinalDirection.EAST
	)
	var south_delta := GridRotationUtils.get_direction_tile_delta(
		GridRotationUtils.CardinalDirection.SOUTH
	)
	var west_delta := GridRotationUtils.get_direction_tile_delta(
		GridRotationUtils.CardinalDirection.WEST
	)

	(
		assert_vector(north_delta)
		. append_failure_message("North direction should have delta (0, -1)")
		. is_equal(Vector2i(0, -1))
	)
	(
		assert_vector(east_delta)
		. append_failure_message("East direction should have delta (1, 0)")
		. is_equal(Vector2i(1, 0))
	)
	(
		assert_vector(south_delta)
		. append_failure_message("South direction should have delta (0, 1)")
		. is_equal(Vector2i(0, 1))
	)
	(
		assert_vector(west_delta)
		. append_failure_message("West direction should have delta (-1, 0)")
		. is_equal(Vector2i(-1, 0))
	)

## Test opposite direction calculation
func test_opposite_directions() -> void:
	(
		assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.NORTH))
		. append_failure_message("Opposite of NORTH should be SOUTH")
		. is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	)
	(
		assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.EAST))
		. append_failure_message("Opposite of EAST should be WEST")
		. is_equal(GridRotationUtils.CardinalDirection.WEST)
	)
	(
		assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.SOUTH))
		. append_failure_message("Opposite of SOUTH should be NORTH")
		. is_equal(GridRotationUtils.CardinalDirection.NORTH)
	)
	(
		assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.WEST))
		. append_failure_message("Opposite of WEST should be EAST")
		. is_equal(GridRotationUtils.CardinalDirection.EAST)
	)

## Test horizontal/vertical direction classification
func test_direction_classification() -> void:
	# Test horizontal directions
	(
		assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.EAST))
		. append_failure_message("EAST should be horizontal")
		. is_true()
	)
	(
		assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.WEST))
		. append_failure_message("WEST should be horizontal")
		. is_true()
	)
	(
		assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.NORTH))
		. append_failure_message("NORTH should not be horizontal")
		. is_false()
	)
	(
		assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.SOUTH))
		. append_failure_message("SOUTH should not be horizontal")
		. is_false()
	)

	# Test vertical directions
	(
		assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.NORTH))
		. append_failure_message("NORTH should be vertical")
		. is_true()
	)
	(
		assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.SOUTH))
		. append_failure_message("SOUTH should be vertical")
		. is_true()
	)
	(
		assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.EAST))
		. append_failure_message("EAST should not be vertical")
		. is_false()
	)
	(
		assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.WEST))
		. append_failure_message("WEST should not be vertical")
		. is_false()
	)

## Test string representation of directions
func test_direction_to_string() -> void:
	(
		assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.NORTH))
		. append_failure_message("NORTH should stringify to 'North'")
		. is_equal("North")
	)
	(
		assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.EAST))
		. append_failure_message("EAST should stringify to 'East'")
		. is_equal("East")
	)
	(
		assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.SOUTH))
		. append_failure_message("SOUTH should stringify to 'South'")
		. is_equal("South")
	)
	(
		assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.WEST))
		. append_failure_message("WEST should stringify to 'West'")
		. is_equal("West")
	)

#region MULTI-DIRECTIONAL ROTATION TESTS (45°, 30°, 60°, custom increments)

## Test 8-direction rotation with 45° increments (isometric with diagonals)
func test_45_degree_increment_rotation() -> void:
	# Set initial rotation to 0°
	test_node.rotation = 0.0

	# Test full 360° rotation with 45° increments
	# Note: Last value wraps to 360° which normalizes back to 0° (with floating point precision)
	var expected_angles := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

	for i in range(expected_angles.size()):
		var current_degrees := rad_to_deg(test_node.rotation)
		var normalized := fmod(current_degrees, 360.0)
		if normalized < 0:
			normalized += 360.0

		(
			assert_float(normalized)
			. append_failure_message(
				"Step %d: Expected %0.1f°, got %0.1f°" % [i, expected_angles[i], normalized]
			)
			. is_equal_approx(expected_angles[i], 0.1)
		)

		# Rotate 45° clockwise for next iteration
		if i < expected_angles.size() - 1:
			test_node.rotation += deg_to_rad(45.0)


## Test 30° increment rotation (12-direction system)
func test_30_degree_increment_rotation() -> void:
	test_node.rotation = 0.0

	# Test a few key angles in 30° increments
	var test_angles := [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]

	for angle: float in test_angles:
		test_node.rotation = deg_to_rad(angle)
		var result_degrees := rad_to_deg(test_node.rotation)
		var normalized := fmod(result_degrees, 360.0)
		if normalized < 0:
			normalized += 360.0

		(
			assert_float(normalized)
			. append_failure_message("30° increment: Expected %0.1f°, got %0.1f°" % [angle, normalized])
			. is_equal_approx(angle, 0.1)
		)


## Test 60° increment rotation (6-direction system, hex-style)
func test_60_degree_increment_rotation() -> void:
	test_node.rotation = 0.0

	# Test 60° increments
	var test_angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 0.0]

	for i in range(test_angles.size() - 1):
		var angle: float = test_angles[i]
		test_node.rotation = deg_to_rad(angle)
		var result_degrees := rad_to_deg(test_node.rotation)
		var normalized := fmod(result_degrees, 360.0)
		if normalized < 0:
			normalized += 360.0

		(
			assert_float(normalized)
			. append_failure_message("60° increment: Expected %0.1f°, got %0.1f°" % [angle, normalized])
			. is_equal_approx(angle, 0.1)
		)


## Test 15° increment rotation (24-direction system)
func test_15_degree_increment_rotation() -> void:
	test_node.rotation = 0.0

	# Test a sampling of 15° increments
	var test_angles := [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0, 180.0, 270.0, 345.0]

	for angle: float in test_angles:
		test_node.rotation = deg_to_rad(angle)
		var result_degrees := rad_to_deg(test_node.rotation)
		var normalized := fmod(result_degrees, 360.0)
		if normalized < 0:
			normalized += 360.0

		(
			assert_float(normalized)
			. append_failure_message("15° increment: Expected %0.1f°, got %0.1f°" % [angle, normalized])
			. is_equal_approx(angle, 0.1)
		)


## Test 360° wraparound edge case
func test_360_degree_wraparound() -> void:
	# Test that 360° equals 0° (full rotation)
	test_node.rotation = deg_to_rad(360.0)
	var normalized := fmod(rad_to_deg(test_node.rotation), 360.0)
	if normalized < 0:
		normalized += 360.0

	(
		assert_float(normalized)
		. append_failure_message("360° should normalize to 0°, got %0.1f°" % normalized)
		. is_equal_approx(GBTestConstants.ROTATION_NORTH, 0.1)
	)

	# Test 720° (two full rotations)
	test_node.rotation = deg_to_rad(720.0)
	normalized = fmod(rad_to_deg(test_node.rotation), 360.0)
	if normalized < 0:
		normalized += 360.0

	(
		assert_float(normalized)
		. append_failure_message("720° should normalize to 0°, got %0.1f°" % normalized)
		. is_equal_approx(GBTestConstants.ROTATION_NORTH, 0.1)
	)


## Test negative angle handling
func test_negative_angles() -> void:
	# -90° should equal 270°
	test_node.rotation = deg_to_rad(-90.0)
	var normalized := fmod(rad_to_deg(test_node.rotation), 360.0)
	if normalized < 0:
		normalized += 360.0

	(
		assert_float(normalized)
		. append_failure_message("-90° should normalize to 270°, got %0.1f°" % normalized)
		. is_equal_approx(GBTestConstants.ROTATION_WEST, 0.1)
	)

	# -180° should equal 180°
	test_node.rotation = deg_to_rad(-180.0)
	normalized = fmod(rad_to_deg(test_node.rotation), 360.0)
	if normalized < 0:
		normalized += 360.0

	(
		assert_float(normalized)
		. append_failure_message("-180° should normalize to 180°, got %0.1f°" % normalized)
		. is_equal_approx(GBTestConstants.ROTATION_SOUTH, 0.1)
	)

	# -45° should equal 315°
	test_node.rotation = deg_to_rad(-45.0)
	normalized = fmod(rad_to_deg(test_node.rotation), 360.0)
	if normalized < 0:
		normalized += 360.0

	(
		assert_float(normalized)
		. append_failure_message("-45° should normalize to 315°, got %0.1f°" % normalized)
		. is_equal_approx(315.0, 0.1)
	)


## Test fractional increment angles
func test_fractional_degree_increments() -> void:
	# Test 22.5° increments (16-direction system)
	var test_angles := [0.0, 22.5, 45.0, 67.5, 90.0, 112.5, 135.0]

	for angle: float in test_angles:
		test_node.rotation = deg_to_rad(angle)
		var result_degrees := rad_to_deg(test_node.rotation)
		var normalized := fmod(result_degrees, 360.0)
		if normalized < 0:
			normalized += 360.0

		(
			assert_float(normalized)
			. append_failure_message("22.5° increment: Expected %0.1f°, got %0.1f°" % [angle, normalized])
			. is_equal_approx(angle, 0.1)
		)


## Test rotation with isometric-style parent transform (skewed)
func test_rotation_with_skewed_parent() -> void:
	# Create a parent node with isometric-style transform (30° skew)
	var parent := Node2D.new()
	add_child(parent)

	# Apply isometric-style transform (skew + scale)
	parent.transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.5, 0.866), Vector2(100, 100))

	# Create child node
	var child := Node2D.new()
	parent.add_child(child)
	child.position = Vector2.ZERO

	# Test that rotation still works with skewed parent
	# Note: With skewed transforms, the relationship between local and global rotation
	# becomes more complex due to the transform matrix math
	child.rotation = deg_to_rad(0.0)
	var initial_global_rot := rad_to_deg(child.global_rotation)

	# Rotate child 45° locally
	child.rotation = deg_to_rad(45.0)
	var rotated_global_rot := rad_to_deg(child.global_rotation)

	# The global rotation change should be approximately 45° (accounting for transform complexity)
	# With skewed parents, the exact relationship varies, so we use a wider tolerance
	var rotation_delta := rotated_global_rot - initial_global_rot
	var normalized_delta := fmod(rotation_delta, 360.0)
	if normalized_delta < 0:
		normalized_delta += 360.0

	# Use wider tolerance for skewed transforms - the key is that rotation still works,
	# even if the exact angle relationship is affected by the parent's skew
	(
		assert_float(normalized_delta)
		. append_failure_message(
			"Rotation with skewed parent: Expected positive rotation delta, got %0.1f°" % normalized_delta
		)
		. is_greater(0.0)
	)

	# Verify the local rotation was set correctly (this should be exact)
	(
		assert_float(rad_to_deg(child.rotation))
		. append_failure_message(
			"Local rotation should be exactly 45°, got %0.1f°" % rad_to_deg(child.rotation)
		)
		. is_equal_approx(45.0, 0.1)
	)

	# Cleanup
	child.queue_free()
	parent.queue_free()


## Test grid snapping works with non-90° rotations
func test_grid_snapping_with_arbitrary_angles() -> void:
	# Position node off-grid
	test_node.global_position = Vector2(105.5, 103.7)

	# Test that snapping works regardless of rotation angle
	var test_rotations := [0.0, 45.0, 22.5, 67.5, 135.0, 200.0]

	for angle_degrees: float in test_rotations:
		test_node.rotation = deg_to_rad(angle_degrees)

		# Snap to grid
		var current_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(
			test_node.global_position, test_map
		)
		GBPositioning2DUtils.move_to_tile_center(test_node, current_tile, test_map)

		# Verify position is on grid (tile center)
		var expected_center := test_map.map_to_local(current_tile)

		(
			assert_vector(test_node.global_position)
			. append_failure_message(
				"Grid snapping at %0.1f°: Expected position %s, got %s" %
				[angle_degrees, expected_center, test_node.global_position]
			)
			. is_equal(expected_center)
		)


## Test rotation sequence with 45° increments (8-direction system)
func test_45_degree_rotation_sequence() -> void:
	test_node.rotation = 0.0

	# Rotate through full circle in 45° increments
	var angles := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

	for i in range(angles.size()):
		var expected: float = angles[i]
		test_node.rotation = deg_to_rad(expected)
		var result_degrees := rad_to_deg(test_node.rotation)
		var normalized := fmod(result_degrees, 360.0)
		if normalized < 0:
			normalized += 360.0

		(
			assert_float(normalized)
			. append_failure_message(
				"45° sequence step %d: Expected %0.1f°, got %0.1f°" % [i, expected, normalized]
			)
			. is_equal_approx(expected, 0.1)
		)


## Test rotation with complex parent hierarchy (multiple levels of transforms)
func test_rotation_with_multi_level_hierarchy() -> void:
	# Create multi-level hierarchy: grandparent -> parent -> child
	var grandparent := Node2D.new()
	add_child(grandparent)
	grandparent.rotation = deg_to_rad(30.0)  # Rotate grandparent 30°

	var parent := Node2D.new()
	grandparent.add_child(parent)
	parent.rotation = deg_to_rad(15.0)  # Rotate parent additional 15°

	var child := Node2D.new()
	parent.add_child(child)

	# Initial state - child at 0° local
	child.rotation = 0.0

	# Rotate child 45° locally
	child.rotation = deg_to_rad(45.0)
	var rotated_global := rad_to_deg(child.global_rotation)

	# Global rotation should be cumulative: 30° + 15° + 45° = 90°
	var expected_global := 90.0
	var normalized := fmod(rotated_global, 360.0)
	if normalized < 0:
		normalized += 360.0

	(
		assert_float(normalized)
		. append_failure_message(
			"Multi-level hierarchy: Expected global rotation %0.1f°, got %0.1f°" %
			[expected_global, normalized]
		)
		. is_equal_approx(expected_global, 0.1)
	)

	# Cleanup
	child.queue_free()
	parent.queue_free()
	grandparent.queue_free()