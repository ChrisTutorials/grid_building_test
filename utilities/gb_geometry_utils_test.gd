## GdUnit TestSuite for GBGeometryUtils.get_all_collision_objects
extends GdUnitTestSuite

func test_get_all_collision_shapes_by_owner_for_scene():
	var scene_uids := [
		"uid://bqq7otaevtlqu", # offset_logo.tscn
		"uid://blgwelirrimr1", # test_rect_15_tiles.tscn
		"uid://j5837ml5dduu",  # test_elipse.tscn
		"uid://b82nv1wlsv8wa", # test_skew_rotation_rect.tscn
		"uid://c673aj2ivgljp", # smithy.tscn
		"uid://cdb08p0iy3vjy", # test_pillar.tscn
		"uid://be5sd0kpcvj0h", # isometric_building.tscn
	]
	for scene_uid in scene_uids:
		print("[DEBUG] Attempting to load UID: ", scene_uid)
		var scene_resource = load(scene_uid)
		assert_object(scene_resource).append_failure_message("Scene failed to load: " + scene_uid).is_not_null()
		var scene_instance = auto_free(scene_resource.instantiate())
		add_child(scene_instance)
		var owner_shapes: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(scene_instance)
		assert_int(owner_shapes.size()).append_failure_message("UID: %s Should find at least one collision owner (CollisionObject2D or CollisionPolygon2D)" % scene_uid).is_greater(0)
		for collision_owner in owner_shapes.keys():
			var shapes = owner_shapes[collision_owner]
			assert_int(shapes.size()).append_failure_message("Owner should have at least one Shape2D").is_greater(0)

func test_get_overlapped_tiles_for_rect_exact_fit() -> void:
	# Setup: 16x16 rectangle centered at (8,8) on a tilemap with 16x16 tiles
	var tile_map : TileMapLayer = auto_free(TileMapLayer.new())
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = Vector2(16, 16)

	var rect_center := Vector2(8, 8)
	var rect_size := Vector2(16, 16)
	var overlapped_tiles := GBGeometryUtils.get_overlapped_tiles_for_rect(rect_center, rect_size, tile_map, 0.1)

	# Expect only one tile to be overlapped
	assert_int(overlapped_tiles.size()).append_failure_message("Should only overlap one tile for exact fit").is_equal(1)
	assert_that(overlapped_tiles[0]).is_equal(Vector2i(0, 0))

func test_get_overlapped_tiles_for_rect_smaller_fit() -> void:
	# Setup: 15x15 rectangle centered at (8,8) on a tilemap with 16x16 tiles
	var tile_map : TileMapLayer= auto_free(TileMapLayer.new())
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = Vector2(16, 16)

	var rect_center := Vector2(8, 8) # Offset to center of a tile
	var rect_size := Vector2(15, 15)
	var overlapped_tiles := GBGeometryUtils.get_overlapped_tiles_for_rect(rect_center, rect_size, tile_map, 0.1)

	# Expect only one tile to be overlapped
	assert_int(overlapped_tiles.size()).append_failure_message("Should only overlap one tile for smaller fit").is_equal(1)
	assert_that(overlapped_tiles[0]).is_equal(Vector2i(0, 0))

## Test for extract_shapes_from_node

# Parameterized test for extract_shapes_from_node

@warning_ignore("unused_parameter")
func test_get_shapes_from_owner_parameterized(p_node : Node2D, expected_shape_type: Variant, expected_count: int, test_parameters := [
	[GBDoubleFactory.create_test_static_body_with_rect_shape(self), RectangleShape2D, 1], # CollisionObject2D
	[GBDoubleFactory.create_test_collision_polygon(self), ConvexPolygonShape2D, 1], # CollisionPolygon2D
	[GBDoubleFactory.create_test_parent_with_body_and_polygon(self), null, 0], # Parent node (Node2D)
]):
	var shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(p_node)
	assert_int(shapes.size()).is_equal(expected_count)
	if expected_shape_type != null and shapes.size() > 0:
		assert_object(shapes[0]).is_instanceof(expected_shape_type)

## Parameterized test for points_array_to_rect_2d
func test_points_array_to_rect_2d_param(points: PackedVector2Array, rect_pos: Vector2, expected: Rect2, test_parameters := [
	[PackedVector2Array([Vector2(0,0), Vector2(10,10), Vector2(-5,5)]), Vector2(0,0), Rect2(Vector2(0,0), Vector2(15,10))],
	[PackedVector2Array([Vector2(2,3), Vector2(2,3)]), Vector2(2,3), Rect2(Vector2(2,3), Vector2(0,0))],
]):
	var result: Rect2 = GBGeometryUtils.points_array_to_rect_2d(points, rect_pos)
	assert_that(result.position).is_equal(expected.position)
	assert_that(result.size).is_equal(expected.size)

## Parameterized test for grow_rect2_to_increment
func test_grow_rect2_to_increment_param(rect: Rect2, increment: Vector2, expected: Rect2, test_parameters := [
	[Rect2(Vector2(0,0), Vector2(10,10)), Vector2(2,2), Rect2(Vector2(0,0), Vector2(12,12))],
	[Rect2(Vector2(5,5), Vector2(5,5)), Vector2(1,1), Rect2(Vector2(5,5), Vector2(6,6))],
]):
	var result: Rect2 = GBGeometryUtils.grow_rect2_to_increment(rect, increment)
	assert_that(result.size).is_equal(expected.size)

## Parameterized test for grow_rect2_to_square
func test_grow_rect2_to_square_param(rect: Rect2, expected: Rect2, test_parameters := [
	[Rect2(Vector2(0,0), Vector2(10,5)), Rect2(Vector2(0,0), Vector2(10,10))],
	[Rect2(Vector2(2,2), Vector2(3,7)), Rect2(Vector2(2,2), Vector2(7,7))],
]):
	var result: Rect2 = GBGeometryUtils.grow_rect2_to_square(rect)
	assert_that(result.size).is_equal(expected.size)

## Parameterized test for get_rect2_position_offset
func test_get_rect2_position_offset_param(rect: Rect2, expected: Vector2, test_parameters := [
	[Rect2(Vector2(0,0), Vector2(10,10)), Vector2(-10,-10)],
	[Rect2(Vector2(5,5), Vector2(5,5)), Vector2(-5,-5)],
]):
	var result: Vector2 = GBGeometryUtils.get_rect2_position_offset(rect)
	assert_that(result).is_equal(expected)

## Test for get_collision_object_shapes with multiple shapes
func test_get_collision_object_shapes_multiple():
	var body: StaticBody2D = auto_free(StaticBody2D.new())
	add_child(body)
	var shape1: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect1: RectangleShape2D = RectangleShape2D.new()
	rect1.extents = Vector2(4,4)
	shape1.shape = rect1
	body.add_child(shape1)
	var shape2: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect2: RectangleShape2D = RectangleShape2D.new()
	rect2.extents = Vector2(8,8)
	shape2.shape = rect2
	body.add_child(shape2)
	var shapes: Array[Shape2D] = GBGeometryUtils.get_collision_object_shapes(body)
	assert_int(shapes.size()).is_equal(2)
	assert_object(shapes[0]).is_instanceof(RectangleShape2D)
	assert_object(shapes[1]).is_instanceof(RectangleShape2D)

## Parameterized test for extract_shapes_from_node edge cases
@warning_ignore("unused_parameter")
func test_get_shapes_from_owner_edge_param(node: Node2D, expected_count: int, test_parameters := [
	[GBDoubleFactory.create_test_node2d(self), 0],
	[GBDoubleFactory.create_test_static_body_with_rect_shape(self), 1],
	[GBDoubleFactory.create_test_collision_polygon(self), 1],
]):
	var shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(node)
	assert_int(shapes.size()).is_equal(expected_count)
	node.free()

## Test for get_all_collision_shapes_by_owner with nested children
func test_get_all_collision_shapes_by_owner_nested():
	var parent: Node2D = auto_free(Node2D.new())
	add_child(parent)
	var child1: StaticBody2D = auto_free(StaticBody2D.new())
	var shape1: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect1: RectangleShape2D = RectangleShape2D.new()
	rect1.extents = Vector2(8,8)
	shape1.shape = rect1
	child1.add_child(shape1)
	parent.add_child(child1)
	var child2: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	child2.polygon = PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(8,16)])
	parent.add_child(child2)
	var result: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(parent)
	assert_int(result.size()).is_equal(2)
	for collision_owner in result.keys():
		assert_int(result[collision_owner].size()).is_greater(0)
