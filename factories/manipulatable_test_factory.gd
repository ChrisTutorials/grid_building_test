## Provides manipulatable test objects for grid building tests
extends RefCounted

static func create_static_body_manipulatable() -> Manipulatable:
	var manipulatable: Manipulatable = Manipulatable.new()
	var static_body: StaticBody2D = StaticBody2D.new()
	static_body.collision_layer = 1
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.extents = Vector2(16, 16)
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	
	manipulatable.add_child(static_body)
	return manipulatable
