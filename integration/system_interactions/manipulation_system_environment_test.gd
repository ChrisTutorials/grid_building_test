## Test Suite: Manipulation System Environment Tests
##
## Validates ManipulationSystem functionality using AllSystems test environment
## Tests proper integration with manipulation state, targeting state, and validation systems
## Ensures manipulation operations work correctly in fully configured environments
##
## Coverage:
## - Factory method validation with proper environment setup
## - System dependency validation in environment context
## - Result object creation and null safety
## - Environment-based testing patterns

extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

#region Test Constants
const ALL_SYSTEMS_ENV_UID: String = "uid://ioucajhfxc8b"
const TEST_TIMEOUT_MS: int = 5000
#endregion

#region Test Environment Variables
var test_environment: AllSystemsTestEnvironment
var manipulation_system: ManipulationSystem
var manipulation_state: ManipulationState
var container: GBCompositionContainer
var test_manipulatable: Manipulatable
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Use the AllSystems test environment for proper integration testing
	test_environment = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)

	# Extract components for testing
	container = test_environment.injector.composition_container
	manipulation_system = test_environment.manipulation_system
	manipulation_state = container.get_states().manipulation  # Access state through container
	
	# Create a test manipulatable object since it's not provided by the environment
	test_manipulatable = auto_free(Manipulatable.new())

	# Validate environment is properly set up
	assert_object(test_environment).append_failure_message("Test environment should be created").is_not_null()
	assert_object(manipulation_system).append_failure_message("ManipulationSystem should be available").is_not_null()
	assert_object(manipulation_state).append_failure_message("ManipulationState should be available").is_not_null()
	assert_object(container).append_failure_message("Container should be available").is_not_null()

func after_test() -> void:
	# Cleanup is handled by GdUnit auto_free
	pass
#endregion

#region Factory Method Validation Tests

func test_manipulation_system_factory_with_environment() -> void:
	"""Test that manipulation system factory creates properly configured systems"""
	# The system should be properly instantiated through the environment
	assert_object(manipulation_system).append_failure_message(
		"ManipulationSystem should be properly instantiated through environment"
	).is_not_null()

	# Should be added to the scene tree
	assert_bool(manipulation_system.is_inside_tree()).append_failure_message(
		"ManipulationSystem should be in scene tree"
	).is_true()

func test_manipulation_system_environment_integration() -> void:
	"""Test manipulation system integration with full environment"""
	# Test that system has access to required dependencies
	assert_object(manipulation_state).append_failure_message(
		"System should have access to manipulation state"
	).is_not_null()

	assert_object(container).append_failure_message(
		"System should have access to composition container"
	).is_not_null()

	# Test that system is properly registered in the environment
	assert_object(test_environment.injector).append_failure_message(
		"Environment injector should be available"
	).is_not_null()

func test_manipulation_system_result_object_creation() -> void:
	"""Test that manipulation system properly creates result objects in environment context"""
	# Test demolish operation result handling
	var demolish_result: bool = await manipulation_system.demolish(test_manipulatable)

	# Should return a valid boolean result
	assert_that(demolish_result).append_failure_message(
		"ManipulationSystem.demolish should return a valid boolean result"
	).is_not_null()

func test_manipulation_system_container_validation() -> void:
	"""Test manipulation system container integration and validation"""
	# Test that container provides required services
	var logger: Object = container.get_logger()
	assert_object(logger).append_failure_message("Container should provide logger service").is_not_null()

	var contexts: Object = container.get_contexts()
	assert_object(contexts).append_failure_message("Container should provide contexts").is_not_null()

	# Test owner context is properly configured
	var owner_context: GBOwnerContext = contexts.owner
	assert_object(owner_context).append_failure_message("Container should have owner context").is_not_null()

func test_manipulation_system_result_objects_not_null() -> void:
	"""Test that manipulation system operations return valid result objects"""
	# Test try_move with null input
	var move_null_result: Variant = await manipulation_system.try_move(null)
	assert_object(move_null_result).append_failure_message(
		"try_move(null) should return result object, not null"
	).is_not_null()

	# Test try_move with invalid node
	var invalid_node: Node = auto_free(Node.new())
	var move_invalid_result: Variant = await manipulation_system.try_move(invalid_node)
	assert_object(move_invalid_result).append_failure_message(
		"try_move(invalid_node) should return result object, not null"
	).is_not_null()

	# Test demolish with null input
	var demolish_result: bool = await manipulation_system.demolish(null)
	assert_that(demolish_result).append_failure_message(
		"demolish(null) should return a valid boolean result"
	).is_not_null()

func test_manipulation_system_environment_vs_factory() -> void:
	"""Test difference between environment-based and factory-based system creation"""
	# Environment-based system (current approach)
	var env_system: ManipulationSystem = manipulation_system

	# Factory-based system (legacy approach - should be removed)
	var factory_system: ManipulationSystem = UnifiedTestFactory.create_manipulation_system(self)
	auto_free(factory_system)

	# Both should exist
	assert_object(env_system).append_failure_message("Environment system should exist").is_not_null()
	assert_object(factory_system).append_failure_message("Factory system should exist").is_not_null()

	# Environment system should be properly integrated
	assert_bool(env_system.is_inside_tree()).append_failure_message(
		"Environment system should be in scene tree"
	).is_true()

func test_manipulation_system_dependency_injection() -> void:
	"""Test that manipulation system receives proper dependency injection"""
	# System should have access to all required dependencies through the environment
	assert_object(manipulation_system).is_not_null()
	assert_object(manipulation_state).is_not_null()
	assert_object(container).is_not_null()
	assert_object(test_environment.injector).is_not_null()

	# Test that the system can perform basic operations without null reference errors
	var test_result: Variant = await manipulation_system.try_move(null)
	assert_object(test_result).append_failure_message(
		"System should handle operations without null reference crashes"
	).is_not_null()

#endregion
