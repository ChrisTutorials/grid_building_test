extends GdUnitTestSuite

## Integration tests using the premade AllSystemsTestEnvironment
## Tests system interactions and functionality with the complete environment

const ALL_SYSTEMS_ENV_UID: String = "uid://ioucajhfxc8b"

var test_env: AllSystemsTestEnvironment

func before_test() -> void:
	test_env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)

# ================================
# Building System Only Tests
# ================================

func test_building_system_focused() -> void:
	assert_that(test_env.building_system).append_failure_message("Expected building system to be available").is_not_null()
	assert_that(test_env.positioner).append_failure_message("Expected positioner to be available").is_not_null()
	assert_that(test_env.indicator_manager).append_failure_message("Expected indicator manager to be available").is_not_null()
	
	# Test building system in isolation
	test_env.positioner.position = Vector2(48, 48)
	assert_that(test_env.positioner.position).append_failure_message("Expected positioner position to be set correctly").is_equal(Vector2(48, 48))

#endregion 
#region Manipulation System Only Tests

func test_manipulation_system_focused() -> void:
	assert_that(test_env.manipulation_system).append_failure_message("Expected manipulation system to be available").is_not_null()
	assert_that(test_env.manipulation_parent).append_failure_message("Expected manipulation parent to be available").is_not_null()
	assert_that(test_env.positioner).append_failure_message("Expected positioner to be available").is_not_null()
	
	# Test manipulation hierarchy
	assert_that(test_env.manipulation_parent.get_parent()).append_failure_message("Expected manipulation parent to be child of positioner").is_equal(test_env.positioner)

#endregion
#region Combined Systems Tests

func test_building_and_manipulation_systems() -> void:
	assert_that(test_env.building_system).append_failure_message("Expected building system to be available").is_not_null()
	assert_that(test_env.manipulation_system).append_failure_message("Expected manipulation system to be available").is_not_null()
	assert_that(test_env.object_manager).append_failure_message("Expected object manager to be available").is_not_null()
	assert_that(test_env.positioner).append_failure_message("Expected positioner to be available").is_not_null()
	
	# Test system coordination
	test_env.positioner.position = Vector2(80, 80)
	assert_that(test_env.positioner.position).append_failure_message("Expected positioner position to be updated correctly").is_equal(Vector2(80, 80))

#endregion
#region Targeting System Tests

func test_targeting_system_with_collision() -> void:
	assert_that(test_env.targeting_system).append_failure_message("Expected targeting system to be available").is_not_null()
	assert_that(test_env.collision_mapper).append_failure_message("Expected collision mapper to be available").is_not_null()
	assert_that(test_env.tile_map).append_failure_message("Expected tile map to be available").is_not_null()
	assert_that(test_env.positioner).append_failure_message("Expected positioner to be available").is_not_null()
	
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
	var offsets: Dictionary = test_env.collision_mapper.get_tile_offsets_for_test_collisions(indicator_test_setup)
	assert_dict(offsets).append_failure_message("Expected collision detection to find tile offsets").is_not_empty()
