## Test within the collision test environment for GridTargetingState wiring
##
## TESTING PATTERN: Uses GdUnitSceneRunner with CollisionTestEnvironment scene
## for deterministic frame control and reliable physics simulation
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: CollisionTestEnvironment
var targeter: TargetingShapeCast2D

func before_test() -> void:
	# Use scene_runner for reliable frame simulation and automatic cleanup
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames
	
	env = runner.scene() as CollisionTestEnvironment
	assert_object(env).append_failure_message("Failed to load CollisionTestEnvironment scene").is_not_null()
	
	targeter = env.targeter
	assert_object(targeter).append_failure_message("CollisionTestEnvironment should have targeter").is_not_null()
	
	# Clear any residual targeting state from previous tests
	var gts: GridTargetingState = env.get_container().get_states().targeting
	if gts:
		gts.target = null

func after_test() -> void:
	# Clear targeting state before runner cleanup
	if env and is_instance_valid(env):
		var gts: GridTargetingState = env.get_container().get_states().targeting
		if gts:
			gts.target = null
	
	# Let scene runner handle cleanup
	runner = null
	env = null
	targeter = null

func test_env_injection_wires_targeting_state() -> void:
	# Acquire targeting state from environment container
	var gts: GridTargetingState = env.get_container().get_states().targeting
	assert_object(gts).append_failure_message("GridTargetingState should be available from container").is_not_null()
	
	# Verify initial state is clean
	assert_object(gts.target).append_failure_message(
		"Initial target should be null before test begins"
	).is_null()
	
	# Set a dummy target and ensure update_target clears it when not colliding
	var dummy_target: Node2D = auto_free(Node2D.new())
	env.objects_parent.add_child(dummy_target)
	
	# Simulate frames to let scene tree update
	runner.simulate_frames(1)
	
	gts.target = dummy_target
	assert_object(gts.target).append_failure_message(
		"Target should be set to dummy_target after assignment"
	).is_same(dummy_target)
	
	# Update target - should clear because targeter is not colliding with dummy_target
	targeter.update_target()
	
	# Simulate frames to let physics update
	runner.simulate_frames(2)
	
	# Final assertion - target should be cleared
	assert_object(gts.target).append_failure_message(
		"TargetingShapeCast2D should clear target when not colliding after injector-based wiring. " +
		"Target is: %s (expected null)" % str(gts.target)
	).is_null()
