## Regression test for indicator generation on transformed objects during move operations.
##
## BUG: When moving an object that has been previously transformed (rotated, flipped),
## indicators fail to generate in correct locations and with correct transforms.
##
## Issues tested:
## 1. Indicator COUNT: Transformed objects should generate same number of indicators as untransformed
## 2. Indicator ROTATION: Indicators should inherit rotation from moved object
## 3. Indicator FLIP: Indicators should inherit flip (scale.x = -1) from moved object
##
## Test objects: Any object works, but Smithy is good test case (64x64 multi-tile)
##
## Expected behavior:
## - Moving object with rotation=90° should generate SAME indicator count as rotation=0°
## - Indicators should be rotated to match object rotation
## - Indicators should be flipped if object is flipped
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _env: AllSystemsTestEnvironment
var _manipulation_system: ManipulationSystem
var _indicator_manager: IndicatorManager
var _targeting_state: GridTargetingState
var _manipulation_parent: Node2D

const ROTATION_PRECISION := 0.01
const SCALE_PRECISION := 0.01

func before_test() -> void:
	# Use scene_runner for reliable frame simulation
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames
	
	_env = runner.scene() as AllSystemsTestEnvironment
	assert_that(_env).is_not_null()
	
	# Get systems
	var container := _env.get_container()
	_manipulation_system = _env.manipulation_system
	_indicator_manager = _env.indicator_manager
	_targeting_state = container.get_states().targeting
	
	# Get manipulation parent from state API (not as child node)
	_manipulation_parent = container.get_states().manipulation.parent
	assert_that(_manipulation_parent).is_not_null()

func after_test() -> void:
	# Clear collision exclusions to prevent test isolation issues
	if _env and _targeting_state:
		_targeting_state.collision_exclusions = []
	runner = null
	_env = null
	_manipulation_system = null
	_indicator_manager = null
	_targeting_state = null
	_manipulation_parent = null

## Helper to create a manipulatable object with collision
func _create_test_object(p_name: String, p_position: Vector2, p_size: Vector2 = Vector2(64, 64)) -> Node2D:
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
	manipulatable.root = root
	var man_settings := ManipulatableSettings.new()
	man_settings.movable = true
	man_settings.rotatable = true
	man_settings.flip_horizontal = true
	manipulatable.settings = man_settings
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
	auto_free(root)  # Prevent orphan nodes
	runner.simulate_frames(2)  # Let physics settle
	
	return root

## Helper to get all indicators under ManipulationParent
func _get_current_indicators() -> Array[RuleCheckIndicator]:
	var indicators: Array[RuleCheckIndicator] = []
	
	if not _manipulation_parent:
		return indicators
	
	# Search for IndicatorManager under ManipulationParent
	var indicator_manager_node := _manipulation_parent.get_node_or_null("IndicatorManager")
	if not indicator_manager_node:
		return indicators
	
	# Collect all RuleCheckIndicator children
	for child in indicator_manager_node.get_children():
		if child is RuleCheckIndicator:
			indicators.append(child)
	
	return indicators

## Helper to format object transform state for diagnostics
func _format_transform_state(object: Node2D) -> String:
	return "pos=%s rot=%.1f° scale=%s" % [
		str(object.global_position),
		object.global_rotation_degrees,
		str(object.scale)
	]

## Helper to format indicator diagnostic info
func _format_indicators_debug(indicators: Array[RuleCheckIndicator], object_name: String) -> String:
	if indicators.is_empty():
		return "No indicators generated"
	
	var rotations: Array[float] = []
	var scales: Array[Vector2] = []
	for ind in indicators:
		rotations.append(ind.global_rotation_degrees)
		scales.append(ind.scale)
	
	return "Object '%s' generated %d indicators: rotations=[%s] scales=[%s]" % [
		object_name,
		indicators.size(),
		_format_float_array(rotations),
		_format_vector_array(scales)
	]

## Helper to format float array for diagnostics
func _format_float_array(arr: Array[float]) -> String:
	var formatted: Array[String] = []
	for val in arr:
		formatted.append("%.1f°" % val)
	return ", ".join(formatted)

## Helper to format Vector2 array for diagnostics
func _format_vector_array(arr: Array[Vector2]) -> String:
	var formatted: Array[String] = []
	for vec in arr:
		formatted.append("(%.2f,%.2f)" % [vec.x, vec.y])
	return ", ".join(formatted)

## Helper to start move operation and return indicators with validation
## Returns null if move fails (with assertion failure explaining why)
func _start_move_and_get_indicators(object: Node2D) -> Array[RuleCheckIndicator]:
	# Position targeting system over object
	var object_center := object.global_position
	_targeting_state.positioner.global_position = object_center
	runner.simulate_frames(1)
	
	# Start move (returns move data)
	var move_data := _manipulation_system.try_move(object)
	
	# CRITICAL: Validate move succeeded before continuing
	if not move_data or move_data.status != GBEnums.Status.STARTED:
		var status_name := "NULL" if not move_data else str(move_data.status)
		var error_msg := "" if not move_data else move_data.message
		assert_bool(false).append_failure_message(
			"SETUP FAILURE: try_move() failed for '%s'. Status=%s Message='%s' Transform=%s. " +
			"Cannot test indicators without successful move operation!" % 
			[object.name, status_name, error_msg, _format_transform_state(object)]
		).is_true()
		return []  # Return empty on failure
	
	runner.simulate_frames(2)  # Wait for indicators to generate
	
	# Get indicators
	var indicators := _get_current_indicators()
	
	# CRITICAL: Validate indicators were generated before continuing
	if indicators.is_empty():
		assert_bool(false).append_failure_message(
			"SETUP FAILURE: No indicators generated after successful move. " +
			"Object='%s' Transform=%s ManipulationParent exists=%s" % 
			[object.name, _format_transform_state(object), str(_manipulation_parent != null)]
		).is_true()
	
	return indicators

func test_rotated_object_generates_same_indicator_count_as_unrotated() -> void:
	## Test: Object with 90° rotation should generate SAME number of indicators as 0° rotation
	## Setup: Create two identical objects, rotate one
	## Act: Start move on both objects
	## Assert: Indicator counts are equal
	
	# Create unrotated object
	var object_unrotated := _create_test_object("TestObject_0deg", Vector2(200, 200), Vector2(64, 64))
	var indicators_unrotated := _start_move_and_get_indicators(object_unrotated)
	if indicators_unrotated.is_empty():
		return  # Setup failed - error already reported by helper
	
	var count_unrotated := indicators_unrotated.size()
	
	# Stop move
	_manipulation_system.cancel()
	runner.simulate_frames(1)
	
	# Create rotated object (90 degrees)
	var object_rotated := _create_test_object("TestObject_90deg", Vector2(400, 200), Vector2(64, 64))
	object_rotated.global_rotation_degrees = 90.0
	runner.simulate_frames(1)
	
	var indicators_rotated := _start_move_and_get_indicators(object_rotated)
	if indicators_rotated.is_empty():
		return  # Setup failed - error already reported by helper
	
	var count_rotated := indicators_rotated.size()
	
	# Assert: Same indicator count regardless of rotation
	var rotation_msg := "INDICATOR COUNT BUG: Rotated object (90°) generated %d indicators, but unrotated generated %d. Rotation should NOT affect indicator count! %s vs %s" % [count_rotated, count_unrotated, _format_indicators_debug(indicators_rotated, object_rotated.name), _format_indicators_debug(indicators_unrotated, object_unrotated.name)]
	assert_int(count_rotated).append_failure_message(rotation_msg).is_equal(count_unrotated)

func test_rotated_object_at_various_angles_generates_consistent_indicator_count() -> void:
	## Test: Objects rotated at different angles should all generate same indicator count
	## Setup: Create objects at 0°, 45°, 90°, 180°, 270° rotation
	## Act: Start move on each
	## Assert: All generate same indicator count
	
	var rotation_angles: Array[float] = [0.0, 45.0, 90.0, 180.0, 270.0]
	var indicator_counts: Dictionary = {}  # angle -> count
	var baseline_count: int = -1
	
	for angle in rotation_angles:
		var object := _create_test_object("TestObject_%ddeg" % int(angle), Vector2(200 + angle, 200), Vector2(64, 64))
		object.global_rotation_degrees = angle
		runner.simulate_frames(1)
		
		var indicators := _start_move_and_get_indicators(object)
		if indicators.is_empty():
			return  # Setup failed - error already reported
		
		indicator_counts[angle] = indicators.size()
		
		# Store baseline from first iteration
		if baseline_count == -1:
			baseline_count = indicators.size()
		else:
			# FAIL FAST: Check immediately instead of accumulating failures
			if indicators.size() != baseline_count:
				var angle_msg := "INDICATOR COUNT BUG: Object at %.0f° generated %d indicators, but 0° generated %d. All rotations should generate SAME count! Stopping test to avoid spam." % [angle, indicators.size(), baseline_count]
				assert_int(indicators.size()).append_failure_message(angle_msg).is_equal(baseline_count)
				return  # Stop test after first failure
		
		# Stop move for next iteration
		_manipulation_system.cancel()
		runner.simulate_frames(1)

func test_indicators_inherit_rotation_from_moved_object() -> void:
	## Test: Indicators should be rotated to match object rotation during move
	## Setup: Create object with 90° rotation
	## Act: Start move operation
	## Assert: Indicators have same rotation as object
	
	# Create and rotate object
	var object := _create_test_object("RotatedObject", Vector2(300, 300), Vector2(64, 64))
	var rotation_amount := deg_to_rad(90.0)
	object.global_rotation = rotation_amount
	runner.simulate_frames(1)
	
	# Start move and get indicators
	var indicators := _start_move_and_get_indicators(object)
	if indicators.is_empty():
		return  # Setup failed - error already reported
	
	# Assert: Each indicator should have same rotation as object
	# Note: Indicators inherit rotation through ManipulationParent transform hierarchy
	var expected_rotation := object.global_rotation
	var first_failure := true
	
	for indicator in indicators:
		var indicator_rotation := indicator.global_rotation
		if not is_equal_approx(indicator_rotation, expected_rotation):
			if first_failure:
				assert_float(indicator_rotation).append_failure_message(
					"ROTATION INHERITANCE BUG: Indicator rotation %.1f° doesn't match object rotation %.1f°. " +
					"Indicators should inherit rotation from moved object! Object=%s %s" % 
					[rad_to_deg(indicator_rotation), rad_to_deg(expected_rotation),
					 object.name, _format_indicators_debug(indicators, object.name)]
				).is_equal_approx(expected_rotation, ROTATION_PRECISION)
				return  # FAIL FAST: Stop after first mismatch to avoid spam

func test_flipped_object_generates_same_indicator_count() -> void:
	## Test: Horizontally flipped object should generate same indicator count as normal
	## Setup: Create two objects, flip one horizontally
	## Act: Start move on both
	## Assert: Same indicator count
	
	# Create normal object
	var object_normal := _create_test_object("NormalObject", Vector2(200, 400), Vector2(64, 64))
	var indicators_normal := _start_move_and_get_indicators(object_normal)
	if indicators_normal.is_empty():
		return  # Setup failed
	
	var count_normal := indicators_normal.size()
	
	# Stop move
	_manipulation_system.cancel()
	runner.simulate_frames(1)
	
	# Create flipped object (scale.x = -1)
	var object_flipped := _create_test_object("FlippedObject", Vector2(400, 400), Vector2(64, 64))
	object_flipped.scale.x = -1.0  # Horizontal flip
	runner.simulate_frames(1)
	
	var indicators_flipped := _start_move_and_get_indicators(object_flipped)
	if indicators_flipped.is_empty():
		return  # Setup failed
	
	var count_flipped := indicators_flipped.size()
	
	# Assert: Same indicator count regardless of flip
	var flip_msg := "INDICATOR COUNT BUG: Flipped object generated %d indicators, but normal generated %d. Flip should NOT affect indicator count! %s vs %s" % [count_flipped, count_normal, _format_indicators_debug(indicators_flipped, object_flipped.name), _format_indicators_debug(indicators_normal, object_normal.name)]
	\t# Assert: Same indicator count regardless of flip\n\tvar flip_msg := \"INDICATOR COUNT BUG: Flipped object generated %d indicators, but normal generated %d. Flip should NOT affect indicator count! %s vs %s\" % [count_flipped, count_normal, _format_indicators_debug(indicators_flipped, object_flipped.name), _format_indicators_debug(indicators_normal, object_normal.name)]\n\tassert_int(count_flipped).append_failure_message(flip_msg).is_equal(count_normal)\n\nfunc test_indicators_inherit_flip_from_moved_object() -> void:
	## Test: Indicators should inherit horizontal flip (scale.x = -1) from moved object
	## Setup: Create object with horizontal flip
	## Act: Start move operation
	## Assert: Indicators have same flip state as object
	
	# Create and flip object
	var object := _create_test_object("FlippedObject", Vector2(300, 500), Vector2(64, 64))
	object.scale.x = -1.0  # Horizontal flip
	runner.simulate_frames(1)
	
	# Start move and get indicators
	var indicators := _start_move_and_get_indicators(object)
	if indicators.is_empty():
		return  # Setup failed
	
	# Assert: Each indicator should have same flip state as object
	# Note: Indicators inherit scale through ManipulationParent transform hierarchy
	var expected_scale_x := object.scale.x
	var first_failure := true
	
	for indicator in indicators:
		var indicator_scale_x := indicator.scale.x
		if not is_equal_approx(indicator_scale_x, expected_scale_x):
			if first_failure:
				assert_float(indicator_scale_x).append_failure_message(
					"FLIP INHERITANCE BUG: Indicator scale.x %.2f doesn't match object scale.x %.2f. " +
					"Indicators should inherit flip from moved object! Object=%s %s" % 
					[indicator_scale_x, expected_scale_x, object.name,
					 _format_indicators_debug(indicators, object.name)]
				).is_equal_approx(expected_scale_x, SCALE_PRECISION)
				return  # FAIL FAST: Stop after first mismatch

func test_combined_rotation_and_flip_generates_correct_indicators() -> void:
	## Test: Object with BOTH rotation AND flip should generate correct indicators
	## Setup: Create object with 90° rotation AND horizontal flip
	## Act: Start move
	## Assert: Indicators inherit both transforms
	
	# Get baseline count for comparison
	var baseline_object := _create_test_object("BaselineObject", Vector2(200, 600), Vector2(64, 64))
	var baseline_indicators := _start_move_and_get_indicators(baseline_object)
	if baseline_indicators.is_empty():
		return  # Setup failed
	var baseline_count := baseline_indicators.size()
	_manipulation_system.cancel()
	runner.simulate_frames(1)
	
	# Create object with combined transforms
	var object := _create_test_object("RotatedFlippedObject", Vector2(300, 600), Vector2(64, 64))
	object.global_rotation_degrees = 90.0
	object.scale.x = -1.0  # Horizontal flip
	runner.simulate_frames(1)
	
	# Start move and get indicators
	var indicators := _start_move_and_get_indicators(object)
	if indicators.is_empty():
		return  # Setup failed
	
	# Assert: Same count as baseline
	var count_message := "INDICATOR COUNT BUG: Object with rotation+flip generated %d indicators, but baseline generated %d. Combined transforms should NOT affect count! %s" % [indicators.size(), baseline_count, _format_indicators_debug(indicators, object.name)]
	assert_int(indicators.size()).append_failure_message(count_message).is_equal(baseline_count)
	
	# If count is wrong, stop here to avoid spam
	if indicators.size() != baseline_count:
		return
	
	# Assert: Indicators inherit both rotation and flip
	var expected_rotation := object.global_rotation
	var expected_scale_x := object.scale.x
	var first_rotation_failure := true
	var first_scale_failure := true
	
	for indicator in indicators:
		# Check rotation
		if not is_equal_approx(indicator.global_rotation, expected_rotation):
			if first_rotation_failure:
				assert_float(indicator.global_rotation).append_failure_message(
					"COMBINED TRANSFORM BUG: Indicator rotation %.1f° doesn't match object %.1f°. " +
					"Indicators should inherit BOTH rotation AND flip!" % 
					[rad_to_deg(indicator.global_rotation), rad_to_deg(expected_rotation)]
				).is_equal_approx(expected_rotation, ROTATION_PRECISION)
				first_rotation_failure = false
				return  # Stop after first failure
		
		# Check scale
		if not is_equal_approx(indicator.scale.x, expected_scale_x):
			if first_scale_failure:
				assert_float(indicator.scale.x).append_failure_message(
					"COMBINED TRANSFORM BUG: Indicator scale.x %.2f doesn't match object %.2f. " +
					"Indicators should inherit BOTH rotation AND flip!" % 
					[indicator.scale.x, expected_scale_x]
				).is_equal_approx(expected_scale_x, SCALE_PRECISION)
				first_scale_failure = false
				return  # Stop after first failure
