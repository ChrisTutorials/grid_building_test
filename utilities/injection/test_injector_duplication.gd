## Simple test to verify GBTestInjectorSystem automatic container duplication
## Uses CollisionTestEnvironment for proper setup and validation
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: CollisionTestEnvironment

func before_test() -> void:
	# Use scene_runner for proper test environment setup
	# This ensures proper validation and avoids validation error floods
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV)
	runner.simulate_frames(2)  # Allow initialization
	env = runner.scene() as CollisionTestEnvironment

func after_test() -> void:
	runner = null
	env = null

func test_automatic_container_duplication_in_scene() -> void:
	# Load the original container resource that's assigned in the scene
	var original_resource_path: String = "res://test/grid_building_test/resources/composition_containers/test_composition_container.tres"
	var original_container: GBCompositionContainer = load(original_resource_path)
	var original_id: int = original_container.get_instance_id()

	# Get the injector from the environment (already loaded and duplicated)
	var injector: GBTestInjectorSystem = env.injector as GBTestInjectorSystem
	assert_object(injector).append_failure_message("Environment should have GBTestInjectorSystem")
	# Get the container from the injector
	var scene_container: GBCompositionContainer = injector.composition_container
	assert_object(scene_container).is_not_null().append_failure_message("Injector should have a composition_container after scene load")
	var scene_id: int = scene_container.get_instance_id()
	# Verify it's a different instance (duplicated) - this is the key test!
	assert_int(scene_id).is_not_equal(original_id).append_failure_message("Container should be duplicated from resource during scene load. Original ID: %d, Scene ID: %d" % [original_id, scene_id])
	# Verify the duplicated container has the same structure
	assert_object(scene_container.config).is_not_null().append_failure_message("Duplicated container should have config")
	assert_object(scene_container.config.settings).is_not_null().append_failure_message("Duplicated container should have settings")

func test_static_duplicate_helper() -> void:
	# Test the static helper method
	var original := GBCompositionContainer.new()
	original.config = GBConfig.new()
	var duplicated := GBTestInjectorSystem.duplicate_container(original)
	assert_that(duplicated).is_not_null().append_failure_message("duplicate_container should return a container").is_not_null()
	assert_that(duplicated).is_not_same(original).append_failure_message("duplicate_container should create a new instance")
	assert_that(duplicated.config).is_not_null().append_failure_message("Duplicated container should have config")
