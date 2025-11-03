extends GdUnitTestSuite

## Tests for FlipManager - Flip operation coordination and validation
##
## FlipManager handles horizontal and vertical flip operations with validation.
## Tests verify flip application, Node2D type checking, and enable/disable flags.

const FlipManager = preload("uid://chtxqe6qie742")
const THRESHOLD := 0.01

var _flip_manager: FlipManager


func before_test() -> void:
	_flip_manager = FlipManager.new()


# region Horizontal Flip Tests


## Tests that flip_horizontal applies negative X scale to Node2D targets
func test_flip_horizontal_negates_x_scale() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.scale = Vector2(1.0, 1.0)

	var result: bool = _flip_manager.flip_horizontal(target)

	assert_bool(result).is_true()
	assert_vector(target.scale).is_equal_approx(Vector2(-1.0, 1.0), THRESHOLD)


## Tests that flip_horizontal can flip twice to restore original scale
func test_flip_horizontal_twice_restores_original() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.scale = Vector2(2.0, 3.0)

	_flip_manager.flip_horizontal(target)
	_flip_manager.flip_horizontal(target)

	assert_vector(target.scale).is_equal_approx(Vector2(2.0, 3.0), THRESHOLD)


## Tests that flip_horizontal rejects non-Node2D targets
func test_flip_horizontal_rejects_non_node2d() -> void:
	var target: Node = auto_free(Node.new())

	var result: bool = _flip_manager.flip_horizontal(target)

	assert_bool(result).is_false()


# endregion

# region Vertical Flip Tests


## Tests that flip_vertical applies negative Y scale to Node2D targets
func test_flip_vertical_negates_y_scale() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.scale = Vector2(1.0, 1.0)

	var result: bool = _flip_manager.flip_vertical(target)

	assert_bool(result).is_true()
	assert_vector(target.scale).is_equal_approx(Vector2(1.0, -1.0), THRESHOLD)


## Tests that flip_vertical can flip twice to restore original scale
func test_flip_vertical_twice_restores_original() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.scale = Vector2(2.0, 3.0)

	_flip_manager.flip_vertical(target)
	_flip_manager.flip_vertical(target)

	assert_vector(target.scale).is_equal_approx(Vector2(2.0, 3.0), THRESHOLD)


## Tests that flip_vertical rejects non-Node2D targets
func test_flip_vertical_rejects_non_node2d() -> void:
	var target: Node = auto_free(Node.new())

	var result: bool = _flip_manager.flip_vertical(target)

	assert_bool(result).is_false()


# endregion

# region Combined Flip Tests


## Tests that horizontal and vertical flips can be combined
func test_flip_horizontal_and_vertical_combined() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.scale = Vector2(1.0, 1.0)

	_flip_manager.flip_horizontal(target)
	_flip_manager.flip_vertical(target)

	assert_vector(target.scale).is_equal_approx(Vector2(-1.0, -1.0), THRESHOLD)


## Tests that flips preserve target position
func test_flips_preserve_position() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.position = Vector2(100.0, 200.0)

	_flip_manager.flip_horizontal(target)
	_flip_manager.flip_vertical(target)

	assert_vector(target.position).is_equal(Vector2(100.0, 200.0))

# endregion
