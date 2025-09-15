extends GdUnitTestSuite

## Unit test for environment loading functionality
## Tests GBTestConstants environment scene loading in isolation

func test_environment_scene_loading() -> void:
	# Test that GBTestConstants can load the all_systems environment
	var env_scene: PackedScene = GBTestConstants.get_environment_scene("all_systems")
	assert_that(env_scene).is_not_null().append_failure_message("All systems environment scene should load successfully")

func test_environment_scene_instantiation() -> void:
	# Test that the loaded scene can be instantiated
	var env_scene: PackedScene = GBTestConstants.get_environment_scene("all_systems")
	assert_that(env_scene).is_not_null().append_failure_message("Environment scene should be available")

	var env: Node = env_scene.instantiate()
	assert_that(env).is_not_null().append_failure_message("Environment scene should instantiate successfully")
	auto_free(env)

func test_environment_components_exist() -> void:
	# Test that key components exist in the instantiated environment
	var env_scene: PackedScene = GBTestConstants.get_environment_scene("all_systems")
	assert_that(env_scene).is_not_null().append_failure_message("Environment scene should be available")

	var env: AllSystemsTestEnvironment = env_scene.instantiate() as AllSystemsTestEnvironment
	assert_that(env).is_not_null().append_failure_message("Environment should instantiate as AllSystemsTestEnvironment")

	# Check that key properties are set via the exported properties
	assert_that(env.injector).is_not_null().append_failure_message("Injector should be available via property")
	assert_that(env.indicator_manager).is_not_null().append_failure_message("IndicatorManager should be available via property")
	assert_that(env.positioner).is_not_null().append_failure_message("Positioner should be available via property")
	assert_that(env.tile_map_layer).is_not_null().append_failure_message("TileMapLayer should be available via property")

	# Check that the tile set is valid
	assert_that(env.tile_map_layer.tile_set).is_not_null().append_failure_message("TileMapLayer should have a valid tile set")

	auto_free(env)