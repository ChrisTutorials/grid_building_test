class_name GodotTestFactory
extends RefCounted

## Factory for creating Godot base class objects in tests
## Provides convenient methods for common Godot objects used in testing
## Keep this separate from UnifiedTestFactory to maintain clean separation

# ================================
# Node Creation
# ================================

## Creates a basic Node2D for testing with proper auto_free setup
static func create_node2d(test: GdUnitTestSuite) -> Node2D:
	var node: Node2D = test.auto_free(Node2D.new())
	test.add_child(node)
	return node

## Creates a Node with auto_free setup
static func create_node(test: GdUnitTestSuite) -> Node:
	var node: Node = test.auto_free(Node.new())
	test.add_child(node)
	return node

## Creates a CanvasItem with auto_free setup
static func create_canvas_item(test: GdUnitTestSuite) -> CanvasItem:
	var item: CanvasItem = test.auto_free(Node2D.new())  # Use Node2D as concrete CanvasItem
	test.add_child(item)
	return item

# ================================
# TileMap Objects
# ================================

## Creates a TileMapLayer with basic tile set and populated grid for testing
static func create_tile_map_layer(test: GdUnitTestSuite, grid_size: int = 200) -> TileMapLayer:
	var map_layer: TileMapLayer = test.auto_free(TileMapLayer.new())
	map_layer.tile_set = load("uid://d11t2vm1pby6y")
	
	# Create a reasonable sized grid for testing
	@warning_ignore("integer_division")
	var half_size: int = grid_size / 2
	for x in range(-half_size, half_size):
		for y in range(-half_size, half_size):
			var coords = Vector2i(x, y)
			map_layer.set_cellv(coords, 0, Vector2i(0, 0))
	
	test.add_child(map_layer)
	return map_layer

## Creates an empty TileMapLayer with tile set but no cells
static func create_empty_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	var map_layer: TileMapLayer = test.auto_free(TileMapLayer.new())
	map_layer.tile_set = TileSet.new()
	test.add_child(map_layer)
	return map_layer

# ================================
# Collision Objects
# ================================

## Creates a StaticBody2D with rectangular collision shape
static func create_static_body_with_rect_shape(test: GdUnitTestSuite, extents: Vector2 = Vector2(8, 8)) -> StaticBody2D:
	var body: StaticBody2D = test.auto_free(StaticBody2D.new())
	var shape: CollisionShape2D = test.auto_free(CollisionShape2D.new())
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.extents = extents
	shape.shape = rect
	test.add_child(body)
	body.add_child(shape)
	return body

## Creates an Area2D with circular collision shape
static func create_area2d_with_circle_shape(test: GdUnitTestSuite, radius: float = 16.0) -> Area2D:
	var area: Area2D = test.auto_free(Area2D.new())
	var shape: CollisionShape2D = test.auto_free(CollisionShape2D.new())
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 1
	test.add_child(area)
	return area

## Creates a CollisionPolygon2D with triangle shape
static func create_collision_polygon(test: GdUnitTestSuite, polygon: PackedVector2Array = PackedVector2Array()) -> CollisionPolygon2D:
	var poly: CollisionPolygon2D = test.auto_free(CollisionPolygon2D.new())
	if polygon.is_empty():
		# Default triangle
		poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)])
	else:
		poly.polygon = polygon
	test.add_child(poly)
	return poly

## Creates a Node2D with a child StaticBody2D that has a circle collision shape
static func create_object_with_circle_shape(test: GdUnitTestSuite) -> Node2D:
	var test_object: Node2D = test.auto_free(Node2D.new())
	var body: StaticBody2D = test.auto_free(StaticBody2D.new())
	test_object.add_child(body)
	var collision_shape: CollisionShape2D = test.auto_free(CollisionShape2D.new())
	collision_shape.shape = CircleShape2D.new()
	body.add_child(collision_shape)
	body.collision_layer = 1
	test.add_child(test_object)
	return test_object

## Creates a parent Node2D with both StaticBody2D and CollisionPolygon2D children
static func create_parent_with_body_and_polygon(test: GdUnitTestSuite) -> Node2D:
	var parent: Node2D = test.auto_free(Node2D.new())
	test.add_child(parent)
	
	# Create body and polygon using other factory methods
	var body: StaticBody2D = create_static_body_with_rect_shape(test)
	var poly: CollisionPolygon2D = create_collision_polygon(test)
	
	# Move from test root to parent
	if body.get_parent() != null:
		body.get_parent().remove_child(body)
	if poly.get_parent() != null:
		poly.get_parent().remove_child(poly)
	
	parent.add_child(body)
	parent.add_child(poly)
	return parent

# ================================
# Shapes
# ================================

## Creates a RectangleShape2D with specified size
static func create_rectangle_shape(size: Vector2 = Vector2(16, 16)) -> RectangleShape2D:
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.extents = size
	return rect

## Creates a CircleShape2D with specified radius
static func create_circle_shape(radius: float = 8.0) -> CircleShape2D:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	return circle

# ================================
# Grid Building Specific Nodes
# ================================

## Creates a Manipulatable with proper setup
static func create_manipulatable(test: GdUnitTestSuite, root_name: String = "ManipulatableRoot") -> Manipulatable:
	var root: Node2D = test.auto_free(Node2D.new())
	test.add_child(root)
	var manipulatable: Manipulatable = test.auto_free(Manipulatable.new())
	manipulatable.root = root
	root.add_child(manipulatable)
	root.name = root_name
	manipulatable.name = "Manipulatable"
	return manipulatable

## Creates a RuleCheckIndicator with rectangular shape
static func create_rule_check_indicator(test: GdUnitTestSuite, tile_size: int = 16) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = test.auto_free(RuleCheckIndicator.new())
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(tile_size, tile_size)
	indicator.shape = rect_shape
	return indicator
