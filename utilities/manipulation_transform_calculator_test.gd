## Unit Test Suite: ManipulationTransformCalculator
##
## Tests pure transform calculation logic in isolation.
## No scene tree, no dependencies, just input -> output validation.
##
## Coverage:
## - Transform calculation from preview + parent
## - Flip semantics preservation (negative scale)
## - Transform validation
## - Transform comparison utilities

extends GdUnitTestSuite

#region Test Helpers

## Creates a mock Node2D with specified transforms for testing
func _create_mock_node(pos: Vector2, rot: float, scale: Vector2) -> Node2D:
	var node: Node2D = auto_free(Node2D.new())
	node.global_position = pos
	node.rotation = rot
	node.scale = scale
	return node

#endregion

#region TRANSFORM_CALCULATION_TESTS

## Test: Basic transform calculation returns expected components
func test_calculate_final_transform_basic() -> void:
	# Arrange: Create preview and parent nodes with known transforms
	# CRITICAL: Calculator reads position from manipulation_parent, NOT from preview_root
	# ManipulationParent follows the grid positioner, so its position is the final placement position
	var preview := _create_mock_node(Vector2.ZERO, deg_to_rad(45), Vector2(1.5, 1.5))
	var parent := _create_mock_node(Vector2(100, 200), deg_to_rad(45), Vector2(1.5, 1.5))
	
	# Act: Calculate final transform
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, parent)
	
	# Assert: Position should match parent position (where ManipulationParent is located)
	assert_vector(result["position"]).is_equal(Vector2(100, 200)).append_failure_message(
		"Position should be read from parent: expected (100, 200), got (%s)" % str(result["position"])
	)

## Test: Horizontal flip (negative scale.x) is preserved
func test_calculate_final_transform_horizontal_flip() -> void:
	# Arrange: Parent has negative scale.x (horizontal flip)
	var preview := _create_mock_node(Vector2(100, 200), 0.0, Vector2.ONE)
	var parent := _create_mock_node(Vector2.ZERO, 0.0, Vector2(-1, 1))
	
	# Act
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, parent)
	
	# Assert: Negative scale should be preserved
	assert_vector(result["scale"]).is_equal(Vector2(-1, 1)).append_failure_message(
		"Horizontal flip should preserve negative scale.x: expected (-1, 1), got (%s)" % str(result["scale"])
	)

## Test: Vertical flip (negative scale.y) is preserved
func test_calculate_final_transform_vertical_flip() -> void:
	# Arrange: Parent has negative scale.y (vertical flip)
	var preview := _create_mock_node(Vector2(100, 200), 0.0, Vector2.ONE)
	var parent := _create_mock_node(Vector2.ZERO, 0.0, Vector2(1, -1))
	
	# Act
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, parent)
	
	# Assert: Negative scale should be preserved
	assert_vector(result["scale"]).is_equal(Vector2(1, -1)).append_failure_message(
		"Vertical flip should preserve negative scale.y: expected (1, -1), got (%s)" % str(result["scale"])
	)

## Test: Combined horizontal + vertical flip (both negative) is preserved
func test_calculate_final_transform_both_flips() -> void:
	# Arrange: Parent has both flips
	var preview := _create_mock_node(Vector2(100, 200), 0.0, Vector2.ONE)
	var parent := _create_mock_node(Vector2.ZERO, 0.0, Vector2(-1, -1))
	
	# Act
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, parent)
	
	# Assert: Both negative scales should be preserved
	assert_vector(result["scale"]).is_equal(Vector2(-1, -1)).append_failure_message(
		"Both flips should preserve negative scale: expected (-1, -1), got (%s)" % str(result["scale"])
	)

## Test: Rotation + flip combination preserves both
func test_calculate_final_transform_rotation_and_flip() -> void:
	# Arrange: Parent has rotation AND horizontal flip
	var preview := _create_mock_node(Vector2(100, 200), deg_to_rad(90), Vector2.ONE)
	var parent := _create_mock_node(Vector2.ZERO, deg_to_rad(90), Vector2(-1, 1))
	
	# Act
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, parent)
	
	# Assert: Both rotation and flip should be preserved
	assert_float(result["rotation"]).is_equal_approx(deg_to_rad(90), 0.01).append_failure_message(
		"Rotation should be preserved: expected 90°, got %.2f°" % rad_to_deg(result["rotation"])
	)
	assert_vector(result["scale"]).is_equal(Vector2(-1, 1)).append_failure_message(
		"Flip should be preserved alongside rotation: expected (-1, 1), got (%s)" % str(result["scale"])
	)

## Test: Null preview returns safe defaults
func test_calculate_final_transform_null_preview() -> void:
	# Arrange
	var parent := _create_mock_node(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Act: Call with null preview (will log error internally)
	var result := ManipulationTransformCalculator.calculate_final_transform(null, parent)
	
	# Assert: Should return safe default values
	assert_vector(result["position"]).is_equal(Vector2.ZERO).append_failure_message(
		"Null preview should return ZERO position, got %s" % str(result["position"])
	)
	assert_float(result["rotation"]).is_equal(0.0).append_failure_message(
		"Null preview should return 0.0 rotation, got %.2f" % result["rotation"]
	)
	assert_vector(result["scale"]).is_equal(Vector2.ONE).append_failure_message(
		"Null preview should return ONE scale, got %s" % str(result["scale"])
	)

## Test: Null parent returns safe defaults
func test_calculate_final_transform_null_parent() -> void:
	# Arrange
	var preview := _create_mock_node(Vector2(100, 200), 0.0, Vector2.ONE)
	
	# Act: Call with null parent (will log error internally)
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, null)
	
	# Assert: Should return safe default values
	assert_vector(result["position"]).is_equal(Vector2.ZERO).append_failure_message(
		"Null parent should return ZERO position, got %s" % str(result["position"])
	)
	assert_float(result["rotation"]).is_equal(0.0).append_failure_message(
		"Null parent should return 0.0 rotation, got %.2f" % result["rotation"]
	)
	assert_vector(result["scale"]).is_equal(Vector2.ONE).append_failure_message(
		"Null parent should return ONE scale, got %s" % str(result["scale"])
	)

#endregion

#region TRANSFORM_VALIDATION_TESTS

## Test: Valid transforms pass validation
func test_validate_transform_preservation_valid() -> void:
	# Arrange
	var transforms := {
		"position": Vector2(100, 200),
		"rotation": deg_to_rad(45),
		"scale": Vector2(1.5, 1.5)
	}
	
	# Act
	var result := ManipulationTransformCalculator.validate_transform_preservation(transforms)
	
	# Assert
	assert_bool(result["is_valid"]).is_true().append_failure_message(
		"Valid transforms should pass validation. Issues: %s" % str(result["issues"])
	)
	assert_array(result["issues"]).is_empty()

## Test: Negative scale (flips) pass validation
func test_validate_transform_preservation_negative_scale_valid() -> void:
	# Arrange: Horizontal flip
	var transforms := {
		"position": Vector2(100, 200),
		"rotation": 0.0,
		"scale": Vector2(-1, 1)
	}
	
	# Act
	var result := ManipulationTransformCalculator.validate_transform_preservation(transforms)
	
	# Assert: Negative scale should be VALID (it's a flip, not an error)
	assert_bool(result["is_valid"]).is_true().append_failure_message(
		"Negative scale (flip) should be valid. Issues: %s" % str(result["issues"])
	)

## Test: Near-zero scale fails validation
func test_validate_transform_preservation_zero_scale_invalid() -> void:
	# Arrange: Scale too small (would make object invisible)
	var transforms := {
		"position": Vector2(100, 200),
		"rotation": 0.0,
		"scale": Vector2(0.001, 0.001)
	}
	
	# Act
	var result := ManipulationTransformCalculator.validate_transform_preservation(transforms)
	
	# Assert: Near-zero scale should fail validation
	assert_bool(result["is_valid"]).is_false().append_failure_message(
		"Near-zero scale should fail validation"
	)
	assert_array(result["issues"]).is_not_empty()

## Test: Missing keys fail validation
func test_validate_transform_preservation_missing_keys() -> void:
	# Arrange: Missing 'rotation' key
	var transforms := {
		"position": Vector2(100, 200),
		"scale": Vector2(1, 1)
	}
	
	# Act
	var result := ManipulationTransformCalculator.validate_transform_preservation(transforms)
	
	# Assert
	assert_bool(result["is_valid"]).is_false()
	assert_array(result["issues"]).is_not_empty().append_failure_message(
		"Missing keys should produce validation issues"
	)

#endregion

#region TRANSFORM_COMPARISON_TESTS

## Test: Identical transforms match
func test_compare_transforms_identical() -> void:
	# Arrange
	var expected := {
		"position": Vector2(100, 200),
		"rotation": deg_to_rad(45),
		"scale": Vector2(1.5, 1.5)
	}
	var actual := {
		"position": Vector2(100, 200),
		"rotation": deg_to_rad(45),
		"scale": Vector2(1.5, 1.5)
	}
	
	# Act
	var result := ManipulationTransformCalculator.compare_transforms(expected, actual)
	
	# Assert
	assert_bool(result["matches"]).is_true().append_failure_message(
		"Identical transforms should match. Differences: %s" % str(result["differences"])
	)
	assert_that(result["differences"]).is_empty()

## Test: Small differences within tolerance match
func test_compare_transforms_within_tolerance() -> void:
	# Arrange
	var expected := {
		"position": Vector2(100.0, 200.0),
		"rotation": deg_to_rad(45.0),
		"scale": Vector2(1.5, 1.5)
	}
	var actual := {
		"position": Vector2(100.05, 200.05),  # 0.05 difference (within 0.1 tolerance)
		"rotation": deg_to_rad(45.005),        # 0.005 rad difference (within 0.01 tolerance)
		"scale": Vector2(1.505, 1.505)         # 0.005 difference (within 0.01 tolerance)
	}
	
	# Act
	var result := ManipulationTransformCalculator.compare_transforms(expected, actual)
	
	# Assert
	assert_bool(result["matches"]).is_true().append_failure_message(
		"Transforms within tolerance should match. Differences: %s" % str(result["differences"])
	)

## Test: Differences beyond tolerance are detected
func test_compare_transforms_beyond_tolerance() -> void:
	# Arrange
	var expected := {
		"position": Vector2(100.0, 200.0),
		"rotation": deg_to_rad(45.0),
		"scale": Vector2(1.5, 1.5)
	}
	var actual := {
		"position": Vector2(110.0, 210.0),  # 10 unit difference (beyond 0.1 tolerance)
		"rotation": deg_to_rad(50.0),       # 5° difference (beyond 0.01 rad tolerance)
		"scale": Vector2(2.0, 2.0)          # 0.5 difference (beyond 0.01 tolerance)
	}
	
	# Act
	var result := ManipulationTransformCalculator.compare_transforms(expected, actual)
	
	# Assert
	assert_bool(result["matches"]).is_false().append_failure_message(
		"Transforms beyond tolerance should not match"
	)
	assert_that(result["differences"]).is_not_empty()
	assert_that(result["differences"].has("position")).is_true()
	assert_that(result["differences"].has("rotation")).is_true()
	assert_that(result["differences"].has("scale")).is_true()

#endregion

#region DIAGNOSTIC_FORMATTING_TESTS

## Test: Format transforms produces readable output
func test_format_transforms_debug() -> void:
	# Arrange
	var transforms := {
		"position": Vector2(100, 200),
		"rotation": deg_to_rad(45),
		"scale": Vector2(-1, 1.5)  # Horizontal flip + vertical scale
	}
	
	# Act
	var formatted := ManipulationTransformCalculator.format_transforms_debug(transforms)
	
	# Assert: Should contain all components in readable format
	assert_str(formatted).contains("Position")
	assert_str(formatted).contains("100")
	assert_str(formatted).contains("200")
	assert_str(formatted).contains("Rotation")
	assert_str(formatted).contains("45")
	assert_str(formatted).contains("Scale")
	assert_str(formatted).contains("-1")  # Should show negative scale for flip

#endregion
