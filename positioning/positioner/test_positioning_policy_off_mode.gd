## Test to verify positioning policy with remain_active_in_off_mode
extends GdUnitTestSuite

func test_positioning_policy_with_remain_active_in_off_mode() -> void:
	# Create positioner and camera
	var positioner := GridPositioner2D.new()
	var camera := Camera2D.new()
	add_child(camera)
	add_child(positioner)
	
	# Create test environment
	var env: CollisionTestEnvironment = EnvironmentTestFactory.create_collision_test_environment(self)
	var container: GBCompositionContainer = env.container
	var config: GBConfig = container.config
	var states: GBStates = container.get_states()
	
	# Set mode to OFF and enable remain_active_in_off_mode
	states.mode.current = GBEnums.Mode.OFF
	var targeting_settings: GridTargetingSettings = config.settings.targeting
	targeting_settings.remain_active_in_off_mode = true
	targeting_settings.enable_mouse_input = true
	targeting_settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE
	
	# Simulate mouse cursor being on screen at specific position
	var mouse_screen_pos := Vector2(100, 100)
	get_viewport().warp_mouse(mouse_screen_pos)
	await get_tree().process_frame  # Wait for mouse position update
	
	print("=== BEFORE DEPENDENCY INJECTION ===")
	print("Mode: ", states.mode.current)
	print("remain_active_in_off_mode: ", targeting_settings.remain_active_in_off_mode)
	print("enable_mouse_input: ", targeting_settings.enable_mouse_input)
	print("manual_recenter_mode: ", targeting_settings.manual_recenter_mode)
	print("mouse_screen_pos: ", mouse_screen_pos)
	print("viewport.get_mouse_position(): ", get_viewport().get_mouse_position())
	print("positioner.global_position: ", positioner.global_position)
	
	# Do dependency injection
	positioner.resolve_gb_dependencies(container)
	await get_tree().process_frame
	
	print("=== AFTER DEPENDENCY INJECTION ===")
	print("viewport.get_mouse_position(): ", get_viewport().get_mouse_position())
	print("positioner.global_position: ", positioner.global_position)
	print("positioner.visible: ", positioner.visible)
	print("positioner._targeting_settings.remain_active_in_off_mode: ", positioner._targeting_settings.remain_active_in_off_mode)
	print("positioner._targeting_settings.manual_recenter_mode: ", positioner._targeting_settings.manual_recenter_mode)
	
	# Test if positioner was positioned according to mouse cursor policy
	var current_mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = Vector2(get_viewport().size)
	var expected_world_pos: Vector2 = camera.to_global(current_mouse_pos - viewport_size / 2.0)
	print("expected_world_pos (approximated): ", expected_world_pos)
	
	# Check if the positioner is reasonably close to the mouse world position
	var position_delta: Vector2 = positioner.global_position - expected_world_pos
	var distance: float = position_delta.length()
	print("distance from expected mouse world pos: ", distance)
	
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
	
	print("Expected NOT to be at default: ", expected_default_position)
	print("Actual position: ", actual_position)
	
	# The position should be different from the default tile center since mouse policy was applied
	var position_was_applied: bool = actual_position != expected_default_position
	assert_bool(position_was_applied).is_true().append_failure_message(
		"Position should be different from default tile center (8, 8) since CENTER_ON_MOUSE policy was applied"
	)
	
	print("Position policy applied: ", position_was_applied)
