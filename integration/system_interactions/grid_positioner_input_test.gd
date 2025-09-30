## Integration tests for GridPositioner2D input handling
##
## Setup chain required for these tests to pass:
## - GBInjectorSystem injects the scene graph and calls resolve_gb_dependencies on GridPositioner2D
## - GridPositioner2D enables its ShapeCast, sets process_mode from DISABLED -> INHERIT, and validates deps
## - LevelContext applies target_map into GridTargetingState (env already wires this in _ready)
## - Tests then ensure: targeting_state.target_map is set, process_mode is NOT DISABLED, and a Camera2D is current if present
##
## Notes:
## - We validate injection by checking the injector meta on the positioner and its runtime issues before sending input.
## - Mouse tests only enable mouse input; keyboard tests enable keyboard input and assert discrete tile movements.
## MIGRATION NOTE: Shapecast logic is covered by dedicated unit tests for TargetingShapeCast2D.
## Integration tests MUST NOT exercise shapecast internals directly; remove calls to `force_shapecast_update()`
## or other shapecast APIs from these tests. Use environment-level configuration and input events to drive behavior.
extends GdUnitTestSuite

var env: CollisionTestEnvironment
var runner: GdUnitSceneRunner

# Project InputMap bindings used by GridPositioner2D
const KEY_UP: int = KEY_I
const KEY_LEFT: int = KEY_J
const KEY_DOWN: int = KEY_K
const KEY_RIGHT: int = KEY_L
const KEY_CENTER: int = KEY_C

func before_test() -> void:
	# Use a SceneRunner to exercise the real InputMap pipeline
	# Pass a resource path/UID so the SceneRunner loads the scene internally
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	# Allow scene to enter tree and _ready to run
	await runner.simulate_frames(1)
	env = runner.scene() as CollisionTestEnvironment
	
	# Set logger level to trace to see detailed debug output for GridPositioner2D
	var container: GBCompositionContainer = env.get_container()
	var logger: GBLogger = container.get_logger()
	var debug_settings: GBDebugSettings = logger.get_debug_settings()
	debug_settings.level = GBDebugSettings.LogLevel.TRACE

func after_test() -> void:
	env = null
	runner = null

## Verify the injector injected the GridPositioner2D and dependencies are resolved
func test_injector_injects_positioner_and_settings() -> void:
	assert_object(env).append_failure_message("Environment should be instantiated").is_not_null()
	var injector: GBInjectorSystem = env.injector
	var positioner: GridPositioner2D = env.positioner
	var container: GBCompositionContainer = env.get_container()
	assert_object(injector).append_failure_message("GBInjectorSystem missing from environment").is_not_null()
	assert_object(container).append_failure_message("GBCompositionContainer should be available via env.get_container()").is_not_null()
	assert_object(positioner).append_failure_message("GridPositioner2D missing from environment").is_not_null()

	# Allow one frame for _ready() and initial injection
	await get_tree().process_frame

	# Injection meta should be present and reference this injector
	var meta_present := positioner.has_meta(GBInjectorSystem.INJECTION_META_KEY)
	assert_bool(meta_present).append_failure_message("Positioner must have injector meta after initial injection").is_true()
	if meta_present:
		var meta: Dictionary = positioner.get_meta(GBInjectorSystem.INJECTION_META_KEY)
		assert_bool(meta.has("injector_id")).append_failure_message("Injector meta missing 'injector_id'").is_true()
		assert_int(meta.get("injector_id", -1)).append_failure_message("Injector id mismatch on injected positioner").is_equal(int(injector.get_instance_id()))
		# WeakRef check (best-effort)
		if meta.has("injector_ref") and meta["injector_ref"] is WeakRef:
			var ref: GBInjectorSystem = (meta["injector_ref"] as WeakRef).get_ref() as GBInjectorSystem
			assert_object(ref).append_failure_message("injector_ref WeakRef should resolve to env.injector").is_same(injector)

	# Runtime issues should be empty after dependencies are resolved
	var issues: Array[String] = positioner.get_runtime_issues()
	assert_array(issues).append_failure_message("GridPositioner2D runtime issues must be empty post-injection. Issues: %s" % [str(issues)]).is_empty()


## New test: GridPositioner2D should be visible in the scene after injection
func test_positioner_is_visible_after_injection() -> void:
	assert_object(env).append_failure_message("Environment should be instantiated").is_not_null()
	var positioner: GridPositioner2D = env.positioner
	assert_object(positioner).append_failure_message("GridPositioner2D should exist in the environment").is_not_null()

	# Allow one frame for injection and visibility updates
	await get_tree().process_frame

	# Check visibility flags and tree visibility
	var visible_flag: bool = false
	if "visible" in positioner:
		visible_flag = positioner.visible

	var visible_in_tree: bool = positioner.is_visible_in_tree()

	assert_bool(visible_flag).append_failure_message("GridPositioner2D.visible flag should be true after injection, got=%s" % [str(visible_flag)]).is_true()
	assert_bool(visible_in_tree).append_failure_message("GridPositioner2D must be visible in the scene tree after injection").is_true()

## Ensure prerequisites: target_map assigned, positioner processing, camera current
func _ensure_target_map_and_processing() -> void:
	var container: GBCompositionContainer = env.get_container()
	var gts: GridTargetingState = container.get_states().targeting
	var tile_map: TileMapLayer = env.tile_map_layer

	# Bind the environment map to targeting state if missing
	if gts.target_map == null:
		gts.target_map = tile_map

	# Sanity: targeting state and map must be set before movement
	assert_object(gts).append_failure_message("GridTargetingState should be available from environment").is_not_null()
	assert_object(gts.target_map).append_failure_message("GridTargetingState.target_map must be assigned before movement tests").is_not_null()

	# Ensure the positioner is registered on the state and actively processing
	if gts.positioner == null:
		gts.positioner = env.positioner
	# Positioner process mode can be disabled in _ready; enable once deps are set
	env.positioner.process_mode = Node.PROCESS_MODE_INHERIT
	env.positioner.set_process_input(true)
	env.positioner.set_process_unhandled_input(true)
	# Enable input processing gate explicitly (fail-fast if API missing)
	env.positioner.set_input_processing_enabled(true)
	# NOTE: Shapecast behavior is now owned by TargetingShapeCast2D (component).
	# Per migration policy, integration tests must NOT call shapecast methods directly on
	# the environment or positioner. Those assertions belong in `TargetingShapeCast2D` unit tests.
	# Therefore we do not attempt to call `force_shapecast_update()` here.

	# Hard assert: dependencies resolved on the positioner
	var pos_issues: Array[String] = env.positioner.get_runtime_issues()
	assert_array(pos_issues).append_failure_message(
		"Positioner must have no runtime issues before input; dependencies unresolved. Issues: %s" % [str(pos_issues)]
	).is_empty()

	# Validate positioner runtime dependencies
	var issues: Array[String] = env.positioner.get_runtime_issues()
	assert_array(issues).append_failure_message(
		"GridPositioner2D runtime issues must be empty before input. Issues: %s" % [str(issues)]
	).is_empty()
	# Also assert validate_dependencies() returns true (will log issues if any)
	assert_bool(env.positioner.validate_dependencies()).append_failure_message(
		"GridPositioner2D.validate_dependencies() returned false. Issues: %s" % [str(issues)]
	).is_true()

	# Process mode must not be disabled at this point
	var pm := env.positioner.process_mode
	assert_int(pm).append_failure_message(
		"GridPositioner2D.process_mode must be active. Got=%d (0=INHERIT, 1=PAUSABLE, 2=WHEN_PAUSED, 3=ALWAYS, 4=DISABLED)" % pm
	).is_not_equal(Node.PROCESS_MODE_DISABLED)

	# Assert input processing flag is enabled
	var input_gate_enabled: bool = env.positioner.input_processing_enabled if "input_processing_enabled" in env.positioner else false
	assert_bool(input_gate_enabled).append_failure_message("GridPositioner2D.input_processing_enabled must be true before sending inputs").is_true()

	# Make sure there is a current camera for screen_to_world projections
	var vp := env.get_viewport()
	var cam := vp.get_camera_2d()
	if cam == null:
		# Synthesize a camera on the same viewport as the tile map, align to map origin
		var cam_node: Camera2D = auto_free(Camera2D.new())
		cam_node.position = tile_map.global_position
		cam_node.zoom = Vector2.ONE
		# Parent camera to the tile_map so transforms align; most factories auto-add, but this is manual
		tile_map.add_child(cam_node)
		cam_node.make_current()
		cam = cam_node
	elif not cam.is_current():
		cam.make_current()

	# Assert tile_map viewport and camera availability
	var map_vp := tile_map.get_viewport()
	assert_object(map_vp).append_failure_message("TileMapLayer viewport must exist for projections").is_not_null()
	var map_cam := map_vp.get_camera_2d()
	# If map camera is null (different viewport), also ensure our synthesized/global camera is current
	if map_cam == null:
		# Already ensured a current camera above
		pass
	elif not map_cam.is_current():
		map_cam.make_current()

	await get_tree().process_frame

## DRY helper: common setup used by many tests (positioner registration, camera ensure)
func _setup_positioner_and_camera() -> void:
	# Ensure target map is assigned and positioner processing enabled
	_ensure_target_map_and_processing()
	# Ensure a Camera2D is current and viewport projections work
	var tile_map: TileMapLayer = env.tile_map_layer
	var vp := tile_map.get_viewport()
	var cam := vp.get_camera_2d()
	if cam == null or not cam.is_current():
		# Synthesize a camera if none exists or not current
		var cam_node: Camera2D = auto_free(Camera2D.new())
		cam_node.position = tile_map.global_position
		tile_map.add_child(cam_node)
		cam_node.make_current()
	await get_tree().process_frame

## Low-level input helpers (avoids SceneRunner parenting focus issues)
func _emit_mouse_motion(screen_pos: Vector2, event_position_override: Variant = null) -> void:
	# Simulate mouse move via SceneRunner and wait until processed deterministically
	runner.simulate_mouse_move(screen_pos)
	# Wait until SceneRunner confirms input was processed; avoids timing races
	await runner.await_input_processed()
	# Also send a low-level InputEventMouseMotion to the tile map viewport with a
	# correctly set global_position as screen coordinates (GridPositioner2D will convert to world)
	# (this reproduces the previous direct-node seeding in a viewport-safe way).
	# Build a mouse motion event with screen coordinates and deliver it
	# directly to the positioner to seed its cached event world (safe in tests).
	var ev := InputEventMouseMotion.new()
	if event_position_override is Vector2:
		ev.position = event_position_override
	else:
		ev.position = screen_pos
	ev.global_position = screen_pos  # Keep as screen coordinates - GridPositioner2D will convert to world
	if is_instance_valid(env) and is_instance_valid(env.positioner):
		env.positioner._input(ev)
	# Allow one idle frame for any deferred calls (visibility, recenter) to run
	await get_tree().process_frame

func _press_and_release_key(keycode: int) -> void:
	await runner.simulate_key_pressed(keycode)
	await runner.await_input_processed()

## Press a mapped action and emit a matching key event in the same frame
func _press_action_with_key(_action: StringName, keycode: int) -> void:
	# Ensure the action is mapped to this key beforehand via _ensure_action_key
	# IMPORTANT: Use only the SceneRunner to avoid double-processing the same input
	# which would result in two tile moves per press.
	runner.simulate_key_press(keycode)
	await runner.await_input_processed()
	await get_tree().process_frame

## Release an action and emit key release event
func _release_action_with_key(_action: StringName, keycode: int) -> void:
	runner.simulate_key_release(keycode)
	await runner.await_input_processed()
	await get_tree().process_frame

## Ensure an InputMap action exists and is mapped to the given keycode
func _ensure_action_key(action_name: StringName, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var exists := false
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey and (((e as InputEventKey).keycode == keycode) or ((e as InputEventKey).physical_keycode == keycode)):
			exists = true
			break
	if not exists:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode as Key
		InputMap.action_add_event(action_name, ev)

## DRY: assert that the positioner is snapped to expected tile
func _assert_at_tile(tile_map: TileMapLayer, positioner: Node2D, expected_tile: Vector2i, label: String) -> void:
	var expected_global: Vector2 = tile_map.to_global(tile_map.map_to_local(expected_tile))
	var actual_global: Vector2 = positioner.global_position
	var actual_tile: Vector2i = Vector2i.ZERO
	if tile_map != null:
		actual_tile = tile_map.local_to_map(tile_map.to_local(actual_global))

	# Gather runtime diagnostics (fail-fast on missing APIs)
	var pos_enabled: bool = false
	if positioner.has_method("is_input_processing_enabled"):
		pos_enabled = positioner.is_input_processing_enabled()
	elif "enabled" in positioner:
		pos_enabled = positioner.enabled
	var input_enabled: bool = positioner.input_processing_enabled if "input_processing_enabled" in positioner else pos_enabled
	var pmode: int = positioner.process_mode
	var runtime_issues: Array = positioner.get_runtime_issues()

	var vp: Viewport = null
	var cam: Camera2D = null
	if tile_map != null:
		vp = tile_map.get_viewport()
		if vp != null:
			cam = vp.get_camera_2d()

	var msg := "%s → Expected global=%s (tile=%s), got global=%s (tile=%s)\n" % [label, str(expected_global), str(expected_tile), str(actual_global), str(actual_tile)]
	msg += "  positioner.enabled=%s input_processing_enabled=%s process_mode=%s\n" % [str(pos_enabled), str(input_enabled), str(pmode)]
	msg += "  runtime_issues=%s\n" % [str(runtime_issues)]
	msg += "  viewport=%s camera=%s\n" % [str(vp), str(cam)]

	var diag := GBDiagnostics.format_debug(msg, "GridPositionerInput", get_script().resource_path)
	assert_vector(actual_global).append_failure_message(diag).is_equal_approx(expected_global, Vector2.ONE)

## Helper: robust screen->world projection that tolerates Camera2D API variants
func _screen_to_world_safe(vp: Viewport, _cam: Camera2D, screen_pos: Vector2) -> Vector2:
	# Use GBPositioning2DUtils centralized conversion logic
	return GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, vp)

func test_positioner_moves_on_mouse_motion_scene_runner() -> void:
	# Arrange
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	assert_that(positioner).is_not_null()
	assert_that(tile_map).is_not_null()

	await _setup_positioner_and_camera()

	# Ensure mouse input enabled in settings
	var container: GBCompositionContainer = env.get_container()
	container.config.settings.targeting.enable_mouse_input = true
	# Allow free movement to the hovered tile for this test
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false
	positioner.global_position = Vector2.ZERO
	await get_tree().process_frame

	# Act: move mouse to a screen position
	var screen_target := Vector2(160, 160)
	await _emit_mouse_motion(screen_target)

	# Compute expected by projecting screen->world via camera, then to map and back
	var map_vp := tile_map.get_viewport()
	var cam := map_vp.get_camera_2d()
	var map_vp_mouse: Variant = null
	if map_vp != null:
		map_vp_mouse = map_vp.get_mouse_position()
	var map_global_mouse: Variant = null
	if tile_map != null:
		map_global_mouse = tile_map.get_global_mouse_position()
	var world_point: Vector2 = _screen_to_world_safe(tile_map.get_viewport(), cam, screen_target)
	var expected_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_point))
	var expected_global: Vector2 = tile_map.to_global(tile_map.map_to_local(expected_tile))

	var gts := env.get_container().get_states().targeting
	var actions := env.get_container().get_actions()
	var is_up := Input.is_action_pressed(actions.positioner_up) if actions else false
	var is_down := Input.is_action_pressed(actions.positioner_down) if actions else false
	var is_left := Input.is_action_pressed(actions.positioner_left) if actions else false
	var is_right := Input.is_action_pressed(actions.positioner_right) if actions else false
	var diag := "Mouse move diagnostics:\n" \
		+ "  settings: {mouse=%s, keyboard=%s}\n" % [str(env.get_container().config.settings.targeting.enable_mouse_input), str(env.get_container().config.settings.targeting.enable_keyboard_input)] \
		+ "  process_mode=%d\n" % [env.positioner.process_mode] \
		+ "  target_map=%s\n" % [str(gts.target_map)] \
		+ "  event_screen=%s world=%s -> expected_tile=%s expected_global=%s\n" % [str(screen_target), str(world_point), str(expected_tile), str(expected_global)] \
		+ "  viewport_mouse=%s map_global_mouse=%s\n" % [str(map_vp_mouse), str(map_global_mouse)] \
		+ "  actual_global=%s actual_tile=%s\n" % [str(positioner.global_position), str(tile_map.local_to_map(tile_map.to_local(positioner.global_position)))] \
		+ "  actions_pressed: up=%s down=%s left=%s right=%s\n" % [str(is_up), str(is_down), str(is_left), str(is_right)]
	var mdiag := GBDiagnostics.format_debug("GridPositioner2D did not update on mouse move.\n" + diag, "GridPositionerInput", get_script().resource_path)
	assert_vector(positioner.global_position).append_failure_message(mdiag).is_equal_approx(expected_global, Vector2.ONE)

func test_mouse_motion_prefers_viewport_position_when_event_differs() -> void:
	# Arrange
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	assert_that(positioner).is_not_null()
	assert_that(tile_map).is_not_null()

	await _setup_positioner_and_camera()

	var container: GBCompositionContainer = env.get_container()
	container.config.settings.targeting.enable_mouse_input = true
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false

	positioner.global_position = Vector2.ZERO
	await get_tree().process_frame

	# Act: deliver mouse motion where event.position differs from viewport mouse
	var screen_target := Vector2(208, 176)
	var faulty_event_screen := Vector2.ZERO
	await _emit_mouse_motion(screen_target, faulty_event_screen)

	# Expected world from the actual viewport mouse position
	var vp := tile_map.get_viewport()
	var cam := vp.get_camera_2d()
	var vp_mouse: Variant = null
	if vp != null:
		vp_mouse = vp.get_mouse_position()
	var map_mouse_world: Variant = null
	if tile_map != null:
		map_mouse_world = tile_map.get_global_mouse_position()
	var world_point: Vector2 = _screen_to_world_safe(vp, cam, screen_target)
	var expected_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_point))
	var expected_global: Vector2 = tile_map.to_global(tile_map.map_to_local(expected_tile))

	var diag := "Viewport projection should win when InputEventMouseMotion.position is stale.\n" \
		+ "  viewport_mouse=%s\n" % [str(screen_target)] \
		+ "  viewport_state_mouse=%s map_global_mouse=%s\n" % [str(vp_mouse), str(map_mouse_world)] \
		+ "  event_override=%s\n" % [str(faulty_event_screen)] \
		+ "  expected_tile=%s expected_global=%s\n" % [str(expected_tile), str(expected_global)] \
		+ "  actual_global=%s actual_tile=%s\n" % [str(positioner.global_position), str(tile_map.local_to_map(tile_map.to_local(positioner.global_position)))]
	var formatted := GBDiagnostics.format_debug(diag, "GridPositionerInput", get_script().resource_path)
	assert_vector(positioner.global_position).append_failure_message(formatted).is_equal_approx(expected_global, Vector2.ONE)

func test_keyboard_moves_and_recenter() -> void:
	# Arrange: enable keyboard input and move to a known tile
	var container: GBCompositionContainer = env.get_container()
	var actions: GBActions = container.get_actions()
	container.config.settings.targeting.enable_keyboard_input = true
	container.config.settings.targeting.enable_mouse_input = true
	# Configure recenter to use mouse position instead of screen center
	container.config.settings.targeting.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE
	# Allow discrete movement independent of region restrictions in this test
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false

	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer

	await _setup_positioner_and_camera()


	# Start at a known tile index
	var start_tile: Vector2i = Vector2i(5, 5)
	var start_global: Vector2 = tile_map.to_global(tile_map.map_to_local(start_tile))
	positioner.global_position = start_global
	await get_tree().process_frame

	# Ensure InputMap has expected bindings (some are empty in project.godot)
	_ensure_action_key(actions.positioner_up, KEY_UP)
	_ensure_action_key(actions.positioner_down, KEY_DOWN)
	_ensure_action_key(actions.positioner_left, KEY_LEFT)
	_ensure_action_key(actions.positioner_right, KEY_RIGHT)
	_ensure_action_key(actions.positioner_center, KEY_CENTER)

	# Act + Assert: Up (y - 1)
	var up_expected: Vector2i = start_tile + Vector2i(0, -1)
	await _press_action_with_key(actions.positioner_up, KEY_UP)
	await _release_action_with_key(actions.positioner_up, KEY_UP)
	_assert_at_tile(tile_map, positioner, up_expected, "Keyboard up")

	# Act + Assert: Down (y + 1) back to start
	var down_expected: Vector2i = start_tile
	await _press_action_with_key(actions.positioner_down, KEY_DOWN)
	await _release_action_with_key(actions.positioner_down, KEY_DOWN)
	_assert_at_tile(tile_map, positioner, down_expected, "Keyboard down")

	# Act + Assert: Left (x - 1)
	var left_expected: Vector2i = start_tile + Vector2i(-1, 0)
	await _press_action_with_key(actions.positioner_left, KEY_LEFT)
	await _release_action_with_key(actions.positioner_left, KEY_LEFT)
	_assert_at_tile(tile_map, positioner, left_expected, "Keyboard left")

	# Act + Assert: Right (x + 1) back to start
	var right_expected: Vector2i = start_tile
	await _press_action_with_key(actions.positioner_right, KEY_RIGHT)
	await _release_action_with_key(actions.positioner_right, KEY_RIGHT)
	_assert_at_tile(tile_map, positioner, right_expected, "Keyboard right")

	# Act + Assert: Recenter to the current cursor tile (seed mouse first)
	var vp := tile_map.get_viewport()
	var cam := vp.get_camera_2d()
	var recenter_screen := Vector2(224, 176)
	await _emit_mouse_motion(recenter_screen)
	var cursor_world: Vector2 = _screen_to_world_safe(vp, cam, recenter_screen)
	var cursor_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(cursor_world))
	var cursor_global: Vector2 = tile_map.to_global(tile_map.map_to_local(cursor_tile))

	# Recenter via key bound to the recenter action (should snap to cursor tile)
	await _press_action_with_key(actions.positioner_center, KEY_CENTER)
	await _release_action_with_key(actions.positioner_center, KEY_CENTER)
	var pressed_recenter := Input.is_action_pressed(actions.positioner_center) if actions else false
	var kdiag := "Recenter diagnostics:\n" \
		+ "  process_mode=%d\n" % [env.positioner.process_mode] \
		+ "  recenter_screen=%s cursor_world=%s cursor_tile=%s\n" % [str(recenter_screen), str(cursor_world), str(cursor_tile)] \
		+ "  expected_global=%s actual_global=%s\n" % [str(cursor_global), str(positioner.global_position)] \
		+ "  recenter_action_pressed=%s\n" % [str(pressed_recenter)]
	var rdiag := GBDiagnostics.format_debug("Keyboard recenter failed.\n" + kdiag, "GridPositionerInput", get_script().resource_path)
	assert_vector(positioner.global_position).append_failure_message(rdiag).is_equal_approx(cursor_global, Vector2.ONE)

## New: When movement is enabled again, recenter to mouse position if mouse enabled
func test_recenter_on_enable_prefers_mouse_when_enabled() -> void:
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	await _setup_positioner_and_camera()

	var container: GBCompositionContainer = env.get_container()
	var settings := container.config.settings.targeting
	settings.enable_mouse_input = true
	settings.enable_keyboard_input = false
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR
	# Configure manual recenter to use mouse position
	settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE

	# Move the mouse to a known screen position and deliver event to cache world
	var screen_target := Vector2(128, 128)
	await _emit_mouse_motion(screen_target)

	# Disable and then re-enable input processing to trigger recenter
	positioner.set_input_processing_enabled(false)
	await get_tree().process_frame
	positioner.set_input_processing_enabled(true)
	await get_tree().process_frame

	# Expected: snapped to the tile under the screen_target projection
	var cam := tile_map.get_viewport().get_camera_2d()
	var world_point: Vector2 = _screen_to_world_safe(tile_map.get_viewport(), cam, screen_target)
	var expected_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_point))
	_assert_at_tile(tile_map, positioner, expected_tile, "Recenter on enable (mouse)")

## New: When only keyboard is enabled, recenter to screen center on enable
func test_recenter_on_enable_keyboard_only_to_view_center() -> void:
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	await _ensure_target_map_and_processing()

	var container: GBCompositionContainer = env.get_container()
	var settings := container.config.settings.targeting
	settings.enable_mouse_input = false
	settings.enable_keyboard_input = true
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER

	# Place positioner away from center
	positioner.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(1,1)))
	await get_tree().process_frame

	positioner.set_input_processing_enabled(false)
	await get_tree().process_frame
	positioner.set_input_processing_enabled(true)
	await get_tree().process_frame

	var vp := tile_map.get_viewport()
	var cam := vp.get_camera_2d()
	var screen_center: Vector2 = vp.get_visible_rect().size / 2.0
	var world_center: Vector2 = _screen_to_world_safe(vp, cam, screen_center)
	var expected_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_center))
	_assert_at_tile(tile_map, positioner, expected_tile, "Recenter on enable (keyboard center)")

## New: When use_cached_location_on_enable is true, prefer last cached location
func test_recenter_on_enable_prefers_cached_when_option_true() -> void:
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	await _ensure_target_map_and_processing()

	var container: GBCompositionContainer = env.get_container()
	var settings := container.config.settings.targeting
	# We'll temporarily enable mouse to seed the cached world position, then disable it
	settings.enable_mouse_input = true
	settings.enable_keyboard_input = true
	settings.position_on_enable_policy = GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN
	# Configure manual recenter to use mouse position
	settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE

	# Seed a cached location by sending a mouse motion event once
	var seed_screen := Vector2(96, 96)
	await _emit_mouse_motion(seed_screen)
	# Now disable mouse input to verify cached preference is used even without mouse
	settings.enable_mouse_input = false

	# Move the positioner somewhere else
	positioner.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(0,0)))
	await get_tree().process_frame

	# Disable and re-enable to trigger recenter; should snap back to cached location tile
	positioner.set_input_processing_enabled(false)
	await get_tree().process_frame
	positioner.set_input_processing_enabled(true)
	await get_tree().process_frame

	var cam := tile_map.get_viewport().get_camera_2d()
	var cached_world: Vector2 = _screen_to_world_safe(tile_map.get_viewport(), cam, seed_screen)
	var expected_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(cached_world))
	_assert_at_tile(tile_map, positioner, expected_tile, "Recenter on enable (cached)")

## Combined input: when both mouse and keyboard are enabled, and no mouse cache exists yet,
## a keyboard press should move relative to the current tile; once a mouse motion occurs,
## the positioner should snap to the mouse tile as normal (all movements are tile-snapped).
func test_combined_keyboard_then_mouse_moves() -> void:
	# Arrange
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	assert_that(positioner).is_not_null()
	assert_that(tile_map).is_not_null()

	await _ensure_target_map_and_processing()

	var container: GBCompositionContainer = env.get_container()
	var actions: GBActions = container.get_actions()
	container.config.settings.targeting.enable_mouse_input = true
	container.config.settings.targeting.enable_keyboard_input = true
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false
	# Ensure continuous mouse follow even if mode is OFF in this test environment
	container.config.settings.targeting.remain_active_in_off_mode = true

	# Start from a known tile; avoid seeding mouse cache so keyboard move is observable
	var start_tile: Vector2i = Vector2i(3, 3)
	positioner.global_position = tile_map.to_global(tile_map.map_to_local(start_tile))
	await get_tree().process_frame

	# Ensure key bindings
	_ensure_action_key(actions.positioner_right, KEY_RIGHT)

	# Act 1: keyboard move right by one tile (no mouse cache yet)
	var expected_after_keyboard: Vector2i = start_tile + Vector2i(1, 0)
	await _press_action_with_key(actions.positioner_right, KEY_RIGHT)
	await _release_action_with_key(actions.positioner_right, KEY_RIGHT)
	_assert_at_tile(tile_map, positioner, expected_after_keyboard, "Combined input: keyboard step")

	# Act 2: now move mouse to screen position; positioner should snap to that tile
	var screen_target := Vector2(200, 140)
	await _emit_mouse_motion(screen_target)
	var cam := tile_map.get_viewport().get_camera_2d()
	var world_point: Vector2 = _screen_to_world_safe(tile_map.get_viewport(), cam, screen_target)
	var expected_mouse_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_point))
	_assert_at_tile(tile_map, positioner, expected_mouse_tile, "Combined input: mouse snap")

## Combined input precedence: when both are enabled and a mouse world cache exists,
## a keyboard press should not persistently override the mouse-follow position; after a subsequent
## mouse motion event, the positioner remains snapped to the last mouse tile (event-driven model).
func test_combined_mouse_cached_then_keyboard_does_not_override_follow() -> void:
	# Arrange
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	await _ensure_target_map_and_processing()

	var container: GBCompositionContainer = env.get_container()
	var actions: GBActions = container.get_actions()
	container.config.settings.targeting.enable_mouse_input = true
	container.config.settings.targeting.enable_keyboard_input = true
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false
	# Ensure continuous mouse follow even if mode is OFF in this test environment
	container.config.settings.targeting.remain_active_in_off_mode = true

	# Seed mouse cache and place positioner by emitting a mouse motion
	var seed_screen := Vector2(180, 180)
	await _emit_mouse_motion(seed_screen)
	var cam := tile_map.get_viewport().get_camera_2d()
	var seed_world: Vector2 = _screen_to_world_safe(tile_map.get_viewport(), cam, seed_screen)
	var mouse_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(seed_world))
	_assert_at_tile(tile_map, positioner, mouse_tile, "Combined input: initial mouse placement")

	# Ensure key binding and press a keyboard move; with event-driven follow, we must emit
	# a subsequent mouse motion to reassert the mouse tile after the keyboard step.
	_ensure_action_key(actions.positioner_up, KEY_UP)
	await _press_action_with_key(actions.positioner_up, KEY_UP)
	await _release_action_with_key(actions.positioner_up, KEY_UP)
	# Re-emit the same mouse position to reassert follow under event-driven input
	await _emit_mouse_motion(seed_screen)
	_assert_at_tile(tile_map, positioner, mouse_tile, "Combined input: mouse follow wins after keyboard")

## Comprehensive movement debug: verify event-driven movement, visual visibility, and last mouse input status
## This test intentionally relies only on InputEventMouseMotion delivery and never on physics-process follow.
func test_movement_debug_event_driven_and_visual_visible() -> void:
	# Arrange
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	assert_that(positioner).is_not_null()
	assert_that(tile_map).is_not_null()

	await _ensure_target_map_and_processing()

	var container: GBCompositionContainer = env.get_container()
	var settings := container.config.settings.targeting
	settings.enable_mouse_input = true
	settings.enable_keyboard_input = false
	settings.restrict_to_map_area = false
	settings.limit_to_adjacent = false

	# Ensure any visual under the positioner is visible (scene template should attach one)
	# This is a best-effort check using the runtime helper API
	var visual_node := positioner.get_visual_node() if positioner.has_method("get_visual_node") else null

	# Act: move to three different screen points, asserting each settles by event
	var points := [Vector2(120, 120), Vector2(200, 160), Vector2(260, 220)]
	for screen_pt: Vector2 in points:
		await _emit_mouse_motion(screen_pt)
		var vp := tile_map.get_viewport()
		var cam := vp.get_camera_2d()
		var w := _screen_to_world_safe(vp, cam, screen_pt)
		var tile := tile_map.local_to_map(tile_map.to_local(w))
		var expected_global := tile_map.to_global(tile_map.map_to_local(tile))

		# Assert the positioner moved by handling the input event (not physics)
		var move_diag := "Movement Debug\n" \
			+ "  screen=\"%s\" world=\"%s\" tile=\"%s\" expected_global=\"%s\"\n" % [str(screen_pt), str(w), str(tile), str(expected_global)] \
			+ "  actual_global=\"%s\"\n" % [str(positioner.global_position)]
		var formatted := GBDiagnostics.format_debug(move_diag, "GridPositionerInput", get_script().resource_path)
		assert_vector(positioner.global_position).append_failure_message(formatted).is_equal_approx(expected_global, Vector2.ONE)

		# Assert we recorded a last mouse input status indicating the event was handled (best-effort)
		var status: Dictionary = {}
		if "get_last_mouse_input_status" in positioner:
			status = positioner.get_last_mouse_input_status()
		if status.size() > 0:
			var status_diag := "Last mouse status: %s" % [str(status)]
			var sformatted := GBDiagnostics.format_debug(status_diag, "GridPositionerInput", get_script().resource_path)
			assert_bool(status.get("allowed", false)).append_failure_message(sformatted).is_true()
			# If provided, ensure method and screen match expectations best-effort
			if status.has("screen"):
				assert_vector(status.screen).append_failure_message("last status screen mismatch").is_equal_approx(screen_pt, Vector2.ONE)

		# Visual node should be visible when mouse_handled toggles allow visibility (best-effort)
		if visual_node != null:
			var vis_diag := "Visual node visibility: %s (%s)" % [str(visual_node.visible), visual_node.get_class()]
			var vformatted := GBDiagnostics.format_debug(vis_diag, "GridPositionerInput", get_script().resource_path)
			assert_bool(visual_node.visible).append_failure_message(vformatted).is_true()

## Test: Manual recenter with "Center on Mouse" mode should move positioner to mouse position
func test_manual_recenter_center_on_mouse_moves_to_cursor() -> void:
	# Arrange: Set up environment with manual recenter mode set to CENTER_ON_MOUSE
	var container: GBCompositionContainer = env.get_container()
	var actions: GBActions = container.get_actions()
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	
	await _setup_positioner_and_camera()
	
	# Configure settings for manual recenter test
	container.config.settings.targeting.enable_keyboard_input = true
	container.config.settings.targeting.enable_mouse_input = true
	container.config.settings.targeting.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE
	# Allow free movement for this test
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false

	# Ensure action binding exists
	_ensure_action_key(actions.positioner_center, KEY_CENTER)

	# Position positioner at a known starting location
	var start_tile: Vector2i = Vector2i(2, 2)
	var start_global: Vector2 = tile_map.to_global(tile_map.map_to_local(start_tile))
	positioner.global_position = start_global
	await get_tree().process_frame

	# Move mouse to a different location and ensure positioner has mouse data
	var mouse_screen_pos: Vector2 = Vector2(200, 150)
	await _emit_mouse_motion(mouse_screen_pos)
	await get_tree().process_frame

	# Calculate expected position after recenter
	var vp := tile_map.get_viewport()
	var cam := vp.get_camera_2d()
	var mouse_world: Vector2 = _screen_to_world_safe(vp, cam, mouse_screen_pos)
	var expected_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(mouse_world))
	var expected_global: Vector2 = tile_map.to_global(tile_map.map_to_local(expected_tile))

	# Act: Trigger manual recenter via C key
	await _press_action_with_key(actions.positioner_center, KEY_CENTER)
	await _release_action_with_key(actions.positioner_center, KEY_CENTER)
	await get_tree().process_frame

	# Assert: Positioner should have moved to the mouse cursor tile
	var actual_global: Vector2 = positioner.global_position
	var actual_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(actual_global))
	
	var diagnostics := "Manual recenter with CENTER_ON_MOUSE failed:\n"
	diagnostics += "  start_tile=%s start_global=%s\n" % [str(start_tile), str(start_global)]
	diagnostics += "  mouse_screen_pos=%s mouse_world=%s\n" % [str(mouse_screen_pos), str(mouse_world)]
	diagnostics += "  expected_tile=%s expected_global=%s\n" % [str(expected_tile), str(expected_global)]
	diagnostics += "  actual_tile=%s actual_global=%s\n" % [str(actual_tile), str(actual_global)]
	diagnostics += "  manual_recenter_mode=%d (CENTER_ON_MOUSE=%d)\n" % [container.config.settings.targeting.manual_recenter_mode, GBEnums.CenteringMode.CENTER_ON_MOUSE]
	diagnostics += "  enable_keyboard_input=%s enable_mouse_input=%s\n" % [str(container.config.settings.targeting.enable_keyboard_input), str(container.config.settings.targeting.enable_mouse_input)]
	
	var formatted_diag := GBDiagnostics.format_debug(diagnostics, "GridPositionerInput", get_script().resource_path)
	assert_vector(actual_global).append_failure_message(formatted_diag).is_equal_approx(expected_global, Vector2.ONE)
