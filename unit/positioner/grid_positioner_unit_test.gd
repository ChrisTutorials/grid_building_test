## Unit tests for GridPositioner2D core behavior
## Focus: visibility toggling on mode changes and input gate toggling
extends GdUnitTestSuite

#region HELPERS & CONSTANTS
const SUITE_NAME := "GridPositionerUnit"
const GRID_POSITIONER_SCRIPT := preload("res://addons/grid_building/systems/grid_targeting/grid_positioner/grid_positioner_2d.gd")

const _IDX_ENV := 0
const _IDX_GP := 1
const _IDX_SETTINGS := 2
const _IDX_STATES := 3
const _IDX_TARGETING_STATE := 4
const _IDX_MAP := 5

func _assert_visible(actual: bool, expected: bool, context: String) -> void:
	if expected:
		assert_bool(actual).append_failure_message(_diag(context)).is_true()
	else:
		assert_bool(actual).append_failure_message(_diag(context)).is_false()

func _snap_world_to_map_global(map: TileMapLayer, world: Vector2) -> Vector2:
	var tile: Vector2i = map.local_to_map(map.to_local(world))
	var tile_local := map.map_to_local(tile)
	var tile_size := map.tile_set.tile_size
	var tile_center_local := tile_local + tile_size * 0.5
	return map.to_global(tile_center_local)

func _expected_view_center_position(map: TileMapLayer) -> Vector2:
	var viewport: Viewport = map.get_viewport()
	if viewport == null:
		return _snap_world_to_map_global(map, map.global_position)

	var camera: Camera2D = viewport.get_camera_2d()
	var center_world: Vector2 = map.global_position
	# Simplified: use direct camera projection instead of removed ProjectionSnapshot API
	if camera != null:
		center_world = camera.global_position
	else:
		center_world = map.global_position

	return _snap_world_to_map_global(map, center_world)


func _create_recenter_env() -> Array:
	var setup: Array = await _create_positioner_env(null, false)
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	# Recenter-specific tests should not hide on handled events
	settings.hide_on_handled = false
	return setup
	
func _diag(message: String) -> String:
	return GBDiagnostics.format_debug(message, SUITE_NAME, get_script().resource_path)

func _create_collision_env() -> CollisionTestEnvironment:
	var env: CollisionTestEnvironment = EnvironmentTestFactory.create_collision_test_environment(self)
	return env

func _replace_positioner(env: CollisionTestEnvironment, replacement: GridPositioner2D) -> GridPositioner2D:
	var original: GridPositioner2D = env.positioner
	var parent: Node = original.get_parent()
	var child_index: int = original.get_index()
	var original_children: Array[Node] = original.get_children()

	replacement.name = original.name
	replacement.global_transform = original.global_transform

	for child: Node in original_children:
		original.remove_child(child)
		replacement.add_child(child)

	if parent != null:
		parent.remove_child(original)
		parent.add_child(replacement)
		parent.move_child(replacement, child_index)

	env.positioner = replacement
	original.queue_free()
	return replacement

func _create_positioner_env(p_positioner: GridPositioner2D = null, hide_on_handled: bool = true) -> Array:
	var env: CollisionTestEnvironment = _create_collision_env()
	await get_tree().process_frame

	var container: GBCompositionContainer = env.container
	var config: GBConfig = container.config
	var states: GBStates = container.get_states()
	var targeting_state: GridTargetingState = states.targeting
	var settings: GridTargetingSettings
	if config != null and config.settings != null:
		settings = config.settings.targeting
	else:
		settings = GridTargetingSettings.new()
	settings.hide_on_handled = hide_on_handled
	settings.enable_mouse_input = true
	settings.positioner_active_when_off = false
	states.mode.current = GBEnums.Mode.MOVE
	if targeting_state != null:
		targeting_state.target_map = env.tile_map_layer

	var gp: GridPositioner2D = env.positioner
	if p_positioner != null:
		auto_free(p_positioner)
		gp = _replace_positioner(env, p_positioner)

	gp.set_dependencies(states, config, container.get_logger(), container.get_actions(), true)
	gp.set_input_processing_enabled(true)
	await get_tree().process_frame

	return [env, gp, settings, states, targeting_state, env.tile_map_layer]

class _MouseProjectionTestMap:
	extends TileMapLayer
	var override_world: Vector2 = Vector2.ZERO

	@warning_ignore("native_method_override")
	func get_global_mouse_position() -> Vector2:
		return override_world

	@warning_ignore("native_method_override")
	func get_viewport() -> Viewport:
		return null
	
#endregion

#region VISIBILITY REGRESSION: active mode without mouse events
func test_visible_in_active_mode_when_mouse_disabled_and_no_events() -> void:
	# Arrange: create a minimal, valid environment
	var setup: Array = await _create_recenter_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var states: GBStates = setup[_IDX_STATES]
	settings.enable_mouse_input = false
	settings.hide_on_handled = false  # keep UI gating out

	# Simulate entering an active mode (e.g., MOVE) by setting the mode state directly
	# In runtime this is set before the mode_changed signal, so reflect that here
	states.mode.current = GBEnums.Mode.MOVE
	await get_tree().process_frame

	# Act: Recompute visibility via the helper which uses should_be_visible()
	gp.update_visibility()

	# Assert: should remain visible even with no mouse events and mouse features disabled
	assert_bool(gp.should_be_visible()).append_failure_message(
		_diag("In active mode, positioner should be visible when mouse is disabled and no events are present")
	).is_true()
	assert_bool(gp.visible).append_failure_message(
		_diag("GridPositioner2D.visible should be true in active mode without mouse dependencies")
	).is_true()
#endregion

#region VISIBILITY MODES
@warning_ignore("unused_parameter")
func test_visibility_modes_scenarios(mode: int, expected_visible: bool, test_parameters := [
	[GBEnums.Mode.OFF, false],
	[GBEnums.Mode.INFO, false],
	[GBEnums.Mode.MOVE, true],
	[GBEnums.Mode.DEMOLISH, true]
]) -> void:
	var setup: Array = await _create_positioner_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	gp._on_mode_changed(mode)
	_assert_visible(
		gp.visible,
		expected_visible,
		"Mode %s should %s the positioner" % [str(mode), "show" if expected_visible else "hide"]
	)
#endregion

func test_input_processing_gate_toggle() -> void:
	var setup: Array = await _create_positioner_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	await get_tree().process_frame
	# Starts disabled in _ready, but _ready isn't called here; verify setter toggles the flag directly
	gp.set_input_processing_enabled(false)
	assert_bool(gp.input_processing_enabled).append_failure_message(
		_diag("Input gate should be false after set_input_processing_enabled(false)")
	).is_false()

	gp.set_input_processing_enabled(true)
	assert_bool(gp.input_processing_enabled).append_failure_message(
		_diag("Input gate should be true after set_input_processing_enabled(true)")
	).is_true()

func test_off_mode_visibility_override_when_enabled() -> void:
	# Arrange: create positioner and settings that allow visibility when OFF
	var setup: Array = await _create_positioner_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	settings.positioner_active_when_off = true

	# Act: set mode to OFF
	gp._on_mode_changed(GBEnums.Mode.OFF)

	# Assert: visible should be true due to override
	assert_bool(gp.visible).append_failure_message(
		_diag("OFF mode should keep the positioner visible when positioner_active_when_off=true")
	).is_true()

#region RECENTER ON ENABLE BEHAVIOR

func test_recenter_on_enable_prefers_cached_when_option_true() -> void:
	var setup: Array = await _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var map: TileMapLayer = setup[_IDX_MAP]
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN
	settings.enable_mouse_input = true

	# Seed last known world position cache
	gp._last_mouse_world = Vector2(123, 456)
	gp._has_mouse_world = true

	gp.set_input_processing_enabled(false)
	gp.global_position = Vector2.ZERO
	gp.set_input_processing_enabled(true)
	await get_tree().process_frame

	var expected_global_ls: Vector2 = _snap_world_to_map_global(map, Vector2(123, 456))
	assert_vector(gp.global_position).append_failure_message(
		_diag("Expected recenter to cached world (snapped to tile)")
	).is_equal_approx(expected_global_ls, Vector2.ONE)

func test_recenter_on_enable_mouse_enabled_centers_on_mouse_else_fallbacks() -> void:
	var setup: Array = await _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var map: TileMapLayer = setup[_IDX_MAP]
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR
	settings.enable_mouse_input = true

	# Simulate available cached value fallback by seeding cache
	gp._last_mouse_world = Vector2(10, 20)
	gp._has_mouse_world = true

	gp.set_input_processing_enabled(false)
	gp.global_position = Vector2.ZERO
	gp.set_input_processing_enabled(true)
	await get_tree().process_frame

	# In unit context without a camera, it should use cached world and snap to tile
	var expected_global_mc: Vector2 = _snap_world_to_map_global(map, Vector2(10, 20))
	assert_vector(gp.global_position).append_failure_message(
		_diag("Expected mouse policy to use cached world (snapped to tile)")
	).is_equal_approx(expected_global_mc, Vector2.ONE)

func test_recenter_on_enable_keyboard_only_centers_view() -> void:
	var setup: Array = await _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var map: TileMapLayer = setup[_IDX_MAP]
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER
	settings.enable_mouse_input = false

	# Starting position
	gp.global_position = Vector2(1, 1)
	gp.set_input_processing_enabled(false)
	gp.set_input_processing_enabled(true)
	await get_tree().process_frame

	var expected_global_vc: Vector2 = _expected_view_center_position(map)
	assert_vector(gp.global_position).append_failure_message(
		_diag("Expected keyboard-only recenter to viewport center (snapped)")
	).is_equal_approx(expected_global_vc, Vector2.ONE)

func test_restrict_to_map_area_respects_parent_transform() -> void:
	var setup: Array = await _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var map: TileMapLayer = setup[_IDX_MAP]
	settings.restrict_to_map_area = true
	settings.limit_to_adjacent = false

	var map_parent: Node2D = auto_free(Node2D.new())
	map_parent.position = Vector2(512, 384)
	add_child(map_parent)
	map.get_parent().remove_child(map)
	map_parent.add_child(map) 
	await get_tree().process_frame

	var target_tile: Vector2i = Vector2i(1, 2)
	var expected_global: Vector2 = map.to_global(map.map_to_local(target_tile))

	gp.global_position = Vector2.ZERO
	GBPositioning2DUtils.move_to_closest_valid_tile_center(gp, target_tile, gp, map, settings)

	assert_vector(gp.global_position).append_failure_message(
		_diag("restrict_to_map_area should honor parent transforms when snapping to tiles")
	).is_equal_approx(expected_global, Vector2.ONE)

class _StubGateGridPositioner:
	extends GridPositioner2D
	var _next_gate_allowed: bool = true

	func set_next_gate(allowed: bool) -> void:
		_next_gate_allowed = allowed

	func _mouse_input_gate() -> bool:
		return _next_gate_allowed

func test_hide_on_handled_mouse_event_hides_positioner() -> void:
	var setup: Array = await _create_positioner_env(_StubGateGridPositioner.new(), true)
	var gp: _StubGateGridPositioner = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var states: GBStates = setup[_IDX_STATES]
	settings.hide_on_handled = true
	settings.enable_mouse_input = true
	states.mode.current = GBEnums.Mode.MOVE

	gp.set_next_gate(false)

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(128, 128)
	motion.relative = Vector2.ZERO

	gp.visible = true
	gp._input(motion)
	await get_tree().process_frame

	assert_bool(gp.visible).append_failure_message(
		_diag("When hide_on_handled is true, UI-handled mouse events should hide the positioner")
	).is_false()

#region PROJECTION STABILIZATION

# DISABLED: test_mouse_event_global_reprojects_to_map_position() - ProjectionSnapshot API was simplified/removed
# func test_mouse_event_global_reprojects_to_map_position() -> void:
# 	var setup: Array = await _create_positioner_env(null, false)
# 	var env: CollisionTestEnvironment = setup[_IDX_ENV]
# 	var gp: GridPositioner2D = setup[_IDX_GP]
# 	var targeting_state: GridTargetingState = setup[_IDX_TARGETING_STATE]
# 	var mock_map: _MouseProjectionTestMap = auto_free(_MouseProjectionTestMap.new())
# 	mock_map.override_world = Vector2(321, 654)
# 	mock_map.tile_set = TileSet.new()
# 	mock_map.set_meta("gb_mouse_world_override", mock_map.override_world)
# 	targeting_state.target_map = mock_map
# 	env.world.add_child(mock_map)
# 	await get_tree().process_frame
# 
# 	# This test used the removed ProjectionSnapshot API
# 	# var raw: ProjectionSnapshot = ProjectionSnapshot.new(Vector2(10, 10), GBEnums.ProjectionMethod.EVENT_GLOBAL, "event.global_position")
# 	# var stabilized: ProjectionSnapshot = gp._stabilize_projection(raw, Vector2(5, 5), Vector2(5, 5))

#endregion

#endregion
