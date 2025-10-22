## IndicatorSetupUtils Unit Tests
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
##
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
extends GdUnitTestSuite

## Test constants for magic number elimination
const DEFAULT_TILE_SIZE := GBTestConstants.DEFAULT_TILE_SIZE_I
const TEST_POSITION_CENTER := GBTestConstants.DEFAULT_TEST_POSITION
const TEST_RECT_SIZE_SMALL := Vector2(GBTestConstants.DEFAULT_TILE_PX * 2, GBTestConstants.DEFAULT_TILE_PX * 2)
const TEST_RECT_SIZE_LARGE := Vector2(GBTestConstants.DEFAULT_TILE_PX * 4, GBTestConstants.DEFAULT_TILE_PX * 4)
const COLLISION_LAYER_DEFAULT := 1
const COLLISION_MASK_SINGLE := 1
const COLLISION_MASK_MIXED := 2560 | 513

## Test position constants for indicator validation
const TILE_POS_ORIGIN := Vector2i(0, 0)
const TILE_POS_RIGHT := Vector2i(1, 0)
const TILE_POS_DOWN := Vector2i(0, 1)
const TILE_POS_WRONG := Vector2i(5, 5)

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

var runner: GdUnitSceneRunner
var _targeting_state: GridTargetingState
var _indicator_template: PackedScene
var _test_rule: TileCheckRule
var env : CollisionTestEnvironment

func before_test() -> void:
	# Setup common test dependencies using scene_runner
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	env = runner.scene() as CollisionTestEnvironment

	assert_object(env).append_failure_message(
		"Failed to load CollisionTestEnvironment scene"
	).is_not_null()

	_targeting_state = env.container.get_targeting_state()
	_indicator_template = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	_test_rule = TileCheckRule.new()

## Test gather_collision_shapes with null input
func test_gather_collision_shapes_null_input() -> void:
	var result := IndicatorSetupUtils.gather_collision_shapes(null)
	assert_that(result).append_failure_message("Expected empty result when input is null").is_empty()

## Test gather_collision_shapes with empty node
func test_gather_collision_shapes_empty_node() -> void:
	var empty_node := Node2D.new()

	var result := IndicatorSetupUtils.gather_collision_shapes(empty_node)
	assert_that(result)
  .append_failure_message("Expected empty result when node has no collision shapes").is_empty()

	empty_node.queue_free()

## Parameterized test for collision shape gathering across multiple test scenes
func test_gather_collision_shapes_parameterized() -> void:
	for test_data: Dictionary in TEST_SCENE_DATA:
		var scene_path: String = test_data["scene_path"]
		var test_name: String = test_data["name"]

		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			var diag: PackedStringArray = PackedStringArray()
			diag.append("Warning: Could not load scene at path: %s" % scene_path)
			var context := "\n".join(diag)
			assert_bool(scene != null).append_failure_message("Scene should load successfully: %s\nContext: %s" % [scene_path, context]).is_true()
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

#region FAILURE ISOLATION TESTS - Mirror Integration Test Failures

# FAILING TEST: Mirror integration test failure - execute_indicator_setup produces 0 indicators despite collision shapes
# Expected failure: setup should create indicators but returns empty array despite finding collision shapes
func test_execute_indicator_setup_produces_zero_indicators_despite_collision_shapes() -> void:
	# Load smithy to match integration test pattern
	var smithy_scene: PackedScene = load(GBTestConstants.SMITHY_PATH)
	assert_object(smithy_scene).append_failure_message("Failed to load Smithy scene").is_not_null()

	var smithy_obj: Node2D = smithy_scene.instantiate()
	add_child(smithy_obj)
	auto_free(smithy_obj)
	smithy_obj.global_position = TEST_POSITION_CENTER

	# Create rule matching integration test - mask for both Area2D and StaticBody2D layers
	var rule := TileCheckRule.new()
	rule.apply_to_objects_mask = COLLISION_MASK_MIXED
	var rules: Array[TileCheckRule] = [rule]

	# Test collision shape gathering (this should work)
	var collision_shapes: Dictionary = IndicatorSetupUtils.gather_collision_shapes(smithy_obj)
	var collision_shapes_count := collision_shapes.size()
	assert_that(collision_shapes_count).append_failure_message(
		"Smithy should have collision shapes"
	).is_greater(0)

	# Test collision test setups building with correct parameters
	var test_setups: Dictionary = IndicatorSetupUtils.build_collision_test_setups(collision_shapes, DEFAULT_TILE_SIZE)
	assert_that(test_setups.size()).append_failure_message(
		"Should build collision test setups from smithy shapes"
	).is_greater(0)

	# Get collision mapper from environment (direct property access)
	var collision_mapper: CollisionMapper = env.collision_mapper
 assert_object(collision_mapper)
  .append_failure_message("CollisionMapper should be available in test environment").is_not_null()

	# CRITICAL: This should create indicators but returns empty result
	# Create a proper Node2D parent for indicators
	var indicator_parent := _create_indicator_parent()

	var setup_result: IndicatorSetupUtils.SetupResult = IndicatorSetupUtils.execute_indicator_setup(
		smithy_obj,
		rules,
		collision_mapper,
		_indicator_template,
		indicator_parent,  # Use Node2D parent instead of test suite
		_targeting_state
	)

	# Calculate expected collision tiles for diagnostic
	var collision_results: Dictionary = collision_mapper.get_collision_tile_positions_with_mask([smithy_obj] as Array[Node2D], COLLISION_MASK_MIXED)
	var expected_collision_tiles: int = collision_results.size()

	# Check if setup_result is valid before accessing properties
	if setup_result == null:
		var diag: PackedStringArray = PackedStringArray()
		diag.append("IndicatorSetupUtils.execute_indicator_setup returned null")
		assert_that(false).append_failure_message(
			"IndicatorSetupUtils.execute_indicator_setup returned null. DBG: collision_shapes=%d, test_setups=%d, expected_collision_tiles=%d, smithy_pos=%s\n%s" % [
				collision_shapes_count, test_setups.size(), expected_collision_tiles, smithy_obj.global_position, "\n".join(diag)
			]
		).is_true()
		return

	# This assertion should FAIL - mirrors integration test smithy failure
	assert_that(setup_result.indicators.size()).append_failure_message(
		"Expected IndicatorSetupUtils.execute_indicator_setup to create indicators but got 0. DBG: collision_shapes=%d, test_setups=%d, expected_collision_tiles=%d, setup_issues=%s, smithy_pos=%s" % [
			collision_shapes_count, test_setups.size(), expected_collision_tiles, str(setup_result.issues), smithy_obj.global_position
		]
	).is_greater(0)

# FAILING TEST: Mirror integration test - collision mapping finds tiles but indicator generation fails
# Expected failure: collision system works but indicator creation pipeline breaks down
func test_collision_mapping_works_but_indicator_creation_fails() -> void:
	# Create simple test object with known collision shape
	var test_object := _create_simple_collision_object(TEST_POSITION_CENTER, TEST_RECT_SIZE_SMALL)

	# Create rule
	var rule := _create_collision_rule(COLLISION_MASK_SINGLE)
	var rules: Array[TileCheckRule] = [rule]

	# Test collision mapping directly (this should work)
	var collision_mapper: CollisionMapper = env.collision_mapper
 assert_object(collision_mapper)
  .append_failure_message("CollisionMapper should be available").is_not_null()

	# CRITICAL FIX: Set up CollisionMapper with CollisionTestSetup2D for the test object
	var test_setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(test_object, _targeting_state)
	assert_that(test_setups.size()).is_greater(0)
  .append_failure_message("Should create at least one CollisionTestSetup2D for the test object")

	# Create test indicator for collision mapper setup
	var test_indicator: RuleCheckIndicator = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER.instantiate()
	add_child(test_indicator)
	auto_free(test_indicator)

	# Set up collision mapper with the test object
	collision_mapper.setup(test_indicator, test_setups)

	# Add debug info about the test setup before collision mapping
	var collision_shapes_in_object := 0
	for child in test_object.get_children():
		if child is CollisionShape2D:
			collision_shapes_in_object += 1

	var collision_results: Dictionary = collision_mapper.get_collision_tile_positions_with_mask([test_object] as Array[Node2D], COLLISION_MASK_SINGLE)
	var collision_tiles_found: int = collision_results.size()

	# Verify collision mapping works
	assert_that(collision_tiles_found).append_failure_message(
		"Collision mapping should find tiles. DBG: test_object_type=%s, position=%s, collision_layer=%d, collision_mask=%d, collision_shapes_count=%d, tilemap_size=%s, targeting_state_valid=%s" % [
			test_object.get_class(),
			str(test_object.global_position),
			test_object.collision_layer,
			COLLISION_MASK_SINGLE,
			collision_shapes_in_object,
			str(_targeting_state.target_map.get_used_rect()) if _targeting_state.target_map else "null_tilemap",
			str(_targeting_state != null)
		]
	).is_greater(0)

	# Test full indicator setup workflow
	# Create a proper Node2D parent for indicators
	var indicator_parent := _create_indicator_parent()

	var setup_result: IndicatorSetupUtils.SetupResult = IndicatorSetupUtils.execute_indicator_setup(
		test_object,
		rules,
		collision_mapper,
		_indicator_template,
		indicator_parent,  # Use Node2D parent instead of test suite
		_targeting_state
	)

	# Check if setup_result is valid before accessing properties
	if setup_result == null:
		var diag: PackedStringArray = PackedStringArray()
		diag.append("IndicatorSetupUtils.execute_indicator_setup returned null when collision mapping finds %d tiles" % collision_tiles_found)
		assert_that(false).append_failure_message(
			"IndicatorSetupUtils.execute_indicator_setup returned null when collision mapping finds %d tiles. DBG: collision_tiles=%d, test_object_pos=%s\n%s" % [
				collision_tiles_found, collision_tiles_found, test_object.global_position, "\n".join(diag)
			]
		).is_true()
		return

	# This assertion should FAIL - collision mapping works but indicator creation fails
	assert_that(setup_result.indicators.size()).is_greater(0).append_failure_message(
		"Expected indicator creation to succeed when collision mapping finds %d tiles. DBG: collision_tiles=%d, setup_issues=%s, test_object_pos=%s" % [
			collision_tiles_found, collision_tiles_found, str(setup_result.issues), test_object.global_position
		]
	)

	# Verify collision system is working (this should pass)
	var collision_shape_info := ""
	for child in test_object.get_children():
		if child is CollisionShape2D:
			var shape_details := "no_shape"
			if child.shape:
				shape_details = child.shape.get_class() + ":" + str(child.shape.size if child.shape.has_method("get_size") else "no_size")
			collision_shape_info += shape_details + " "

	assert_int(collision_tiles_found).append_failure_message(
		"Collision system should find at least 1 tile for 2x2 object. DBG: collision_results_size=%d, test_object_children_count=%d, collision_shape_info='%s', collision_mapper_valid=%s, test_object_collision_layer=%d" % [
			collision_results.size(),
			test_object.get_children().size(),
			collision_shape_info.strip_edges(),
			str(collision_mapper != null),
			test_object.collision_layer
		]
	).is_greater_equal(1)

#endregion

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

	assert_that(result).append_failure_message("Expected collision shapes to be found").is_not_empty()
	assert_that(result.has(collision_owner))
  .append_failure_message("Expected collision_owner to be in result").is_true()
	assert_that(result[collision_owner])
  .append_failure_message("Expected shapes array to not be empty").is_not_empty()
	assert_that(result[collision_owner][0])
  .append_failure_message("Expected first shape to be RectangleShape2D").is_class("RectangleShape2D")
	assert_that(result[collision_owner][0].size)
  .append_failure_message("Expected shape size to be Vector2(32, 32)").is_equal(Vector2(32, 32))

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

	assert_that(result.has_issues())
  .append_failure_message("Expected setup to have issues with null inputs").is_true()
	assert_that(result.indicators)
  .append_failure_message("Expected no indicators when setup has issues").is_empty()

## Parameterized test for complete indicator setup workflow
func test_execute_indicator_setup_basic_success() -> void:
	# Arrange
	var test_object: Node2D = _create_test_object_with_shapes()
	var tile_check_rules: Array[TileCheckRule] = _create_tile_check_rules()
	var collision_mapper: CollisionMapper = CollisionMapper.new(_targeting_state, env.get_logger())
	var indicators_parent: Node2D = _create_indicator_parent()

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

## Test calculate_indicator_count with various test objects
func test_calculate_indicator_count_parameterized() -> void:
	for test_data: Dictionary in TEST_SCENE_DATA:
		var scene_path: String = test_data["scene_path"]
		var test_name: String = test_data["name"]

		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			var diag: PackedStringArray = PackedStringArray()
			diag.append("Warning: Could not load scene at path: %s" % scene_path)
			var context := "\n".join(diag)
			assert_bool(scene != null).append_failure_message("Scene should load successfully: %s\nContext: %s" % [scene_path, context]).is_true()
			continue

		var test_object: Node2D = scene.instantiate() as Node2D
		add_child(test_object)

		var collision_mapper: CollisionMapper = CollisionMapper.new(_targeting_state, env.get_logger())
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
	var expected_positions: Array[Vector2i] = [TILE_POS_ORIGIN, TILE_POS_RIGHT, TILE_POS_DOWN]

	# Create indicators at the expected tile positions
	for pos: Vector2i in expected_positions:
		var indicator: RuleCheckIndicator = _indicator_template.instantiate() as RuleCheckIndicator
		add_child(indicator)
		auto_free(indicator)

		var world_pos: Vector2 = _targeting_state.target_map.map_to_local(pos)
		indicator.global_position = world_pos
		indicators.append(indicator)

	var result: IndicatorSetupUtils.PositionValidationResult = IndicatorSetupUtils.validate_indicator_positions(
		indicators,
		expected_positions,
		_targeting_state
	)

	assert_that(result.is_valid)
  .append_failure_message("Expected validation to be successful").is_true()
	assert_that(result.size_mismatch).append_failure_message("Expected no size mismatch").is_false()
	assert_that(result.position_mismatches)
  .append_failure_message("Expected no position mismatches").is_empty()

## Test validate_indicator_positions with size mismatch
func test_validate_indicator_positions_size_mismatch() -> void:
	var indicators: Array[RuleCheckIndicator] = []
	var expected_positions: Array[Vector2i] = [TILE_POS_ORIGIN, TILE_POS_RIGHT]

	# Create only one indicator (size mismatch)
	var indicator: RuleCheckIndicator = _indicator_template.instantiate() as RuleCheckIndicator
	add_child(indicator)
	auto_free(indicator)
	indicators.append(indicator)

	var result: IndicatorSetupUtils.PositionValidationResult = IndicatorSetupUtils.validate_indicator_positions(
		indicators,
		expected_positions,
		_targeting_state
	)

	assert_that(result.is_valid)
  .append_failure_message("Expected validation to fail due to size mismatch").is_false()
	assert_that(result.size_mismatch)
  .append_failure_message("Expected size mismatch to be detected").is_true()
	assert_that(result.expected_count).append_failure_message("Expected count should be 2").is_equal(2)
	assert_that(result.actual_count).append_failure_message("Actual count should be 1").is_equal(1)

## Test validate_indicator_positions with position mismatch
func test_validate_indicator_positions_position_mismatch() -> void:
	var indicators: Array[RuleCheckIndicator] = []
	var expected_positions: Array[Vector2i] = [TILE_POS_ORIGIN]

	# Create indicator at wrong position
	var indicator: RuleCheckIndicator = _indicator_template.instantiate() as RuleCheckIndicator
	add_child(indicator)
	auto_free(indicator)
	var wrong_world_pos: Vector2 = _targeting_state.target_map.map_to_local(TILE_POS_WRONG)  # Wrong position
	indicator.global_position = wrong_world_pos
	indicators.append(indicator)

	var result: IndicatorSetupUtils.PositionValidationResult = IndicatorSetupUtils.validate_indicator_positions(
		indicators,
		expected_positions,
		_targeting_state
	)

	assert_that(result.is_valid)
  .append_failure_message("Expected validation to fail due to position mismatch").is_false()
	assert_that(result.size_mismatch).append_failure_message("Expected no size mismatch").is_false()
	assert_that(result.position_mismatches)
  .append_failure_message("Expected position mismatches to be detected").is_not_empty()
	assert_that(result.position_mismatches[0]["expected"])
  .append_failure_message("Expected position should be TILE_POS_ORIGIN").is_equal(TILE_POS_ORIGIN)
	assert_that(result.position_mismatches[0]["actual"])
  .append_failure_message("Actual position should be TILE_POS_WRONG").is_equal(TILE_POS_WRONG)

## Test build_collision_test_setups with empty input
func test_build_collision_test_setups_empty_input() -> void:
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var tile_size := Vector2i(GBTestConstants.DEFAULT_TILE_SIZE.x, GBTestConstants.DEFAULT_TILE_SIZE.y)

	var result := IndicatorSetupUtils.build_collision_test_setups(owner_shapes, tile_size)
	assert_that(result).append_failure_message("Expected empty result with empty input").is_empty()

## Test build_collision_test_setups with CollisionObject2D owner
func test_build_collision_test_setups_collision_object_owner() -> void:
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var collision_owner := StaticBody2D.new()
	var shapes: Array[Node2D] = []
	owner_shapes[collision_owner] = shapes

	var tile_size := Vector2i(GBTestConstants.DEFAULT_TILE_SIZE.x, GBTestConstants.DEFAULT_TILE_SIZE.y)

	var result := IndicatorSetupUtils.build_collision_test_setups(owner_shapes, tile_size)

	assert_that(result)
  .append_failure_message("Expected collision setups to be created").is_not_empty()
	assert_that(result.has(collision_owner))
  .append_failure_message("Expected collision_owner to be in result").is_true()
	assert_that(result[collision_owner])
  .append_failure_message("Expected setup to not be null").is_not_null()
	assert_that(result[collision_owner]).append_failure_message("Expected setup to be CollisionTestSetup2D").is_class("CollisionTestSetup2D")

	# Verify the stretch amount calculation (tile_size * 2.0)
	var expected_stretch := Vector2(32, 32)  # 16 * 2.0
	assert_that(result[collision_owner].shape_stretch_size).append_failure_message("Expected shape stretch size to be Vector2(32, 32)").is_equal(expected_stretch)

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

	assert_that(result).append_failure_message("Expected result to not be empty").is_not_empty()
	assert_that(result.has(collision_owner))
  .append_failure_message("Expected collision_owner to be in result").is_true()
	assert_that(result[collision_owner]).append_failure_message("Expected null setup for CollisionPolygon2D").is_null()  # CollisionPolygon2D gets null setup

	# Cleanup
	collision_owner.queue_free()

## Test map_positions_to_rules with null collision mapper
func test_map_positions_to_rules_null_mapper() -> void:
	var collision_mapper: CollisionMapper = null
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var rules: Array[TileCheckRule] = []

	var result := IndicatorSetupUtils.map_positions_to_rules(collision_mapper, owner_shapes, rules)
	assert_that(result)
  .append_failure_message("Expected empty result with null collision mapper").is_empty()

## Test validate_setup_preconditions with valid inputs
func test_validate_setup_preconditions_valid_inputs() -> void:
	var test_object := Node2D.new()
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper

	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, mock_collision_mapper)
	assert_that(result)
  .append_failure_message("Expected no validation issues with valid preconditions").is_empty()

	# Cleanup
	test_object.queue_free()

## Test validate_setup_preconditions with null test object
func test_validate_setup_preconditions_null_test_object() -> void:
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper

	var result := IndicatorSetupUtils.validate_setup_preconditions(null, rules, mock_collision_mapper)
	assert_that(result)
  .append_failure_message("Expected validation issues with null test object").is_not_empty()
	assert_that(result.has("Test object is null or invalid")).is_true()

## Test validate_setup_preconditions with empty rules
func test_validate_setup_preconditions_empty_rules() -> void:
	var test_object := Node2D.new()
	var rules: Array[TileCheckRule] = []
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper

	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, mock_collision_mapper)
	assert_that(result)
  .append_failure_message("Expected validation issues with empty rules").is_not_empty()
	assert_that(result.has("No tile check rules provided"))
  .append_failure_message("Expected specific error message about rules").is_true()

	# Cleanup
	test_object.queue_free()

## Test validate_setup_preconditions with null collision mapper
func test_validate_setup_preconditions_null_collision_mapper() -> void:
	var test_object := Node2D.new()
	auto_free(test_object)
	add_child(test_object)
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]

	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, null)
	assert_that(result)
  .append_failure_message("Expected validation issues with null collision mapper").is_not_empty()
	assert_that(result.has("Collision mapper is not available"))
  .append_failure_message("Expected specific error message about collision mapper").is_true()

	# Cleanup
	test_object.free()

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

## Helper method to create a Node2D parent for indicators with proper setup
func _create_indicator_parent(p_name: String = "IndicatorParent") -> Node2D:
	return GodotTestFactory.create_node2d(self, p_name)

## Helper method to create a simple test object with rectangular collision shape
func _create_simple_collision_object(position: Vector2 = TEST_POSITION_CENTER, size: Vector2 = TEST_RECT_SIZE_SMALL) -> StaticBody2D:
	var body := StaticBody2D.new()
	add_child(body)
	auto_free(body)
	body.global_position = position

	# Add collision shape
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	body.collision_layer = COLLISION_LAYER_DEFAULT
	body.add_child(collision_shape)

	return body

## Helper method to create a basic tile check rule with specified mask
func _create_collision_rule(mask: int = COLLISION_MASK_SINGLE) -> TileCheckRule:
	var rule := TileCheckRule.new()
	rule.apply_to_objects_mask = mask
	return rule

## Helper method to create collision rules matching integration test patterns
func _create_mixed_collision_rules() -> Array[TileCheckRule]:
	var rule := TileCheckRule.new()
	rule.apply_to_objects_mask = COLLISION_MASK_MIXED
	return [rule]

## Helper method to load and instantiate a test scene
func _load_test_scene(scene_path: String, position: Vector2 = TEST_POSITION_CENTER) -> Node2D:
	var scene: PackedScene = load(scene_path) as PackedScene
 assert_object(scene).append_failure_message("Failed to load scene: " + scene_path).is_not_null()

	var instance: Node2D = scene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.global_position = position

	return instance

## Helper method to validate collision mapping works for test objects
func _validate_collision_mapping(test_objects: Array[Node2D], mask: int = COLLISION_MASK_SINGLE) -> int:
	var collision_mapper: CollisionMapper = env.collision_mapper
 assert_object(collision_mapper)
  .append_failure_message("CollisionMapper should be available").is_not_null()

	var collision_results: Dictionary = collision_mapper.get_collision_tile_positions_with_mask(test_objects, mask)
	var tiles_found: int = collision_results.size()

 assert_that(tiles_found).append_failure_message( "Collision mapping should find tiles for mask %d" % mask ) return tiles_found ## Helper method to run indicator setup and validate basic success func _run_indicator_setup(test_object: Node2D, rules: Array[TileCheckRule], expected_success: bool = true) -> IndicatorSetupUtils.SetupResult: var collision_mapper: CollisionMapper = env.collision_mapper var indicator_parent := _create_indicator_parent() var setup_result: IndicatorSetupUtils.SetupResult = IndicatorSetupUtils.execute_indicator_setup( test_object, rules, collision_mapper, _indicator_template, indicator_parent, _targeting_state ) if expected_success: assert_object(setup_result).append_failure_message("Setup result should not be null").is_not_null().is_greater(0)
		assert_that(setup_result.indicators.size()).is_greater(0).append_failure_message(
			"Expected indicators to be created. Issues: %s" % str(setup_result.issues)
		)

	return setup_result

## Test collision rule creation and configuration - isolates integration test failures
func test_collision_rule_validation_setup() -> void:
	# This test isolates the rule setup logic issues seen in integration tests
	var test_object := Node2D.new()
	auto_free(test_object)
	add_child(test_object)

	# Create a collision rule with specific configuration
	var collision_rule := CollisionsCheckRule.new()
	collision_rule.pass_on_collision = false  # Should fail when collision detected
	collision_rule.apply_to_objects_mask = 1  # Layer 1

	# Test rule properties are set correctly
	assert_bool(collision_rule.pass_on_collision)
  .append_failure_message("Expected pass_on_collision to be false").is_false()
	assert_int(collision_rule.apply_to_objects_mask)
  .append_failure_message("Expected collision mask to be 1").is_equal(1)

	var rules: Array[TileCheckRule] = [collision_rule]
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper

	# Basic setup validation should pass
	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, mock_collision_mapper)
	assert_that(result).append_failure_message("Expected no validation issues with properly configured collision rule").is_empty()

	var diag_rule_ok: PackedStringArray = PackedStringArray()
	diag_rule_ok.append("Collision rule validation test - rule configured properly, setup validation passed")

## Test rule validation with multiple rules - isolates multi-rule scenarios
func test_multiple_rule_validation_setup() -> void:
	var test_object := Node2D.new()
	auto_free(test_object)
	add_child(test_object)

	# Create multiple rules as seen in failing tests
	var collision_rule := CollisionsCheckRule.new()
	collision_rule.pass_on_collision = true  # Pass on collision
	collision_rule.apply_to_objects_mask = 1

	var tile_rule := TileCheckRule.new()
	tile_rule.apply_to_objects_mask = 2

	var rules: Array[TileCheckRule] = [collision_rule, tile_rule]
	var mock_collision_mapper := mock(CollisionMapper) as CollisionMapper

	# Test that multiple rules can be set up without issues
	var result := IndicatorSetupUtils.validate_setup_preconditions(test_object, rules, mock_collision_mapper)
	assert_that(result)
  .append_failure_message("Expected no validation issues with multiple rules").is_empty()

	# Verify rule count and types
	assert_int(rules.size()).append_failure_message("Expected 2 rules").is_equal(2)
	assert_bool(rules[0] is CollisionsCheckRule)
  .append_failure_message("Expected first rule to be CollisionsCheckRule").is_true()
	assert_bool(rules[1] is TileCheckRule)
  .append_failure_message("Expected second rule to be TileCheckRule").is_true()

	var diag_multi: PackedStringArray = PackedStringArray()
	diag_multi.append("Multiple rule validation test - %d rules configured, setup validation passed" % rules.size())
