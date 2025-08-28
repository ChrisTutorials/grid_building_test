extends GdUnitTestSuite

## Consolidated composition container tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary
var injector: GBInjectorSystem

func before_test():
	test_hierarchy = UnifiedTestFactory.create_basic_test_setup(self, TEST_CONTAINER)
	injector = test_hierarchy.injector

func test_component_registration():
	var component_registry = injector._component_registry
	assert_dict(component_registry).is_not_empty()
	assert_bool(component_registry.has("tile_map")).is_true()
	assert_bool(component_registry.has("collision_mapper")).is_true()

func test_dependency_resolution():
	var tile_map = injector.get_component("tile_map")
	assert_object(tile_map).is_not_null()
	assert_bool(is_instance_of(tile_map, TileMap)).is_true()

func test_component_lifecycle():
	var original_count = injector._component_registry.size()
	
	var test_component = Node.new()
	injector.register_component("test_node", test_component)
	
	assert_int(injector._component_registry.size()).is_equal(original_count + 1)
	
	var retrieved = injector.get_component("test_node")
	assert_object(retrieved).is_same(test_component)
	
	auto_free(test_component)

func test_component_defaults():
	var tile_map = injector.get_component("tile_map")
	assert_object(tile_map).is_not_null()
	assert_int(tile_map.tile_set.get_source_count()).is_greater(0)

func test_injector_initialization():
	assert_object(injector).is_not_null()
	assert_dict(injector._component_registry).is_not_empty()
	assert_bool(injector.has_method("get_component")).is_true()
	assert_bool(injector.has_method("register_component")).is_true()

func test_container_integration():
	var positioner = injector.get_component("positioner")
	var tile_map = injector.get_component("tile_map")
	
	assert_object(positioner).is_not_null()
	assert_object(tile_map).is_not_null()
	
	# Test hierarchy relationship
	assert_bool(positioner.get_parent() != null).is_true()

func test_component_type_validation():
	var collision_mapper = injector.get_component("collision_mapper")
	var rule_checker = injector.get_component("rule_checker")
	
	assert_object(collision_mapper).is_not_null()
	assert_object(rule_checker).is_not_null()
	
	# Verify components have expected methods
	assert_bool(collision_mapper.has_method("get_tile_positions_for_area")).is_true()
	assert_bool(rule_checker.has_method("check_all_rules")).is_true()

func test_multiple_component_access():
	var components = ["tile_map", "positioner", "collision_mapper", "rule_checker"]
	var retrieved_components = {}
	
	for comp_name in components:
		retrieved_components[comp_name] = injector.get_component(comp_name)
		assert_object(retrieved_components[comp_name]).is_not_null()
	
	# All components should be unique instances
	var values = retrieved_components.values()
	for i in range(values.size()):
		for j in range(i + 1, values.size()):
			assert_object(values[i]).is_not_same(values[j])

func test_component_persistence():
	var first_access = injector.get_component("tile_map")
	var second_access = injector.get_component("tile_map")
	
	# Should return same instance (singleton behavior)
	assert_object(first_access).is_same(second_access)
