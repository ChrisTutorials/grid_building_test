## Unit tests for GridPositioner2D mouse input gate functionality
##
## Tests verify that enable_mouse_input setting properly gates mouse positioning:
## - When true: mouse movement updates position and world tracking
## - When false: mouse movement is blocked, no position updates, no world tracking
##
## TESTING PATTERN: Uses parameterized tests with GdUnitSceneRunner
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _env: CollisionTestEnvironment
var _positioner: GridPositioner2D
var _settings: GridTargetingSettings
var _targeting_state: GridTargetingState

func before_test() -> void:
	# Use scene_runner for reliable frame simulation
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames

	_env = runner.scene() as CollisionTestEnvironment
	# Container is already duplicated by environment's _ready() for test isolation

	_positioner = _env.positioner
	_targeting_state = _env.targeting_state
	_settings = _env.container.config.settings.targeting

	# Ensure mode is BUILD for testing
	_env.container.get_states().mode.current = GBEnums.Mode.BUILD

func after_test() -> void:
	runner = null
	_env = null
	_positioner = null
	_settings = null
	_targeting_state = null

## Test mouse gate respects enable_mouse_input setting
## Parameterized: tests both enabled (true) and disabled (false) scenarios
@warning_ignore("unused_parameter")
func test_mouse_gate_respects_enable_mouse_input_setting(
	enable_mouse_input: bool,
	should_update_position: bool,
	should_track_world: bool,
	test_parameters := [
		[true, true, true],   # Mouse enabled: position updates, world tracked
		[false, false, false], # Mouse disabled: no updates, no tracking
	]
) -> void:
	# GIVEN: Mouse input setting configured
	_settings.enable_mouse_input = enable_mouse_input

	# GIVEN: Initial positioner state
	var initial_position := _positioner.global_position
	var initial_has_mouse := _positioner._has_mouse_world
	var initial_mouse_world := _positioner._last_mouse_world if _positioner._has_mouse_world else Vector2.ZERO

	# WHEN: Simulate mouse motion event
	var mouse_screen_pos := Vector2(200, 200)
	var mouse_event := InputEventMouseMotion.new()
	mouse_event.position = mouse_screen_pos

	# Send input event and process frame
	_positioner._input(mouse_event)
	runner.simulate_frames(1)

	# THEN: Verify position updates match expectation
	if should_update_position:
		assert_that(_positioner.global_position).append_failure_message(
				"With enable_mouse_input=%s, position should have changed from %s" % [
					str(enable_mouse_input),
					str(initial_position)
				]
			).is_not_equal(initial_position)
	else:
		assert_vector(_positioner.global_position).append_failure_message(
				"With enable_mouse_input=%s, position should remain at %s but got %s" % [
					str(enable_mouse_input),
					str(initial_position),
					str(_positioner.global_position)
				]
			).is_equal(initial_position)

	# THEN: Verify world position tracking matches expectation
	if should_track_world:
		assert_bool(_positioner._has_mouse_world).append_failure_message(
				"With enable_mouse_input=%s, _has_mouse_world should be true" % str(enable_mouse_input)
			).is_true()

		# World position should have updated to something different
		if initial_has_mouse:
			assert_that(_positioner._last_mouse_world).append_failure_message(
					"With enable_mouse_input=%s, _last_mouse_world should have changed from %s" % [
						str(enable_mouse_input),
						str(initial_mouse_world)
					]
				).is_not_equal(initial_mouse_world)
	else:
		# When mouse is disabled, tracking state should not change
		assert_bool(_positioner._has_mouse_world).append_failure_message(
				"With enable_mouse_input=%s, _has_mouse_world should remain %s but got %s" % [
					str(enable_mouse_input),
					str(initial_has_mouse),
					str(_positioner._has_mouse_world)
				]
			).is_equal(initial_has_mouse)

## Test mouse gate status reflects setting changes
func test_mouse_gate_status_changes_with_setting() -> void:
	# GIVEN: Mouse input enabled initially
	_settings.enable_mouse_input = true
	var gate_enabled := _positioner._mouse_input_gate()
	assert_bool(gate_enabled).append_failure_message("Mouse gate should be open with enable_mouse_input=true").is_true()

	# WHEN: Mouse input disabled
	_settings.enable_mouse_input = false

	# THEN: Gate should be closed
	var gate_disabled := _positioner._mouse_input_gate()
	assert_bool(gate_disabled).append_failure_message("Mouse gate should be closed with enable_mouse_input=false").is_false()

	# WHEN: Re-enabled
	_settings.enable_mouse_input = true

	# THEN: Gate should reopen
	var gate_reenabled := _positioner._mouse_input_gate()
	assert_bool(gate_reenabled).append_failure_message("Mouse gate should reopen with enable_mouse_input=true").is_true()

## Test mouse gate blocks input status world update
func test_mouse_gate_blocks_input_status_world_update() -> void:
	# GIVEN: Mouse input disabled
	_settings.enable_mouse_input = false

	# GIVEN: Clear any existing mouse status
	_positioner._last_mouse_input_status.world = Vector2.ZERO
	_positioner._last_mouse_input_status.allowed = false

	# WHEN: Mouse motion event sent
	var mouse_event := InputEventMouseMotion.new()
	mouse_event.position = Vector2(300, 300)
	_positioner._input(mouse_event)
	runner.simulate_frames(1)

	# THEN: Input status world should NOT be updated (should remain Vector2.ZERO)
	assert_vector(_positioner._last_mouse_input_status.world).append_failure_message(
			"With enable_mouse_input=false, _last_mouse_input_status.world should remain unset, got %s" %
			str(_positioner._last_mouse_input_status.world)
		).is_equal(Vector2.ZERO)

	# THEN: Input status should correctly reflect blocked state
	assert_bool(_positioner._last_mouse_input_status.allowed).append_failure_message(
			"With enable_mouse_input=false, _last_mouse_input_status.allowed should be false"
		).is_false()

## Test mouse gate allows input status world update when enabled
func test_mouse_gate_allows_input_status_world_update_when_enabled() -> void:
	# GIVEN: Mouse input enabled
	_settings.enable_mouse_input = true

	# GIVEN: Clear any existing mouse status
	_positioner._last_mouse_input_status.world = Vector2.ZERO
	_positioner._last_mouse_input_status.allowed = false

	# WHEN: Mouse motion event sent
	var mouse_event := InputEventMouseMotion.new()
	mouse_event.position = Vector2(300, 300)
	_positioner._input(mouse_event)
	runner.simulate_frames(1)

	# THEN: Input status world SHOULD be updated to non-zero
	assert_that(_positioner._last_mouse_input_status.world).append_failure_message(
			"With enable_mouse_input=true, _last_mouse_input_status.world should be updated from zero"
		).is_not_equal(Vector2.ZERO)

	# THEN: Input status should correctly reflect allowed state
	assert_bool(_positioner._last_mouse_input_status.allowed).append_failure_message(
			"With enable_mouse_input=true, _last_mouse_input_status.allowed should be true"
		).is_true()

## Test multiple mouse events with gate toggling
func test_mouse_events_respect_gate_across_toggle() -> void:
	# GIVEN: Mouse enabled, send first event
	_settings.enable_mouse_input = true
	var event1 := InputEventMouseMotion.new()
	event1.position = Vector2(100, 100)
	_positioner._input(event1)
	runner.simulate_frames(1)
	var position_after_first := _positioner.global_position

	assert_that(position_after_first).append_failure_message("First mouse event should have moved positioner").is_not_equal(Vector2(8, 8))

	# WHEN: Disable mouse and send second event
	_settings.enable_mouse_input = false
	var event2 := InputEventMouseMotion.new()
	event2.position = Vector2(400, 400)
	_positioner._input(event2)
	runner.simulate_frames(1)
	var position_after_second := _positioner.global_position

	# THEN: Position should NOT change from first event
	assert_vector(position_after_second).append_failure_message(
			"With gate closed, position should remain %s but got %s" % [
				str(position_after_first),
				str(position_after_second)
			]
		).is_equal(position_after_first)

	# WHEN: Re-enable mouse and send third event
	_settings.enable_mouse_input = true
	var event3 := InputEventMouseMotion.new()
	event3.position = Vector2(200, 200)
	_positioner._input(event3)
	runner.simulate_frames(1)
	var position_after_third := _positioner.global_position

	# THEN: Position SHOULD change (gate reopened)
	assert_that(position_after_third).append_failure_message(
			"With gate reopened, position should change from %s" % str(position_after_second)
		).is_not_equal(position_after_second)
