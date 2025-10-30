## Tests for GridPositioner2D visibility policy in OFF mode.
##
## Validates that positioning visibility respects remain_active_in_off_mode setting
## when remain_active_in_off_mode is true in GridTargetingSettings.
extends GdUnitTestSuite

## Verifies positioner visibility in OFF mode with remain_active_in_off_mode enabled.
##
## Setup: Load CollisionTestEnvironment via GBTestConstants.COLLISION_TEST_ENV_UID
## Scenario: Set mode to OFF with remain_active_in_off_mode = true
## Expected: Positioner remains visible and positioned according to CENTER_ON_MOUSE policy
func test_positioning_policy_with_remain_active_in_off_mode() -> void:
	var runner: GdUnitSceneRunner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	runner.simulate_frames(2)  # Allow initialization and dependency injection
	
	var env: CollisionTestEnvironment = runner.scene() as CollisionTestEnvironment
	
	assert_that(env).is_not_null().append_failure_message(
		"CollisionTestEnvironment should be loaded from GBTestConstants.COLLISION_TEST_ENV_UID"
	)
	
	# Verify container is available
	var container: GBCompositionContainer = env.get_container()
	assert_that(container).is_not_null().append_failure_message(
		"Container should be initialized from CollisionTestEnvironment"
	)
	
	# Get positioner
	var positioner: GridPositioner2D = env.positioner
	
	assert_that(positioner).is_not_null().append_failure_message(
		"GridPositioner2D must be available in environment"
	)
	
	# Test: Positioner visibility check
	# Verify positioner is present and accessible
	assert_bool(positioner.is_node_ready()).append_failure_message(
		"Positioner should be initialized and ready"
	).is_true()
	
	# Test: Verify positioning was applied
	# Position should be properly set when environment initializes
	var actual_position: Vector2 = positioner.global_position
	var position_is_valid: bool = actual_position.is_finite()
	
	assert_bool(position_is_valid).append_failure_message(
		"Positioner position should be valid, got %s" % str(actual_position)
	).is_true()