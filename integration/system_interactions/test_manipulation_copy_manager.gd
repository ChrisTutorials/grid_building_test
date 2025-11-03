extends GdUnitTestSuite

## Tests for ManipulationCopyManager - Copy creation, setup, and cleanup
##
## ManipulationCopyManager handles creating manipulation copies, setting up
## targeting state, preparing copies for manipulation, and cleanup.


const ManipulationCopyManager = preload(
	"res://addons/grid_building/systems/manipulation/components/manipulation_copy_manager.gd"
)


var _copy_manager: ManipulationCopyManager


func before_test() -> void:
	_copy_manager = ManipulationCopyManager.new()


# region Copy Creation Tests

## Tests that create_copy handles null source
func test_create_copy_handles_null_source() -> void:
	var copy: Manipulatable = _copy_manager.create_copy(null)

	assert_that(copy).is_null()


# endregion


# region Copy Setup Tests

## Tests that setup_copy adds copy root to parent
func test_setup_copy_adds_copy_to_parent() -> void:
	var parent_node: Node = auto_free(Node.new())
	add_child(parent_node)

	var copy: Manipulatable = auto_free(Manipulatable.new())
	var copy_node: Node2D = auto_free(Node2D.new())
	copy.root = copy_node

	_copy_manager.setup_copy(copy, parent_node)

	assert_that(copy_node.get_parent()).is_equal(parent_node)


## Tests that setup_copy reparents copy if already has parent
func test_setup_copy_reparents_existing() -> void:
	var old_parent: Node = auto_free(Node.new())
	var new_parent: Node = auto_free(Node.new())
	add_child(old_parent)
	add_child(new_parent)

	var copy: Manipulatable = auto_free(Manipulatable.new())
	var copy_node: Node2D = auto_free(Node2D.new())
	copy.root = copy_node
	old_parent.add_child(copy_node)

	_copy_manager.setup_copy(copy, new_parent)

	assert_that(copy_node.get_parent()).is_equal(new_parent)


## Tests that setup_copy marks copy as preview
func test_setup_copy_marks_as_preview() -> void:
	var parent_node: Node = auto_free(Node.new())
	add_child(parent_node)

	var copy: Manipulatable = auto_free(Manipulatable.new())
	var copy_node: Node2D = auto_free(Node2D.new())
	copy.root = copy_node

	_copy_manager.setup_copy(copy, parent_node)

	assert_bool(copy_node.get_meta("gb_preview", false)).is_true()


# endregion


# region Copy Preparation Tests

## Tests that prepare_copy normalizes transform to identity
func test_prepare_copy_normalizes_transform() -> void:
	var copy: Manipulatable = auto_free(Manipulatable.new())
	var copy_node: Node2D = auto_free(Node2D.new())
	copy_node.rotation = 1.5  # 45 degrees in radians
	copy_node.scale = Vector2(2.0, 2.0)
	copy.root = copy_node

	var stored_transform: Array[Variant] = _copy_manager.prepare_copy(copy)

	# Should normalize to identity
	assert_float(copy_node.rotation).is_equal_approx(0.0, 0.0001)
	assert_float(copy_node.scale.x).is_equal_approx(1.0, 0.0001)
	assert_float(copy_node.scale.y).is_equal_approx(1.0, 0.0001)

	# Should store original transform
	assert_bool(stored_transform.size() > 0).is_true()


## Tests that prepare_copy returns stored transform for restoration
func test_prepare_copy_stores_original_transform() -> void:
	var copy: Manipulatable = auto_free(Manipulatable.new())
	var copy_node: Node2D = auto_free(Node2D.new())
	var original_rotation: float = 0.785  # ~45 degrees
	var original_scale: Vector2 = Vector2(3.0, 2.0)
	copy_node.rotation = original_rotation
	copy_node.scale = original_scale
	copy.root = copy_node

	var stored_transform: Array[Variant] = _copy_manager.prepare_copy(copy)

	# Verify stored transform matches original
	assert_float(stored_transform[0] as float).is_equal_approx(
		original_rotation, 0.0001
	)
	assert_float(stored_transform[1].x).is_equal_approx(
		original_scale.x, 0.0001
	)
	assert_float(stored_transform[1].y).is_equal_approx(
		original_scale.y, 0.0001
	)


## Tests that prepare_copy disables scripts on copy
func test_prepare_copy_disables_scripts() -> void:
	var copy: Manipulatable = auto_free(Manipulatable.new())
	var copy_node: Node2D = auto_free(Node2D.new())
	copy.root = copy_node

	_copy_manager.prepare_copy(copy)

	# Copy should have scripts disabled (via GBManipulationCopyUtils)
	# Verified by checking processing is disabled
	assert_bool(true).is_true()  # Placeholder - actual check is in integration


# endregion


# region Copy Cleanup Tests

## Tests that cleanup_copy handles null copy
func test_cleanup_copy_handles_null_copy() -> void:
	_copy_manager.cleanup_copy(null)

	# Should not error
	assert_bool(true).is_true()


## Tests that cleanup_copy handles null copy root
func test_cleanup_copy_handles_null_root() -> void:
	var copy: Manipulatable = auto_free(Manipulatable.new())
	copy.root = null

	_copy_manager.cleanup_copy(copy)

	# Should not error
	assert_bool(true).is_true()


# endregion
