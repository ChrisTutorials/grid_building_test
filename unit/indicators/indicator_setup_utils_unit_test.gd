## IndicatorSetupUtils Unit Tests
##
## Tests for the IndicatorSetupUtils runtime utilities class.
## These tests verify collision shape gathering, test setup building,
## position mapping, validation functionality, indicator generation,
## and positioning accuracy using parameterized tests with various test objects.
##
## Test Coverage:
## - gather_collision_shapes: Shape extraction from test objects
## - build_collision_test_setups: Test setup creation for different owner types
## - execute_indicator_setup: Complete setup workflow with various test objects
## - validate_indicator_positions: Position accuracy validation
## - calculate_indicator_count: Indicator count calculation
## - validate_setup_preconditions: Input validation checks
class_name IndicatorSetupUtilsUnitTest
extends GdUnitTestSuite

## Test data for parameterized tests
const TEST_SCENE_DATA = [
	{
		"scene_path": GBTestConstants.SMITHY_PATH,
		"expected_count": 48,  # 8x6 tiles (112x80 pixels + 8px centering offset with 16x16 tiles)
		"name": "smithy"
	},
	{
		"scene_path": GBTestConstants.RECT_15_TILES_PATH, 
		"expected_count": 15,  # 5x3 tiles (64x32 pixels + 8px centering offset with 16x16 tiles)
		"name": "rectangle"
	},
	{
		"scene_path": GBTestConstants.PILLAR_PATH,
		"expected_count": 2,  # 2x1 tiles (capsule 14x22 pixels + 8px centering offset needs 2 tiles)
		"name": "pillar"
	},
	{
		"scene_path": GBTestConstants.GIGANTIC_EGG_PATH,
		"expected_count": 63,  # 7x9 tiles (96x128 pixel capsule + 8px centering offset with 16x16 tiles)
		"name": "egg"
	}
]

var _targeting_state: GridTargetingState
var _indicator_template: PackedScene
var _test_rule: TileCheckRule

func before_test() -> void:
	# Setup common test dependencies
	_targeting_state = GridTargetingState.new(GBOwnerContext.new())
	
	# Create a test tile map with proper tile set
	var test_map: TileMapLayer = TileMapLayer.new()
	auto_free(test_map)
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(GBTestConstants.DEFAULT_TILE_SIZE.x, GBTestConstants.DEFAULT_TILE_SIZE.y)
	test_map.tile_set = tile_set
	add_child(test_map)
	
	# Create a positioner for the targeting state
	var positioner: Node2D = Node2D.new()
	auto_free(positioner)
	add_child(positioner)
	positioner.global_position = Vector2.ZERO
	
	# Set up the targeting state with the tile map and positioner
	_targeting_state.target_map = test_map
	_targeting_state.maps = [test_map]
	_targeting_state.positioner = positioner
	
	_indicator_template = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	
	# Create a simple test rule
	_test_rule = TileCheckRule.new()

## Test gather_collision_shapes with null input
func test_gather_collision_shapes_null_input() -> void:
	var result := IndicatorSetupUtils.gather_collision_shapes(null)
	assert_that(result).is_empty()

## Test gather_collision_shapes with empty node
func test_gather_collision_shapes_empty_node() -> void:
	var empty_node := Node2D.new()
	
	var result := IndicatorSetupUtils.gather_collision_shapes(empty_node)
	assert_that(result).is_empty()
	
	empty_node.queue_free()

## Parameterized test for collision shape gathering across multiple test scenes
func test_gather_collision_shapes_parameterized() -> void:
	for test_data: Dictionary in TEST_SCENE_DATA:
		var scene_path: String = test_data["scene_path"]
		var test_name: String = test_data["name"]
		
		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			print("Warning: Could not load scene at path: ", scene_path)
			continue
			
		var test_object: Node2D = scene.instantiate() as Node2D
		add_child(test_object)
		
		var result: Dictionary = IndicatorSetupUtils.gather_collision_shapes(test_object)
		
		# Should find collision shapes
		assert_that(result).append_failure_message(
			"Should find collision shapes for %s" % test_name
		).is_not_empty()
		
		# Check that we have the expected structure
		for owner_node: Node in result.keys():
			assert_that(owner_node).append_failure_message(
				"Owner should be Node2D for %s" % test_name
			).is_instanceof(Node2D)
			var shapes: Array = result[owner_node]
			assert_that(shapes).append_failure_message(
				"Shapes array should not be empty for %s" % test_name
			).is_not_empty()
		
		test_object.queue_free()

## Test gather_collision_shapes with valid collision object
func test_gather_collision_shapes_with_collision_object() -> void:
	var test_object := Node2D.new()
	var collision_owner := StaticBody2D.new()
	var collision_shape := CollisionShape2D.new()
	var rectangle_shape := RectangleShape2D.new()
	rectangle_shape.size = Vector2(32, 32)
	collision_shape.shape = rectangle_shape
	
	collision_owner.add_child(collision_shape)
	test_object.add_child(collision_owner)
	add_child(test_object)
	
	var result := IndicatorSetupUtils.gather_collision_shapes(test_object)
	
	assert_that(result).is_not_empty()
	assert_that(result.has(collision_owner)).is_true()
	assert_that(result[collision_owner]).is_not_empty()
	assert_that(result[collision_owner][0]).is_instanceof(RectangleShape2D)
	assert_that(result[collision_owner][0].size).is_equal(Vector2(32, 32))
	
	# Cleanup
	test_object.queue_free()

## Test execute_indicator_setup with null inputs
func test_execute_indicator_setup_null_inputs() -> void:
	var result: IndicatorSetupUtils.SetupResult = IndicatorSetupUtils.execute_indicator_setup(
		null,
		[_test_rule],
		null,
		_indicator_template,
		self,
		_targeting_state
	)
	
	assert_that(result.has_issues()).is_true()
	assert_that(result.indicators).is_empty()

## Parameterized test for complete indicator setup workflow
func test_execute_indicator_setup_basic_success() -> void:
	# Arrange
	var test_object: Node2D = _create_test_object_with_shapes()
	var tile_check_rules: Array[TileCheckRule] = _create_tile_check_rules()
	var collision_mapper: CollisionMapper = CollisionMapper.new(_targeting_state, GBLogger.new())
	var indicators_parent: Node2D = Node2D.new()
	add_child(indicators_parent)
	
	# Act
	var result: IndicatorSetupUtils.SetupResult = IndicatorSetupUtils.execute_indicator_setup(
		test_object,
		tile_check_rules,
		collision_mapper,
		_indicator_template,
		indicators_parent,
		_targeting_state
	)
	
	# Assert: result should be successful and contain indicators
	assert_that(result.is_successful()).append_failure_message("Setup should be successful").is_true()
	assert_that(result.has_issues()).append_failure_message("Should have no issues").is_false()
	assert_that(result.indicators).append_failure_message("Should have indicators").is_not_empty()
	assert_that(result.owner_shapes).append_failure_message("Should have owner shapes").is_not_empty()
	
	# Clean up
	test_object.queue_free()
	indicators_parent.queue_free()

## Test calculate_indicator_count with various test objects
func test_calculate_indicator_count_parameterized() -> void:
	for test_data: Dictionary in TEST_SCENE_DATA:
		var scene_path: String = test_data["scene_path"]
		var test_name: String = test_data["name"]
		
		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			print("Warning: Could not load scene at path: ", scene_path)
			continue
			
		var test_object: Node2D = scene.instantiate() as Node2D
		add_child(test_object)
		
		var collision_mapper: CollisionMapper = CollisionMapper.new(_targeting_state, GBLogger.new())
		var rules: Array[TileCheckRule] = [_test_rule]
		
		var count: int = IndicatorSetupUtils.calculate_indicator_count(
			test_object,
			rules,
			collision_mapper,
			_indicator_template,
			self
		)
		
		# Should return a positive count
		assert_that(count).append_failure_message(
			"Should return positive count for %s, got %d" % [test_name, count]
		).is_greater_equal(1)
		
		test_object.queue_free()

## Test validate_indicator_positions with properly positioned indicators
func test_validate_indicator_positions_correct_positioning() -> void:
	# Create test indicators at known positions
	var indicators: Array[RuleCheckIndicator] = []
	var expected_positions: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	
	# Create indicators at the expected tile positions
	for pos: Vector2i in expected_positions:
		var indicator: RuleCheckIndicator = _indicator_template.instantiate() as RuleCheckIndicator
		
		var world_pos: Vector2 = _targeting_state.target_map.map_to_local(pos)
		indicator.global_position = world_pos
		indicators.append(indicator)
	
	var result: IndicatorSetupUtils.PositionValidationResult = IndicatorSetupUtils.validate_indicator_positions(
		indicators,
		expected_positions,
		_targeting_state
	)
	
	assert_that(result.is_valid).is_true()
	assert_that(result.size_mismatch).is_false()
	assert_that(result.position_mismatches).is_empty()
	
	# Cleanup
	for indicator in indicators:
		indicator.queue_free()

## Test validate_indicator_positions with size mismatch
func test_validate_indicator_positions_size_mismatch() -> void:
	var indicators: Array[RuleCheckIndicator] = []
	var expected_positions: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	
	# Create only one indicator (size mismatch)
	var indicator: RuleCheckIndicator = _indicator_template.instantiate() as RuleCheckIndicator
	add_child(indicator)
	indicators.append(indicator)
	
	var result: IndicatorSetupUtils.PositionValidationResult = IndicatorSetupUtils.validate_indicator_positions(
		indicators,
		expected_positions,
		_targeting_state
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.size_mismatch).is_true()
	assert_that(result.expected_count).is_equal(2)
	assert_that(result.actual_count).is_equal(1)
	
	# Cleanup
	indicator.queue_free()

## Test validate_indicator_positions with position mismatch
func test_validate_indicator_positions_position_mismatch() -> void:
	var indicators: Array[RuleCheckIndicator] = []
	var expected_positions: Array[Vector2i] = [Vector2i(0, 0)]
	
	# Create indicator at wrong position
	var indicator: RuleCheckIndicator = _indicator_template.instantiate() as RuleCheckIndicator
	add_child(indicator)
	var wrong_world_pos: Vector2 = _targeting_state.target_map.map_to_local(Vector2i(5, 5))  # Wrong position
	indicator.global_position = wrong_world_pos
	indicators.append(indicator)
	
	var result: IndicatorSetupUtils.PositionValidationResult = IndicatorSetupUtils.validate_indicator_positions(
		indicators,
		expected_positions,
		_targeting_state
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.size_mismatch).is_false()
	assert_that(result.position_mismatches).is_not_empty()
	assert_that(result.position_mismatches[0]["expected"]).is_equal(Vector2i(0, 0))
	assert_that(result.position_mismatches[0]["actual"]).is_equal(Vector2i(5, 5))
	
	# Cleanup
	indicator.queue_free()

## Test build_collision_test_setups with empty input
func test_build_collision_test_setups_empty_input() -> void:
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var tile_size := Vector2i(GBTestConstants.DEFAULT_TILE_SIZE.x, GBTestConstants.DEFAULT_TILE_SIZE.y)
	
	var result := IndicatorSetupUtils.build_collision_test_setups(owner_shapes, tile_size)
	assert_that(result).is_empty()

## Test build_collision_test_setups with CollisionObject2D owner
func test_build_collision_test_setups_collision_object_owner() -> void:
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var collision_owner := StaticBody2D.new()
	var shapes: Array[Node2D] = []
	owner_shapes[collision_owner] = shapes
	
	var tile_size := Vector2i(GBTestConstants.DEFAULT_TILE_SIZE.x, GBTestConstants.DEFAULT_TILE_SIZE.y)
	
	var result := IndicatorSetupUtils.build_collision_test_setups(owner_shapes, tile_size)
	
	assert_that(result).is_not_empty()
	assert_that(result.has(collision_owner)).is_true()
	assert_that(result[collision_owner]).is_not_null()
	assert_that(result[collision_owner]).is_instanceof(CollisionTestSetup2D)
	
	# Verify the stretch amount calculation (tile_size * 2.0)
	var expected_stretch := Vector2(32, 32)  # 16 * 2.0
	assert_that(result[collision_owner].shape_stretch_size).is_equal(expected_stretch)
	
	# Cleanup
	collision_owner.queue_free()

## Test build_collision_test_setups with CollisionPolygon2D owner
func test_build_collision_test_setups_collision_polygon_owner() -> void:
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var collision_owner := CollisionPolygon2D.new()
	var shapes: Array[Node2D] = []
	owner_shapes[collision_owner] = shapes
	
	var tile_size := Vector2i(32, 32)
	
	var result := IndicatorSetupUtils.build_collision_test_setups(owner_shapes, tile_size)
	
	assert_that(result).is_not_empty()
	assert_that(result.has(collision_owner)).is_true()
	assert_that(result[collision_owner]).is_null()  # CollisionPolygon2D gets null setup
	
	# Cleanup
	collision_owner.queue_free()

## Test map_positions_to_rules with null collision mapper
func test_map_positions_to_rules_null_mapper() -> void:
	var collision_mapper: CollisionMapper = null
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var rules: Array[TileCheckRule] = []
	
	var result := IndicatorSetupUtils.map_positions_to_rules(collision_mapper, owner_shapes, rules)
	assert_that(result).is_empty()

## Test validate_setup_preconditions with valid inputs
func test_validate_setup_preconditions_valid_inputs() -> void:
	var test_object := Node2D.new()
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper
	
	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, mock_collision_mapper)
	assert_that(result).is_empty()
	
	# Cleanup
	test_object.queue_free()

## Test validate_setup_preconditions with null test object
func test_validate_setup_preconditions_null_test_object() -> void:
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper
	
	var result := IndicatorSetupUtils.validate_setup_preconditions(null, rules, mock_collision_mapper)
	assert_that(result).is_not_empty()
	assert_that(result.has("Test object is null or invalid")).is_true()

## Test validate_setup_preconditions with empty rules
func test_validate_setup_preconditions_empty_rules() -> void:
	var test_object := Node2D.new()
	var rules: Array[TileCheckRule] = []
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper
	
	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, mock_collision_mapper)
	assert_that(result).is_not_empty()
	assert_that(result.has("No tile check rules provided")).is_true()
	
	# Cleanup
	test_object.queue_free()

## Test validate_setup_preconditions with null collision mapper
func test_validate_setup_preconditions_null_collision_mapper() -> void:
	var test_object := Node2D.new()
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	
	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, null)
	assert_that(result).is_not_empty()
	assert_that(result.has("Collision mapper is not available")).is_true()
	
	# Cleanup
	test_object.queue_free()

## Helper method to create a test object with collision shapes
func _create_test_object_with_shapes() -> Node2D:
	var test_object := Area2D.new()
	var collision_shape := CollisionShape2D.new()
	var rectangle_shape := RectangleShape2D.new()
	# Create a larger shape that should span multiple tiles (64x64 pixels = 4 tiles with 16x16 tile size)
	rectangle_shape.size = Vector2(64, 64)
	collision_shape.shape = rectangle_shape
	test_object.add_child(collision_shape)
	add_child(test_object)
	# Set to origin position for consistent testing
	test_object.global_position = Vector2.ZERO
	return test_object

## Helper method to create tile check rules for testing
func _create_tile_check_rules() -> Array[TileCheckRule]:
	var rules: Array[TileCheckRule] = []
	var rule := TileCheckRule.new()
	rules.append(rule)
	return rules
