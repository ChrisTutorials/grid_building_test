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

var _env: AllSystemsTestEnvironment
var _manipulation_system: ManipulationSystem
var _targeting_state: GridTargetingState

func before_test() -> void:
	_env = EnvironmentTestFactory.create_all_systems_env(self)
	
	# Get systems
	var container := _env.get_container()
	_manipulation_system = _env.manipulation_system
	_targeting_state = container.get_states().targeting

func after_test() -> void:
	_env = null
	_manipulation_system = null
	_targeting_state = null

## Helper to create a manipulatable object with collision
func _create_manipulatable_object(p_name: String, p_position: Vector2, p_size: Vector2 = Vector2(32, 32)) -> Node2D:
	var root := Node2D.new()
	root.name = p_name
	root.position = p_position
	
	# Add body with collision
	var body := CharacterBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape"
	var rect := RectangleShape2D.new()
	rect.size = p_size
	shape.shape = rect
	body.add_child(shape)
	
	# Add manipulatable component
	var manipulatable := Manipulatable.new()
	manipulatable.name = "Manipulatable"
	manipulatable.root = root  # CRITICAL: Set root property so try_move() can find it
	root.add_child(manipulatable)
	
	# Add placement shape for targeting
	var placement_area := Area2D.new()
	placement_area.name = "PlacementShape"
	placement_area.collision_layer = 2048  # Targetable layer
	root.add_child(placement_area)
	
	var placement_shape := CollisionShape2D.new()
	var placement_rect := RectangleShape2D.new()
	placement_rect.size = p_size
	placement_shape.shape = placement_rect
	placement_area.add_child(placement_shape)
	
	_env.add_child(root)
	return root

func test_indicators_ignore_original_when_positioner_inside_bounds() -> void:
	# GIVEN: A manipulatable object at (100, 100) with size 32x32
	var original := _create_manipulatable_object("Original", Vector2(100, 100), Vector2(32, 32))
	await get_tree().process_frame
	
	# GIVEN: Start manipulation move
	var move_data := _manipulation_system.try_move(original)
	assert_object(move_data).is_not_null()
	await get_tree().process_frame
	
	# GIVEN: Move the preview so positioner is INSIDE original bounds (e.g., 108, 100)
	# This should be within the 32x32 area centered at (100, 100)
	_env.positioner.position = Vector2(108, 100)
	await get_tree().process_frame
	
	# WHEN: Check indicator validity
	var indicators := _get_active_indicators()
	var all_valid := _all_indicators_valid(indicators)
	
	# Build diagnostic
	var diagnostic := "Test: positioner INSIDE bounds\n"
	diagnostic += "  Positioner position: %s\n" % str(_env.positioner.position)
	diagnostic += "  Original position: %s\n" % str(original.position)
	diagnostic += _format_exclusions_diagnostic("  Collision exclusions", _targeting_state.collision_exclusions)
	diagnostic += _format_indicators_diagnostic(indicators)
	
	# THEN: All indicators should be valid (no collision with self)
	assert_bool(all_valid).append_failure_message(
		"%s\nIndicators should ignore original object when positioner is INSIDE bounds" % diagnostic
	).is_true()

func test_indicators_ignore_original_when_positioner_outside_bounds() -> void:
	# GIVEN: A manipulatable object at (100, 100) with size 32x32
	var original := _create_manipulatable_object("Original", Vector2(100, 100), Vector2(32, 32))
	await get_tree().process_frame
	
	# GIVEN: Start manipulation move
	var move_data := _manipulation_system.try_move(original)
	assert_object(move_data).is_not_null()
	await get_tree().process_frame
	
	# GIVEN: Move the preview so positioner is OUTSIDE original bounds (e.g., 150, 100)
	# This is clearly outside the 32x32 area centered at (100, 100)
	_env.positioner.position = Vector2(150, 100)
	await get_tree().process_frame
	
	# WHEN: Check indicator validity
	var indicators := _get_active_indicators()
	var all_valid := _all_indicators_valid(indicators)
	
	# Build diagnostic
	var diagnostic := "Test: positioner OUTSIDE bounds\n"
	diagnostic += "  Positioner position: %s\n" % str(_env.positioner.position)
	diagnostic += "  Original position: %s\n" % str(original.position)
	diagnostic += _format_exclusions_diagnostic("  Collision exclusions", _targeting_state.collision_exclusions)
	diagnostic += _format_indicators_diagnostic(indicators)
	
	# THEN: All indicators should be valid (no collision with self)
	# THIS IS THE BUG: Indicators incorrectly detect collision with original
	assert_bool(all_valid).append_failure_message(
		"%s\nBUG: Indicators should ignore original object when positioner is OUTSIDE bounds" % diagnostic
	).is_true()

func test_indicators_remain_valid_across_position_transitions() -> void:
	# GIVEN: A manipulatable object
	var original := _create_manipulatable_object("Original", Vector2(100, 100), Vector2(32, 32))
	await get_tree().process_frame
	
	# GIVEN: Start manipulation move
	var move_data := _manipulation_system.try_move(original)
	assert_object(move_data).is_not_null()
	await get_tree().process_frame
	
	# WHEN: Move from inside → outside → inside bounds
	var test_positions := [
		Vector2(100, 100),  # Center (inside)
		Vector2(116, 100),  # Edge (barely inside)
		Vector2(150, 100),  # Far outside
		Vector2(132, 100),  # Just outside
		Vector2(108, 100),  # Back inside
	]
	var test_labels := ["center", "edge_inside", "far_outside", "just_outside", "back_inside"]
	
	var results: Array[bool] = []
	var exclusions_at_positions: Array[int] = []
	for pos: Vector2 in test_positions:
		_env.positioner.position = pos
		await get_tree().process_frame
		
		var indicators := _get_active_indicators()
		var all_valid := _all_indicators_valid(indicators)
		results.append(all_valid)
		exclusions_at_positions.append(_targeting_state.collision_exclusions.size())
	
	# THEN: All positions should show valid indicators (no collision with self)
	for i in range(results.size()):
		var diagnostic := "Position transition test [%d/%d]: %s\n" % [i+1, results.size(), test_labels[i]]
		diagnostic += "  Position: %s\n" % str(test_positions[i])
		diagnostic += "  Collision exclusions: %d\n" % exclusions_at_positions[i]
		diagnostic += "  Original at: %s\n" % str(original.position)
		
		assert_bool(results[i]).append_failure_message(
			"%s  Indicators should ignore original object at all positions" % diagnostic
		).is_true()

func test_exclusion_list_contains_original_during_move() -> void:
	# GIVEN: A manipulatable object
	var original := _create_manipulatable_object("Original", Vector2(100, 100))
	await get_tree().process_frame
	
	# WHEN: Start manipulation move
	var move_data := _manipulation_system.try_move(original)
	assert_object(move_data).is_not_null()
	
	# Check exclusions IMMEDIATELY (before any frame waits that might clear them)
	var exclusions_immediate := _targeting_state.collision_exclusions.duplicate()
	
	# Then wait for frame
	await get_tree().process_frame
	
	# Check exclusions AFTER frame wait
	var exclusions_after_frame := _targeting_state.collision_exclusions.duplicate()
	
	# Build diagnostic using DRY helpers
	var diagnostic := "Exclusion list initialization check:\n"
	diagnostic += "  Original: %s (valid: %s)\n" % [str(original), str(is_instance_valid(original))]
	diagnostic += _format_move_data_diagnostic(move_data)
	diagnostic += _format_exclusions_diagnostic("  Exclusions (immediate)", exclusions_immediate)
	diagnostic += _format_exclusions_diagnostic("  Exclusions (after frame)", exclusions_after_frame)
	
	# THEN: Exclusion list should contain the original object (check the one after frame)
	var exclusions := exclusions_after_frame
	assert_int(exclusions.size()).append_failure_message(
		"%s\nExclusion list should contain exactly 1 node (the original object)" % diagnostic
	).is_equal(1)
	
	if exclusions.size() > 0:
		assert_that(exclusions[0]).is_same(original).append_failure_message(
			"Exclusion list should contain the original object root node"
		)

## Helper to convert status enum to human-readable string
func _status_to_string(status: int) -> String:
	match status:
		GBEnums.Status.CREATED: return "CREATED"
		GBEnums.Status.STARTED: return "STARTED"
		GBEnums.Status.FAILED: return "FAILED"
		GBEnums.Status.FINISHED: return "FINISHED"
		GBEnums.Status.CANCELED: return "CANCELED"
		_: return "UNKNOWN"

func test_exclusion_list_persists_across_positioner_movement() -> void:
	# GIVEN: Object being moved
	var original := _create_manipulatable_object("Original", Vector2(100, 100))
	await get_tree().process_frame
	
	var move_data := _manipulation_system.try_move(original)
	assert_object(move_data).is_not_null()
	await get_tree().process_frame
	
	# WHEN: Move positioner to different positions
	_env.positioner.position = Vector2(100, 100)
	await get_tree().process_frame
	var exclusions_inside := _targeting_state.collision_exclusions.duplicate()
	
	_env.positioner.position = Vector2(150, 100)
	await get_tree().process_frame
	var exclusions_outside := _targeting_state.collision_exclusions.duplicate()
	
	# Build diagnostic using DRY helpers
	var diagnostic := "Exclusion persistence across movement:\n"
	diagnostic += "  Original: %s\n" % str(original)
	diagnostic += _format_move_data_diagnostic(move_data)
	diagnostic += _format_exclusions_diagnostic("  At position (100,100) - INSIDE", exclusions_inside)
	diagnostic += _format_exclusions_diagnostic("  At position (150,100) - OUTSIDE", exclusions_outside)
	
	# THEN: Exclusion list should remain the same (contain original)
	assert_int(exclusions_inside.size()).append_failure_message(
		"%s\nCRITICAL: Exclusions should contain 1 item at INSIDE position" % diagnostic
	).is_equal(1)
	assert_int(exclusions_outside.size()).append_failure_message(
		"%s\nCRITICAL BUG: Exclusions cleared when positioner moves OUTSIDE!" % diagnostic
	).is_equal(1)
	
	if exclusions_inside.size() > 0:
		assert_that(exclusions_inside[0]).is_same(original)
	if exclusions_outside.size() > 0:
		assert_that(exclusions_outside[0]).is_same(original)

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

## Helper: Format collision exclusions diagnostic
func _format_exclusions_diagnostic(label: String, exclusions: Array) -> String:
	var diag := "%s: %d exclusions\n" % [label, exclusions.size()]
	if exclusions.size() > 0:
		for i in exclusions.size():
			diag += "    [%d] %s (valid: %s)\n" % [i, str(exclusions[i]), str(is_instance_valid(exclusions[i]))]
	else:
		diag += "    (empty)\n"
	return diag

## Helper: Format indicator state diagnostic
func _format_indicators_diagnostic(indicators: Array[RuleCheckIndicator]) -> String:
	if indicators.is_empty():
		return "  No indicators found\n"
	
	var diag := "  Indicators: %d total, %d invalid\n" % [indicators.size(), _count_invalid_indicators(indicators)]
	for i in indicators.size():
		var ind := indicators[i]
		diag += "    [%d] valid=%s pos=%s\n" % [i, str(ind.valid), str(ind.global_position)]
	return diag

## Helper: Format move_data diagnostic
func _format_move_data_diagnostic(move_data: ManipulationData) -> String:
	if not move_data:
		return "  move_data: null\n"
	
	var diag := "  move_data:\n"
	diag += "    status: %s (%s)\n" % [str(move_data.status), _status_to_string(move_data.status)]
	diag += "    message: %s\n" % str(move_data.message)
	diag += "    source: %s\n" % str(move_data.source)
	diag += "    target: %s\n" % str(move_data.target)
	return diag
