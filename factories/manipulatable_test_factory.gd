## Provides manipulatable test objects for grid building tests
class_name ManipulatableTestFactory
extends RefCounted

## Creates a simple manipulatable with static body collision
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

## Creates a manipulatable with a custom root node name for test scenarios
## [param test] The GdUnitTestSuite instance for auto_free() management
## [param root_name] Name to assign to the root Node2D
## [return] A Manipulatable instance with a named root node and registered to test suite
static func create_manipulatable_with_root(test: GdUnitTestSuite, root_name: String = "ManipulatableRoot") -> Manipulatable:
	var manipulatable: Manipulatable = test.auto_free(Manipulatable.new())
	var root: Node2D = test.auto_free(Node2D.new())
	root.name = root_name
	
	manipulatable.root = root
	test.add_child(root)
	
	return manipulatable
