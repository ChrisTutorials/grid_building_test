## Debug test for viewport center calculation
extends GdUnitTestSuite

var grid_positioner: GridPositioner2D
var target_map: TileMapLayer
var viewport: Viewport
var camera: Camera2D

func before_test() -> void:
	# Create test components manually
	grid_positioner = GridPositioner2D.new()
	add_child(grid_positioner)
	auto_free(grid_positioner)
	target_map = GodotTestFactory.create_tile_map_layer(self)
	
	# Add camera to the viewport
	viewport = get_viewport()
	camera = Camera2D.new()
	add_child(camera)
	
	# Wait for scene setup
	await get_tree().process_frame

func after_test() -> void:
	if camera:
		camera.queue_free()

func test_debug_viewport_center_calculation() -> void:
	# Check viewport and camera setup
	assert_object(viewport).is_not_null().append_failure_message("Viewport should exist")
	assert_object(camera).is_not_null().append_failure_message("Camera should exist")
	
	# Check if camera is current
	var current_camera: Camera2D = viewport.get_camera_2d()
	var cam_pos_str := camera.global_position if camera != null else "null"
	var diag := "camera_current=%s our_camera=%s cam_pos=%s viewport_size=%s viewport_center=%s" % [str(current_camera), str(camera), str(cam_pos_str), str(viewport.get_visible_rect().size), str(viewport.get_visible_rect().get_center())]
	
	# Test viewport center to world conversion
	var viewport_center: Vector2 = viewport.get_visible_rect().get_center()
	var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(viewport_center, viewport)
	diag += " | viewport_center=%s world_pos=%s" % [str(viewport_center), str(world_pos)]
	
	# Test direct viewport center positioning utility
	var result_tile: Vector2i = GBPositioning2DUtils.move_node_to_tile_at_viewport_center(grid_positioner, target_map, viewport)
	diag += " | result_tile=%s grid_pos=%s" % [str(result_tile), str(grid_positioner.global_position)]
	
	# Test expected calculation manually
	var expected_world: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(viewport)
	var expected_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(expected_world, target_map)
	var expected_center: Vector2 = target_map.map_to_local(expected_tile)
	var expected_center_global: Vector2 = target_map.to_global(expected_center)
	diag += " | expected_world=%s expected_tile=%s expected_center=%s expected_center_global=%s" % [str(expected_world), str(expected_tile), str(expected_center), str(expected_center_global)]
	
	# Compare results
	var position_delta: Vector2 = grid_positioner.global_position - expected_center_global
	diag += " | delta=%s" % str(position_delta)

func test_debug_camera_setup() -> void:
	# Ensure camera is set as current
	camera.make_current()
	await get_tree().process_frame
	
	var current_camera: Camera2D = viewport.get_camera_2d()
	print("DEBUG: After make_current - Current camera = ", current_camera)
	if camera:
		print("DEBUG: After make_current - Camera enabled = ", camera.enabled)
	else:
		print("DEBUG: After make_current - Camera enabled = null")
	
	assert_object(current_camera).is_same(camera).append_failure_message(
		"Camera should be current. Expected: %s, Got: %s\n%s" % [str(camera), str(current_camera), diag]
	)
