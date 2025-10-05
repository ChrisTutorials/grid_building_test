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
const TransformPersistenceDiagnostics = preload("res://test/helpers/transform_persistence_diagnostics.gd")

## Test: Horizontal flip during move is preserved on placement
func test_horizontal_flip_persists_on_placement() -> void:
	# Setup: Place an object that can be moved (place far from test area to avoid collision)
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	var enter_successful: bool = placement_report.is_successful()
	assert_bool(enter_successful).is_true()
	
	# Place initial object away from test area to avoid collision during move test
	# Use positive offset to stay within 31x31 tilemap bounds (5 tiles = 160px from center)
	var initial_position: Vector2 = GBTestConstants.CENTER + Vector2(160, 160)
	_targeting_state.positioner.global_position = initial_position
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(initial_position)
	var place_successful: bool = place_report.is_successful()
	assert_bool(place_successful).append_failure_message(
		"Failed to place test object in build mode: %s" % str(place_report.get_issues())
	).is_true()
	
	# Get the placed object
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	
	# Act: Enter move mode
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for horizontal flip test").is_not_null()
	var move_valid: bool = move_data.is_valid()
	assert_bool(move_valid).append_failure_message("ManipulationData should be valid before applying horizontal flip").is_true()
	_runner.simulate_frames(1)
	
	# Apply horizontal flip
	_manipulation_parent.apply_horizontal_flip()
	_runner.simulate_frames(1)

	# Move to test position (collision-free area)
	var test_position: Vector2 = GBTestConstants.CENTER
	_targeting_state.positioner.global_position = test_position
	_runner.simulate_frames(1)
	var preview_transform: Transform2D = TransformPersistenceDiagnostics.capture_preview_transform(move_data)

	# Confirm placement (now collision-free since source moved from initial_position to test_position)
	var validation_results: ValidationResults = _manipulation_system.try_placement(move_data)
	var placement_valid: bool = validation_results.is_successful()
	
	# Enhanced diagnostics for placement failures
	if not placement_valid:
		var diag_msg: String = TransformPersistenceDiagnostics.format_placement_failure(
			"Horizontal flip",
			placed_object,
			_manipulation_parent,
			validation_results)
		assert_bool(placement_valid).append_failure_message(diag_msg).is_true()
	else:
		assert_bool(placement_valid).is_true()
	
	TransformPersistenceDiagnostics.assert_transforms_preserved(
		preview_transform,
		placed_object.global_transform,
		"Horizontal flip should preserve preview transform",
		POSITION_PRECISION,
		SCALE_PRECISION,
		Callable(self, "_assert_component"))

#endregion

#region VERTICAL_FLIP_PERSISTENCE_TESTS

## Test: Vertical flip during move is preserved on placement
func test_vertical_flip_persists_on_placement() -> void:
	# Setup: Place an object far from test area to avoid collision
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	var initial_position: Vector2 = GBTestConstants.CENTER + Vector2(5 * 32, 5 * 32)  # 5 tiles away from center
	_targeting_state.positioner.global_position = initial_position
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(initial_position)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before vertical flip: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	
	# Act: Enter move mode and flip vertically
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for vertical flip test").is_not_null()
	_runner.simulate_frames(1)
	
	_manipulation_parent.apply_vertical_flip()
	_runner.simulate_frames(1)

	# Move to collision-free test position
	var test_position: Vector2 = GBTestConstants.CENTER
	_targeting_state.positioner.global_position = test_position
	_runner.simulate_frames(1)
	var preview_transform: Transform2D = TransformPersistenceDiagnostics.capture_preview_transform(move_data)

	# Confirm placement (collision-free since source moved away)
	var validation_results: ValidationResults = _manipulation_system.try_placement(move_data)
	var placement_valid_v: bool = validation_results.is_successful()
	if not placement_valid_v:
		var diag_msg_v: String = TransformPersistenceDiagnostics.format_placement_failure(
			"Vertical flip",
			placed_object,
			_manipulation_parent,
			validation_results)
		assert_bool(placement_valid_v).append_failure_message(diag_msg_v).is_true()
	else:
		assert_bool(placement_valid_v).is_true()

	TransformPersistenceDiagnostics.assert_transforms_preserved(
		preview_transform,
		placed_object.global_transform,
		"Vertical flip should preserve preview transform",
		POSITION_PRECISION,
		SCALE_PRECISION,
		Callable(self, "_assert_component"))

#endregion

#region ROTATION_PERSISTENCE_TESTS

## Test: Rotation during move is preserved on placement
func test_rotation_persists_on_placement() -> void:
	# Setup: Place an object far from test area to avoid collision
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	var initial_position: Vector2 = GBTestConstants.CENTER + Vector2(5 * 32, 5 * 32)  # 5 tiles away from center
	_targeting_state.positioner.global_position = initial_position
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(initial_position)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before rotation: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	
	# Act: Enter move mode and rotate
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for rotation test").is_not_null()
	_runner.simulate_frames(1)
	
	# Rotate 90 degrees
	var rotation_amount: float = 90.0
	_manipulation_parent.apply_rotation(rotation_amount)
	_runner.simulate_frames(1)

	# Move to collision-free test position
	var test_position_rot: Vector2 = GBTestConstants.CENTER
	_targeting_state.positioner.global_position = test_position_rot
	_runner.simulate_frames(1)
	var preview_transform: Transform2D = TransformPersistenceDiagnostics.capture_preview_transform(move_data)

	# Confirm placement (collision-free since source moved away)
	var validation_results: ValidationResults = _manipulation_system.try_placement(move_data)
	var placement_valid_r: bool = validation_results.is_successful()
	if not placement_valid_r:
		var diag_msg_r: String = TransformPersistenceDiagnostics.format_placement_failure(
			"Rotation",
			placed_object,
			_manipulation_parent,
			validation_results)
		assert_bool(placement_valid_r).append_failure_message(diag_msg_r).is_true()
	else:
		assert_bool(placement_valid_r).is_true()

	TransformPersistenceDiagnostics.assert_transforms_preserved(
		preview_transform,
		placed_object.global_transform,
		"Rotation should preserve preview transform",
		POSITION_PRECISION,
		SCALE_PRECISION,
		Callable(self, "_assert_component"))

#endregion

#region COMBINED_TRANSFORM_PERSISTENCE_TESTS

## Test: Combined rotation and flip during move is preserved on placement
func test_combined_rotation_and_flip_persist_on_placement() -> void:
	# Setup: Place an object far from test area to avoid collision
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	var initial_position: Vector2 = GBTestConstants.CENTER + Vector2(5 * 32, 5 * 32)  # 5 tiles away from center
	_targeting_state.positioner.global_position = initial_position
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(initial_position)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before combined transforms: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	
	# Act: Enter move mode
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for combined transforms test").is_not_null()
	_runner.simulate_frames(1)
	
	# Apply both rotation and vertical flip
	_manipulation_parent.rotation += deg_to_rad(-135)
	_manipulation_parent.apply_vertical_flip()
	_runner.simulate_frames(1)

	# Move to collision-free test position
	var test_position: Vector2 = GBTestConstants.CENTER
	_targeting_state.positioner.global_position = test_position
	_runner.simulate_frames(1)
	var preview_transform: Transform2D = TransformPersistenceDiagnostics.capture_preview_transform(move_data)

	# Confirm placement (collision-free since source moved away)
	var validation_results: ValidationResults = _manipulation_system.try_placement(move_data)
	var placement_valid_combined: bool = validation_results.is_successful()
	if not placement_valid_combined:
		var diag_msg_combined: String = TransformPersistenceDiagnostics.format_placement_failure(
			"Combined rotation+flip",
			placed_object,
			_manipulation_parent,
			validation_results)
		assert_bool(placement_valid_combined).append_failure_message(diag_msg_combined).is_true()
	else:
		assert_bool(placement_valid_combined).is_true()

	TransformPersistenceDiagnostics.assert_transforms_preserved(
		preview_transform,
		placed_object.global_transform,
		"Combined rotation+flip should preserve preview transform",
		POSITION_PRECISION,
		SCALE_PRECISION,
		Callable(self, "_assert_component"))

#endregion

#region SCALE_PERSISTENCE_TESTS

## Test: Custom scale during move is preserved on placement
func test_custom_scale_persists_on_placement() -> void:
	# Setup: Place an object far from test area to avoid collision
	var placement_report: PlacementReport = _building_system.enter_build_mode(test_smithy_placeable)
	assert_bool(placement_report.is_successful()).is_true()
	
	var initial_position: Vector2 = GBTestConstants.CENTER + Vector2(5 * 32, 5 * 32)  # 5 tiles away from center
	_targeting_state.positioner.global_position = initial_position
	_runner.simulate_frames(1)
	
	var place_report: PlacementReport = _building_system.try_build_at_position(initial_position)
	assert_bool(place_report.is_successful()).append_failure_message(
		"Failed to place test object before custom scale: %s" % str(place_report.get_issues())
	).is_true()
	
	var placed_object: Node = _targeting_state.target
	assert_object(placed_object).is_not_null()
	
	# Act: Enter move mode
	var move_data: ManipulationData = _manipulation_system.try_move(placed_object)
	assert_object(move_data).append_failure_message("try_move() returned null ManipulationData for custom scale test").is_not_null()
	_runner.simulate_frames(1)
	
	# Apply custom scale (1.5x)
	_manipulation_parent.scale = Vector2(1.5, 1.5)
	_runner.simulate_frames(1)

	# Move to collision-free test position
	var test_position_scale: Vector2 = GBTestConstants.CENTER
	_targeting_state.positioner.global_position = test_position_scale
	_runner.simulate_frames(1)
	var preview_transform_scale: Transform2D = TransformPersistenceDiagnostics.capture_preview_transform(move_data)

	# Confirm placement (collision-free since source moved away)
	var validation_results: ValidationResults = _manipulation_system.try_placement(move_data)
	var placement_valid_scale: bool = validation_results.is_successful()
	if not placement_valid_scale:
		var diag_msg_scale: String = TransformPersistenceDiagnostics.format_placement_failure(
			"Custom scale",
			placed_object,
			_manipulation_parent,
			validation_results)
		assert_bool(placement_valid_scale).append_failure_message(diag_msg_scale).is_true()
	else:
		assert_bool(placement_valid_scale).is_true()

	TransformPersistenceDiagnostics.assert_transforms_preserved(
		preview_transform_scale,
		placed_object.global_transform,
		"Custom scale should preserve preview transform",
		POSITION_PRECISION,
		SCALE_PRECISION,
		Callable(self, "_assert_component"))

#endregion

## Component-wise assertion adapter bridging generic diagnostics helper with GdUnit fluent assertions.
func _assert_component(kind: String, actual: float, expected: float, tolerance: float, message: String) -> void:
	assert_float(actual).is_equal_approx(expected, tolerance).append_failure_message(
		"%s | %s delta=%.4f tol=%.4f" % [message, kind, abs(actual-expected), tolerance])

#region HELPER METHODS

#endregion
