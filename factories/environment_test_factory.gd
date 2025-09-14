class_name EnvironmentTestFactory
extends RefCounted

## Environment Test Factory
## Centralized creation of test environments and system containers
## Following GdUnit best practices: DRY principle, centralize common object creation

## Creates an AllSystemsTestEnvironment (extracted from UnifiedTestFactory)
## @param test_instance: Test instance for node management
## @param scene_uid: Scene UID for environment setup
static func create_all_systems_env(test_instance: Node, scene_uid: String) -> AllSystemsTestEnvironment:
	var env: AllSystemsTestEnvironment = load(scene_uid).instantiate()
	test_instance.add_child(env)
	
	# Use GdUnit test suite auto_free if available, otherwise handle manually
	if test_instance.has_method("auto_free"):
		test_instance.auto_free(env)
	
	# Validate environment setup
	var issues: Array = env.get_issues()
	if not issues.is_empty():
		push_error("Environment is not properly setup. Issues: %s" % str(issues))
	
	return env

## Creates a basic building system test environment
## @param test_instance: Test instance for node management  
## @param scene_uid: Scene UID for environment setup
static func create_building_system_test_environment(test_instance: Node, scene_uid: String) -> AllSystemsTestEnvironment:
	# Delegate for now, can be specialized later
	return create_all_systems_env(test_instance, scene_uid)

## Creates an indicator manager test environment
## @param test_instance: Test instance for node management
## @param scene_uid: Scene UID for environment setup  
static func create_indicator_manager_test_environment(test_instance: Node, scene_uid: String) -> AllSystemsTestEnvironment:
	# Delegate for now, can be specialized later
	return create_all_systems_env(test_instance, scene_uid)

## Validates that an environment is properly set up without issues
## @param env: The environment to validate
## @param context: Context string for error messages
static func validate_environment_setup(env: AllSystemsTestEnvironment, context: String = "Test environment") -> bool:
	if env == null:
		push_error("%s: environment is null" % context)
		return false
	
	# Use environment's get_issues method for validation
	var issues: Array = env.get_issues()
	if not issues.is_empty():
		push_error("%s has issues: %s" % [context, str(issues)])
		return false
	
	return true

## Validates that required dependencies are available from environment
## @param env: The environment to validate
## @param required_systems: Array of system names to check
static func validate_required_dependencies(env: AllSystemsTestEnvironment, required_systems: Array[String] = []) -> bool:
	if not validate_environment_setup(env, "Environment dependency validation"):
		return false
	
	# Default system checks
	var default_systems: Array[String] = ["building_system", "indicator_manager", "grid_targeting_system"]
	var systems_to_check: Array[String] = required_systems if not required_systems.is_empty() else default_systems
	
	for system_name: String in systems_to_check:
		var system: Variant = env.get(system_name)
		if system == null:
			push_error("Required system '%s' not available from environment" % system_name)
			return false
	
	return true
