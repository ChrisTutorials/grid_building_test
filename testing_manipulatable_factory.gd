class_name TestingManipulatableFactory
extends GdUnitTestSuite

func create_manipulatable() -> Manipulatable:
	var root = auto_free(Node2D.new())
	add_child(root)
	var manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root
	root.add_child(manipulatable)
	root.name = "FactoryManipulatableRoot"
	manipulatable.name = "FactoryManipulatable"
	return manipulatable
