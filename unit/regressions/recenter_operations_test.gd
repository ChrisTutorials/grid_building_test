## Debug test for recenter operation failures
extends GdUnitTestSuite

var container: GBCompositionContainer
var positioner: GridPositioner2D
var tile_map: TileMapLayer

func before_test() -> void:
	container = UnifiedTestFactory.create_test_composition_container(self)
	positioner = UnifiedTestFactory.create_grid_positioner(self)
	tile_map = UnifiedTestFactory.create_tile_map_layer(self)
	
	# Set up dependencies
	positioner.resolve_gb_dependencies(container)
	
	# Set up camera like in the failing tests
	var camera: Camera2D = Camera2D.new()
	camera.position = tile_map.global_position  # (0, 0)
	tile_map.add_child(camera)
	camera.make_current()
	
	await get_tree().process_frame

func test_debug_recenter_operations() -> void:
	print("=== RECENTER DEBUG TEST ===")
	
	# Check initial state
	print("Initial positioner position: ", positioner.global_position)
	print("Initial tile: ", GBPositioning2DUtils.get_tile_from_global_position(positioner.global_position, tile_map))
	
	# Check dependencies
	print("\n=== DEPENDENCY CHECK ===")
	print("is_input_ready(): ", positioner.is_input_ready())
	print("targeting_state: ", positioner._targeting_state)
	if positioner._targeting_state:
		print("target_map: ", positioner._targeting_state.target_map)
	else:
		print("target_map: null")
	print("targeting_settings: ", positioner._targeting_settings)
	print("input_processing_enabled: ", positioner.input_processing_enabled)
	
	# Check viewport and camera
	print("\n=== VIEWPORT/CAMERA CHECK ===")
	var vp: Viewport = tile_map.get_viewport()
	var cam: Camera2D = vp.get_camera_2d()
	print("viewport: ", vp)
	print("camera: ", cam)
	if cam:
		print("camera position: ", cam.global_position)
	else:
		print("camera position: null")
	print("viewport size: ", vp.get_visible_rect().size)
	
	# Test viewport center calculation
	print("\n=== VIEWPORT CENTER TEST ===")
	var viewport_center_world: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(vp)
	var viewport_center_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(viewport_center_world, tile_map)
	print("viewport center world: ", viewport_center_world)
	print("viewport center tile: ", viewport_center_tile)
	
	# Test move_to_viewport_center_tile directly
	print("\n=== DIRECT VIEWPORT CENTER MOVE ===")
	print("Before move_to_viewport_center_tile: ", positioner.global_position)
	var result_tile: Vector2i = positioner.move_to_viewport_center_tile()
	print("After move_to_viewport_center_tile: ", positioner.global_position)
	print("Returned tile: ", result_tile)
	
	# Test cursor move with specific screen position
	print("\n=== CURSOR MOVE TEST ===")
	var screen_pos: Vector2 = Vector2(224, 176)
	var cursor_world: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, vp)
	var cursor_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(cursor_world, tile_map)
	print("Screen pos: ", screen_pos)
	print("Cursor world: ", cursor_world)  
	print("Cursor tile: ", cursor_tile)
	
	# Simulate mouse input to cache position
	var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.position = screen_pos
	mouse_event.global_position = cursor_world
	positioner._input(mouse_event)
	
	print("Before move_to_cursor_center_tile: ", positioner.global_position)
	var cursor_result_tile: Vector2i = positioner.move_to_cursor_center_tile()
	print("After move_to_cursor_center_tile: ", positioner.global_position)
	print("Returned cursor tile: ", cursor_result_tile)
	
	# Test recenter on enable
	print("\n=== RECENTER ON ENABLE TEST ===")
	
	# Set up settings for mouse recenter
	var settings: GridTargetingSettings = container.config.settings.targeting
	settings.enable_mouse_input = true
	settings.manual_recenter_mode = GBEnums.CenteringMode.CENTER_ON_MOUSE
	
	print("Settings - mouse enabled: ", settings.enable_mouse_input)
	print("Settings - manual recenter mode: ", settings.manual_recenter_mode)
	print("Settings - position on enable policy: ", settings.position_on_enable_policy)
	
	# Test _apply_recenter_on_enable
	print("Before _apply_recenter_on_enable: ", positioner.global_position)
	positioner._apply_recenter_on_enable()
	print("After _apply_recenter_on_enable: ", positioner.global_position)
	
	# Check for any issues that might cause fallback
	print("\n=== DIAGNOSTIC CHECKS ===")
	var disabled_in_off_mode: bool = positioner._is_disabled_in_off_mode() if positioner.has_method("_is_disabled_in_off_mode") else false
	var mouse_on_screen: bool = positioner._is_mouse_cursor_on_screen() if positioner.has_method("_is_mouse_cursor_on_screen") else false
	print("disabled_in_off_mode: ", disabled_in_off_mode)
	print("mouse_on_screen: ", mouse_on_screen)
