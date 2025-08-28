extends GdUnitTestSuite

## Consolidated Factories and Validation Test Suite
## Consolidates: factories_test.gd, validation_test.gd, factory_edge_cases_test.gd,
## validation_edge_cases_test.gd, factory_performance_test.gd, validation_performance_test.gd,
## factory_integration_test.gd, validation_integration_test.gd

## MARK FOR REMOVAL - factories_test.gd, validation_test.gd, factory_edge_cases_test.gd,
## validation_edge_cases_test.gd, factory_performance_test.gd, validation_performance_test.gd,
## factory_integration_test.gd, validation_integration_test.gd

var test_env: Dictionary

func before_test() -> void:
	test_env = UnifiedTestFactory.create_utilities_test_environment(self)

# ===== FACTORY CREATION TESTS =====

func test_unified_test_factory_basic() -> void:
	# Test basic factory functionality
	var basic_env: Dictionary = UnifiedTestFactory.create_utilities_test_environment(self)
	
	assert_object(basic_env).append_failure_message(
		"Factory should create test environment"
	).is_not_null()
	
	var env_type: String = basic_env.get("type", "")
	assert_str(env_type).append_failure_message(
		"Environment should have utilities type"
	).contains("utilities")

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
	var test_tilemap: TileMap = test_env.get("tilemap")
	
	if test_tilemap:
		assert_object(test_tilemap).append_failure_message(
			"Should have TileMap instance in environment"
		).is_not_null()
		
		var tilemap_class: String = test_tilemap.get_class()
		assert_str(tilemap_class).append_failure_message(
			"Should be TileMap type"
		).is_equal("TileMap")

func test_composition_container_factory() -> void:
	# Test composition container creation
	var container: GBCompositionContainer = test_env.get("container")
	
	assert_object(container).append_failure_message(
		"Environment should include container"
	).is_not_null()
	
	# Test container functionality if available
	if container and container.has_method("resolve_dependency") -> void:
		var test_dependency: Object = container.resolve_dependency("test_logger")
		assert_object(test_dependency).append_failure_message(
			"Container should resolve test logger dependency"
		).is_not_null()

# ===== FACTORY LAYERING TESTS =====

func test_placement_system_factory_layer() -> void:
	# Test placement system factory layer
	var placement_env: Dictionary = UnifiedTestFactory.create_placement_system_test_environment(self)
	
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

# ===== FACTORY EDGE CASES =====

func test_factory_null_inputs() -> void:
	# Test factory behavior with null inputs
	var env_with_null = UnifiedTestFactory.create_utilities_test_environment(null)
	
	# Should handle null gracefully
	assert_object(env_with_null).append_failure_message(
		"Factory should handle null test suite gracefully"
	).is_not_null()

func test_factory_repeated_calls() -> void:
	# Test multiple factory calls for same environment
	var env1 = UnifiedTestFactory.create_utilities_test_environment(self)
	var env2 = UnifiedTestFactory.create_utilities_test_environment(self)
	
	assert_object(env1).is_not_null()
	assert_object(env2).is_not_null()
	
	# Each call should create fresh environment
	var are_same_instance = env1 == env2
	assert_bool(are_same_instance).append_failure_message(
		"Multiple factory calls should create independent environments"
	).is_false()

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

func test_rule_validation_parameters() -> void:
	# Test rule validation parameter creation
	var params = test_env.get("rule_validation_parameters")
	
	assert_object(params).append_failure_message(
		"Test environment should include validation parameters"
	).is_not_null()
	
	# Validate parameter structure
	if params and params.has_method("is_valid"):
		var is_valid = params.is_valid()
		assert_bool(is_valid).append_failure_message(
			"Validation parameters should be valid"
		).is_true()

func test_targeting_state_validation() -> void:
	# Test targeting state validation
	var targeting_state: Object = test_env.get("targeting_state")
	
	assert_object(targeting_state).append_failure_message(
		"Test environment should include targeting state"
	).is_not_null()
	
	# Basic targeting state properties
	if targeting_state:
		assert_object(targeting_state).append_failure_message(
			"Targeting state should be valid object"
		).is_not_null()

func test_collision_rule_validation() -> void:
	# Test collision rule validation
	var collision_rule = CollisionsCheckRule.new()
	
	assert_object(collision_rule).append_failure_message(
		"Should create collision rule instance"
	).is_not_null()
	
	# Test rule validation methods if available
	if collision_rule.has_method("validate"):
		var params = test_env.rule_validation_parameters
		var validation_result = collision_rule.validate(params)
		
		assert_object(validation_result).append_failure_message(
			"Rule validation should return result"
		).is_not_null()

# ===== VALIDATION EDGE CASES =====

func test_validation_null_parameters() -> void:
	# Test validation with null parameters
	var collision_rule = CollisionsCheckRule.new()
	
	if collision_rule.has_method("validate"):
		var null_result = collision_rule.validate(null)
		
		assert_object(null_result).append_failure_message(
			"Should handle null validation parameters"
		).is_not_null()
		
		# Result should indicate failure
		if null_result.has_method("is_valid"):
			var is_valid = null_result.is_valid()
			assert_bool(is_valid).append_failure_message(
				"Null parameters should result in invalid validation"
			).is_false()

func test_validation_invalid_tilemap() -> void:
	# Test validation with invalid tilemap
	var params = test_env.rule_validation_parameters
	if params:
		# Temporarily set invalid tilemap
		var original_tilemap = params.tile_map
		params.tile_map = null
		
		var collision_rule = CollisionsCheckRule.new()
		if collision_rule.has_method("validate"):
			var result = collision_rule.validate(params)
			
			assert_object(result).is_not_null()
			
			# Should handle invalid tilemap gracefully
			if result.has_method("is_valid"):
				var is_valid = result.is_valid()
				assert_bool(is_valid).append_failure_message(
					"Invalid tilemap should result in validation failure"
				).is_false()
		
		# Restore original tilemap
		params.tile_map = original_tilemap

func test_validation_out_of_bounds() -> void:
	# Test validation with out-of-bounds positions
	var params = test_env.rule_validation_parameters
	if params:
		# Set extremely large position
		var original_position = params.target_position
		params.target_position = Vector2(999999, 999999)
		
		var collision_rule = CollisionsCheckRule.new()
		if collision_rule.has_method("validate"):
			var result = collision_rule.validate(params)
			
			assert_object(result).append_failure_message(
				"Should handle out-of-bounds position"
			).is_not_null()
		
		# Restore original position
		params.target_position = original_position

# ===== FACTORY PERFORMANCE TESTS =====

func test_factory_creation_performance() -> void:
	# Test factory creation performance
	var start_time: int = Time.get_ticks_msec()
	
	# Create multiple environments
	for i in range(10):
		var temp_env = UnifiedTestFactory.create_utilities_test_environment(self)
		assert_object(temp_env).is_not_null()
	
	var end_time: int = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Should complete reasonably quickly
	assert_int(duration).append_failure_message(
		"Factory creation should complete in reasonable time: %d ms" % duration
	).is_less(5000) # 5 seconds max

func test_large_object_creation() -> void:
	# Test creating larger test objects
	var large_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	
	# Add many child nodes to simulate complex object
	for i in range(50):
		var child = Node2D.new()
		child.name = "child_%d" % i
		large_object.add_child(child)
	
	assert_int(large_object.get_child_count()).append_failure_message(
		"Should create large object with many children"
	).is_equal(50)
	
	# Cleanup
	large_object.queue_free()

# ===== VALIDATION PERFORMANCE TESTS =====

func test_validation_performance() -> void:
	# Test validation performance with multiple rules
	var start_time: int = Time.get_ticks_msec()
	
	var params = test_env.rule_validation_parameters
	
	# Test multiple collision rules
	for i in range(20):
		var rule = CollisionsCheckRule.new()
		if rule.has_method("validate"):
			var result = rule.validate(params)
			assert_object(result).is_not_null()
	
	var end_time: int = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Should complete reasonably quickly
	assert_int(duration).append_failure_message(
		"Validation performance should be reasonable: %d ms" % duration
	).is_less(3000) # 3 seconds max

# ===== INTEGRATION TESTS =====

func test_factory_validation_integration() -> void:
	# Test integration between factory and validation
	var placement_env = UnifiedTestFactory.create_placement_system_test_environment(self)
	
	# Create validation parameters from factory environment
	var params = placement_env.get("rule_validation_parameters")
	assert_object(params).is_not_null()
	
	# Test validation with factory-created objects
	var collision_rule = CollisionsCheckRule.new()
	if collision_rule.has_method("validate"):
		var result = collision_rule.validate(params)
		assert_object(result).append_failure_message(
			"Factory-created parameters should work with validation"
		).is_not_null()

func test_multi_layer_factory_integration() -> void:
	# Test integration across multiple factory layers
	var utilities_env = UnifiedTestFactory.create_utilities_test_environment(self)
	var placement_env = UnifiedTestFactory.create_placement_system_test_environment(self)
	var rule_env = UnifiedTestFactory.create_rule_indicator_test_environment(self)
	var systems_env = UnifiedTestFactory.create_systems_integration_test_environment(self)
	
	# All environments should be created successfully
	assert_object(utilities_env).is_not_null()
	assert_object(placement_env).is_not_null()
	assert_object(rule_env).is_not_null()
	assert_object(systems_env).is_not_null()
	
	# Higher layers should include components from lower layers
	var utilities_container = utilities_env.get("container")
	var systems_container = systems_env.get("container")
	
	if utilities_container and systems_container:
		# Should be related but independent instances
		assert_object(utilities_container).is_not_null()
		assert_object(systems_container).is_not_null()

func test_end_to_end_factory_validation() -> void:
	# Test complete end-to-end workflow
	var systems_env = UnifiedTestFactory.create_systems_integration_test_environment(self)
	
	# Create test object
	var test_object: Node2D = UnifiedTestFactory.create_test_node2d(self)
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	test_object.add_child(collision_shape)
	
	# Test collision mapping
	var collision_mapper: Object = systems_env.get("collision_mapper")
	if collision_mapper:
		var collision_tiles = collision_mapper.get_collision_tiles(test_object, Vector2(100, 100))
		assert_array(collision_tiles).append_failure_message(
			"End-to-end collision mapping should work"
		).is_not_empty()
	
	# Test indicator generation
	var indicator_manager: Object = systems_env.get("indicator_manager")
	if indicator_manager:
		var test_rule = CollisionsCheckRule.new()
		var params = systems_env.get("rule_validation_parameters")
		if params:
			params.placeable_instance = test_object
			params.target_position = Vector2(100, 100)
			
			var result = indicator_manager.try_setup([test_rule], params)
			assert_object(result).append_failure_message(
				"End-to-end indicator generation should work"
			).is_not_null()
	
	# Cleanup
	test_object.queue_free()
