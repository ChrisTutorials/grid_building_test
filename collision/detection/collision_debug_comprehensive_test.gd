extends GdUnitTestSuite

## Comprehensive debug test suite combining collision detection, shape detection,
## and PackedScene debugging
## Consolidates debug_shape_detection_test.gd, packed_scene_debug_test.gd,
## and related debugging functionality

# Test constants
const DEFAULT_RECT_SIZE: Vector2 = Vector2(32, 32)
const DEFAULT_CIRCLE_RADIUS: float = 16.0
const DEFAULT_CAPSULE_HEIGHT: float = 32.0
const TEST_COLLISION_LAYER_RIGID: int = 513
const TEST_COLLISION_LAYER_STATIC: int = 1
const TEST_COLLISION_LAYER_AREA: int = 2560
const TEST_COLLISION_LAYER_CHARACTER: int = 1

# Test data structures (initialized in _init or before_test)
var collision_object_test_cases: Array[Array]
var packed_scene_test_cases: Array[Array]
var polygon_test_cases: Array[Dictionary]

func _init() -> void:
	collision_object_test_cases = [
		["RigidBody2D", TEST_COLLISION_LAYER_RIGID, "RectangleShape2D", Vector2(16, 16), 1],
		["StaticBody2D", TEST_COLLISION_LAYER_STATIC, "RectangleShape2D", DEFAULT_RECT_SIZE, 1],
		["Area2D", TEST_COLLISION_LAYER_AREA, "CircleShape2D", Vector2(24, 24), 1],
		["CharacterBody2D", TEST_COLLISION_LAYER_CHARACTER, "CapsuleShape2D", Vector2(16, 32), 1]
	]

	packed_scene_test_cases = [
		["RigidBody2D", TEST_COLLISION_LAYER_RIGID],
		["StaticBody2D", TEST_COLLISION_LAYER_STATIC],
		["Area2D", TEST_COLLISION_LAYER_AREA]
	]

	polygon_test_cases = [
		{
			"name": "Single Point",
			"points": PackedVector2Array([Vector2(8, 8)]),
			"expected_valid": false
		},
		{
			"name": "Two Points (Line)",
			"points": PackedVector2Array([Vector2(0, 0), Vector2(16, 16)]),
			"expected_valid": false
		},
		{
			"name": "Minimal Triangle",
			"points": PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(4, 4)]),
			"expected_valid": true
		},
		{
			"name": "Degenerate Rectangle",
			"points": PackedVector2Array([Vector2(0, 0), Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)]),
			"expected_valid": false
		}
	]

func test_collision_object_debug_scenarios() -> void:
	for test_case: Array in collision_object_test_cases:
		var object_type: String = test_case[0]
		var collision_layer: int = test_case[1]
		var shape_type: String = test_case[2]
		var shape_size: Vector2 = test_case[3]
		var expected_shape_count: int = test_case[4]

		_test_single_collision_object_scenario(
			object_type, collision_layer, shape_type, shape_size, expected_shape_count
		)

func _test_single_collision_object_scenario(
	object_type: String,
	collision_layer: int,
	shape_type: String,
	shape_size: Vector2,
	expected_shape_count: int
) -> void:
	GBTestDiagnostics.buffer("=== DEBUG COLLISION OBJECT: %s ===" % object_type)

	# Create collision object based on type
	var collision_obj: CollisionObject2D = _create_collision_object(object_type, collision_layer)
	add_child(collision_obj)

	# Create collision shape based on type
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	collision_shape.name = "TestCollisionShape"

	var shape: Shape2D = _create_shape(shape_type, shape_size)
	collision_shape.shape = shape
	collision_obj.add_child(collision_shape)

	# Debug output
	GBTestDiagnostics.buffer(
		"1. %s.collision_layer: %d" % [object_type, collision_obj.collision_layer]
	)
	GBTestDiagnostics.buffer("2. %s.name: %s" % [object_type, collision_obj.name])
	GBTestDiagnostics.buffer("3. CollisionShape2D.name: %s" % collision_shape.name)
	GBTestDiagnostics.buffer("4. CollisionShape2D.shape: %s" % collision_shape.shape)
	GBTestDiagnostics.buffer("5. %s.get_shape_owners(): %s" % [
		object_type, collision_obj.get_shape_owners()
	])

	# Test shape detection utilities
	var shapes_from_owner: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(collision_obj)
	GBTestDiagnostics.buffer("6. get_shapes_from_owner result: %d shapes" % shapes_from_owner.size())

	var all_shapes: Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(
		collision_obj
	)
	GBTestDiagnostics.buffer(
		"7. get_all_collision_shapes_by_owner result: %d owners" % all_shapes.size()
	)

	# Assertions
	assert_int(shapes_from_owner.size()).append_failure_message(
		"Expected %d shapes from %s, got %d" % [
			expected_shape_count, object_type, shapes_from_owner.size()
		]
	).is_equal(expected_shape_count)

	assert_int(all_shapes.size()).append_failure_message(
		"Expected at least 1 collision owner for %s" % object_type
	).is_greater(0)

func _create_collision_object(object_type: String, collision_layer: int) -> CollisionObject2D:
	var collision_obj: CollisionObject2D
	match object_type:
		"RigidBody2D":
			collision_obj = auto_free(RigidBody2D.new())
		"StaticBody2D":
			collision_obj = auto_free(StaticBody2D.new())
		"Area2D":
			collision_obj = auto_free(Area2D.new())
		"CharacterBody2D":
			collision_obj = auto_free(CharacterBody2D.new())
		_:
			assert_that(object_type).append_failure_message("Unknown collision object type").is_equal("")
			return null

	collision_obj.name = "Test%s" % object_type
	collision_obj.collision_layer = collision_layer
	return collision_obj

func _create_shape(shape_type: String, shape_size: Vector2) -> Shape2D:
	var shape: Shape2D
	match shape_type:
		"RectangleShape2D":
			var rect_shape: RectangleShape2D = RectangleShape2D.new()
			rect_shape.size = shape_size
			shape = rect_shape
		"CircleShape2D":
			var circle_shape: CircleShape2D = CircleShape2D.new()
			circle_shape.radius = shape_size.x
			shape = circle_shape
		"CapsuleShape2D":
			var capsule_shape: CapsuleShape2D = CapsuleShape2D.new()
			capsule_shape.radius = shape_size.x
			capsule_shape.height = shape_size.y
			shape = capsule_shape
		_:
			assert_that(shape_type).append_failure_message("Unknown shape type").is_equal("")
			return null
	return shape

func test_packed_scene_collision_debug_scenarios() -> void:
	for test_case: Array in packed_scene_test_cases:
		var object_type: String = test_case[0]
		var collision_layer: int = test_case[1]

		_test_single_packed_scene_scenario(object_type, collision_layer)

func _test_single_packed_scene_scenario(object_type: String, collision_layer: int) -> void:
	GBTestDiagnostics.buffer("=== DEBUG PACKED SCENE: %s ===" % object_type)

	# Create original collision object (NO auto_free for PackedScene nodes)
	var original_obj: CollisionObject2D = _create_collision_object_for_packed_scene(
		object_type, collision_layer
	)
	add_child(original_obj)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()  # NO auto_free for PackedScene
	collision_shape.name = "OriginalCollisionShape"
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = DEFAULT_RECT_SIZE
	collision_shape.shape = rect_shape
	original_obj.add_child(collision_shape)

	# CRITICAL: Set owner for PackedScene to include children
	collision_shape.owner = original_obj

	GBTestDiagnostics.buffer(
		"1. Original %s children: %d" % [object_type, original_obj.get_child_count()]
	)
	if original_obj.get_child_count() > 0:
		var child: Node = original_obj.get_children()[0]
		GBTestDiagnostics.buffer("1a. First child name: %s" % child.name)
		GBTestDiagnostics.buffer("1b. First child type: %s" % child.get_class())

	GBTestDiagnostics.buffer(
		"2. Original %s shape_owners: %s" % [object_type, original_obj.get_shape_owners()]
	)
	var original_shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(original_obj)
	GBTestDiagnostics.buffer("3. Original shapes: %d" % original_shapes.size())

	# Create PackedScene and verify packing
	var scene: PackedScene = PackedScene.new()
	var pack_result: int = scene.pack(original_obj)
	GBTestDiagnostics.buffer("4. PackedScene.pack() result: %s" % pack_result)

	var state: SceneState = scene.get_state()
	GBTestDiagnostics.buffer("5. Packed scene node count: %d" % state.get_node_count())
	for i in range(state.get_node_count()):
		GBTestDiagnostics.buffer(
			"5a. Node %d: %s (type: %s)" % [i, state.get_node_name(i), state.get_node_type(i)]
		)

	# Instantiate and test
	var preview_obj: CollisionObject2D = scene.instantiate() as CollisionObject2D
	add_child(preview_obj)

	GBTestDiagnostics.buffer(
		"6. Preview %s children: %d" % [object_type, preview_obj.get_child_count()]
	)
	var preview_shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(preview_obj)
	GBTestDiagnostics.buffer("7. Preview shapes: %d" % preview_shapes.size())

	# Assertions
	assert_int(pack_result).append_failure_message("PackedScene.pack() failed").is_equal(OK)
	assert_int(state.get_node_count()).append_failure_message(
		"Expected at least 2 nodes in packed scene"
	).is_greater_equal(2)
	assert_int(preview_obj.get_child_count()).append_failure_message(
		"Preview should have children"
	).is_greater(0)

func _create_collision_object_for_packed_scene(
	object_type: String, collision_layer: int
) -> CollisionObject2D:
	var collision_obj: CollisionObject2D
	match object_type:
		"RigidBody2D":
			collision_obj = RigidBody2D.new()
		"StaticBody2D":
			collision_obj = StaticBody2D.new()
		"Area2D":
			collision_obj = Area2D.new()
		_:
			assert_that(object_type).append_failure_message("Unknown collision object type").is_equal("")
			return null

	collision_obj.name = "Original%s" % object_type
	collision_obj.collision_layer = collision_layer
	return collision_obj

## Test polygon shape conversion and collision detection edge cases
func test_polygon_collision_edge_cases() -> void:
	var diagnostic_messages: Array[String] = []
	diagnostic_messages.append("=== DEBUG POLYGON COLLISION EDGE CASES ===")

	for test_case: Dictionary in polygon_test_cases:
		diagnostic_messages.append("--- Testing: %s ---" % test_case.name)
		var points: PackedVector2Array = test_case.points as PackedVector2Array
		var expected_valid: bool = test_case.expected_valid as bool

		diagnostic_messages.append("Input points: %s" % points)

		# Test bounds calculation
		var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(points)
		diagnostic_messages.append("Polygon bounds: %s" % bounds)

		# Test if polygon is considered valid (using points.size() >= 3)
		var is_valid: bool = points.size() >= 3 and CollisionGeometryCalculator.polygon_area(
			points
		) > 0.001
		diagnostic_messages.append("Is valid polygon: %s" % is_valid)

		# Test area calculation if valid
		if is_valid:
			var area: float = CollisionGeometryCalculator.polygon_area(points)
			diagnostic_messages.append("Polygon area: %f" % area)

		assert_bool(is_valid).append_failure_message(
			"Polygon validity mismatch for %s: expected %s, got %s" % [
				test_case.name, expected_valid, is_valid
			] + "\n" + "\n".join(diagnostic_messages)
		).is_equal(expected_valid)
