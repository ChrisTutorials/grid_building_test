## Test to verify CENTER_ON_MOUSE vs CENTER_ON_SCREEN positioning policies
extends GdUnitTestSuite

func test_center_on_mouse_vs_center_on_screen_policies() -> void:
	# Create camera first - required for coordinate conversion
	var camera := Camera2D.new()
	add_child(camera)
	
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

	# Test 1: CENTER_ON_MOUSE policy
	print("=== TESTING CENTER_ON_MOUSE POLICY ===")
	var positioner_mouse := GridPositioner2D.new()
	add_child(positioner_mouse)
	
	# Warp mouse to specific position before dependency injection
	var mouse_pos := Vector2(150, 150)
	get_viewport().warp_mouse(mouse_pos)
	await get_tree().process_frame
	
	# Set CENTER_ON_MOUSE policy
	targeting_settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE
	print("Mouse position: ", get_viewport().get_mouse_position())
	print("Manual recenter mode: ", targeting_settings.manual_recenter_mode)
	
	# Apply dependencies with CENTER_ON_MOUSE
	positioner_mouse.resolve_gb_dependencies(container)
	await get_tree().process_frame
	
	var mouse_position := positioner_mouse.global_position
	print("CENTER_ON_MOUSE result: ", mouse_position)
	
	# Test 2: CENTER_ON_SCREEN policy for comparison
	print("=== TESTING CENTER_ON_SCREEN POLICY ===")
	var positioner_screen := GridPositioner2D.new() 
	add_child(positioner_screen)
	
	# Set CENTER_ON_SCREEN policy
	targeting_settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_SCREEN
	print("Manual recenter mode: ", targeting_settings.manual_recenter_mode)
	
	# Apply dependencies with CENTER_ON_SCREEN
	positioner_screen.resolve_gb_dependencies(container)
	await get_tree().process_frame
	
	var screen_position := positioner_screen.global_position
	print("CENTER_ON_SCREEN result: ", screen_position)
	
	# Validation: The two policies should produce different positions
	var positions_are_different := mouse_position != screen_position
	print("Positions are different: ", positions_are_different)
	print("Mouse policy position: ", mouse_position)
	print("Screen policy position: ", screen_position)
	
	# Assert that the policies produce different results
	assert_bool(positions_are_different).is_true().append_failure_message(
		"CENTER_ON_MOUSE and CENTER_ON_SCREEN should produce different positions. Mouse: %s, Screen: %s" % 
		[str(mouse_position), str(screen_position)]
	)
	
	# Assert that both positioners are visible
	assert_bool(positioner_mouse.visible).is_true().append_failure_message(
		"Mouse policy positioner should be visible"
	)
	assert_bool(positioner_screen.visible).is_true().append_failure_message(
		"Screen policy positioner should be visible"
	)
	
	# Assert that neither is at the default position (0,0) or uninitialized position
	var default_pos := Vector2(0.0, 0.0)
	assert_bool(mouse_position != default_pos).is_true().append_failure_message(
		"Mouse policy should position away from (0,0)"
	)
	assert_bool(screen_position != default_pos).is_true().append_failure_message(
		"Screen policy should position away from (0,0)"
	)