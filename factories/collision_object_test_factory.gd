extends GdUnitTestSuite

## Collision Object Test Factory
## Provides reusable factory methods for creating collision objects in tests
## Eliminates duplicate setup code across test suites

class_name CollisionObjectTestFactory

## Creates a StaticBody2D with a rectangular collision shape
static func create_static_body_with_rect(test_suite: GdUnitTestSuite, size: Vector2, position: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	collision_shape.position = position
	collision_body.add_child(collision_shape)

	return collision_body

## Creates a StaticBody2D with a circular collision shape
static func create_static_body_with_circle(test_suite: GdUnitTestSuite, radius: float, position: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	collision_shape.position = position
	collision_body.add_child(collision_shape)

	return collision_body

## Creates a StaticBody2D with a polygon collision shape
static func create_static_body_with_polygon(test_suite: GdUnitTestSuite, polygon_points: PackedVector2Array, position: Vector2 = Vector2.ZERO) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = polygon_points
	collision_polygon.position = position
	collision_body.add_child(collision_polygon)

	return collision_body

## Creates a complex collision object with multiple shapes
static func create_complex_collision_object(test_suite: GdUnitTestSuite, rect_size: Vector2, circle_radius: float, circle_offset: Vector2 = Vector2(20, 20)) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	# Add rectangular collision shape
	var rect_collision: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = rect_size
	rect_collision.shape = rect_shape
	rect_collision.position = Vector2.ZERO
	collision_body.add_child(rect_collision)

	# Add circular collision shape
	var circle_collision: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = circle_radius
	circle_collision.shape = circle_shape
	circle_collision.position = circle_offset
	collision_body.add_child(circle_collision)

	return collision_body

## Sets up collision mapper with test indicator and collision object setups
static func setup_collision_mapper_with_objects(
	test_suite: GdUnitTestSuite,
	test_env: Dictionary,
	collision_objects: Array[StaticBody2D],
	bounds: Vector2,
	indicator_size: int = 16
) -> CollisionMapper:
	var collision_mapper: CollisionMapper = test_env.collision_mapper
	var test_indicator = UnifiedTestFactory.create_test_indicator_rect(test_suite, indicator_size)

	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for obj in collision_objects:
		var collision_setup = IndicatorCollisionTestSetup.new(obj as CollisionObject2D, bounds, test_env.logger)
		collision_object_test_setups[obj] = collision_setup

	collision_mapper.setup(test_indicator, collision_object_test_setups)
	return collision_mapper

## Gets collision tiles for objects with proper typing
static func get_collision_tiles_for_objects(
	collision_mapper: CollisionMapper,
	objects: Array[StaticBody2D],
	mask: int = 1
) -> Dictionary:
    # Can include CollisionObject2D, Area2D, etc. Should have a CollisionShape2D or CollisionPolygon2D attached.
	var collision_objects: Array[Node2D] = []
	for obj in objects:
		collision_objects.append(obj as Node2D)
	return collision_mapper.get_collision_tile_positions_with_mask(collision_objects, mask)

## Tests collision tile generation for an object at a specific position
static func test_collision_tiles_at_position(
	test_suite: GdUnitTestSuite,
	test_env: Dictionary,
	collision_object: StaticBody2D,
	position: Vector2,
	expected_min_tiles: int = 1
) -> Dictionary:
	collision_object.global_position = position
	var collision_objects_typed: Array[CollisionObject2D] = [collision_object as CollisionObject2D]
	var collision_tiles = test_env.collision_mapper.get_collision_tile_positions_with_mask(collision_objects_typed, 1)

	test_suite.assert_int(collision_tiles.size()).append_failure_message(
		"Should generate at least %d collision tiles at position %s" % [expected_min_tiles, position]
	).is_greater_equal(expected_min_tiles)

	return collision_tiles

## Creates an Area2D with a rectangular collision shape
static func create_area_with_rect(test_suite: GdUnitTestSuite, size: Vector2, position: Vector2 = Vector2.ZERO) -> Area2D:
	var area: Area2D = Area2D.new()
	test_suite.add_child(area)
	test_suite.auto_free(area)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	collision_shape.position = position
	area.add_child(collision_shape)

	return area

## Creates an Area2D with a circular collision shape
static func create_area_with_circle(test_suite: GdUnitTestSuite, radius: float, position: Vector2 = Vector2.ZERO) -> Area2D:
	var area: Area2D = Area2D.new()
	test_suite.add_child(area)
	test_suite.auto_free(area)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	collision_shape.position = position
	area.add_child(collision_shape)

	return area

## Creates an Area2D with circular collision shape and parents it to a positioner
static func create_area_with_circle_collision(
	test_suite: GdUnitTestSuite,
	positioner: Node2D,
	radius: float = 12.0
) -> Area2D:
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = radius
	shape.position = Vector2.ZERO  # Explicitly set position
	area.add_child(shape)
	positioner.add_child(area)
	test_suite.auto_free(area)

	return area

## Creates an Area2D with rectangular collision shape and parents it to a positioner
static func create_area_with_rect_collision(
	test_suite: GdUnitTestSuite,
	positioner: Node2D,
	size: Vector2 = Vector2(32, 32)
) -> Area2D:
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	shape.position = Vector2.ZERO  # Explicitly set position
	area.add_child(shape)
	positioner.add_child(area)
	test_suite.auto_free(area)

	# Assert that collision shape is properly parented to positioner
	test_suite.assert_that(area.get_parent()).is_equal(positioner)
	test_suite.assert_that(shape.get_parent()).is_equal(area)
	test_suite.assert_that(positioner.get_children()).contains(area)

	return area
