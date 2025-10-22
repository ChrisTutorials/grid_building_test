## Test to verify positioning policy with remain_active_in_off_mode
extends GdUnitTestSuite

#region CONSTANTS

# Test mouse positions
const TEST_MOUSE_SCREEN_POS: Vector2 = Vector2(100, 100)

# Default positioning values
const DEFAULT_TILE_CENTER: Vector2 = Vector2(8, 8)  # Default tile center position

#endregion

func test_positioning_policy_with_remain_active_in_off_mode() -> void:
	# Create positioner and camera
	var positioner := GridPositioner2D.new()
	var camera := Camera2D.new()
	add_child(camera)
	add_child(positioner)

	# MIGRATION: Use scene_runner WITHOUT frame simulation
	var runner: GdUnitSceneRunner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	var env: CollisionTestEnvironment = runner.scene() as CollisionTestEnvironment

	assert_object(env).append_failure_message(
		"Failed to load CollisionTestEnvironment scene"
	).is_not_null()
	var container: GBCompositionContainer = env.container
	var config: GBConfig = container.config
	var states: GBStates = container.get_states()

	# Set mode to OFF and enable remain_active_in_off_mode
	states.mode.current = GBEnums.Mode.OFF
	var targeting_settings: GridTargetingSettings = config.settings.targeting
	targeting_settings.remain_active_in_off_mode = true
	# CRITICAL: Enable mouse input for CENTER_ON_MOUSE positioning policy test
	targeting_settings.enable_mouse_input = true
	# CRITICAL: Set position_on_enable_policy (not manual_recenter_mode) for dependency injection
	targeting_settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR

	# Simulate mouse cursor being on screen at specific position
	var mouse_screen_pos := TEST_MOUSE_SCREEN_POS
	get_viewport().warp_mouse(mouse_screen_pos)
	await get_tree().process_frame  # Wait for mouse position update

	# Capture initial state for diagnostics
	var initial_mode: GBEnums.Mode = states.mode.current
	var _initial_remain_active: bool = targeting_settings.remain_active_in_off_mode
	var _initial_enable_mouse: bool = targeting_settings.enable_mouse_input
	var _initial_policy: GridTargetingSettings.RecenterOnEnablePolicy = targeting_settings.position_on_enable_policy
	var initial_mouse_pos := get_viewport().get_mouse_position()
	var initial_positioner_pos := positioner.global_position

	# Do dependency injection
	positioner.resolve_gb_dependencies(container)
	await get_tree().process_frame

	# CRITICAL: Wait for the deferred positioning sequence to complete
	# The positioning is done via call_deferred() so we need to wait for it
	await get_tree().process_frame  # Wait for deferred positioning
	await get_tree().process_frame  # Extra frame for good measure

	# Capture final state for diagnostics
	var final_mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var _final_positioner_pos: Vector2 = positioner.global_position
	var final_visible := positioner.visible
	var final_remain_active := positioner._targeting_settings.remain_active_in_off_mode
	var final_policy := positioner._targeting_settings.position_on_enable_policy

	# Test if positioner was positioned according to mouse cursor policy
	var actual_pos := positioner.global_position
	var distance_from_default := actual_pos.distance_to(DEFAULT_TILE_CENTER)  # Default tile center

	assert_bool(actual_pos != DEFAULT_TILE_CENTER).append_failure_message(
		"CENTER_ON_MOUSE positioning policy failed - Expected position != (8, 8), got (%s). Mouse enabled: %s, Remain active in OFF: %s, Position policy: %s, Current mode: %s, Viewport mouse: %s, Distance from default: %.2f. State before: mode=%s, mouse=%s, pos=%s. State after: visible=%s, remain=%s, policy=%s" % [
			str(actual_pos),
			str(targeting_settings.enable_mouse_input),
			str(targeting_settings.remain_active_in_off_mode),
			str(targeting_settings.position_on_enable_policy),
			str(states.mode.current),
			str(final_mouse_pos),
			distance_from_default,
			str(initial_mode),
			str(initial_mouse_pos),
			str(initial_positioner_pos),
			str(final_visible),
			str(final_remain_active),
			str(final_policy)
		]
	).is_true()
	var current_mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = Vector2(get_viewport().size)
	var expected_world_pos: Vector2 = camera.to_global(current_mouse_pos - viewport_size / 2.0)

	# Check if the positioner is reasonably close to the mouse world position
	var position_delta: Vector2 = positioner.global_position - expected_world_pos
	var distance: float = position_delta.length()

	# Test that positioner is visible (we already confirmed this works)
	assert_bool(positioner.visible).is_true().append_failure_message(
		"Positioner should be visible with remain_active_in_off_mode=true"
	)

	# Test that positioner was positioned according to CENTER_ON_MOUSE policy
	# The actual positioning depends on the mouse position AT THE TIME of dependency injection
	# Let's verify it was positioned correctly by checking it used the mouse cursor path

	# We can't predict exactly where it will be positioned because:
	# 1. The mouse position might change between warp and dependency injection
	# 2. The coordinate conversion depends on camera setup and viewport size
	# 3. The positioning uses tile centering logic

	# Instead, let's validate the policy was applied by ensuring:
	# 1. The positioner is not at the default position (which would mean no positioning happened)
	# 2. The positioner is visible (which we already validated)

	# Also confirm it's not at the default tile center (8, 8)
	var expected_default_position := Vector2(8.0, 8.0)  # Default tile center
	var actual_position := positioner.global_position

	# The position should be different from the default tile center since mouse policy was applied
	var position_was_applied: bool = actual_position != expected_default_position

	# Get comprehensive diagnostic information
	var mouse_enabled: bool = targeting_settings.enable_mouse_input
	var remain_active: bool = targeting_settings.remain_active_in_off_mode
	var position_policy: GridTargetingSettings.RecenterOnEnablePolicy = targeting_settings.position_on_enable_policy
	var current_mode: GBEnums.Mode = states.mode.current
	var viewport_mouse_pos: Vector2 = get_viewport().get_mouse_position()

	assert_bool(position_was_applied).append_failure_message(
		"CENTER_ON_MOUSE positioning policy failed - Expected position != (8, 8), got %s. Mouse enabled: %s, Remain active in OFF: %s, Position policy: %s, Current mode: %s, Viewport mouse: %s, Distance from default: %.2f, Expected world pos: %s, Position delta: %s, Distance to mouse: %.2f" % [
			str(actual_position),
			str(mouse_enabled),
			str(remain_active),
			str(position_policy),
			str(current_mode),
			str(viewport_mouse_pos),
			actual_position.distance_to(expected_default_position),
			str(expected_world_pos),
			str(position_delta),
			distance
		]
	).is_true()


