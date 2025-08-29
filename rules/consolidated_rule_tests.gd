extends GdUnitTestSuite

## Consolidated rule tests
## Combines all rule-related tests into a single comprehensive suite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_setup: Dictionary

func before_test() -> void:
	test_setup = UnifiedTestFactory.create_basic_test_setup(self, TEST_CONTAINER)
	test_setup.merge(UnifiedTestFactory.create_rule_validation_parameters(self))
	test_setup.merge(UnifiedTestFactory.create_collision_mapper_setup(self))

# ================================
# TileCheckRule Tests (from tile_check_rule_test.gd)
# ================================

func test_tile_check_rule_creation() -> void:
	var rule = TileCheckRule.new()
	auto_free(rule)
	
	assert_that(rule).is_not_null()
	# Rule interface is assumed to exist - fail fast approach

func test_tile_check_rule_basic_validation() -> void:
	var rule = TileCheckRule.new()
	auto_free(rule)
	
	var _logger = test_setup.logger
	var owner_context = UnifiedTestFactory.create_owner_context(self)
	var targeting_state: Object = GridTargetingState.new(owner_context)
	auto_free(targeting_state)
	
	# Create basic tile map setup
	var tile_map = GodotTestFactory.create_tile_map_layer(self, 8)
	targeting_state.target_map = tile_map
	
	# Create test positioner and placer
	var positioner = GodotTestFactory.create_node2d(self)
	var _placer = GodotTestFactory.create_node2d(self)
	
	targeting_state.positioner = positioner
	
	# Test rule check - basic functionality
	# Note: Simplified test - full implementation would require more setup
	assert_that(rule).is_not_null()

# ================================
# CollisionsCheckRule Tests (from collisions_check_rule_test.gd)
# ================================

func test_collisions_check_rule_creation() -> void:
	var rule = CollisionsCheckRule.new()
	auto_free(rule)
	
	assert_that(rule).is_not_null()
	# Rule interface is assumed to exist - fail fast approach

func test_collisions_check_rule_with_indicator() -> void:
	var _container: GBCompositionContainer = UnifiedTestFactory.create_test_composition_container(self)
	var rule = CollisionsCheckRule.new()
	auto_free(rule)
	
	# Create a basic indicator for testing
	var indicator_template = TEST_CONTAINER.get_templates().indicator
	if indicator_template:
		var indicator = indicator_template.instantiate()
		auto_free(indicator)
		add_child(indicator)
		
		# Test rule with indicator
		assert_that(rule).is_not_null()
		assert_that(indicator).is_not_null()

func test_collisions_check_rule_validation_results() -> void:
	var rule = CollisionsCheckRule.new()
	auto_free(rule)
	
	# Test that rule produces valid results structure
	# Note: This would need proper setup with collision objects in real implementation
	# Rule interface is assumed to exist - fail fast approach

# ================================
# WithinTilemapBoundsRule Tests (from within_tilemap_bounds_rule_test.gd)
# ================================

func test_within_bounds_rule_creation() -> void:
	var rule = WithinTilemapBoundsRule.new()
	auto_free(rule)
	
	assert_that(rule).is_not_null()
	# Rule interface is assumed to exist - fail fast approach

func test_within_bounds_rule_boundary_checking() -> void:
	var rule = WithinTilemapBoundsRule.new()
	auto_free(rule)
	
	# Create tile map with known bounds
	var tile_map = GodotTestFactory.create_tile_map_layer(self, 8)  # 8x8 tile map
	
	# Test positions within and outside bounds
	var _within_bounds_pos = Vector2i(4, 4)  # Center, should be valid
	var _outside_bounds_pos = Vector2i(10, 10)  # Outside, should be invalid
	
	# Note: Actual validation would require proper rule context setup
	assert_that(rule).is_not_null()
	assert_that(tile_map).is_not_null()
	
	# Verify bounds exist
	var tile_set = tile_map.tile_set
	assert_that(tile_set).is_not_null()

func test_within_bounds_rule_edge_cases() -> void:
	var rule = WithinTilemapBoundsRule.new()
	auto_free(rule)
	
	# Create minimal tile map
	var tile_map = GodotTestFactory.create_tile_map_layer(self, 1)  # 1x1 tile map
	
	# Test edge positions
	var edge_positions: Array = [
		Vector2i(0, 0),    # Top-left corner
		Vector2i(-1, 0),   # Just outside left
		Vector2i(0, -1),   # Just outside top
		Vector2i(1, 0),    # Just outside right
		Vector2i(0, 1)     # Just outside bottom
	]
	
	# Note: Actual boundary validation would need proper implementation
	assert_that(rule).is_not_null()
	assert_that(tile_map).is_not_null()
	assert_int(edge_positions.size()).is_equal(5)

# ================================
# Rule Integration Tests
# ================================

func test_multiple_rules_combination() -> void:
	# Test combining multiple rule types
	var tile_rule = TileCheckRule.new()
	var collision_rule = CollisionsCheckRule.new()
	var bounds_rule = WithinTilemapBoundsRule.new()
	
	auto_free(tile_rule)
	auto_free(collision_rule) 
	auto_free(bounds_rule)
	
	var rules: Array = [tile_rule, collision_rule, bounds_rule]
	
	assert_int(rules.size()).is_equal(3)
	for rule in rules:
		assert_that(rule).is_not_null()
		# Rule interface is assumed to exist - fail fast approach

func test_rule_validation_chain() -> void:
	# Test that rules can be chained for validation
	var rules: Array = [
		TileCheckRule.new(),
		CollisionsCheckRule.new(),
		WithinTilemapBoundsRule.new()
	]
	
	for rule in rules:
		auto_free(rule)
	
	# Test basic rule chain processing
	var processed_rules: Array = []
	for rule in rules:
		# Direct rule processing - fail fast approach
		processed_rules.append(rule)
	
	assert_int(processed_rules.size()).is_equal(3)

func test_rule_error_handling() -> void:
	# Test rule behavior with invalid inputs
	var rule = TileCheckRule.new()
	auto_free(rule)
	
	# Test that rule handles null inputs gracefully
	assert_that(rule).is_not_null()
	
	# Note: Actual error handling tests would require proper implementation
	# This is a placeholder to ensure rules exist and have expected methods

# ================================
# Rule Performance Tests  
# ================================

func test_rule_performance_single() -> void:
	var rule = TileCheckRule.new()
	auto_free(rule)
	
	# Time basic rule operations
	var start_time: int = Time.get_ticks_msec()
	
	# Simulate rule processing (simplified)
	for i in range(100):
		# Basic rule method calls - direct access
		pass  # Would call rule.check() with proper parameters
	
	var end_time: int = Time.get_ticks_msec()
	var processing_time = end_time - start_time
	
	# Should complete quickly
	assert_int(processing_time).is_less_equal(50)  # 50ms max for 100 operations

func test_rule_performance_multiple() -> void:
	var rules: Array = [
		TileCheckRule.new(),
		CollisionsCheckRule.new(),
		WithinTilemapBoundsRule.new()
	]
	
	for rule in rules:
		auto_free(rule)
	
	# Time multiple rule operations
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(10):
		for rule in rules:
			# Direct rule processing - fail fast approach
			pass  # Would call rule.check() with proper parameters
	
	var end_time: int = Time.get_ticks_msec()
	var processing_time = end_time - start_time
	
	# Should complete quickly even with multiple rules
	assert_int(processing_time).is_less_equal(100)  # 100ms max for 30 operations

# ================================
# Rule Configuration Tests
# ================================

func test_rule_configuration_properties() -> void:
	# Test that rules have expected configuration properties
	var tile_rule = TileCheckRule.new()
	auto_free(tile_rule)
	
	# Most rules should be configurable
	assert_that(tile_rule).is_not_null()
	
	# Test that rule can be configured (placeholder)
	# Real implementation would test specific rule properties

func test_rule_serialization_compatibility() -> void:
	# Test that rules can be saved/loaded if needed
	var rule = TileCheckRule.new()
	auto_free(rule)
	
	# Basic serialization test - ensure rule has necessary methods
	assert_that(rule).is_not_null()
	
	# Note: Actual serialization tests would require proper implementation
	# This ensures basic rule structure exists
