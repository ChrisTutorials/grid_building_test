## Unit tests for isometric rotation handling where nodes may be skewed and rotated
##
## Tests the manipulation system's ability to handle rotations correctly in isometric
## contexts where the base node hierarchy includes skew transforms and pre-existing rotations.
## These tests ensure that manipulation rotations work correctly regardless of the initial
## transform state of the isometric game setup.
##
## Key scenarios tested:
## - Base isometric setup (30° rotation + 30° skew + 3x scale)
## - 45° variations for comprehensive coverage  
## - Identity transforms for baseline comparison
## - Extreme values to test robustness
extends GdUnitTestSuite

#region TEST CONSTANTS

## Test transformation scenarios - covers various isometric setups
const TEST_SCENARIOS: Array[Dictionary] = [
	{
		"name": "identity_baseline",
		"base_rotation_deg": 0.0,
		"base_skew_deg": 0.0,
		"base_scale": Vector2(1, 1),
		"description": "Baseline case with no transforms"
	},
	{
		"name": "standard_isometric", 
		"base_rotation_deg": 30.0,
		"base_skew_deg": 30.0,
		"base_scale": Vector2(3, 3),
		"description": "Standard isometric setup from template"
	},
	{
		"name": "45_degree_isometric",
		"base_rotation_deg": 45.0,
		"base_skew_deg": 45.0, 
		"base_scale": Vector2(2, 2),
		"description": "45-degree isometric variation"
	},
	{
		"name": "negative_skew",
		"base_rotation_deg": 30.0,
		"base_skew_deg": -30.0,
		"base_scale": Vector2(1.5, 1.5),
		"description": "Negative skew isometric setup"
	},
	{
		"name": "extreme_values",
		"base_rotation_deg": 60.0,
		"base_skew_deg": 75.0,
		"base_scale": Vector2(4, 2),
		"description": "Extreme transform values"
	}
]

## Rotation test increments to apply during manipulation
const ROTATION_INCREMENTS: Array[float] = [0.0, 45.0, 90.0, 180.0, -45.0, -90.0]

## Tolerance for floating point comparison  
const ROTATION_TOLERANCE: float = 0.01

#endregion

#region TEST INFRASTRUCTURE

var _manipulation_parent: ManipulationParent
var _indicator_manager: Node2D
var _test_object: Node2D
var _base_transform_node: Node2D
var _test_indicators: Array[Node2D]

func before_test() -> void:
	# Create base isometric-style transform node (like GridTargeter)
	_base_transform_node = auto_free(Node2D.new())
	_base_transform_node.name = "IsometricTransformBase"
	add_child(_base_transform_node)
	
	# Create manipulation parent as child of transform base
	_manipulation_parent = auto_free(ManipulationParent.new())
	_manipulation_parent.name = "ManipulationParent" 
	_base_transform_node.add_child(_manipulation_parent)
	
	# Create indicator manager as child of manipulation parent
	_indicator_manager = auto_free(Node2D.new())
	_indicator_manager.name = "IndicatorManager"
	_manipulation_parent.add_child(_indicator_manager)
	
	# Create test manipulatable object as child of manipulation parent
	_test_object = auto_free(Node2D.new())
	_test_object.name = "TestIsometricObject"
	_manipulation_parent.add_child(_test_object)
	
	# Initialize test indicators array
	_test_indicators = []

func after_test() -> void:
	_test_indicators.clear()

func _transforms_equal(t1: Transform2D, t2: Transform2D, tolerance: float = ROTATION_TOLERANCE) -> bool:
	"""Compare two Transform2D objects with floating point tolerance"""
	return (
		abs(t1.get_rotation() - t2.get_rotation()) < tolerance and
		t1.get_origin().is_equal_approx(t2.get_origin()) and
		t1.get_scale().is_equal_approx(t2.get_scale()) and
		abs(t1.get_skew() - t2.get_skew()) < tolerance
	)

func _setup_isometric_base_transform(scenario: Dictionary) -> void:
	"""Apply base isometric transforms to the transform base node"""
	_base_transform_node.rotation_degrees = scenario.base_rotation_deg
	_base_transform_node.skew = deg_to_rad(scenario.base_skew_deg) 
	_base_transform_node.scale = scenario.base_scale

func _create_test_indicators(count: int = 3) -> Array[Node2D]:
	"""Create test indicators as children of indicator manager"""
	var indicators: Array[Node2D] = []
	
	for i in range(count):
		var indicator: Node2D = auto_free(Node2D.new())
		indicator.name = "TestIndicator%d" % i
		indicator.position = Vector2(i * 20, i * 10)  # Spread them out
		_indicator_manager.add_child(indicator)
		indicators.append(indicator)
	
	_test_indicators = indicators
	return indicators

## Normalize angle to Godot's standard -180 to 180 range
func _normalize_angle(angle: float) -> float:
	# Godot normalizes angles to -180 to 180 range
	while angle > 180.0:
		angle -= 360.0
	while angle <= -180.0:
		angle += 360.0
	return angle

## Check if two angles are equivalent (handles -180/+180 edge case)
func _angles_equivalent(angle1: float, angle2: float, tolerance: float = ROTATION_TOLERANCE) -> bool:
	var diff: float = abs(angle1 - angle2)
	# Handle the -180/+180 wraparound case
	if diff > 180.0:
		diff = 360.0 - diff
	return diff <= tolerance

func _capture_global_rotations() -> Dictionary:
	"""Capture current global rotations of all test nodes"""
	var indicator_rotations: Array[float] = []
	for indicator in _test_indicators:
		indicator_rotations.append(indicator.global_rotation_degrees)
	
	return {
		"base_transform": _base_transform_node.global_rotation_degrees,
		"manipulation_parent": _manipulation_parent.global_rotation_degrees,
		"indicator_manager": _indicator_manager.global_rotation_degrees,
		"test_object": _test_object.global_rotation_degrees,
		"indicators": indicator_rotations
	}

func _calculate_expected_rotation_delta(initial_rotations: Dictionary, applied_degrees: float) -> Dictionary:
	"""Calculate expected rotations after applying manipulation rotation"""
	var expected_indicator_rotations: Array[float] = []
	var initial_indicator_rotations: Array = initial_rotations.indicators
	for i in range(initial_indicator_rotations.size()):
		var rotation: float = initial_indicator_rotations[i]
		expected_indicator_rotations.append(_normalize_angle(rotation + applied_degrees))
	
	return {
		"base_transform": initial_rotations.base_transform,  # Should not change
		"manipulation_parent": _normalize_angle(initial_rotations.manipulation_parent + applied_degrees),
		"indicator_manager": _normalize_angle(initial_rotations.indicator_manager + applied_degrees),
		"test_object": _normalize_angle(initial_rotations.test_object + applied_degrees),
		"indicators": expected_indicator_rotations
	}

#endregion

#region PARAMETERIZED TESTS

## Test: Isometric rotation handling with various base transforms and rotation increments
## Setup: Apply base isometric transforms (rotation + skew + scale)
## Act: Apply manipulation rotation via ManipulationParent.apply_rotation()
## Assert: All children rotate correctly relative to their isometric base
@warning_ignore("unused_parameter")
func test_isometric_rotation_scenarios(
	scenario_name: String,
	base_rotation_deg: float,
	base_skew_deg: float, 
	base_scale: Vector2,
	rotation_increment: float,
	test_parameters := _generate_test_parameters()
) -> void:
	
	# Setup: Find the scenario configuration
	var scenario: Dictionary = {}
	for test_scenario in TEST_SCENARIOS:
		if test_scenario.name == scenario_name:
			scenario = test_scenario
			break
	
	assert_bool(not scenario.is_empty()).append_failure_message(
		"Test scenario '%s' not found in TEST_SCENARIOS" % scenario_name
	).is_true()
	
	# Setup: Apply base isometric transforms
	_setup_isometric_base_transform(scenario)
	
	# Setup: Create test indicators
	var indicators: Array[Node2D] = _create_test_indicators(3)
	
	# Allow scene tree to update transforms
	await get_tree().process_frame
	
	# Capture initial state
	var initial_rotations: Dictionary = _capture_global_rotations()
	
	# Act: Apply manipulation rotation
	_manipulation_parent.apply_rotation(rotation_increment)
	
	# Allow scene tree to update transforms  
	await get_tree().process_frame
	
	# Capture final state
	var final_rotations: Dictionary = _capture_global_rotations() 
	
	# Calculate expected rotations (normalized to Godot's -180 to 180 range)
	var expected_rotations: Dictionary = _calculate_expected_rotation_delta(initial_rotations, rotation_increment)
	
	# Assert: Base transform node should be unchanged
	assert_float(final_rotations.base_transform).append_failure_message(
		"Base transform rotation should be unchanged - Scenario: %s, Expected: %.2f, Got: %.2f" % 
		[scenario_name, expected_rotations.base_transform, final_rotations.base_transform]
	).is_equal_approx(expected_rotations.base_transform, ROTATION_TOLERANCE)
	
	# Assert: ManipulationParent should have applied rotation
	assert_bool(_angles_equivalent(final_rotations.manipulation_parent, expected_rotations.manipulation_parent)).append_failure_message(
		"ManipulationParent rotation mismatch - Scenario: %s, Applied: %.2f°, Expected: %.2f°, Got: %.2f°" %
		[scenario_name, rotation_increment, expected_rotations.manipulation_parent, final_rotations.manipulation_parent]
	).is_true()
	
	# Assert: IndicatorManager should inherit rotation from ManipulationParent
	assert_bool(_angles_equivalent(final_rotations.indicator_manager, expected_rotations.indicator_manager)).append_failure_message(
		"IndicatorManager should inherit rotation from ManipulationParent - Scenario: %s, Expected: %.2f°, Got: %.2f°" %
		[scenario_name, expected_rotations.indicator_manager, final_rotations.indicator_manager]
	).is_true()
	
	# Assert: Test object should inherit rotation from ManipulationParent  
	assert_bool(_angles_equivalent(final_rotations.test_object, expected_rotations.test_object)).append_failure_message(
		"Test object should inherit rotation from ManipulationParent - Scenario: %s, Expected: %.2f°, Got: %.2f°" %
		[scenario_name, expected_rotations.test_object, final_rotations.test_object]
	).is_true()
	
	# Assert: All indicators should inherit rotation from ManipulationParent
	for i in range(indicators.size()):
		var expected_indicator_rotation: float = expected_rotations.indicators[i]
		var actual_indicator_rotation: float = final_rotations.indicators[i]
		
		assert_bool(_angles_equivalent(actual_indicator_rotation, expected_indicator_rotation)).append_failure_message(
			"Indicator[%d] rotation mismatch - Scenario: %s, Expected: %.2f°, Got: %.2f°" %
			[i, scenario_name, expected_indicator_rotation, actual_indicator_rotation]
		).is_true()

## Test: Cumulative rotation behavior in isometric contexts
## Setup: Apply base isometric transforms
## Act: Apply multiple sequential rotations
## Assert: Rotations accumulate correctly without drift
@warning_ignore("unused_parameter") 
func test_isometric_cumulative_rotation(
	scenario_name: String,
	base_rotation_deg: float,
	base_skew_deg: float,
	base_scale: Vector2, 
	test_parameters := _generate_cumulative_test_parameters()
) -> void:
	
	# Setup: Find the scenario configuration
	var scenario: Dictionary = {}
	for test_scenario in TEST_SCENARIOS:
		if test_scenario.name == scenario_name:
			scenario = test_scenario
			break
	
	# Setup: Apply base isometric transforms
	_setup_isometric_base_transform(scenario)
	
	# Setup: Create test indicators
	var indicators: Array[Node2D] = _create_test_indicators(2)
	
	await get_tree().process_frame
	
	# Capture initial state
	var initial_rotations: Dictionary = _capture_global_rotations()
	
	# Act: Apply multiple sequential rotations
	var total_rotation: float = 0.0
	var rotation_steps: Array[float] = [45.0, 90.0, -30.0, 60.0]
	
	for step in rotation_steps:
		_manipulation_parent.apply_rotation(step)
		total_rotation += step
		await get_tree().process_frame
	
	# Capture final state
	var final_rotations: Dictionary = _capture_global_rotations()
	
	# Calculate expected total rotation (normalized)
	var expected_final_rotation: float = _normalize_angle(initial_rotations.manipulation_parent + total_rotation)
	
	# Assert: Cumulative rotation is correct
	assert_bool(_angles_equivalent(final_rotations.manipulation_parent, expected_final_rotation)).append_failure_message(
		"Cumulative rotation failed - Scenario: %s, Total applied: %.2f°, Expected: %.2f°, Got: %.2f°" %
		[scenario_name, total_rotation, expected_final_rotation, final_rotations.manipulation_parent]
	).is_true()
	
	# Assert: Indicators followed cumulative rotation
	for i in range(indicators.size()):
		var expected_indicator_rotation: float = _normalize_angle(initial_rotations.indicators[i] + total_rotation)
		var actual_indicator_rotation: float = final_rotations.indicators[i]
		
		assert_bool(_angles_equivalent(actual_indicator_rotation, expected_indicator_rotation)).append_failure_message(
			"Indicator[%d] cumulative rotation failed - Scenario: %s, Expected: %.2f°, Got: %.2f°" %
			[i, scenario_name, expected_indicator_rotation, actual_indicator_rotation]
		).is_true()## Test: Transform isolation - manipulation transforms should not affect base isometric setup
## Setup: Apply base isometric transforms and manipulation transforms
## Act: Reset manipulation parent transform  
## Assert: Base transforms remain unchanged, only manipulation transforms reset
@warning_ignore("unused_parameter")
func test_isometric_transform_isolation(
	scenario_name: String,
	base_rotation_deg: float,
	base_skew_deg: float,
	base_scale: Vector2,
	test_parameters := _generate_isolation_test_parameters()
) -> void:
	
	# Setup: Find the scenario configuration
	var scenario: Dictionary = {}
	for test_scenario in TEST_SCENARIOS:
		if test_scenario.name == scenario_name:
			scenario = test_scenario
			break
	
	# Setup: Apply base isometric transforms
	_setup_isometric_base_transform(scenario)
	
	# Setup: Create test indicators
	_create_test_indicators(2)
	
	await get_tree().process_frame
	
	# Capture base transform state (before manipulation)
	var base_transform_initial: Transform2D = _base_transform_node.transform
	var base_global_rotation_initial: float = _base_transform_node.global_rotation_degrees
	
	# Act: Apply manipulation rotation
	_manipulation_parent.apply_rotation(90.0)
	await get_tree().process_frame
	
	# Capture state after manipulation
	var base_transform_after_manipulation: Transform2D = _base_transform_node.transform
	var base_global_rotation_after_manipulation: float = _base_transform_node.global_rotation_degrees
	
	# Act: Reset manipulation parent transform
	_manipulation_parent.reset()
	await get_tree().process_frame
	
	# Capture final state
	var base_transform_final: Transform2D = _base_transform_node.transform
	var base_global_rotation_final: float = _base_transform_node.global_rotation_degrees
	
	# Assert: Base transform was never affected by manipulation operations
	assert_bool(_transforms_equal(base_transform_after_manipulation, base_transform_initial)).append_failure_message(
		"Base transform should not be affected by manipulation - Scenario: %s" % scenario_name
	).is_true()
	
	assert_bool(_transforms_equal(base_transform_final, base_transform_initial)).append_failure_message(
		"Base transform should remain unchanged after manipulation reset - Scenario: %s" % scenario_name
	).is_true()
	
	# Assert: Base global rotation remains consistent
	assert_float(base_global_rotation_after_manipulation).append_failure_message(
		"Base global rotation should not change during manipulation - Scenario: %s, Expected: %.2f°, Got: %.2f°" %
		[scenario_name, base_global_rotation_initial, base_global_rotation_after_manipulation]
	).is_equal_approx(base_global_rotation_initial, ROTATION_TOLERANCE)
	
	assert_float(base_global_rotation_final).append_failure_message(
		"Base global rotation should remain unchanged after reset - Scenario: %s, Expected: %.2f°, Got: %.2f°" %
		[scenario_name, base_global_rotation_initial, base_global_rotation_final]
	).is_equal_approx(base_global_rotation_initial, ROTATION_TOLERANCE)

#endregion

#region PARAMETER GENERATION

static func _generate_test_parameters() -> Array:
	"""Generate parameterized test data for isometric rotation scenarios"""
	var parameters: Array = []
	
	for scenario in TEST_SCENARIOS:
		for rotation_increment in ROTATION_INCREMENTS:
			parameters.append([
				scenario.name,
				scenario.base_rotation_deg,
				scenario.base_skew_deg,
				scenario.base_scale,
				rotation_increment
			])
	
	return parameters

static func _generate_cumulative_test_parameters() -> Array:
	"""Generate parameterized test data for cumulative rotation scenarios"""
	var parameters: Array = []
	
	# Test cumulative rotation with a subset of scenarios
	var cumulative_scenarios: Array = ["identity_baseline", "standard_isometric", "45_degree_isometric"]
	
	for scenario in TEST_SCENARIOS:
		if scenario.name in cumulative_scenarios:
			parameters.append([
				scenario.name,
				scenario.base_rotation_deg,
				scenario.base_skew_deg,
				scenario.base_scale
			])
	
	return parameters

## Test: Grid-aware rotation fix for isometric contexts
## Setup: Isometric parent hierarchy with rotation, skew, and scale transforms  
## Act: Apply cardinal direction rotation using GBGridRotationUtils
## Assert: Preview object achieves correct global rotation regardless of parent transforms
@warning_ignore("unused_parameter")
func test_grid_aware_rotation_fix_in_isometric_context(
	scenario_name: String,
	base_rotation_deg: float,
	base_skew_deg: float,
	base_scale: Vector2,
	test_parameters := _generate_isolation_test_parameters()
) -> void:
	
	# Setup: Find the scenario configuration
	var scenario: Dictionary = {}
	for test_scenario in TEST_SCENARIOS:
		if test_scenario.name == scenario_name:
			scenario = test_scenario
			break
	
	assert_bool(not scenario.is_empty()).append_failure_message(
		"Test scenario '%s' not found in TEST_SCENARIOS" % scenario_name
	).is_true()
	
	# Setup: Apply base isometric transforms to create problematic hierarchy
	_setup_isometric_base_transform(scenario)
	
	# Setup: Create a TileMapLayer for grid rotation utilities
	var tile_map: TileMapLayer = auto_free(TileMapLayer.new())
	add_child(tile_map)
	
	# Allow scene tree to update transforms
	await get_tree().process_frame
	
	# Test all cardinal directions with the FIXED grid rotation utilities
	var cardinal_directions: Array[float] = [0.0, 90.0, 180.0, 270.0]
	var direction_names: Array[String] = ["North", "East", "South", "West"]
	var cardinal_enums: Array[GBGridRotationUtils.CardinalDirection] = [
		GBGridRotationUtils.CardinalDirection.NORTH,
		GBGridRotationUtils.CardinalDirection.EAST,
		GBGridRotationUtils.CardinalDirection.SOUTH,
		GBGridRotationUtils.CardinalDirection.WEST
	]
	
	for i in range(4):
		var target_direction: GBGridRotationUtils.CardinalDirection = cardinal_enums[i]
		var expected_global_rotation: float = cardinal_directions[i]
		var direction_name: String = direction_names[i]
		
		# Act: Apply grid-aware rotation using the FIXED utility function
		GBGridRotationUtils.set_node_direction(_manipulation_parent, target_direction, tile_map, false)
		
		# Allow scene tree to update transforms
		await get_tree().process_frame
		
		# Assert: Preview object should have the correct global rotation
		var actual_global_rotation: float = _test_object.global_rotation_degrees
		var normalized_actual: float = _normalize_angle(actual_global_rotation)
		var normalized_expected: float = _normalize_angle(expected_global_rotation)
		
		assert_bool(_angles_equivalent(normalized_actual, normalized_expected, ROTATION_TOLERANCE)).append_failure_message(
			"Grid-aware rotation FAILED for %s direction in %s scenario - Expected global rotation: %.2f°, Got: %.2f°, Error: %.2f°, Parent hierarchy: (rot=%.1f°, skew=%.1f°, scale=%s)" % [
				direction_name,
				scenario_name,
				normalized_expected,
				normalized_actual,
				abs(normalized_expected - normalized_actual),
				scenario.base_rotation_deg,
				scenario.base_skew_deg,
				str(scenario.base_scale)
			]
		).is_true()

static func _generate_isolation_test_parameters() -> Array:
	"""Generate parameterized test data for transform isolation scenarios"""
	var parameters: Array = []
	
	# Test isolation with all scenarios
	for scenario in TEST_SCENARIOS:
		parameters.append([
			scenario.name,
			scenario.base_rotation_deg,
			scenario.base_skew_deg,
			scenario.base_scale
		])
	
	return parameters

#endregion