extends GdUnitTestSuite

## Unit tests for ManipulationTransformHandler component.
##
## Tests rotation and flip operations on Node2D objects.

const ManipulationTransformHandler = preload("uid://cbgh6gqc3l1nq")

var _handler: RefCounted
var _test_node: Node2D


func before_test() -> void:
	_handler = auto_free(ManipulationTransformHandler.new())
	_test_node = auto_free(Node2D.new())


## Tests that apply_rotation increases rotation_degrees.
func test_apply_rotation_increases_rotation_degrees() -> void:
	_test_node.rotation_degrees = 0.0

	_handler.apply_rotation(_test_node, 90.0)

	(
		assert_float(_test_node.rotation_degrees)
		. append_failure_message("Should rotate node by 90 degrees")
		. is_equal(90.0)
	)


## Tests that apply_rotation handles null target gracefully.
func test_apply_rotation_handles_null_target() -> void:
	_handler.apply_rotation(null, 90.0)

	assert_bool(true).append_failure_message("Should not crash when rotating null target").is_true()


## Tests that apply_rotation handles non-Node2D target gracefully.
func test_apply_rotation_handles_non_node2d() -> void:
	var invalid_target: Node = auto_free(Node.new())

	_handler.apply_rotation(invalid_target, 90.0)

	(
		assert_bool(true)
		. append_failure_message("Should not crash when rotating non-Node2D target")
		. is_true()
	)


## Tests that apply_flip_horizontal inverts scale.x.
func test_apply_flip_horizontal_inverts_scale_x() -> void:
	_test_node.scale = Vector2(1.0, 1.0)

	_handler.apply_flip_horizontal(_test_node)

	(
		assert_float(_test_node.scale.x)
		. append_failure_message("Should invert scale.x on horizontal flip")
		. is_equal(-1.0)
	)


## Tests that apply_flip_vertical inverts scale.y.
func test_apply_flip_vertical_inverts_scale_y() -> void:
	_test_node.scale = Vector2(1.0, 1.0)

	_handler.apply_flip_vertical(_test_node)

	(
		assert_float(_test_node.scale.y)
		. append_failure_message("Should invert scale.y on vertical flip")
		. is_equal(-1.0)
	)


## Tests that apply_flip_horizontal handles null target gracefully.
func test_apply_flip_horizontal_handles_null() -> void:
	_handler.apply_flip_horizontal(null)

	assert_bool(true).append_failure_message("Should not crash when flipping null target").is_true()


## Tests that apply_flip_vertical handles non-Node2D target gracefully.
func test_apply_flip_vertical_handles_non_node2d() -> void:
	var invalid_target: Node = auto_free(Node.new())

	_handler.apply_flip_vertical(invalid_target)

	(
		assert_bool(true)
		. append_failure_message("Should not crash when flipping non-Node2D target")
		. is_true()
	)


## Tests that multiple rotations accumulate correctly.
func test_multiple_rotations_accumulate() -> void:
	_test_node.rotation_degrees = 0.0

	_handler.apply_rotation(_test_node, 45.0)
	_handler.apply_rotation(_test_node, 45.0)

	(
		assert_float(_test_node.rotation_degrees)
		. append_failure_message("Should accumulate rotations to 90 degrees")
		. is_equal(90.0)
	)


## Tests that double horizontal flip restores original scale.
func test_double_flip_horizontal_restores_scale() -> void:
	_test_node.scale = Vector2(1.0, 1.0)

	_handler.apply_flip_horizontal(_test_node)
	_handler.apply_flip_horizontal(_test_node)

	(
		assert_float(_test_node.scale.x)
		. append_failure_message("Double flip should restore scale.x to 1.0")
		. is_equal(1.0)
	)
