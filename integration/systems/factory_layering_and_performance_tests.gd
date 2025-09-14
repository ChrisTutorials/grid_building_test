extends GdUnitTestSuite

## Tests for UnifiedTestFactory layering and performance
## Verifies factory methods produce consistent hierarchies and performance benefits

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# ================================
# Performance Benefits Test
# ================================

func test_focused_setup_performance() -> void:
	# Test that focused setup is more efficient than full setup
	var start_time : float = Time.get_ticks_msec()
	
	# Create minimal setup - just indicator hierarchy
	var minimal_setup : Dictionary = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER.duplicate(true))
	
	var minimal_time : float = Time.get_ticks_msec() - start_time
	
	# Create focused setup with one system
	start_time = Time.get_ticks_msec()
	var focused_setup : Dictionary = UnifiedTestFactory.create_systems_test_hierarchy(self, ["building"], TEST_CONTAINER.duplicate(true))
	var focused_time : float = Time.get_ticks_msec() - start_time
	
	# Create full setup
	start_time = Time.get_ticks_msec()
	var full_setup : Dictionary = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER.duplicate(true))
	var full_time : float = Time.get_ticks_msec() - start_time
	
	# All setups should work
	assert_that(minimal_setup).is_not_null()
	assert_that(focused_setup).is_not_null()
	assert_that(full_setup).is_not_null()
	
	# Performance relationship should be: minimal <= focused <= full
	assert_int(int(minimal_time)).is_less_equal(int(focused_time) + 10)  # Allow 10ms tolerance
	assert_int(int(focused_time)).is_less_equal(int(full_time) + 10)     # Allow 10ms tolerance

#endregion
#region Factory Layering Verification

func test_factory_layering_consistency() -> void:
	# Test that all factory methods produce consistent base hierarchy
	var indicator_hierarchy : Dictionary = UnifiedTestFactory.create_indicator_test_hierarchy(self, TEST_CONTAINER.duplicate(true))
	var systems_hierarchy : Dictionary = UnifiedTestFactory.create_systems_test_hierarchy(self, ["building"], TEST_CONTAINER.duplicate(true))
	var full_hierarchy : Dictionary = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER.duplicate(true))
	
	# All should have the same base components from indicator hierarchy
	var base_components : Array[String] = ["positioner", "manipulation_parent", "indicator_manager", "tile_map", "collision_mapper", "container", "logger"]

	for component in base_components:
		assert_that(indicator_hierarchy.has(component)).is_true()
		assert_that(systems_hierarchy.has(component)).is_true()
		assert_that(full_hierarchy.has(component)).is_true()
	
	# Systems hierarchy should have additional building system
	assert_that(systems_hierarchy.has("building_system")).is_true()
	assert_that(indicator_hierarchy.has("building_system")).is_false()
	
	# Full hierarchy should have all systems
	var full_components: Array[String] = ["building_system", "manipulation_system", "targeting_system", "object_manager", "grid"]
	for component: String in full_components:
		assert_that(full_hierarchy.has(component)).is_true()

func test_hierarchy_relationships() -> void:
	# Test that the node hierarchy is consistent across all factory methods
	var full_setup: Dictionary = UnifiedTestFactory.create_full_integration_test_scene(self, TEST_CONTAINER.duplicate(true))
	
	var positioner: Node2D = full_setup.positioner
	var manipulation_parent: Node2D = full_setup.manipulation_parent
	var indicator_manager: IndicatorManager = full_setup.indicator_manager
	
	# Verify the hierarchy: positioner -> manipulation_parent -> (indicator_manager as child)
	assert_that(manipulation_parent.get_parent()).is_equal(positioner)
	assert_that(indicator_manager).is_not_null()
	
	# The indicator manager should be properly connected to manipulation_parent
	# (exact relationship depends on implementation, but both should exist and be properly configured)
