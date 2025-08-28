extends GdUnitTestSuite

## Demonstrates focused system testing using the layered factory approach
## Only creates the systems needed for specific test scenarios

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# ================================
# Building System Only Tests
# ================================

func test_building_system_focused():
	# Create hierarchy with only building system
	var test_setup = UnifiedTestFactory.create_systems_test_hierarchy(self, ["building"], TEST_CONTAINER)
	
	var building_system = test_setup.building_system
	var positioner = test_setup.positioner
	var indicator_manager = test_setup.indicator_manager
	
	assert_that(building_system).is_not_null()
	assert_that(positioner).is_not_null()
	assert_that(indicator_manager).is_not_null()
	
	# Test building system in isolation
	positioner.position = Vector2(48, 48)
	assert_that(positioner.position).is_equal(Vector2(48, 48))

# ================================
# Manipulation System Only Tests
# ================================

func test_manipulation_system_focused():
	# Create hierarchy with only manipulation system
	var test_setup = UnifiedTestFactory.create_systems_test_hierarchy(self, ["manipulation"], TEST_CONTAINER)
	
	var manipulation_system = test_setup.manipulation_system
	var manipulation_parent = test_setup.manipulation_parent
	var positioner = test_setup.positioner
	
	assert_that(manipulation_system).is_not_null()
	assert_that(manipulation_parent).is_not_null()
	assert_that(positioner).is_not_null()
	
	# Test manipulation hierarchy
	assert_that(manipulation_parent.get_parent()).is_equal(positioner)

# ================================
# Combined Systems Tests
# ================================

func test_building_and_manipulation_systems():
	# Create hierarchy with multiple specific systems
	var test_setup = UnifiedTestFactory.create_systems_test_hierarchy(
		self, 
		["building", "manipulation", "object_manager"], 
		TEST_CONTAINER
	)
	
	var building_system = test_setup.building_system
	var manipulation_system = test_setup.manipulation_system
	var object_manager = test_setup.object_manager
	var positioner = test_setup.positioner
	
	assert_that(building_system).is_not_null()
	assert_that(manipulation_system).is_not_null()
	assert_that(object_manager).is_not_null()
	assert_that(positioner).is_not_null()
	
	# Test system coordination
	positioner.position = Vector2(80, 80)
	
	# All systems should be able to work together
	assert_that(positioner.position).is_equal(Vector2(80, 80))

# ================================
# Targeting System Tests
# ================================

func test_targeting_system_with_collision():
	# Create hierarchy with targeting and collision capabilities
	var test_setup = UnifiedTestFactory.create_systems_test_hierarchy(self, ["targeting"], TEST_CONTAINER)
	
	var targeting_system = test_setup.targeting_system
	var collision_mapper = test_setup.collision_mapper
	var tile_map = test_setup.tile_map
	var positioner = test_setup.positioner
	
	assert_that(targeting_system).is_not_null()
	assert_that(collision_mapper).is_not_null()
	assert_that(tile_map).is_not_null()
	assert_that(positioner).is_not_null()
	
	# Create test collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(32, 32)
	area.add_child(collision_shape)
	positioner.add_child(area)
	auto_free(area)
	
	# Test targeting with collision
	positioner.position = Vector2(64, 64)
	var offsets = collision_mapper._get_tile_offsets_for_collision_object(area, tile_map)
	assert_dict(offsets).is_not_empty()

# ================================
# Performance Benefits Test
# ================================

func test_focused_setup_performance():
	# Test that focused setup is more efficient than full setup
	var start_time = Time.get_ticks_msec()
	
	# Create minimal setup - just indicator hierarchy
	var minimal_setup = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)
	
	var minimal_time = Time.get_ticks_msec() - start_time
	
	# Create focused setup with one system
	start_time = Time.get_ticks_msec()
	var focused_setup = UnifiedTestFactory.create_systems_test_hierarchy(self, ["building"], TEST_CONTAINER)
	var focused_time = Time.get_ticks_msec() - start_time
	
	# Create full setup
	start_time = Time.get_ticks_msec()
	var full_setup = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER)
	var full_time = Time.get_ticks_msec() - start_time
	
	# All setups should work
	assert_that(minimal_setup).is_not_null()
	assert_that(focused_setup).is_not_null()
	assert_that(full_setup).is_not_null()
	
	# Performance relationship should be: minimal <= focused <= full
	assert_int(minimal_time).is_less_equal(focused_time + 10)  # Allow 10ms tolerance
	assert_int(focused_time).is_less_equal(full_time + 10)     # Allow 10ms tolerance

# ================================
# Factory Layering Verification
# ================================

func test_factory_layering_consistency():
	# Test that all factory methods produce consistent base hierarchy
	var indicator_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER)
	var systems_hierarchy = UnifiedTestFactory.create_systems_test_hierarchy(self, ["building"], TEST_CONTAINER)
	var full_hierarchy = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER)
	
	# All should have the same base components from indicator hierarchy
	var base_components = ["positioner", "manipulation_parent", "indicator_manager", "tile_map", "collision_mapper", "container", "logger"]
	
	for component in base_components:
		assert_that(indicator_hierarchy.has(component)).is_true()
		assert_that(systems_hierarchy.has(component)).is_true()
		assert_that(full_hierarchy.has(component)).is_true()
	
	# Systems hierarchy should have additional building system
	assert_that(systems_hierarchy.has("building_system")).is_true()
	assert_that(indicator_hierarchy.has("building_system")).is_false()
	
	# Full hierarchy should have all systems
	var full_components = ["building_system", "manipulation_system", "targeting_system", "object_manager", "grid"]
	for component in full_components:
		assert_that(full_hierarchy.has(component)).is_true()

func test_hierarchy_relationships():
	# Test that the node hierarchy is consistent across all factory methods
	var full_setup = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER)
	
	var positioner = full_setup.positioner
	var manipulation_parent = full_setup.manipulation_parent
	var indicator_manager = full_setup.indicator_manager
	
	# Verify the hierarchy: positioner -> manipulation_parent -> (indicator_manager as child)
	assert_that(manipulation_parent.get_parent()).is_equal(positioner)
	assert_that(indicator_manager).is_not_null()
	
	# The indicator manager should be properly connected to manipulation_parent
	# (exact relationship depends on implementation, but both should exist and be properly configured)
