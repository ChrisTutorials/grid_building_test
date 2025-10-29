## Unit Tests for CollisionObjectResolver
##
## Tests the collision object resolution logic for different collision node types:
## - CollisionObject2D (direct)
## - CollisionShape2D (via parent CollisionObject2D)
## - CollisionPolygon2D (via parent CollisionObject2D)
extends GdUnitTestSuite

var _CollisionObjectResolver: GDScript = preload(
	"res://addons/grid_building/placement/manager/components/mapper/collision_object_resolver.gd"
)


## Local copy of ResolutionResult for testing
class ResolutionResult:
	var collision_object: CollisionObject2D = null
	var test_setup: CollisionTestSetup2D = null
	var is_valid: bool = false
	var error_message: String = ""


## Test data object for collision resolution tests
class CollisionResolutionTestData:
	var collision_node: Node2D
	var test_setups: Array[CollisionTestSetup2D]
	var expected_collision_obj: CollisionObject2D
	var expected_test_setup: CollisionTestSetup2D
	var cleanup_objects: Array[Node]

	func _init(
		p_collision_node: Node2D,
		p_test_setups: Array[CollisionTestSetup2D],
		p_expected_collision_obj: CollisionObject2D,
		p_expected_test_setup: CollisionTestSetup2D,
		p_cleanup_objects: Array[Node]
	) -> void:
		collision_node = p_collision_node
		test_setups = p_test_setups
		expected_collision_obj = p_expected_collision_obj
		expected_test_setup = p_expected_test_setup
		cleanup_objects = p_cleanup_objects


var _resolver: RefCounted


func before_test() -> void:
	_resolver = _CollisionObjectResolver.new()


func after_test() -> void:
	_resolver = null


## Test data for parameterized collision object resolution tests
func collision_resolution_test_data() -> Array[Array]:
	return [
		# [test_name, setup_func, expected_valid, expected_error_contains]
		[
			"direct_collision_object_2d",
			func() -> CollisionResolutionTestData: return _setup_direct_collision_object(),
			true,
			""
		],
		[
			"collision_shape_2d_with_parent",
			func() -> CollisionResolutionTestData: return _setup_collision_shape_with_parent(),
			true,
			""
		],
		[
			"collision_polygon_2d_with_parent",
			func() -> CollisionResolutionTestData: return _setup_collision_polygon_with_parent(),
			true,
			""
		],
		[
			"collision_shape_2d_without_parent",
			func() -> CollisionResolutionTestData: return _setup_collision_shape_without_parent(),
			false,
			"has no CollisionObject2D parent"
		],
		[
			"collision_polygon_2d_without_parent",
			func() -> CollisionResolutionTestData: return _setup_collision_polygon_without_parent(),
			false,
			"has no CollisionObject2D parent"
		],
		[
			"unsupported_node_type",
			func() -> CollisionResolutionTestData: return _setup_unsupported_node(),
			false,
			"Unsupported collision node type"
		],
		[
			"null_node",
			func() -> CollisionResolutionTestData: return _setup_null_node(),
			false,
			"Collision node is null"
		],
		[
			"collision_object_2d_without_test_setup",
			func() -> CollisionResolutionTestData:
				return _setup_collision_object_without_test_setup(),
			false,
			"No test setup found"
		]
	]


## Parameterized test for collision object resolution
@warning_ignore("unused_parameter")
func test_collision_object_resolution(
	test_name: String,
	setup_func: Callable,
	expected_valid: bool,
	expected_error_contains: String,
	test_parameters := collision_resolution_test_data()
) -> void:
	var test_data: CollisionResolutionTestData = setup_func.call()
	var collision_node: Node2D = test_data.collision_node
	var test_setups: Array[CollisionTestSetup2D] = test_data.test_setups
	var expected_collision_obj: CollisionObject2D = test_data.expected_collision_obj
	var expected_test_setup: CollisionTestSetup2D = test_data.expected_test_setup

	# Resolve
	var result: Variant = _resolver.resolve_collision_object(collision_node, test_setups)

	# Assert
	(
		assert_that(result.is_valid)
		. append_failure_message("Resolution validity should match expected")
		. is_equal(expected_valid)
	)
	if expected_valid:
		(
			assert_that(result.collision_object)
			. append_failure_message("Valid resolution should return expected collision object")
			. is_same(expected_collision_obj)
		)
		(
			assert_that(result.test_setup)
			. append_failure_message("Valid resolution should return expected test setup")
			. is_same(expected_test_setup)
		)
		(
			assert_that(result.error_message)
			. append_failure_message("Valid resolution should have no error message")
			. is_empty()
		)
	else:
		(
			assert_that(result.collision_object)
			. append_failure_message("Invalid resolution should return expected collision object")
			. is_same(expected_collision_obj)
		)
		(
			assert_that(result.test_setup)
			. append_failure_message("Invalid resolution should return expected test setup")
			. is_same(expected_test_setup)
		)
		(
			assert_that(result.error_message)
			. append_failure_message("Invalid resolution should contain expected error text")
			. contains(expected_error_contains)
		)

	# Cleanup
	for obj: Node in test_data.cleanup_objects:
		if is_instance_valid(obj):
			obj.queue_free()


## Test layer mask matching
func test_object_matches_layer_mask() -> void:
	var collision_obj: CollisionObject2D = StaticBody2D.new()
	collision_obj.collision_layer = 5  # Binary: 101

	# Test matching masks
	(
		assert_that(_resolver.object_matches_layer_mask(collision_obj, 1))
		. append_failure_message("Layer 1 should match collision object on layer 5")
		. is_true()
	)  # 001 & 101 = 001
	(
		assert_that(_resolver.object_matches_layer_mask(collision_obj, 4))
		. append_failure_message("Layer 4 should match collision object on layer 5")
		. is_true()
	)  # 100 & 101 = 100
	(
		assert_that(_resolver.object_matches_layer_mask(collision_obj, 2))
		. append_failure_message("Layer 2 should NOT match collision object on layer 5")
		. is_false()
	)  # 010 & 101 = 000

	# Test null object
	(
		assert_that(_resolver.object_matches_layer_mask(null, 1))
		. append_failure_message("Null object should not match any layer mask")
		. is_false()
	)

	# Cleanup
	collision_obj.queue_free()


## Setup functions for test data


func _setup_direct_collision_object() -> CollisionResolutionTestData:
	var collision_obj: CollisionObject2D = StaticBody2D.new()
	collision_obj.collision_layer = 1
	var test_setup := CollisionTestSetup2D.new(collision_obj, Vector2(32, 32))
	var test_setups: Array[CollisionTestSetup2D] = [test_setup]

	return CollisionResolutionTestData.new(
		collision_obj, test_setups, collision_obj, test_setup, [collision_obj]
	)


func _setup_collision_shape_with_parent() -> CollisionResolutionTestData:
	var parent_obj: CollisionObject2D = StaticBody2D.new()
	parent_obj.collision_layer = 2

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	shape.shape = rect_shape
	parent_obj.add_child(shape)

	var test_setup := CollisionTestSetup2D.new(parent_obj, Vector2(32, 32))
	var test_setups: Array[CollisionTestSetup2D] = [test_setup]

	return CollisionResolutionTestData.new(shape, test_setups, parent_obj, test_setup, [parent_obj])


func _setup_collision_polygon_with_parent() -> CollisionResolutionTestData:
	var parent_obj: CollisionObject2D = StaticBody2D.new()
	parent_obj.collision_layer = 4

	var polygon := CollisionPolygon2D.new()
	polygon.polygon = [Vector2(-16, -16), Vector2(16, -16), Vector2(0, 16)]
	parent_obj.add_child(polygon)

	var test_setup := CollisionTestSetup2D.new(parent_obj, Vector2(32, 32))
	var test_setups: Array[CollisionTestSetup2D] = [test_setup]

	return CollisionResolutionTestData.new(
		polygon, test_setups, parent_obj, test_setup, [parent_obj]
	)


func _setup_collision_shape_without_parent() -> CollisionResolutionTestData:
	var shape := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 16
	shape.shape = circle_shape

	var test_setups: Array[CollisionTestSetup2D] = []

	return CollisionResolutionTestData.new(shape, test_setups, null, null, [shape])


func _setup_collision_polygon_without_parent() -> CollisionResolutionTestData:
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = [Vector2(-8, -8), Vector2(8, -8), Vector2(0, 8)]

	var test_setups: Array[CollisionTestSetup2D] = []

	return CollisionResolutionTestData.new(polygon, test_setups, null, null, [polygon])


func _setup_unsupported_node() -> CollisionResolutionTestData:
	var node := Node2D.new()
	var test_setups: Array[CollisionTestSetup2D] = []

	return CollisionResolutionTestData.new(node, test_setups, null, null, [node])


func _setup_null_node() -> CollisionResolutionTestData:
	var test_setups: Array[CollisionTestSetup2D] = []

	return CollisionResolutionTestData.new(null, test_setups, null, null, [])


func _setup_collision_object_without_test_setup() -> CollisionResolutionTestData:
	var collision_obj: CollisionObject2D = StaticBody2D.new()
	collision_obj.collision_layer = 1

	var test_setups: Array[CollisionTestSetup2D] = []  # Empty test setups

	return CollisionResolutionTestData.new(
		collision_obj, test_setups, collision_obj, null, [collision_obj]
	)
