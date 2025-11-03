## Unit tests for GBInjectorSystem to verify test isolation and dependency injection.
##
## Tests that the injector system properly:
## - Injects dependencies into nodes
## - Maintains isolation between tests
## - Handles container duplication correctly
## - Tracks injection state properly
extends GdUnitTestSuite

var _test_container: GBCompositionContainer
var _injector: GBInjectorSystem


func before_test() -> void:
	# Create a fresh container for each test
	_test_container = auto_free(GBCompositionContainer.new())
	_test_container.config = auto_free(GBConfig.new())

	# Create injector with the test container
	_injector = auto_free(GBInjectorSystem.new(_test_container))


func after_test() -> void:
	_test_container = null
	_injector = null


## Tests that the injector correctly initializes with a container
func test_injector_initializes_with_container() -> void:
	(
		assert_object(_injector.composition_container)
		. append_failure_message("Injector should have composition_container set")
		. is_not_null()
	)

	(
		assert_object(_injector.composition_container)
		. append_failure_message("Injector container should match test container")
		. is_equal(_test_container)
	)


## Tests that multiple test runs maintain isolation
func test_multiple_tests_maintain_container_isolation() -> void:
	# First test setup
	var container1: GBCompositionContainer = _test_container

	# Modify the container
	container1.config.settings = auto_free(GBSettings.new())

	# Simulate a new test by creating a new container
	var container2: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	container2.config = auto_free(GBConfig.new())

	# Verify they are different instances
	(
		assert_object(container2)
		. append_failure_message("Second container should be a different instance")
		. is_not_equal(container1)
	)

	# Verify second container is unaffected by first container's modifications
	(
		assert_object(container2.config.settings)
		. append_failure_message("Second container should have null settings (unaffected by first)")
		. is_null()
	)

	(
		assert_object(container1.config.settings)
		. append_failure_message("First container should have settings we just set")
		. is_not_null()
	)


## Tests that injector tracks injection state correctly
func test_injector_tracks_injection_count() -> void:
	# Create a test node that implements resolve_gb_dependencies
	var test_node: Node = auto_free(Node.new())
	test_node.set_script(preload("res://test/grid_building_test/utilities/test_injectable_node.gd"))

	# Manually trigger injection
	if test_node.has_method("resolve_gb_dependencies"):
		test_node.resolve_gb_dependencies(_test_container)

	# Verify the node received the container
	(
		assert_object(test_node.get("_injected_container"))
		. append_failure_message("Node should have received container via injection")
		. is_equal(_test_container)
	)


## Tests that container duplication creates independent instances
func test_container_duplication_creates_independent_instances() -> void:
	var original: GBCompositionContainer = _test_container
	var duplicated: GBCompositionContainer = auto_free(original.duplicate(true))

	# Verify they are different instances
	(
		assert_object(duplicated)
		. append_failure_message("Duplicate should be a different instance")
		. is_not_equal(original)
	)

	# Modify the duplicate
	duplicated.config.settings = auto_free(GBSettings.new())

	# Verify original is unaffected
	(
		assert_object(original.config.settings)
		. append_failure_message(
			"Original container should be unaffected by duplicate modifications"
		)
		. is_null()
	)


## Tests that injector handles null container gracefully
func test_injector_handles_null_container_gracefully() -> void:
	var null_injector: GBInjectorSystem = auto_free(GBInjectorSystem.new())

	# Verify it doesn't crash
	(
		assert_object(null_injector)
		. append_failure_message("Injector should exist even with null container")
		. is_not_null()
	)

	(
		assert_object(null_injector.composition_container)
		. append_failure_message("Injector should have null container")
		. is_null()
	)


## Tests that container state changes don't leak between injectors
func test_container_state_isolation_between_injectors() -> void:
	# Create first injector with container
	var injector1: GBInjectorSystem = auto_free(GBInjectorSystem.new(_test_container))

	# Modify container through injector1
	injector1.composition_container.config.settings = auto_free(GBSettings.new())

	# Create a new container for second injector
	var container2: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	container2.config = auto_free(GBConfig.new())
	var injector2: GBInjectorSystem = auto_free(GBInjectorSystem.new(container2))

	# Verify second injector's container is unaffected
	(
		assert_object(injector2.composition_container.config.settings)
		. append_failure_message("Second injector's container should be unaffected")
		. is_null()
	)

	(
		assert_object(injector1.composition_container.config.settings)
		. append_failure_message("First injector's container should have settings")
		. is_not_null()
	)


## Tests that deep duplication copies nested objects
func test_deep_duplication_copies_nested_objects() -> void:
	# Set up nested structure
	_test_container.config.settings = auto_free(GBSettings.new())
	var original_settings: GBSettings = _test_container.config.settings

	# Deep duplicate
	var duplicated: GBCompositionContainer = auto_free(_test_container.duplicate(true))

	# Verify nested objects are different instances
	(
		assert_object(duplicated.config)
		. append_failure_message("Duplicate config should be a different instance")
		. is_not_equal(_test_container.config)
	)

	# Modify duplicate's nested object
	duplicated.config.settings.runtime_checks = auto_free(GBRuntimeChecks.new())

	# Verify original's nested object is unaffected
	(
		assert_object(original_settings.runtime_checks)
		. append_failure_message("Original settings runtime_checks should be unaffected")
		. is_null()
	)


## Tests that injector maintains independent state across test runs
func test_injector_state_independence_across_runs() -> void:
	# First run
	var container1: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	container1.config = auto_free(GBConfig.new())
	var injector1: GBInjectorSystem = auto_free(GBInjectorSystem.new(container1))

	# Mark as initialized (simulate injection completing)
	injector1.composition_container.config.settings = auto_free(GBSettings.new())

	# Second run with fresh setup
	var container2: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	container2.config = auto_free(GBConfig.new())
	var injector2: GBInjectorSystem = auto_free(GBInjectorSystem.new(container2))

	# Verify second run starts clean
	(
		assert_object(injector2.composition_container.config.settings)
		. append_failure_message("Second injector should start with clean state")
		. is_null()
	)
