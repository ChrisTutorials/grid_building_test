## Test Suite: Manipulation Transform Persistence Tests
##
## Validates that rotation, flip, and scale transforms applied during manipulation
## (move mode) are correctly preserved when the object is placed.
##
## Coverage:
## - Horizontal flip persistence on placement
## - Vertical flip persistence on placement  
## - Rotation persistence on placement
## - Combined transforms (rotation + flip) persistence
## - Scale persistence on placement

extends GdUnitTestSuite

#region Test Environment
var _runner: GdUnitSceneRunner
var _test_env: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _manipulation_system: ManipulationSystem
var _building_system: BuildingSystem
var _targeting_state: GridTargetingState
var _manipulation_state: ManipulationState
var _manipulation_parent: ManipulationParent
var _logger: GBLogger
#endregion

#region Test Constants
const GBTestConstants = preload("res://test/grid_building_test/constants/test_constants.gd")

const ROTATION_PRECISION: float = 0.01
const SCALE_PRECISION: float = 0.01
const POSITION_PRECISION: float = 0.1
const ALL_SYSTEMS_ENV_UID: String = "uid://ioucajhfxc8b"
#endregion

#region Test Resources
var test_smithy_placeable: Placeable = load("uid://dirh6mcrgdm3w")
#endregion

func before_test() -> void:
	# Load the AllSystemsTestEnvironment using scene_runner
	_runner = scene_runner(ALL_SYSTEMS_ENV_UID)
	_test_env = _runner.scene() as AllSystemsTestEnvironment
	assert_object(_test_env).append_failure_message("AllSystemsTestEnvironment failed to load via scene_runner").is_not_null()
	
	# Extract system references from the environment
	_container = _test_env.get_container()
	_manipulation_system = _test_env.manipulation_system
	_building_system = _test_env.building_system
	_targeting_state = _container.get_states().targeting
	_manipulation_state = _container.get_manipulation_state()
	_manipulation_parent = _manipulation_state.parent as ManipulationParent
	_logger = _container.get_logger()
	
	# Ensure manipulation system is ready
	assert_bool(_manipulation_system.is_ready()).append_failure_message("ManipulationSystem should be ready before running transform persistence tests").is_true()

func after_test() -> void:
	# scene_runner automatically cleans up - no manual disposal needed
	pass

#region HORIZONTAL_FLIP_PERSISTENCE_TESTS

## Test: Horizontal flip during move is preserved on placement
func test_horizontal_flip_persists_on_placement() -> void:
	# Setup: Place an object that can be moved
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	var enter_successful: bool = placement_report.is_successful()
	assert_bool(enter_successful).is_true()
	
	_targeting_state.positioner.global_position = GBTestConstants.CENTER
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(GBTestConstants.CENTER)
	var place_successful: bool = place_report.is_successful()
	assert_bool(place_successful).append_failure_message(
		"Failed to place test object in build mode: %s" % str(place_report.get_issues())
	).is_true()
	
	# Get the placed object
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	var original_scale: Vector2 = placed_object.scale
	
	# Act: Enter move mode
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for horizontal flip test").is_not_null()
	var move_valid: bool = move_data.is_valid()
	assert_bool(move_valid).append_failure_message("ManipulationData should be valid before applying horizontal flip").is_true()
	_runner.simulate_frames(1)
	
	# Apply horizontal flip
	_manipulation_parent.apply_horizontal_flip()
	_runner.simulate_frames(1)

	var preview_transform: Transform2D = (move_data.target.root as Node2D).global_transform
	
	# Confirm placement
	_targeting_state.positioner.global_position = GBTestConstants.CENTER + Vector2(64, 0)
	_runner.simulate_frames(1)
	var validation_results: ValidationResults = await _manipulation_system.try_placement(move_data)
	var placement_valid: bool = validation_results.is_successful()
	assert_bool(placement_valid).append_failure_message(
		"Horizontal flip placement validation failed: %s" % str(validation_results.get_issues())
	).is_true()
	
	_assert_transforms_match(
		preview_transform,
		placed_object.global_transform,
		"Horizontal flip should preserve preview transform"
	)

#endregion

#region VERTICAL_FLIP_PERSISTENCE_TESTS

## Test: Vertical flip during move is preserved on placement
func test_vertical_flip_persists_on_placement() -> void:
	# Setup: Place an object
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	_targeting_state.positioner.global_position = GBTestConstants.CENTER
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(GBTestConstants.CENTER)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before vertical flip: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	var original_scale: Vector2 = placed_object.scale
	
	# Act: Enter move mode and flip vertically
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for vertical flip test").is_not_null()
	_runner.simulate_frames(1)
	
	_manipulation_parent.apply_vertical_flip()
	_runner.simulate_frames(1)

	var preview_transform: Transform2D = (move_data.target.root as Node2D).global_transform
	
	# Confirm placement
	_targeting_state.positioner.global_position = GBTestConstants.CENTER + Vector2(64, 0)
	_runner.simulate_frames(1)
	var validation_results: ValidationResults = await _manipulation_system.try_placement(move_data)
	var placement_valid_v: bool = validation_results.is_successful()
	assert_bool(placement_valid_v).append_failure_message(
		"Vertical flip placement validation failed: %s" % str(validation_results.get_issues())
	).is_true()

	_assert_transforms_match(
		preview_transform,
		placed_object.global_transform,
		"Vertical flip should preserve preview transform"
	)

#endregion

#region ROTATION_PERSISTENCE_TESTS

## Test: Rotation during move is preserved on placement
func test_rotation_persists_on_placement() -> void:
	# Setup: Place an object
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	_targeting_state.positioner.global_position = GBTestConstants.CENTER
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(GBTestConstants.CENTER)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before rotation: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	var original_rotation: float = placed_object.global_rotation_degrees
	
	# Act: Enter move mode and rotate
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for rotation test").is_not_null()
	_runner.simulate_frames(1)
	
	# Rotate 90 degrees
	var rotation_amount: float = 90.0
	_manipulation_parent.apply_rotation(rotation_amount)
	_runner.simulate_frames(1)

	var preview_transform: Transform2D = (move_data.target.root as Node2D).global_transform
	
	# Confirm placement
	_targeting_state.positioner.global_position = GBTestConstants.CENTER + Vector2(64, 0)
	_runner.simulate_frames(1)
	var validation_results: ValidationResults = await _manipulation_system.try_placement(move_data)
	var placement_valid_r: bool = validation_results.is_successful()
	assert_bool(placement_valid_r).append_failure_message(
		"Rotation placement validation failed: %s" % str(validation_results.get_issues())
	).is_true()

	_assert_transforms_match(
		preview_transform,
		placed_object.global_transform,
		"Rotation should preserve preview transform"
	)

#endregion

#region COMBINED_TRANSFORM_PERSISTENCE_TESTS

## Test: Combined rotation and flip transforms persist on placement
func test_combined_rotation_and_flip_persist_on_placement() -> void:
	# Setup: Place an object
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	_targeting_state.positioner.global_position = GBTestConstants.CENTER
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(GBTestConstants.CENTER)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before combined transform: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	var original_rotation: float = placed_object.global_rotation_degrees
	var original_scale: Vector2 = placed_object.scale
	
	# Act: Enter move mode, rotate, and flip
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for combined transform test").is_not_null()
	_runner.simulate_frames(1)
	
	# Apply rotation
	var rotation_amount: float = 45.0
	_manipulation_parent.apply_rotation(rotation_amount)
	_runner.simulate_frames(1)
	
	# Apply horizontal flip
	_manipulation_parent.apply_horizontal_flip()
	_runner.simulate_frames(1)

	var preview_transform: Transform2D = (move_data.target.root as Node2D).global_transform
	
	# Confirm placement
	_targeting_state.positioner.global_position = GBTestConstants.CENTER + Vector2(64, 0)
	_runner.simulate_frames(1)
	var validation_results: ValidationResults = await _manipulation_system.try_placement(move_data)
	var placement_valid_c: bool = validation_results.is_successful()
	assert_bool(placement_valid_c).append_failure_message(
		"Combined transform placement validation failed: %s" % str(validation_results.get_issues())
	).is_true()

	_assert_transforms_match(
		preview_transform,
		placed_object.global_transform,
		"Combined rotation + flip should preserve preview transform"
	)

#endregion

#region SCALE_PERSISTENCE_TESTS

## Test: Custom scale applied during move is preserved on placement
func test_custom_scale_persists_on_placement() -> void:
	# Setup: Place an object
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	_targeting_state.positioner.global_position = GBTestConstants.CENTER
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(GBTestConstants.CENTER)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before custom scale: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	
	# Act: Enter move mode and apply custom scale
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for custom scale test").is_not_null()
	_runner.simulate_frames(1)
	
	# Apply custom scale via ManipulationParent
	var custom_scale: Vector2 = Vector2(1.5, 1.5)
	_manipulation_parent.scale = custom_scale
	_runner.simulate_frames(1)

	var preview_transform: Transform2D = (move_data.target.root as Node2D).global_transform
	
	# Confirm placement
	_targeting_state.positioner.global_position = GBTestConstants.CENTER + Vector2(64, 0)
	_runner.simulate_frames(1)
	var validation_results: ValidationResults = await _manipulation_system.try_placement(move_data)
	var placement_valid_s: bool = validation_results.is_successful()
	assert_bool(placement_valid_s).append_failure_message(
		"Placement validation failed: %s" % str(validation_results.get_issues())
	).is_true()
	
	_assert_transforms_match(
		preview_transform,
		placed_object.global_transform,
		"Custom scale should preserve preview transform"
	)

#endregion

#region HELPER METHODS

func _assert_transforms_match(expected: Transform2D, actual: Transform2D, context: String) -> void:
	_assert_vector_close(expected.origin, actual.origin, POSITION_PRECISION, "%s - position mismatch" % context)
	_assert_vector_close(expected.x, actual.x, SCALE_PRECISION, "%s - basis.x mismatch" % context)
	_assert_vector_close(expected.y, actual.y, SCALE_PRECISION, "%s - basis.y mismatch" % context)

func _assert_vector_close(expected: Vector2, actual: Vector2, tolerance: float, context: String) -> void:
	assert_float(actual.x).is_equal_approx(expected.x, tolerance).append_failure_message(
		"%s (expected.x=%.4f, actual.x=%.4f)" % [context, expected.x, actual.x]
	)
	assert_float(actual.y).is_equal_approx(expected.y, tolerance).append_failure_message(
		"%s (expected.y=%.4f, actual.y=%.4f)" % [context, expected.y, actual.y]
	)

#endregion
