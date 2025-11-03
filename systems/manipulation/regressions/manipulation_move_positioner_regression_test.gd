## Regression test for manipulation move collision exclusion with positioner position.
##
## BUG: When moving an object, collision exclusion only works when the grid positioner
## (targeting ShapeCast2D) is INSIDE the original object's bounds. When the positioner
## moves OUTSIDE the original object's bounds, the exclusion fails and indicators
## incorrectly detect collision with the original object.
##
## Expected: Indicators should ALWAYS exclude the original object during move,
## regardless of positioner position.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _env: AllSystemsTestEnvironment
var _manipulation_system: ManipulationSystem


func before_test() -> void:
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	runner.simulate_frames(2)
	_env = runner.scene() as AllSystemsTestEnvironment
	_manipulation_system = _env.manipulation_system

	# Validate manipulation system exists with diagnostic
	(
		assert_object(_manipulation_system)
		. append_failure_message(
			(
				"ManipulationSystem must exist in test environment - Container: %s"
				% str(_env.get_container())
			)
		)
		. is_not_null()
	)


func after_test() -> void:
	_manipulation_system = null
	runner = null


## Helper to create a manipulatable object
func _create_manipulatable_object(
	p_name: String, p_position: Vector2, p_size: Vector2i = Vector2i(48, 32)
) -> Node2D:
	var root := Node2D.new()
	root.name = p_name
	root.position = p_position

	# Add Manipulatable component with proper configuration
	var manipulatable := Manipulatable.new()
	manipulatable.name = "Manipulatable"
	manipulatable.root = root  # CRITICAL: Set root reference
	manipulatable.settings = load("uid://dn881lunp3lrm")  # Use test settings with movable=true
	root.add_child(manipulatable)

	# Add collision body
	var body := CharacterBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

	# Add collision shape matching the size
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(p_size.x, p_size.y)
	shape.shape = rect
	body.add_child(shape)

	_env.add_child(root)
	return root


## Helper to get indicator validity at a specific positioner position (sync version with scene_runner)
func _check_indicators_at_position_sync(p_position: Vector2) -> Dictionary[String, Variant]:
	# Move positioner to test position
	_env.positioner.global_position = p_position

	# Use scene_runner for reliable frame simulation
	runner.simulate_frames(2)

	# Get all indicators
	var container: GBCompositionContainer = _env.get_container()
	var indicator_manager: IndicatorManager = container.get_indicator_context().get_manager()
	var indicators: Array[RuleCheckIndicator] = indicator_manager.get_indicators()

	var result := {
		"all_valid": true,
		"valid_count": 0,
		"invalid_count": 0,
		"total_count": indicators.size(),
		"position": p_position,
		"indicators": []
	}

	for indicator: RuleCheckIndicator in indicators:
		var info := {"position": indicator.global_position, "valid": indicator.valid}
		result.indicators.append(info)

		if indicator.valid:
			result.valid_count += 1
		else:
			result.invalid_count += 1
			result.all_valid = false

	return result


#region DIAGNOSTIC HELPERS - DRY Pattern


## Format manipulation system diagnostic information
func _format_manipulation_diagnostic() -> String:
	var lines: Array[String] = []
	lines.append("Manipulation System State:")
	lines.append("  System exists: %s" % str(_manipulation_system != null))
	return "\n".join(lines)


## Format indicator check result diagnostic
func _format_result_diagnostic(result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Indicator Check Result:")
	lines.append("  Position: %s" % str(result.get("position", "unknown")))
	lines.append("  Total indicators: %d" % result.total_count)
	lines.append("  Valid: %d" % result.valid_count)
	lines.append("  Invalid: %d" % result.invalid_count)
	lines.append("  All valid: %s" % str(result.all_valid))
	return "\n".join(lines)


#endregion


func test_move_exclusion_works_when_positioner_inside_original_bounds() -> void:
	# GIVEN: A manipulatable object at (200, 200) with 48x32 size
	var original := _create_manipulatable_object("Original", Vector2(200, 200), Vector2i(48, 32))
	runner.simulate_frames(2)

	# GIVEN: Start manipulation move with try_move API
	var move_result: ManipulationData = _manipulation_system.try_move(original)
	(
		assert_object(move_result)
		. append_failure_message(
			"try_move should return ManipulationData - %s" % _format_manipulation_diagnostic()
		)
		. is_not_null()
	)
	(
		assert_bool(move_result.status == GBEnums.Status.STARTED)
		. append_failure_message(
			"Move should start successfully - %s" % _format_manipulation_diagnostic()
		)
		. is_true()
	)

	runner.simulate_frames(2)

	# WHEN: Positioner is INSIDE the original object bounds (center)
	var result_inside := _check_indicators_at_position_sync(Vector2(200, 200))

	# THEN: All indicators should be valid (no collision with original)
	(
		assert_bool(result_inside.all_valid)
		. append_failure_message(
			(
				"Indicators should be valid when positioner inside bounds - %s"
				% _format_result_diagnostic(result_inside)
			)
		)
		. is_true()
	)
	(
		assert_int(result_inside.invalid_count)
		. append_failure_message(
			"Should have 0 invalid indicators - %s" % _format_result_diagnostic(result_inside)
		)
		. is_equal(0)
	)


func test_move_exclusion_fails_when_positioner_outside_original_bounds() -> void:
	# GIVEN: A manipulatable object at (200, 200) with 48x32 size
	var original := _create_manipulatable_object("Original", Vector2(200, 200), Vector2i(48, 32))
	runner.simulate_frames(2)

	# GIVEN: Start manipulation move with try_move API
	var move_result: ManipulationData = _manipulation_system.try_move(original)
	(
		assert_object(move_result)
		. append_failure_message(
			"try_move should return ManipulationData - %s" % _format_manipulation_diagnostic()
		)
		. is_not_null()
	)
	(
		assert_bool(move_result.status == GBEnums.Status.STARTED)
		. append_failure_message(
			"Move should start successfully - %s" % _format_manipulation_diagnostic()
		)
		. is_true()
	)

	runner.simulate_frames(2)

	# WHEN: Positioner is OUTSIDE the original object bounds (to the right)
	# Original bounds: x: 176-224 (200 ± 24), y: 184-216 (200 ± 16)
	# Test position: 250 (well outside right edge)
	var result_outside := _check_indicators_at_position_sync(Vector2(250, 200))

	# THEN: All indicators should STILL be valid (original should be excluded)
	# BUG: This currently FAILS - indicators incorrectly detect collision with original
	(
		assert_bool(result_outside.all_valid)
		. append_failure_message("All indicators should be valid when original is excluded")
		. is_true()
	)
	(
		assert_int(result_outside.invalid_count)
		. append_failure_message("No indicators should be invalid when original is excluded")
		. is_equal(0)
	)


func test_move_exclusion_consistent_across_multiple_positions() -> void:
	# GIVEN: A manipulatable object
	var original := _create_manipulatable_object("Original", Vector2(200, 200), Vector2i(48, 32))
	runner.simulate_frames(2)

	# GIVEN: Start manipulation move with try_move API
	var move_result: ManipulationData = _manipulation_system.try_move(original)
	(
		assert_object(move_result)
		. append_failure_message(
			"try_move should return ManipulationData - %s" % _format_manipulation_diagnostic()
		)
		. is_not_null()
	)
	(
		assert_bool(move_result.status == GBEnums.Status.STARTED)
		. append_failure_message(
			"Move should start successfully - %s" % _format_manipulation_diagnostic()
		)
		. is_true()
	)
	runner.simulate_frames(2)

	# WHEN: Testing multiple positioner positions
	var positions := [
		Vector2(200, 200),  # Center (inside)
		Vector2(180, 200),  # Left edge (inside)
		Vector2(220, 200),  # Right edge (inside)
		Vector2(150, 200),  # Far left (outside)
		Vector2(250, 200),  # Far right (outside)
		Vector2(200, 150),  # Above (outside)
		Vector2(200, 250),  # Below (outside)
	]

	var results: Array[Dictionary] = []
	for pos: Vector2 in positions:
		var result: Dictionary[String, Variant] = _check_indicators_at_position_sync(pos)
		results.append(result)

	# THEN: ALL positions should have valid indicators (original excluded everywhere)
	for i in range(results.size()):
		var result: Dictionary[String, Variant] = results[i]
		var pos: Vector2 = positions[i]
		(
			assert_bool(result.all_valid)
			. append_failure_message(
				(
					"Position %s should have valid indicators - %s"
					% [str(pos), _format_result_diagnostic(result)]
				)
			)
			. is_true()
		)


func test_move_exclusion_with_overlapping_indicators() -> void:
	# GIVEN: A manipulatable object
	var original := _create_manipulatable_object("Original", Vector2(200, 200), Vector2i(64, 48))
	runner.simulate_frames(2)

	# GIVEN: Start manipulation move with try_move API
	var move_result: ManipulationData = _manipulation_system.try_move(original)
	(
		assert_bool(move_result.status == GBEnums.Status.STARTED)
		. append_failure_message(
			"Move should start successfully - %s" % _format_manipulation_diagnostic()
		)
		. is_true()
	)
	runner.simulate_frames(2)

	# WHEN: Positioner positioned so indicators overlap original AND empty space
	# Move slightly to the right - some indicators over original, some over empty
	var result_overlap: Dictionary[String, Variant] = _check_indicators_at_position_sync(
		Vector2(230, 200)
	)

	# THEN: All indicators should be valid (those over original excluded, those over empty valid)
	(
		assert_bool(result_overlap.all_valid)
		. append_failure_message(
			(
				"Overlapping indicators should all be valid - %s"
				% _format_result_diagnostic(result_overlap)
			)
		)
		. is_true()
	)
