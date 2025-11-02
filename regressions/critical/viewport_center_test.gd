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


func after_test() -> void:
	if camera:
		camera.queue_free()
	GBTestDiagnostics.clear()


func test_debug_viewport_center_calculation() -> void:
	# Check viewport and camera setup
	assert_object(viewport).append_failure_message("Viewport should exist").is_not_null()
	assert_object(camera).append_failure_message("Camera should exist").is_not_null()

	# Collect diagnostics for potential failures (use per-test local diag)
	var cam_pos_str: String = str(camera.global_position) if camera != null else "null"
	var diag: PackedStringArray = PackedStringArray()
	diag.append(
		(
			"viewport_size=%s viewport_center=%s"
			% [str(viewport.get_visible_rect().size), str(viewport.get_visible_rect().get_center())]
		)
	)
	diag.append("camera_position=%s" % str(cam_pos_str))

	# Test viewport center to world conversion
	var viewport_center: Vector2 = viewport.get_visible_rect().get_center()
	var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(
		viewport_center, viewport
	)
	diag.append("viewport_center=%s world_pos=%s" % [str(viewport_center), str(world_pos)])

	# Test direct viewport center positioning utility
	var result_tile: Vector2i = GBPositioning2DUtils.move_node_to_tile_at_viewport_center(
		grid_positioner, target_map, viewport
	)
	diag.append(
		(
			"result_tile=%s positioner_pos=%s"
			% [str(result_tile), str(grid_positioner.global_position)]
		)
	)

	# Test expected calculation manually
	var expected_world: Vector2 = GBPositioning2DUtils.viewport_center_to_world_position(viewport)
	var expected_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(
		expected_world, target_map
	)
	var expected_center: Vector2 = target_map.map_to_local(expected_tile)
	var expected_center_global: Vector2 = target_map.to_global(expected_center)
	diag.append(
		(
			"expected_world=%s expected_tile=%s expected_center_global=%s"
			% [str(expected_world), str(expected_tile), str(expected_center_global)]
		)
	)

	# Test camera setup
	camera.make_current()

	var current_camera: Camera2D = viewport.get_camera_2d()
	var diag_context := "\n".join(diag)
	(
		assert_object(current_camera) \
		. append_failure_message(
			(
				"Camera should be current. Expected: %s, Got: %s%s%s"
				% [
					str(camera),
					str(current_camera),
					"\n" if diag_context != "" else "",
					diag_context
				]
			)
		) \
		. is_same(camera)
	)
