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
	
	print("=== COORDINATE CONVERSION DEBUG ===")
	print("Camera position: ", camera.global_position)
	print("Camera zoom: ", camera.zoom)
	print("Viewport size: ", viewport.get_visible_rect().size)
	print("Screen position: ", screen_pos)
	
	# Method 1: GBPositioning2DUtils (used by tests)
	var world_pos_gb: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, viewport)
	print("GBPositioning2DUtils result: ", world_pos_gb)
	
	# Method 2: Direct canvas transform (what GBPositioning2DUtils actually does)
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var world_pos_canvas: Vector2 = canvas_transform.affine_inverse() * screen_pos
	print("Canvas transform result: ", world_pos_canvas)
	
	# Method 3: Camera projection (what I expected)
	var camera_global_transform: Transform2D = camera.get_global_transform()
	var world_pos_camera: Vector2 = camera_global_transform * (screen_pos - viewport.get_visible_rect().size / 2.0)
	print("Camera projection result: ", world_pos_camera)
	
	# Method 4: Simple offset from camera (basic calculation)
	var viewport_center: Vector2 = viewport.get_visible_rect().size / 2.0
	var screen_offset: Vector2 = screen_pos - viewport_center  
	var world_pos_offset: Vector2 = camera.global_position + screen_offset
	print("Simple offset result: ", world_pos_offset)
	
	print("\n=== CANVAS TRANSFORM DETAILS ===")
	print("Canvas transform origin: ", canvas_transform.origin)
	print("Canvas transform x axis: ", canvas_transform.x)
	print("Canvas transform y axis: ", canvas_transform.y)
	
	# Convert to tile coordinates and check what we get
	var tile_gb: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(world_pos_gb, tile_map)
	var tile_expected: Vector2i = Vector2i(-26, -12)  # From test failure
	
	print("\n=== TILE CONVERSION ===")
	print("GBPositioning2DUtils tile: ", tile_gb)
	print("Expected tile from test: ", tile_expected)
	print("Difference: ", tile_gb - tile_expected)
	
	# Check if there's a discrepancy
	if tile_gb != tile_expected:
		print("\n!!! COORDINATE CONVERSION MISMATCH !!!")
		print("This explains why recenter operations fail")
