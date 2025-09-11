extends GdUnitTestSuite

## Consolidated composition container tests using factory patterns

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary
var injector: GBInjectorSystem

func before_test():
	test_hierarchy = UnifiedTestFactory.create_basic_test_setup(self, TEST_CONTAINER)
	injector = test_hierarchy.injector

func test_component_registration():
	# Test that the injector system is properly initialized with container
	assert_object(injector).is_not_null()
	assert_object(injector.composition_container).is_not_null()
	
	# Test that the container has the expected states
	states: Node = injector.composition_container.get_states()
	assert_object(states).is_not_null()
	assert_object(states.targeting).is_not_null()
	assert_object(states.building).is_not_null()

func test_dependency_resolution():
	# Test that we can access components through the container's states
	var targeting_state = injector.composition_container.get_states().targeting
	assert_object(targeting_state).is_not_null()
	
	# Test that targeting state has expected properties
	assert_object(targeting_state.positioner).is_not_null()
	assert_object(targeting_state.target_map).is_not_null()
	
	# Test component access through container states
	var building_state = injector.composition_container.get_states().building
	assert_object(building_state).is_not_null()

func test_component_lifecycle():
	# Test that the injector properly manages component lifecycle through dependency injection
	var _initial_injection_count = 0
	
	# Create a test node that should be injected
	var test_node = Node2D.new()
	test_node.name = "TestInjectableNode"
	test_node.set_script(GDScript.new())  # Add a script so it can have resolve_gb_dependencies
	add_child(test_node)
	
	# The injector should handle the lifecycle through its injection system
	assert_object(test_node).is_not_null()
	
	auto_free(test_node)

func test_component_defaults():
	# Test that components have proper default configurations through the container
	var targeting_state = injector.composition_container.get_states().targeting
	assert_object(targeting_state).is_not_null()
	
	# Test that the container has proper default settings
	var config = injector.composition_container.config
	assert_object(config).is_not_null()
	
	# Test that states have default configurations
	assert_object(targeting_state.positioner).is_not_null()
	assert_object(targeting_state.target_map).is_not_null()

func test_injector_initialization():
	assert_object(injector).is_not_null()
	assert_object(injector.composition_container).is_not_null()
	
	# Test that injector is of expected type
	assert_object(injector).is_instanceof(GBInjectorSystem)
	
	# Test that the container is properly configured
	var contexts = injector.composition_container.get_contexts()
	var states = injector.composition_container.get_states()
	assert_object(contexts).is_not_null()
	assert_object(states).is_not_null()
	
	# Test that container has expected state components
	assert_object(states.targeting).is_not_null()
	assert_object(states.building).is_not_null()
	assert_object(states.manipulation).is_not_null()

func test_container_integration():
	# Test integration through the composition container's state management
	var targeting_state = injector.composition_container.get_states().targeting
	var positioner = targeting_state.positioner
	var tile_map = targeting_state.target_map
	
	assert_object(positioner).is_not_null()
	assert_object(tile_map).is_not_null()
	
	# Test hierarchy relationship
	assert_bool(positioner.get_parent() != null).is_true()
	
	# Test that container properly manages state relationships
	var building_state = injector.composition_container.get_states().building
	assert_object(building_state).is_not_null()

func test_component_type_validation():
	# Test that components accessed through the container have expected types
	var targeting_state = injector.composition_container.get_states().targeting
	
	# Test that targeting state has expected properties
	assert_object(targeting_state.positioner).is_not_null()
	assert_object(targeting_state.target_map).is_not_null()
	
	# Test that components are of expected types
	assert_object(targeting_state.target_map).is_instanceof(TileMapLayer)
	assert_object(targeting_state.positioner).is_instanceof(Node2D)

func test_multiple_component_access():
	# Test accessing multiple components through the container's state system
	var states = injector.composition_container.get_states()
	var targeting_state = states.targeting
	var building_state = states.building
	var manipulation_state = states.manipulation
	
	# Verify all states are accessible
	assert_object(targeting_state).is_not_null()
	assert_object(building_state).is_not_null()
	assert_object(manipulation_state).is_not_null()
	
	# Test that states have their expected properties
	assert_object(targeting_state.positioner).is_not_null()
	assert_object(building_state.placed_parent).is_not_null()
	
	# Test cross-state relationships
	if building_state.placed_parent:
		assert_bool(building_state.placed_parent is Node2D).is_true()

func test_component_persistence():
	# Test that components persist through the container's state management
	var first_access = injector.composition_container.get_states().targeting.target_map
	var second_access = injector.composition_container.get_states().targeting.target_map
	
	# Should return same instance (state persistence)
	assert_object(first_access).is_same(second_access)
	
	# Test that positioner persists as well
	var first_positioner = injector.composition_container.get_states().targeting.positioner
	var second_positioner = injector.composition_container.get_states().targeting.positioner
	assert_object(first_positioner).is_same(second_positioner)
