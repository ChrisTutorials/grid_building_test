## Reliable Test Base Class
##
## Provides fail-fast validation for test environments to prevent null object access patterns.
## All test classes should extend this for robust environment setup validation.
##
## Key Features:
## - Fail-fast environment validation in before_test()
## - Comprehensive cleanup in after_test()
## - Clear error messages for debugging
## - Proper resource lifecycle management
extends GdUnitTestSuite
class_name ReliableTestBase

var test_environment: AllSystemsTestEnvironment

## Override this method in child classes to perform additional environment setup
## Call super() first to ensure base environment validation
func before_test() -> void:
	# Create test environment
	test_environment = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	
	# Fail fast if environment is invalid
	if not test_environment:
		fail("Test environment creation failed - check EnvironmentTestFactory.create_all_systems_env()")
		return
	
	# Validate core components exist
	var validation_errors: Array[String] = []
	
	if not test_environment.injector:
		validation_errors.append("Missing injector")
	
	if not test_environment.building_system:
		validation_errors.append("Missing building_system")
	
	if not test_environment.grid_targeting_system:
		validation_errors.append("Missing grid_targeting_system")
	
	if not test_environment.positioner:
		validation_errors.append("Missing positioner")
	
	if not test_environment.world:
		validation_errors.append("Missing world")
	
	if not test_environment.level:
		validation_errors.append("Missing level")
	
	# Check for environment-specific issues
	var environment_issues: Array = test_environment.get_issues()
	if not environment_issues.is_empty():
		for issue: Variant in environment_issues:
			validation_errors.append("Environment issue: " + str(issue))
	
	# Fail fast with detailed error information
	if validation_errors.size() > 0:
		var error_message: String = "Environment validation failed:\n"
		for i in range(validation_errors.size()):
			error_message += "  %d. %s\n" % [i + 1, validation_errors[i]]
		error_message += "\nThis indicates a fundamental problem with test environment setup."
		error_message += "\nCheck AllSystemsTestEnvironment scene and factory methods."
		fail(error_message)

## Override this method in child classes to perform additional cleanup
## Call super() last to ensure base cleanup happens after child cleanup
func after_test() -> void:
	# Clean up test environment
	if test_environment:
		test_environment.queue_free()
		test_environment = null

## Helper method to validate that required components are available
## Use this in test methods to ensure dependencies are met
func validate_component_available(component: Object, component_name: String) -> bool:
	if component == null:
		fail("Required component '%s' is not available. Check environment setup." % component_name)
		return false
	return true

## Helper method to validate targeting state is properly configured
func validate_targeting_state(state: GridTargetingState, context: String = "Targeting state") -> bool:
	if state == null:
		fail("%s is null. Check environment initialization." % context)
		return false
	
	if not state.is_active:
		fail("%s is not active. Check targeting system setup." % context)
		return false
	
	return true

## Helper method to validate building system is ready
func validate_building_system(system: BuildingSystem, context: String = "Building system") -> bool:
	if system == null:
		fail("%s is null. Check environment initialization." % context)
		return false
	
	# Add specific building system validation here if needed
	return true

## Helper method to validate collision mapper setup
func validate_collision_mapper(mapper: CollisionMapper, context: String = "Collision mapper") -> bool:
	if mapper == null:
		fail("%s is null. Check environment initialization." % context)
		return false
	
	# Add specific collision mapper validation here if needed
	return true

## Helper method to create and validate a test node
func create_validated_test_node(node_name: String = "TestNode") -> Node2D:
	var node: Node2D = UnifiedTestFactory.create_test_node2d(self)
	if not validate_component_available(node, "Test Node2D"):
		return null
	
	node.name = node_name
	return node

## Helper method to create and validate a composition container
func create_validated_container() -> GBCompositionContainer:
	var container: GBCompositionContainer = UnifiedTestFactory.create_test_composition_container(self)
	if not validate_component_available(container, "Composition Container"):
		return null
	return container

## Helper method to log test context for debugging
func log_test_environment_state() -> void:
	if not test_environment:
		print("TEST ENVIRONMENT STATE: Environment is null")
		return
	
	var state_info: Array[String] = []
	state_info.append("injector: " + ("✓" if test_environment.injector else "✗"))
	state_info.append("building_system: " + ("✓" if test_environment.building_system else "✗"))
	state_info.append("grid_targeting_system: " + ("✓" if test_environment.grid_targeting_system else "✗"))
	state_info.append("positioner: " + ("✓" if test_environment.positioner else "✗"))
	state_info.append("world: " + ("✓" if test_environment.world else "✗"))
	state_info.append("level: " + ("✓" if test_environment.level else "✗"))
	
	print("TEST ENVIRONMENT STATE: " + ", ".join(state_info))

## Helper method to get targeting state from environment
func get_targeting_state() -> GridTargetingState:
	if not test_environment or not test_environment.grid_targeting_system:
		fail("Cannot get targeting state - grid targeting system not available")
		return null
	
	var state: GridTargetingState = test_environment.grid_targeting_system.get_targeting_state()
	if not validate_targeting_state(state, "Environment targeting state"):
		return null
	
	return state

## Helper method to get building system from environment
func get_building_system() -> BuildingSystem:
	if not test_environment:
		fail("Cannot get building system - test environment not available")
		return null
	
	if not validate_building_system(test_environment.building_system, "Environment building system"):
		return null
	
	return test_environment.building_system
