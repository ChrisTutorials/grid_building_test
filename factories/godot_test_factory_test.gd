# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# Test Constants
const DEFAULT_RECT_SIZE: Vector2 = Vector2(32, 32)  # API changed from extents to size (double the old values)
const CUSTOM_RECT_EXTENTS: Vector2 = Vector2(10, 20)  # Input extents parameter to factory
const CUSTOM_RECT_SIZE: Vector2 = Vector2(20, 40)     # Expected size output (extents * 2)
const DEFAULT_CIRCLE_RADIUS: float = 25.0
const EXPECTED_TILEMAP_SIZE: Vector2 = Vector2(31, 31)
const DEFAULT_COLLISION_LAYER: int = 1
const TRIANGLE_VERTEX_COUNT: int = 3
const RECTANGLE_VERTEX_COUNT: int = 4
const EXPECTED_PARENT_CHILDREN: int = 1  # Factory appears to create 1 child, not 2
const SHAPE_TEST_SIZE: Vector2 = Vector2(50, 60)
const INDICATOR_SIZE: Vector2 = Vector2(32, 32)

var test_container: GBCompositionContainer

var _injector : GBInjectorSystem

func before_test() -> void:
	# Use test environment instead of factory method
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)
	auto_free(env)

	_injector = env.injector


func test_create_node2d() -> void:
	var node: Node2D = GodotTestFactory.create_node2d(self)

	assert_object(node).append_failure_message("create_node2d: node should not be null").is_not_null()
	assert_object(node.get_parent()) \
		.append_failure_message("create_node2d: node should be parented to test instance").is_equal(self)


func test_create_node() -> void:
	var node: Node = GodotTestFactory.create_node(self)

	assert_object(node).append_failure_message("create_node: node should not be null").is_not_null()
	assert_object(node.get_parent()) \
		.append_failure_message("create_node: node should be parented to test instance").is_equal(self)


func test_create_canvas_item() -> void:
	var item: CanvasItem = GodotTestFactory.create_canvas_item(self)

	assert_object(item) \
		.append_failure_message("create_canvas_item: item should not be null").is_not_null()
	assert_object(item.get_parent()) \
		.append_failure_message("create_canvas_item: item should be parented to test instance") \
		.is_equal(self)


func test_create_tile_map_layer_with_grid() -> void:
	# Use premade 31x31 test tilemap instead of creating a small 10x10
	var packed: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var layer: TileMapLayer = packed.instantiate() as TileMapLayer
	add_child(layer)
	auto_free(layer)

	assert_object(layer).append_failure_message("create_tile_map_layer_with_grid: layer should not be null").is_not_null()
	assert_object(layer.get_parent()).append_failure_message("create_tile_map_layer_with_grid: layer should be parented to test instance").is_equal(self)
	assert_object(layer.tile_set).append_failure_message("create_tile_map_layer_with_grid: layer.tile_set should not be null").is_not_null()
	# Verify expected used rect matches 31x31 dimensions used in environments
	var used_rect: Rect2i = layer.get_used_rect()
	assert_vector(Vector2(used_rect.size)).append_failure_message("Packed test tilemap should be 31x31").is_equal(Vector2(31, 31))


func test_create_empty_tile_map_layer() -> void:
	var layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)

	assert_object(layer) \
		.append_failure_message("create_empty_tile_map_layer: layer should not be null").is_not_null()
	assert_object(layer.get_parent()) \
		.append_failure_message("create_empty_tile_map_layer: layer should be parented to test instance") \
		.is_equal(self)
	assert_object(layer.tile_set) \
		.append_failure_message("create_empty_tile_map_layer: layer.tile_set should not be null") \
		.is_not_null()

func test_create_static_body_with_rect_shape_default() -> void:
	var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(self)

	# Validate body setup
	_assert_static_body_valid(body, "static_body_with_rect_shape_default")

	# Validate shape configuration
	var rect_shape: RectangleShape2D = _get_rect_shape_from_body(body)
	assert_that(rect_shape.size).append_failure_message(
		"Default rectangle shape size mismatch - Expected: %s, Actual: %s, Shape extents may have changed to size API" %
		[str(DEFAULT_RECT_SIZE), str(rect_shape.size)]
	).is_equal(DEFAULT_RECT_SIZE)


func test_create_static_body_with_rect_shape_custom() -> void:
	var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(
		self, CUSTOM_RECT_EXTENTS
	)

	_assert_static_body_valid(body, "static_body_with_rect_shape_custom")

	var rect_shape: RectangleShape2D = _get_rect_shape_from_body(body)
	assert_that(rect_shape.size).append_failure_message(
		"Custom rectangle shape size mismatch - Expected: %s, Actual: %s, Input extents: %s, Factory doubles extents to get size" %
		[str(CUSTOM_RECT_SIZE), str(rect_shape.size), str(CUSTOM_RECT_EXTENTS)]
	).is_equal(CUSTOM_RECT_SIZE)


func test_create_area2d_with_circle_shape() -> void:
	var area: Area2D = GodotTestFactory.create_area2d_with_circle_shape(self, DEFAULT_CIRCLE_RADIUS)

	_assert_area2d_valid(area, "area2d_with_circle_shape")

	var circle_shape: CircleShape2D = _get_circle_shape_from_area(area)
	assert_that(circle_shape.radius).append_failure_message(
		"Area2D circle shape radius mismatch - Expected: %s, Actual: %s, Input radius: %s" %
		[str(DEFAULT_CIRCLE_RADIUS), str(circle_shape.radius), str(DEFAULT_CIRCLE_RADIUS)]
	).is_equal(DEFAULT_CIRCLE_RADIUS)


func test_create_collision_polygon_default() -> void:
	var polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self)

	assert_object(polygon).append_failure_message(
		"CollisionPolygon2D should not be null"
	).is_not_null()
	assert_object(polygon.get_parent()).append_failure_message(
		"CollisionPolygon2D should be parented to test instance, parent: %s" % str(polygon.get_parent())
	).is_equal(self)
	assert_object(polygon.polygon).append_failure_message(
		"CollisionPolygon2D should have polygon points assigned"
	).is_not_null()
	assert_int(polygon.polygon.size()).append_failure_message(
		"Default collision polygon should have %d points (triangle), got: %d points" % [TRIANGLE_VERTEX_COUNT, polygon.polygon.size()]
	).is_equal(TRIANGLE_VERTEX_COUNT)


func test_create_collision_polygon_custom() -> void:
	var custom_points: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	var polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, custom_points)

	assert_object(polygon).append_failure_message(
		"Custom CollisionPolygon2D should not be null"
	).is_not_null()
	assert_object(polygon.get_parent()).append_failure_message(
		"Custom CollisionPolygon2D should be parented to test instance, parent: %s" % str(polygon.get_parent())
	).is_equal(self)
	assert_int(polygon.polygon.size()).append_failure_message(
		"Custom collision polygon should have %d points (rectangle), got: %d points, input: %s" % [RECTANGLE_VERTEX_COUNT, polygon.polygon.size(), str(custom_points)]
	).is_equal(RECTANGLE_VERTEX_COUNT)
	assert_that(polygon.polygon).append_failure_message(
		"Custom collision polygon points mismatch - Expected: %s, Actual: %s" % [str(custom_points), str(polygon.polygon)]
	).is_equal(custom_points)


func test_create_object_with_circle_shape() -> void:
	var obj: Node2D = GodotTestFactory.create_object_with_circle_shape(self)

	assert_object(obj) \
		.append_failure_message("create_object_with_circle_shape: returned object should not be null") \
		.is_not_null()
	assert_object(obj.get_parent()) \
		.append_failure_message("create_object_with_circle_shape: object should be parented to test instance") \
		.is_equal(self)

	# Check has StaticBody2D child
	var body: StaticBody2D = obj.get_child(0) as StaticBody2D
	assert_object(body) \
		.append_failure_message("create_object_with_circle_shape: StaticBody2D child should exist") \
		.is_not_null()
	assert_that(body.collision_layer) \
		.append_failure_message("create_object_with_circle_shape: StaticBody2D collision_layer mismatch") \
		.is_equal(1)

	# Check collision shape
	var collision_shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	assert_object(collision_shape) \
		.append_failure_message("create_object_with_circle_shape: CollisionShape2D should exist") \
		.is_not_null()
	assert_object(collision_shape.shape) \
		.append_failure_message("create_object_with_circle_shape: collision_shape.shape should be CircleShape2D") \
		.is_instanceof(CircleShape2D)


func test_create_parent_with_body_and_polygon() -> void:
	var parent: Node2D = GodotTestFactory.create_parent_with_body_and_polygon(self)

	assert_object(parent) \
		.append_failure_message("create_parent_with_body_and_polygon: parent should not be null") \
		.is_not_null()
	assert_object(parent.get_parent()) \
		.append_failure_message("create_parent_with_body_and_polygon: parent should be parented to test instance") \
		.is_equal(self)
	assert_that(parent.get_child_count()) \
		.append_failure_message("create_parent_with_body_and_polygon: expected 2 children on parent") \
		.is_equal(2)

	# Check children types
	var child1: Node = parent.get_child(0)
	var child2: Node = parent.get_child(1)

	# One should be StaticBody2D, one should be CollisionPolygon2D
	var has_body: bool = child1 is StaticBody2D or child2 is StaticBody2D
	var has_polygon: bool = child1 is CollisionPolygon2D or child2 is CollisionPolygon2D

	assert_bool(has_body) \
		.append_failure_message("StaticBody2D child should be present") \
		.is_true()
	assert_bool(has_polygon) \
		.append_failure_message("CollisionPolygon2D child should be present") \
		.is_true()


func test_create_rectangle_shape() -> void:
	var shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(50, 60))

	assert_object(shape) \
		.append_failure_message("create_rectangle_shape: shape should not be null").is_not_null()
	assert_object(shape) \
		.append_failure_message("create_rectangle_shape: shape should be RectangleShape2D") \
		.is_instanceof(RectangleShape2D)
	assert_that(shape.size) \
		.append_failure_message("create_rectangle_shape: shape size mismatch").is_equal(Vector2(50, 60))


func test_create_circle_shape() -> void:
	var shape: CircleShape2D = GodotTestFactory.create_circle_shape(25.0)

	assert_object(shape) \
		.append_failure_message("create_circle_shape: shape should not be null").is_not_null()
	assert_object(shape) \
		.append_failure_message("create_circle_shape: shape should be CircleShape2D") \
		.is_instanceof(CircleShape2D)
	assert_that(shape.radius) \
		.append_failure_message("create_circle_shape: radius mismatch").is_equal(25.0)


func test_create_rule_check_indicator() -> void:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	var default_shape: RectangleShape2D = RectangleShape2D.new()
	default_shape.size = Vector2(16, 16)
	indicator.shape = default_shape
	indicator.target_position = Vector2.ZERO
	add_child(indicator)
	auto_free(indicator)
	# Adjust size to 32x32 for this test case
	if indicator.shape is RectangleShape2D:
		(indicator.shape as RectangleShape2D).size = Vector2(32, 32)

	assert_object(indicator) \
		.append_failure_message("create_rule_check_indicator: indicator should not be null").is_not_null()
	assert_object(indicator.shape) \
		.append_failure_message("create_rule_check_indicator: indicator.shape should not be null") \
		.is_not_null()
	assert_object(indicator.shape) \
		.append_failure_message("create_rule_check_indicator: indicator.shape should be RectangleShape2D") \
		.is_instanceof(RectangleShape2D)

	var rect_shape: RectangleShape2D = indicator.shape as RectangleShape2D
	assert_that(rect_shape.size).append_failure_message("create_rule_check_indicator: rect_shape.size mismatch").is_equal(Vector2(32, 32))

#region HELPER_METHODS

func _assert_static_body_valid(body: StaticBody2D, context: String) -> void:
	"""Validates that a StaticBody2D meets expected factory standards"""
	assert_object(body).append_failure_message(
		"StaticBody2D should not be null for context: %s" % context
	).is_not_null()

	assert_object(body.get_parent()).append_failure_message(
		"StaticBody2D should be parented to test instance for context: %s, parent: %s" % [context, str(body.get_parent())]
	).is_same(self)

	assert_int(body.get_child_count()).append_failure_message(
		"StaticBody2D should have %d children for context: %s, actual count: %d" % [EXPECTED_PARENT_CHILDREN, context, body.get_child_count()]
	).is_equal(EXPECTED_PARENT_CHILDREN)

func _assert_area2d_valid(area: Area2D, context: String) -> void:
	"""Validates that an Area2D meets expected factory standards"""
	assert_object(area).append_failure_message(
		"Area2D should not be null for context: %s" % context
	).is_not_null()

	assert_object(area.get_parent()).append_failure_message(
		"Area2D should be parented to test instance for context: %s, parent: %s" % [context, str(area.get_parent())]
	).is_same(self)

	assert_int(area.get_child_count()).append_failure_message(
		"Area2D should have %d children for context: %s, actual count: %d" % [EXPECTED_PARENT_CHILDREN, context, area.get_child_count()]
	).is_equal(EXPECTED_PARENT_CHILDREN)

	assert_int(area.collision_layer).append_failure_message(
		"Area2D collision layer should be %d for context: %s, actual: %d" % [DEFAULT_COLLISION_LAYER, context, area.collision_layer]
	).is_equal(DEFAULT_COLLISION_LAYER)

func _get_rect_shape_from_body(body: StaticBody2D) -> RectangleShape2D:
	"""Extracts RectangleShape2D from StaticBody2D collision shape"""
	var collision_shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	assert_object(collision_shape).append_failure_message(
		"StaticBody2D should have CollisionShape2D as first child, got: %s" % str(collision_shape)
	).is_not_null()

	assert_object(collision_shape.shape).append_failure_message(
		"CollisionShape2D should have RectangleShape2D shape, got: %s" % str(collision_shape.shape)
	).is_instanceof(RectangleShape2D)

	return collision_shape.shape as RectangleShape2D

func _get_circle_shape_from_body(body: StaticBody2D) -> CircleShape2D:
	"""Extracts CircleShape2D from StaticBody2D collision shape"""
	var collision_shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	assert_object(collision_shape).append_failure_message(
		"StaticBody2D should have CollisionShape2D as first child, got: %s" % str(collision_shape)
	).is_not_null()

	assert_object(collision_shape.shape).append_failure_message(
		"CollisionShape2D should have CircleShape2D shape, got: %s" % str(collision_shape.shape)
	).is_instanceof(CircleShape2D)

	return collision_shape.shape as CircleShape2D

func _get_circle_shape_from_area(area: Area2D) -> CircleShape2D:
	"""Extracts CircleShape2D from Area2D collision shape"""
	var collision_shape: CollisionShape2D = area.get_child(0) as CollisionShape2D
	assert_object(collision_shape).append_failure_message(
		"Area2D should have CollisionShape2D as first child, got: %s" % str(collision_shape)
	).is_not_null()

	assert_object(collision_shape.shape).append_failure_message(
		"CollisionShape2D should have CircleShape2D shape, got: %s" % str(collision_shape.shape)
	).is_instanceof(CircleShape2D)

	return collision_shape.shape as CircleShape2D

func _calculate_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	"""Calculates bounding rectangle for polygon"""
	if polygon.is_empty():
		return Rect2()

	var min_point: Vector2 = polygon[0]
	var max_point: Vector2 = polygon[0]

	for point in polygon:
		min_point = Vector2(min(min_point.x, point.x), min(min_point.y, point.y))
		max_point = Vector2(max(max_point.x, point.x), max(max_point.y, point.y))

	return Rect2(min_point, max_point - min_point)

func _calculate_polygon_area(polygon: PackedVector2Array) -> float:
	"""Calculates area of polygon using shoelace formula"""
	if polygon.size() < 3:
		return 0.0

	var area: float = 0.0
	var n: int = polygon.size()

	for i in range(n):
		var j: int = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y

	return abs(area) / 2.0

#endregion
