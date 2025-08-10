## Tests the hierarchy validation logic of Manipulatable component.
extends GdUnitTestSuite

var _scene_root: Node


func before_test() -> void:
	_scene_root = Node.new()
	add_child(_scene_root)


func after_test() -> void:
	_scene_root.queue_free()


func test_hierarchy_valid_when_root_is_ancestor() -> void:
	var root := Node3D.new()
	_scene_root.add_child(root)
	var child := Node3D.new()
	root.add_child(child)
	var m := Manipulatable.new()
	child.add_child(m)
	m.root = root
	assert_bool(m.is_root_hierarchy_valid()).is_true()
	assert_bool(m.validate_setup()).is_true()


func test_hierarchy_invalid_when_root_not_ancestor() -> void:
	var unrelated := Node3D.new()
	_scene_root.add_child(unrelated)
	var other_branch := Node3D.new()
	_scene_root.add_child(other_branch)
	var child := Node3D.new()
	other_branch.add_child(child)
	var m := Manipulatable.new()
	child.add_child(m)
	m.root = unrelated
	assert_bool(m.is_root_hierarchy_valid()).is_false()
	assert_bool(m.validate_setup()).is_false()
