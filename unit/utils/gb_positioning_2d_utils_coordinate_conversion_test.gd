extends GdUnitTestSuite

## Unit tests for GBPositioning2DUtils coordinate conversion functions
## Tests screen-to-world coordinate conversion accuracy with Camera2D

var test_viewport: SubViewport
var test_camera: Camera2D

func before_test() -> void:
	# Create test viewport and camera setup
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(800, 600)
	add_child(test_viewport)
	
	test_camera = Camera2D.new()
	test_viewport.add_child(test_camera)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Wait for camera setup to complete
	await get_tree().process_frame

func after_test() -> void:
	if test_viewport:
		test_viewport.queue_free()

## Test basic screen-to-world coordinate conversion with camera at origin
func test_screen_to_world_camera_at_origin() -> void:
	# Setup: Camera at origin with default zoom
	test_camera.global_position = Vector2.ZERO
	test_camera.zoom = Vector2.ONE
	await get_tree().process_frame
	
	# Act: Convert screen center to world position
	var screen_center: Vector2 = test_viewport.get_visible_rect().get_center()
	var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_center, test_viewport)
	
	# Assert: Screen center should map to camera position (origin)
	assert_vector(world_pos).is_equal_approx(Vector2.ZERO, Vector2.ONE * 2.0).append_failure_message(
		"Screen center should map to camera position. Expected: (0,0), Got: %s, Camera: %s" % [world_pos, test_camera.global_position]
	)

## Test coordinate conversion with camera offset
func test_screen_to_world_camera_offset() -> void:
	# Setup: Camera positioned away from origin
	var camera_pos: Vector2 = Vector2(100, 50)
	test_camera.global_position = camera_pos
	test_camera.zoom = Vector2.ONE
	await get_tree().process_frame
	
	# Act: Convert screen center to world position
	var screen_center: Vector2 = test_viewport.get_visible_rect().get_center()
	var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_center, test_viewport)
	
	# Assert: Screen center should map to camera position
	assert_vector(world_pos).is_equal_approx(camera_pos, Vector2.ONE * 2.0).append_failure_message(
		"Screen center should map to camera position. Expected: %s, Got: %s" % [camera_pos, world_pos]
	)

## Test coordinate conversion with camera zoom
func test_screen_to_world_camera_zoom() -> void:
	# Setup: Camera with 2x zoom
	test_camera.global_position = Vector2.ZERO
	test_camera.zoom = Vector2(2.0, 2.0)  # 2x zoom
	await get_tree().process_frame
	
	# Act: Convert screen point to world position
	var screen_offset: Vector2 = Vector2(100, 0)  # 100 pixels right of center
	var screen_center: Vector2 = test_viewport.get_visible_rect().get_center()
	var screen_pos: Vector2 = screen_center + screen_offset
	var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, test_viewport)
	
	# Assert: With 2x zoom, 100 screen pixels should be 50 world units
	var expected_world_pos: Vector2 = Vector2(50, 0)  # 100 / 2.0 zoom
	assert_vector(world_pos).is_equal_approx(expected_world_pos, Vector2.ONE * 5.0).append_failure_message(
		"With 2x zoom, 100 screen pixels should be 50 world units. Expected: %s, Got: %s, Zoom: %s" % [expected_world_pos, world_pos, test_camera.zoom]
	)

## Test fallback behavior when no camera is present
func test_screen_to_world_no_camera() -> void:
	# Setup: Viewport without camera
	var no_camera_viewport: SubViewport = SubViewport.new()
	no_camera_viewport.size = Vector2i(400, 300)
	add_child(no_camera_viewport)
	auto_free(no_camera_viewport)
	
	# Act: Attempt coordinate conversion without camera
	var screen_pos: Vector2 = Vector2(100, 50)
	var world_pos: Vector2 = GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, no_camera_viewport)
	
	# Assert: Should fall back to returning screen position
	assert_vector(world_pos).is_equal(screen_pos).append_failure_message(
		"Without camera, should return screen position as fallback. Expected: %s, Got: %s" % [screen_pos, world_pos]
	)