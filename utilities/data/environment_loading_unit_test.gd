extends GdUnitTestSuite

## Unit test for environment loading functionality
## Tests GBTestConstants environment scene loading in isolation
## and ensures all environments use the same test composition container
##
## TILEMAP DIMENSION VALIDATION:
## All test environment scenes must have 31x31 tile maps from (-15, -15) to (15, 15).
## This provides:
## - Consistent test boundary expectations across all environments
## - Safe placement zones for collision and bounds testing
## - Prevents "Tried placing outside of valid map area" errors
## - Ensures indicator generation has sufficient space for all test objects
## - Provides predictable coordinate ranges for parameterized tests
##
## WHY 31x31 FROM -15 TO +15 (ACTUAL DIMENSIONS):
## - Centered at origin (0, 0) for intuitive positioning
## - 31x31 provides sufficient space for complex multi-tile objects
## - Historical implementation uses (-15, -15) to (15, 15) inclusive
## - ISOMETRIC_TEST uses different dimensions due to isometric tile requirements
## - Provides margins for drag-building tests and collision separation
##
## WHY 31x31 FROM -15 TO +15 (ACTUAL DIMENSIONS):
## - Centered at origin (0, 0) for intuitive positioning
## - 31x31 provides sufficient space for complex multi-tile objects
## - Historical implementation uses (-15, -15) to (15, 15) inclusive
## - ISOMETRIC_TEST uses different dimensions due to isometric tile requirements
## - Provides margins for drag-building tests and collision separation

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
		assert_that(env_scene).append_failure_message("%s environment scene should load successfully" % type_name).is_not_null()

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
		assert_that(env_scene).append_failure_message("%s environment scene should be available" % type_name).is_not_null()

		var env: Node = env_scene.instantiate()
		assert_that(env).append_failure_message("%s environment scene should instantiate successfully" % type_name).is_not_null()
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
		assert_that(env_scene).append_failure_message("%s environment scene should be available" % type_name).is_not_null()

		var env: GBTestEnvironment = env_scene.instantiate() as GBTestEnvironment
		assert_that(env).append_failure_message("%s environment should instantiate as GBTestEnvironment" % type_name).is_not_null()

		# Get the container from the environment
		var container: GBCompositionContainer = env.get_container()
		assert_that(container).append_failure_message("%s environment should have a container" % type_name).is_not_null()

		# Verify it's the same test composition container instance/resource (except for ISOMETRIC_TEST)
	var expected_container: GBCompositionContainer = auto_free(GBTestConstants.TEST_COMPOSITION_CONTAINER.duplicate(true))
		if environment_type == GBTestConstants.EnvironmentType.ISOMETRIC_TEST:
			# ISOMETRIC_TEST may use a different container - just verify it has placement rules
			var placement_rules: Array[PlacementRule] = container.get_placement_rules()
			GBTestDiagnostics.buffer("[CONTAINER_TEST] %s environment placement_rules count: %d" % [type_name, placement_rules.size()])
			var context := GBTestDiagnostics.flush_for_assert()
			assert_that(placement_rules.size()).append_failure_message(
				"%s environment should have placement rules configured. Context: %s" % [type_name, context]
			).is_greater(0)
		else:
			# Other environments should use the standard test container
			assert_that(container.resource_path).append_failure_message(
				"%s environment should use the same test composition container. Expected: %s, Got: %s" % [
					type_name, expected_container.resource_path, container.resource_path
				]
			).is_equal(expected_container.resource_path)

			# Verify placement rules are consistent (single source of truth)
			var placement_rules: Array[PlacementRule] = container.get_placement_rules()
			GBTestDiagnostics.buffer("[CONTAINER_TEST] %s environment placement_rules count: %d" % [type_name, placement_rules.size()])
			
			# All test environments should have the same placement rules from the shared container
			var expected_rules: Array[PlacementRule] = expected_container.get_placement_rules()
			var context := GBTestDiagnostics.flush_for_assert()
			assert_that(placement_rules.size()).append_failure_message(
				"%s environment should have same number of placement rules as test container. Expected: %d, Got: %d. Context: %s" % [
					type_name, expected_rules.size(), placement_rules.size(), context
				]
			).is_equal(expected_rules.size())

		auto_free(env)

## Test: Environment tilemaps are correctly dimensioned (31x31 from -15 to +15)
## This ensures consistent test environments and prevents bounds validation issues
func test_environment_tilemaps_have_correct_dimensions() -> void:
	var env_types: Array = [
		[GBTestConstants.EnvironmentType.ALL_SYSTEMS, "ALL_SYSTEMS"],
		[GBTestConstants.EnvironmentType.BUILDING_TEST, "BUILDING_TEST"],
		[GBTestConstants.EnvironmentType.COLLISION_TEST, "COLLISION_TEST"],
		# ISOMETRIC_TEST is handled separately due to different requirements
	]

	for env_data: Array in env_types:
		var environment_type: GBTestConstants.EnvironmentType = env_data[0]
		var type_name: String = env_data[1]
		
		var env_scene: PackedScene = GBTestConstants.get_environment_scene(environment_type)
		assert_that(env_scene).is_not_null().append_failure_message("%s environment scene should be available" % type_name)

		var env: GBTestEnvironment = env_scene.instantiate() as GBTestEnvironment
		assert_that(env).is_not_null().append_failure_message("%s environment should instantiate as GBTestEnvironment" % type_name)
		add_child(env)
		await get_tree().process_frame  # Let the environment initialize

		# Verify tilemap layer exists
		assert_that(env.tile_map_layer).is_not_null().append_failure_message(
			"%s environment should have a tile_map_layer" % type_name
		)

		var tile_map: TileMapLayer = env.tile_map_layer
		var used_rect: Rect2i = tile_map.get_used_rect()
		
		# Expected dimensions: 31x31 tiles from (-15, -15) to (15, 15) inclusive
		# This gives us used_rect.position = (-15, -15) and used_rect.size = (31, 31)
		var expected_position: Vector2i = Vector2i(-15, -15)
		var expected_size: Vector2i = Vector2i(31, 31)
		var expected_end: Vector2i = Vector2i(15, 15)  # position + size - 1
		var actual_end: Vector2i = used_rect.position + used_rect.size - Vector2i(1, 1)
		
		assert_vector(Vector2(used_rect.position)).is_equal(Vector2(expected_position)).append_failure_message(
			"%s tilemap used_rect.position should be %s but was %s" % [type_name, expected_position, used_rect.position]
		)
		
		assert_vector(Vector2(used_rect.size)).is_equal(Vector2(expected_size)).append_failure_message(
			"%s tilemap used_rect.size should be %s (31x31) but was %s" % [type_name, expected_size, used_rect.size]
		)
		
		assert_vector(Vector2(actual_end)).is_equal(Vector2(expected_end)).append_failure_message(
			"%s tilemap should end at %s but ends at %s (used_rect=%s)" % [type_name, expected_end, actual_end, used_rect]
		)

		# Verify tile_set configuration
		assert_that(tile_map.tile_set).is_not_null().append_failure_message(
			"%s tilemap should have a tile_set configured" % type_name
		)

		# Verify standard tile size (16x16 pixels as per GBTestConstants.DEFAULT_TILE_SIZE)
		var tile_size: Vector2i = tile_map.tile_set.tile_size
		var expected_tile_size: Vector2i = Vector2i(16, 16)
		assert_vector(Vector2(tile_size)).is_equal(Vector2(expected_tile_size)).append_failure_message(
			"%s tilemap tile_size should be %s but was %s" % [type_name, expected_tile_size, tile_size]
		)

		# Verify tiles have proper TileData (required for bounds validation)
		# Test a few key positions to ensure tilemap has valid tile data
		var test_positions: Array[Vector2i] = [
			Vector2i(0, 0),    # Center
			Vector2i(-15, -15), # Top-left corner
			Vector2i(15, 15),   # Bottom-right corner
			Vector2i(-10, -12), # Conservative safe zone position
		]
		
		for test_pos: Vector2i in test_positions:
			var tile_data: TileData = tile_map.get_cell_tile_data(test_pos)
			assert_object(tile_data).is_not_null().append_failure_message(
				"%s tilemap should have TileData at position %s for proper bounds validation" % [type_name, test_pos]
			)

		auto_free(env)

## Test: Isometric environment has appropriate dimensions for isometric testing
func test_isometric_environment_tilemap_dimensions() -> void:
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ISOMETRIC_TEST)
	assert_that(env_scene).append_failure_message("ISOMETRIC_TEST environment scene should be available").is_not_null()

	var env: GBTestEnvironment = env_scene.instantiate() as GBTestEnvironment
	assert_that(env).append_failure_message("ISOMETRIC_TEST environment should instantiate as GBTestEnvironment").is_not_null()
	add_child(env)
	await get_tree().process_frame  # Let the environment initialize

	# Verify tilemap layer exists
	assert_that(env.tile_map_layer).append_failure_message(
		"ISOMETRIC_TEST environment should have a tile_map_layer"
	).is_not_null()

	var tile_map: TileMapLayer = env.tile_map_layer
	var used_rect: Rect2i = tile_map.get_used_rect()

	# Document actual isometric dimensions (from test results: 14x14 from (-7, -6) to (6, 7))
	# Note: Isometric environments may have different requirements due to tile shape
	var _actual_position: Vector2i = used_rect.position
	var actual_size: Vector2i = used_rect.size
	var _actual_end: Vector2i = used_rect.position + used_rect.size - Vector2i(1, 1)

	# Verify tilemap has reasonable dimensions (not empty, has sufficient space)
	assert_int(actual_size.x).append_failure_message(
		"ISOMETRIC_TEST tilemap should have reasonable width, got %d" % actual_size.x
	).is_greater(10)
	assert_int(actual_size.y).append_failure_message(
		"ISOMETRIC_TEST tilemap should have reasonable height, got %d" % actual_size.y
	).is_greater(10)

	# Verify tile_set configuration
	assert_that(tile_map.tile_set).append_failure_message(
		"ISOMETRIC_TEST tilemap should have a tile_set configured"
	).is_not_null()

	# Document actual tile size for isometric (from test results: 90x50 pixels)
	var tile_size: Vector2i = tile_map.tile_set.tile_size
	assert_int(tile_size.x).append_failure_message(
		"ISOMETRIC_TEST tile_size.x should be positive, got %d" % tile_size.x
	).is_greater(0)
	assert_int(tile_size.y).append_failure_message(
		"ISOMETRIC_TEST tile_size.y should be positive, got %d" % tile_size.y
	).is_greater(0)

	auto_free(env)
