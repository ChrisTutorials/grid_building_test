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
extends GdUnitTestSuite

var env: CollisionTestEnvironment

# Project InputMap bindings used by GridPositioner2D
const KEY_UP: int = KEY_I
const KEY_LEFT: int = KEY_J
const KEY_DOWN: int = KEY_K
const KEY_RIGHT: int = KEY_L
const KEY_CENTER: int = KEY_C

func before_test() -> void:
	env = UnifiedTestFactory.instance_collision_test_env(self, GBTestConstants.COLLISION_TEST_ENV_UID)

func after_test() -> void:
	env = null

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
	env.positioner.enabled = true
	# Ensure input processing gate is enabled for tests (some test envs bypass injector lifecycle)
	if env.positioner.has_method("set_input_processing_enabled"):
		env.positioner.set_input_processing_enabled(true)
	env.positioner.force_shapecast_update()

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

## Low-level input helpers (avoids SceneRunner parenting focus issues)
func _emit_mouse_motion(screen_pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = screen_pos
	# Provide global_position for fallback paths
	ev.global_position = screen_pos
	# Dispatch globally; rely on normal input flow
	Input.parse_input_event(ev)
	await get_tree().physics_frame

func _press_and_release_key(keycode: int) -> void:
	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = keycode as Key
	press.physical_keycode = keycode as Key
	Input.parse_input_event(press)
	await get_tree().physics_frame

## Press a mapped action and emit a matching key event in the same frame
func _press_action_with_key(action: StringName, keycode: int) -> void:
	Input.action_press(action)
	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = keycode as Key
	press.physical_keycode = keycode as Key
	Input.parse_input_event(press)
	await get_tree().physics_frame

## Release an action and emit key release event
func _release_action_with_key(action: StringName, keycode: int) -> void:
	var key_release := InputEventKey.new()
	key_release.pressed = false
	key_release.keycode = keycode as Key
	key_release.physical_keycode = keycode as Key
	Input.parse_input_event(key_release)
	Input.action_release(action)
	await get_tree().physics_frame

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

	# Gather runtime diagnostics (best-effort)
	var pos_enabled: bool = false
	var input_enabled: bool = false
	var pmode: int = -1
	var runtime_issues: Array = []
	if is_instance_valid(positioner):
		if "enabled" in positioner:
			pos_enabled = positioner.enabled
		if "input_processing_enabled" in positioner:
			input_enabled = positioner.input_processing_enabled
		if "process_mode" in positioner:
			pmode = positioner.process_mode
		if positioner.has_method("get_runtime_issues"):
			runtime_issues = positioner.get_runtime_issues()

	var vp: Viewport = null
	var cam: Camera2D = null
	if tile_map != null:
		vp = tile_map.get_viewport()
		if vp != null and vp.has_method("get_camera_2d"):
			cam = vp.get_camera_2d()

	var msg := "%s → Expected global=%s (tile=%s), got global=%s (tile=%s)\n" % [label, str(expected_global), str(expected_tile), str(actual_global), str(actual_tile)]
	msg += "  positioner.enabled=%s input_processing_enabled=%s process_mode=%s\n" % [str(pos_enabled), str(input_enabled), str(pmode)]
	msg += "  runtime_issues=%s\n" % [str(runtime_issues)]
	msg += "  viewport=%s camera=%s\n" % [str(vp), str(cam)]

	assert_vector(actual_global).append_failure_message(msg).is_equal_approx(expected_global, Vector2.ONE)

## Helper: robust screen->world projection that tolerates Camera2D API variants
func _screen_to_world_safe(vp: Viewport, cam: Camera2D, screen_pos: Vector2) -> Vector2:
	if cam != null:
		if cam.has_method("screen_to_world"):
			return cam.screen_to_world(screen_pos)
		if cam.has_method("unproject_position"):
			return cam.unproject_position(screen_pos)
		# Fallback: try camera global transform inverse
		if cam is Camera2D:
			var xform := cam.get_global_transform().affine_inverse()
			return xform * screen_pos
	# As final fallback, use the viewport canvas transform inverse
	if vp != null and vp.has_method("get_canvas_transform"):
		var ct := vp.get_canvas_transform()
		return ct.affine_inverse() * screen_pos
	return screen_pos

func test_positioner_moves_on_mouse_motion_scene_runner() -> void:
	# Arrange
	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer
	assert_that(positioner).is_not_null()
	assert_that(tile_map).is_not_null()

	await _ensure_target_map_and_processing()

	# Ensure mouse input enabled in settings
	var container: GBCompositionContainer = env.get_container()
	container.config.settings.targeting.enable_mouse_input = true
	positioner.global_position = Vector2.ZERO
	await get_tree().process_frame

	# Act: move mouse to a screen position
	var screen_target := Vector2(160, 160)
	await _emit_mouse_motion(screen_target)

	# Compute expected by projecting screen->world via camera, then to map and back
	var cam := tile_map.get_viewport().get_camera_2d()
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
		+ "  actual_global=%s actual_tile=%s\n" % [str(positioner.global_position), str(tile_map.local_to_map(tile_map.to_local(positioner.global_position)))] \
		+ "  actions_pressed: up=%s down=%s left=%s right=%s\n" % [str(is_up), str(is_down), str(is_left), str(is_right)]

	assert_vector(positioner.global_position).append_failure_message(
		"GridPositioner2D did not update on mouse move.\n" + diag
	).is_equal_approx(expected_global, Vector2.ONE)

func test_keyboard_moves_and_recenter() -> void:
	# Arrange: enable keyboard input and move to a known tile
	var container: GBCompositionContainer = env.get_container()
	var actions: GBActions = container.get_actions()
	container.config.settings.targeting.enable_keyboard_input = true

	var positioner: GridPositioner2D = env.positioner
	var tile_map: TileMapLayer = env.tile_map_layer

	await _ensure_target_map_and_processing()


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
	_ensure_action_key(actions.positioner_recenter, KEY_CENTER)

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

	# Act + Assert: Recenter to camera/viewport center tile
	var vp := tile_map.get_viewport()
	var cam := vp.get_camera_2d()
	var screen_center: Vector2 = vp.get_visible_rect().size / 2.0
	var world_center: Vector2 = _screen_to_world_safe(vp, cam, screen_center)
	var center_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(world_center))
	var center_global: Vector2 = tile_map.to_global(tile_map.map_to_local(center_tile))

	# Recenter via key bound to the recenter action
	await _press_action_with_key(actions.positioner_recenter, KEY_CENTER)
	await _release_action_with_key(actions.positioner_recenter, KEY_CENTER)

	var pressed_recenter := Input.is_action_pressed(actions.positioner_recenter) if actions else false
	var kdiag := "Recenter diagnostics:\n" \
		+ "  process_mode=%d\n" % [env.positioner.process_mode] \
		+ "  screen_center=%s world_center=%s center_tile=%s\n" % [str(screen_center), str(world_center), str(center_tile)] \
		+ "  expected_global=%s actual_global=%s\n" % [str(center_global), str(positioner.global_position)] \
		+ "  recenter_action_pressed=%s\n" % [str(pressed_recenter)]
	assert_vector(positioner.global_position).append_failure_message(
		"Keyboard recenter failed.\n" + kdiag
	).is_equal_approx(center_global, Vector2.ONE)
