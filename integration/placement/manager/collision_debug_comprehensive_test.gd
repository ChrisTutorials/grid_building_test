extends GdUnitTestSuite

## Comprehensive debug test suite combining collision detection, shape detection, and PackedScene debugging
## Consolidates debug_shape_detection_test.gd, packed_scene_debug_test.gd, and related debugging functionality

@warning_ignore("unused_parameter")
func test_collision_object_debug_scenarios(
	object_type: String,
	collision_layer: int,
	shape_type: String,
	shape_size: Vector2,
	expected_shape_count: int,
	test_parameters := [
		["RigidBody2D", 513, "RectangleShape2D", Vector2(16, 16), 1],
		["StaticBody2D", 1, "RectangleShape2D", Vector2(32, 32), 1],
		["Area2D", 2560, "CircleShape2D", Vector2(24, 24), 1],
		["CharacterBody2D", 1, "CapsuleShape2D", Vector2(16, 32), 1]
	]
):
	print("=== DEBUG COLLISION OBJECT: %s ===" % object_type)
	
	# Create collision object based on type
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
			return
	
	collision_obj.name = "Test%s" % object_type
	collision_obj.collision_layer = collision_layer
	add_child(collision_obj)
	
	# Create collision shape based on type
	collision_shape: Node = auto_free(CollisionShape2D.new())
	collision_shape.name = "TestCollisionShape"
	
	var shape: Shape2D
	match shape_type:
		"RectangleShape2D":
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = shape_size
			shape = rect_shape
		"CircleShape2D":
			var circle_shape = CircleShape2D.new()
			circle_shape.radius = shape_size.x
			shape = circle_shape
		"CapsuleShape2D":
			var capsule_shape = CapsuleShape2D.new()
			capsule_shape.radius = shape_size.x
			capsule_shape.height = shape_size.y
			shape = capsule_shape
		_:
			assert_that(shape_type).append_failure_message("Unknown shape type").is_equal("")
			return
	
	collision_shape.shape = shape
	collision_obj.add_child(collision_shape)
	
	# Debug output
	print("1. %s.collision_layer: %d" % [object_type, collision_obj.collision_layer])
	print("2. %s.name: %s" % [object_type, collision_obj.name])
	print("3. CollisionShape2D.name: %s" % collision_shape.name)
	print("4. CollisionShape2D.shape: %s" % collision_shape.shape)
	print("5. %s.get_shape_owners(): %s" % [object_type, collision_obj.get_shape_owners()])
	
	# Test shape detection utilities
	var shapes_from_owner = GBGeometryUtils.get_shapes_from_owner(collision_obj)
	print("6. get_shapes_from_owner result: %d shapes" % shapes_from_owner.size())
	
	var all_shapes = GBGeometryUtils.get_all_collision_shapes_by_owner(collision_obj)
	print("7. get_all_collision_shapes_by_owner result: %d owners" % all_shapes.size())
	
	# Assertions
	assert_int(shapes_from_owner.size()).append_failure_message(
		"Expected %d shapes from %s, got %d" % [expected_shape_count, object_type, shapes_from_owner.size()]
	).is_equal(expected_shape_count)
	
	assert_int(all_shapes.size()).append_failure_message(
		"Expected at least 1 collision owner for %s" % object_type
	).is_greater(0)

@warning_ignore("unused_parameter") 
func test_packed_scene_collision_debug_scenarios(
	object_type: String,
	collision_layer: int,
	test_parameters := [
		["RigidBody2D", 513],
		["StaticBody2D", 1],
		["Area2D", 2560]
	]
):
	print("=== DEBUG PACKED SCENE: %s ===" % object_type)
	
	# Create original collision object (NO auto_free for PackedScene nodes)
	var original_obj: CollisionObject2D
	match object_type:
		"RigidBody2D":
			original_obj = RigidBody2D.new()
		"StaticBody2D":
			original_obj = StaticBody2D.new()
		"Area2D":
			original_obj = Area2D.new()
		_:
			assert_that(object_type).append_failure_message("Unknown collision object type").is_equal("")
			return
	
	original_obj.name = "Original%s" % object_type
	original_obj.collision_layer = collision_layer
	add_child(original_obj)
	
	var collision_shape = CollisionShape2D.new()  # NO auto_free for PackedScene
	collision_shape.name = "OriginalCollisionShape"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2size
	collision_shape.shape = rect_shape
	original_obj.add_child(collision_shape)
	
	# CRITICAL: Set owner for PackedScene to include children
	collision_shape.owner = original_obj
	
	print("1. Original %s children: %d" % [object_type, original_obj.get_child_count()])
	if original_obj.get_child_count() > 0:
		var child = original_obj.get_children()[0]
		print("1a. First child name: %s" % child.name)
		print("1b. First child type: %s" % child.get_class())
	
	print("2. Original %s shape_owners: %s" % [object_type, original_obj.get_shape_owners()])
	var original_shapes = GBGeometryUtils.get_shapes_from_owner(original_obj)
	print("3. Original shapes: %d" % original_shapes.size())
	
	# Create PackedScene and verify packing
	var scene = PackedScene.new()
	var pack_result = scene.pack(original_obj)
	print("4. PackedScene.pack() result: %s" % pack_result)
	
	var state = scene.get_state()
	print("5. Packed scene node count: %d" % state.get_node_count())
	for i in range(state.get_node_count()):
		print("5a. Node %d: %s (type: %s)" % [i, state.get_node_name(i), state.get_node_type(i)])
	
	# Instantiate and test
	var preview_obj = scene.instantiate() as CollisionObject2D
	add_child(preview_obj)
	
	print("6. Preview %s children: %d" % [object_type, preview_obj.get_child_count()])
	var preview_shapes = GBGeometryUtils.get_shapes_from_owner(preview_obj)
	print("7. Preview shapes: %d" % preview_shapes.size())
	
	# Assertions
	assert_int(pack_result).append_failure_message("PackedScene.pack() failed").is_equal(OK)
	assert_int(state.get_node_count()).append_failure_message("Expected at least 2 nodes in packed scene").is_greater_equal(2)
	assert_int(preview_obj.get_child_count()).append_failure_message("Preview should have children").is_greater(0)

## Test polygon shape conversion and collision detection edge cases
func test_polygon_collision_edge_cases():
	print("=== DEBUG POLYGON COLLISION EDGE CASES ===")
	
	var test_cases = [
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
	
	for test_case in test_cases:
		print("--- Testing: %s ---" % test_case.name)
		var points = test_case.points as PackedVector2Array
		var expected_valid = test_case.expected_valid as bool
		
		print("Input points: %s" % points)
		
		# Test bounds calculation
		var bounds = CollisionGeometryCalculator._get_polygon_bounds(points)
		print("Polygon bounds: %s" % bounds)
		
		# Test if polygon is considered valid (using points.size() >= 3)
		var is_valid = points.size() >= 3 and CollisionGeometryCalculator._polygon_area(points) > 0.001
		print("Is valid polygon: %s" % is_valid)
		
		# Test area calculation if valid
		if is_valid:
			var area = CollisionGeometryCalculator._polygon_area(points)
			print("Polygon area: %f" % area)
		
		assert_bool(is_valid).append_failure_message(
			"Polygon validity mismatch for %s: expected %s, got %s" % [test_case.name, expected_valid, is_valid]
		).is_equal(expected_valid)
