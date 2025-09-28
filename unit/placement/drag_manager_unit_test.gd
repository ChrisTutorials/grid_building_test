## DragManager unit tests focusing on tile switch behavior and duplicate prevention
## Scope: Validate last_attempted_tile transitions and build attempt mechanics
## Expectations:
## - Map ~30x30 (-15..15); Placeable RECT_4X2 (4x2 tiles); drag_multi_build enabled
## - First tile switch attempts a build and updates last_attempted_tile
## - Re-sending the same tile does NOT create a new placement or attempt
extends GdUnitTestSuite

const SAFE_LEFT_TILE: Vector2i = Vector2i(-4, 0)
const SAFE_RIGHT_TILE: Vector2i = Vector2i(4, 0)

var env: BuildingTestEnvironment
var _container: GBCompositionContainer
var _building_system: BuildingSystem
var _indicator_manager: IndicatorManager
var _map: TileMapLayer
var _targeting_system: GridTargetingSystem
var _targeting_state: GridTargetingState
var _positioner: Node2D

var _build_success_count: int
var _build_failed_count: int
var _placed_positions: Array[Vector2]

func before_test() -> void:
	env = EnvironmentTestFactory.create_building_system_test_environment(self)
	assert_object(env).append_failure_message("Failed to create building test environment").is_not_null()
	
	# Configure runtime checks to disable Camera2D validation for unit testing
	var container: GBCompositionContainer = env.get_container()
	if container and container.config and container.config.settings and container.config.settings.runtime_checks:
		var runtime_checks: GBRuntimeChecks = container.config.settings.runtime_checks
		runtime_checks.camera_2d = false
	
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_map = env.tile_map_layer
	_targeting_system = env.grid_targeting_system
	_targeting_state = _targeting_system.get_state()
	_positioner = env.positioner
	_container = env.get_container()
	_placed_positions = []
	_build_success_count = 0
	_build_failed_count = 0
	_container.get_states().building.success.connect(_on_build_success)
	_container.get_states().building.failed.connect(_on_build_failed)
	# Ensure targeting state is fully configured
	assert_object(_map).append_failure_message("Environment tile_map_layer is null").is_not_null()
	if _targeting_state.target_map == null:
		_targeting_state.target_map = _map
	_targeting_state.target = env.placer
	# Allow one frame so environment systems can finish _ready hooks
	await get_tree().process_frame

func after_test() -> void:
	if _container and _container.get_states().building.success.is_connected(_on_build_success):
		_container.get_states().building.success.disconnect(_on_build_success)
	if _container and _container.get_states().building.failed.is_connected(_on_build_failed):
		_container.get_states().building.failed.disconnect(_on_build_failed)
	await get_tree().process_frame

func _on_build_success(data: BuildActionData) -> void:
	_build_success_count += 1
	if data and data.report and data.report.placed:
		_placed_positions.append(data.get_placed_position())

func _on_build_failed(_data: BuildActionData) -> void:
	_build_failed_count += 1

func _move_positioner_to_tile(tile: Vector2i) -> void:
	assert_object(_map).append_failure_message("TileMapLayer missing in _move_positioner_to_tile").is_not_null()
	_positioner.global_position = _map.to_global(_map.map_to_local(tile))
	# No manual _process on targeting state (it's a Resource). Direct position update is sufficient.

func _enter_rect_4x2_drag() -> Variant:
	var report: PlacementReport = _building_system.enter_build_mode(GBTestConstants.PLACEABLE_RECT_4X2)
	assert_bool(report.is_successful()).append_failure_message("enter_build_mode failed: %s" % [report.get_issues()]).is_true()
	_container.get_settings().building.drag_multi_build = true
	_building_system.start_drag()
	var drag_manager: Variant = _building_system.get_lazy_drag_manager()
	assert_bool(drag_manager.is_dragging()).append_failure_message("start_drag did not enable dragging").is_true()
	# Guard: drag_data and its targeting_state must be valid with a target_map
	return drag_manager

func test_last_attempted_updates_on_tile_switch() -> void:
	_move_positioner_to_tile(SAFE_LEFT_TILE)
	var drag_manager: Variant = _enter_rect_4x2_drag()
	var drag_data: Variant = drag_manager.drag_data
	assert_object(drag_data).append_failure_message("drag_data missing after start_drag").is_not_null()
	assert_bool(_container.get_states().building.success.is_connected(_on_build_success)).append_failure_message("BuildingState.success must be connected").is_true()

	# First switch should update last_attempted_tile and cause a build attempt
	var attempts_before: int = _build_success_count + _build_failed_count
	_building_system._on_drag_targeting_new_tile(drag_data, SAFE_LEFT_TILE, SAFE_RIGHT_TILE)
	assert_that(drag_data.last_attempted_tile).append_failure_message("last_attempted not set to target on first switch").is_equal(SAFE_LEFT_TILE)
	var attempts_after: int = _build_success_count + _build_failed_count
	assert_int(attempts_after).append_failure_message("No build attempt after first tile switch").is_greater(attempts_before)
	assert_int(_placed_positions.size()).append_failure_message("Expected one placement after first switch").is_equal(1)

func test_no_duplicate_on_same_tile() -> void:
	_move_positioner_to_tile(SAFE_LEFT_TILE)
	var drag_manager: Variant = _enter_rect_4x2_drag()
	var drag_data: Variant = drag_manager.drag_data
	assert_object(drag_data).append_failure_message("drag_data missing after start_drag").is_not_null()

	# First switch
	_building_system._on_drag_targeting_new_tile(drag_data, SAFE_LEFT_TILE, SAFE_RIGHT_TILE)
	assert_int(_placed_positions.size()).append_failure_message("Should place once on first tile switch").is_equal(1)
	var attempts_after_first: int = _build_success_count + _build_failed_count

	# Same tile again should not add placement nor attempt
	_building_system._on_drag_targeting_new_tile(drag_data, SAFE_LEFT_TILE, SAFE_LEFT_TILE)
	assert_int(_placed_positions.size()).append_failure_message("Duplicate placement on same tile").is_equal(1)
	var attempts_after_same: int = _build_success_count + _build_failed_count
	assert_int(attempts_after_same).append_failure_message("Should not attempt build again on same tile").is_equal(attempts_after_first)
