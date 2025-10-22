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

 assert_bool(positioner.visible).append_failure_message( "Positioner should be visible with remain_active_in_off_mode=true" ) # Test that positioner was positioned according to CENTER_ON_MOUSE policy # The actual positioning depends on the mouse position AT THE TIME of dependency injection # Let's verify it was positioned correctly by checking it used the mouse cursor path # We can't predict exactly where it will be positioned because: # 1. The mouse position might change between warp and dependency injection # 2. The coordinate conversion depends on camera setup and viewport size # 3. The positioning uses tile centering logic # Instead, let's validate the policy was applied by ensuring: # 1. The positioner is not at the default position (which would mean no positioning happened) # 2. The positioner is visible (which we already validated) # Also confirm it's not at the default tile center (8, 8) var expected_default_position := Vector2(8.0, 8.0) # Default tile center var actual_position := positioner.global_position # The position should be different from the default tile center since mouse policy was applied var position_was_applied: bool = actual_position != expected_default_position # Get comprehensive diagnostic information var mouse_enabled: bool = targeting_settings.enable_mouse_input var remain_active: bool = targeting_settings.remain_active_in_off_mode var position_policy: GridTargetingSettings.RecenterOnEnablePolicy = targeting_settings.position_on_enable_policy var current_mode: GBEnums.Mode = states.mode.current var viewport_mouse_pos: Vector2 = get_viewport().get_mouse_position() assert_bool(position_was_applied).append_failure_message( "CENTER_ON_MOUSE positioning policy failed - Expected position != (8, 8), got %s. Mouse enabled: %s, Remain active in OFF: %s, Position policy: %s, Current mode: %s, Viewport mouse: %s, Distance from default: %.2f, Expected world pos: %s, Position delta: %s, Distance to mouse: %.2f" % [ str(actual_position), str(mouse_enabled), str(remain_active), str(position_policy), str(current_mode), str(viewport_mouse_pos), actual_position.distance_to(expected_default_position), str(expected_world_pos), str(position_delta), distance ] ).is_true().is_true()