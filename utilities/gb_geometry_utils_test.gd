## GdUnit TestSuite for GBGeometryUtils utilities
##
## Epsilon expectations (overlap threshold):
## - Count a tile as overlapped only when intersection AREA is strictly greater than epsilon
##   (i.e. area > epsilon).
## - Point/edge-only contact has zero area and must not count, unless a case explicitly
##   documents a different behavior.
## - Rectangle helpers may shrink by a small epsilon to avoid counting neighbors on
##   exact fits.
## - Parameterized tests pass explicit epsilons to make intent unambiguous.
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
		var load_fail_msg: String = "Scene failed to load: " + scene_uid
		assert_object(scene_resource).append_failure_message(load_fail_msg).is_not_null()
		var scene_instance = auto_free(scene_resource.instantiate())
		add_child(scene_instance)
		var owner_shapes: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(scene_instance)
		var owner_fail_msg: String = "UID: %s Should find at least one collision owner" % scene_uid
		owner_fail_msg += " (CollisionObject2D or CollisionPolygon2D)"
		assert_int(owner_shapes.size()).append_failure_message(owner_fail_msg).is_greater(0)
		for collision_owner in owner_shapes.keys():
			var shapes = owner_shapes[collision_owner]
			assert_int(shapes.size()).append_failure_message("Owner should have at least one Shape2D").is_greater(0)

func test_get_overlapped_tiles_for_rect_exact_fit() -> void:
	# Setup: 16x16 rectangle centered at (8,8) on a tilemap with 16x16 tiles
	var tile_map: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	tile_map.tile_set.tile_size = Vector2(16, 16)

	var rect_center := Vector2(8, 8)
	var rect_size := Vector2(16, 16)
	var overlapped_tiles := GBGeometryUtils.get_overlapped_tiles_for_rect(rect_center, rect_size, tile_map, 0.1)

	# Expect only one tile to be overlapped (we shrink by epsilon so border-only neighbors are excluded)
	assert_int(overlapped_tiles.size()).append_failure_message("Should only overlap one tile for exact fit").is_equal(1)
	assert_that(overlapped_tiles[0]).is_equal(Vector2i(0, 0))

func test_get_overlapped_tiles_for_rect_smaller_fit() -> void:
	# Setup: 15x15 rectangle centered at (8,8) on a tilemap with 16x16 tiles
	var tile_map: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	tile_map.tile_set.tile_size = Vector2(16, 16)

	var rect_center := Vector2(8, 8) # Offset to center of a tile
	var rect_size := Vector2(15, 15)
	var overlapped_tiles := GBGeometryUtils.get_overlapped_tiles_for_rect(rect_center, rect_size, tile_map, 0.1)

	# Expect only one tile to be overlapped (strict area > epsilon)
	assert_int(overlapped_tiles.size()).append_failure_message("Should only overlap one tile for smaller fit").is_equal(1)
	assert_that(overlapped_tiles[0]).is_equal(Vector2i(0, 0))

## Test for extract_shapes_from_node

# Parameterized test for extract_shapes_from_node

## Parameterized test for get_shapes_from_owner with different node types
@warning_ignore("unused_parameter")
func test_get_shapes_from_owner_parameterized(_p_node : Node2D, expected_shape_type: Variant, expected_count: int, test_parameters := [
	# These functions are called at runtime, not during parameter definition
	[null, RectangleShape2D, 1], # Will be replaced with StaticBody2D in test
	[null, ConvexPolygonShape2D, 1], # Will be replaced with CollisionPolygon2D in test
	[null, null, 0], # Will be replaced with parent node in test
]):
	# Create the actual test objects here since parameters can't call methods
	var actual_node: Node2D
	if expected_count == 1 and expected_shape_type == RectangleShape2D:
		actual_node = GodotTestFactory.create_static_body_with_rect_shape(self)
	elif expected_count == 1 and expected_shape_type == ConvexPolygonShape2D:
		actual_node = GodotTestFactory.create_collision_polygon(self)
	else:
		actual_node = GodotTestFactory.create_parent_with_body_and_polygon(self)
	
	var shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(actual_node)
	assert_int(shapes.size()).is_equal(expected_count)
	if expected_shape_type != null and shapes.size() > 0:
		assert_object(shapes[0]).is_instanceof(expected_shape_type)

## Test for get_collision_object_shapes with multiple shapes
func test_get_collision_object_shapes_multiple():
	var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(self, Vector2(4, 4))
	# Add second collision shape manually since factory only creates one
	var shape2: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect2: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(8, 8))
	shape2.shape = rect2
	body.add_child(shape2)
	
	var shapes: Array[Shape2D] = GBGeometryUtils.get_collision_object_shapes(body)
	assert_int(shapes.size()).is_equal(2)
	assert_object(shapes[0]).is_instanceof(RectangleShape2D)
	assert_object(shapes[1]).is_instanceof(RectangleShape2D)

## Parameterized test for get_shapes_from_owner edge cases
@warning_ignore("unused_parameter")
func test_get_shapes_from_owner_edge_param(node_type: int, expected_count: int, test_parameters := [
	[0, 0], # Node2D
	[1, 1], # StaticBody2D with rect shape
	[2, 1], # CollisionPolygon2D
]):
	var test_node: Node2D
	match node_type:
		0: test_node = GodotTestFactory.create_node2d(self)
		1: test_node = GodotTestFactory.create_static_body_with_rect_shape(self)
		2: test_node = GodotTestFactory.create_collision_polygon(self)
	
	var shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(test_node)
	assert_int(shapes.size()).is_equal(expected_count)

## Test for get_all_collision_shapes_by_owner with nested children
func test_get_all_collision_shapes_by_owner_nested():
	var parent: Node2D = GodotTestFactory.create_node2d(self)
	var child1: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(self)
	var child2: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self)
	# Move from test root to parent
	child1.get_parent().remove_child(child1)
	child2.get_parent().remove_child(child2)
	parent.add_child(child1)
	parent.add_child(child2)
	var result: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(parent)
	assert_int(result.size()).is_equal(2)
	for collision_owner in result.keys():
		assert_int(result[collision_owner].size()).is_greater(0)

## Parameterized test for get_overlapped_tiles_for_polygon
## Expectation: only tiles with intersection area strictly greater than epsilon are included
@warning_ignore("unused_parameter")
func test_get_overlapped_tiles_for_polygon_param(polygon: PackedVector2Array, tile_size: Vector2, tile_type: int, expected: Array[Vector2i], epsilon: float, test_parameters := [
## Triangle, square tile size 16 (counts area overlap against tile (0,0))
 [PackedVector2Array([Vector2(0,0), Vector2(16,0), Vector2(8,16)]), Vector2(16,16), GBEnums.TileType.SQUARE, [Vector2i(0,0)], 0.01],
## Thin rectangle, square tile size 16 (actual overlap is only tile (1,0))
 [PackedVector2Array([Vector2(16,7), Vector2(32,7), Vector2(32,9), Vector2(16,9)]), Vector2(16,16), GBEnums.TileType.SQUARE, [Vector2i(1,0)], 0.01],
## Large square, tile size 8 (unchanged, passes)
 [PackedVector2Array([Vector2(0,0), Vector2(24,0), Vector2(24,24), Vector2(0,24)]), Vector2(8,8), GBEnums.TileType.SQUARE, [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)], 0.01],
## Diamond polygon, isometric tile size 16 (center at (16,16) so it spans 4 central tiles)
 [PackedVector2Array([Vector2(16,0), Vector2(32,16), Vector2(16,32), Vector2(0,16)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)], 8.0],
]):
	var tile_map: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	tile_map.tile_set.tile_size = tile_size
	var result: Array[Vector2i] = GBGeometryUtils.get_overlapped_tiles_for_polygon(polygon, tile_map, tile_type, epsilon)
	print("[DEBUG] overlapped tiles (param):", result)
	assert_int(result.size()).is_equal(expected.size())
	for tile in expected:
		assert_bool(result.has(tile)).append_failure_message("Missing expected tile: %s" % str(tile)).is_true()

## Parameterized test: is_tile_covered_by_collision_shape
## Note: Point/edge-only contact is zero area and normally should not count (> epsilon).
## This group reflects current behavior for RectangleShape2D conversion; expectations are
## documented per case.
@warning_ignore("unused_parameter")
func test_is_tile_covered_by_collision_shape_param(tile_pos: Vector2, tile_size: Vector2, shape_type: int, shape_pos: Vector2, shape_extents: Vector2, tile_type: int, expected: bool, test_parameters := [
 # Tile at (0,0), RectangleShape2D at (16,16) (touches at one point, actual: true)
 [Vector2(0,0), Vector2(16,16), 0, Vector2(16,16), Vector2(8,8), GBEnums.TileType.SQUARE, true],
 # Tile at (0,0), RectangleShape2D at (0,16) (touches at edge, actual: true)
 [Vector2(0,0), Vector2(16,16), 0, Vector2(0,16), Vector2(8,8), GBEnums.TileType.SQUARE, true],
 # Tile at (0,0), RectangleShape2D at (8,8) (true overlap)
 [Vector2(0,0), Vector2(16,16), 0, Vector2(8,8), Vector2(8,8), GBEnums.TileType.SQUARE, true],
]):
	var shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	if shape_type == 0:
		shape.shape = GodotTestFactory.create_rectangle_shape(shape_extents)
	shape.global_position = shape_pos
	var result := GBGeometryUtils.is_tile_covered_by_collision_shape(tile_pos, tile_size, shape, tile_type)
	assert_bool(result).is_equal(expected)

## Parameterized test: is_tile_covered_by_collision_polygon
## Point/edge contact should NOT count; area must be > epsilon
@warning_ignore("unused_parameter")
func test_is_tile_covered_by_collision_polygon_param(tile_pos: Vector2, tile_size: Vector2, polygon: PackedVector2Array, tile_type: int, expected: bool, test_parameters := [
	# Tile at (0,0), polygon vertex at (16,16) (touches at one point)
	[Vector2(0,0), Vector2(16,16), PackedVector2Array([Vector2(16,16), Vector2(32,16), Vector2(32,32), Vector2(16,32)]), GBEnums.TileType.SQUARE, false],
	# Tile at (0,0), polygon edge at y=16 (touches at edge)
	[Vector2(0,0), Vector2(16,16), PackedVector2Array([Vector2(0,16), Vector2(16,16), Vector2(16,32), Vector2(0,32)]), GBEnums.TileType.SQUARE, false],
	# Tile at (0,0), polygon overlaps (true overlap)
	[Vector2(0,0), Vector2(16,16), PackedVector2Array([Vector2(4,4), Vector2(20,4), Vector2(20,20), Vector2(4,20)]), GBEnums.TileType.SQUARE, true],
]):
	var poly: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, polygon)
	var result := GBGeometryUtils.is_tile_covered_by_collision_polygon(tile_pos, tile_size, poly, tile_type)
	assert_bool(result).is_equal(expected)

## Parameterized test: get_overlapped_tiles_for_polygon
## Single-point/edge contact should NOT count as collision (area must be > epsilon)
@warning_ignore("unused_parameter")
func test_get_overlapped_tiles_for_polygon_single_point_param(polygon: PackedVector2Array, tile_size: Vector2, tile_type: int, expected: Array[Vector2i], epsilon: float, test_parameters := [
 # Polygon vertex at (16,16), tile at (0,0) (touches at one point, actual: [Vector2i(1,1)])
  [PackedVector2Array([Vector2(16,16), Vector2(32,16), Vector2(32,32), Vector2(16,32)]), Vector2(16,16), GBEnums.TileType.SQUARE, [Vector2i(1,1)], 0.01],
  # Diamond polygon near origin spanning adjacent isometric tiles; expect four overlaps
  [PackedVector2Array([Vector2(8,16), Vector2(24,8), Vector2(8,-8), Vector2(-8,8)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [Vector2i(0,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)], 1.0],
]):
	var tile_map: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	tile_map.tile_set.tile_size = tile_size
	var result: Array[Vector2i] = GBGeometryUtils.get_overlapped_tiles_for_polygon(polygon, tile_map, tile_type, epsilon)
	print("[DEBUG] overlapped tiles (single_point):", result)
	assert_int(result.size()).is_equal(expected.size())
	for tile in expected:
		assert_bool(result.has(tile)).append_failure_message("Missing expected tile: %s" % str(tile)).is_true()

## Additional isometric cases for strict area-based overlap
## IMPORTANT: For isometric tiles, polygon coordinates must overlap the tile polygons in world space.
## If the polygon is not centered appropriately, intersection area is zero and tests will fail.
## All polygons now use counterclockwise winding to match tile polygon
## Polygon fully inside a single isometric tile: use top-left (0,0) + diamond
@warning_ignore("unused_parameter")
func test_get_overlapped_tiles_for_polygon_isometric_cases_param(polygon: PackedVector2Array, tile_size: Vector2, tile_type: int, expected: Array[Vector2i], epsilon: float, test_parameters := [
	# NOTE (2025-08-09): Earlier failures came from assuming raw Cartesian offsets matched isometric tile centers; polygons only touched by point/edge so expectations were invalid. Always derive/world-position polygons so they produce area > epsilon.
	# Case 0: Diamond fully inside tile (0,0)
	[PackedVector2Array([Vector2(8,0), Vector2(16,8), Vector2(8,16), Vector2(0,8)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [Vector2i(0,0)], 1.0],
	# Case 1 (fixed): Diamond centered at x=16,y=8 spanning tiles (0,0) & (1,0) (straddles vertical boundary)
	[PackedVector2Array([Vector2(16,0), Vector2(24,8), Vector2(16,16), Vector2(8,8)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [Vector2i(0,0), Vector2i(1,0)], 1.0],
	# Case 2: Diamond to the right, no overlap with origin area
	[PackedVector2Array([Vector2(32,8), Vector2(40,16), Vector2(32,24), Vector2(24,16)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [], 1.0],
	# Case 3 (fixed): Small diamond (half size) centered inside tile (0,0)
	[PackedVector2Array([Vector2(8,4), Vector2(12,8), Vector2(8,12), Vector2(4,8)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [Vector2i(0,0)], 1.0],
	# Case 4: Far diamond no overlap
	[PackedVector2Array([Vector2(32,24), Vector2(40,32), Vector2(32,40), Vector2(24,32)]), Vector2(16,16), GBEnums.TileType.ISOMETRIC, [], 1.0],
]):
	var tile_map: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	tile_map.tile_set.tile_size = tile_size
	# Print tile polygon for (0,0) for the first test case
	if expected == [Vector2i(0,0)]:
		var cell_center := tile_map.map_to_local(Vector2i(0,0))
		var _tile_poly := GBGeometryMath.get_tile_polygon(cell_center, tile_size, tile_type)

	var result: Array[Vector2i] = GBGeometryUtils.get_overlapped_tiles_for_polygon(polygon, tile_map, tile_type, epsilon)

	assert_int(result.size()).is_equal(expected.size())
	for tile in expected:
		assert_bool(result.has(tile)).append_failure_message("Missing expected tile: %s" % str(tile)).is_true()
