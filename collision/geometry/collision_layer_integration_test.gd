extends GdUnitTestSuite
## Tests collision layer matching integration to isolate specific layer mask 2561 vs collision layer 513 failures

const PhysicsUtils = preload("res://addons/grid_building/utils/physics_matching_utils_2d.gd")


func test_layer_mask_2561_matches_collision_layer_513() -> void:
	# Test the specific layer combination from the failing integration tests
	var layer_mask: int = 2561  # Layers [0, 9, 11]
	var collision_layer: int = 513  # Layers [0, 9]

	# Verify our conversion logic - order doesn't matter for our use case
	var layers_from_mask: Array[int] = PhysicsUtils.get_layers_from_bitmask(layer_mask)
	(
		assert_that(layers_from_mask) \
		. contains_exactly_in_any_order([0, 9, 11]) \
		. append_failure_message("Layer mask 2561 should contain layers [0, 9, 11]")
	)

	var layers_from_collision: Array[int] = PhysicsUtils.get_layers_from_bitmask(collision_layer)
	(
		assert_that(layers_from_collision) \
		. contains_exactly_in_any_order([0, 9]) \
		. append_failure_message("Collision layer 513 should contain layers [0, 9]")
	)

	# Create a test collision object with layer 513
	var area: Area2D = auto_free(Area2D.new())
	area.collision_layer = collision_layer
	add_child(area)

	# Test the matching logic
	var matches: bool = PhysicsUtils.object_has_matching_layer(area, layer_mask)
	assert_bool(matches).append_failure_message(
		(
			"Area2D with collision layer 513 should match layer mask 2561. "
			+ "Mask layers: %s, Object layers: %s" % [layers_from_mask, layers_from_collision]
		)
	).is_true()


func test_regression_collision_layer_513_mask_2561_debug() -> void:
	# This test reproduces the exact scenario from the failing integration tests

	# Create collision object similar to integration test setup
	var test_area: Area2D = auto_free(Area2D.new())
	test_area.collision_layer = 513
	test_area.name = "TestIndicatorSetupArea"

	# Add collision shape
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array(
		[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
	)
	test_area.add_child(collision_polygon)

	# Position it
	test_area.position = Vector2(64, 64)
	add_child(test_area)

	# Test direct layer matching
	var direct_match: bool = PhysicsUtils.object_has_matching_layer(test_area, 2561)

	# Validate regression test success
	(
		assert_bool(direct_match) \
		. append_failure_message(
			(
				"Collision layer 513 should properly match mask 2561. Layer value: %d, Mask value: %d, Intersection: %d"
				% [513, 2561, 513 & 2561]
			)
		) \
		. is_true()
	)


func test_debug_layer_conversion_consistency() -> void:
	# Test that our layer conversion is consistent with Godot's bit operations
	var test_masks: Array[int] = [513, 2561, 1, 2, 4, 8, 16, 32]

	for mask in test_masks:
		var layers: Array[int] = PhysicsUtils.get_layers_from_bitmask(mask)

		# Verify each layer in the result
		for layer in layers:
			var expected_bit: int = 1 << layer
			assert_that(mask & expected_bit).append_failure_message(
				"Layer %d should be present in mask %d (bit check failed)" % [layer, mask]
			).is_not_equal(0)

		# Verify no extra layers
		for i in range(32):
			var bit_set: bool = (mask & (1 << i)) != 0
			var layer_in_result: bool = layers.has(i)
			assert_bool(bit_set == layer_in_result).append_failure_message(
				(
					"Layer %d presence mismatch in mask %d: bit_set=%s, in_result=%s"
					% [i, mask, bit_set, layer_in_result]
				)
			).is_true()


func test_specific_integration_error_scenario() -> void:
	# Reproduce the exact error: "Collision object IndicatorSetupTestingArea does not match layer mask 2561"

	var setup_area: Area2D = auto_free(Area2D.new())
	setup_area.name = "IndicatorSetupTestingArea"
	setup_area.collision_layer = 513  # This should match mask 2561

	# Add collision shape to make it realistic
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	setup_area.add_child(collision_shape)

	add_child(setup_area)

	# This should return true - no "does not match" error
	var should_match: bool = PhysicsUtils.object_has_matching_layer(setup_area, 2561)
	(
		assert_bool(should_match) \
		. append_failure_message(
			(
				"CRITICAL: IndicatorSetupTestingArea with collision layer 513 must match layer mask 2561. "
				+ "This is the exact error from integration tests."
			)
		) \
		. is_true()
	)

	# Additional verification: check the binary representation
	(
		assert_that(513 & 2561) \
		. append_failure_message(
			(
				"Binary intersection of collision layer 513 and mask 2561 must be non-zero. Layer: %d, Mask: %d, Intersection: %d"
				% [513, 2561, 513 & 2561]
			)
		) \
		. is_greater(0)
	)
