## Simple test to verify remain_active_in_off_mode visibility behavior
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: CollisionTestEnvironment

func before_test() -> void:
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV)
	env = runner.scene() as CollisionTestEnvironment

func test_remain_active_in_off_mode_visibility() -> void:
	# Get the container and its states/settings
	var container: GBCompositionContainer = env.get_container()
	assert_that(container).is_not_null().append_failure_message("Container should be available")

	var states: GBStates = container.get_states()
	assert_that(states).is_not_null().append_failure_message("States should be available")

	var settings: GridTargetingSettings = container.config.settings.targeting
	assert_that(settings).is_not_null().append_failure_message("Targeting settings should be available")

	# Set remain_active_in_off_mode to true
	settings.remain_active_in_off_mode = true

	# Set mode to OFF
	states.mode.current = GBEnums.Mode.OFF

	# Get the positioner
	var positioner: GridPositioner2D = env.positioner
	assert_that(positioner).is_not_null().append_failure_message("Positioner should be available")

	# Test that positioner should be visible in OFF mode when remain_active_in_off_mode is true
	var should_be_visible: bool = positioner.should_be_visible()
	assert_bool(should_be_visible).append_failure_message(
		"Expected positioner to be visible with remain_active_in_off_mode=true in OFF mode | " +
		"Mode: %s, remain_active_in_off_mode: %s, should_be_visible: %s" %
		[str(states.mode.current), str(settings.remain_active_in_off_mode), str(should_be_visible)]
	).is_true()