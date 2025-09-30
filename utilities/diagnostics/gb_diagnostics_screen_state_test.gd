## Unit tests for GBDiagnostics screen/camera helpers and formatted output.
extends GdUnitTestSuite

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
	assert_str(msg).contains("<no camera>")
	assert_str(msg).contains(str(pos))

func test_camera_world_bounds_and_inside_flag() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(800, 600)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.global_position = Vector2(256, 256)
	var bounds := GBDiagnostics.camera_world_bounds(cam, vp)
	assert_bool(bounds.get("has", false)).is_true()
	var center: Vector2 = bounds.get("center", Vector2.ZERO)
	assert_bool(center.distance_to(Vector2(256, 256)) < 0.001).is_true()
	var world_min: Vector2 = bounds.get("world_min", Vector2.ZERO)
	var world_max: Vector2 = bounds.get("world_max", Vector2.ZERO)
	var expected_min := Vector2(256, 256) - Vector2(400, 300)
	var expected_max := Vector2(256, 256) + Vector2(400, 300)
	assert_bool(world_min.distance_to(expected_min) < 0.001).is_true()
	assert_bool(world_max.distance_to(expected_max) < 0.001).is_true()

	# Position inside bounds
	var inside_pos := Vector2(300, 300)
	assert_bool(GBDiagnostics.is_inside_camera_bounds(bounds, inside_pos)).is_true()
	# Position outside bounds
	var outside_pos := Vector2(2000, 2000)
	assert_bool(GBDiagnostics.is_offscreen(bounds, outside_pos)).is_true()
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
	assert_str(msg).contains("cam_center=")
	assert_str(msg).contains("world_min=")
	assert_str(msg).contains("world_max=")
	assert_str(msg).contains("pos=")
	assert_str(msg).contains("inside=")
	assert_str(msg).contains("pos_tile=")
	assert_str(msg).contains("mouse_world=")
	assert_str(msg).contains("mouse_tile=")
	assert_str(msg).contains("delta_tiles=")
	assert_str(msg).contains("has_mouse=true")
	# Check specific tile computations
	assert_str(msg).contains("pos_tile=(3, 4)")
	assert_str(msg).contains("mouse_tile=(5, 5)")
	assert_str(msg).contains("delta_tiles=(2, 1)")
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
	assert_str(msg).contains("has_mouse=false")
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
	assert_str(s).contains("Probe(Sprite2D)")
	assert_str(s).contains("vis=true")
	assert_str(s).contains("a=0.75")
	assert_str(s).contains("z=7")
	# Vector formatting may include decimals, so only check key fragments
	assert_str(s).contains("pos=(10")
	assert_str(s).contains(", 20")
	assert_str(s).contains("scale=(2")
	sprite.free()

func test_visibility_context_with_hidden_ancestor_and_zoom_bounds() -> void:
	# Hidden ancestor
	var parent := Node2D.new()
	parent.name = "HiddenParent"
	parent.visible = false
	var child := Sprite2D.new()
	parent.add_child(child)
	var ctx := GBDiagnostics.format_visibility_context(child, child, null, null)
	assert_str(ctx).contains("anc_hidden=HiddenParent(Node2D)")
	# Zoom bounds formatting via screen state
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(400, 300)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.global_position = Vector2(100, 50)
	var msg := GBDiagnostics.format_screen_state(cam, vp, Vector2(100, 50), false, Vector2.ZERO, null)
	assert_str(msg).contains("cam_center=(100")
	assert_str(msg).contains("zoom=(2")
	# With zoom=(2,2), half=(200,150)*2=(400,300): world_min=(100,50)-(400,300)=(-300,-250)
	assert_str(msg).contains("world_min=(-300")
	# world_max=(100,50)+(400,300)=(500,350)
	assert_str(msg).contains("world_max=(500")
	# Cleanup
	child.free()
	parent.free()
	cam.free()
	vp.free()
