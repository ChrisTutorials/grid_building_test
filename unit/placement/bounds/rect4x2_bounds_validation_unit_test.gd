## Unit tests isolating pre-validation bounds for RECT_4X2
## Purpose: Reproduce "Tried placing outside of valid map area" seen in integration
## Strategy: Use IndicatorManager + PlacementValidator directly, compute safe tiles from used_rect,
## and assert pre-validation succeeds at start tile, with rich diagnostics.
extends GdUnitTestSuite

# Test constants to eliminate magic numbers
const SAFE_START_TILE := GBTestConstants.DEFAULT_CENTER_TILE
const OUTSIDE_OFFSET := 2
const PLACEABLE_RECT_4X2 := GBTestConstants.PLACEABLE_RECT_4X2

var env: BuildingTestEnvironment
var _building_system : BuildingSystem
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
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_placement_validator = _indicator_manager.get_placement_validator()
	_map = env.tile_map_layer
	_positioner = env.positioner
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	_targeting_state = targeting_system.get_state()
	if _targeting_state.target_map == null:
		_targeting_state.target_map = _map
	_targeting_state.target = env.placer
	
	# CRITICAL: Disable both targeting system and positioner to prevent mouse tracking during tests
	# GridTargetingSystem has _process() that calls _move_positioner(), so disable it too
	targeting_system.process_mode = Node.PROCESS_MODE_DISABLED
	# GridPositioner2D has _physics_process that tracks mouse, so disable its processing
	_positioner.process_mode = Node.PROCESS_MODE_DISABLED

	## Ensure tile map layer meets expectations
	GBTestConstants.assert_tile_map_size(self, env, 31, 31)

# Helper method to move positioner to a specific tile
func _move_positioner_to_tile(tile: Vector2i) -> void:
	_positioner.global_position = _map.to_global(_map.map_to_local(tile))
	# Add immediate verification that the position stuck
	var actual_pos: Vector2 = _positioner.global_position
	var expected_pos: Vector2 = _map.to_global(_map.map_to_local(tile))
	if not actual_pos.distance_to(expected_pos) < 0.1:
		push_error("POSITIONER POSITION FAILED: Set to %s but immediately reads as %s" % [str(expected_pos), str(actual_pos)])

# Helper method to enter build mode for a placeable
func _enter_build_mode_for_placeable(placeable: Placeable) -> PlacementReport:
	var setup_report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_object(setup_report).append_failure_message("enter_build_mode returned null").is_not_null()
	assert_bool(setup_report.is_successful()).append_failure_message(
		"enter_build_mode should succeed; issues=" + str(setup_report.get_issues())
	).is_true()
	return setup_report

# Helper method to validate placement and return results
func _validate_placement() -> ValidationResults:
	return _indicator_manager.validate_placement()

# Helper method to get indicator positions as tile coordinates (relative to tile map)
func _get_indicator_tile_positions_as_strings() -> Array[String]:
	var indicators: Array = _indicator_manager.get_indicators()
	var indicator_tile_positions: Array[String] = []
	for indicator: Object in indicators:
		if indicator != null:
			# Convert indicator's global position to tile coordinates relative to the tile map
			# Result is in tile units (e.g., (17, 3) means tile at x=17, y=3 in tile map coordinates)
			var tile_pos: Vector2i = _map.local_to_map(_map.to_local(indicator.global_position))
			indicator_tile_positions.append(str(tile_pos))
	return indicator_tile_positions

# Helper method to assert validation success with diagnostics
func _assert_validation_success(result: ValidationResults, context_message: String) -> void:
	var indicator_tile_positions: Array[String] = _get_indicator_tile_positions_as_strings()
	var used_rect: Rect2i = _map.get_used_rect()
	var issues: Array[String] = result.get_issues()

	# Comprehensive positioner diagnostics
	var positioner_world_pos: Vector2 = _positioner.global_position
	var positioner_tile_pos: Vector2i = _map.local_to_map(_map.to_local(positioner_world_pos))
	var expected_tile_pos: Vector2i = SAFE_START_TILE  # What we tried to set
	var expected_world_pos: Vector2 = _map.to_global(_map.map_to_local(expected_tile_pos))
	
	var formatted_message: String = "\n" + context_message + "\n"
	formatted_message += "├─ POSITIONER DIAGNOSTICS:\n"
	formatted_message += "│  ├─ Expected tile: " + str(expected_tile_pos) + "\n"
	formatted_message += "│  ├─ Expected world pos: " + str(expected_world_pos) + "\n"
	formatted_message += "│  ├─ Actual world pos: " + str(positioner_world_pos) + "\n"
	formatted_message += "│  ├─ Actual tile pos: " + str(positioner_tile_pos) + "\n"
	formatted_message += "│  ├─ Position delta: " + str(positioner_world_pos - expected_world_pos) + "\n"
	formatted_message += "│  └─ Tile delta: " + str(positioner_tile_pos - expected_tile_pos) + "\n"
	formatted_message += "├─ Validation Issues: " + str(issues) + "\n"
	formatted_message += "├─ Tile Map Used Rect: " + str(used_rect) + " (covers tiles from " + str(used_rect.position) + " to " + str(used_rect.position + used_rect.size - Vector2i.ONE) + ")\n"
	formatted_message += "└─ Indicator Tile Positions (relative to tile map coordinate system):\n"

	# Format indicator positions in a more readable way
	for i in range(indicator_tile_positions.size()):
		var position_str: String = indicator_tile_positions[i]
		var prefix: String = "    "
		if i == indicator_tile_positions.size() - 1:
			prefix += "└─ "
		else:
			prefix += "├─ "
		formatted_message += prefix + position_str
		if i < indicator_tile_positions.size() - 1:
			formatted_message += "\n"

	assert_bool(result.is_successful()).append_failure_message(formatted_message).is_true()

func test_pre_validation_is_successful_for_rect4x2_start_tile() -> void:
	# Arrange
	# Reset positions to ensure consistent testing regardless of scene layout
	_map.global_position = Vector2(0, 0)
	_positioner.global_position = Vector2(0, 0)
	
	var start_tile: Vector2i = SAFE_START_TILE
	_move_positioner_to_tile(start_tile)
	
	# Use actual runtime path: enter build mode to ensure indicators are created
	var placeable: Placeable = PLACEABLE_RECT_4X2
	
	# Replace raw prints with assert chains so failure reports include these diagnostics
	assert_object(_positioner).append_failure_message(
		"start_tile=%s positioner.global_position=%s" % [str(start_tile), str(_positioner.global_position)]).is_not_null()
	assert_object(_targeting_state).append_failure_message(
		"targeting_state.positioner.global_position=%s" % str(_targeting_state.positioner.global_position)).is_not_null()
	assert_bool(_positioner == _targeting_state.positioner).append_failure_message(
		"Are they the same object? %s" % str(_positioner == _targeting_state.positioner)).is_true()
	
	# Ensure the building system uses the correct targeting state
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	assert_object(targeting_system.get_state().positioner).append_failure_message(
		"targeting_system.get_state().positioner.global_position=%s" % str(targeting_system.get_state().positioner.global_position)).is_not_null()
	
	var _setup_report: PlacementReport = _enter_build_mode_for_placeable(placeable)
	
	# Act
	var result: ValidationResults = _validate_placement()
	
	# Assert
	_assert_validation_success(result, "Pre-validation should pass at start_tile " + str(start_tile))

func test_bounds_tiles_have_tiledata() -> void:
	var start_tile: Vector2i = SAFE_START_TILE
	var td: TileData = _map.get_cell_tile_data(start_tile)
	assert_object(td).append_failure_message(
		"Start tile must have TileData; start_tile=" + str(start_tile) + " used_rect=" + str(_map.get_used_rect())
	).is_not_null()

func test_pre_validation_out_of_bounds_outside_used_rect() -> void:
	# Arrange: move clearly outside the used_rect to guarantee OOB
	# Reset positions to ensure consistent testing regardless of scene layout
	_map.global_position = Vector2(0, 0)
	_positioner.global_position = Vector2(0, 0)
	
	var ur: Rect2i = _map.get_used_rect()
	var outside_tile: Vector2i = Vector2i(ur.position.x - OUTSIDE_OFFSET, ur.position.y)
	_move_positioner_to_tile(outside_tile)
	var placeable: Placeable = PLACEABLE_RECT_4X2
	var _setup_report: PlacementReport = _enter_build_mode_for_placeable(placeable)

	# Act
	var result: ValidationResults = _validate_placement()

	# Assert: Must fail when obviously outside
	assert_bool(result.is_successful()).append_failure_message(
		"Validation should fail when outside used_rect. outside_tile=" + str(outside_tile) + " used_rect=" + str(ur) + " issues=" + str(result.get_issues())
	).is_false()
