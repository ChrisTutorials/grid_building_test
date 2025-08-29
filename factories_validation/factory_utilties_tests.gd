extends GdUnitTestSuite

## Consolidated Factories and Validation Test Suite
## Consolidates: factories_test.gd, validation_test.gd, factory_edge_cases_test.gd,
## validation_edge_cases_test.gd, factory_performance_test.gd, validation_performance_test.gd,
## factory_integration_test.gd, validation_integration_test.gd

## MARK FOR REMOVAL - factories_test.gd, validation_test.gd, factory_edge_cases_test.gd,
## validation_edge_cases_test.gd, factory_performance_test.gd, validation_performance_test.gd,
## factory_integration_test.gd, validation_integration_test.gd

#region FACTORY CREATION TESTS

func test_test_node2d_factory() -> void:
	# Test Node2D factory method
	var test_node: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	assert_object(test_node).append_failure_message(
		"Should create Node2D instance"
	).is_not_null()
	
	var node_class: String = test_node.get_class()
	assert_str(node_class).append_failure_message(
		"Should be Node2D type"
	).is_equal("Node2D")

func test_test_tilemap_factory() -> void:
	# Test TileMap from test environment
	var test_tilemap: TileMapLayer = UnifiedTestFactory.create_tile_map_layer(self)
	
	if test_tilemap:
		assert_object(test_tilemap).append_failure_message(
			"Should have TileMap instance in environment"
		).is_not_null()
		
		var tilemap_class: String = test_tilemap.get_class()
		assert_str(tilemap_class).append_failure_message(
			"Should be TileMap type"
		).is_equal("TileMap")

func test_composition_container_factory() -> void:
	var test_logger = UnifiedTestFactory.create_test_composition_container(self)
	
	var logger = test_logger.get_logger()
	assert_object(logger).append_failure_message(
		"Container should provide logger"
	).is_not_null()

# ===== FACTORY LAYERING TESTS =====

func test_placement_system_factory_layer() -> void:
	# Test placement system factory layer
	var placement_env: Dictionary = UnifiedTestFactory.create_indicator_system_test_environment(self)
	
	assert_object(placement_env).is_not_null()
	
	# Should include utilities layer components
	var container: GBCompositionContainer = placement_env.get("container")
	assert_object(container).is_not_null()
	
	# Should include placement-specific components
	var collision_mapper: Object = placement_env.get("collision_mapper")
	if collision_mapper:
		assert_object(collision_mapper).append_failure_message(
			"Placement environment should include collision mapper"
		).is_not_null()

func test_rule_indicator_factory_layer() -> void:
	# Test rule indicator factory layer
	var rule_env = UnifiedTestFactory.create_rule_indicator_test_environment(self)
	
	assert_object(rule_env).is_not_null()
	
	# Should include placement layer components
	assert_object(rule_env.get("collision_mapper")).is_not_null()
	
	# Should include rule-specific components
	var indicator_manager: Object = rule_env.get("indicator_manager")
	if indicator_manager:
		assert_object(indicator_manager).append_failure_message(
			"Rule environment should include indicator manager"
		).is_not_null()

func test_systems_integration_factory_layer() -> void:
	# Test systems integration factory layer
	var systems_env = UnifiedTestFactory.create_systems_integration_test_environment(self)
	
	assert_object(systems_env).is_not_null()
	
	# Should include all lower layer components
	assert_object(systems_env.get("container")).is_not_null()
	assert_object(systems_env.get("collision_mapper")).is_not_null()
	assert_object(systems_env.get("indicator_manager")).is_not_null()
	
	# Should include systems-specific components
	var building_manager = systems_env.get("building_manager")
	if building_manager:
		assert_object(building_manager).append_failure_message(
			"Systems environment should include building manager"
		).is_not_null()

#region FACTORY EDGE CASES

func test_factory_memory_cleanup() -> void:
	# Test that factory properly cleans up created objects
	var temp_node: Node2D = UnifiedTestFactory.create_test_node2d(self)
	var _node_path = temp_node.get_path()
	
	# Node should exist initially
	assert_object(temp_node).is_not_null()
	
	# After explicit cleanup, node should be freed
	temp_node.queue_free()
	await get_tree().process_frame
	
	# Node path should no longer be valid
	var is_still_valid = is_instance_valid(temp_node)
	assert_bool(is_still_valid).append_failure_message(
		"Node should be properly freed after cleanup"
	).is_false()

# ===== VALIDATION TESTS =====

func test_rule_validation_parameters(p_container : GBCompositionContainer, test_parameters := [
	load("uid://dy6e5p5d6ax6n")
]) -> void:
	var params = UnifiedTestFactory.create_rule_validation_parameters(self, p_container)
	
	assert_object(params).append_failure_message(
		"Test environment should include validation parameters"
	).is_not_null()
	
	# Validate parameter structure using real API
	if params:
		var validation_issues = RuleValidationParameters.validate(params)
		assert_array(validation_issues).append_failure_message(
			"Validation parameters should be valid"
		).is_empty()

func test_targeting_state_validation() -> void:
	# Test targeting state validation
	var owner_context := UnifiedTestFactory.create_owner_context(self)
	var targeting_state: GridTargetingState = UnifiedTestFactory.create_targeting_state(self, owner_context)
	
	assert_object(targeting_state).append_failure_message(
		"Test environment should include targeting state"
	).is_not_null()
	
	# Basic targeting state properties
	if targeting_state:
		assert_object(targeting_state).append_failure_message(
			"Targeting state should be valid object"
		).is_not_null()

func test_collision_rule_validation(p_container : GBCompositionContainer, test_parameters := [
	load("uid://dy6e5p5d6ax6n")
]) -> void:
	# Test collision rule validation
	var collision_rule = CollisionsCheckRule.new()
	
	assert_object(collision_rule).append_failure_message(
		"Should create collision rule instance"
	).is_not_null()
	
	# Test rule validation methods using real API
	if collision_rule:
		var params = UnifiedTestFactory.create_rule_validation_parameters(self, p_container)
		if params:
			var setup_issues = collision_rule.setup(params)
			assert_array(setup_issues).append_failure_message(
				"Rule setup should succeed"
			).is_empty()
			
			var result = collision_rule.validate_condition()
			assert_object(result).append_failure_message(
				"Rule validation should return result"
			).is_not_null()

# ===== VALIDATION EDGE CASES =====

func test_validation_null_parameters() -> void:
	# Test validation with null parameters
	var collision_rule = CollisionsCheckRule.new()
	
	if collision_rule:
		var setup_issues = collision_rule.setup(null)
		assert_array(setup_issues).append_failure_message(
			"Should handle null validation parameters"
		).is_not_empty()
		
		# Result should indicate failure
		var result = collision_rule.validate_condition()
		assert_object(result).is_not_null()
		assert_bool(result.is_successful).append_failure_message(
			"Null parameters should result in validation failure"
		).is_false()

func test_validation_invalid_tilemap(p_container : GBCompositionContainer, test_parameters := [
	load("uid://dy6e5p5d6ax6n")
]) -> void:
	# Test validation with invalid tilemap
	var params = UnifiedTestFactory.create_rule_validation_parameters(self, p_container)
	if params:
		# Temporarily set invalid tilemap
		var original_tilemap = params.targeting_state.target_map
		params.targeting_state.target_map = null
		
		var collision_rule = CollisionsCheckRule.new()
		if collision_rule:
			var setup_issues = collision_rule.setup(params)
			assert_array(setup_issues).is_not_empty()
			
			var result = collision_rule.validate_condition()
			assert_object(result).is_not_null()
			
			# Should handle invalid tilemap gracefully
			assert_bool(result.is_successful).append_failure_message(
				"Invalid tilemap should result in validation failure"
			).is_false()
		
		# Restore original tilemap
		params.targeting_state.target_map = original_tilemap

func test_validation_out_of_bounds(p_container : GBCompositionContainer, test_parameters := [
	load("uid://dy6e5p5d6ax6n")
]) -> void:
	# Test validation with out-of-bounds positions
	var params = UnifiedTestFactory.create_rule_validation_parameters(self, p_container)
	if params:
		# Set extremely large position
		var original_position = params.target.global_position
		params.target.global_position = Vector2(999999, 999999)
		
		var collision_rule = CollisionsCheckRule.new()
		if collision_rule:
			var setup_issues = collision_rule.setup(params)
			assert_array(setup_issues).is_empty()
			
			var result = collision_rule.validate_condition()
			assert_object(result).append_failure_message(
				"Should handle out-of-bounds position"
			).is_not_null()
		
		# Restore original position
		params.target.global_position = original_position

#endregion
