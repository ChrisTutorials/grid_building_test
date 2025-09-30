## Simple test to verify remain_active_in_off_mode visibility behavior
extends GdUnitTestSuite

func test_visibility_with_remain_active_in_off_mode() -> void:
	# Create minimal test setup
	var positioner := GridPositioner2D.new()
	add_child(positioner)
	
	# Create test environment
	var env: CollisionTestEnvironment = EnvironmentTestFactory.create_collision_test_environment(self)
	var container: GBCompositionContainer = env.container
	var config: GBConfig = container.config
	var states: GBStates = container.get_states()
	
	# Set mode to OFF
	states.mode.current = GBEnums.Mode.OFF
	
	# Enable remain_active_in_off_mode
	var settings: GridTargetingSettings = config.settings.targeting
	settings.remain_active_in_off_mode = true
	
	# Test the visibility logic directly
	var should_be_visible := GridPositionerLogic.should_be_visible(
		states.mode.current, 
		settings, 
		null, # last_mouse_input_status
		false # has_mouse_world
	)
	
	print("Mode: ", states.mode.current)
	print("remain_active_in_off_mode: ", settings.remain_active_in_off_mode)
	print("should_be_visible result: ", should_be_visible)
	
	assert_bool(should_be_visible).is_true().append_failure_message(
		"Expected positioner to be visible with remain_active_in_off_mode=true in OFF mode"
	)