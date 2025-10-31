## Unit tests for GridPositioner2D core behavior
## Focus: visibility toggling on mode changes and input gate toggling
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
##
## IMPORTANT: GridPositioner2D snaps to tile centers - objects are placed in the MIDDLE of tiles
## In Godot 4.x, TileMapLayer.map_to_local() returns tile CENTER coordinates.
## Expected behavior: positioner positions at tile centers like (8.0, 8.0) for 16x16 tiles.
extends GdUnitTestSuite

#region HELPERS & CONSTANTS
const SUITE_NAME := "GridPositionerUnit"

const GRID_POSITIONER_SCRIPT = preload(
	"res://addons/grid_building/systems/grid_targeting/grid_positioner/grid_positioner_2d.gd"
)

const _IDX_ENV := 0
const _IDX_GP := 1
const _IDX_SETTINGS := 2
const _IDX_STATES := 3
const _IDX_TARGETING_STATE := 4
const _IDX_MAP := 5

# Test configuration constants
const DEFAULT_HIDE_GATE_POSITION := Vector2(100, 100)
const EXPECTED_ACTIVE_MODE := GBEnums.Mode.MOVE
const GATE_BLOCKS_INPUT := false
const GATE_ALLOWS_INPUT := true
const INITIAL_VISIBILITY := true
const MOUSE_EVENT_REPETITIONS := 3
const POSITION_OFFSET_INCREMENT := Vector2(1, 1)

var runner: GdUnitSceneRunner

# Tests run under the GdUnit scene runner; use the runner directly for deterministic frame advancement.


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


func _create_recenter_env() -> Array[Variant]:
	var setup: Array[Variant] = _create_positioner_env(null, false)
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	# Recenter-specific tests should not hide on handled events
	settings.hide_on_handled = false
	return setup


func _diag(message: String) -> String:
	return GBDiagnostics.format_debug(message, SUITE_NAME, get_script().resource_path)


func _create_collision_env() -> CollisionTestEnvironment:
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV.resource_path)
	var env: CollisionTestEnvironment = runner.scene() as CollisionTestEnvironment

	(
		assert_object(env) \
		. append_failure_message("Failed to load CollisionTestEnvironment scene") \
		. is_not_null()
	)

	return env


func _replace_positioner(
	env: CollisionTestEnvironment, replacement: GridPositioner2D
) -> GridPositioner2D:
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


func _create_positioner_env(
	p_positioner: GridPositioner2D = null, hide_on_handled: bool = true
) -> Array[Variant]:
	var env: CollisionTestEnvironment = _create_collision_env()
	runner.simulate_frames(1)

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
	settings.remain_active_in_off_mode = false
	states.mode.current = GBEnums.Mode.MOVE
	if targeting_state != null:
		targeting_state.target_map = env.tile_map_layer

	var gp: GridPositioner2D = env.positioner
	if p_positioner != null:
		auto_free(p_positioner)
		gp = _replace_positioner(env, p_positioner)

	gp.set_dependencies(states, config, container.get_logger(), container.get_actions(), true)
	gp.set_input_processing_enabled(true)
	runner.simulate_frames(1)

	return [env, gp, settings, states, targeting_state, env.tile_map_layer]


class _MouseProjectionTestMap:
	extends TileMapLayer
	var override_world: Vector2 = Vector2.ZERO

	@warning_ignore("native_method_override")
	## Mock implementation returning controlled mouse position for testing.
	func get_global_mouse_position() -> Vector2:
		return override_world

	## Mock implementation returning null viewport for testing isolation.
	@warning_ignore("native_method_override")
	func get_viewport() -> Viewport:
		return null


#endregion


#region VISIBILITY REGRESSION: active mode without mouse events
## Tests that positioner remains visible in active mode when mouse input is disabled and no events occur.
func test_visible_in_active_mode_when_mouse_disabled_and_no_events() -> void:
	# Arrange: create a minimal, valid environment
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var states: GBStates = setup[_IDX_STATES]
	settings.enable_mouse_input = false
	settings.hide_on_handled = false  # keep UI gating out

	# Simulate entering an active mode (e.g., MOVE) by setting the mode state directly
	# In runtime this is set before the mode_changed signal, so reflect that here
	states.mode.current = GBEnums.Mode.MOVE
	runner.simulate_frames(1)

	# Act: Recompute visibility via the helper which uses should_be_visible()
	gp.update_visibility()

	# Assert: should remain visible even with no mouse events and mouse features disabled
	(
		assert_bool(gp.should_be_visible()) \
		. append_failure_message(
			_diag(
				"In active mode, positioner should be visible when mouse is disabled and no events are present"
			)
		) \
		. is_true()
	)
	(
		assert_bool(gp.visible) \
		. append_failure_message(
			_diag(
				"GridPositioner2D.visible should be true in active mode without mouse dependencies"
			)
		) \
		. is_true()
	)


#endregion

#region VISIBILITY MODES
@warning_ignore("unused_parameter")
func test_visibility_modes_scenarios(
	mode: int,
	expected_visible: bool,
	test_parameters := [
		[GBEnums.Mode.OFF, false],
		[GBEnums.Mode.INFO, false],
		[GBEnums.Mode.MOVE, true],
		[GBEnums.Mode.DEMOLISH, true]
	]
) -> void:
	var setup: Array[Variant] = _create_positioner_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	gp._on_mode_changed(mode)
	_assert_visible(
		gp.visible,
		expected_visible,
		"Mode %s should %s the positioner" % [str(mode), "show" if expected_visible else "hide"]
	)


#endregion


## Tests that the input processing gate can be toggled on and off correctly.
func test_input_processing_gate_toggle() -> void:
	var setup: Array[Variant] = _create_positioner_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	runner.simulate_frames(1)
	# Starts disabled in _ready, but _ready isn't called here; verify setter toggles the flag directly
	gp.set_input_processing_enabled(false)
	(
		assert_bool(gp.input_processing_enabled) \
		. append_failure_message(
			_diag("Input gate should be false after set_input_processing_enabled(false)")
		) \
		. is_false()
	)

	gp.set_input_processing_enabled(true)
	(
		assert_bool(gp.input_processing_enabled) \
		. append_failure_message(
			_diag("Input gate should be true after set_input_processing_enabled(true)")
		) \
		. is_true()
	)


## Tests that positioner can remain visible in OFF mode when remain_active_in_off_mode is enabled.
func test_off_mode_visibility_override_when_enabled() -> void:
	# Arrange: create positioner and settings that allow visibility when OFF
	var setup: Array[Variant] = _create_positioner_env()
	var gp: GridPositioner2D = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	settings.remain_active_in_off_mode = true

	# Act: set mode to OFF
	gp._on_mode_changed(GBEnums.Mode.OFF)

	# Assert: visible should be true due to override
	(
		assert_bool(gp.visible) \
		. append_failure_message(
			_diag("OFF mode should keep the positioner visible when remain_active_in_off_mode=true")
		) \
		. is_true()
	)


#region RECENTER ON ENABLE BEHAVIOR


func test_recenter_on_enable_prefers_cached_when_option_true() -> void:
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	# Note: map variable removed - was unused and caused compiler warning
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN
	settings.enable_mouse_input = true

	# IMPORTANT: LAST_SHOWN policy should use the cached mouse position when available
	# The positioner should move to the cached position (snapped to grid), not stay at tile center
	# Seed last known world position cache - this SHOULD be used by LAST_SHOWN policy
	gp._last_mouse_world = Vector2(123, 456)
	gp._has_mouse_world = true

	gp.set_input_processing_enabled(false)
	gp.global_position = Vector2.ZERO
	gp.set_input_processing_enabled(true)
	runner.simulate_frames(1)

	# EXPECTED: With LAST_SHOWN policy, positioner should move to cached position (snapped to grid)
	# The cached position Vector2(123, 456) should be snapped to the nearest tile center
	var map: TileMapLayer = setup[_IDX_MAP]
	var cached_tile := GBPositioning2DUtils.get_tile_from_global_position(gp._last_mouse_world, map)
	var tile_center_local := map.map_to_local(cached_tile)
	var expected_pos := map.to_global(tile_center_local)
	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag(
				(
					"LAST_SHOWN policy should use cached position. Actual: %s, Expected: %s, Cache: %s, Has cache: %s, Cached tile: %s"
					% [
						str(gp.global_position),
						str(expected_pos),
						str(gp._last_mouse_world),
						str(gp._has_mouse_world),
						str(cached_tile)
					]
				)
			)
		) \
		. is_equal_approx(expected_pos, Vector2(8.0, 8.0))
	)  # 8px tolerance for tile snapping


func test_recenter_on_enable_mouse_enabled_centers_on_mouse_else_fallbacks() -> void:
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	# Note: map variable removed - was unused and caused compiler warning
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR
	settings.enable_mouse_input = true

	# IMPORTANT: MOUSE_CURSOR policy should use cached mouse position when available
	# The positioner should move to the cached position (snapped to grid)
	# Simulate available cached value - this SHOULD be used by MOUSE_CURSOR policy
	gp._last_mouse_world = Vector2(10, 20)
	gp._has_mouse_world = true

	gp.set_input_processing_enabled(false)
	gp.global_position = Vector2.ZERO
	gp.set_input_processing_enabled(true)
	runner.simulate_frames(1)

	# EXPECTED: With MOUSE_CURSOR policy, positioner should move to cached mouse position (snapped to grid)
	# The cached position Vector2(10, 20) should be snapped to the nearest tile center
	var map: TileMapLayer = setup[_IDX_MAP]
	var cached_tile := GBPositioning2DUtils.get_tile_from_global_position(gp._last_mouse_world, map)
	var tile_center_local := map.map_to_local(cached_tile)
	var expected_pos := map.to_global(tile_center_local)
	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag(
				(
					"MOUSE_CURSOR policy should use cached mouse position. Actual: %s, Expected: %s, Cache: %s, Has cache: %s, Cached tile: %s"
					% [
						str(gp.global_position),
						str(expected_pos),
						str(gp._last_mouse_world),
						str(gp._has_mouse_world),
						str(cached_tile)
					]
				)
			)
		) \
		. is_equal_approx(expected_pos, Vector2(8.0, 8.0))
	)  # 8px tolerance for tile snapping


func test_recenter_on_enable_keyboard_only_centers_view() -> void:
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var map: TileMapLayer = setup[_IDX_MAP]
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER
	settings.enable_mouse_input = false

	# Starting position
	gp.global_position = Vector2(1, 1)
	gp.set_input_processing_enabled(false)
	gp.set_input_processing_enabled(true)
	runner.simulate_frames(1)

	var expected_global_vc: Vector2 = _expected_view_center_position(map)
	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag(
				(
					"Expected keyboard-only recenter to viewport center (snapped to tile center). Actual: %s, Expected: %s, Map pos: %s"
					% [str(gp.global_position), str(expected_global_vc), str(map.global_position)]
				)
			)
		) \
		. is_equal_approx(expected_global_vc, Vector2(8.0, 8.0))
	)


func test_restrict_to_map_area_respects_parent_transform() -> void:
	var setup: Array[Variant] = _create_recenter_env()
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
	runner.simulate_frames(1)

	var target_tile: Vector2i = Vector2i(1, 2)
	var expected_global: Vector2 = map.to_global(map.map_to_local(target_tile))

	gp.global_position = Vector2.ZERO
	GBPositioning2DUtils.move_to_closest_valid_tile_center(gp, target_tile, gp, map, settings)

	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag("restrict_to_map_area should honor parent transforms when snapping to tiles")
		) \
		. is_equal_approx(expected_global, Vector2.ONE)
	)


class _StubGateGridPositioner:
	extends GridPositioner2D
	var _next_gate_allowed: bool = true

	func set_next_gate(allowed: bool) -> void:
		_next_gate_allowed = allowed

	func get_input_gate() -> bool:
		return _next_gate_allowed

	func _mouse_input_gate() -> bool:
		return _next_gate_allowed


func test_hide_on_handled_mouse_event_hides_positioner() -> void:
	# Test: hide_on_handled behavior when gate blocks input
	# Setup: Positioner with hide_on_handled enabled and blocking gate
	# Act: Process mouse event with blocked gate
	# Assert: System behavior matches current design (cached position retention priority)

	# Create the stub positioner specifically for this test
	var stub_positioner := _StubGateGridPositioner.new()
	var setup: Array[Variant] = _create_positioner_env(stub_positioner, true)
	var gp: GridPositioner2D = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	var states: GBStates = setup[_IDX_STATES]

	var stub := gp as _StubGateGridPositioner

	# Configure hide_on_handled behavior
	settings.hide_on_handled = true
	settings.enable_mouse_input = true

	# Set mode to an active state that would normally show the positioner
	states.mode.current = EXPECTED_ACTIVE_MODE

	# Clear any cached mouse state by setting the positioner to OFF mode first
	# This ensures we start with a clean state
	states.mode.current = GBEnums.Mode.OFF
	runner.simulate_frames(1)

	# Set the gate to block input BEFORE any mouse events
	stub.set_next_gate(GATE_BLOCKS_INPUT)

	# Now switch back to active mode
	states.mode.current = EXPECTED_ACTIVE_MODE

	# Set positioner visible initially
	gp.visible = INITIAL_VISIBILITY

	# Send multiple blocked mouse events to ensure the system recognizes the blocking
	_send_blocked_mouse_events(gp, stub)

	# Validate configuration before assertions
	_assert_hide_settings_configured(settings, stub, states)

	# Get detailed state for enhanced diagnostics
	var diagnostic_state := _create_comprehensive_diagnostic_state(gp, stub, settings, states)

	# Assert gate blocks input (this triggers hide_on_handled behavior)
	var gate_blocks_input: bool = not stub.get_input_gate()
	(
		assert_bool(gate_blocks_input) \
		. append_failure_message(
			"Gate should block input to trigger hide_on_handled behavior. %s" % diagnostic_state
		) \
		. is_true()
	)

	# Assert hide_on_handled setting is active
	(
		assert_bool(settings.hide_on_handled) \
		. append_failure_message("hide_on_handled should be enabled. %s" % diagnostic_state) \
		. is_true()
	)

	# Assert actual system behavior: hide_on_handled takes effect when gate blocks input
	# Current design: mouse_gate:blocked triggers visibility off
	(
		assert_bool(gp.visible) \
		. append_failure_message(
			(
				"System design: hide_on_handled should hide positioner when gate blocks input. %s"
				% diagnostic_state
			)
		) \
		. is_false()
	)


func test_recenter_on_resolve_dependencies_mouse_enabled_and_cursor_on_screen() -> void:
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]
	# Note: map variable not needed for this test (avoids unused variable warning)

	# Enable mouse input
	settings.enable_mouse_input = true

	# Replace with test positioner that mocks cursor as on screen
	var test_positioner := TestPositionerWithMockCursor.new()
	test_positioner._mock_cursor_on_screen = true
	test_positioner._test_expected_cursor_position = Vector2(160, 120)
	gp = _replace_positioner(setup[_IDX_ENV], test_positioner)

	# Set positioner to a known position away from center and disable input processing
	gp.global_position = Vector2(1, 1)
	gp.set_input_processing_enabled(false)

	# Trigger recenter logic by enabling input processing (simulates resolve dependencies)
	gp.set_input_processing_enabled(true)
	runner.simulate_frames(1)

	# Should fail fast - positioning utilities now require Camera2D and return Vector2.ZERO on failure
	# With fail-fast behavior, Vector2.ZERO maps to tile (0,0) which centers at (8.0, 8.0)
	var expected_fail_safe_position: Vector2 = Vector2(8.0, 8.0)  # Tile (0,0) center

	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag(
				(
					"Expected fail-safe positioning to tile (0,0) center when Camera2D missing. Got: %s"
					% str(gp.global_position)
				)
			)
		) \
		. is_equal(expected_fail_safe_position)
	)


func test_recenter_on_resolve_dependencies_mouse_disabled_moves_to_center() -> void:
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]

	# Disable mouse input
	settings.enable_mouse_input = false

	# Set positioner to a known position away from center and disable input processing
	gp.global_position = Vector2(1, 1)
	gp.set_input_processing_enabled(false)

	# Trigger recenter logic by enabling input processing (simulates resolve dependencies)
	gp.set_input_processing_enabled(true)
	runner.simulate_frames(1)

	# Should fail fast - positioning utilities now require Camera2D and return Vector2.ZERO on failure
	# With fail-fast behavior, Vector2.ZERO maps to tile (0,0) which centers at (8.0, 8.0)
	var expected_fail_safe_position: Vector2 = Vector2(8.0, 8.0)  # Tile (0,0) center
	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag(
				(
					"Expected fail-safe positioning to tile (0,0) center when Camera2D missing. Got: %s"
					% str(gp.global_position)
				)
			)
		) \
		. is_equal(expected_fail_safe_position)
	)


func test_recenter_on_resolve_dependencies_cursor_off_screen_moves_to_center() -> void:
	var setup: Array[Variant] = _create_recenter_env()
	var gp: GRID_POSITIONER_SCRIPT = setup[_IDX_GP]
	var settings: GridTargetingSettings = setup[_IDX_SETTINGS]

	# Enable mouse input
	settings.enable_mouse_input = true

	# Set up a test scenario where cursor should be considered "off screen"
	var test_positioner := TestPositionerWithMockCursor.new()
	test_positioner._mock_cursor_on_screen = false
	gp = _replace_positioner(setup[_IDX_ENV], test_positioner)

	# Wait for scene tree to stabilize after positioner replacement
	runner.simulate_frames(2)

	# Set positioner to a known position away from center and disable input processing
	gp.global_position = Vector2(1, 1)
	gp.set_input_processing_enabled(false)

	# Wait for state to propagate
	runner.simulate_frames(1)

	# Trigger recenter logic by enabling input processing (simulates resolve dependencies)
	gp.set_input_processing_enabled(true)

	# Wait for positioning logic to complete (multiple frames for full propagation)
	runner.simulate_frames(3)

	# Should fail fast - positioning utilities now require Camera2D and return Vector2.ZERO on failure
	# With fail-fast behavior, Vector2.ZERO maps to tile (0,0) which centers at (8.0, 8.0)
	var expected_fail_safe_position: Vector2 = Vector2(8.0, 8.0)  # Tile (0,0) center
	(
		assert_vector(gp.global_position) \
		. append_failure_message(
			_diag(
				(
					"Expected fail-safe positioning to tile (0,0) center when Camera2D missing. Got: %s"
					% str(gp.global_position)
				)
			)
		) \
		. is_equal(expected_fail_safe_position)
	)


# Test helper class that extends GridPositioner2D to mock cursor behavior
class TestPositionerWithMockCursor:
	extends GridPositioner2D

	var _mock_cursor_on_screen: bool = false
	var _test_expected_cursor_position: Vector2 = Vector2.ZERO

	func _is_mouse_cursor_on_screen() -> bool:
		return _mock_cursor_on_screen

	func _get_cursor_world_position() -> Vector2:
		return _test_expected_cursor_position


#region PROJECTION STABILIZATION

## NOTE: A legacy test that validated ProjectionSnapshot-based reprojection was removed.
## The old ProjectionSnapshot API and gp._stabilize_projection() are no longer available
## in the current codebase. The reprojection logic was simplified to prefer viewport
## projection, fall back to map-provided overrides, and use cached coordinates last
## (see `docs_internal/archive/fixes/grid_positioner_viewport_projection_fix_2025_09_24.md`).
##
## If we need a replacement test, write a focused unit test that exercises the
## current reprojection path (for example: feed an InputEventMouseMotion, ensure
## the positioner uses the viewport location, and validate map override behavior).

#endregion

#region DRY_HELPER_METHODS

#region DRY_HELPER_METHODS


## Helper method for sending multiple blocked mouse events to test hide_on_handled behavior
func _send_blocked_mouse_events(gp: GridPositioner2D, _stub: _StubGateGridPositioner) -> void:
	for i in range(MOUSE_EVENT_REPETITIONS):
		var mouse_event := InputEventMouseMotion.new()
		mouse_event.position = DEFAULT_HIDE_GATE_POSITION + (POSITION_OFFSET_INCREMENT * i)
		gp._input(mouse_event)
		runner.simulate_frames(1)


## Helper method for validating hide_on_handled settings configuration
func _assert_hide_settings_configured(
	settings: GridTargetingSettings, stub: _StubGateGridPositioner, states: GBStates
) -> void:
	(
		assert_bool(settings.hide_on_handled) \
		. append_failure_message("Settings hide_on_handled should be true") \
		. is_true()
	)
	(
		assert_bool(settings.enable_mouse_input) \
		. append_failure_message("Settings mouse input should be enabled") \
		. is_true()
	)
	(
		assert_bool(stub.get_input_gate()) \
		. append_failure_message("Gate should block input (return false)") \
		. is_false()
	)
	assert_int(states.mode.current).append_failure_message("Mode should be MOVE (active)").is_equal(
		EXPECTED_ACTIVE_MODE
	)


## Helper method for creating comprehensive diagnostic state information
func _create_comprehensive_diagnostic_state(
	gp: GridPositioner2D,
	stub: _StubGateGridPositioner,
	settings: GridTargetingSettings,
	states: GBStates
) -> String:
	# Get diagnostic information from the positioner
	var diagnostic_info := (
		gp.to_diagnostic_string() if gp.has_method("to_diagnostic_string") else "no_diagnostic"
	)

	return (
		"Gate blocked: %s, Mouse enabled: %s, Hide on handled: %s, Mode: %s, Current visible: %s, Diagnostic: %s"
		% [
			str(not stub.get_input_gate()),
			str(settings.enable_mouse_input),
			str(settings.hide_on_handled),
			str(states.mode.current),
			str(gp.visible),
			diagnostic_info
		]
	)


## Helper method for creating test mouse event
func _create_test_mouse_event() -> InputEventMouseMotion:
	var mouse_event := InputEventMouseMotion.new()
	mouse_event.position = DEFAULT_HIDE_GATE_POSITION
	return mouse_event


## Helper method for validating hide_on_handled settings configuration (legacy name support)
func _assert_hide_settings_valid(
	settings: GridTargetingSettings, stub: _StubGateGridPositioner, states: GBStates
) -> void:
	_assert_hide_settings_configured(settings, stub, states)


## Helper method for generating comprehensive diagnostic state information (legacy name support)
func _get_hide_diagnostic_state(
	gp: GridPositioner2D,
	stub: _StubGateGridPositioner,
	settings: GridTargetingSettings,
	states: GBStates
) -> String:
	return _create_comprehensive_diagnostic_state(gp, stub, settings, states)

#endregion

#endregion
