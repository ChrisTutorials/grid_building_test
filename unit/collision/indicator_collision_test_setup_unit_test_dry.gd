extends GdUnitTestSuite

# Unit test to isolate IndicatorCollisionTestSetup creation issues
# This tests the lowest level dependency that's causing the collision mapper tests to fail

# Constants
const TEST_TILE_SIZE := Vector2(16, 16)
const DEBUG_PREFIX := "DEBUG: "

func before_test() -> void:
	pass

# Helper: Create a StaticBody2D with CollisionShape2D and RectangleShape2D
func _create_body_with_rectangle_shape(size: Vector2 = TEST_TILE_SIZE) -> StaticBody2D:
	var body := StaticBody2D.new()
	auto_free(body)
	add_child(body)

	var shape := CollisionShape2D.new()
	auto_free(shape)
	var rect := RectangleShape2D.new()
	auto_free(rect)
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	return body

# Helper: Create empty StaticBody2D for testing
func _create_empty_body() -> StaticBody2D:
	var body := StaticBody2D.new()
	auto_free(body)
	add_child(body)
	return body

# Helper: Debug shape owners information
func _debug_shape_owners(body: StaticBody2D) -> void:
	var shape_owner_count: int = body.get_shape_owners().size()
	print(DEBUG_PREFIX + "Shape owner count: ", shape_owner_count)

	if shape_owner_count > 0:
		var shape_owner_ids: Array = body.get_shape_owners()
		for owner_id: int in shape_owner_ids:
			var owner_node: Node2D = body.shape_owner_get_owner(owner_id)
			var shape_count: int = body.shape_owner_get_shape_count(owner_id)
			print(DEBUG_PREFIX + "Owner: ", owner_node.name, ", Shape count: ", shape_count)

# Helper: Debug test setup validation
func _debug_test_setup_validation(test_setup: IndicatorCollisionTestSetup) -> void:
	var is_valid: bool = test_setup.validate_setup()
	print(DEBUG_PREFIX + "Test setup valid: ", is_valid)
	print(DEBUG_PREFIX + "Issues: ", test_setup.issues)
	print(DEBUG_PREFIX + "Rect collision test setups size: ", test_setup.rect_collision_test_setups.size())

# Helper: Create and validate test setup
func _create_and_validate_test_setup(body: StaticBody2D, tile_size: Vector2 = TEST_TILE_SIZE) -> IndicatorCollisionTestSetup:
	var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(body, tile_size)
	test_setup.validate_setup()
	return test_setup

# Test: IndicatorCollisionTestSetup creation with CollisionShape2D
func test_indicator_collision_test_setup_creation() -> void:
	# Create a StaticBody2D with CollisionShape2D
	var body := _create_body_with_rectangle_shape()

	# Ensure the scene tree is ready
	await get_tree().process_frame

	# Debug: Check shape owners
	_debug_shape_owners(body)

	# Create test setup
	var test_setup := _create_and_validate_test_setup(body)

	# Debug: Check validation
	_debug_test_setup_validation(test_setup)

	# This should pass if the setup is working correctly
	assert_that(test_setup.validate_setup()).is_true()
	assert_that(test_setup.rect_collision_test_setups.size()).is_greater(0)

# Test: IndicatorCollisionTestSetup with no shapes (should fail gracefully)
func test_indicator_collision_test_setup_empty_body() -> void:
	var body := _create_empty_body()

	var test_setup := _create_and_validate_test_setup(body)

	var is_valid: bool = test_setup.validate_setup()
	assert_that(is_valid).is_false()
	assert_that(test_setup.issues.size()).is_greater(0)
