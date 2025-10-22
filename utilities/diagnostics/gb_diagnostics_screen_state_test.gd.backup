## Unit tests for GBDiagnostics screen/camera helpers and formatted output.
extends GdUnitTestSuite

# Module-level constants extracted from tests
const NO_CAMERA_MARKER: String = "<no camera>"
const KEY_CAM_CENTER: String = "cam_center="
const KEY_WORLD_MIN: String = "world_min="
const KEY_WORLD_MAX: String = "world_max="
const KEY_POS: String = "pos="
const KEY_INSIDE: String = "inside="
const KEY_POS_TILE: String = "pos_tile="
const KEY_MOUSE_WORLD: String = "mouse_world="
const KEY_MOUSE_TILE: String = "mouse_tile="
const KEY_DELTA_TILES: String = "delta_tiles="
const KEY_HAS_MOUSE_TRUE: String = "has_mouse=true"
const EXPECT_POS_TILE: String = "pos_tile=(3, 4)"
const EXPECT_MOUSE_TILE: String = "mouse_tile=(5, 5)"
const EXPECT_DELTA_TILES: String = "delta_tiles=(2, 1)"

## Simple fake map implementing the minimal API used by GBPositioning2DUtils
class FakeMap:
	extends Node2D
	var tile_size: int = 16
	func local_to_map(p: Vector2) -> Vector2i:
		return Vector2i(floor(p.x / tile_size), floor(p.y / tile_size))
	func map_to_local(t: Vector2i) -> Vector2:
		return Vector2(t.x * tile_size, t.y * tile_size)

func test_format_screen_state_no_camera() -> void:
	var pos := Vector2(100, 200)
	var msg := GBDiagnostics.format_screen_state(null, null, pos, false, Vector2.ZERO, null)
	assert_str(msg).append_failure_message("format_screen_state with null camera should include '<no camera>' marker. Got: %s" % msg).contains(NO_CAMERA_MARKER)
	assert_str(msg).append_failure_message("format_screen_state should include position %s. Got: %s" % [str(pos), msg]).contains(str(pos))

func test_camera_world_bounds_and_inside_flag() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(800, 600)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.global_position = Vector2(256, 256)
	var bounds := GBDiagnostics.camera_world_bounds(cam, vp)
	assert_bool(bounds.get("has", false)).append_failure_message("camera_world_bounds should return dict with 'has' key. Got: %s" % bounds).is_true()
	var center: Vector2 = bounds.get("center", Vector2.ZERO)
	assert_bool(center.distance_to(Vector2(256, 256)) < 0.001).append_failure_message("Camera center should be at (256, 256), got %s" % center).is_true()
	var world_min: Vector2 = bounds.get("world_min", Vector2.ZERO)
	var world_max: Vector2 = bounds.get("world_max", Vector2.ZERO)
	var expected_min := Vector2(256, 256) - Vector2(400, 300)
	var expected_max := Vector2(256, 256) + Vector2(400, 300)
	assert_bool(world_min.distance_to(expected_min) < 0.001).append_failure_message("World min should be %s, got %s" % [expected_min, world_min]).is_true()
	assert_bool(world_max.distance_to(expected_max) < 0.001).append_failure_message("World max should be %s, got %s" % [expected_max, world_max]).is_true()

	# Position inside bounds
	var inside_pos := Vector2(300, 300)
	assert_bool(GBDiagnostics.is_inside_camera_bounds(bounds, inside_pos)).append_failure_message("Position %s should be inside camera bounds" % inside_pos).is_true()
	# Position outside bounds
	var outside_pos := Vector2(2000, 2000)
	assert_bool(GBDiagnostics.is_offscreen(bounds, outside_pos)).append_failure_message("Position %s should be offscreen" % outside_pos).is_true()
	cam.free()
	vp.free()

func test_format_screen_state_with_map_and_mouse() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(320, 240)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.global_position = Vector2(160, 120)
	var map := FakeMap.new()
	map.position = Vector2.ZERO
	# Positioner at (48, 64) -> tiles (3,4) with 16px tiles
	var pos := Vector2(48, 64)
	var mouse := Vector2(80, 80) # -> tiles (5,5)
	var msg := GBDiagnostics.format_screen_state(cam, vp, pos, true, mouse, map)
	# Expect core fields present
	assert_str(msg).append_failure_message("Screen state should include camera center field").contains(KEY_CAM_CENTER)
	assert_str(msg).append_failure_message("Screen state should include world min field").contains(KEY_WORLD_MIN)
	assert_str(msg).append_failure_message("Screen state should include world max field").contains(KEY_WORLD_MAX)
	assert_str(msg).append_failure_message("Screen state should include position field").contains(KEY_POS)
	assert_str(msg).append_failure_message("Screen state should include inside field").contains(KEY_INSIDE)
	assert_str(msg).append_failure_message("Screen state should include position tile field").contains(KEY_POS_TILE)
	assert_str(msg).append_failure_message("Screen state should include mouse world field").contains(KEY_MOUSE_WORLD)
	assert_str(msg).append_failure_message("Screen state should include mouse tile field").contains(KEY_MOUSE_TILE)
	assert_str(msg).append_failure_message("Screen state should include delta tiles field").contains(KEY_DELTA_TILES)
	assert_str(msg).append_failure_message("Screen state should show has_mouse=true").contains(KEY_HAS_MOUSE_TRUE)
	# Check specific tile computations
	assert_str(msg).append_failure_message("Screen state should show correct position tile (3, 4)").contains(EXPECT_POS_TILE)
	assert_str(msg).append_failure_message("Screen state should show correct mouse tile (5, 5)").contains(EXPECT_MOUSE_TILE)
	assert_str(msg).append_failure_message("Screen state should show correct delta tiles (2, 1)").contains(EXPECT_DELTA_TILES)
	cam.free()
	vp.free()
	map.free()

func test_format_screen_state_without_mouse_cache() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(200, 200)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.global_position = Vector2(100, 100)
	var map := FakeMap.new()
	var msg := GBDiagnostics.format_screen_state(cam, vp, Vector2(0, 0), false, Vector2.ZERO, map)
	assert_str(msg).append_failure_message("Screen state should show has_mouse=false when no mouse").contains("has_mouse=false")
	cam.free()
	vp.free()
	map.free()

func test_format_canvas_item_state_basic() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Probe"
	sprite.visible = true
	sprite.self_modulate.a = 0.75
	sprite.z_index = 7
	sprite.global_position = Vector2(10, 20)
	sprite.scale = Vector2(2, 2)
	var s := GBDiagnostics.format_canvas_item_state(sprite)
	assert_str(s).append_failure_message("Canvas item state should include sprite name 'Probe'. Got: %s" % s).contains("Probe(Sprite2D)")
	assert_str(s).append_failure_message("Canvas item state should show visibility. Got: %s" % s).contains("vis=true")
	assert_str(s).append_failure_message("Canvas item state should show alpha 0.75. Got: %s" % s).contains("a=0.75")
	assert_str(s).append_failure_message("Canvas item state should show z_index 7. Got: %s" % s).contains("z=7")
	# Vector formatting may include decimals, so only check key fragments
	assert_str(s).append_failure_message("Canvas item state should include position. Got: %s" % s).contains("pos=(10")
	assert_str(s).append_failure_message("Canvas item state should include position y coord. Got: %s" % s).contains(", 20")
	assert_str(s).append_failure_message("Canvas item state should include scale. Got: %s" % s).contains("scale=(2")
	sprite.free()

func test_visibility_context_with_hidden_ancestor_and_zoom_bounds() -> void:
	# Hidden ancestor
	var parent := Node2D.new()
	parent.name = "HiddenParent"
	parent.visible = false
	var child := Sprite2D.new()
	parent.add_child(child)
	var visibility_info := GBDiagnostics.format_visibility_context(child, child, null, null)
	assert_str(visibility_info).append_failure_message("Visibility context should show hidden ancestor. Got: %s" % visibility_info).contains("anc_hidden=HiddenParent(Node2D)")
	# Zoom bounds formatting via screen state
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(400, 300)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.global_position = Vector2(100, 50)
	var msg := GBDiagnostics.format_screen_state(cam, vp, Vector2(100, 50), false, Vector2.ZERO, null)
	assert_str(msg).append_failure_message("Screen state should show camera center at (100, 50). Got: %s" % msg).contains("cam_center=(100")
	assert_str(msg).append_failure_message("Screen state should show zoom (2, 2). Got: %s" % msg).contains("zoom=(2")
	# With zoom=(2,2), half=(200,150)*2=(400,300): world_min=(100,50)-(400,300)=(-300,-250)
	assert_str(msg).append_failure_message("Screen state should show world_min with -300 x coord. Got: %s" % msg).contains("world_min=(-300")
	# world_max=(100,50)+(400,300)=(500,350)
	assert_str(msg).append_failure_message("Screen state should show world_max=(500, 350). Got: %s" % msg).contains("world_max=(500")
	# Cleanup
	child.free()
	parent.free()
	cam.free()
	vp.free()
