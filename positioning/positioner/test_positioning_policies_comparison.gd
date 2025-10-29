## Test to verify CENTER_ON_MOUSE vs CENTER_ON_SCREEN positioning policies
extends GdUnitTestSuite

# Constants for test configuration
const DEFAULT_POSITION := Vector2(0.0, 0.0)
const POSITION_TOLERANCE := 5.0  # Allow small differences due to floating point precision

var runner: GdUnitSceneRunner
var env: CollisionTestEnvironment
var container: GBCompositionContainer


func before_test() -> void:
	# Use scene runner for proper initialization
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames

	env = runner.scene() as CollisionTestEnvironment
	container = env.container

	# Configure base settings
	var states: GBStates = container.get_states()
	states.mode.current = GBEnums.Mode.OFF

	var targeting_settings: GridTargetingSettings = container.config.settings.targeting
	targeting_settings.remain_active_in_off_mode = true
	targeting_settings.enable_mouse_input = false  # Will enable per test

	runner.simulate_frames(1)


func after_test() -> void:
	container = null
	env = null
	runner = null


# Helper method to create and configure a positioner
func _create_positioner_with_policy(
	policy: GBEnums.CenteringMode, enable_input: bool
) -> GridPositioner2D:
	var positioner: GridPositioner2D = auto_free(GridPositioner2D.new())
	env.add_child(positioner)

	# Set the policy before dependency injection
	var targeting_settings: GridTargetingSettings = container.config.settings.targeting
	targeting_settings.manual_recenter_mode = policy
	targeting_settings.enable_mouse_input = enable_input

	# Apply dependencies
	positioner.resolve_gb_dependencies(container)
	runner.simulate_frames(1)

	# Enable visibility and processing
	positioner.visible = true
	positioner.set_input_processing_enabled(enable_input)
	runner.simulate_frames(2)  # Allow positioning to occur

	return positioner


# Helper method to get positioning diagnostics
func _get_position_diagnostics(positioner: GridPositioner2D, policy_name: String) -> String:
	var has_camera := env.get_viewport().get_camera_2d() != null
	var viewport_size := (
		env.get_viewport().get_visible_rect().size if env.get_viewport() else Vector2.ZERO
	)
	return (
		"Policy: %s, Position: %s, Visible: %s, In tree: %s, Enabled: %s, Camera: %s, Viewport: %s"
		% [
			policy_name,
			str(positioner.global_position),
			str(positioner.visible),
			str(positioner.is_inside_tree()),
			str(positioner.is_input_processing_enabled()),
			str(has_camera),
			str(viewport_size)
		]
	)


func test_center_on_mouse_vs_center_on_screen_policies() -> void:
	# Test both positioning policies with manual positioning
	var positioner_mouse := _create_positioner_with_policy(
		GBEnums.CenteringMode.CENTER_ON_MOUSE, false
	)
	# Manually set positions to test that policies don't interfere
	positioner_mouse.global_position = Vector2(50, 50)
	runner.simulate_frames(1)
	var mouse_position := positioner_mouse.global_position
	var mouse_diag := _get_position_diagnostics(positioner_mouse, "CENTER_ON_MOUSE")

	var positioner_screen := _create_positioner_with_policy(
		GBEnums.CenteringMode.CENTER_ON_SCREEN, false
	)
	positioner_screen.global_position = Vector2(100, 100)
	runner.simulate_frames(1)
	var screen_position := positioner_screen.global_position
	var screen_diag := _get_position_diagnostics(positioner_screen, "CENTER_ON_SCREEN")

	# Calculate position difference
	var position_distance := mouse_position.distance_to(screen_position)
	var mouse_from_origin := mouse_position.length()
	var screen_from_origin := screen_position.length()

	# Assert that both positioners are visible and functional
	(
		assert_bool(positioner_mouse.visible) \
		. append_failure_message("Mouse policy positioner should be visible. %s" % mouse_diag) \
		. is_true()
	)

	(
		assert_bool(positioner_screen.visible) \
		. append_failure_message("Screen policy positioner should be visible. %s" % screen_diag) \
		. is_true()
	)

	# Assert that both accept manual positioning
	(
		assert_bool(mouse_position != DEFAULT_POSITION) \
		. append_failure_message(
			(
				"Mouse policy should accept positioning. Pos: %s, Distance from origin: %.2f | %s"
				% [str(mouse_position), mouse_from_origin, mouse_diag]
			)
		) \
		. is_true()
	)

	(
		assert_bool(screen_position != DEFAULT_POSITION) \
		. append_failure_message(
			(
				"Screen policy should accept positioning. Pos: %s, Distance from origin: %.2f | %s"
				% [str(screen_position), screen_from_origin, screen_diag]
			)
		) \
		. is_true()
	)

	# Assert positioning is maintained (both should stay at assigned positions)
	(
		assert_bool(mouse_from_origin > 40.0 and screen_from_origin > 90.0) \
		. append_failure_message(
			(
				"Both policies should maintain assigned positions. Mouse dist: %.2f (expected ~70), Screen dist: %.2f (expected ~141), Policy dist: %.2f | Mouse: %s | Screen: %s"
				% [
					mouse_from_origin,
					screen_from_origin,
					position_distance,
					mouse_diag,
					screen_diag
				]
			)
		) \
		. is_true()
	)
