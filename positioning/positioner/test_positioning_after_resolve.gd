## Test to verify that GridPositioner2D moves after resolve_gb_dependencies is called
extends GdUnitTestSuite

var positioner: GridPositioner2D

func after_test() -> void:
	if positioner:
		positioner.queue_free()

## Test: positioner moves after resolve_gb_dependencies is called
## Setup: positioner at origin with valid dependencies
## Act: call resolve_gb_dependencies
## Assert: positioner position changes from origin
func test_positioner_moves_after_resolve_dependencies() -> void:
	# Create positioner and add to scene
	positioner = GridPositioner2D.new()
	add_child(positioner)
	
	# Hide positioner until proper injection
	positioner.visible = false
	
	# Set initial position at origin
	positioner.global_position = Vector2.ZERO
	var initial_position := positioner.global_position
	
	# Create test environment with proper setup
	var env: CollisionTestEnvironment = EnvironmentTestFactory.create_collision_test_environment(self)
	
	# Add camera and ensure it's ready before dependency injection
	var camera := Camera2D.new()
	add_child(camera)
	camera.make_current()
	await get_tree().process_frame  # Let camera become current
	
	# Get container with proper config
	var container: GBCompositionContainer = env.container
	var config: GBConfig = container.config
	var states: GBStates = container.get_states()
	
	# Setup targeting state with existing tilemap
	states.targeting.target_map = env.tile_map_layer
	
	# Enable mouse input in settings so recenter logic activates  
	var settings: GridTargetingSettings = config.settings.targeting
	settings.enable_mouse_input = true
	settings.remain_active_in_off_mode = true
	
	await get_tree().process_frame
	
	# Act: resolve dependencies (should trigger positioning)
	positioner.resolve_gb_dependencies(container)
	
	# Now show positioner after proper injection
	positioner.visible = true
	
	await get_tree().process_frame
	
	# Assert: position should have changed from origin
	var final_position := positioner.global_position
	assert_vector(final_position).is_not_equal(initial_position).append_failure_message(
		"Expected positioner to move from origin after resolve_gb_dependencies. Initial: %s, Final: %s" % [str(initial_position), str(final_position)]
	)
	
	# The position should be meaningful (not stay at origin)
	# Note: Exact position depends on camera viewport center and tile mapping
	assert_bool(final_position.length() > 0.1).is_true().append_failure_message(
		"Expected positioner to be positioned away from origin. Actual position: %s" % [str(final_position)]
	)
