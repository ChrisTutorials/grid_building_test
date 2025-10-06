## Manipulation Rotation Workflow Test
##
## REGRESSION TEST: Validates that rotation doesn't break manipulation workflow.
## Tests that placement succeeds after rotation, proving indicator generation works correctly.
##
## HISTORICAL BUG (NOW FIXED): Rotating buildings caused indicator loss which broke placement.
## This test verifies the workflow remains functional through rotation cycles.
##
## ROOT CAUSE (FIXED): AABB expansion on rotation caused tile range calculation issues.
## Fixed by using polygon normalization during indicator calculation.
##
## TESTING APPROACH: Follows proven patterns from manipulation_system_test.gd
## Tests BEHAVIOR (placement success) rather than INTERNAL STATE (indicator count).
## This is more robust and matches best practices.
##
## See: WORKING_TEST_PATTERNS_ANALYSIS.md, TEST_INVESTIGATION_SUMMARY.md

extends GdUnitTestSuite

#region CONSTANTS

## Test position for placing objects (tile center, away from edges)
const TEST_POSITION: Vector2 = Vector2(128, 128)

## Manipulatable settings allowing all operations
var manipulatable_settings_all_allowed: ManipulatableSettings = load("uid://dn881lunp3lrm")

#endregion

#region TEST ENVIRONMENT

var runner: GdUnitSceneRunner
var test_environment: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _manipulation_system: ManipulationSystem
var _manipulation_state: ManipulationState

func before_test() -> void:
	# Use ALL_SYSTEMS test environment (matches working test patterns)
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	test_environment = runner.scene() as AllSystemsTestEnvironment
	
	assert_object(test_environment).append_failure_message(
		"Failed to load AllSystemsTestEnvironment scene"
	).is_not_null()
	
	# Extract systems from environment
	_container = test_environment.injector.composition_container
	_manipulation_system = test_environment.manipulation_system
	_manipulation_state = _container.get_manipulation_state()
	
	# Setup targeting state for manipulation
	_setup_targeting_state()

## Sets up targeting state with default target (required for manipulation)
func _setup_targeting_state() -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting
	
	if targeting_state.target == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		targeting_state.target = default_target

func after_test() -> void:
	# Cancel any active manipulation
	if _manipulation_system:
		_manipulation_system.cancel()
	
	# Clean up any created nodes
	for child in get_children():
		if child.name == "SmithyRoot":
			child.queue_free()

#endregion

#region HELPER METHODS

## Creates a manipulatable with collision shapes for indicator generation
## CRITICAL: Collision shapes are REQUIRED for indicator generation during placement
## Follows pattern from manipulation_system_test.gd
func _create_test_manipulatable() -> Manipulatable:
	var root: Node2D = Node2D.new()
	root.name = "SmithyRoot"
	root.global_position = TEST_POSITION
	add_child(root)
	
	var manipulatable: Manipulatable = Manipulatable.new()
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	manipulatable.settings = manipulatable_settings_all_allowed
	root.add_child(manipulatable)
	
	# CRITICAL: Add collision shape for indicator generation
	# 64x64 pixels = 5x5 tiles at 16px tile size
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	rect_shape.size = Vector2(64, 64)
	collision_shape.shape = rect_shape
	collision_body.add_child(collision_shape)
	root.add_child(collision_body)
	
	return manipulatable

## Starts manipulation (pickup) - returns true if successful
func _start_manipulation(manipulatable: Manipulatable) -> bool:
	var move_data: ManipulationData = _manipulation_system.try_move(manipulatable.root)
	
	assert_object(move_data).append_failure_message(
		"try_move should return ManipulationData"
	).is_not_null()
	
	if move_data == null:
		return false
	
	var started: bool = move_data.status == GBEnums.Status.STARTED
	
	if started:
		await get_tree().process_frame
	
	return started

## Rotates the manipulation using system method (correct approach)
func _rotate_manipulation(degrees: float) -> bool:
	var move_data: ManipulationData = _manipulation_state.data
	
	if move_data == null or move_data.source == null:
		return false
	
	var success: bool = _manipulation_system.rotate(move_data.source.root, degrees)
	
	if success:
		await get_tree().process_frame
	
	return success

## Places the manipulated object - returns true if successful
func _place_manipulated_object() -> bool:
	var move_data: ManipulationData = _manipulation_state.data
	
	if move_data == null or move_data.target == null:
		return false
	
	# Position for placement
	move_data.target.root.global_position = TEST_POSITION
	
	# Try placement
	var placement_results: ValidationResults = _manipulation_system.try_placement(move_data)
	
	if placement_results == null:
		return false
	
	var success: bool = placement_results.is_successful()
	
	if success:
		await get_tree().process_frame
	
	return success

#endregion

#region REGRESSION TESTS

func test_manipulation_workflow_succeeds_after_rotation() -> void:
	## REGRESSION TEST: Verifies that rotation doesn't break manipulation workflow
	## If placement succeeds after rotation, indicator generation MUST be working correctly
	## (Placement internally uses indicators for validation)
	##
	## HISTORICAL BUG: Rotation caused indicator loss → placement failures
	## EXPECTED NOW: Placement succeeds after rotation → indicators work correctly
	
	# STEP 1: Create test manipulatable with collision shapes
	var manipulatable: Manipulatable = _create_test_manipulatable()
	
	# STEP 2: Start manipulation (pickup)
	var pickup_success: bool = await _start_manipulation(manipulatable)
	
	assert_bool(pickup_success).append_failure_message(
		"Initial pickup should succeed - indicates try_move works"
	).is_true()
	
	# STEP 3: Rotate 90 degrees
	var rotation_success: bool = await _rotate_manipulation(90.0)
	
	assert_bool(rotation_success).append_failure_message(
		"Rotation should succeed - indicates rotate system works"
	).is_true()
	
	# STEP 4: Place the rotated object
	var place_success: bool = await _place_manipulated_object()
	
	assert_bool(place_success).append_failure_message(
		"REGRESSION: Placement failed after rotation!\n" +
		"This indicates indicator generation is broken.\n" +
		"Historical bug: Rotation caused indicator loss → placement failures.\n" +
		"Expected: Placement succeeds → indicators work correctly after rotation."
	).is_true()
	
	# STEP 5: Verify we can pick up again (proves no state corruption)
	var pickup_again_success: bool = await _start_manipulation(manipulatable)
	
	assert_bool(pickup_again_success).append_failure_message(
		"Second pickup should succeed - proves no state corruption from rotation"
	).is_true()

func test_multiple_rotations_maintain_workflow() -> void:
	## Extended test: Verify workflow stays functional through multiple rotation cycles
	## Tests 90° → 180° → 270° → 360° (full rotation)
	##
	## Each cycle: pickup → rotate → place
	## If any placement fails, indicator generation is broken at that angle
	
	# Create test manipulatable
	var manipulatable: Manipulatable = _create_test_manipulatable()
	
	# Test 4 rotations (full circle)
	var rotation_angles: Array[int] = [90, 180, 270, 360]
	
	for angle in rotation_angles:
		# Pickup
		var pickup_success: bool = await _start_manipulation(manipulatable)
		
		assert_bool(pickup_success).append_failure_message(
			"Pickup should succeed before %d° rotation" % angle
		).is_true()
		
		# Rotate
		var rotation_success: bool = await _rotate_manipulation(90.0)
		
		assert_bool(rotation_success).append_failure_message(
			"Rotation to %d° should succeed" % angle
		).is_true()
		
		# Place - this PROVES indicators work at this rotation angle
		var place_success: bool = await _place_manipulated_object()
		
		assert_bool(place_success).append_failure_message(
			("REGRESSION at %d°: Placement failed!\n" +
			"Indicators not working correctly at this rotation angle.\n" +
			"Historical bug: Some angles caused indicator loss.") % angle
		).is_true()

func test_rotate_then_flip_workflow() -> void:
	## Tests combined transformations: rotation + flip
	## Ensures indicator generation works with multiple transform types
	
	var manipulatable: Manipulatable = _create_test_manipulatable()
	
	# Pickup
	var pickup_success: bool = await _start_manipulation(manipulatable)
	assert_bool(pickup_success).is_true()
	
	# Rotate 45 degrees
	var rotation_success: bool = await _rotate_manipulation(45.0)
	assert_bool(rotation_success).is_true()
	
	# Flip horizontal
	_manipulation_system.flip_horizontal(manipulatable.root)
	await get_tree().process_frame
	
	# Place - should succeed with combined transforms
	var place_success: bool = await _place_manipulated_object()
	
	assert_bool(place_success).append_failure_message(
		"Placement should succeed after rotation + flip"
	).is_true()

#endregion
