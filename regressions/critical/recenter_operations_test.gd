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
	GBTestDiagnostics.buffer("=== RECENTER DEBUG TEST ===")
	
	# Check initial state
	GBTestDiagnostics.buffer("Initial positioner position: %s" % [str(positioner.global_position)])
	GBTestDiagnostics.buffer("Initial tile: %s" % [str(GBPositioning2DUtils.get_tile_from_global_position(positioner.global_position, tile_map))])
	
	# Check dependencies
	GBTestDiagnostics.buffer("\n=== DEPENDENCY CHECK ===")
	GBTestDiagnostics.buffer("is_input_ready(): %s" % [str(positioner.is_input_ready())])
	GBTestDiagnostics.buffer("targeting_state: %s" % [str(positioner._targeting_state)])
	if positioner._targeting_state:
		GBTestDiagnostics.buffer("target_map: %s" % [str(positioner._targeting_state.target_map)])
	else:
		GBTestDiagnostics.buffer("target_map: null")
	GBTestDiagnostics.buffer("targeting_settings: %s" % [str(positioner._targeting_settings)])
	GBTestDiagnostics.buffer("input_processing_enabled: %s" % [str(positioner.input_processing_enabled)])
	
	# Check viewport and camera
	GBTestDiagnostics.buffer("\n=== VIEWPORT/CAMERA CHECK ===")
	var vp: Viewport = tile_map.get_viewport()
	var cam: Camera2D = vp.get_camera_2d()
	GBTestDiagnostics.buffer("viewport: %s" % [str(vp)])
	GBTestDiagnostics.buffer("camera: %s" % [str(cam)])
	if cam:
		GBTestDiagnostics.buffer("camera position: %s" % [str(cam.global_position)])
	else:
		GBTestDiagnostics.buffer("camera position: null")
	GBTestDiagnostics.buffer("viewport size: %s" % [str(vp.get_visible_rect().size)])
	
	# Test viewport center calculation
	GBTestDiagnostics.buffer("\n=== VIEWPORT CENTER TEST ===")
	var viewport_center_world: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(vp)
	var viewport_center_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(viewport_center_world, tile_map)
	GBTestDiagnostics.buffer("viewport center world: %s" % [str(viewport_center_world)])
	GBTestDiagnostics.buffer("viewport center tile: %s" % [str(viewport_center_tile)])
	
	# Test move_to_viewport_center_tile directly
	GBTestDiagnostics.buffer("\n=== DIRECT VIEWPORT CENTER MOVE ===")
	GBTestDiagnostics.buffer("Before move_to_viewport_center_tile: %s" % [str(positioner.global_position)])
	var result_tile: Vector2i = positioner.move_to_viewport_center_tile()
	GBTestDiagnostics.buffer("After move_to_viewport_center_tile: %s" % [str(positioner.global_position)])
	GBTestDiagnostics.buffer("Returned tile: %s" % [str(result_tile)])
	
	# Test cursor move with specific screen position
	GBTestDiagnostics.buffer("\n=== CURSOR MOVE TEST ===")
	var screen_pos: Vector2 = Vector2(224, 176)
	var cursor_world: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, vp)
	var cursor_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(cursor_world, tile_map)
	GBTestDiagnostics.buffer("Screen pos: %s" % [str(screen_pos)])
	GBTestDiagnostics.buffer("Cursor world: %s" % [str(cursor_world)])
	GBTestDiagnostics.buffer("Cursor tile: %s" % [str(cursor_tile)])
	
	# Simulate mouse input to cache position
	var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.position = screen_pos
	mouse_event.global_position = cursor_world
	positioner._input(mouse_event)
	
	GBTestDiagnostics.buffer("Before move_to_cursor_center_tile: %s" % [str(positioner.global_position)])
	var cursor_result_tile: Vector2i = positioner.move_to_cursor_center_tile()
	GBTestDiagnostics.buffer("After move_to_cursor_center_tile: %s" % [str(positioner.global_position)])
	GBTestDiagnostics.buffer("Returned cursor tile: %s" % [str(cursor_result_tile)])
	
	# Test recenter on enable
	GBTestDiagnostics.buffer("\n=== RECENTER ON ENABLE TEST ===")
	
	# Set up settings for mouse recenter
	var settings: GridTargetingSettings = container.config.settings.targeting
	settings.enable_mouse_input = true
	settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE
	
	GBTestDiagnostics.buffer("Settings - mouse enabled: %s" % [str(settings.enable_mouse_input)])
	GBTestDiagnostics.buffer("Settings - manual recenter mode: %s" % [str(settings.manual_recenter_mode)])
	GBTestDiagnostics.buffer("Settings - position on enable policy: %s" % [str(settings.position_on_enable_policy)])
	
	# Test _apply_recenter_on_enable
	GBTestDiagnostics.buffer("Before _apply_recenter_on_enable: %s" % [str(positioner.global_position)])
	positioner._apply_recenter_on_enable()
	GBTestDiagnostics.buffer("After _apply_recenter_on_enable: %s" % [str(positioner.global_position)])
	
	# Check for any issues that might cause fallback
	GBTestDiagnostics.buffer("\n=== DIAGNOSTIC CHECKS ===")
	var disabled_in_off_mode: bool = positioner._is_disabled_in_off_mode() if positioner.has_method("_is_disabled_in_off_mode") else false
	var mouse_on_screen: bool = positioner._is_mouse_cursor_on_screen() if positioner.has_method("_is_mouse_cursor_on_screen") else false
	GBTestDiagnostics.buffer("disabled_in_off_mode: %s" % [str(disabled_in_off_mode)])
	GBTestDiagnostics.buffer("mouse_on_screen: %s" % [str(mouse_on_screen)])

	# Attach diagnostics to a no-op assertion so failure messages include the collected data
	assert_bool(true).is_true().append_failure_message(GBTestDiagnostics.flush_for_assert())
