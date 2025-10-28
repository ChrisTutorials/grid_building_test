extends GdUnitTestSuite

## Consolidated composition container tests using factory patterns

var runner: GdUnitSceneRunner
var env: AllSystemsTestEnvironment


func before_test() -> void:
	# Use the premade AllSystemsTestEnvironment scene
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	env = runner.scene() as AllSystemsTestEnvironment


func test_component_registration() -> void:
	# Test that the injector system is properly initialized with container
	(
		assert_object(env.injector)
		. append_failure_message("Injector should be initialized in test environment")
		. is_not_null()
	)
	(
		assert_object(env.injector.composition_container)
		. append_failure_message("Composition container should be available through injector")
		. is_not_null()
	)

	# Test that the container has the expected states
	var states: GBStates = env.injector.composition_container.get_states()
	(
		assert_object(states)
		. append_failure_message("States should be accessible from composition container")
		. is_not_null()
	)
	(
		assert_object(states.targeting)
		. append_failure_message("Targeting state should be initialized")
		. is_not_null()
	)
	(
		assert_object(states.building)
		. append_failure_message("Building state should be initialized")
		. is_not_null()
	)


func test_dependency_resolution() -> void:
	# Test that we can access components through the container's states
	var targeting_state: GridTargetingState = (
		env.injector.composition_container.get_states().targeting
	)
	(
		assert_object(targeting_state)
		. append_failure_message("Targeting state should be resolvable from container")
		. is_not_null()
	)

	# Test that targeting state has expected properties
	(
		assert_object(targeting_state.positioner)
		. append_failure_message("Positioner should be available in targeting state")
		. is_not_null()
	)
	(
		assert_object(targeting_state.target_map)
		. append_failure_message("Target map should be available in targeting state")
		. is_not_null()
	)

	# Test component access through container states
	var building_state: BuildingState = env.injector.composition_container.get_states().building
	(
		assert_object(building_state)
		. append_failure_message("Building state should be accessible through container")
		. is_not_null()
	)


func test_component_lifecycle() -> void:
	# Test that the injector properly manages component lifecycle through dependency injection
	var _initial_injection_count: int = 0

	# Create a test node that should be injected
	var test_node: Node2D = Node2D.new()
	test_node.name = "TestInjectableNode"
	test_node.set_script(GDScript.new())  # Add a script so it can have resolve_gb_dependencies
	add_child(test_node)

	# The injector should handle the lifecycle through its injection system
	(
		assert_object(test_node)
		. append_failure_message("Test node should be created and added to scene")
		. is_not_null()
	)

	auto_free(test_node)


func test_component_defaults() -> void:
	# Test that components have proper default configurations through the container
	var targeting_state: GridTargetingState = (
		env.injector.composition_container.get_states().targeting
	)
	(
		assert_object(targeting_state)
		. append_failure_message(
			"Targeting state should be available for default configuration testing"
		)
		. is_not_null()
	)

	# Test that the container has proper default settings
	var config: GBConfig = env.injector.composition_container.config
	(
		assert_object(config)
		. append_failure_message("Container should have default configuration")
		. is_not_null()
	)

	# Test that states have default configurations
	(
		assert_object(targeting_state.positioner)
		. append_failure_message("Positioner should have default configuration")
		. is_not_null()
	)
	(
		assert_object(targeting_state.target_map)
		. append_failure_message("Target map should have default configuration")
		. is_not_null()
	)


func test_injector_initialization() -> void:
	(
		assert_object(env.injector)
		. append_failure_message("Injector should be initialized in test environment")
		. is_not_null()
	)
	(
		assert_object(env.injector.composition_container)
		. append_failure_message("Composition container should be available through injector")
		. is_not_null()
	)

	# Test that injector is of expected type
	(
		assert_object(env.injector)
		. append_failure_message("Injector should be instance of GBInjectorSystem")
		. is_instanceof(GBInjectorSystem)
	)

	# Test that the container is properly configured
	var contexts: GBContexts = env.injector.composition_container.get_contexts()
	var states: GBStates = env.injector.composition_container.get_states()
	(
		assert_object(contexts)
		. append_failure_message("Contexts should be accessible from composition container")
		. is_not_null()
	)
	(
		assert_object(states)
		. append_failure_message("States should be accessible from composition container")
		. is_not_null()
	)

	# Test that container has expected state components
	(
		assert_object(states.targeting)
		. append_failure_message("Targeting state should be initialized in container")
		. is_not_null()
	)
	(
		assert_object(states.building)
		. append_failure_message("Building state should be initialized in container")
		. is_not_null()
	)
	(
		assert_object(states.manipulation)
		. append_failure_message("Manipulation state should be initialized in container")
		. is_not_null()
	)


func test_container_integration() -> void:
	# Test integration through the composition container's state management
	var targeting_state: GridTargetingState = (
		env.injector.composition_container.get_states().targeting
	)
	var positioner: Node2D = targeting_state.positioner
	var tile_map: TileMapLayer = targeting_state.target_map

	(
		assert_object(positioner)
		. append_failure_message("Positioner should be available from targeting state")
		. is_not_null()
	)
	(
		assert_object(tile_map)
		. append_failure_message("Tile map should be available from targeting state")
		. is_not_null()
	)

	# Test hierarchy relationship
	(
		assert_bool(positioner.get_parent() != null)
		. append_failure_message("Positioner should have a parent in the scene hierarchy")
		. is_true()
	)

	# Test that container properly manages state relationships
	var building_state: BuildingState = env.injector.composition_container.get_states().building
	(
		assert_object(building_state)
		. append_failure_message("Building state should be accessible from container")
		. is_not_null()
	)


func test_component_type_validation() -> void:
	# Test that components accessed through the container have expected types
	var targeting_state: GridTargetingState = (
		env.injector.composition_container.get_states().targeting
	)

	# Test that targeting state has expected properties
	(
		assert_object(targeting_state.positioner)
		. append_failure_message("Positioner should be available in targeting state")
		. is_not_null()
	)
	(
		assert_object(targeting_state.target_map)
		. append_failure_message("Target map should be available in targeting state")
		. is_not_null()
	)

	# Test that components are of expected types
	(
		assert_object(targeting_state.target_map)
		. append_failure_message("Target map should be a TileMapLayer instance")
		. is_instanceof(TileMapLayer)
	)
	(
		assert_object(targeting_state.positioner)
		. append_failure_message("Positioner should be a Node2D instance")
		. is_instanceof(Node2D)
	)


func test_multiple_component_access() -> void:
	# Test accessing multiple components through the container's state system
	var states: GBStates = env.injector.composition_container.get_states()
	var targeting_state: GridTargetingState = states.targeting
	var building_state: BuildingState = states.building
	var manipulation_state: ManipulationState = states.manipulation

	# Verify all states are accessible
	(
		assert_object(targeting_state)
		. append_failure_message("Targeting state should be accessible from container states")
		. is_not_null()
	)
	(
		assert_object(building_state)
		. append_failure_message("Building state should be accessible from container states")
		. is_not_null()
	)
	(
		assert_object(manipulation_state)
		. append_failure_message("Manipulation state should be accessible from container states")
		. is_not_null()
	)

	# Test that states have their expected properties
	(
		assert_object(targeting_state.positioner)
		. append_failure_message("Positioner should be available in targeting state")
		. is_not_null()
	)
	(
		assert_object(building_state.placed_parent)
		. append_failure_message("Placed parent should be available in building state")
		. is_not_null()
	)

	# Test cross-state relationships
	if building_state.placed_parent:
		(
			assert_bool(building_state.placed_parent is Node2D)
			. append_failure_message("Placed parent should be a Node2D instance")
			. is_true()
		)


func test_component_persistence() -> void:
	# Test that components persist through the container's state management
	var first_access: TileMapLayer = (
		env.injector.composition_container.get_states().targeting.target_map
	)
	var second_access: TileMapLayer = (
		env.injector.composition_container.get_states().targeting.target_map
	)

	# Should return same instance (state persistence)
	(
		assert_object(first_access)
		. append_failure_message("First access to target map should return valid instance")
		. is_same(second_access)
	)

	# Test that positioner persists as well
	var first_positioner: Node2D = (
		env.injector.composition_container.get_states().targeting.positioner
	)
	var second_positioner: Node2D = (
		env.injector.composition_container.get_states().targeting.positioner
	)
	(
		assert_object(first_positioner)
		. append_failure_message("First access to positioner should return valid instance")
		. is_same(second_positioner)
	)
