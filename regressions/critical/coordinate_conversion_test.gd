## Debug test for coordinate conversion discrepancy
extends GdUnitTestSuite

var tile_map: TileMapLayer
var camera: Camera2D
var viewport: Viewport

func before_test() -> void:
	tile_map = GodotTestFactory.create_tile_map_layer(self)
	viewport = get_viewport()

	# Create camera at origin like in the failing test
	camera = Camera2D.new()
	camera.position = tile_map.global_position  # This is (0, 0)
	tile_map.add_child(camera)
	camera.make_current()

	await get_tree().process_frame

func after_test() -> void:
	if camera:
		camera.queue_free()

func test_coordinate_conversion_comparison() -> void:
	# Test the specific screen position from the failing test
	var screen_pos := Vector2(224, 176)

	# Use a single-line formatted diagnostic attached to assertion failures
	var diag := "COORD_CONV: camera=%s zoom=%s viewport=%s screen=%s" % [str(camera.global_position), str(camera.zoom), str(viewport.get_visible_rect().size), str(screen_pos)]

	# Method 1: GBPositioning2DUtils (used by tests)
	var world_pos_gb: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, viewport)
	diag += " | gb=%s" % str(world_pos_gb)

	# Method 2: Direct canvas transform (what GBPositioning2DUtils actually does)
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var world_pos_canvas: Vector2 = canvas_transform.affine_inverse() * screen_pos
	diag += " | canvas=%s" % str(world_pos_canvas)

	# Method 3: Camera projection (what I expected)
	var camera_global_transform: Transform2D = camera.get_global_transform()
	var world_pos_camera: Vector2 = camera_global_transform * (screen_pos - viewport.get_visible_rect().size / 2.0)
	diag += " | camera=%s" % str(world_pos_camera)

	# Method 4: Simple offset from camera (basic calculation)
	var viewport_center: Vector2 = viewport.get_visible_rect().size / 2.0
	var screen_offset: Vector2 = screen_pos - viewport_center
	var world_pos_offset: Vector2 = camera.global_position + screen_offset
	diag += " | offset=%s" % str(world_pos_offset)

	diag += " | canvas_origin=%s x=%s y=%s" % [str(canvas_transform.origin), str(canvas_transform.x), str(canvas_transform.y)]

	# Convert to tile coordinates and check what we get
	var tile_gb: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(world_pos_gb, tile_map)
	var tile_expected: Vector2i = Vector2i(-26, -12)  # From test failure

	diag += " | tile_gb=%s expected=%s diff=%s" % [str(tile_gb), str(tile_expected), str(tile_gb - tile_expected)]

	# Check if there's a discrepancy
	if tile_gb != tile_expected:
		fail("Coordinate conversion mismatch - %s" % diag)
