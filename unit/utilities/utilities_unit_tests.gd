extends GdUnitTestSuite

## Comprehensive unit tests for core utility classes: geometry math, geometry utils, collision geometry,
## string utilities, and search utilities. Tests individual utility functions in isolation with
## proper validation of collision object discovery, mathematical operations, and utility functions.
## Ensures robust collision detection and mathematical accuracy across all utility systems.

@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

#region CONSTANTS

## Standard test tile dimensions
const TEST_TILE_SIZE := Vector2(32, 32)
const TEST_TILE_POS := Vector2(10, 10)
const TEST_RECT_SIZE := Vector2(32, 32)
const TEST_POSITION := Vector2(10, 10)

## Test data polygons for various geometric operations
var TEST_POLYGON := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
var TEST_CONVEX_POLYGON := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
var TEST_CONCAVE_POLYGON := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 5), Vector2(10, 10), Vector2(0, 10)])

## Expected intersection area for polygon tests
const EXPECTED_INTERSECTION_AREA := 25.0

## Standard polygon vertex count
const POLYGON_VERTEX_COUNT := 4

## Performance test parameters
const PERFORMANCE_ITERATION_COUNT := 100
const PERFORMANCE_MAX_TIME_US := 100000  # 0.1 seconds

## Test string constants
const TEST_NODE_NAME := "test_node_name"
const TEST_STATIC_BODY_NAME := "TestStaticBody"

## Assertion message constants
const SCENE_LOAD_SUCCESS_MESSAGE := "Scene should load successfully: "
const COLLISION_OBJECT_COUNT_MESSAGE := "Scene {scene_path} should have exactly {expected_count} collision objects"

## Test scene paths and expected collision object counts
const TEST_SCENE_DATA := [
	[GBTestConstants.GIGANTIC_EGG_PATH, 1],
	[GBTestConstants.PILLAR_PATH, 1],
	[GBTestConstants.RECT_15_TILES_PATH, 1],
	[GBTestConstants.SMITHY_PATH, 2],
	[GBTestConstants.PLACEABLE_INSTANCE_2D_PATH, 0],
	[GBTestConstants.TEST_2D_OBJECT_PATH, 0],
	[GBTestConstants.ELLIPSE_PATH, 1],
	[GBTestConstants.SKEW_ROTATION_RECT_PATH, 1],
	[GBTestConstants.ISOMETRIC_BUILDING_PATH, 1],
	[GBTestConstants.SCRIPT_KEEP_SCENE_PATH, 0],
]

#endregion

#region TEST DATA VARIABLES

var _created_test_nodes: Array[Node] = []

#endregion

#region GEOMETRY MATHEMATICS TESTS

@warning_ignore("unused_parameter")
func test_geometry_math_polygon_intersection() -> void:
	var poly_a := TEST_POLYGON
	var poly_b := PackedVector2Array([Vector2(5, 5), Vector2(15, 5), Vector2(15, 15), Vector2(5, 15)])

	var intersection_area: float = GBGeometryMath.polygon_intersection_area(poly_a, poly_b)
	assert_that(intersection_area).is_equal(EXPECTED_INTERSECTION_AREA)

@warning_ignore("unused_parameter")
func test_geometry_math_tile_operations() -> void:
	var tile_polygon: PackedVector2Array = GBGeometryMath.get_tile_polygon(Vector2(0, 0), TEST_TILE_SIZE, TileSet.TILE_SHAPE_SQUARE)

	assert_that(tile_polygon.size()).is_equal(POLYGON_VERTEX_COUNT)
	assert_that(tile_polygon[0]).is_equal(Vector2(0, 0))

@warning_ignore("unused_parameter")
func test_geometry_math_polygon_overlap() -> void:
	var polygon := PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)])

	var overlaps: bool = GBGeometryMath.does_polygon_overlap_tile(polygon, TEST_TILE_POS, TEST_TILE_SIZE, TileSet.TILE_SHAPE_SQUARE, 0.01)
	assert_that(overlaps).is_true()

#endregion

#region GEOMETRY UTILITIES TESTS

@warning_ignore("unused_parameter")
func test_geometry_utils_collision_shapes() -> void:
	var test_obj := _create_test_node_with_collision_shape()
	_track_test_node(test_obj)
	add_child(test_obj)

	var shapes_by_owner: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(test_obj)
	assert_that(shapes_by_owner.size()).is_greater(0)

#endregion

#region COLLISION GEOMETRY TESTS

@warning_ignore("unused_parameter")
func test_collision_geometry_utils_transform_building() -> void:
	var test_obj := _create_test_node_with_static_body()
	_track_test_node(test_obj)
	add_child(test_obj)

	var transform: Transform2D = CollisionGeometryUtils.build_shape_transform(test_obj.get_child(0), test_obj)
	assert_that(transform.origin).is_equal(TEST_POSITION)

@warning_ignore("unused_parameter")
func test_collision_geometry_polygon_operations() -> void:
	var collision_polygon := _create_collision_polygon(TEST_POLYGON)
	_track_test_node(collision_polygon)
	add_child(collision_polygon)

	var world_polygon: PackedVector2Array = CollisionGeometryUtils.to_world_polygon(collision_polygon)
	assert_that(world_polygon.size()).is_equal(POLYGON_VERTEX_COUNT)

@warning_ignore("unused_parameter")
func test_collision_geometry_convex_check() -> void:
	assert_that(CollisionGeometryUtils.is_polygon_convex(TEST_CONVEX_POLYGON)).is_true()
	assert_that(CollisionGeometryUtils.is_polygon_convex(TEST_CONCAVE_POLYGON)).is_false()

#endregion

#region STRING UTILITIES TESTS

@warning_ignore("unused_parameter")
func test_string_utilities_name_conversion() -> void:
	var readable_name: String = GBString.convert_name_to_readable(TEST_NODE_NAME)
	assert_that(readable_name).is_not_equal(TEST_NODE_NAME)  # Should be converted

@warning_ignore("unused_parameter")
func test_string_utilities_separator_matching(
	separator: String,
	separator_type: int,
	expected: bool,
	test_parameters := [
		["_", GBString.SeparatorType.UNDERSCORE, true],
		["-", GBString.SeparatorType.DASH, true],
		[" ", GBString.SeparatorType.SPACE, true],
		["_ ", GBString.SeparatorType.NONE, false],
		["_ ", GBString.SeparatorType.SPACE, false],
		["_ ", GBString.SeparatorType.DASH, false],
		["- ", GBString.SeparatorType.NONE, false],
		["- ", GBString.SeparatorType.SPACE, false],
		["- ", GBString.SeparatorType.UNDERSCORE, false],
		["  ", GBString.SeparatorType.NONE, false],
		["  ", GBString.SeparatorType.UNDERSCORE, false],
		["  ", GBString.SeparatorType.DASH, false]
	]
) -> void:
	var result: bool = GBString.match_num_seperator(separator, separator_type)
	assert_bool(result).is_equal(expected)

@warning_ignore("unused_parameter")
func test_string_utilities_get_separator_string(
	separator_type: int,
	expected: String,
	test_parameters := [
		[GBString.SeparatorType.NONE, ""],
		[GBString.SeparatorType.SPACE, " "],
		[GBString.SeparatorType.UNDERSCORE, "_"],
		[GBString.SeparatorType.DASH, "-"]
	]
) -> void:
	var result: String = GBString.get_separator_string(separator_type)
	assert_str(result).is_equal(expected)

#endregion

#region SEARCH UTILITIES TESTS

@warning_ignore("unused_parameter")
func test_search_utils_find_first() -> void:
	var parent := _create_test_parent_with_static_body()
	_track_test_node(parent)
	add_child(parent)

	var found: Node = GBSearchUtils.find_first(parent, StaticBody2D)
	assert_that(found).is_not_null()
	assert_that(found).is_same(parent.get_child(0))

@warning_ignore("unused_parameter")
func test_search_utils_collision_objects() -> void:
	var parent := _create_test_parent_with_collision_objects()
	_track_test_node(parent)
	add_child(parent)

	var collision_objects: Array = GBSearchUtils.get_collision_object_2ds(parent)
	assert_that(collision_objects.size()).is_equal(2)

@warning_ignore("unused_parameter")
func test_search_utils_premade_scene_collision_objects(
	scene_path: String,
	expected_collision_count: int,
	test_parameters := TEST_SCENE_DATA
) -> void:
	# Test that premade scenes properly return collision objects (or lack thereof)
	# This validates that fallback mechanisms are only needed when appropriate
	var scene: PackedScene = load(scene_path)
	assert_that(scene).is_not_null().append_failure_message(
		"Scene should load successfully: " + scene_path
	)
	
	var instance: Node2D = scene.instantiate()
	_track_test_node(instance)
	add_child(instance)
	
	var collision_objects: Array = GBSearchUtils.get_collision_object_2ds(instance)
	assert_that(collision_objects.size()).is_equal(expected_collision_count).append_failure_message(
		"Scene " + scene_path + " should have exactly " + str(expected_collision_count) + " collision objects"
	)
	
	# If collision objects exist, verify they are properly configured
	if expected_collision_count > 0:
		_assert_collision_objects_properly_configured(collision_objects, scene_path)

# Integration tests - Environment usage
# ================================================================================

@warning_ignore("unused_parameter")
func test_geometry_collision_integration() -> void:
	var collision_polygon := _create_collision_polygon(PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20), Vector2(0, 20)]))
	_track_test_node(collision_polygon)
	add_child(collision_polygon)

	var world_polygon: PackedVector2Array = CollisionGeometryUtils.to_world_polygon(collision_polygon)
	var intersection_area: float = GBGeometryMath.intersection_area_with_tile(world_polygon, Vector2(0, 0), Vector2(20, 20), TileSet.TILE_SHAPE_SQUARE)

	assert_that(intersection_area).is_equal(400.0)  # Full overlap

@warning_ignore("unused_parameter")
func test_performance_utilities_combined() -> void:
	var start_time: int = Time.get_ticks_usec()

	for i in range(PERFORMANCE_ITERATION_COUNT):
		var tile_pos := Vector2(i, i)
		var tile_size := Vector2(16, 16)
		var polygon: PackedVector2Array = GBGeometryMath.get_tile_polygon(tile_pos, tile_size, TileSet.TILE_SHAPE_SQUARE)

		var is_convex: bool = CollisionGeometryUtils.is_polygon_convex(polygon)
		assert_that(polygon.size()).is_equal(POLYGON_VERTEX_COUNT)
		assert_that(is_convex).is_true()  # Square polygons are convex

	var elapsed: int = Time.get_ticks_usec() - start_time
	assert_that(elapsed).append_failure_message("Combined utilities performance test completed in " + str(elapsed) + " microseconds").is_less(PERFORMANCE_MAX_TIME_US)

#endregion

#region TEST SETUP AND TEARDOWN

func before_test() -> void:
	_created_test_nodes.clear()

func after_test() -> void:
	# Clean up all tracked test nodes to prevent state leakage
	for node: Node in _created_test_nodes:
		if is_instance_valid(node) and node.get_parent():
			node.queue_free()
	_created_test_nodes.clear()

## Helper to track test nodes for proper cleanup
func _track_test_node(node: Node) -> Node:
	if node and not _created_test_nodes.has(node):
		_created_test_nodes.append(node)
	return node

## Assert that collision objects are properly configured with valid layers and masks
func _assert_collision_objects_properly_configured(collision_objects: Array, context: String) -> void:
	for collision_obj: CollisionObject2D in collision_objects:
		assert_that(collision_obj.collision_layer).is_greater(0).append_failure_message(
			"Collision object in " + context + " should have a valid collision layer set"
		)
		assert_that(collision_obj.collision_mask).is_greater(0).append_failure_message(
			"Collision object in " + context + " should have a valid collision mask set"
		)

#endregion

#region HELPER FUNCTIONS

func _create_test_node_with_collision_shape() -> Node2D:
	var test_obj := Node2D.new()

	var static_body := StaticBody2D.new()
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = TEST_RECT_SIZE
	collision_shape.shape = rect_shape
	static_body.add_child(collision_shape)
	test_obj.add_child(static_body)

	return test_obj

func _create_test_node_with_static_body() -> Node2D:
	var test_obj := Node2D.new()

	var static_body := StaticBody2D.new()
	static_body.position = TEST_POSITION
	test_obj.add_child(static_body)

	return test_obj

func _create_collision_polygon(polygon: PackedVector2Array) -> CollisionPolygon2D:
	var collision_polygon := CollisionPolygon2D.new()
	collision_polygon.polygon = polygon
	return collision_polygon

func _create_test_parent_with_static_body() -> Node2D:
	var parent := Node2D.new()

	var static_body := StaticBody2D.new()
	static_body.name = TEST_STATIC_BODY_NAME
	parent.add_child(static_body)

	return parent

func _create_test_parent_with_collision_objects() -> Node2D:
	var parent := Node2D.new()

	var static_body := StaticBody2D.new()
	var area := Area2D.new()
	parent.add_child(static_body)
	parent.add_child(area)

	return parent
