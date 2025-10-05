## CRITICAL REGRESSION TEST: Placement validation failure should prevent movement
##
## This test validates that when manipulation placement validation fails,
## the source object is NOT moved to the target position. This is a critical
## bug where collision rule violations still result in object placement.
##
## Bug Description:
## When try_placement() validation fails (e.g., collision rules violated),
## the system correctly reports failure but still applies the movement
## transforms to the source object. This allows invalid placements.
##
## Expected Behavior:
## - Validation fails → Object remains in original position
## - Validation succeeds → Object moves to target position
##
## Test Coverage:
## - Collision rule validation failure scenario
## - Position preservation when validation fails
## - Proper cleanup of target copy on validation failure
## - Status reporting accuracy (FAILED vs FINISHED)

extends GdUnitTestSuite
@warning_ignore("unused_parameter")

#region Test Environment
var test_hierarchy: AllSystemsTestEnvironment
var manipulation_system: ManipulationSystem
var _container: GBCompositionContainer
var collision_body: StaticBody2D
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Create test environment with manipulation system
	test_hierarchy = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	_container = test_hierarchy.get_container()
	manipulation_system = test_hierarchy.manipulation_system
	
	# Set up targeting state for manipulation tests
	_setup_targeting_state()

func _setup_targeting_state() -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting
	if targeting_state.target == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		targeting_state.target = default_target
#endregion

#region Helper Methods
func _create_test_manipulatable_with_collision_rules() -> Manipulatable:
	"""Create a manipulatable object with collision checking rules enabled."""
	var root: Node2D = auto_free(Node2D.new())
	add_child(root)
	root.position = Vector2(32, 32)  # Initial position
	
	# Add collision shape to the root so indicators can be generated
	var test_collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	var test_collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var test_rect_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	test_rect_shape.size = Vector2(32, 32)
	test_collision_shape.shape = test_rect_shape
	test_collision_body.add_child(test_collision_shape)
	root.add_child(test_collision_body)
	
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	
	# Use settings with collision rules that will fail
	var collision_settings: ManipulatableSettings = load("uid://5u2sgj1wk4or")  # 2 rules, 1 tile check
	manipulatable.settings = collision_settings
	manipulatable.root = root
	root.add_child(manipulatable)
	
	return manipulatable

func _create_collision_obstacle_at_position(position: Vector2) -> StaticBody2D:
	"""Create a collision obstacle that will cause validation to fail."""
	var obstacle: StaticBody2D = auto_free(StaticBody2D.new())
	add_child(obstacle)
	obstacle.global_position = position
	
	# Add collision shape
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	obstacle.add_child(collision_shape)
	
	# Set collision layer to trigger rule violations
	obstacle.collision_layer = 1  # Default layer that should cause conflicts
	
	return obstacle
#endregion

#region Regression Tests

## CRITICAL REGRESSION TEST: Validation failure must prevent object movement
## 
## Bug: When try_placement() validation fails due to collision rules,
## the source object is still moved to the target position despite the failure.
## 
## Expected: Object should remain at original position when validation fails.
func test_validation_failure_prevents_object_movement() -> void:
	# Setup: Create manipulatable with collision rules
	var manipulatable: Manipulatable = _create_test_manipulatable_with_collision_rules()
	var original_position: Vector2 = manipulatable.root.global_position
	
	# Setup: Create collision obstacle at target position to cause validation failure
	var target_position: Vector2 = Vector2(96, 96)
	collision_body = _create_collision_obstacle_at_position(target_position)
	
	# Act: Start move operation
	var move_data: ManipulationData = manipulation_system.try_move(manipulatable.root)
	assert_that(move_data).append_failure_message(
		"Move should start successfully"
	).is_not_null()
	
	assert_int(move_data.status).append_failure_message(
		"Move should be in STARTED status"
	).is_equal(GBEnums.Status.STARTED)
	
	# Act: Move target to collision position and attempt placement
	move_data.target.root.global_position = target_position
	
	# Act: Try placement - should fail due to collision
	var validation_results: ValidationResults = await manipulation_system.try_placement(move_data)
	
	# Assert: Validation should fail
	assert_that(validation_results).append_failure_message(
		"Validation results should not be null"
	).is_not_null()
	
	assert_bool(validation_results.is_successful()).append_failure_message(
		"Validation should fail due to collision at target position. Issues: %s" % 
		str(validation_results.get_issues())
	).is_false()
	
	# Assert: Move status should be FAILED (not FINISHED)
	assert_int(move_data.status).append_failure_message(
		"Move status should be FAILED after validation failure"
	).is_equal(GBEnums.Status.FAILED)
	
	# CRITICAL ASSERTION: Source object should NOT have moved
	assert_vector(manipulatable.root.global_position).append_failure_message(
		"CRITICAL BUG: Source object moved despite validation failure! " +
		"Original: %s, Current: %s, Target: %s. " % [
			str(original_position), 
			str(manipulatable.root.global_position),
			str(target_position)
		] +
		"Validation failure should prevent movement."
	).is_equal(original_position)

## Test: Successful validation allows object movement (control test)
##
## This test ensures that when validation succeeds, the object DOES move.
## This serves as a control to verify the test setup is correct.
func test_validation_success_allows_object_movement() -> void:
	# Setup: Create manipulatable with permissive rules
	var root: Node2D = auto_free(Node2D.new())
	add_child(root)
	root.position = Vector2(32, 32)
	
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	var all_allowed_settings: ManipulatableSettings = load("uid://dn881lunp3lrm")  # All allowed
	manipulatable.settings = all_allowed_settings
	manipulatable.root = root
	root.add_child(manipulatable)
	
	var original_position: Vector2 = manipulatable.root.global_position
	var target_position: Vector2 = Vector2(128, 128)  # Clear area
	
	# Act: Start move operation
	var move_data: ManipulationData = manipulation_system.try_move(manipulatable.root)
	assert_that(move_data).is_not_null()
	
	# Act: Move to clear area and attempt placement
	move_data.target.root.global_position = target_position
	var validation_results: ValidationResults = await manipulation_system.try_placement(move_data)
	
	# Assert: Validation should succeed
	assert_bool(validation_results.is_successful()).append_failure_message(
		"Validation should succeed in clear area. Issues: %s" % 
		str(validation_results.get_issues())
	).is_true()
	
	# Assert: Object should have moved to target position
	assert_vector(manipulatable.root.global_position).append_failure_message(
		"Object should move to target position when validation succeeds. " +
		"Original: %s, Expected: %s, Actual: %s" % [
			str(original_position),
			str(target_position), 
			str(manipulatable.root.global_position)
		]
	).is_equal(target_position)

#endregion