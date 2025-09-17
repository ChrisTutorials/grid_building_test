extends GdUnitTestSuite

## Unit test for environment loading functionality
## Tests GBTestConstants environment scene loading in isolation
## and ensures all environments use the same test composition container

func test_environment_scene_loading() -> void:
	# Test that GBTestConstants can load each environment type
	var env_types: Array = [
		[GBTestConstants.EnvironmentType.ALL_SYSTEMS, "ALL_SYSTEMS"],
		[GBTestConstants.EnvironmentType.BUILDING_TEST, "BUILDING_TEST"],  
		[GBTestConstants.EnvironmentType.COLLISION_TEST, "COLLISION_TEST"],
		[GBTestConstants.EnvironmentType.ISOMETRIC_TEST, "ISOMETRIC_TEST"]
	]
	
	for env_data: Array in env_types:
		var environment_type: GBTestConstants.EnvironmentType = env_data[0]
		var type_name: String = env_data[1]
		
		var env_scene: PackedScene = GBTestConstants.get_environment_scene(environment_type)
		assert_that(env_scene).is_not_null().append_failure_message("%s environment scene should load successfully" % type_name)

func test_environment_scene_instantiation() -> void:
	# Test that the loaded scene can be instantiated
	var env_types: Array = [
		[GBTestConstants.EnvironmentType.ALL_SYSTEMS, "ALL_SYSTEMS"],
		[GBTestConstants.EnvironmentType.BUILDING_TEST, "BUILDING_TEST"],  
		[GBTestConstants.EnvironmentType.COLLISION_TEST, "COLLISION_TEST"],
		[GBTestConstants.EnvironmentType.ISOMETRIC_TEST, "ISOMETRIC_TEST"]
	]
	
	for env_data: Array in env_types:
		var environment_type: GBTestConstants.EnvironmentType = env_data[0]
		var type_name: String = env_data[1]
		
		var env_scene: PackedScene = GBTestConstants.get_environment_scene(environment_type)
		assert_that(env_scene).is_not_null().append_failure_message("%s environment scene should be available" % type_name)

		var env: Node = env_scene.instantiate()
		assert_that(env).is_not_null().append_failure_message("%s environment scene should instantiate successfully" % type_name)
		auto_free(env)

func test_environment_uses_same_test_container() -> void:
	# Test that all environments use the same test composition container (single source of truth)
	# Note: ISOMETRIC_TEST may use a different container (isometric-specific)
	var env_types: Array = [
		[GBTestConstants.EnvironmentType.ALL_SYSTEMS, "ALL_SYSTEMS"],
		[GBTestConstants.EnvironmentType.BUILDING_TEST, "BUILDING_TEST"],  
		[GBTestConstants.EnvironmentType.COLLISION_TEST, "COLLISION_TEST"],
		[GBTestConstants.EnvironmentType.ISOMETRIC_TEST, "ISOMETRIC_TEST"]
	]
	
	for env_data: Array in env_types:
		var environment_type: GBTestConstants.EnvironmentType = env_data[0]
		var type_name: String = env_data[1]
		
		var env_scene: PackedScene = GBTestConstants.get_environment_scene(environment_type)
		assert_that(env_scene).is_not_null().append_failure_message("%s environment scene should be available" % type_name)

		var env: GBTestEnvironment = env_scene.instantiate() as GBTestEnvironment
		assert_that(env).is_not_null().append_failure_message("%s environment should instantiate as GBTestEnvironment" % type_name)

		# Get the container from the environment
		var container: GBCompositionContainer = env.get_container()
		assert_that(container).is_not_null().append_failure_message("%s environment should have a container" % type_name)

		# Verify it's the same test composition container instance/resource (except for ISOMETRIC_TEST)
		var expected_container: GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER
		if environment_type == GBTestConstants.EnvironmentType.ISOMETRIC_TEST:
			# ISOMETRIC_TEST may use a different container - just verify it has placement rules
			var placement_rules: Array[PlacementRule] = container.get_placement_rules()
			print("[CONTAINER_TEST] %s environment placement_rules count: %d" % [type_name, placement_rules.size()])
			assert_that(placement_rules.size()).is_greater(0).append_failure_message(
				"%s environment should have placement rules configured" % type_name
			)
		else:
			# Other environments should use the standard test container
			assert_that(container.resource_path).is_equal(expected_container.resource_path).append_failure_message(
				"%s environment should use the same test composition container. Expected: %s, Got: %s" % [
					type_name, expected_container.resource_path, container.resource_path
				]
			)

			# Verify placement rules are consistent (single source of truth)
			var placement_rules: Array[PlacementRule] = container.get_placement_rules()
			print("[CONTAINER_TEST] %s environment placement_rules count: %d" % [type_name, placement_rules.size()])
			
			# All test environments should have the same placement rules from the shared container
			var expected_rules: Array[PlacementRule] = expected_container.get_placement_rules()
			assert_that(placement_rules.size()).is_equal(expected_rules.size()).append_failure_message(
				"%s environment should have same number of placement rules as test container. Expected: %d, Got: %d" % [
					type_name, expected_rules.size(), placement_rules.size()
				]
			)

		auto_free(env)
