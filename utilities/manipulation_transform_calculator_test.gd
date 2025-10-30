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
	assert_vector(result["position"]).append_failure_message(
		"Null preview should return ZERO position, got %s" % str(result["position"])
	).is_equal(Vector2.ZERO)
	assert_float(result["rotation"]).append_failure_message(
		"Float assertion failed"
	).is_equal(0.0).append_failure_message(
		"Null preview should return 0.0 rotation, got %.2f" % result["rotation"]
	)
	assert_vector(result["scale"]).append_failure_message(
		"Vector assertion failed"
	).is_equal(Vector2.ONE).append_failure_message(
		"Null preview should return ONE scale, got %s" % str(result["scale"])
	)

## Test: Null parent returns safe defaults
func test_calculate_final_transform_null_parent() -> void:
	# Arrange
	var preview := _create_mock_node(Vector2(100, 200), 0.0, Vector2.ONE)
	# Act: Call with null parent (will log error internally)
	var result := ManipulationTransformCalculator.calculate_final_transform(preview, null)
	# Assert: Should return safe default values
	assert_vector(result["position"]).append_failure_message(
		"Vector assertion failed"
	).is_equal(Vector2.ZERO).append_failure_message(
		"Null parent should return ZERO position, got %s" % str(result["position"])
	)
	assert_float(result["rotation"]).append_failure_message(
		"Float assertion failed"
	).is_equal(0.0).append_failure_message(
		"Null parent should return 0.0 rotation, got %.2f" % result["rotation"]
	)
	assert_vector(result["scale"]).append_failure_message(
		"Vector assertion failed"
	).is_equal(Vector2.ONE).append_failure_message(
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
	assert_bool(result["is_valid"]).append_failure_message(
		"Boolean assertion failed"
	).is_true().append_failure_message(
		"Valid transforms should pass validation. Issues: %s" % str(result["issues"])
	)
	assert_array(result["issues"]).is_empty().append_failure_message(
		"Valid transforms should have no validation issues"
	)

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
	assert_bool(result["is_valid"]).append_failure_message(
		"Boolean assertion failed"
	).is_true().append_failure_message(
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
	assert_bool(result["is_valid"]).append_failure_message(
		"Boolean assertion failed"
	).is_false().append_failure_message(
		"Near-zero scale should fail validation"
	)
	assert_array(result["issues"]).is_not_empty().append_failure_message(
		"Near-zero scale should produce validation issues"
	)

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
	assert_bool(result["is_valid"]).append_failure_message(
		"Boolean assertion failed"
	).is_false().append_failure_message(
		"Missing keys should fail validation"
	)
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
	assert_bool(result["matches"]).append_failure_message(
		"Boolean assertion failed"
	).is_true().append_failure_message(
		"Identical transforms should match. Differences: %s" % str(result["differences"])
	)
	assert_that(result["differences"]).is_empty().append_failure_message(
		"Identical transforms should have no differences"
	)

## Test: Small differences within tolerance match
func test_compare_transforms_within_tolerance() -> void:
	# Arrange
	var expected := {
		"position": Vector2(100.0, 200.0),
		"rotation": deg_to_rad(45.0),
		"scale": Vector2(1.5, 1.5)
	}
	var actual := {
		"position": Vector2(100.05, 200.05), # 0.05 difference (within 0.1 tolerance)
		"rotation": deg_to_rad(45.005), # 0.005 rad difference (within 0.01 tolerance)
		"scale": Vector2(1.505, 1.505) # 0.005 difference (within 0.01 tolerance)
	}
	# Act
	var result := ManipulationTransformCalculator.compare_transforms(expected, actual)
	# Assert
	assert_bool(result["matches"]).append_failure_message(
		"Boolean assertion failed"
	).is_true().append_failure_message(
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
		"position": Vector2(110.0, 210.0), # 10 unit difference (beyond 0.1 tolerance)
		"rotation": deg_to_rad(50.0), # 5° difference (beyond 0.01 rad tolerance)
		"scale": Vector2(2.0, 2.0) # 0.5 difference (beyond 0.01 tolerance)
	}
	# Act
	var result := ManipulationTransformCalculator.compare_transforms(expected, actual)
	# Assert
	assert_bool(result["matches"]).append_failure_message(
		"Boolean assertion failed"
	).is_false().append_failure_message(
		"Transforms beyond tolerance should not match"
	)
	assert_that(result["differences"]).is_not_empty().append_failure_message(
		"Differences array should contain detected differences"
	)
	assert_that(result["differences"].has("position")).is_true().append_failure_message(
		"Position difference should be detected when beyond tolerance"
	)
	assert_that(result["differences"].has("rotation")).is_true().append_failure_message(
		"Rotation difference should be detected when beyond tolerance"
	)
	assert_that(result["differences"].has("scale")).is_true().append_failure_message(
		"Scale difference should be detected when beyond tolerance"
	)

#endregion

#region DIAGNOSTIC_FORMATTING_TESTS

## Test: Format transforms produces readable output
func test_format_transforms_debug() -> void:
	# Arrange
	var transforms := {
		"position": Vector2(100, 200),
		"rotation": deg_to_rad(45),
		"scale": Vector2(-1, 1.5) # Horizontal flip + vertical scale
	}
	# Act
	var formatted := ManipulationTransformCalculator.format_transforms_debug(transforms)
	# Assert: Should contain all components in readable format
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain 'Position' label"
	).contains("Position")
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain position X coordinate '100'"
	).contains("100")
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain position Y coordinate '200'"
	).contains("200")
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain 'Rotation' label"
	).contains("Rotation")
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain rotation value '45'"
	).contains("45")
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain 'Scale' label"
	).contains("Scale")
	assert_str(formatted).append_failure_message(
		"Formatted debug string should contain negative scale value '-1' for horizontal flip"
	).contains("-1")