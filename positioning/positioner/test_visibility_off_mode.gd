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
	assert_bool(should_be_visible).append_failure_message( "Expected positioner to be visible with remain_active_in_off_mode=true in OFF mode | " + "Mode: %s, remain_active_in_off_mode: %s, should_be_visible: %s" % [ str(states.mode.current), str(settings.remain_active_in_off_mode), str(should_be_visible) ] ).is_true()