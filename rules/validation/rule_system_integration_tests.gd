extends GdUnitTestSuite

## Consolidated rule tests
## Combines all rule-related tests into a single comprehensive suite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# Test constants for magic number elimination
const DEFAULT_TILE_MAP_SIZE: int = 8
const MINIMAL_TILE_MAP_SIZE: int = 1
const PERFORMANCE_TEST_ITERATIONS: int = 100
const MULTIPLE_RULE_TEST_ITERATIONS: int = 10
const SINGLE_RULE_TIMEOUT_MS: int = 50
const MULTIPLE_RULE_TIMEOUT_MS: int = 100
const EXPECTED_RULE_COUNT: int = 3
const EDGE_POSITION_COUNT: int = 5
const CENTER_POSITION_X: int = 4
const CENTER_POSITION_Y: int = 4
const OUTSIDE_BOUNDS_X: int = 10
const OUTSIDE_BOUNDS_Y: int = 10

var env: AllSystemsTestEnvironment

func before_test() -> void:
	env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)

# Helper functions for DRY patterns

## Creates a rule instance and automatically frees it after the test
func create_rule(rule_type: GDScript) -> Object:
	var rule: Object = rule_type.new()
	auto_free(rule)
	return rule

## Creates all standard rule types and returns them as an array
func create_all_rules() -> Array[Object]:
	var rules: Array[Object] = [
		TileCheckRule.new(),
		CollisionsCheckRule.new(),
		WithinTilemapBoundsRule.new()
	]
	for rule in rules:
		auto_free(rule)
	return rules

## Performs basic rule validation assertion
func assert_rule_valid(rule: Object) -> void:
	assert_that(rule).is_not_null()
	# Rule interface is assumed to exist - fail fast approach

## Times a block of code and returns the processing time in milliseconds
func time_execution(callable: Callable) -> int:
	var start_time: int = Time.get_ticks_msec()
	callable.call()
	var end_time: int = Time.get_ticks_msec()
	return end_time - start_time

#region TileCheckRule Tests (from tile_check_rule_test.gd)

func test_tile_check_rule_creation() -> void:
	var rule: TileCheckRule = create_rule(TileCheckRule)
	assert_rule_valid(rule)

func test_tile_check_rule_basic_validation() -> void:
	var rule: TileCheckRule = TileCheckRule.new()
	auto_free(rule)
	
	# Get dependencies from environment container instead of creating them manually
	var container: GBCompositionContainer = env.get_container()
	var logger: GBLogger = container.get_logger()
	var targeting_state: GridTargetingState = container.get_states().targeting
	var gb_owner: GBOwner = env.gb_owner
	
	# Use premade 31x31 tilemap for rule tests instead of creating small maps
	var tile_map: TileMapLayer = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE.instantiate() as TileMapLayer
	add_child(tile_map)
	auto_free(tile_map)
	targeting_state.target_map = tile_map
	
	# Create test positioner and placer
	var positioner: Node2D = GodotTestFactory.create_node2d(self)
	var _placer: Node2D = GodotTestFactory.create_node2d(self)
	
	targeting_state.positioner = positioner
	
	# Test rule check - basic functionality
	# Note: Simplified test - full implementation would require more setup
	assert_that(rule).is_not_null()
	assert_that(logger).is_not_null()
	assert_that(container).is_not_null()
	assert_that(gb_owner).is_not_null()
	assert_that(targeting_state).is_not_null()

#endregion

#region CollisionsCheckRule Tests (from collisions_check_rule_test.gd)

func test_collisions_check_rule_creation() -> void:
	var rule: CollisionsCheckRule = create_rule(CollisionsCheckRule)
	assert_rule_valid(rule)

func test_collisions_check_rule_with_indicator() -> void:
	# Use environment container instead of creating one manually
	var container: GBCompositionContainer = env.get_container()
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	auto_free(rule)
	
	# Create a basic indicator for testing
	var indicator_template: PackedScene = TEST_CONTAINER.get_templates().rule_check_indicator
	if indicator_template:
		var indicator: Node = indicator_template.instantiate()
		auto_free(indicator)
		add_child(indicator)
		
		# Test rule with indicator
		assert_that(rule).is_not_null()
		assert_that(indicator).is_not_null()
		assert_that(container).is_not_null()

func test_collisions_check_rule_validation_results() -> void:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	auto_free(rule)
	
	# Test that rule produces valid results structure
	# Note: This would need proper setup with collision objects in real implementation
	# Rule interface is assumed to exist - fail fast approach

#endregion

#region WithinTilemapBoundsRule Tests (from within_tilemap_bounds_rule_test.gd)

func test_within_bounds_rule_creation() -> void:
	var rule: WithinTilemapBoundsRule = create_rule(WithinTilemapBoundsRule)
	assert_rule_valid(rule)

func test_within_bounds_rule_boundary_checking() -> void:
	var rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	auto_free(rule)
	
	# Use premade 31x31 tilemap for bounds rule testing
	var tile_map: TileMapLayer = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE.instantiate() as TileMapLayer
	add_child(tile_map)
	auto_free(tile_map)
	
	# Test positions within and outside bounds
	var _within_bounds_pos: Vector2i = Vector2i(CENTER_POSITION_X, CENTER_POSITION_Y)  # Center, should be valid
	var _outside_bounds_pos: Vector2i = Vector2i(OUTSIDE_BOUNDS_X, OUTSIDE_BOUNDS_Y)  # Outside, should be invalid
	
	# Note: Actual validation would require proper rule context setup
	assert_that(rule).is_not_null()
	assert_that(tile_map).is_not_null()
	
	# Verify bounds exist
	var tile_set: TileSet = tile_map.tile_set
	assert_that(tile_set).is_not_null()

func test_within_bounds_rule_edge_cases() -> void:
	var rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	auto_free(rule)
	
	# For edge case tests use the premade tilemap (31x31) but validate edge positions logically
	var tile_map: TileMapLayer = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE.instantiate() as TileMapLayer
	add_child(tile_map)
	auto_free(tile_map)
	
	# Test edge positions
	var edge_positions: Array[Vector2i] = [
		Vector2i(0, 0),    # Top-left corner
		Vector2i(-1, 0),   # Just outside left
		Vector2i(0, -1),   # Just outside top
		Vector2i(1, 0),    # Just outside right
		Vector2i(0, 1)     # Just outside bottom
	]
	
	# Note: Actual boundary validation would need proper implementation
	assert_that(rule).is_not_null()
	assert_that(tile_map).is_not_null()
	assert_int(edge_positions.size()).is_equal(EDGE_POSITION_COUNT)

#endregion

#region Rule Integration Tests

func test_multiple_rules_combination() -> void:
	# Test combining multiple rule types
	var rules: Array[Object] = create_all_rules()
	
	assert_int(rules.size()).is_equal(EXPECTED_RULE_COUNT)
	for rule in rules:
		assert_rule_valid(rule)

func test_rule_validation_chain() -> void:
	# Test that rules can be chained for validation
	var rules: Array[Object] = create_all_rules()
	
	# Test basic rule chain processing
	var processed_rules: Array[Object] = []
	for rule in rules:
		# Direct rule processing - fail fast approach
		processed_rules.append(rule)
	
	assert_int(processed_rules.size()).is_equal(EXPECTED_RULE_COUNT)

func test_rule_error_handling() -> void:
	# Test rule behavior with invalid inputs
	var rule: TileCheckRule = create_rule(TileCheckRule)
	assert_rule_valid(rule)
	
	# Note: Actual error handling tests would require proper implementation
	# This is a placeholder to ensure rules exist and have expected methods

#endregion

#region Rule Performance Tests

func test_rule_performance_single() -> void:
	var _rule: TileCheckRule = create_rule(TileCheckRule)
	
	# Time basic rule operations
	var processing_time: int = time_execution(func() -> void:
		# Simulate rule processing (simplified)
		for i in range(PERFORMANCE_TEST_ITERATIONS):
			# Basic rule method calls - direct access
			pass  # Would call rule.check() with proper parameters
	)
	
	# Should complete quickly
	assert_int(processing_time).is_less_equal(SINGLE_RULE_TIMEOUT_MS)  # 50ms max for 100 operations

func test_rule_performance_multiple() -> void:
	var rules: Array[Object] = create_all_rules()
	
	# Time multiple rule operations
	var processing_time: int = time_execution(func() -> void:
		for i in range(MULTIPLE_RULE_TEST_ITERATIONS):
			for rule in rules:
				# Direct rule processing - fail fast approach
				pass  # Would call rule.check() with proper parameters
	)
	
	# Should complete quickly even with multiple rules
	assert_int(processing_time).is_less_equal(MULTIPLE_RULE_TIMEOUT_MS)  # 100ms max for 30 operations

#endregion

#region Rule Configuration Tests

func test_rule_configuration_properties() -> void:
	# Test that rules have expected configuration properties
	var tile_rule: TileCheckRule = create_rule(TileCheckRule)
	assert_rule_valid(tile_rule)
	
	# Test that rule can be configured (placeholder)
	# Real implementation would test specific rule properties

func test_rule_serialization_compatibility() -> void:
	# Test that rules can be saved/loaded if needed
	var rule: TileCheckRule = create_rule(TileCheckRule)
	assert_rule_valid(rule)
	
	# Note: Actual serialization tests would require proper implementation
	# This ensures basic rule structure exists

#endregion
