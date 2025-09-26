extends GdUnitTestSuite

## Test within the collision test environment for GridTargetingState wiring
var env : CollisionTestEnvironment

## The TargetingShapeCast2D under test
var targeter : TargetingShapeCast2D

func before_test() -> void:
	# Use a prebuilt collision test environment; injector auto-wires components on add_child
	env = EnvironmentTestFactory.create_collision_test_environment(self)
	assert_object(env).append_failure_message("Failed to create CollisionTestEnvironment via EnvironmentTestFactory").is_not_null()
	targeter = env.targeter

func test_env_injection_wires_targeting_state() -> void:
	# Acquire targeting state from environment container
	var gts: GridTargetingState = env.get_container().get_states().targeting
	# Set a dummy target and ensure update_target clears it when not colliding
	var dummy_target := Node2D.new()
	env.objects_parent.add_child(dummy_target)
	auto_free(dummy_target)
	gts.target = dummy_target
	targeter.update_target()
	assert_object(gts.target).append_failure_message("TargetingShapeCast2D should clear target when not colliding after injector-based wiring").is_null()
