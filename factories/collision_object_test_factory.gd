class_name CollisionObjectTestFactory
extends RefCounted

## Collision Object Test Factory
## Provides reusable factory methods for creating collision objects in tests
## Eliminates duplicate setup code across test suites
##
## ## Related Factories:
## - **UnifiedTestFactory**: Main factory for comprehensive test environments
##   - Located at: test/grid_building_test/factories/unified_test_factory.gd
##   - Use for: Complete test environment setup, building systems, indicators
##   - Methods: create_utilities_test_environment(), create_building_system_test_environment(), etc.
##
## ## Usage:
## ```gdscript
## collision_body: Node = CollisionObjectTestFactory.create_static_body_with_diamond(self, Vector2(64, 32))
## var isometric_building = CollisionObjectTestFactory.create_isometric_blacksmith(self)
## ```

#region Constants

## Default collision layer for test objects
const DEFAULT_COLLISION_LAYER: int = 1

## Default collision mask for test objects
const DEFAULT_COLLISION_MASK: int = 1

## Demo blacksmith collision layer (used in demo scenes)
const DEMO_BLACKSMITH_COLLISION_LAYER: int = 2560

## Demo blacksmith collision mask (used in demo scenes)
const DEMO_BLACKSMITH_COLLISION_MASK: int = 1536

## Default test object size (32x32 pixels)
const DEFAULT_TEST_SIZE: Vector2 = Vector2(32, 32)

## Default circle radius for test objects
const DEFAULT_CIRCLE_RADIUS: float = 16.0

## Default capsule radius
const DEFAULT_CAPSULE_RADIUS: float = 16.0

## Default capsule height
const DEFAULT_CAPSULE_HEIGHT: float = 32.0

## Small circle radius for tests
const SMALL_CIRCLE_RADIUS: float = 12.0

## Diamond shape default dimensions
const DIAMOND_DEFAULT_WIDTH: float = 32.0
const DIAMOND_DEFAULT_HEIGHT: float = 32.0

## Trapezoid polygon points (relative coordinates)
static var TRAPEZOID_POLYGON_POINTS: PackedVector2Array = PackedVector2Array(
	[Vector2(-20, -10), Vector2(20, -10), Vector2(15, 10), Vector2(-15, 10)]
)

## Concave polygon points for testing complex shapes
static var CONCAVE_POLYGON_POINTS: PackedVector2Array = PackedVector2Array(
	[
		Vector2(-32, -16),
		Vector2(32, -16),
		Vector2(16, 0),
		Vector2(32, 16),
		Vector2(-32, 16),
		Vector2(-16, 0)
	]
)

#endregion


## Creates a StaticBody2D with a rectangular collision shape
static func create_static_body_with_rect(
	test_suite: GdUnitTestSuite, size: Vector2, position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_body.add_child(collision_shape)
	test_suite.auto_free(collision_shape)
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	collision_shape.position = position

	# Ensure collision layer matches the test mask
	collision_body.collision_layer = DEFAULT_COLLISION_LAYER

	return collision_body


## Creates a StaticBody2D with a circular collision shape
static func create_static_body_with_circle(
	test_suite: GdUnitTestSuite, radius: float, position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	collision_shape.position = position
	collision_body.add_child(collision_shape)

	# Ensure collision layer matches the test mask
	collision_body.collision_layer = DEFAULT_COLLISION_LAYER

	return collision_body


## Creates a StaticBody2D with an elliptical / capsule collision shape
static func create_static_body_with_capsule(
	test_suite: GdUnitTestSuite,
	radius: float = DEFAULT_CAPSULE_RADIUS,
	height: float = DEFAULT_CAPSULE_HEIGHT,
	position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision_shape.shape = capsule_shape
	collision_shape.position = position
	collision_body.add_child(collision_shape)

	# Ensure collision layer matches the test mask
	collision_body.collision_layer = DEFAULT_COLLISION_LAYER

	return collision_body


## Creates a StaticBody2D with a polygon collision shape
static func create_static_body_with_polygon(
	test_suite: GdUnitTestSuite,
	polygon_points: PackedVector2Array,
	position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = polygon_points
	collision_polygon.position = position
	collision_body.add_child(collision_polygon)

	# Ensure collision layer matches the test mask
	collision_body.collision_layer = DEFAULT_COLLISION_LAYER

	return collision_body


## Creates an Area2D with a polygon collision shape
static func create_area_with_polygon(
	test_suite: GdUnitTestSuite,
	polygon_points: PackedVector2Array,
	position: Vector2 = Vector2.ZERO
) -> Area2D:
	var area: Area2D = Area2D.new()
	test_suite.add_child(area)
	test_suite.auto_free(area)

	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = polygon_points
	collision_polygon.position = position
	area.add_child(collision_polygon)

	# Ensure collision layer matches the test mask
	area.collision_layer = DEFAULT_COLLISION_LAYER

	return area


## Creates a complex collision object with multiple shapes
static func create_complex_collision_object(
	test_suite: GdUnitTestSuite,
	rect_size: Vector2,
	circle_radius: float,
	circle_offset: Vector2 = Vector2(16, 0)
) -> StaticBody2D:
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

	# Ensure collision layer matches the test mask
	collision_body.collision_layer = DEFAULT_COLLISION_LAYER

	return collision_body


## Sets up collision mapper with test indicator and collision object setups
static func setup_collision_mapper_with_objects(
	test_suite: GdUnitTestSuite,
	test_env: CollisionTestEnvironment,
	collision_objects: Array[StaticBody2D],
	bounds: Vector2,
	_indicator_size: int = 16
) -> CollisionMapper:
	var collision_mapper: CollisionMapper = test_env.collision_mapper
	var indicator_manager: IndicatorManager = test_env.indicator_manager
	var test_indicator: RuleCheckIndicator = indicator_manager.get_or_create_testing_indicator(
		test_suite
	)

	var collision_object_test_setups: Array[CollisionTestSetup2D] = []
	for obj: StaticBody2D in collision_objects:
		var collision_setup: CollisionTestSetup2D = CollisionTestSetup2D.new(
			obj as CollisionObject2D, bounds
		)
		collision_object_test_setups.append(collision_setup)

	collision_mapper.setup(test_indicator, collision_object_test_setups)
	return collision_mapper  ## Gets collision tiles for objects with proper typing


static func get_collision_tiles_for_objects(
	collision_mapper: CollisionMapper,
	objects: Array[StaticBody2D],
	mask: int = DEFAULT_COLLISION_MASK
) -> Dictionary:
	# Can include CollisionObject2D, Area2D, etc. Should have a CollisionShape2D or CollisionPolygon2D attached.
	var collision_objects: Array[Node2D] = []
	for obj in objects:
		collision_objects.append(obj as Node2D)
	return collision_mapper.get_collision_tile_positions_with_mask(collision_objects, mask)


## Tests collision tile generation for an object at a specific position
static func check_collsion_tiles_at_position(
	test_suite: GdUnitTestSuite,
	test_env: Dictionary,
	collision_object: StaticBody2D,
	position: Vector2,
	expected_min_tiles: int = 1
) -> Dictionary:
	collision_object.global_position = position
	var collision_objects_typed: Array[CollisionObject2D] = [collision_object as CollisionObject2D]
	var collision_tiles: Dictionary = (
		test_env
		. collision_mapper
		. get_collision_tile_positions_with_mask(collision_objects_typed, DEFAULT_COLLISION_MASK)
	)

	(
		test_suite
		. assert_int(collision_tiles.size())
		. append_failure_message(
			(
				"Should generate at least %d collision tiles at position %s"
				% [expected_min_tiles, position]
			)
		)
		. is_greater_equal(expected_min_tiles)
	)

	return collision_tiles


## Creates an Area2D with a rectangular collision shape
static func create_area_with_rect(
	test_suite: GdUnitTestSuite, size: Vector2, position: Vector2 = Vector2.ZERO
) -> Area2D:
	var area: Area2D = Area2D.new()
	test_suite.add_child(area)
	test_suite.auto_free(area)

	area.collision_layer = DEFAULT_COLLISION_LAYER

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	collision_shape.position = position
	area.add_child(collision_shape)

	return area


## Creates an Area2D with a circular collision shape
static func create_area_with_circle(
	test_suite: GdUnitTestSuite, radius: float, position: Vector2 = Vector2.ZERO
) -> Area2D:
	var area: Area2D = Area2D.new()
	test_suite.add_child(area)
	test_suite.auto_free(area)

	area.collision_layer = DEFAULT_COLLISION_LAYER

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	collision_shape.position = position
	area.add_child(collision_shape)

	return area


## Creates an Area2D with circular collision shape and parents it to a positioner
static func create_area_with_circle_collision(
	test_suite: GdUnitTestSuite, positioner: Node2D, radius: float = SMALL_CIRCLE_RADIUS
) -> Area2D:
	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = radius
	shape.position = Vector2.ZERO  # Explicitly set position
	area.add_child(shape)
	positioner.add_child(area)
	test_suite.auto_free(area)

	return area


## Creates an Area2D with rectangular collision shape and parents it to a positioner
static func create_area_with_rect_collision(
	test_suite: GdUnitTestSuite, positioner: Node2D, size: Vector2 = DEFAULT_TEST_SIZE
) -> Area2D:
	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
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


## Creates a StaticBody2D with a diamond/rhombus collision shape (for isometric buildings)
static func create_static_body_with_diamond(
	test_suite: GdUnitTestSuite,
	width: float = DIAMOND_DEFAULT_WIDTH,
	height: float = DIAMOND_DEFAULT_HEIGHT,
	position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)

	# Create diamond-shaped polygon
	var half_width: float = width / 2.0
	var half_height: float = height / 2.0
	var diamond_points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0, -half_height),  # Top
			Vector2(half_width, 0),  # Right
			Vector2(0, half_height),  # Bottom
			Vector2(-half_width, 0)  # Left
		]
	)

	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = diamond_points
	collision_polygon.position = position
	collision_body.add_child(collision_polygon)

	return collision_body


## Creates an isometric blacksmith building with proper collision layers
static func create_isometric_blacksmith(
	test_suite: GdUnitTestSuite, position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var blacksmith: StaticBody2D = create_static_body_with_diamond(
		test_suite, DIAMOND_DEFAULT_WIDTH, DIAMOND_DEFAULT_HEIGHT, position
	)

	# Set blacksmith-specific collision layers (common demo values)
	blacksmith.collision_layer = DEMO_BLACKSMITH_COLLISION_LAYER
	blacksmith.collision_mask = DEMO_BLACKSMITH_COLLISION_MASK
	blacksmith.global_position = position

	return blacksmith


## Creates a building with custom collision layers and diamond shape
static func create_isometric_building_with_layers(
	test_suite: GdUnitTestSuite,
	collision_layer: int,
	collision_mask: int,
	width: float = DIAMOND_DEFAULT_WIDTH,
	height: float = DIAMOND_DEFAULT_HEIGHT,
	position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var building: StaticBody2D = create_static_body_with_diamond(test_suite, width, height)
	building.collision_layer = collision_layer
	building.collision_mask = collision_mask
	building.global_position = position

	return building


## Sets up a complete collision test environment with building, collision mapper, and indicator
static func setup_collision_test_environment(
	test_suite: GdUnitTestSuite, test_env: Dictionary, building: StaticBody2D
) -> Dictionary:
	# Set up collision mapper with test setup - create directly instead of circular call
	var test_setup: CollisionTestSetup2D = CollisionTestSetup2D.new(
		building as CollisionObject2D, Vector2(32, 32)
	)
	test_suite.auto_free(test_setup)
	test_env.collision_mapper.collision_object_test_setups[building] = test_setup

	# Create indicator manager directly
	var indicator_manager: IndicatorManager = IndicatorManager.new()
	test_suite.add_child(indicator_manager)
	test_suite.auto_free(indicator_manager)

	return {
		"building": building,
		"collision_mapper": test_env.collision_mapper,
		"indicator_manager": indicator_manager,
		"test_setup": test_setup
	}


## Tests collision generation for a building with rotation
static func check_collision_generation_with_rotation(
	test_suite: GdUnitTestSuite,
	building: StaticBody2D,
	collision_mapper: CollisionMapper,
	rotation_angles: Array = [0.0, PI / 4, PI / 2, PI]
) -> void:
	for angle: float in rotation_angles:
		building.rotation = angle

		# Test collision mapping with rotation
		var collision_tiles: Dictionary = collision_mapper.get_collision_tile_positions_with_mask(
			[building], building.collision_layer
		)
		(
			test_suite
			. assert_array(collision_tiles.keys())
			. append_failure_message(
				"Should generate collision tiles at rotation %s degrees" % [rad_to_deg(angle)]
			)
			. is_not_empty()
		)


## Creates a test object with collision shape based on shape type
## Used by collision mapper tests to create various collision objects
static func create_test_object_with_shape(
	test_suite: GdUnitTestSuite, shape_type: String, position: Vector2 = Vector2.ZERO
) -> StaticBody2D:
	var collision_body: StaticBody2D = StaticBody2D.new()
	test_suite.add_child(collision_body)
	test_suite.auto_free(collision_body)
	collision_body.global_position = position

	if shape_type == "rectangle":
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = DEFAULT_TEST_SIZE
		collision_shape.shape = rect_shape
		collision_body.add_child(collision_shape)
	elif shape_type == "circle":
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var circle_shape: CircleShape2D = CircleShape2D.new()
		circle_shape.radius = DEFAULT_CIRCLE_RADIUS
		collision_shape.shape = circle_shape
		collision_body.add_child(collision_shape)
	elif shape_type == "capsule":
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
		capsule_shape.radius = DEFAULT_CAPSULE_RADIUS
		capsule_shape.height = DEFAULT_CAPSULE_HEIGHT
		collision_shape.shape = capsule_shape
		collision_body.add_child(collision_shape)
	elif shape_type == "trapezoid":
		var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
		collision_polygon.polygon = TRAPEZOID_POLYGON_POINTS
		collision_body.add_child(collision_polygon)
	else:
		test_suite.fail("Unknown shape type: %s" % shape_type)

	return collision_body


## Creates a polygon test object for testing indicator behavior
static func create_polygon_test_object(test_suite: GdUnitTestSuite, parent: Node) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "PolygonTestObject"
	parent.add_child(body)
	test_suite.auto_free(body)

	# Define a concave polygon for testing
	var points: PackedVector2Array = CONCAVE_POLYGON_POINTS

	# Create the polygon shape
	var polygon := CollisionPolygon2D.new()
	polygon.name = "CollisionPolygon2D"
	polygon.polygon = points
	body.add_child(polygon)

	# Set collision properties on the body, not the shape
	body.collision_layer = 1  # Set collision layer for detection
	body.collision_mask = 1  # Set collision mask for detection

	# Debug: print children of the created object for test diagnostics
	var child_list := []
	for child: Node in body.get_children():
		child_list.append(str(child.get_class()) + ":" + str(child.name))
	# Also print owner info for each child for debugging pack inclusion
	var owner_info := []
	for child: Node in body.get_children():
		owner_info.append(
			str(child.name) + "->owner=" + (str(child.owner) if child.owner != null else "null")
		)
	print(
		(
			"create_polygon_test_object: created obj with children=%s owners=%s"
			% [str(child_list), str(owner_info)]
		)
	)

	return body


static func instance_placeable(
	p_test: GdUnitTestSuite, p_placeable: Placeable, p_parent: Node
) -> Node2D:
	var root: Node2D = p_placeable.packed_scene.instantiate()
	p_test.auto_free(root)
	p_parent.add_child(root)
	return root
