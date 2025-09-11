extends GdUnitTestSuite

# Unit test to isolate IndicatorCollisionTestSetup creation issues
# This tests the lowest level dependency that's causing the collision mapper tests to fail

func before_test():
	pass

# Test: IndicatorCollisionTestSetup creation with CollisionShape2D
func test_indicator_collision_test_setup_creation() -> void:
	# Create a StaticBody2D with CollisionShape2D
	var body := StaticBody2D.new()
	auto_free(body)
	add_child(body)

	var shape := CollisionShape2D.new()
	auto_free(shape)
	var rect := RectangleShape2D.new()
	auto_free(rect)
	rect.size = Vector2size
	shape.shape = rect
	body.add_child(shape)

	# Ensure the scene tree is ready
	await get_tree().process_frame

	# Debug: Check shape owners
	shape_owner_count: Node = body.get_shape_owners().size()
	print("DEBUG: Shape owner count: ", shape_owner_count)

	if shape_owner_count > 0:
		var shape_owner_ids = body.get_shape_owners()
		for owner_id in shape_owner_ids:
			var owner_node = body.shape_owner_get_owner(owner_id)
			var shape_count = body.shape_owner_get_shape_count(owner_id)
			print("DEBUG: Owner: ", owner_node.name, ", Shape count: ", shape_count)

	# Create test setup
	var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(body, Vector2(16, 16))

	# Debug: Check validation
	var is_valid = test_setup.validate_setup()
	print("DEBUG: Test setup valid: ", is_valid)
	print("DEBUG: Issues: ", test_setup.issues)
	print("DEBUG: Rect collision test setups size: ", test_setup.rect_collision_test_setups.size())

	# This should pass if the setup is working correctly
	assert_that(is_valid).is_true().append_failure_message("IndicatorCollisionTestSetup should be valid for CollisionShape2D")
	assert_that(test_setup.rect_collision_test_setups.size()).is_greater(0).append_failure_message("Should have at least one rect collision test setup")

# Test: IndicatorCollisionTestSetup with no shapes (should fail gracefully)
func test_indicator_collision_test_setup_empty_body() -> void:
	var body := StaticBody2D.new()
	auto_free(body)
	add_child(body)

	var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(body, Vector2(16, 16))

	var is_valid = test_setup.validate_setup()
	assert_that(is_valid).is_false().append_failure_message("Empty body should not be valid")
	assert_that(test_setup.issues.size()).is_greater(0).append_failure_message("Should have validation issues")
