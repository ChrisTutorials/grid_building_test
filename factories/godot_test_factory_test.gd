# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

var test_container: GBCompositionContainer

var _injector : GBInjectorSystem

func before_test() -> void:
	var test_composition_container: GBCompositionContainer = load("uid://dy6e5p5d6ax6n")
	_injector = UnifiedTestFactory.create_test_injector(self, test_composition_container)


func test_create_node2d() -> void:
	var node: Node2D = GodotTestFactory.create_node2d(self)

	assert_object(node).is_not_null()
	assert_object(node.get_parent()).is_equal(self)


func test_create_node() -> void:
	var node: Node = GodotTestFactory.create_node(self)

	assert_object(node).is_not_null()
	assert_object(node.get_parent()).is_equal(self)


func test_create_canvas_item() -> void:
	var item: CanvasItem = GodotTestFactory.create_canvas_item(self)

	assert_object(item).is_not_null()
	assert_object(item.get_parent()).is_equal(self)


func test_create_tile_map_layer_with_grid() -> void:
	var layer: TileMapLayer = GodotTestFactory.create_tile_map_layer(self, 10)

	assert_object(layer).is_not_null()
	assert_object(layer.get_parent()).is_equal(self)
	assert_object(layer.tile_set).is_not_null()


func test_create_empty_tile_map_layer() -> void:
	var layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)

	assert_object(layer).is_not_null()
	assert_object(layer.get_parent()).is_equal(self)
	assert_object(layer.tile_set).is_not_null()


func test_create_manipulatable() -> void:
	var manipulatable: Manipulatable = GodotTestFactory.create_manipulatable(
		self, "TestManipulatable"
	)

	assert_object(manipulatable).is_not_null()
	assert_that(manipulatable.name).is_equal("Manipulatable")
	assert_object(manipulatable.root).is_not_null()
	assert_that(manipulatable.root.name).is_equal("TestManipulatable")


func test_create_static_body_with_rect_shape_default() -> void:
	var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(self)

	assert_object(body).is_not_null()
	assert_object(body.get_parent()).is_equal(self)

	# Check collision shape
	var collision_shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	assert_object(collision_shape).is_not_null()
	assert_object(collision_shape.shape).is_instanceof(RectangleShape2D)

	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	assert_that(rect_shape.extents).is_equal(Vector2(8, 8))


func test_create_static_body_with_rect_shape_custom() -> void:
	var body: StaticBody2D = GodotTestFactory.create_static_body_with_rect_shape(
		self, Vector2(10, 20)
	)

	assert_object(body).is_not_null()
	assert_object(body.get_parent()).is_equal(self)

	# Check collision shape
	var collision_shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	assert_object(collision_shape).is_not_null()
	assert_object(collision_shape.shape).is_instanceof(RectangleShape2D)

	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	assert_that(rect_shape.extents).is_equal(Vector2(10, 20))


func test_create_area2d_with_circle_shape() -> void:
	var area: Area2D = GodotTestFactory.create_area2d_with_circle_shape(self, 25.0)

	assert_object(area).is_not_null()
	assert_object(area.get_parent()).is_equal(self)
	assert_that(area.collision_layer).is_equal(1)

	# Check collision shape
	var collision_shape: CollisionShape2D = area.get_child(0) as CollisionShape2D
	assert_object(collision_shape).is_not_null()
	assert_object(collision_shape.shape).is_instanceof(CircleShape2D)

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	assert_that(circle_shape.radius).is_equal(25.0)


func test_create_collision_polygon_default() -> void:
	var polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self)

	assert_object(polygon).is_not_null()
	assert_object(polygon.get_parent()).is_equal(self)
	assert_object(polygon.polygon).is_not_null()
	assert_that(polygon.polygon.size()).is_equal(3)  # Triangle has 3 points


func test_create_collision_polygon_custom() -> void:
	var custom_points: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]
	)
	var polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, custom_points)

	assert_object(polygon).is_not_null()
	assert_object(polygon.get_parent()).is_equal(self)
	assert_that(polygon.polygon.size()).is_equal(4)  # Rectangle has 4 points
	assert_that(polygon.polygon).is_equal(custom_points)


func test_create_object_with_circle_shape() -> void:
	var obj: Node2D = GodotTestFactory.create_object_with_circle_shape(self)

	assert_object(obj).is_not_null()
	assert_object(obj.get_parent()).is_equal(self)

	# Check has StaticBody2D child
	var body: StaticBody2D = obj.get_child(0) as StaticBody2D
	assert_object(body).is_not_null()
	assert_that(body.collision_layer).is_equal(1)

	# Check collision shape
	var collision_shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	assert_object(collision_shape).is_not_null()
	assert_object(collision_shape.shape).is_instanceof(CircleShape2D)


func test_create_parent_with_body_and_polygon() -> void:
	var parent: Node2D = GodotTestFactory.create_parent_with_body_and_polygon(self)

	assert_object(parent).is_not_null()
	assert_object(parent.get_parent()).is_equal(self)
	assert_that(parent.get_child_count()).is_equal(2)

	# Check children types
	var child1: Node = parent.get_child(0)
	var child2: Node = parent.get_child(1)

	# One should be StaticBody2D, one should be CollisionPolygon2D
	var has_body: bool = child1 is StaticBody2D or child2 is StaticBody2D
	var has_polygon: bool = child1 is CollisionPolygon2D or child2 is CollisionPolygon2D

	assert_bool(has_body).is_true()
	assert_bool(has_polygon).is_true()


func test_create_rectangle_shape() -> void:
	var shape: RectangleShape2D = GodotTestFactory.create_rectangle_shape(Vector2(50, 60))

	assert_object(shape).is_not_null()
	assert_object(shape).is_instanceof(RectangleShape2D)
	assert_that(shape.size).is_equal(Vector2(50, 60))


func test_create_circle_shape() -> void:
	var shape: CircleShape2D = GodotTestFactory.create_circle_shape(25.0)

	assert_object(shape).is_not_null()
	assert_object(shape).is_instanceof(CircleShape2D)
	assert_that(shape.radius).is_equal(25.0)


func test_create_rule_check_indicator() -> void:
	var indicator: RuleCheckIndicator = GodotTestFactory.create_rule_check_indicator(self, self, 32)

	assert_object(indicator).is_not_null()
	assert_object(indicator.shape).is_not_null()
	assert_object(indicator.shape).is_instanceof(RectangleShape2D)

	var rect_shape: RectangleShape2D = indicator.shape as RectangleShape2D
	assert_that(rect_shape.size).is_equal(Vector2(32, 32))
