## Unit tests for GBGridRotationUtils
## Tests grid-aware rotation utilities for cardinal direction rotation
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
	assert_int(GridRotationUtils.degrees_to_cardinal(0)).is_equal(GridRotationUtils.CardinalDirection.NORTH)
	assert_int(GridRotationUtils.degrees_to_cardinal(90)).is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(GridRotationUtils.degrees_to_cardinal(180)).is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(GridRotationUtils.degrees_to_cardinal(270)).is_equal(GridRotationUtils.CardinalDirection.WEST)

## Test cardinal direction conversion to degrees
func test_cardinal_to_degrees_conversion() -> void:
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.NORTH)).is_equal(0.0)
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.EAST)).is_equal(90.0)
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.SOUTH)).is_equal(180.0)
	assert_float(GridRotationUtils.cardinal_to_degrees(GridRotationUtils.CardinalDirection.WEST)).is_equal(270.0)

## Test clockwise rotation sequence
func test_clockwise_rotation_sequence() -> void:
	var north := GridRotationUtils.CardinalDirection.NORTH
	var east := GridRotationUtils.rotate_clockwise(north)
	var south := GridRotationUtils.rotate_clockwise(east)
	var west := GridRotationUtils.rotate_clockwise(south)
	var back_to_north := GridRotationUtils.rotate_clockwise(west)
	
	assert_int(east).is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(south).is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(west).is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(back_to_north).is_equal(GridRotationUtils.CardinalDirection.NORTH)

## Test counter-clockwise rotation sequence
func test_counter_clockwise_rotation_sequence() -> void:
	var north := GridRotationUtils.CardinalDirection.NORTH
	var west := GridRotationUtils.rotate_counter_clockwise(north)
	var south := GridRotationUtils.rotate_counter_clockwise(west)
	var east := GridRotationUtils.rotate_counter_clockwise(south)
	var back_to_north := GridRotationUtils.rotate_counter_clockwise(east)
	
	assert_int(west).is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(south).is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(east).is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_int(back_to_north).is_equal(GridRotationUtils.CardinalDirection.NORTH)

## Test node rotation with grid snapping
func test_node_rotation_with_grid_snapping() -> void:
	# Set initial rotation to 0 (North)
	test_node.rotation = 0.0
	
	# Test clockwise rotation
	var new_direction := GridRotationUtils.rotate_node_clockwise(test_node, test_map)
	assert_int(new_direction).is_equal(GridRotationUtils.CardinalDirection.EAST)
	assert_float(rad_to_deg(test_node.rotation)).is_equal_approx(90.0, 0.1)

## Test direction tile delta calculations
func test_direction_tile_deltas() -> void:
	var north_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.NORTH)
	var east_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.EAST)
	var south_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.SOUTH)
	var west_delta := GridRotationUtils.get_direction_tile_delta(GridRotationUtils.CardinalDirection.WEST)
	
	assert_vector(north_delta).is_equal(Vector2i(0, -1))
	assert_vector(east_delta).is_equal(Vector2i(1, 0))
	assert_vector(south_delta).is_equal(Vector2i(0, 1))
	assert_vector(west_delta).is_equal(Vector2i(-1, 0))

## Test opposite direction calculation
func test_opposite_directions() -> void:
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.NORTH)).is_equal(GridRotationUtils.CardinalDirection.SOUTH)
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.EAST)).is_equal(GridRotationUtils.CardinalDirection.WEST)
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.SOUTH)).is_equal(GridRotationUtils.CardinalDirection.NORTH)
	assert_int(GridRotationUtils.get_opposite_direction(GridRotationUtils.CardinalDirection.WEST)).is_equal(GridRotationUtils.CardinalDirection.EAST)

## Test horizontal/vertical direction classification
func test_direction_classification() -> void:
	# Test horizontal directions
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.EAST)).is_true()
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.WEST)).is_true()
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.NORTH)).is_false()
	assert_bool(GridRotationUtils.is_horizontal(GridRotationUtils.CardinalDirection.SOUTH)).is_false()
	
	# Test vertical directions
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.NORTH)).is_true()
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.SOUTH)).is_true()
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.EAST)).is_false()
	assert_bool(GridRotationUtils.is_vertical(GridRotationUtils.CardinalDirection.WEST)).is_false()

## Test string representation of directions
func test_direction_to_string() -> void:
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.NORTH)).is_equal("North")
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.EAST)).is_equal("East")
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.SOUTH)).is_equal("South")
	assert_str(GridRotationUtils.direction_to_string(GridRotationUtils.CardinalDirection.WEST)).is_equal("West")