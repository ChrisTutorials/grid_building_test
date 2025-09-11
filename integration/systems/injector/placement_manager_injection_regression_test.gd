# Test dependency injection timing issues where IndicatorManager may not be
# properly injected or registered when BuildingSystem initializes.
extends GdUnitTestSuite

# Test environment with proper dependency setup
var test_env: BuildingTestEnvironment

# Preload the environment scene
const BUILDING_TEST_ENV_SCENE = preload("uid://c4ujk08n8llv8")

func before_test() -> void:
	# Create fresh test environment for each test
	test_env = BUILDING_TEST_ENV_SCENE.instantiate()
	add_child(test_env)
	
	# Let environment initialize
	await await_idle_frame()

func after_test() -> void:
	if test_env:
		test_env.queue_free()
		test_env = null

func test_indicator_manager_gets_dependency_injection() -> void:
	# Test environment should have IndicatorManager properly injected
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	assert_object(indicator_manager).append_failure_message(
		"BuildingTestEnvironment should have IndicatorManager"
	).is_not_null()
	
	# Check if injection metadata exists
	assert_bool(indicator_manager.has_meta("gb_injection_meta")).append_failure_message(
		"IndicatorManager should have injection metadata after environment setup"
	).is_true()

func test_indicator_manager_registers_with_indicator_context() -> void:
	# Test environment should have properly registered IndicatorManager
	var indicator_context : IndicatorContext = test_env.get_container().get_indicator_context()
	var registered_manager : IndicatorManager= indicator_context.get_manager()
	
	assert_object(registered_manager).append_failure_message(
		"IndicatorManager should be registered with IndicatorContext after injection"
	).is_not_null()

	var indicator_manager: IndicatorManager = test_env.indicator_manager
	assert_object(registered_manager).append_failure_message(
		"Specific IndicatorManager instance should be found in IndicatorContext"
	).is_same(indicator_manager)

func test_building_system_has_indicator_context_after_injection() -> void:
	# Check BuildingSystem has access to indicator context
	var building_system: BuildingSystem = test_env.building_system
	assert_object(building_system).append_failure_message(
		"BuildingTestEnvironment should have BuildingSystem"
	).is_not_null()
	
	# Get indicator context through the container
	var indicator_context: IndicatorContext = test_env.get_container().get_indicator_context()
	assert_object(indicator_context).append_failure_message(
		"Container should provide indicator context after test environment setup"
	).is_not_null()
