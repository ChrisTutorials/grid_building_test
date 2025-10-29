## Debug test for recenter operation failures
extends GdUnitTestSuite

var container: GBCompositionContainer
var positioner: GridPositioner2D
var tile_map: TileMapLayer


func before_test() -> void:
	container = GBTestConstants.TEST_COMPOSITION_CONTAINER.duplicate(true)
	positioner = GridPositioner2D.new()
	add_child(positioner)
	auto_free(positioner)
	tile_map = GodotTestFactory.create_tile_map_layer(self)

	# Set up dependencies
	positioner.resolve_gb_dependencies(container)

	# Set up camera like in the failing tests
	var camera: Camera2D = Camera2D.new()
	camera.position = tile_map.global_position  # (0, 0)
	tile_map.add_child(camera)
	camera.make_current()

	await get_tree().process_frame


func test_debug_recenter_operations() -> void:
	var diag: PackedStringArray = PackedStringArray()
	diag.append("=== RECENTER DEBUG TEST ===")

	# Check initial state
	diag.append("Initial positioner position: %s" % [str(positioner.global_position)])
	diag.append(
		(
			"Initial tile: %s"
			% [
				str(
					GBPositioning2DUtils.get_tile_from_global_position(
						positioner.global_position, tile_map
					)
				)
			]
		)
	)

	# Check dependencies
	diag.append("\n=== DEPENDENCY CHECK ===")
	diag.append("is_input_ready(): %s" % [str(positioner.is_input_ready())])
	diag.append("targeting_state: %s" % [str(positioner._targeting_state)])
	if positioner._targeting_state:
		diag.append("target_map: %s" % [str(positioner._targeting_state.target_map)])
	else:
		diag.append("target_map: null")
	diag.append("targeting_settings: %s" % [str(positioner._targeting_settings)])
	diag.append("input_processing_enabled: %s" % [str(positioner.input_processing_enabled)])

	# Check viewport and camera
	diag.append("\n=== VIEWPORT/CAMERA CHECK ===")
	var vp: Viewport = tile_map.get_viewport()
	var cam: Camera2D = vp.get_camera_2d()
	diag.append("viewport: %s" % [str(vp)])
	diag.append("camera: %s" % [str(cam)])
	if cam:
		diag.append("camera position: %s" % [str(cam.global_position)])
	else:
		diag.append("camera position: null")
	diag.append("viewport size: %s" % [str(vp.get_visible_rect().size)])

	# Test viewport center calculation
	diag.append("\n=== VIEWPORT CENTER TEST ===")
	var viewport_center_world: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(vp)
	var viewport_center_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(
		viewport_center_world, tile_map
	)
	diag.append("viewport center world: %s" % [str(viewport_center_world)])
	diag.append("viewport center tile: %s" % [str(viewport_center_tile)])

	# Test move_to_viewport_center_tile directly
	diag.append("\n=== DIRECT VIEWPORT CENTER MOVE ===")
	diag.append("Before move_to_viewport_center_tile: %s" % [str(positioner.global_position)])
	var result_tile: Vector2i = positioner.move_to_viewport_center_tile()
	diag.append("After move_to_viewport_center_tile: %s" % [str(positioner.global_position)])
	diag.append("Returned tile: %s" % [str(result_tile)])

	# Test cursor move with specific screen position
	diag.append("\n=== CURSOR MOVE TEST ===")
	var screen_pos: Vector2 = Vector2(224, 176)
	var cursor_world: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(
		screen_pos, vp
	)
	var cursor_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(
		cursor_world, tile_map
	)
	diag.append("Screen pos: %s" % [str(screen_pos)])
	diag.append("Cursor world: %s" % [str(cursor_world)])
	diag.append("Cursor tile: %s" % [str(cursor_tile)])

	# Simulate mouse input to cache position
	var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.position = screen_pos
	mouse_event.global_position = cursor_world
	positioner._input(mouse_event)

	diag.append("Before move_to_cursor_center_tile: %s" % [str(positioner.global_position)])
	var cursor_result_tile: Vector2i = positioner.move_to_cursor_center_tile()
	diag.append("After move_to_cursor_center_tile: %s" % [str(positioner.global_position)])
	diag.append("Returned cursor tile: %s" % [str(cursor_result_tile)])

	# Test recenter on enable
	diag.append("\n=== RECENTER ON ENABLE TEST ===")

	# Set up settings for mouse recenter
	var settings: GridTargetingSettings = container.config.settings.targeting
	settings.enable_mouse_input = true
	settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE

	diag.append("Settings - mouse enabled: %s" % [str(settings.enable_mouse_input)])
	diag.append("Settings - manual recenter mode: %s" % [str(settings.manual_recenter_mode)])
	diag.append(
		"Settings - position on enable policy: %s" % [str(settings.position_on_enable_policy)]
	)

	# Test _apply_recenter_on_enable
	diag.append("Before _apply_recenter_on_enable: %s" % [str(positioner.global_position)])
	positioner._apply_recenter_on_enable()
	diag.append("After _apply_recenter_on_enable: %s" % [str(positioner.global_position)])

	# Check for any issues that might cause fallback
	diag.append("\n=== DIAGNOSTIC CHECKS ===")
	var disabled_in_off_mode: bool = (
		positioner._is_disabled_in_off_mode()
		if positioner.has_method("_is_disabled_in_off_mode")
		else false
	)
	var mouse_on_screen: bool = (
		positioner._is_mouse_cursor_on_screen()
		if positioner.has_method("_is_mouse_cursor_on_screen")
		else false
	)
	diag.append("disabled_in_off_mode: %s" % [str(disabled_in_off_mode)])
	diag.append("mouse_on_screen: %s" % [str(mouse_on_screen)])

	# Attach diagnostics to a meaningful assertion so failure messages include the collected data
	# Assert that the positioner moved from the origin (sanity check for recenter operations)
	(
		assert_bool(positioner.global_position != Vector2.ZERO) \
		. append_failure_message("%s" % "\n".join(diag)) \
		. is_true()
	)
