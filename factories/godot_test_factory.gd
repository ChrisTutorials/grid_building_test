## Factory for creating Godot base class objects in tests.
## Provides convenient methods for common Godot objects used in testing.
## Keep this separate from UnifiedTestFactory to maintain clean separation.
class_name GodotTestFactory
extends RefCounted

#region Collision Validation Helpers
## Validates that a collision shape has a proper CollisionObject2D parent
## @param collision_node: The CollisionShape2D or CollisionPolygon2D to validate
## @param method_name: Name of the calling method for error messages
static func _validate_collision_parent(collision_node: Node, method_name: String) -> void:
	assert(collision_node != null, "%s: collision_node cannot be null" % method_name)
	
	var parent: Node = collision_node.get_parent()
	assert(parent != null, "%s: Collision node must have a parent" % method_name)
	assert(parent is CollisionObject2D, "%s: Collision shapes must be children of CollisionObject2D (StaticBody2D, RigidBody2D, CharacterBody2D, or Area2D). Found parent type: %s" % [method_name, parent.get_class()])

## Ensures a collision shape is properly parented to a CollisionObject2D
## @param collision_node: The CollisionShape2D or CollisionPolygon2D to parent
## @param parent: The CollisionObject2D to parent to
## @param test: Test suite for auto_free management
## @param method_name: Name of the calling method for error messages
static func _ensure_collision_parent(collision_node: Node, parent: CollisionObject2D, test: GdUnitTestSuite, method_name: String) -> void:
	assert(collision_node != null, "%s: collision_node cannot be null" % method_name)
	assert(parent != null, "%s: parent cannot be null" % method_name)
	assert(parent is CollisionObject2D, "%s: Parent must be a CollisionObject2D (StaticBody2D, RigidBody2D, CharacterBody2D, or Area2D). Found type: %s" % [method_name, parent.get_class()])
	
	# If collision_node is already in the scene tree, remove it
	if collision_node.get_parent() != null:
		collision_node.get_parent().remove_child(collision_node)
	
	# Add to the proper parent
	parent.add_child(collision_node)
	
	# Ensure parent is auto-freed and in test scene
	if parent.get_parent() == null:
		test.add_child(parent)

#endregion
#region Capsule and Transform Factories

## Creates a CapsuleShape2D with specified radius and height
static func create_capsule_shape(radius: float = 48.0, height: float = 128.0) -> CapsuleShape2D:
	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = height
	return capsule


## Creates a Transform2D at the given origin (default Vector2.ZERO)
static func create_transform2d(origin: Vector2 = Vector2.ZERO) -> Transform2D:
	var transform := Transform2D()
	transform.origin = origin
	return transform


## Creates standard tile size Vector2 (16, 16) commonly used in tests
static func create_tile_size(size: int = 16) -> Vector2:
	return Vector2(size, size)

#endregion
#region Node Creation

## Creates a basic Node2D for testing with proper auto_free setup
static func create_node2d(test: GdUnitTestSuite, p_name : String = "TestNode2D") -> Node2D:
	var node: Node2D = test.auto_free(Node2D.new())
	node.name = p_name
	test.add_child(node)
	return node as Node2D

## Creates a Node with auto_free setup
static func create_node(test: GdUnitTestSuite) -> Node:
	var node: Node = test.auto_free(Node.new())
	node.name = "TestNode"
	test.add_child(node)
	return node

## Creates a CanvasItem with auto_free setup
static func create_canvas_item(test: GdUnitTestSuite) -> CanvasItem:
	var item: CanvasItem = test.auto_free(Node2D.new())  # Use Node2D as concrete CanvasItem
	item.name = "TestCanvasItem"
	test.add_child(item)
	return item

#endregion
#region TileMap Objects

## Creates a TileMapLayer with basic tile set and populated grid for testing.
## grid_size: overall width/height in tiles (square). Reduced default for faster unit tests.
## Tiles are created starting from the top-left corner (0,0) and fill down and to the right,
## so all used tiles are in the bottom right grid quadrant, covering (0,0) to (grid_size-1, grid_size-1).
static func create_tile_map_layer(test: GdUnitTestSuite, grid_size: int = 40) -> TileMapLayer:
	# Reverted: create a programmatic square TileMapLayer to preserve previous behavior
	# Delegate to create_tile_map_layer_with_shape which builds a populated tileset grid
	var map_layer: TileMapLayer = create_tile_map_layer_with_shape(test, grid_size, TileSet.TILE_SHAPE_SQUARE)
	# Ensure test owns the node for teardown
	if map_layer.get_parent() == null:
		test.add_child(map_layer)
	return map_layer

## Creates a TileMapLayer with specified tile shape (square, isometric, or half-offset)
static func create_tile_map_layer_with_shape(
	test: GdUnitTestSuite, 
	grid_size: int = 40, 
	tile_shape: TileSet.TileShape = TileSet.TILE_SHAPE_SQUARE
) -> TileMapLayer:
	var map_layer: TileMapLayer = test.auto_free(TileMapLayer.new())
	var tile_set := TileSet.new()
	tile_set.tile_shape = tile_shape
	tile_set.tile_size = Vector2i(16, 16)
	
	var atlas := TileSetAtlasSource.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	atlas.texture = tex
	atlas.create_tile(Vector2i(0,0))
	tile_set.add_source(atlas)
	map_layer.tile_set = tile_set

	# Use the new helper to populate cells
	populate_tilemap_cells(map_layer, Rect2i(0, 0, grid_size, grid_size), 0, Vector2i(0, 0))

	# If fallback tileset was needed, repopulate all cells after assigning new tileset
	if map_layer.get_cell_tile_data(Vector2i.ZERO) == null:
		var ts := TileSet.new()
		ts.tile_shape = tile_shape
		ts.tile_size = Vector2i(16, 16)
		var atlas2 := TileSetAtlasSource.new()
		var img2 := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img2.fill(Color.BLUE)
		var tex2 := ImageTexture.create_from_image(img2)
		atlas2.texture = tex2
		atlas2.create_tile(Vector2i(0,0))
		ts.add_source(atlas2)
		map_layer.tile_set = ts
		map_layer.clear()
		# Use helper for fallback population too
		populate_tilemap_cells(map_layer, Rect2i(0, 0, grid_size, grid_size), 0, Vector2i(0, 0))

	var actual_populated_cells := map_layer.get_used_cells().size()
	assert(actual_populated_cells == (grid_size * grid_size), "Expected: %s Actual: %s" % [grid_size * grid_size, actual_populated_cells])
	var map_size_px : Vector2 = map_layer.get_used_rect().size * map_layer.tile_set.tile_size
	test.assert_vector(map_size_px).append_failure_message("GodotTestFactory Math Incorrect").is_equal(Vector2(grid_size * 16, grid_size * 16))
	
	test.add_child(map_layer)
	return map_layer as TileMapLayer


## Creates an isometric TileMapLayer for isometric tile-based games
static func create_isometric_tile_map_layer(test: GdUnitTestSuite, grid_size: int = 40) -> TileMapLayer:
	return create_tile_map_layer_with_shape(test, grid_size, TileSet.TILE_SHAPE_ISOMETRIC)


## Creates a top-down TileMapLayer for top-down perspective games
static func create_top_down_tile_map_layer(test: GdUnitTestSuite, grid_size: int = 40) -> TileMapLayer:
	return create_tile_map_layer_with_shape(test, grid_size, TileSet.TILE_SHAPE_SQUARE)


## Creates a platformer TileMapLayer for side-scrolling platformer games
static func create_platformer_tile_map_layer(test: GdUnitTestSuite, grid_size: int = 40) -> TileMapLayer:
	return create_tile_map_layer_with_shape(test, grid_size, TileSet.TILE_SHAPE_SQUARE)


## Creates an empty TileMapLayer with tile set but no cells
static func create_empty_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	var map_layer: TileMapLayer = test.auto_free(TileMapLayer.new())
	var tile_set := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	atlas.texture = tex
	atlas.create_tile(Vector2i(0,0))
	tile_set.add_source(atlas)
	map_layer.tile_set = tile_set
	test.add_child(map_layer)
	return map_layer as TileMapLayer


## Populates a TileMapLayer with cells in the specified rectangular region
## @param tilemap: The TileMapLayer to populate
## @param rect: The rectangular region to fill (position and size in tile coordinates)
## @param tile_id: The tile source ID to use (default: 0)
## @param atlas_coords: The atlas coordinates to use (default: Vector2i(0, 0))
static func populate_tilemap_cells(
	tilemap: TileMapLayer,
	rect: Rect2i,
	tile_id: int = 0,
	atlas_coords: Vector2i = Vector2i(0, 0)
) -> void:
	assert(tilemap != null, "populate_tilemap_cells: tilemap cannot be null")
	assert(tilemap.tile_set != null, "populate_tilemap_cells: tilemap must have a tile_set assigned")
	
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			tilemap.set_cell(Vector2i(x, y), tile_id, atlas_coords)


## Creates a TileMapLayer pre-populated with cells in the specified region
## @param test: The test suite for auto_free management
## @param rect: The rectangular region to fill (position and size in tile coordinates)
## @param tile_id: The tile source ID to use (default: 0)
## @param atlas_coords: The atlas coordinates to use (default: Vector2i(0, 0))
## @return: A TileMapLayer with cells already populated
static func create_populated_tile_map_layer(
	test: GdUnitTestSuite,
	rect: Rect2i = Rect2i(0, 0, 50, 50),
	tile_id: int = 0,
	atlas_coords: Vector2i = Vector2i(0, 0)
) -> TileMapLayer:
	var map_layer: TileMapLayer = create_empty_tile_map_layer(test)
	populate_tilemap_cells(map_layer, rect, tile_id, atlas_coords)
	return map_layer


#endregion
#region Collision Objects


## Creates a StaticBody2D with rectangular collision shape
static func create_static_body_with_rect_shape(
	test: GdUnitTestSuite, extents: Vector2 = Vector2(16, 16)
) -> StaticBody2D:
	var body: StaticBody2D = test.auto_free(StaticBody2D.new())
	var shape: CollisionShape2D = test.auto_free(CollisionShape2D.new())
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = extents * 2  # Convert extents to size (extents is half-size)
	shape.shape = rect
	test.add_child(body)
	body.add_child(shape)
	body.collision_layer = 1  # Set collision layer to match test expectations
	test.assert_object(shape.shape).append_failure_message("GodotTestFactory: Bad Generated Shape").is_not_null()
	
	# Validate collision hierarchy
	_validate_collision_parent(shape, "create_static_body_with_rect_shape")
	
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
	
	# Validate collision hierarchy
	_validate_collision_parent(shape, "create_area2d_with_circle_shape")
	
	return area


## Creates a CollisionPolygon2D with triangle shape
## @param test: Test suite for auto_free management  
## @param polygon: Optional polygon points (defaults to triangle)
## @param parent: Optional CollisionObject2D parent for proper collision hierarchy
static func create_collision_polygon(
	test: GdUnitTestSuite, 
	polygon: PackedVector2Array = PackedVector2Array(),
	parent: CollisionObject2D = null
) -> CollisionPolygon2D:
	var poly: CollisionPolygon2D = test.auto_free(CollisionPolygon2D.new())
	if polygon.is_empty():
		# Default triangle
		poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)])
	else:
		poly.polygon = polygon
	
	if parent != null:
		_ensure_collision_parent(poly, parent, test, "create_collision_polygon")
	else:
		# Add to test by default but validate later if parent changes
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
	
	# Validate collision hierarchy
	_validate_collision_parent(collision_shape, "create_object_with_circle_shape")
	
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
	rect.size = size
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
static func create_manipulatable(
	test: GdUnitTestSuite, root_name: String = "ManipulatableRoot"
) -> Manipulatable:
	var root: Node2D = test.auto_free(Node2D.new())
	test.add_child(root)
	var manipulatable: Manipulatable = test.auto_free(Manipulatable.new())
	manipulatable.root = root
	root.add_child(manipulatable)
	root.name = root_name
	manipulatable.name = "Manipulatable"
	return manipulatable


## (Removed) RuleCheckIndicator factory relocated
## This factory only handles Godot base class objects. Grid-building specific
## factories such as RuleCheckIndicator are provided by UnifiedTestFactory.
