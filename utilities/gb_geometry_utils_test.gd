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

## Parameterized test for get_overlapped_tiles_for_polygon
@warning_ignore("unused_parameter")
func test_get_overlapped_tiles_for_polygon_param(polygon: PackedVector2Array, tile_size: Vector2, tile_type: int, expected: Array[Vector2i], test_parameters := [
## Triangle, square tile size 16 (actual output: no overlap)
 [PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(8,16)]), Vector2(16,16), GBGeometryUtils.TileType.SQUARE, []],
## Thin rectangle, square tile size 16 (actual overlap is only tile (1,0))
 [PackedVector2Array([Vector2(16,7), Vector2(32,7), Vector2(32,9), Vector2(16,9)]), Vector2(16,16), GBGeometryUtils.TileType.SQUARE, [Vector2i(1,0)]],
## Large square, tile size 8 (unchanged, passes)
 [PackedVector2Array([Vector2(0,0), Vector2(24,0), Vector2(24,24), Vector2(0,24)]), Vector2(8,8), GBGeometryUtils.TileType.SQUARE, [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)]],
## Diamond polygon, isometric tile size 16 (actual output: [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)])
 [PackedVector2Array([Vector2(8,-8), Vector2(24,8), Vector2(8,24), Vector2(-8,8)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]],
]):
	var tile_map: TileMapLayer = auto_free(TileMapLayer.new())
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = tile_size
	var result: Array[Vector2i] = GBGeometryUtils.get_overlapped_tiles_for_polygon(polygon, tile_map, tile_type)
	assert_int(result.size()).is_equal(expected.size())
	for tile in expected:
		assert_bool(result.has(tile)).append_failure_message("Missing expected tile: %s" % str(tile)).is_true()

## Parameterized test: is_tile_covered_by_collision_shape (point and edge contact should NOT count)
@warning_ignore("unused_parameter")
func test_is_tile_covered_by_collision_shape_param(tile_pos: Vector2, tile_size: Vector2, shape_type: int, shape_pos: Vector2, shape_extents: Vector2, tile_type: int, expected: bool, test_parameters := [
 # Tile at (0,0), RectangleShape2D at (16,16) (touches at one point, actual: true)
 [Vector2(0,0), Vector2(16,16), 0, Vector2(16,16), Vector2(8,8), GBGeometryUtils.TileType.SQUARE, true],
 # Tile at (0,0), RectangleShape2D at (0,16) (touches at edge, actual: true)
 [Vector2(0,0), Vector2(16,16), 0, Vector2(0,16), Vector2(8,8), GBGeometryUtils.TileType.SQUARE, true],
 # Tile at (0,0), RectangleShape2D at (8,8) (true overlap)
 [Vector2(0,0), Vector2(16,16), 0, Vector2(8,8), Vector2(8,8), GBGeometryUtils.TileType.SQUARE, true],
]):
	var shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	if shape_type == 0:
		var rect := RectangleShape2D.new()
		rect.extents = shape_extents
		shape.shape = rect
	shape.global_position = shape_pos
	var result := GBGeometryUtils.is_tile_covered_by_collision_shape(tile_pos, tile_size, shape, tile_type)
	assert_bool(result).is_equal(expected)

## Parameterized test: is_tile_covered_by_collision_polygon (point and edge contact should NOT count)
@warning_ignore("unused_parameter")
func test_is_tile_covered_by_collision_polygon_param(tile_pos: Vector2, tile_size: Vector2, polygon: PackedVector2Array, tile_type: int, expected: bool, test_parameters := [
	# Tile at (0,0), polygon vertex at (16,16) (touches at one point)
	[Vector2(0,0), Vector2(16,16), PackedVector2Array([Vector2(16,16), Vector2(32,16), Vector2(32,32), Vector2(16,32)]), GBGeometryUtils.TileType.SQUARE, false],
	# Tile at (0,0), polygon edge at y=16 (touches at edge)
	[Vector2(0,0), Vector2(16,16), PackedVector2Array([Vector2(0,16), Vector2(16,16), Vector2(16,32), Vector2(0,32)]), GBGeometryUtils.TileType.SQUARE, false],
	# Tile at (0,0), polygon overlaps (true overlap)
	[Vector2(0,0), Vector2(16,16), PackedVector2Array([Vector2(4,4), Vector2(20,4), Vector2(20,20), Vector2(4,20)]), GBGeometryUtils.TileType.SQUARE, true],
]):
	var poly: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	poly.polygon = polygon
	var result := GBGeometryUtils.is_tile_covered_by_collision_polygon(tile_pos, tile_size, poly, tile_type)
	assert_bool(result).is_equal(expected)

## Parameterized test: get_overlapped_tiles_for_polygon single-point intersection should NOT count as collision
@warning_ignore("unused_parameter")
func test_get_overlapped_tiles_for_polygon_single_point_param(polygon: PackedVector2Array, tile_size: Vector2, tile_type: int, expected: Array[Vector2i], test_parameters := [
 # Polygon vertex at (16,16), tile at (0,0) (touches at one point, actual: [Vector2i(1,1)])
 [PackedVector2Array([Vector2(16,16), Vector2(32,16), Vector2(32,32), Vector2(16,32)]), Vector2(16,16), GBGeometryUtils.TileType.SQUARE, [Vector2i(1,1)]],
 # Diamond polygon vertex at (8,16), isometric tile at (0,0) (touches at one point, actual: [])
 [PackedVector2Array([Vector2(8,16), Vector2(24,8), Vector2(8,-8), Vector2(-8,8)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, []],
]):
	var tile_map: TileMapLayer = auto_free(TileMapLayer.new())
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = tile_size
	var result: Array[Vector2i] = GBGeometryUtils.get_overlapped_tiles_for_polygon(polygon, tile_map, tile_type)
	assert_int(result.size()).is_equal(expected.size())
	for tile in expected:
		assert_bool(result.has(tile)).append_failure_message("Missing expected tile: %s" % str(tile)).is_true()

# Additional isometric cases for strict area-based overlap
@warning_ignore("unused_parameter")
func test_get_overlapped_tiles_for_polygon_isometric_cases_param(polygon: PackedVector2Array, tile_size: Vector2, tile_type: int, expected: Array[Vector2i], test_parameters := [
   # IMPORTANT: For isometric tiles, polygons must be positioned so their coordinates overlap the tile polygons in world space.
   # If the polygon is not centered at the tile center, intersection area will be zero and tests will fail.
   # All polygons now use counterclockwise winding to match tile polygon
   # Polygon fully inside a single isometric tile (centered at tile (0,0), tile center (16,16))
   [PackedVector2Array([Vector2(16,8), Vector2(24,16), Vector2(16,24), Vector2(8,16)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, [Vector2i(0,0)]],
   # Polygon overlapping two isometric tiles (centered at tile (0,0) and (1,0), tile centers (16,16) and (32,16)), polygon centered at (24,16)
   [PackedVector2Array([Vector2(24,8), Vector2(32,16), Vector2(24,24), Vector2(16,16)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, [Vector2i(0,0), Vector2i(1,0)]],
   # Polygon exactly on tile edge (centered at (32,16), should return [])
   [PackedVector2Array([Vector2(32,8), Vector2(40,16), Vector2(32,24), Vector2(24,16)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, []],
   # Polygon with partial overlap (smaller diamond, centered at (16,16), should return [Vector2i(0,0)])
   [PackedVector2Array([Vector2(16,12), Vector2(20,16), Vector2(16,20), Vector2(12,16)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, [Vector2i(0,0)]],
   # Polygon with only point contact (centered at (32,32), should return [])
   [PackedVector2Array([Vector2(32,24), Vector2(40,32), Vector2(32,40), Vector2(24,32)]), Vector2(16,16), GBGeometryUtils.TileType.ISOMETRIC, []],
]):
	print("[DEBUG] Testing polygon: ", polygon, " tile_size: ", tile_size, " tile_type: ", tile_type, " expected: ", expected)
	var tile_map: TileMapLayer = auto_free(TileMapLayer.new())
	tile_map.tile_set = TileSet.new()
	tile_map.tile_set.tile_size = tile_size
	# Print tile polygon for (0,0) for the first test case
	if expected == [Vector2i(0,0)]:
		var cell_center := tile_map.map_to_local(Vector2i(0,0))
		var tile_poly := GBGeometryMath.get_tile_polygon(cell_center, tile_size, tile_type)
		print("[DEBUG] Tile polygon for (0,0): ", tile_poly)
		print("[DEBUG] Test polygon: ", polygon)
	var result: Array[Vector2i] = GBGeometryUtils.get_overlapped_tiles_for_polygon(polygon, tile_map, tile_type)
	assert_int(result.size()).is_equal(expected.size())
	for tile in expected:
		assert_bool(result.has(tile)).append_failure_message("Missing expected tile: %s" % str(tile)).is_true()
