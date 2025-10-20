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
##
## IMPORTANT: Architecture Pattern (v5.x)
## As of v5.x, GridTargetingState is the single source of truth for the target node.
## 
## The correct pattern for manipulation tests:
## 1. Create a manipulatable object
## 2. Set targeting_state to target that manipulatable (before calling try_move)
## 3. Call manipulation_system.try_move() - it will use targeting_state.get_target()
## 4. The returned ManipulationData.source contains the found Manipulatable component
##
## DO NOT pass the manipulatable directly expecting it to be used as target.
## The system uses targeting_state as the single source of truth.

extends GdUnitTestSuite
@warning_ignore("unused_parameter")

const ManipulationHelpers := preload("res://test/grid_building_test/regressions/manipulation/manipulation_test_helpers.gd")

#region Test Environment
var runner: GdUnitSceneRunner
var env: AllSystemsTestEnvironment
var manipulation_system: ManipulationSystem
var _container: GBCompositionContainer
var collision_body: StaticBody2D
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Use scene_runner for proper frame control
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	env = runner.scene() as AllSystemsTestEnvironment
	
	# Get systems from test environment properties
	manipulation_system = env.manipulation_system
	_container = env.get_container()
	
	# Wait for systems to initialize
	runner.simulate_frames(2)
	
	# Set up targeting state for manipulation tests
	_setup_targeting_state()

func _setup_targeting_state() -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting
	if targeting_state.get_target() == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		env.add_child(default_target)
		targeting_state.set_manual_target(default_target)
#endregion

#region Helper Methods
func _create_test_manipulatable_with_collision_rules() -> Manipulatable:
	"""Create a manipulatable object with collision checking rules enabled."""
	# Use ManipulationHelpers which properly sets up rules
	var manipulatable: Manipulatable = ManipulationHelpers.create_test_manipulatable(
		self,
		"TestManipulatable",
		Vector2(32, 32),
		Vector2(32, 32),
		true  # with_move_rules = true
	)
	
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
##
## SETUP PATTERN (v5.x Architecture):
## 1. Create manipulatable object
## 2. IMPORTANT: Call targeting_state.set_manual_target(manipulatable.root) BEFORE try_move()
##    This establishes targeting_state as the single source of truth for the target
## 3. Call manipulation_system.try_move() - uses targeting_state.get_target() internally
## 4. The returned ManipulationData.source will contain the Manipulatable component found
func test_validation_failure_prevents_object_movement() -> void:
	# Setup: Create manipulatable with collision rules
	var manipulatable: Manipulatable = ManipulationHelpers.create_test_manipulatable(
		env,
		"TestManipulatable",
		Vector2(32, 32),
		Vector2(32, 32),
		true  # with_move_rules = true
	)
	var original_position: Vector2 = manipulatable.root.global_position
	
	# CRITICAL: Update targeting_state BEFORE calling try_move()
	# targeting_state is now the single source of truth for which node is being manipulated
	var targeting_state: GridTargetingState = _container.get_states().targeting
	targeting_state.set_manual_target(manipulatable.root)
	
	# Setup: Create collision obstacle at target position to cause validation failure
	var target_position: Vector2 = Vector2(96, 96)
	collision_body = ManipulationHelpers.create_collision_obstacle(
		env,
		target_position,
		Vector2(32, 32),
		1  # Same collision layer as manipulatable body
	)
	
	# CRITICAL: Wait for physics to register the obstacle
	runner.simulate_frames(2, 60)  # 2 physics frames
	
	# Verify obstacle is in scene tree with proper setup
	assert_bool(collision_body.is_inside_tree()).append_failure_message("Obstacle should be in scene tree").is_true()
	assert_int(collision_body.get_child_count()).append_failure_message("Obstacle should have CollisionShape2D child").is_greater(0)
	
	if collision_body.get_child_count() > 0:
		var shape_node: CollisionShape2D = collision_body.get_child(0) as CollisionShape2D
		if shape_node:
			assert_object(shape_node.shape).append_failure_message("CollisionShape2D should have a shape").is_not_null()
	
	# Act: Start move operation
	var move_data: ManipulationData = manipulation_system.try_move(manipulatable.root)
	assert_that(move_data).append_failure_message(
		"Move should start successfully"
	).is_not_null()
	
	assert_int(move_data.status).append_failure_message(
		"Move should be in STARTED status, got: %s" % ManipulationHelpers.format_status(move_data.status)
	).is_equal(GBEnums.Status.STARTED)
	
	# Act: Move positioner to collision position (this moves preview AND indicators together)
	# The manipulation system parents the target to ManipulationParent, and indicators
	# are positioned relative to the target. Moving the positioner updates everything.
	targeting_state.positioner.global_position = target_position
	
	# Force indicators to regenerate at new position with collision detection
	var indicator_manager: IndicatorManager = env.indicator_manager
	var move_rules: Array[PlacementRule] = []
	move_rules.assign(move_data.source.get_move_rules())
	var setup_report := indicator_manager.try_setup(move_rules, targeting_state)
	
	assert_bool(setup_report.is_successful()).append_failure_message(
		"Indicator setup should succeed: %s" % str(setup_report.get_issues())
	).is_true()
	
	# Force validity evaluation at new position
	var updated_count := indicator_manager.force_indicators_validity_evaluation()
	assert_int(updated_count).append_failure_message(
		"Expected at least one indicator to be updated"
	).is_greater(0)
	
	# Act: Try placement (should fail validation due to collision)
	var validation_results: ValidationResults = manipulation_system.try_placement(move_data)
	
	# Assert: Validation should fail
	assert_that(validation_results).append_failure_message(
		"Validation results should not be null"
	).is_not_null()
	
	assert_bool(validation_results.is_successful()).append_failure_message(
		"Validation should fail due to collision at target position. Issues: %s" % 
		str(validation_results.get_issues())
	).is_false()
	
	# Assert: Move status should remain STARTED (to allow retry)
	# System keeps manipulation active so user can try placing elsewhere
	assert_int(move_data.status).append_failure_message(
		"Move status should remain STARTED after validation failure to allow retry, got: %s" % ManipulationHelpers.format_status(move_data.status)
	).is_equal(GBEnums.Status.STARTED)
	
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
## Uses NO collision rules to guarantee success.
##
## SETUP PATTERN (v5.x Architecture):
## 1. Create manipulatable object
## 2. IMPORTANT: Call targeting_state.set_manual_target(manipulatable.root) BEFORE try_move()
##    This establishes targeting_state as the single source of truth for the target
## 3. Call manipulation_system.try_move() - uses targeting_state.get_target() internally
## 4. The returned ManipulationData.source will contain the Manipulatable component found
func test_validation_success_allows_object_movement() -> void:
	# Setup: Create manipulatable WITHOUT collision rules
	# No rules means no validation constraints, placement always succeeds
	var manipulatable: Manipulatable = ManipulationHelpers.create_test_manipulatable(
		env,
		"TestManipulatable",
		Vector2(32, 32),
		Vector2(32, 32),
		false  # with_move_rules = false - no validation rules
	)
	
	# CRITICAL: Update targeting_state BEFORE calling try_move()
	# targeting_state is now the single source of truth for which node is being manipulated
	var targeting_state: GridTargetingState = _container.get_states().targeting
	targeting_state.set_manual_target(manipulatable.root)
	
	var original_position: Vector2 = manipulatable.root.global_position
	var target_position: Vector2 = Vector2(256, 256)
	
	# Act: Start move operation
	var move_data: ManipulationData = manipulation_system.try_move(manipulatable.root)
	assert_that(move_data).append_failure_message(
		"Move should start successfully"
	).is_not_null()
	
	# Act: Move to target and attempt placement
	move_data.move_copy.root.global_position = target_position
	var validation_results: ValidationResults = manipulation_system.try_placement(move_data)
	
	# Assert: Validation should succeed (no rules to fail)
	assert_bool(validation_results.is_successful()).append_failure_message(
		"Validation should succeed with no rules. Issues: %s" % 
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
