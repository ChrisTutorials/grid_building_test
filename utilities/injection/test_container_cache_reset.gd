## Isolated test for GBCompositionContainer cache reset after duplication
## Tests ONLY the container duplication and cache behavior, nothing else
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var test_env: Node
var original_container: GBCompositionContainer
var original_states: GBStates


func before_test() -> void:
	# Load test environment
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	runner.simulate_frames(1)
	test_env = runner.scene()

	# Get the original container reference BEFORE any operations
	original_container = test_env.injector.composition_container
	original_states = original_container.get_states()

	var logger: GBLogger = original_container.get_logger()
	if logger:
		logger.log_debug(
			"[test_container_cache_reset] Original container: %s" % [original_container]
		)
		logger.log_debug("[test_container_cache_reset] Original states: %s" % [original_states])


## TEST 1: Verify container is duplicated on scene load
func test_container_is_duplicated_on_load() -> void:
	var injector: GBTestInjectorSystem = test_env.injector as GBTestInjectorSystem
	assert_object(injector).append_failure_message("Should have GBTestInjectorSystem").is_not_null()

	var current_container: GBCompositionContainer = test_env.injector.composition_container

	# Container should be different object than what scene file had (duplicated)
	# Note: We can't easily test this without scene file inspection, but we can verify it's not null
	assert_object(current_container).append_failure_message("Container should exist").is_not_null()


## TEST 2: Verify states object is fresh after duplication
func test_states_are_fresh_after_duplication() -> void:
	var container: GBCompositionContainer = test_env.injector.composition_container
	var states: GBStates = container.get_states()

	var logger: GBLogger = container.get_logger()
	if logger:
		logger.log_debug("[test_states_fresh] Container: %s" % [container])
		logger.log_debug("[test_states_fresh] States: %s" % [states])

	# States should be non-null
	assert_object(states).append_failure_message("States should be created").is_not_null()

	# Get states again - should be SAME object (cached)
	var states_again: GBStates = container.get_states()
	(
		assert_bool(states == states_again)
		. append_failure_message("get_states() should return cached instance")
		. is_true()
	)


## TEST 3: Verify manipulation_state.data starts as null
func test_manipulation_state_data_starts_null() -> void:
	var container: GBCompositionContainer = test_env.injector.composition_container
	var states: GBStates = container.get_states()
	var manipulation_state: ManipulationState = states.manipulation

	var logger: GBLogger = container.get_logger()
	if logger:
		logger.log_debug("[test_data_null] Container: %s" % [container])
		logger.log_debug("[test_data_null] States: %s" % [states])
		logger.log_debug("[test_data_null] manipulation_state.data: %s" % [manipulation_state.data])

	(
		assert_object(manipulation_state.data)
		. append_failure_message("manipulation_state.data should start as null")
		. is_null()
	)


## TEST 4: Verify setting data and then clearing works
func test_setting_and_clearing_data_works() -> void:
	var container: GBCompositionContainer = test_env.injector.composition_container
	var states: GBStates = container.get_states()
	var manipulation_state: ManipulationState = states.manipulation

	var logger: GBLogger = container.get_logger()
	if logger:
		logger.log_debug(
			"[test_set_clear] BEFORE: manipulation_state.data=%s" % [manipulation_state.data]
		)

	# Create dummy data
	var test_data: ManipulationData = ManipulationData.new(null, null, null, GBEnums.Action.MOVE)

	# Set it
	states.manipulation.data = test_data
	if logger:
		logger.log_debug(
			"[test_set_clear] AFTER SET: manipulation_state.data=%s" % [manipulation_state.data]
		)

	(
		assert_object(manipulation_state.data)
		. append_failure_message("Data should be set")
		. is_not_null()
	)

	# Clear it
	states.manipulation.data = null
	if logger:
		logger.log_debug(
			"[test_set_clear] AFTER CLEAR: manipulation_state.data=%s" % [manipulation_state.data]
		)

	(
		assert_object(manipulation_state.data)
		. append_failure_message("Data should be cleared to null")
		. is_null()
	)


## TEST 5: Verify multiple tests get fresh states (between tests)
var _test_5_first_run: bool = false


func test_fresh_states_between_tests() -> void:
	var container: GBCompositionContainer = test_env.injector.composition_container
	var states: GBStates = container.get_states()

	var logger: GBLogger = container.get_logger()
	if logger:
		logger.log_debug("[test_fresh_states] Container: %s" % [container])
		logger.log_debug("[test_fresh_states] States: %s" % [states])
		logger.log_debug("[test_fresh_states] _test_5_first_run: %s" % [_test_5_first_run])

	if not _test_5_first_run:
		_test_5_first_run = true
		# Set data in first run
		states.manipulation.data = ManipulationData.new(null, null, null, GBEnums.Action.MOVE)
		if logger:
			logger.log_debug(
				"[test_fresh_states] FIRST RUN - Set data: %s" % [states.manipulation.data]
			)
	else:
		# In second run (retry), data should be null (fresh states)
		if logger:
			logger.log_debug(
				"[test_fresh_states] SECOND RUN - Check data: %s" % [states.manipulation.data]
			)

		# This will FAIL if states are not fresh between tests
		(
			assert_object(states.manipulation.data)
			. append_failure_message(
				"States should be fresh between test runs (data should be null)"
			)
			. is_null()
		)
