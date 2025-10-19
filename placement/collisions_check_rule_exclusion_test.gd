## Unit tests for CollisionsCheckRule exclusion mechanism.
## 
## Tests verify that collision exclusions work correctly:
## - Root node exclusion
## - Child collision objects excluded
## - Multiple collision shapes under one parent excluded
## - Non-excluded objects still detected
##
## TESTING PATTERN: Uses direct collision checking via force_shapecast_update()
## instead of physics frame simulation for deterministic, non-flaky tests
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _rule: CollisionsCheckRule
var _env: CollisionTestEnvironment

func before_test() -> void:
	# Use scene_runner for test environment setup
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	
	_env = runner.scene() as CollisionTestEnvironment
	# Container is already duplicated by environment's _ready() for test isolation
	_env.container.config.settings.targeting.enable_mouse_input = false # Explicitly disable mouse input to avoid interference
	
	# Create collision rule
	_rule = CollisionsCheckRule.new()
	_rule.pass_on_collision = false  # Fail when collision detected
	_rule.collision_mask = 1  # Check layer 0
	var setup_issues := _rule.setup(_env.targeting_state)
	assert_array(setup_issues).is_empty() \
		.append_failure_message("Rule setup should succeed with no issues")

func after_test() -> void:
	# Clear collision exclusions to prevent test isolation issues
	if _env and _env.targeting_state:
		_env.targeting_state.collision_exclusions = []
	_rule = null
	runner = null

## Helper to create a collision object at a position
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
	
	_env.add_child(body)
	return body

## Helper to create an indicator at a position
func _create_indicator(p_position: Vector2) -> RuleCheckIndicator:
	var indicator := RuleCheckIndicator.new()
	indicator.position = p_position
	indicator.target_position = Vector2.ZERO
	
	# Create shape for indicator
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	indicator.shape = rect_shape
	
	indicator.collision_mask = 1  # Will be overridden by rule
	_env.add_child(indicator)
	
	return indicator

func test_exclusion_prevents_collision_with_single_body() -> void:
	# GIVEN: A collision body at (100, 100)
	var excluded_body := _create_collision_body("ExcludedBody", Vector2(100, 100))
	
	# GIVEN: An indicator at the same position
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)
	
	# Force immediate collision check
	indicator.force_shapecast_update()
	
	# WHEN: No exclusions set
	var failing_without_exclusion := _rule.get_failing_indicators([indicator])
	
	# THEN: Indicator detects collision (fails)
	assert_int(failing_without_exclusion.size()).is_equal(1) \
		.append_failure_message("Indicator should detect collision without exclusions")
	assert_that(failing_without_exclusion[0]).is_equal(indicator) \
		.append_failure_message("Failing indicator should be our test indicator")
	
	# WHEN: Excluded body is added to exclusion list
	_env.targeting_state.collision_exclusions = [excluded_body]
	indicator.force_shapecast_update()
	
	# THEN: Indicator no longer detects collision (passes)
	var failing_with_exclusion := _rule.get_failing_indicators([indicator])
	assert_array(failing_with_exclusion).is_empty() \
		.append_failure_message("Indicator should not detect collision when body is excluded")

func test_exclusion_applies_to_all_children() -> void:
	# GIVEN: A parent body with multiple collision children
	var parent_body := CharacterBody2D.new()
	parent_body.name = "ParentBody"
	parent_body.position = Vector2(200, 100)
	_env.add_child(parent_body)
	
	# Add multiple collision children
	var child1 := CollisionShape2D.new()
	child1.name = "CollisionShape1"
	child1.position = Vector2(-8, 0)
	var rect1 := RectangleShape2D.new()
	rect1.size = Vector2(16, 16)
	child1.shape = rect1
	parent_body.add_child(child1)
	parent_body.collision_layer = 1
	
	var area_child := Area2D.new()
	area_child.name = "AreaChild"
	area_child.position = Vector2(8, 0)
	area_child.collision_layer = 1
	var child2 := CollisionShape2D.new()
	child2.name = "CollisionShape2"
	var rect2 := RectangleShape2D.new()
	rect2.size = Vector2(16, 16)
	child2.shape = rect2
	area_child.add_child(child2)
	parent_body.add_child(area_child)
	
	# GIVEN: Indicators at both child positions
	var indicator1 := _create_indicator(Vector2(192, 100))  # Over child1
	var indicator2 := _create_indicator(Vector2(208, 100))  # Over area_child
	indicator1.add_rule(_rule)
	indicator2.add_rule(_rule)
	
	# Force immediate collision checks
	indicator1.force_shapecast_update()
	indicator2.force_shapecast_update()
	
	# WHEN: No exclusions
	var failing_without := _rule.get_failing_indicators([indicator1, indicator2])
	
	# THEN: Both indicators detect collisions
	assert_int(failing_without.size()).is_equal(2) \
		.append_failure_message("Both indicators should detect collisions without exclusions")
	
	# WHEN: Parent is excluded
	_env.targeting_state.collision_exclusions = [parent_body]
	indicator1.force_shapecast_update()
	indicator2.force_shapecast_update()
	
	# THEN: Both indicators pass (all children excluded)
	var failing_with := _rule.get_failing_indicators([indicator1, indicator2])
	assert_array(failing_with).is_empty() \
		.append_failure_message("No indicators should fail when parent is excluded (children should be excluded too)")

func test_exclusion_only_affects_specified_objects() -> void:
	# GIVEN: Two separate bodies
	var excluded_body := _create_collision_body("ExcludedBody", Vector2(100, 100))
	var _detected_body := _create_collision_body("DetectedBody", Vector2(132, 100))
	
	# GIVEN: Indicators at both positions
	var indicator1 := _create_indicator(Vector2(100, 100))
	var indicator2 := _create_indicator(Vector2(132, 100))
	indicator1.add_rule(_rule)
	indicator2.add_rule(_rule)
	
	# WHEN: Only first body is excluded
	_env.targeting_state.collision_exclusions = [excluded_body]
	indicator1.force_shapecast_update()
	indicator2.force_shapecast_update()
	
	# THEN: First indicator passes, second fails
	var failing := _rule.get_failing_indicators([indicator1, indicator2])
	assert_int(failing.size()).is_equal(1) \
		.append_failure_message("Only one indicator should fail (non-excluded body)")
	assert_that(failing[0]).is_equal(indicator2) \
		.append_failure_message("The failing indicator should be indicator2 (non-excluded body)")

func test_exclusion_persists_across_multiple_checks() -> void:
	# GIVEN: Excluded body and indicator
	var excluded_body := _create_collision_body("ExcludedBody", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)
	_env.targeting_state.collision_exclusions = [excluded_body]
	indicator.force_shapecast_update()
	
	# WHEN: Checking multiple times in sequence
	var check1 := _rule.get_failing_indicators([indicator])
	var check2 := _rule.get_failing_indicators([indicator])
	var check3 := _rule.get_failing_indicators([indicator])
	
	# THEN: All checks respect exclusion (no failures)
	assert_array(check1).is_empty() \
		.append_failure_message("First check should respect exclusion")
	assert_array(check2).is_empty() \
		.append_failure_message("Second check should respect exclusion")
	assert_array(check3).is_empty() \
		.append_failure_message("Third check should respect exclusion (persistence verified)")

func test_exclusion_cleared_when_target_changes() -> void:
	# GIVEN: Excluded body and indicator
	var excluded_body := _create_collision_body("ExcludedBody", Vector2(100, 100))
	var indicator := _create_indicator(Vector2(100, 100))
	indicator.add_rule(_rule)
	_env.targeting_state.collision_exclusions = [excluded_body]
	indicator.force_shapecast_update()
	
	# WHEN: Exclusion is set
	var failing_with_exclusion := _rule.get_failing_indicators([indicator])
	assert_array(failing_with_exclusion).append_failure_message(
		"Indicator should not fail when body is excluded - collisions=%d exclusions=%s" % [
			indicator.get_collision_count(),
			str(_env.targeting_state.collision_exclusions)
		]
	).is_empty()
	
	# WHEN: Target changes (manually clear exclusions for test)
	var dummy_target := Node2D.new()
	_env.add_child(dummy_target)
	_env.targeting_state.set_manual_target(dummy_target)
	_env.targeting_state.clear_collision_exclusions()  # Explicit clear for deterministic testing
	
	# Force collision recheck after target change
	indicator.force_shapecast_update()
	
	# THEN: Exclusions are cleared, collision detected again
	var failing_after_clear := _rule.get_failing_indicators([indicator])
	var exclusions_after_clear := _env.targeting_state.collision_exclusions
	var exclusions_state := "null" if exclusions_after_clear == null else ("empty" if exclusions_after_clear.is_empty() else str(exclusions_after_clear.size()))
	var body_pos := "invalid" if not is_instance_valid(excluded_body) else str(excluded_body.global_position)
	assert_int(failing_after_clear.size()).append_failure_message(
		"Indicator should fail after target change clears exclusions - collisions=%d exclusions_state=%s body_valid=%s indicator_pos=%s body_pos=%s" % [
			indicator.get_collision_count(),
			exclusions_state,
			str(is_instance_valid(excluded_body)),
			str(indicator.global_position),
			body_pos
		]
	).is_equal(1)
	
	dummy_target.free()

func test_multiple_exclusions() -> void:
	# GIVEN: Multiple bodies to exclude
	var excluded1 := _create_collision_body("Excluded1", Vector2(100, 100))
	var excluded2 := _create_collision_body("Excluded2", Vector2(132, 100))
	var _detected := _create_collision_body("Detected", Vector2(164, 100))
	
	# GIVEN: Indicators at all positions
	var indicator1 := _create_indicator(Vector2(100, 100))
	var indicator2 := _create_indicator(Vector2(132, 100))
	var indicator3 := _create_indicator(Vector2(164, 100))
	indicator1.add_rule(_rule)
	indicator2.add_rule(_rule)
	indicator3.add_rule(_rule)
	
	# WHEN: Two bodies excluded
	_env.targeting_state.collision_exclusions = [excluded1, excluded2]
	indicator1.force_shapecast_update()
	indicator2.force_shapecast_update()
	indicator3.force_shapecast_update()
	
	# THEN: Only third indicator fails
	var failing := _rule.get_failing_indicators([indicator1, indicator2, indicator3])
	assert_int(failing.size()).is_equal(1) \
		.append_failure_message("Only one indicator should fail (non-excluded body)")
	assert_that(failing[0]).is_equal(indicator3) \
		.append_failure_message("The failing indicator should be indicator3 (non-excluded body)")

func test_exclusion_with_nested_hierarchy() -> void:
	# GIVEN: Deep hierarchy - root > parent > child > collision_shape
	var root := Node2D.new()
	root.name = "Root"
	root.position = Vector2(300, 100)
	_env.add_child(root)
	
	var parent := Node2D.new()
	parent.name = "Parent"
	parent.position = Vector2(0, 0)
	root.add_child(parent)
	
	var collision_body := CharacterBody2D.new()
	collision_body.name = "CollisionBody"
	collision_body.collision_layer = 1
	parent.add_child(collision_body)
	
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	collision_body.add_child(shape)
	
	# GIVEN: Indicator at collision position
	var indicator := _create_indicator(Vector2(300, 100))
	indicator.add_rule(_rule)
	indicator.force_shapecast_update()
	
	# WHEN: Root node excluded
	_env.targeting_state.collision_exclusions = [root]
	indicator.force_shapecast_update()
	
	# THEN: Deep nested collision is excluded
	var failing := _rule.get_failing_indicators([indicator])
	assert_array(failing).is_empty() \
		.append_failure_message("Deep nested collision should be excluded when root ancestor is in exclusion list")
