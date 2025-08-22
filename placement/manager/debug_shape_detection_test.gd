extends GdUnitTestSuite

## Debug test to understand why GBGeometryUtils.get_shapes_from_owner() fails for RigidBody2D with CollisionShape2D

func test_debug_rigid_body_shape_detection():
	# Create a RigidBody2D with CollisionShape2D exactly like the failing test
	var rigid_body = auto_free(RigidBody2D.new())
	rigid_body.name = "TestRigidBody"
	rigid_body.collision_layer = 513
	add_child(rigid_body)
	
	var collision_shape = auto_free(CollisionShape2D.new())
	collision_shape.name = "TestCollisionShape"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	collision_shape.shape = rect_shape
	rigid_body.add_child(collision_shape)
	
	print("=== DEBUG SHAPE DETECTION ===")
	print("1. RigidBody2D.collision_layer: ", rigid_body.collision_layer)
	print("2. RigidBody2D.name: ", rigid_body.name)
	print("3. CollisionShape2D.name: ", collision_shape.name)
	print("4. CollisionShape2D.shape: ", collision_shape.shape)
	print("5. RigidBody2D.get_shape_owners(): ", rigid_body.get_shape_owners())
	
	# Test get_shapes_from_owner directly
	var shapes_from_owner = GBGeometryUtils.get_shapes_from_owner(rigid_body)
	print("6. get_shapes_from_owner result: ", shapes_from_owner.size(), " shapes")
	
	# Test get_all_collision_shapes_by_owner
	var all_shapes = GBGeometryUtils.get_all_collision_shapes_by_owner(rigid_body)
	print("7. get_all_collision_shapes_by_owner result: ", all_shapes.size(), " owners")
	
	# Let's check if the CollisionShape2D is being considered
	if rigid_body.get_children().size() > 0:
		var child = rigid_body.get_children()[0]
		print("8. First child type: ", child.get_class())
		print("9. First child is CollisionShape2D: ", child is CollisionShape2D)
		if child is CollisionShape2D:
			print("10. Child CollisionShape2D.shape: ", child.shape)
	
	# Check if maybe we need to look at children differently
	var collision_children = []
	for child in rigid_body.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			collision_children.append(child)
	print("11. Collision children found: ", collision_children.size())
	
	# The issue might be that RigidBody2D doesn't automatically register CollisionShape2D children as "shape owners"
	# Let's see what get_collision_object_shapes returns
	var collision_object_shapes = GBGeometryUtils.get_collision_object_shapes(rigid_body)
	print("12. get_collision_object_shapes result: ", collision_object_shapes.size(), " shapes")
	
	# This should find at least one shape
	assert_int(shapes_from_owner.size()).append_failure_message("get_shapes_from_owner should find shapes").is_greater(0)
