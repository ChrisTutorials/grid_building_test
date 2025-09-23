extends GdUnitTestSuite

## Integration tests using the premade AllSystemsTestEnvironment
## Tests system interactions and functionality with the complete environment

const ALL_SYSTEMS_ENV_UID: String = "uid://ioucajhfxc8b"

var test_env: AllSystemsTestEnvironment

func before_test() -> void:
	test_env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)

#region Building System Only Tests

func test_building_system_focused() -> void:
	assert_that(test_env.building_system).is_not_null()
	assert_that(test_env.positioner).is_not_null()
	assert_that(test_env.indicator_manager).is_not_null()
	
	# Test building system in isolation
	test_env.positioner.position = Vector2(48, 48)
	assert_that(test_env.positioner.position).is_equal(Vector2(48, 48))

#endregion 
#region Manipulation System Only Tests

func test_manipulation_system_focused() -> void:
	assert_that(test_env.manipulation_system).is_not_null()
	assert_that(test_env.manipulation_parent).is_not_null()
	assert_that(test_env.positioner).is_not_null()
	
	# Test manipulation hierarchy
	assert_that(test_env.manipulation_parent.get_parent()).is_equal(test_env.positioner)

#endregion
#region Combined Systems Tests

func test_building_and_manipulation_systems() -> void:
	assert_that(test_env.building_system).is_not_null()
	assert_that(test_env.manipulation_system).is_not_null()
	assert_that(test_env.objects_parent).is_not_null()
	assert_that(test_env.positioner).is_not_null()
	
	# Test system coordination
	test_env.positioner.position = Vector2(80, 80)
	assert_that(test_env.positioner.position).is_equal(Vector2(80, 80))

#endregion
#region Targeting System Tests

func test_targeting_system_with_collision() -> void:
	assert_that(test_env.grid_targeting_system).is_not_null()
	assert_that(test_env.get_collision_mapper()).is_not_null()
	assert_that(test_env.tile_map_layer).is_not_null()
	assert_that(test_env.positioner).is_not_null()
	
	# Create test collision object
	var area := Area2D.new()
	area.name = "TestArea2D"
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "TestRectangleCollisionShape2D_32x32"
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(32, 32)
	area.add_child(collision_shape)
	test_env.positioner.add_child(area)
	auto_free(area)
	
	# Test targeting with collision
	test_env.positioner.position = Vector2(32, 32)
	var indicator_test_setup : CollisionTestSetup2D = CollisionTestSetup2D.new(area, Vector2(32,32))
	var offsets: Dictionary = test_env.get_collision_mapper().get_tile_offsets_for_test_collisions(indicator_test_setup)
	assert_dict(offsets).is_not_empty()

func test_locations_close_to_zero_are_within_tile_map_bounds() -> void:
	# Create a map bounds rule to test tilemap boundary validation
	var map_bounds_rule := WithinTilemapBoundsRule.new()
	map_bounds_rule.apply_to_objects_mask = 1
	
	# Set up the rule with the grid targeting system
	var setup_issues := map_bounds_rule.setup(test_env.grid_targeting_system.get_state())
	assert_array(setup_issues).is_empty()
	
	# Create an indicator from test constants
	var indicator_scene := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var indicator_instance: RuleCheckIndicator = indicator_scene.instantiate()
	test_env.positioner.add_child(indicator_instance)
	auto_free(indicator_instance)
	
	# Assign the rule to the indicator
	indicator_instance.add_rule(map_bounds_rule)
	
	# Verify only one rule is assigned to prevent duplicate evaluations
	var assigned_rules := indicator_instance.get_rules()
	assert_int(assigned_rules.size()).is_equal(1) \
		.append_failure_message("Expected exactly 1 rule, but found %d rules" % assigned_rules.size())
	
	# Test positions in 16 pixel increments from -3 tiles to +3 tiles on both X and Y
	# This covers 7x7 = 49 positions total, ensuring comprehensive boundary testing
	var tile_size := GBTestConstants.DEFAULT_TILE_SIZE.x  # 16 pixels
	var test_range := 3  # tiles
	
	for x_offset in range(-test_range, test_range + 1):
		for y_offset in range(-test_range, test_range + 1):
			var test_position := Vector2(x_offset * tile_size, y_offset * tile_size)
			
			# Position the indicator at the test location
			indicator_instance.global_position = test_position
			
			# Validate that this position is within tilemap bounds
			var validation_result := map_bounds_rule.validate_placement()
			
			# Debug: Check if there are duplicate error messages
			if not validation_result.is_successful():
				var error_messages: Array[String] = validation_result.get_issues()
				var unique_messages := {}
				for msg: String in error_messages:
					unique_messages[msg] = unique_messages.get(msg, 0) + 1
				
				# Assert no duplicate error messages
				for msg: String in unique_messages:
					var count: int = unique_messages[msg]
					assert_int(count).is_equal(1) \
						.append_failure_message("Duplicate error message '%s' appeared %d times at position %s" % [msg, count, test_position])
			
			# All positions within the test range should be valid
			assert_bool(validation_result.is_successful()).is_true() \
				.append_failure_message("Position %s should be within tilemap bounds. Issues: %s" % [test_position, str(validation_result.get_issues())])
	
	# Clean up the rule
	map_bounds_rule.tear_down()

func test_simple_tilemap_bounds_rule_creation() -> void:
	# Test 1: Simple rule creation
	var rule := WithinTilemapBoundsRule.new()
	assert_that(rule).is_not_null()
	assert_str(rule.failed_message).is_equal("Tried placing outside of valid map area")

func test_simple_indicator_creation() -> void:
	# Test 2: Simple indicator creation from constants
	var indicator_scene := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var indicator := indicator_scene.instantiate()
	test_env.positioner.add_child(indicator)
	auto_free(indicator)
	
	assert_that(indicator).is_not_null()
	assert_that(indicator).is_instanceof(RuleCheckIndicator)

func test_rule_setup_with_grid_targeting_state() -> void:
	# Test 3: Rule setup process
	var rule := WithinTilemapBoundsRule.new()
	var grid_state := test_env.grid_targeting_system.get_state()
	
	assert_that(grid_state).is_not_null()
	assert_that(grid_state.target_map).is_not_null()
	
	var setup_issues := rule.setup(grid_state)
	assert_array(setup_issues).is_empty()
	
	rule.tear_down()

func test_indicator_rule_assignment() -> void:
	# Test 4: Rule assignment to indicator
	var rule := WithinTilemapBoundsRule.new()
	var setup_issues := rule.setup(test_env.grid_targeting_system.get_state())
	assert_array(setup_issues).is_empty()
	
	var indicator_scene := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var indicator := indicator_scene.instantiate()
	test_env.positioner.add_child(indicator)
	auto_free(indicator)
	
	# Before assignment
	var initial_rules: Array = indicator.get_rules()
	assert_array(initial_rules).is_empty()
	
	# After assignment
	indicator.add_rule(rule)
	var assigned_rules: Array = indicator.get_rules()
	assert_int(assigned_rules.size()).is_equal(1)
	assert_that(assigned_rules[0]).is_same(rule)
	
	rule.tear_down()

func test_single_position_validation() -> void:
	# Test 5: Single position validation (origin)
	var rule := WithinTilemapBoundsRule.new()
	var setup_issues := rule.setup(test_env.grid_targeting_system.get_state())
	assert_array(setup_issues).is_empty()
	
	var indicator_scene := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var indicator := indicator_scene.instantiate()
	test_env.positioner.add_child(indicator)
	auto_free(indicator)
	
	indicator.add_rule(rule)
	indicator.global_position = Vector2.ZERO
	
	var validation_result := rule.validate_placement()
	
	# Debug the validation result
	if not validation_result.is_successful():
		var issues: Array = validation_result.get_issues()
		print("Validation failed at origin. Issues: ", issues)
		print("Issue count: ", issues.size())
		
		# Check for duplicate issues
		var issue_counts := {}
		for issue: String in issues:
			issue_counts[issue] = issue_counts.get(issue, 0) + 1
			
		for issue: String in issue_counts:
			var count: int = issue_counts[issue]
			if count > 1:
				assert_int(count).is_equal(1) \
					.append_failure_message("Duplicate issue '%s' appeared %d times" % [issue, count])
	
	# This should pass since origin is within a reasonable tilemap
	assert_bool(validation_result.is_successful()).is_true() \
		.append_failure_message("Origin position should be valid. Issues: %s" % str(validation_result.get_issues()))
	
	rule.tear_down()
