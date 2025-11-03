## RotationManager Component Tests
##
## Tests for rotation and flip management logic extracted from ManipulationSystem.
extends GdUnitTestSuite

var _manager: Resource
var _test_node: Node2D
var _manipulation_parent: Node2D


func before_test() -> void:
	_test_node = auto_free(Node2D.new())
	_test_node.rotation = 0.0
	_test_node.scale = Vector2.ONE

	# Create a mock ManipulationParent-like node for testing
	_manipulation_parent = auto_free(Node2D.new())
	_manipulation_parent.add_child(_test_node)

	# Load the rotation manager component
	var path: String = (
		"res://addons/grid_building/systems/manipulation/components/"
		+ "rotation_manager.gd"
	)
	var ManagerClass: Variant = load(path)
	if ManagerClass:
		_manager = ManagerClass.new()


#region Rotation Tests

## Tests manager rotates node by specified degrees.
func test_rotate_by_degrees() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var initial_rotation: float = _test_node.rotation
	var degrees_to_rotate: float = 45.0
	var radians_to_rotate: float = deg_to_rad(degrees_to_rotate)

	var result: Variant = _manager.rotate(_test_node, degrees_to_rotate)

	assert_bool(result).is_true().append_failure_message(
		"Should successfully rotate valid Node2D"
	)

	assert_float(_test_node.rotation).append_failure_message(
		"Rotation should be applied"
	).is_equal_approx(initial_rotation + radians_to_rotate, 0.0001)


## Tests manager handles rotation of zero degrees.
func test_rotate_zero_degrees() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var initial_rotation: float = _test_node.rotation
	var result: Variant = _manager.rotate(_test_node, 0.0)

	assert_bool(result).is_true().append_failure_message(
		"Should handle zero rotation"
	)

	assert_float(_test_node.rotation).append_failure_message(
		"Rotation should remain unchanged"
	).is_equal(initial_rotation)


## Tests manager handles negative rotation (counter-clockwise).
func test_rotate_negative_degrees() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	_test_node.rotation = 0.0
	var degrees_to_rotate: float = -90.0
	var radians_to_rotate: float = deg_to_rad(degrees_to_rotate)

	var result: Variant = _manager.rotate(_test_node, degrees_to_rotate)

	assert_bool(result).is_true().append_failure_message(
		"Should handle negative rotation"
	)

	assert_float(_test_node.rotation).append_failure_message(
		"Should rotate counter-clockwise"
	).is_equal_approx(radians_to_rotate, 0.0001)


## Tests manager rejects non-Node2D targets.
func test_rotate_rejects_non_node2d() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var node: Node = auto_free(Node.new())
	var result: Variant = _manager.rotate(node, 45.0)

	assert_bool(result).is_false().append_failure_message(
		"Should reject non-Node2D targets"
	)

#endregion


#region Horizontal Flip Tests

## Tests manager flips node horizontally.
func test_flip_horizontal() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var initial_scale: Vector2 = _test_node.scale
	var result: Variant = _manager.flip_horizontal(_test_node)

	assert_bool(result).is_true().append_failure_message(
		"Should successfully flip horizontally"
	)

	assert_float(_test_node.scale.x).append_failure_message(
		"X scale should be negated"
	).is_equal(-initial_scale.x)

	assert_float(_test_node.scale.y).append_failure_message(
		"Y scale should remain unchanged"
	).is_equal(initial_scale.y)


## Tests manager rejects horizontal flip for non-Node2D.
func test_flip_horizontal_rejects_non_node2d() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var node: Node = auto_free(Node.new())
	var result: Variant = _manager.flip_horizontal(node)

	assert_bool(result).is_false().append_failure_message(
		"Should reject non-Node2D targets"
	)

#endregion


#region Vertical Flip Tests

## Tests manager flips node vertically.
func test_flip_vertical() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var initial_scale: Vector2 = _test_node.scale
	var result: Variant = _manager.flip_vertical(_test_node)

	assert_bool(result).is_true().append_failure_message(
		"Should successfully flip vertically"
	)

	assert_float(_test_node.scale.x).append_failure_message(
		"X scale should remain unchanged"
	).is_equal(initial_scale.x)

	assert_float(_test_node.scale.y).append_failure_message(
		"Y scale should be negated"
	).is_equal(-initial_scale.y)


## Tests manager rejects vertical flip for non-Node2D.
func test_flip_vertical_rejects_non_node2d() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	var node: Node = auto_free(Node.new())
	var result: Variant = _manager.flip_vertical(node)

	assert_bool(result).is_false().append_failure_message(
		"Should reject non-Node2D targets"
	)

#endregion


#region Combined Transform Tests

## Tests that multiple rotations accumulate.
func test_multiple_rotations_accumulate() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	_test_node.rotation = 0.0

	_manager.rotate(_test_node, 45.0)
	_manager.rotate(_test_node, 45.0)

	var expected_rotation: float = deg_to_rad(90.0)

	assert_float(_test_node.rotation).append_failure_message(
		"Rotations should accumulate"
	).is_equal_approx(expected_rotation, 0.0001)


## Tests that flip can be combined with rotation.
func test_flip_and_rotate_combined() -> void:
	assert_object(_manager).is_not_null().append_failure_message(
		"RotationManager should be loaded"
	)

	_test_node.rotation = 0.0
	_test_node.scale = Vector2.ONE

	_manager.flip_horizontal(_test_node)
	_manager.rotate(_test_node, 90.0)

	assert_float(_test_node.scale.x).append_failure_message(
		"X scale should be flipped"
	).is_equal(-1.0)

	assert_float(_test_node.rotation).append_failure_message(
		"Rotation should be applied after flip"
	).is_equal_approx(deg_to_rad(90.0), 0.0001)

#endregion
