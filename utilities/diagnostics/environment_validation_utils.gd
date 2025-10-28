## Environment Validation Utilities
##
## Static utility methods for validating test environments and providing clear error messages
## when environment setup fails. Use these utilities in test before_test() methods to catch
## environment issues early and prevent widespread test failures.
class_name EnvironmentValidationUtils
extends RefCounted


## Validates that an AllSystemsTestEnvironment is properly set up
## Returns true if valid, false if invalid (with error messages logged)
static func validate_all_systems_environment(
	env: AllSystemsTestEnvironment, test_name: String = "Test"
) -> bool:
	if env == null:
		push_error(
			(
				"%s: AllSystemsTestEnvironment is null - check EnvironmentTestFactory.instance_all_systems_env() or EnvironmentTestFactory.create_all_systems_env() call"
				% test_name
			)
		)
		return false

	var validation_errors: Array[String] = []

	# Check core components
	if env.injector == null:
		validation_errors.append("injector is null")

	if env.building_system == null:
		validation_errors.append("building_system is null")

	if env.grid_targeting_system == null:
		validation_errors.append("grid_targeting_system is null")

	if env.positioner == null:
		validation_errors.append("positioner is null")

	if env.world == null:
		validation_errors.append("world is null")

	if env.level == null:
		validation_errors.append("level is null")

	if env.level_context == null:
		validation_errors.append("level_context is null")

	if env.tile_map_layer == null:
		validation_errors.append("tile_map_layer is null")

	if env.objects_parent == null:
		validation_errors.append("objects_parent is null")

	if env.placer == null:
		validation_errors.append("placer is null")

	# Check for environment-specific issues
	var environment_issues: Array = env.get_issues()
	if not environment_issues.is_empty():
		for issue: Variant in environment_issues:
			validation_errors.append("Environment issue: " + str(issue))

	# Report errors if any found
	if validation_errors.size() > 0:
		var error_message: String = "%s: AllSystemsTestEnvironment validation failed:\n" % test_name
		for i: int in range(validation_errors.size()):
			error_message += "  %d. %s\n" % [i + 1, validation_errors[i]]
		error_message += "\nThis indicates a fundamental problem with test environment setup."
		error_message += "\nCheck AllSystemsTestEnvironment scene (uid://ioucajhfxc8b) and factory methods."
		push_error(error_message)
		return false

	return true


## Validates that a collision test environment is properly set up
static func validate_collision_test_environment(env: Node, test_name: String = "Test") -> bool:
	if env == null:
		push_error(
			(
				"%s: CollisionTestEnvironment is null - check EnvironmentTestFactory.instance_collision_test_env() or EnvironmentTestFactory.create_collision_test_env() call"
				% test_name
			)
		)
		return false

	# Check if it has basic methods we expect
	if not env.has_method("get_container"):
		push_error(
			(
				"%s: CollisionTestEnvironment does not have get_container() method - wrong scene type?"
				% test_name
			)
		)
		return false

	var container: GBCompositionContainer = env.get_container()
	if container == null:
		push_error(
			(
				"%s: CollisionTestEnvironment.get_container() returned null - dependency injection broken"
				% test_name
			)
		)
		return false

	return true


## Validates that components extracted from test environment are not null
static func validate_extracted_components(
	components: Dictionary, test_name: String = "Test"
) -> bool:
	var validation_errors: Array[String] = []

	for component_name: String in components.keys():
		var component: Variant = components[component_name]
		if component == null:
			validation_errors.append("%s is null" % component_name)

	if validation_errors.size() > 0:
		var error_message: String = "%s: Component extraction failed:\n" % test_name
		for i: int in range(validation_errors.size()):
			error_message += "  %d. %s\n" % [i + 1, validation_errors[i]]
		error_message += "\nComponents are null in test environment. Check environment setup."
		push_error(error_message)
		return false

	return true


## Validates targeting state is properly configured
static func validate_targeting_state(state: GridTargetingState, test_name: String = "Test") -> bool:
	if state == null:
		push_error("%s: GridTargetingState is null - check environment initialization" % test_name)
		return false

	if not state.is_active:
		push_error(
			"%s: GridTargetingState is not active - check targeting system setup" % test_name
		)
		return false

	return true


## Validates collision mapper is properly configured
static func validate_collision_mapper(mapper: CollisionMapper, test_name: String = "Test") -> bool:
	if mapper == null:
		push_error("%s: CollisionMapper is null - check environment initialization" % test_name)
		return false

	# Add specific collision mapper validation if needed
	return true


## Validates building system is properly configured
static func validate_building_system(system: BuildingSystem, test_name: String = "Test") -> bool:
	if system == null:
		push_error("%s: BuildingSystem is null - check environment initialization" % test_name)
		return false

	# Add specific building system validation if needed
	return true


## Validates indicator manager is properly configured
static func validate_indicator_manager(
	manager: IndicatorManager, test_name: String = "Test"
) -> bool:
	if manager == null:
		push_error("%s: IndicatorManager is null - check environment initialization" % test_name)
		return false

	# Check if it can create collision mapper
	var collision_mapper: CollisionMapper = manager.get_collision_mapper()
	if collision_mapper == null:
		push_error(
			(
				"%s: IndicatorManager.get_collision_mapper() returned null - dependency issue"
				% test_name
			)
		)
		return false

	return true


## Helper method to create a standardized validation report
static func create_validation_report(test_name: String, components_to_validate: Dictionary) -> bool:
	var all_valid: bool = true

	for component_name: String in components_to_validate.keys():
		var component: Variant = components_to_validate[component_name]
		var is_valid: bool = false

		match component_name:
			"all_systems_environment":
				is_valid = validate_all_systems_environment(
					component as AllSystemsTestEnvironment, test_name
				)
			"collision_test_environment":
				is_valid = validate_collision_test_environment(component as Node, test_name)
			"targeting_state":
				is_valid = validate_targeting_state(component as GridTargetingState, test_name)
			"collision_mapper":
				is_valid = validate_collision_mapper(component as CollisionMapper, test_name)
			"building_system":
				is_valid = validate_building_system(component as BuildingSystem, test_name)
			"indicator_manager":
				is_valid = validate_indicator_manager(component as IndicatorManager, test_name)
			_:
				# Generic null check for unknown component types
				if component == null:
					push_error("%s: %s is null" % [test_name, component_name])
					is_valid = false
				else:
					is_valid = true

		if not is_valid:
			all_valid = false

	return all_valid


## Logs environment state for debugging purposes
static func log_environment_state(
	env: AllSystemsTestEnvironment, test_name: String = "Test"
) -> void:
	if env == null:
		print("%s: Environment state: NULL" % test_name)
		return

	var state_info: Array[String] = []
	state_info.append("injector: " + ("✓" if env.injector else "✗"))
	state_info.append("building_system: " + ("✓" if env.building_system else "✗"))
	state_info.append("grid_targeting_system: " + ("✓" if env.grid_targeting_system else "✗"))
	state_info.append("positioner: " + ("✓" if env.positioner else "✗"))
	state_info.append("world: " + ("✓" if env.world else "✗"))
	state_info.append("level: " + ("✓" if env.level else "✗"))
	state_info.append("tile_map_layer: " + ("✓" if env.tile_map_layer else "✗"))

	print("%s: Environment state: %s" % [test_name, ", ".join(state_info)])


## Safe extraction helper that validates components during extraction
static func safely_extract_components(
	env: AllSystemsTestEnvironment, test_name: String = "Test"
) -> Dictionary:
	if not validate_all_systems_environment(env, test_name):
		return {}  # Empty dictionary indicates failure

	var components: Dictionary = {
		"positioner": env.positioner,
		"collision_mapper": null,
		"indicator_manager": env.indicator_manager,
		"tile_map_layer": env.tile_map_layer,
		"building_system": env.building_system,
		"targeting_state": null
	}

	# Safely extract collision mapper from indicator manager
	if env.indicator_manager != null:
		components["collision_mapper"] = env.indicator_manager.get_collision_mapper()

	# Safely extract targeting state from grid targeting system
	if env.grid_targeting_system != null:
		components["targeting_state"] = env.grid_targeting_system.get_targeting_state()

	# Validate all extracted components
	if not validate_extracted_components(components, test_name):
		return {}  # Empty dictionary indicates failure

	return components
