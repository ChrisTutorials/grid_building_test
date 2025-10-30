## Tests RuleCheckIndicator behavior with collision exclusions.
##
## Verifies that indicators properly respect exclusions during their
## _physics_process() validation cycle, ensuring:
## - Valid state persists across multiple physics frames
## - Exclusions work during continuous validation
## - Indicator state updates correctly when exclusions change
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _env: CollisionTestEnvironment
var _rule: CollisionsCheckRule

func before_test() -> void:
	# MIGRATION: Use scene_runner WITHOUT frame simulation
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV)
	_env = runner.scene() as CollisionTestEnvironment

	assert_object(_env).append_failure_message(
		"Failed to load CollisionTestEnvironment scene"
	).is_not_null()

	# Create collision rule
	_rule = CollisionsCheckRule.new()
	_rule.pass_on_collision = false  # Fail when collision detected
	_rule.collision_mask = 1  # Check layer 0
	var setup_issues := _rule.setup(_env.targeting_state)
	assert_array(setup_issues).append_failure_message(
		"CollisionsCheckRule setup should have no issues"
	).is_empty()

func after_test() -> void:
	# Clear collision exclusions to prevent test isolation issues
	if _env and _env.targeting_state:
		_env.targeting_state.collision_exclusions = []
	_rule = null

## Helper to create a collision body
func _create_collision_body(p_name: String, p_position: Vector2, p_layer: int = 1) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = p_name
	body.position = p_position
	body.collision_layer = p_layer
	body.collision_mask = 0

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)

	# Ensure the test suite will free this node at teardown
	self.auto_free(body)
	_env.add_child(body)
	return body

## Helper to create an indicator
func _create_indicator(p_position: Vector2) -> RuleCheckIndicator:
	var indicator := RuleCheckIndicator.new()
	indicator.position = p_position
	indicator.target_position = Vector2.ZERO

	# Create shape for indicator
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	indicator.shape = rect_shape

	indicator.collision_mask = 1
	# Ensure the test suite will free this node at teardown
	self.auto_free(indicator)
	_env.add_child(indicator)

	return indicator

func test_indicator_stays_valid_across_physics_frames_with_exclusion() -> void:
	# GIVEN: Collision body and indicator at same position
	var excluded_body := _create_collision_body("ExcludedBody", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)

	# GIVEN: Body is excluded
	_env.targeting_state.collision_exclusions = [excluded_body]

	# Evaluate indicators immediately after setting exclusions for deterministic result
	_env.indicator_manager.force_indicators_validity_evaluation()
	# WHEN: Multiple physics frames pass
	# Ensure indicator collision and validity are evaluated deterministically
	_env.indicator_manager.force_indicators_validity_evaluation()
	# Also force this specific indicator to evaluate its validity synchronously
	indicator.force_validity_evaluation()
	var valid_frame1 := indicator.valid

	runner.simulate_frames(1)
	_env.indicator_manager.force_indicators_validity_evaluation()
	indicator.force_validity_evaluation()
	var valid_frame2 := indicator.valid

	runner.simulate_frames(1)
	_env.indicator_manager.force_indicators_validity_evaluation()
	indicator.force_validity_evaluation()
	var valid_frame3 := indicator.valid

	runner.simulate_frames(1)
	_env.indicator_manager.force_indicators_validity_evaluation()
	indicator.force_validity_evaluation()
	var valid_frame4 := indicator.valid

	# THEN: Indicator remains valid across all frames
	assert_bool(valid_frame1).append_failure_message(
		"Frame 1 should be valid - %s, %s, %s" % [
			_format_indicator_state(indicator),
			_format_body_state(excluded_body),
			_format_exclusions()
		]
	).is_true()
	assert_bool(valid_frame2).append_failure_message(
		"Frame 2 should be valid - %s" % _format_indicator_state(indicator)
	).is_true()
	assert_bool(valid_frame3).append_failure_message(
		"Frame 3 should be valid - %s" % _format_indicator_state(indicator)
	).is_true()
	assert_bool(valid_frame4).append_failure_message(
		"Frame 4 should be valid - %s" % _format_indicator_state(indicator)
	).is_true()

func test_indicator_becomes_invalid_when_exclusion_cleared() -> void:
	# GIVEN: Excluded body and valid indicator
	var excluded_body := _create_collision_body("ExcludedBody", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)
	_env.targeting_state.collision_exclusions = [excluded_body]

	# Wait for indicator to validate with exclusion present
	assert(runner != null, "scene_runner required for physics simulation")
	runner.simulate_frames(2)
	assert_bool(indicator.valid).append_failure_message(
		"Should be valid with exclusion - %s, %s, %s" % [
			_format_indicator_state(indicator),
			_format_body_state(excluded_body),
			_format_exclusions()
		]
	).is_true()

	# WHEN: Exclusion is cleared
	_env.targeting_state.clear_collision_exclusions()

	# THEN: Indicator becomes invalid on next physics frame
	runner.simulate_frames(1)
	assert_bool(indicator.valid).append_failure_message(
		"Should be invalid after clearing exclusions - %s" % _format_indicator_state(indicator)
	).is_false()

func test_indicator_updates_immediately_after_exclusion_added() -> void:
	# GIVEN: Collision body and indicator (not excluded initially)
	var body := _create_collision_body("Body", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)

	runner.simulate_frames(1)
	assert_bool(indicator.valid).append_failure_message(
		"Should be invalid without exclusion - %s, %s, %s" % [
			_format_indicator_state(indicator),
			_format_body_state(body),
			_format_exclusions()
		]
	).is_false()  # Collision detected

	# WHEN: Body is added to exclusions
	_env.targeting_state.collision_exclusions = [body]

	# THEN: Indicator becomes valid on next validation
	runner.simulate_frames(1)
	assert_bool(indicator.valid).append_failure_message(
		"Should be valid with exclusion - %s, %s" % [
			_format_indicator_state(indicator),
			_format_exclusions()
		]
	).is_true()

func test_indicator_respects_exclusions_during_continuous_validation() -> void:
	# GIVEN: Two bodies - one excluded, one not
	var excluded_body := _create_collision_body("Excluded", Vector2(100, 100))
	var _detected_body := _create_collision_body("Detected", Vector2(132, 100))

	var indicator1 := _create_indicator(Vector2(100, 100))
	var indicator2 := _create_indicator(Vector2(132, 100))
	indicator1.add_rule(_rule)
	indicator2.add_rule(_rule)

	_env.targeting_state.collision_exclusions = [excluded_body]

	runner.simulate_frames(1)
	var ind1_valid_f1 := indicator1.valid
	var ind2_valid_f1 := indicator2.valid

	runner.simulate_frames(1)
	var ind1_valid_f2 := indicator1.valid
	var ind2_valid_f2 := indicator2.valid

	runner.simulate_frames(1)
	var ind1_valid_f3 := indicator1.valid
	var ind2_valid_f3 := indicator2.valid

	# THEN: Indicator1 stays valid (excluded), Indicator2 stays invalid (detected)
	assert_bool(ind1_valid_f1).append_failure_message(
		"Ind1 F1 should be valid (excluded) - %s, %s" % [
			_format_indicator_state(indicator1),
			_format_exclusions()
		]
	).is_true()
	assert_bool(ind1_valid_f2).append_failure_message(
		"Ind1 F2 should be valid (excluded) - %s" % _format_indicator_state(indicator1)
	).is_true()
	assert_bool(ind1_valid_f3).append_failure_message(
		"Ind1 F3 should be valid (excluded) - %s" % _format_indicator_state(indicator1)
	).is_true()

	assert_bool(ind2_valid_f1).append_failure_message(
		"Ind2 F1 should be invalid (detected) - %s" % _format_indicator_state(indicator2)
	).is_false()
	assert_bool(ind2_valid_f2).append_failure_message(
		"Ind2 F2 should be invalid (detected) - %s" % _format_indicator_state(indicator2)
	).is_false()
	assert_bool(ind2_valid_f3).append_failure_message(
		"Ind2 F3 should be invalid (detected) - %s" % _format_indicator_state(indicator2)
	).is_false()

func test_indicator_emits_valid_changed_signal_when_exclusion_changes() -> void:
	# GIVEN: Collision body and indicator
	var body := _create_collision_body("Body", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)

	runner.simulate_frames(1)
	assert_bool(indicator.valid).append_failure_message(
		"Should be invalid initially - %s, %s" % [
			_format_indicator_state(indicator),
			_format_body_state(body)
		]
	).is_false()

	# WHEN: Exclusion added
	_env.targeting_state.collision_exclusions = [body]
	runner.simulate_frames(1)

	# THEN: Signal emitted with true and indicator becomes valid
	assert_signal(indicator).is_emitted("valid_changed")
	assert_bool(indicator.valid).is_true()

func test_multiple_indicators_share_same_exclusion_list() -> void:
	# GIVEN: One body, multiple indicators at same position
	var excluded_body := _create_collision_body("Excluded", Vector2(100, 100))

	var indicator1 := _create_indicator(Vector2(100, 100))
	var indicator2 := _create_indicator(Vector2(100, 100))
	var indicator3 := _create_indicator(Vector2(100, 100))

	indicator1.add_rule(_rule)
	indicator2.add_rule(_rule)
	indicator3.add_rule(_rule)

	# WHEN: Body excluded via targeting state
	_env.targeting_state.collision_exclusions = [excluded_body]
 runner.simulate_frames(1)

	# THEN: All indicators respect the exclusion
	assert_bool(indicator1.valid).append_failure_message(
		"Ind1 should be valid with shared exclusion - %s, %s" % [
			_format_indicator_state(indicator1),
			_format_exclusions()
		]
	).is_true()
	assert_bool(indicator2.valid).append_failure_message(
		"Ind2 should be valid with shared exclusion - %s" % _format_indicator_state(indicator2)
	).is_true()
	assert_bool(indicator3.valid).append_failure_message(
		"Ind3 should be valid with shared exclusion - %s" % _format_indicator_state(indicator3)
	).is_true()

func test_indicator_handles_exclusion_of_nested_collision_objects() -> void:
	# GIVEN: Parent with nested collision hierarchy
	var root := Node2D.new()
	root.name = "Root"
	root.position = Vector2(200, 100)
	# Ensure root is cleaned up by test harness
	self.auto_free(root)
	_env.add_child(root)

	var parent := CharacterBody2D.new()
	parent.name = "Parent"
	parent.collision_layer = 1
	parent.position = Vector2.ZERO  # Positioned at same location as root (200, 100 world)

	# Parent must be added to scene under root so its global position matches root
	# Auto-free parent so teardown removes it cleanly
	self.auto_free(parent)
	root.add_child(parent)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	parent.add_child(shape)

	# Create indicator at same world position
	var indicator := _create_indicator(Vector2(200, 100))
	indicator.add_rule(_rule)

	# Wait for physics to detect collision
 runner.simulate_frames(1)
 runner.simulate_frames(1)

	# DEBUG: Verify collision setup
	var body_world_pos := parent.global_position
	var indicator_world_pos := indicator.global_position
	assert_bool(indicator.valid).append_failure_message(
		"Should be invalid before exclusion - %s, %s, Body world pos: %s, Indicator world pos: %s" % [
			_format_indicator_state(indicator),
			_format_exclusions(),
			str(body_world_pos),
			str(indicator_world_pos)
		]
	).is_false()  # Collision detected

	# WHEN: Root excluded (should exclude all children)
	_env.targeting_state.collision_exclusions = [root]
 runner.simulate_frames(1)

	# THEN: Indicator becomes valid (nested collision excluded)
	var root_name: String = str(root.name) if is_instance_valid(root) else "null"
	assert_bool(indicator.valid).append_failure_message(
		"Should be valid with nested exclusion - %s, Excluded root: %s" % [
			_format_indicator_state(indicator),
			root_name
		]
	).is_true()

func test_indicator_validation_without_exclusions_baseline() -> void:
	# GIVEN: Collision body and indicator (no exclusions)
	var _body := _create_collision_body("Body", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)

	# WHEN: Multiple physics frames pass without exclusions
 runner.simulate_frames(1)
	var valid_f1 := indicator.valid

 runner.simulate_frames(1)
	var valid_f2 := indicator.valid

 runner.simulate_frames(1)
	var valid_f3 := indicator.valid

	# THEN: Indicator consistently invalid (collision detected)
	assert_bool(valid_f1).append_failure_message(
		"F1 should be invalid (no exclusions) - %s" % _format_indicator_state(indicator)
	).is_false()
	assert_bool(valid_f2).append_failure_message(
		"F2 should be invalid (no exclusions) - %s" % _format_indicator_state(indicator)
	).is_false()
	assert_bool(valid_f3).append_failure_message(
		"F3 should be invalid (no exclusions) - %s" % _format_indicator_state(indicator)
	).is_false()

#region DRY Diagnostic Helpers

## Format indicator state for diagnostic messages
func _format_indicator_state(indicator: RuleCheckIndicator) -> String:
	if not indicator:
		return "[Indicator: null]"
	# Provide a compact snapshot of indicator state
	var valid_state := indicator.valid
	var in_tree := indicator.is_inside_tree()
	var processing := indicator.is_physics_processing()
	var pos := str(indicator.global_position)
	var rules_count := indicator.rules.size() if indicator.rules else 0
	return "[Indicator: valid=%s, in_tree=%s, processing=%s, pos=%s, rules=%d]" % [str(valid_state), str(in_tree), str(processing), pos, rules_count]

## Format collision exclusions for diagnostic messages
func _format_exclusions() -> String:
	if not _env or not _env.targeting_state:
		return "[Exclusions: null]"
	var exclusions: Array[Node] = _env.targeting_state.collision_exclusions
	if exclusions.is_empty():
		return "[Exclusions: none]"
	var names: Array[String] = []
	for obj: Variant in exclusions:
		if obj and obj is Node:
			names.append(str(obj.name))
	return "[Exclusions: %s]" % ", ".join(names)
func _format_body_state(body: CharacterBody2D) -> String:
	if not body:
		return "[Body: null]"
	return "[Body: name=%s, pos=%s, layer=%d, in_tree=%s]" % [
		body.name,
		str(body.global_position),
		body.collision_layer,
		str(body.is_inside_tree())
	]

## Format rule state for diagnostic messages
func _format_rule_state() -> String:
	if not _rule:
		return "[Rule: null]"
	return "[Rule: type=CollisionsCheckRule, pass_on_collision=%s, mask=%d]" % [
		_rule.pass_on_collision,
		_rule.collision_mask
	]

#endregion
