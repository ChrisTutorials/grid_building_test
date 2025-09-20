## Unit tests isolating pre-validation bounds for RECT_4X2
## Purpose: Reproduce "Tried placing outside of valid map area" seen in integration
## Strategy: Use IndicatorManager + PlacementValidator directly, compute safe tiles from used_rect,
## and assert pre-validation succeeds at start tile, with rich diagnostics.
extends GdUnitTestSuite

var env: BuildingTestEnvironment
var _container: GBCompositionContainer
var _indicator_manager: IndicatorManager
var _placement_validator: PlacementValidator
var _map: TileMapLayer
var _targeting_state: GridTargetingState
var _positioner: Node2D

func before_test() -> void:
	env = EnvironmentTestFactory.create_building_system_test_environment(self)
	assert_object(env).append_failure_message("Failed to create building test environment").is_not_null()
	_container = env.get_container()
	_indicator_manager = env.indicator_manager
	_placement_validator = _indicator_manager.get_placement_validator()
	_map = env.tile_map_layer
	_positioner = env.positioner
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	_targeting_state = targeting_system.get_state()
	if _targeting_state.target_map == null:
		_targeting_state.target_map = _map
	_targeting_state.target = env.placer
	await get_tree().process_frame

func _move_positioner_to_tile(tile: Vector2i) -> void:
	# Positions the test positioner so validators read the desired tile
	_positioner.global_position = _map.to_global(_map.map_to_local(tile))
	await get_tree().process_frame

func _compute_safe_start_tile() -> Vector2i:
	# Use the center tile as the safest possible position
	# This should definitely be within bounds for any reasonable tilemap
	return Vector2i(0, 0)

func test_pre_validation_is_successful_for_rect4x2_start_tile() -> void:
	# Arrange
	var start_tile: Vector2i = _compute_safe_start_tile()
	await _move_positioner_to_tile(start_tile)
	
	# Use actual runtime path: enter build mode to ensure indicators are created
	var placeable: Placeable = GBTestConstants.PLACEABLE_RECT_4X2
	var building_system: BuildingSystem = env.building_system
	
	# Log positioner position to verify it's set correctly
	print("DEBUG: start_tile=", start_tile, " positioner.global_position=", _positioner.global_position)
	print("DEBUG: targeting_state.positioner.global_position=", _targeting_state.positioner.global_position)
	print("DEBUG: Are they the same object? ", _positioner == _targeting_state.positioner)
	
	# Ensure the building system uses the correct targeting state
	var targeting_system: GridTargetingSystem = env.grid_targeting_system  
	print("DEBUG: targeting_system.get_state().positioner.global_position=", targeting_system.get_state().positioner.global_position)
	
	var setup_report: PlacementReport = building_system.enter_build_mode(placeable)
	assert_object(setup_report).append_failure_message("enter_build_mode returned null").is_not_null()
	await get_tree().process_frame
	assert_bool(setup_report.is_successful()).append_failure_message(
		"enter_build_mode should succeed for RECT_4X2; issues=" + str(setup_report.get_issues())
	).is_true()
	
	# Debug: Log indicator positions to understand the actual footprint
	var indicators: Array = _indicator_manager.get_indicators()
	var indicator_positions: Array[String] = []
	for indicator: Object in indicators:
		if indicator != null:
			var tile_pos: Vector2i = _map.local_to_map(_map.to_local(indicator.global_position))
			indicator_positions.append(str(tile_pos))
	
	# Act
	var result: ValidationResults = _indicator_manager.validate_placement()
	# Assert
	assert_bool(result.is_successful()).append_failure_message(
		"Pre-validation should pass at start_tile " + str(start_tile) + ". Issues: " + str(result.get_issues()) + 
		", used_rect=" + str(_map.get_used_rect()) + ", indicator_positions=" + str(indicator_positions)
	).is_true()

func test_bounds_tiles_have_tiledata() -> void:
	var start_tile: Vector2i = _compute_safe_start_tile()
	var td: TileData = _map.get_cell_tile_data(start_tile)
	assert_object(td).append_failure_message(
		"Start tile must have TileData; start_tile=" + str(start_tile) + " used_rect=" + str(_map.get_used_rect())
	).is_not_null()

func test_pre_validation_out_of_bounds_outside_used_rect() -> void:
	# Arrange: move clearly outside the used_rect to guarantee OOB
	var ur: Rect2i = _map.get_used_rect()
	var outside_tile: Vector2i = Vector2i(ur.position.x - 2, ur.position.y)
	await _move_positioner_to_tile(outside_tile)
	var placeable: Placeable = GBTestConstants.PLACEABLE_RECT_4X2
	var building_system: BuildingSystem = env.building_system
	var setup_report: PlacementReport = building_system.enter_build_mode(placeable)
	assert_object(setup_report).append_failure_message("enter_build_mode returned null outside used_rect").is_not_null()
	await get_tree().process_frame

	# Act
	var result: ValidationResults = _indicator_manager.validate_placement()

	# Assert: Must fail when obviously outside
	assert_bool(result.is_successful()).append_failure_message(
		"Validation should fail when outside used_rect. outside_tile=" + str(outside_tile) + " used_rect=" + str(ur) + " issues=" + str(result.get_issues())
	).is_false()
