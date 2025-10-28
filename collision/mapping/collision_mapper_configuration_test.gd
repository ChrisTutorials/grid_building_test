## Integration test specifically focused on collision mapper configuration issues
## This test isolates the problem where collision geometry calculation works correctly
## but the collision mapper fails to generate indicators for calculated tile positions
extends GdUnitTestSuite

# Test constants to eliminate magic numbers and strings
const TEST_POSITION_MINIMAL := Vector2(240, 240)  # Near center tile (15,15) for 16x16 tiles
const SHAPE_SIZE_SQUARE := Vector2(32, 32)
const TILE_SIZE := Vector2(16, 16)
const TEST_POSITION_TRAPEZOID := Vector2(280, 280)  # Also near center for predictable offsets
const COLLISION_LAYER_DEFAULT := 1
const MINIMAL_TEST_OBJECT_NAME := "MinimalTestObject"
const MOCK_INDICATOR_NAME := "MinimalMockIndicator"
const PROPER_TEST_OBJECT_NAME := "ProperTestObject"

# Test variables for non-constant expressions
var _trapezoid_points := PackedVector2Array([
	Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
])

var _env: BuildingTestEnvironment
var _collision_mapper: CollisionMapper
var _targeting_state: GridTargetingState
var _indicator_manager: IndicatorManager

func before_test() -> void:
	_env = EnvironmentTestFactory.create_building_system_test_environment(self)
	_collision_mapper = _env.indicator_manager.get_collision_mapper()
	_targeting_state = _env.grid_targeting_system.get_state()
	_indicator_manager = _env.indicator_manager

	# Validate basic environment setup
 assert_object(_collision_mapper)
  .append_failure_message("CollisionMapper should not be null").is_not_null()
 assert_object(_targeting_state)
  .append_failure_message("GridTargetingState should not be null").is_not_null()
 assert_object(_indicator_manager)
  .append_failure_message("IndicatorManager should not be null").is_not_null()

# Helper method to create minimal test object with square collision shape
func _create_minimal_test_object() -> StaticBody2D:
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = MINIMAL_TEST_OBJECT_NAME
	test_object.global_position = TEST_POSITION_MINIMAL
	test_object.collision_layer = COLLISION_LAYER_DEFAULT

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = SHAPE_SIZE_SQUARE
	collision_shape.shape = shape
	test_object.add_child(collision_shape)

	_env.objects_parent.add_child(test_object)
	auto_free(test_object)

	return test_object

# Helper method to create trapezoid test object
func _create_trapezoid_test_object() -> StaticBody2D:
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = PROPER_TEST_OBJECT_NAME
	test_object.global_position = TEST_POSITION_TRAPEZOID

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = _trapezoid_points
	collision_shape.shape = shape
	test_object.add_child(collision_shape)

	_env.add_child(test_object)
	auto_free(test_object)

	return test_object

# Helper method to create mock indicator
func _create_mock_indicator(indicator_name: String, collision_mask: int) -> RuleCheckIndicator:
	var mock_indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	mock_indicator.name = indicator_name
	mock_indicator.collision_mask = collision_mask
	mock_indicator.shape = RectangleShape2D.new()
	auto_free(mock_indicator)
	_env.add_child(mock_indicator)

	return mock_indicator

# Helper method to setup targeting state for a target object
func _setup_targeting_state(target: Node2D) -> void:
	_targeting_state.set_manual_target(target)
	# Position the positioner at a grid-aligned location near the map center
	# This ensures indicators will be positioned within map bounds
	var center_tile := Vector2i(15, 15)  # Center of 31x31 map
	var center_world_pos: Vector2 = _targeting_state.target_map.to_global(_targeting_state.target_map.map_to_local(center_tile))
	_targeting_state.positioner.global_position = center_world_pos

# Helper method to compute expected offsets for trapezoid
func _compute_expected_trapezoid_offsets(test_object: StaticBody2D) -> Array[Vector2i]:
	var center_tile: Vector2i = Vector2i(
		int(test_object.global_position.x / TILE_SIZE.x),
		int(test_object.global_position.y / TILE_SIZE.y)
	)

	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _trapezoid_points:
		world_polygon.append(point + test_object.global_position)

	return CollisionGeometryUtils.compute_polygon_tile_offsets(
		world_polygon, TILE_SIZE, center_tile
	)

## Test collision mapper with minimal configuration
func test_collision_mapper_minimal_setup() -> void:
	# Arrange
	var test_object: StaticBody2D = _create_minimal_test_object()
	_setup_targeting_state(test_object)

	var mock_indicator: RuleCheckIndicator = _create_mock_indicator(MOCK_INDICATOR_NAME, COLLISION_LAYER_DEFAULT)

	var setup_list: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(test_object, _targeting_state)
	assert_that(setup_list.size()).append_failure_message("Expected create_test_setups_from_test_node to produce at least one setup for the test object").is_not_equal(0)

	_collision_mapper.setup(mock_indicator, setup_list)

	# Act
	var col_objects: Array[Node2D] = [test_object]
	var tile_check_rules: Array[TileCheckRule] = []
	var positions_to_rules: Dictionary[Vector2i, Array] = _collision_mapper.map_collision_positions_to_rules(col_objects, tile_check_rules)

	# Assert
	var positions: Array[Vector2i] = positions_to_rules.keys()
	assert_int(positions_to_rules.size()).append_failure_message(
		"CollisionMapper should map at least one position for a simple square shape. Mapped positions: %s" % str(positions)
	).is_not_equal(0)


## Test collision mapper configuration requirements
func test_collision_mapper_configuration_requirements() -> void:
	# Arrange
	# Before setup, required properties should be null
	assert_object(_collision_mapper.get("test_indicator")).append_failure_message(
		"Expected test_indicator to be null before setup"
	).is_null()
	var pre_setups: Array[CollisionTestSetup2D] = _collision_mapper.get("test_setups")
	assert_array(pre_setups).append_failure_message(
		"Expected test_setups to be empty before setup, got: %s" % str(pre_setups)
	).is_empty()

	# Act & Assert
	var mock_indicator: RuleCheckIndicator = _create_mock_indicator("MockTestIndicator", COLLISION_LAYER_DEFAULT)
	var mock_setups: Array[CollisionTestSetup2D] = []
	_collision_mapper.setup(mock_indicator, mock_setups)

	assert_object(_collision_mapper.get("test_indicator")).is_same(mock_indicator)
  .append_failure_message(
		"CollisionMapper.setup(...) should set the test_indicator reference provided."
	)
	assert_object(_collision_mapper.get("test_setups")).is_same(mock_setups).append_failure_message(
		"CollisionMapper.setup(...) should set the test_setups array provided."
	)


## Test creating proper collision mapper configuration
func test_proper_collision_mapper_setup() -> void:
	# Arrange
	var test_object: StaticBody2D = _create_trapezoid_test_object()
	_setup_targeting_state(test_object)

	var expected_offsets: Array[Vector2i] = _compute_expected_trapezoid_offsets(test_object)
	assert_int(expected_offsets.size()).append_failure_message(
		"CollisionGeometryUtils should compute at least one tile offset for the trapezoid."
	).is_not_equal(0)

	# Act: proper setup of collision mapper before mapping
	var setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(test_object, _targeting_state)
	assert_int(setups.size())
  .append_failure_message("Expected at least one test setup for trapezoid owner").is_greater(0)
	var mock_indicator: RuleCheckIndicator = _create_mock_indicator("TrapezoidMockIndicator", COLLISION_LAYER_DEFAULT)
	_collision_mapper.setup(mock_indicator, setups)

	var col_objects: Array[Node2D] = [test_object]
	var tile_check_rules: Array[TileCheckRule] = []
	var position_rules: Dictionary[Vector2i, Array] = _collision_mapper.map_collision_positions_to_rules(col_objects, tile_check_rules)

	# Assert
 assert_bool(position_rules is Dictionary)
  .append_failure_message("map_collision_positions_to_rules should return a Dictionary.").is_true()
 assert_bool(k is Vector2i)
 	.append_failure_message( "All keys in position_rules should be Vector2i. Found: %s" % str(k) ) keys_typed.append(k) for pos: Vector2i in keys_typed: mapped_positions.append(pos) # Compare collision mapper results vs expected var missing_positions: Array[Vector2i] = [] var expected_positions: Array[Vector2i] = [] var center_tile: Vector2i = Vector2i( int(test_object.global_position.x / TILE_SIZE.x), int(test_object.global_position.y / TILE_SIZE.y) ) for offset in expected_offsets: expected_positions.append(center_tile + offset) for expected_pos in expected_positions: if not mapped_positions.has(expected_pos): missing_positions.append(expected_pos) var failure_msg := "CollisionMapper should map all %d expected positions but is missing %d: %s. Expected: %s, Mapped: %s" % [ expected_positions.size(), missing_positions.size(), str(missing_positions), str(expected_positions), str(mapped_positions) ] assert_int(missing_positions.size())
 	.is_equal(0)
 	.append_failure_message(failure_msg)
 	.is_true()
