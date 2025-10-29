## Unit tests for CollisionGeometryUtils with rotated objects
##
## PURPOSE: Isolate and test the root cause of indicator multiplication bug when objects are rotated.
##
## CRITICAL BUG: When moving a rotated object, indicators are multiplied (26 → 52 → 78).
## Root cause hypothesis: Rotated shapes generate larger axis-aligned bounding boxes, causing
## more tiles to be detected than the actual shape occupies.
##
## Test strategy:
## 1. Test build_shape_transform() with rotation to verify transform composition
## 2. Test that rotated shapes produce correct polygon representations
## 3. Test that tile range calculation accounts for rotation correctly
## 4. Test that overlap detection works correctly with rotated shapes

extends GdUnitTestSuite

# Test constants
const TILE_SIZE: Vector2 = Vector2(16, 16)
const SHAPE_SIZE: Vector2 = Vector2(32, 32)  # 2x2 tiles when unrotated
const ROTATION_45_DEG: float = PI / 4.0
const ROTATION_90_DEG: float = PI / 2.0
const ORIGIN: Vector2 = Vector2.ZERO


# Helper: Create a test collision object with rotation
func _create_test_object(rotation_radians: float) -> Node2D:
	var obj := Node2D.new()
	auto_free(obj)
	obj.rotation = rotation_radians
	obj.global_position = ORIGIN
	return obj


# Helper: Create a test shape owner (child node)
func _create_shape_owner(parent: Node2D, local_position: Vector2 = Vector2.ZERO) -> Node2D:
	var shape_owner := Node2D.new()
	parent.add_child(shape_owner)
	shape_owner.position = local_position
	return shape_owner


#region TRANSFORM COMPOSITION TESTS


## Test: build_shape_transform with no rotation produces identity + position
## Setup: Object at origin with no rotation, shape owner at origin
## Act: Build shape transform
## Assert: Transform has no rotation, origin at object's global_position
func test_build_shape_transform_no_rotation() -> void:
	var obj := _create_test_object(0.0)
	obj.global_position = Vector2(100, 200)
	var shape_owner := _create_shape_owner(obj)

	var transform := CollisionGeometryUtils.build_shape_transform(obj, shape_owner)

	# Transform should have object's position as origin
	(
		assert_vector(transform.origin) \
		. append_failure_message(
			(
				"Transform origin should match object position. Expected %s, got %s"
				% [str(obj.global_position), str(transform.origin)]
			)
		) \
		. is_equal(obj.global_position)
	)

	# Transform should have no rotation (basis is identity)
	var expected_rotation := 0.0
	var actual_rotation := transform.get_rotation()
	(
		assert_float(actual_rotation) \
		. append_failure_message(
			(
				"Transform should have no rotation. Expected %.2f°, got %.2f°"
				% [rad_to_deg(expected_rotation), rad_to_deg(actual_rotation)]
			)
		) \
		. is_equal_approx(expected_rotation, 0.01)
	)


## Test: build_shape_transform with 90° rotation applies rotation correctly
## Setup: Object rotated 90° at origin, shape owner at origin
## Act: Build shape transform
## Assert: Transform has 90° rotation applied
func test_build_shape_transform_90_degree_rotation() -> void:
	var obj := _create_test_object(ROTATION_90_DEG)
	obj.global_position = Vector2(100, 200)
	var shape_owner := _create_shape_owner(obj)

	var transform := CollisionGeometryUtils.build_shape_transform(obj, shape_owner)

	# Transform should have 90° rotation
	var actual_rotation := transform.get_rotation()
	(
		assert_float(actual_rotation) \
		. append_failure_message(
			(
				"Transform should have 90° rotation. Expected %.2f°, got %.2f°"
				% [rad_to_deg(ROTATION_90_DEG), rad_to_deg(actual_rotation)]
			)
		) \
		. is_equal_approx(ROTATION_90_DEG, 0.01)
	)


## Test: build_shape_transform with 45° rotation applies rotation correctly
## Setup: Object rotated 45° at origin, shape owner at origin
## Act: Build shape transform
## Assert: Transform has 45° rotation applied
func test_build_shape_transform_45_degree_rotation() -> void:
	var obj := _create_test_object(ROTATION_45_DEG)
	obj.global_position = Vector2(100, 200)
	var shape_owner := _create_shape_owner(obj)

	var transform := CollisionGeometryUtils.build_shape_transform(obj, shape_owner)

	# Transform should have 45° rotation
	var actual_rotation := transform.get_rotation()
	(
		assert_float(actual_rotation) \
		. append_failure_message(
			(
				"Transform should have 45° rotation. Expected %.2f°, got %.2f°"
				% [rad_to_deg(ROTATION_45_DEG), rad_to_deg(actual_rotation)]
			)
		) \
		. is_equal_approx(ROTATION_45_DEG, 0.01)
	)


## Test: build_shape_transform with shape owner offset applies offset in rotated space
## Setup: Object rotated 90°, shape owner offset by (16, 0) local
## Act: Build shape transform
## Assert: Transform origin includes rotated offset (should be (100, 216) for 90° rotation)
func test_build_shape_transform_with_shape_owner_offset_rotated() -> void:
	var obj := _create_test_object(ROTATION_90_DEG)
	obj.global_position = Vector2(100, 200)
	var shape_owner := _create_shape_owner(obj, Vector2(16, 0))  # Offset in local space

	var transform := CollisionGeometryUtils.build_shape_transform(obj, shape_owner)

	# With 90° rotation, local offset (16, 0) becomes world offset (0, 16)
	# So final origin should be (100, 200) + (0, 16) = (100, 216)
	var expected_origin := Vector2(100, 216)
	(
		assert_vector(transform.origin) \
		. append_failure_message(
			(
				"Transform origin should include rotated shape owner offset. Expected %s, got %s"
				% [str(expected_origin), str(transform.origin)]
			)
		) \
		. is_equal_approx(expected_origin, Vector2(0.1, 0.1))
	)


#endregion

#region POLYGON CONVERSION TESTS


## Test: Rectangle shape converts to correct polygon when unrotated
## Setup: 32x32 rectangle at origin, no rotation
## Act: Convert to polygon
## Assert: Polygon has 4 vertices forming a 32x32 rectangle centered at origin
func test_rectangle_to_polygon_no_rotation() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SHAPE_SIZE

	var transform := Transform2D()
	transform.origin = ORIGIN

	var polygon := GBGeometryMath.convert_shape_to_polygon(shape, transform)

	# Should have 4 vertices for rectangle
	(
		assert_int(polygon.size()) \
		. append_failure_message(
			"Rectangle polygon should have 4 vertices, got %d" % polygon.size()
		) \
		. is_equal(4)
	)

	# Calculate bounding box of polygon
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	var polygon_size := max_point - min_point

	# Polygon should cover 32x32 area
	(
		assert_vector(polygon_size) \
		. append_failure_message(
			"Unrotated rectangle polygon should be 32x32. Got %s" % str(polygon_size)
		) \
		. is_equal_approx(SHAPE_SIZE, Vector2(0.1, 0.1))
	)


## Test: Rectangle shape converts to correct polygon when rotated 45°
## Setup: 32x32 rectangle at origin, rotated 45°
## Act: Convert to polygon
## Assert: Polygon has 4 vertices, bounding box is larger due to rotation (45.25x45.25)
func test_rectangle_to_polygon_45_degree_rotation() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SHAPE_SIZE

	var transform := Transform2D()
	transform = transform.rotated(ROTATION_45_DEG)
	transform.origin = ORIGIN

	var polygon := GBGeometryMath.convert_shape_to_polygon(shape, transform)

	# Should have 4 vertices for rectangle
	(
		assert_int(polygon.size()) \
		. append_failure_message(
			"Rectangle polygon should have 4 vertices, got %d" % polygon.size()
		) \
		. is_equal(4)
	)

	# Calculate bounding box of rotated polygon
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	var polygon_bounds_size := max_point - min_point

	# CRITICAL: Rotated 45° rectangle has larger axis-aligned bounding box
	# For a 32x32 square rotated 45°, diagonal = 32 * sqrt(2) ≈ 45.25
	var expected_bounds_diagonal := SHAPE_SIZE.x * sqrt(2.0)

	# Both width and height of bounds should be approximately the diagonal
	(
		assert_float(polygon_bounds_size.x) \
		. append_failure_message(
			(
				"Rotated 45° rectangle bounding box width should be ~%.2f (diagonal). Got %.2f"
				% [expected_bounds_diagonal, polygon_bounds_size.x]
			)
		) \
		. is_equal_approx(expected_bounds_diagonal, 1.0)
	)

	(
		assert_float(polygon_bounds_size.y) \
		. append_failure_message(
			(
				"Rotated 45° rectangle bounding box height should be ~%.2f (diagonal). Got %.2f"
				% [expected_bounds_diagonal, polygon_bounds_size.y]
			)
		) \
		. is_equal_approx(expected_bounds_diagonal, 1.0)
	)


## Test: Rectangle shape converts to correct polygon when rotated 90°
## Setup: 32x32 rectangle at origin, rotated 90°
## Act: Convert to polygon
## Assert: Polygon has 4 vertices, bounding box is still 32x32 (just rotated, no size change)
func test_rectangle_to_polygon_90_degree_rotation() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SHAPE_SIZE

	var transform := Transform2D()
	transform = transform.rotated(ROTATION_90_DEG)
	transform.origin = ORIGIN

	var polygon := GBGeometryMath.convert_shape_to_polygon(shape, transform)

	# Should have 4 vertices for rectangle
	(
		assert_int(polygon.size()) \
		. append_failure_message(
			"Rectangle polygon should have 4 vertices, got %d" % polygon.size()
		) \
		. is_equal(4)
	)

	# Calculate bounding box of rotated polygon
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	var polygon_bounds_size := max_point - min_point

	# For a SQUARE rotated 90°, bounding box should be same size (32x32)
	(
		assert_vector(polygon_bounds_size) \
		. append_failure_message(
			(
				"Square rotated 90° should have same bounding box (32x32). Got %s"
				% str(polygon_bounds_size)
			)
		) \
		. is_equal_approx(SHAPE_SIZE, Vector2(0.1, 0.1))
	)


#endregion

#region BOUNDING BOX VS ACTUAL SHAPE COVERAGE


## Test: CRITICAL - Unrotated 32x32 shape should cover exactly 2x2 = 4 tiles
## Setup: 32x32 rectangle at tile (0,0), 16x16 tiles, no rotation
## Act: Calculate which tiles the shape overlaps
## Expected: Exactly 4 tiles (2x2 grid)
##
## This establishes the baseline: unrotated shape = 4 tiles
func test_unrotated_rectangle_covers_4_tiles() -> void:
	# This test will need TileMapLayer - add TODO for now
	# TODO: Implement with actual tile overlap calculation
	pass


## Test: CRITICAL - Rotated 45° 32x32 shape should still cover approximately 4 tiles
## Setup: 32x32 rectangle at tile (0,0), 16x16 tiles, rotated 45°
## Act: Calculate which tiles the shape overlaps
## Expected: ~4-6 tiles (actual shape coverage, not bounding box)
##
## BUG HYPOTHESIS: Current implementation uses axis-aligned bounding box which is 45x45,
## causing it to detect 3x3 = 9 tiles instead of the actual ~4-6 tiles the shape covers
func test_rotated_45_degree_rectangle_covers_similar_tiles() -> void:
	# This test will need TileMapLayer - add TODO for now
	# TODO: Implement with actual tile overlap calculation
	pass


## Test: CRITICAL - Rotated 90° 32x32 SQUARE should cover exactly 2x2 = 4 tiles
## Setup: 32x32 square at tile (0,0), 16x16 tiles, rotated 90°
## Act: Calculate which tiles the shape overlaps
## Expected: Exactly 4 tiles (rotation doesn't change coverage for a square)
##
## This verifies that 90° rotation of a SQUARE should produce identical tile coverage
func test_rotated_90_degree_square_covers_4_tiles() -> void:
	# This test will need TileMapLayer - add TODO for now
	# TODO: Implement with actual tile overlap calculation
	pass


#endregion

#region DIAGNOSTIC HELPERS


## Helper: Format transform for debugging
func _format_transform(transform: Transform2D) -> String:
	return (
		"origin=%s rotation=%.1f° scale=%s"
		% [str(transform.origin), rad_to_deg(transform.get_rotation()), str(transform.get_scale())]
	)


## Helper: Format polygon bounds for debugging
func _format_polygon_bounds(polygon: PackedVector2Array) -> String:
	if polygon.size() == 0:
		return "empty"

	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	var size := max_point - min_point
	return "min=%s max=%s size=%s" % [str(min_point), str(max_point), str(size)]

#endregion
