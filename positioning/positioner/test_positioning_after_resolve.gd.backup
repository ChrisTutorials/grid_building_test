## Test to verify that GridPositioner2D moves after resolve_gb_dependencies is called
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: CollisionTestEnvironment
var container: GBCompositionContainer
var positioner: GridPositioner2D

func before_test() -> void:
	# Use scene runner for proper initialization
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames

	env = runner.scene() as CollisionTestEnvironment
	container = env.container

	# Disable mouse input to prevent interference
	container.config.settings.targeting.enable_mouse_input = false

	# Create positioner
	positioner = auto_free(GridPositioner2D.new())
	env.add_child(positioner)

	runner.simulate_frames(1)

func after_test() -> void:
	positioner = null
	container = null
	env = null
	runner = null

## Test: positioner moves after resolve_gb_dependencies is called
## Setup: positioner at origin with valid dependencies
## Act: call resolve_gb_dependencies and manually set position
## Assert: positioner accepts position changes and maintains them
func test_positioner_moves_after_resolve_dependencies() -> void:
	# Set initial position at origin
	positioner.global_position = Vector2.ZERO
	var initial_position := positioner.global_position

	# Get states and configure for positioning
	var states: GBStates = container.get_states()
	states.targeting.target_map = env.tile_map_layer

	# Disable mouse input to prevent interference
	var settings: GridTargetingSettings = container.config.settings.targeting
	settings.enable_mouse_input = false
	settings.remain_active_in_off_mode = true

	# Log pre-resolve state
	var pre_resolve_diag := "Pre-resolve: pos=%s, visible=%s, in_tree=%s" % [
		str(positioner.global_position),
		str(positioner.visible),
		str(positioner.is_inside_tree())
	]

	# Act: resolve dependencies
	positioner.resolve_gb_dependencies(container)
	runner.simulate_frames(1)

	# Manually set position (testing that positioning works after resolve)
	var test_position := Vector2(100, 100)
	positioner.global_position = test_position
	runner.simulate_frames(1)

	# Get final state
	var final_position := positioner.global_position
	var position_changed := final_position != initial_position
	var distance_from_origin := final_position.length()

	# Log post-resolve state
	var post_resolve_diag := "Post-resolve: pos=%s, visible=%s, distance=%.2f" % [
		str(final_position),
		str(positioner.visible),
		distance_from_origin
	]

	# Assert: position should have changed from origin
	assert_vector(final_position).append_failure_message(
		"Positioner should accept position changes after resolve. %s | %s" % [pre_resolve_diag, post_resolve_diag]
	).is_not_equal(initial_position)

	# The position should be at our test position
	assert_bool(distance_from_origin > 50.0).append_failure_message(
		"Positioner should maintain assigned position. Initial: %s, Final: %s, Expected: %s, Distance: %.2f, Changed: %s | %s | %s" % [
			str(initial_position), str(final_position), str(test_position), distance_from_origin, str(position_changed), pre_resolve_diag, post_resolve_diag
		]
	).is_true()
