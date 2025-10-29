## Regression test for manipulation move collision exclusion bug.
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
##
## BUG: When moving an object, collision exclusions work correctly ONLY when
## the grid positioner (targeting ShapeCast2D) is inside the original object's bounds.
## When the positioner moves outside the original object's bounds, the exclusion
## fails and indicators incorrectly detect collision with the original object.
##
## EXPECTED: Exclusions should work regardless of positioner position - the original
## object should ALWAYS be excluded from collision detection during move operations.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _env: CollisionTestEnvironment
var _rule: CollisionsCheckRule

func before_test() -> void:
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	_env = runner.scene() as CollisionTestEnvironment

	assert_object(_env).append_failure_message(
		"Failed to load CollisionTestEnvironment scene"
	).is_not_null()

	_rule = CollisionsCheckRule.new()
	_rule.pass_on_collision = false
	_rule.collision_mask = 1
	var setup_issues := _rule.setup(_env.targeting_state)
 assert_array(setup_issues).append_failure_message("Collision rule setup should complete without issues").is_empty()

func after_test() -> void:
	# Clear collision exclusions to prevent test isolation issues
	if _env and _env.targeting_state:
		_env.targeting_state.collision_exclusions = []
	_rule = null

## Helper to create a large collision body (simulating Smithy building)
func _create_large_body(p_name: String, p_position: Vector2, p_size: Vector2 = Vector2(64, 64)) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = p_name
	body.position = p_position
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape"
	var rect := RectangleShape2D.new()
	rect.size = p_size
	shape.shape = rect
	body.add_child(shape)

	_env.add_child(body)
	return body

## Helper to create an indicator
func _create_indicator(p_position: Vector2) -> RuleCheckIndicator:
	var indicator := RuleCheckIndicator.new()
	indicator.position = p_position
	indicator.target_position = Vector2.ZERO

	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	indicator.shape = rect_shape

	indicator.collision_mask = 1
	_env.add_child(indicator)

	return indicator

func test_exclusion_works_when_positioner_inside_original_bounds() -> void:
	# GIVEN: Large body (64x64 simulating Smithy)
	var original_body := _create_large_body("OriginalSmithy", Vector2(100, 100), Vector2(64, 64))

	# GIVEN: Indicator INSIDE the original body's bounds
	var indicator := _create_indicator(Vector2(100, 100))  # Center of body
	indicator.add_rule(_rule)

	# GIVEN: Body is excluded (simulating manipulation move)
	_env.targeting_state.collision_exclusions = [original_body]

	await get_tree().physics_frame
	await get_tree().physics_frame

	# THEN: Indicator should be valid (exclusion works)
 assert_bool(indicator.valid).append_failure_message("Indicator should be valid when collision body is excluded").is_true()

func test_exclusion_fails_when_positioner_outside_original_bounds() -> void:
	# GIVEN: Large body (64x64 simulating Smithy) at (100, 100)
	# Body bounds: x=[68, 132], y=[68, 132]
	var original_body := _create_large_body("OriginalSmithy", Vector2(100, 100), Vector2(64, 64))

	# GIVEN: Indicator OUTSIDE the original body's bounds
	var indicator := _create_indicator(Vector2(150, 100))  # x=150 > 132 (outside)
	indicator.add_rule(_rule)

	# GIVEN: Body is excluded (simulating manipulation move)
	_env.targeting_state.collision_exclusions = [original_body]

	await get_tree().physics_frame
	await get_tree().physics_frame

	# THEN: Indicator should be valid (exclusion should work)
	# BUG: This currently FAILS - indicator.valid = false
 assert_bool(indicator.valid).append_failure_message("Indicator should be valid when positioned outside original bounds with exclusion")\
	.is_true()

func test_exclusion_works_at_edge_of_original_bounds() -> void:
	# GIVEN: Large body at (100, 100), size 64x64
	var original_body := _create_large_body("OriginalSmithy", Vector2(100, 100), Vector2(64, 64))

	# GIVEN: Indicator at edge of bounds (x=132, right edge)
	var indicator := _create_indicator(Vector2(132, 100))
	indicator.add_rule(_rule)

	# GIVEN: Body is excluded
	_env.targeting_state.collision_exclusions = [original_body]

	await get_tree().physics_frame
	await get_tree().physics_frame

	# THEN: Indicator should be valid
 assert_bool(indicator.valid).append_failure_message("Indicator at edge of original bounds should be valid when body is excluded")\
	.is_true()

func test_multiple_indicators_outside_bounds_all_excluded() -> void:
	# GIVEN: Large body
	var original_body := _create_large_body("OriginalSmithy", Vector2(100, 100), Vector2(64, 64))

	# GIVEN: Multiple indicators outside bounds in different directions
	var indicator_right := _create_indicator(Vector2(150, 100))  # Right of body
	var indicator_left := _create_indicator(Vector2(50, 100))    # Left of body
	var indicator_top := _create_indicator(Vector2(100, 50))     # Above body
	var indicator_bottom := _create_indicator(Vector2(100, 150)) # Below body

	indicator_right.add_rule(_rule)
	indicator_left.add_rule(_rule)
	indicator_top.add_rule(_rule)
	indicator_bottom.add_rule(_rule)

	# GIVEN: Body is excluded
	_env.targeting_state.collision_exclusions = [original_body]

	await get_tree().physics_frame
	await get_tree().physics_frame

	# THEN: All indicators should be valid regardless of position
 assert_bool(indicator_right.valid).append_failure_message("Right indicator should be valid when body is excluded").is_true()
 assert_bool(indicator_left.valid).append_failure_message("Left indicator should be valid when body is excluded").is_true()
 assert_bool(indicator_top.valid).append_failure_message("Top indicator should be valid when body is excluded").is_true()
 assert_bool(indicator_bottom.valid).append_failure_message("Bottom indicator should be valid when body is excluded").is_true()

func test_exclusion_independent_of_positioner_movement() -> void:
	# GIVEN: Large body
	var original_body := _create_large_body("OriginalSmithy", Vector2(100, 100), Vector2(64, 64))

	# GIVEN: Indicator that starts inside, moves outside
	var indicator := _create_indicator(Vector2(100, 100))  # Inside
	indicator.add_rule(_rule)

	# GIVEN: Body is excluded
	_env.targeting_state.collision_exclusions = [original_body]

	await get_tree().physics_frame
	var valid_inside := indicator.valid

	# WHEN: Indicator moves outside bounds
	indicator.position = Vector2(150, 100)
	indicator.force_shapecast_update()

	await get_tree().physics_frame
	var valid_outside := indicator.valid

	# THEN: Exclusion should work in both positions
 assert_bool(valid_inside).append_failure_message("Indicator should be valid inside bounds when body is excluded").is_true()
 assert_bool(valid_outside).append_failure_message("Indicator should remain valid outside bounds when body is excluded")\
	.is_true()
