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
	assert_object(env)
  .append_failure_message("Failed to load CollisionTestEnvironment scene").is_not_null()

	targeter = env.targeter
	assert_object(targeter)
  .append_failure_message("CollisionTestEnvironment should have targeter").is_not_null()

	# Clear any residual targeting state from previous tests
	var gts: GridTargetingState = env.get_container().get_states().targeting
	if gts:
		gts.clear()

func after_test() -> void:
	# Clear targeting state before runner cleanup
	if env and is_instance_valid(env):
		var gts: GridTargetingState = env.get_container().get_states().targeting
		if gts:
			gts.clear()

	# Let scene runner handle cleanup
	runner = null
	env = null
	targeter = null

func test_env_injection_wires_targeting_state() -> void:
	# Acquire targeting state from environment container
	var gts: GridTargetingState = env.get_container().get_states().targeting
	assert_object(gts)
  .append_failure_message("GridTargetingState should be available from container").is_not_null()

	# Ensure manual targeting is not active initially
	gts.is_manual_targeting_active = false

	# Verify initial state is clean
	assert_object(gts.get_target()).append_failure_message(
		"Initial target should be null before test begins"
	).is_null()

	# Create a test collision body to use as a target
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	collision_shape.shape = shape
	collision_body.add_child(collision_shape)
	collision_body.collision_layer = 1
	collision_body.global_position = Vector2(100, 100)
	env.objects_parent.add_child(collision_body)

	# Test manual targeting mode - set target directly
	gts.is_manual_targeting_active = true
	gts.set_manual_target(collision_body)

	# Verify manual targeting works
	assert_object(gts.get_target()).append_failure_message(
		"Manual targeting should set target to collision_body"
	).is_same(collision_body)

	# Test clearing target
	gts.clear()

	assert_object(gts.get_target()).append_failure_message(
		"Target should be null after being cleared"
	).is_null()

	# Test that automatic targeting is blocked when manual mode is active
	gts.is_manual_targeting_active = true
	targeter.global_position = collision_body.global_position  # Position over body
	runner.simulate_frames(3)

	# Target should remain null because manual mode blocks automatic updates
	assert_object(gts.get_target()).append_failure_message(
		"Target should remain null when manual targeting is active (blocks automatic updates)"
	).is_null()

	# Re-enable automatic targeting
	gts.is_manual_targeting_active = false
