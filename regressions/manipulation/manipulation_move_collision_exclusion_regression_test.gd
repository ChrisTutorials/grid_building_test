## Regression test for collision exclusion bug during manipulation move.
##
## BUG: When moving an object, collision indicators incorrectly show collision
## with the original object ONLY when the grid positioner (targeting ShapeCast2D)
## moves outside the bounds of the original object's collision area.
##
## EXPECTED: Indicators should ALWAYS ignore the original object during move,
## regardless of where the grid positioner is located.
##
## Test Scenario:
## 1. Start moving an object (e.g., Smithy)
## 2. Move preview so grid positioner is INSIDE original bounds -> indicators GREEN ✅
## 3. Move preview so grid positioner is OUTSIDE original bounds -> indicators RED ❌ BUG!
extends GdUnitTestSuite

const ManipulationHelpers := preload("uid://ba4o2x6ctbwr")

var _runner: GdUnitSceneRunner
var _env: AllSystemsTestEnvironment
var _manipulation_system: ManipulationSystem
var _targeting_state: GridTargetingState

func before_test() -> void:
	# Use scene_runner with ALL_SYSTEMS_ENV for complete system setup
	_runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	_runner.simulate_frames(2)  # Initial setup frames

	_env = _runner.scene() as AllSystemsTestEnvironment
	assert_object(_env).append_failure_message(
		"Failed to load AllSystemsTestEnvironment via scene_runner"
	).is_not_null()

	# Get systems through systems context
	var container := _env.get_container()
	var systems_context := container.get_systems_context()
	_manipulation_system = systems_context.get_manipulation_system()
	_targeting_state = container.get_states().targeting

	# Verify systems are properly initialized
	assert_object(_manipulation_system).append_failure_message(
		"ManipulationSystem should be initialized in AllSystemsTestEnvironment"
	).is_not_null()
	assert_object(_targeting_state).append_failure_message(
		"GridTargetingState should be initialized in AllSystemsTestEnvironment"
	).is_not_null()

func after_test() -> void:
	_runner = null
	_env = null
	_manipulation_system = null
	_targeting_state = null

func test_indicators_ignore_original_when_positioner_inside_bounds() -> void:
	# GIVEN: A manipulatable object at (100, 100) with size 32x32
	var manipulatable := ManipulationHelpers.create_test_manipulatable(
		_env,
		"Original",
		Vector2(100, 100),
		Vector2(32, 32)
	)
	var original: Node2D = manipulatable.root
	assert_object(original).append_failure_message("Manipulatable root should not be null").is_not_null()
	_runner.simulate_frames(1)

	# GIVEN: Start manipulation move
	_manipulation_system.try_move(original)
	_runner.simulate_frames(1)

	# GIVEN: Move the preview so positioner is INSIDE original bounds (e.g., 108, 100)
	# This should be within the 32x32 area centered at (100, 100)
	_env.positioner.position = Vector2(108, 100)
	_runner.simulate_frames(2)

	# WHEN: Check indicator validity
	var indicators := _get_active_indicators()
	var all_valid := _all_indicators_valid(indicators)

	# THEN: All indicators should be valid (no collision with self)
	assert_bool(all_valid).append_failure_message(
		"Indicators should ignore original object when positioner is INSIDE bounds. " +
		"Found %d invalid indicators." % _count_invalid_indicators(indicators)
	).is_true()

func test_indicators_ignore_original_when_positioner_outside_bounds() -> void:
	# GIVEN: A manipulatable object at (100, 100) with size 32x32
	var manipulatable := ManipulationHelpers.create_test_manipulatable(
		_env,
		"Original",
		Vector2(100, 100),
		Vector2(32, 32)
	)
	var original: Node2D = manipulatable.root
	assert_object(original).append_failure_message("Manipulatable root should not be null").is_not_null()
	_runner.simulate_frames(1)

	# GIVEN: Start manipulation move
	_manipulation_system.try_move(original)
	_runner.simulate_frames(1)

	# GIVEN: Move the preview so positioner is OUTSIDE original bounds (e.g., 150, 100)
	# This is clearly outside the 32x32 area centered at (100, 100)
	_env.positioner.position = Vector2(150, 100)
	_runner.simulate_frames(2)

	# WHEN: Check indicator validity
	var indicators := _get_active_indicators()
	var all_valid := _all_indicators_valid(indicators)

	# THEN: All indicators should be valid (no collision with self)
	# THIS IS THE BUG: Indicators incorrectly detect collision with original
	assert_bool(all_valid).append_failure_message(
		"BUG REPRODUCED: Indicators should ignore original object when positioner is OUTSIDE bounds. " +
		"Found %d invalid indicators detecting collision with original object." % _count_invalid_indicators(indicators)
	).is_true()

func test_indicators_remain_valid_across_position_transitions() -> void:
	# GIVEN: A manipulatable object
	var manipulatable := ManipulationHelpers.create_test_manipulatable(
		_env,
		"Original",
		Vector2(100, 100),
		Vector2(32, 32)
	)
	var original: Node2D = manipulatable.root
	assert_object(original).append_failure_message("Manipulatable root should not be null").is_not_null()
	_runner.simulate_frames(1)

	# GIVEN: Start manipulation move
	_manipulation_system.try_move(original)
	_runner.simulate_frames(1)

	# WHEN: Move from inside → outside → inside bounds
	var test_positions := [
		Vector2(100, 100),  # Center (inside)
		Vector2(116, 100),  # Edge (barely inside)
		Vector2(150, 100),  # Far outside
		Vector2(132, 100),  # Just outside
		Vector2(108, 100),  # Back inside
	]

	var results: Array[bool] = []
	for pos: Vector2 in test_positions:
		_env.positioner.position = pos
		_runner.simulate_frames(2)

		var indicators := _get_active_indicators()
		var all_valid := _all_indicators_valid(indicators)
		results.append(all_valid)

	# THEN: All positions should show valid indicators (no collision with self)
	for i in range(results.size()):
		assert_bool(results[i]).append_failure_message(
			"Position %d (%s) failed: indicators should ignore original object at all positions" %
			[i, str(test_positions[i])]
		).is_true()

func test_exclusion_list_contains_original_during_move() -> void:
	# GIVEN: A manipulatable object
	var manipulatable := ManipulationHelpers.create_test_manipulatable(
		_env,
		"Original",
		Vector2(100, 100)
	)
	var original: Node2D = manipulatable.root
	assert_object(original).append_failure_message("Manipulatable root should not be null").is_not_null()
	_runner.simulate_frames(1)

	# WHEN: Start manipulation move
	_manipulation_system.try_move(original)
	_runner.simulate_frames(1)

	# THEN: Exclusion list should contain the original object
	var exclusions := _targeting_state.collision_exclusions
	assert_int(exclusions.size()).append_failure_message(
		"Exclusion list should contain exactly 1 node (the original object)"
	).is_equal(1)
	assert_that(exclusions[0]).append_failure_message(
		"Exclusion list should contain the original object root node"
	).is_same(original)

func test_exclusion_list_persists_across_positioner_movement() -> void:
	# GIVEN: Object being moved
	var manipulatable := ManipulationHelpers.create_test_manipulatable(
		_env,
		"Original",
		Vector2(100, 100)
	)
	var original: Node2D = manipulatable.root
	assert_object(original).append_failure_message("Manipulatable root should not be null").is_not_null()
	_runner.simulate_frames(1)

	_manipulation_system.try_move(original)
	_runner.simulate_frames(1)

	# WHEN: Move positioner to different positions
	_env.positioner.position = Vector2(100, 100)
	_runner.simulate_frames(1)
	var exclusions_inside := _targeting_state.collision_exclusions.duplicate()

	_env.positioner.position = Vector2(150, 100)
	_runner.simulate_frames(1)
	var exclusions_outside := _targeting_state.collision_exclusions.duplicate()

	# THEN: Exclusion list should remain the same (contain original)
	assert_int(exclusions_inside.size())\
		.append_failure_message("Collision exclusions should contain exactly 1 item when positioner is inside bounds") \
		.is_equal(1)
	assert_int(exclusions_outside.size())\
		.append_failure_message("Collision exclusions should contain exactly 1 item when positioner is outside bounds") \
		.is_equal(1)
	assert_that(exclusions_inside[0]).append_failure_message("First exclusion inside bounds should be the original object").is_same(original)
	assert_that(exclusions_outside[0]).append_failure_message("First exclusion outside bounds should be the original object").is_same(original)

## Helper: Get all active indicators
func _get_active_indicators() -> Array[RuleCheckIndicator]:
	var indicator_manager := _env.indicator_manager
	if not indicator_manager:
		return []

	var indicators: Array[RuleCheckIndicator] = []
	for child in indicator_manager.get_children():
		if child is RuleCheckIndicator:
			indicators.append(child)
	return indicators

## Helper: Check if all indicators are valid
func _all_indicators_valid(indicators: Array[RuleCheckIndicator]) -> bool:
	if indicators.is_empty():
		return true

	for indicator in indicators:
		if not indicator.valid:
			return false
	return true

## Helper: Count invalid indicators
func _count_invalid_indicators(indicators: Array[RuleCheckIndicator]) -> int:
	var count := 0
	for indicator in indicators:
		if not indicator.valid:
			count += 1
	return count
