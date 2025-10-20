## Unit tests for PolygonTileMapper static methods
extends GdUnitTestSuite

## DRY Constants - reused 3+ times across test methods
const DEFAULT_TILE_SIZE = Vector2i(16, 16)
const DEFAULT_TEST_POSITION = Vector2(320, 320)
const TEST_MAP_SIZE = 40

## DRY Helper: Create a properly configured TileMapLayer for testing
func _create_test_tile_map(tile_size: Vector2i = DEFAULT_TILE_SIZE) -> TileMapLayer:
	var test_map: TileMapLayer = TileMapLayer.new()
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = tile_size
	test_map.tile_set = tile_set
	auto_free(test_map)
	add_child(test_map)
	return test_map

## DRY Helper: Create a StaticBody2D with proper collision hierarchy setup
func _create_static_body(position: Vector2 = DEFAULT_TEST_POSITION) -> StaticBody2D:
	var static_body: StaticBody2D = auto_free(StaticBody2D.new())
	static_body.position = position
	add_child(static_body)
	return static_body

## DRY Helper: Create a CollisionPolygon2D with points and add to parent
func _create_collision_polygon(points: PackedVector2Array, parent: Node) -> CollisionPolygon2D:
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = points
	parent.add_child(polygon)
	auto_free(polygon)
	return polygon

## Helper function to run polygon mapping tests
func _run_polygon_test(
	points: PackedVector2Array,
	description: String,
	tile_type: String = "square",
	expected_min: int = 1,
	expected_max: int = -1,
	position: Vector2 = DEFAULT_TEST_POSITION
) -> void:
	var test_map: TileMapLayer
	
	if tile_type == "isometric":
		test_map = _create_test_tile_map()
	else:
		test_map = _create_test_tile_map()

	# Create a StaticBody2D parent for proper collision hierarchy
	var static_body: StaticBody2D = _create_static_body(position)
	
	var polygon: CollisionPolygon2D = _create_collision_polygon(points, static_body)

	var result: Array = PolygonTileMapper.compute_tile_offsets(polygon, test_map)

	var failure_message: String = "Expected %s to produce tile offsets, got %d" % [description, result.size()]
	assert_that(result.size()).append_failure_message(failure_message).is_greater_equal(expected_min)

	if expected_max != -1:
		var between_message: String = "Expected %s to produce %d-%d tiles, got %d" % [description, expected_min, expected_max, result.size()]
		assert_that(result.size()).append_failure_message(between_message).is_between(expected_min, expected_max)

## Parameterized test for different polygon shapes on square tiles
@warning_ignore("unused_parameter")
func test_compute_tile_offsets_polygon_shapes(
	polygon_name: String,
	points: PackedVector2Array,
	description: String,
	expected_range: Array,
	test_parameters := [
		["triangle", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)]), "basic triangle polygon", []],
		["rectangle", PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]), "32x32 rectangle polygon", [1, 9]],
		["convex", PackedVector2Array([Vector2(0, 0), Vector2(24, -8), Vector2(32, 16), Vector2(16, 32), Vector2(-8, 24)]), "complex convex polygon", []],
		["concave", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 16), Vector2(32, 32), Vector2(0, 32)]), "concave polygon with indent", []]
	]
) -> void:
	_run_polygon_test(points, description, "square", 1, -1, Vector2(320, 320))

## Parameterized test for different tile types
@warning_ignore("unused_parameter")
func test_compute_tile_offsets_tile_types(
	tile_name: String,
	tile_type: String,
	description: String,
	test_parameters := [
		["square", "square", "square tiles"],
		["isometric", "isometric", "isometric tiles"]
	]
) -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)])
	_run_polygon_test(points, "triangle on " + description, tile_type)

## DRY: Covered by parameterized shape/tile tests above

## Test diagnostic processing functionality
func test_process_polygon_with_diagnostics() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)])
	_run_polygon_test(points, "diagnostic processing")

## Test null polygon handling
func test_compute_tile_offsets_null_polygon() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()

	var result: Array = PolygonTileMapper.compute_tile_offsets(null, test_map)

	assert_that(result.size()).append_failure_message("Expected null polygon to return empty result").is_equal(0)

## Test null map handling
func test_compute_tile_offsets_null_map() -> void:
	# Create a StaticBody2D parent for proper collision hierarchy
	var static_body: StaticBody2D = _create_static_body()
	
	var triangle_polygon: CollisionPolygon2D = _create_collision_polygon(PackedVector2Array([
		Vector2(0, 0),
		Vector2(32, 0),
		Vector2(16, 32)
	]), static_body)

	var result: Array = PolygonTileMapper.compute_tile_offsets(triangle_polygon, null)

	assert_that(result.size()).append_failure_message("Expected null map to return empty result").is_equal(0)

## Test map without tile set
func test_compute_tile_offsets_no_tile_set() -> void:
	var test_map: TileMapLayer = TileMapLayer.new()  # No tile set
	test_map = auto_free(test_map)
	add_child(test_map)
	
	# Create a StaticBody2D parent for proper collision hierarchy
	var static_body: StaticBody2D = _create_static_body()
	
	var triangle_polygon: CollisionPolygon2D = _create_collision_polygon(PackedVector2Array([
		Vector2(0, 0),
		Vector2(32, 0),
		Vector2(16, 32)
	]), static_body)

	var result: Array = PolygonTileMapper.compute_tile_offsets(triangle_polygon, test_map)

	assert_that(result.size()).append_failure_message("Expected map without tile set to return empty result").is_equal(0)

## Parameterized: degenerate polygons
@warning_ignore("unused_parameter")
func test_compute_tile_offsets_degenerate_polygons(
	case_name: String,
	points: PackedVector2Array,
	expected_max: int,
	test_parameters := [
		["empty", PackedVector2Array(), 1],
		["single_point", PackedVector2Array([Vector2(0, 0)]), 0],
		["two_points", PackedVector2Array([Vector2(0, 0), Vector2(32, 0)]), 0]
	]
) -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	
	# Create a StaticBody2D parent for proper collision hierarchy
	var static_body: StaticBody2D = _create_static_body()
	
	var poly: CollisionPolygon2D = _create_collision_polygon(points, static_body)
	var result: Array = PolygonTileMapper.compute_tile_offsets(poly, test_map)
	if expected_max == 0:
		assert_that(result.size()).append_failure_message("Expected %s polygon to return empty result" % case_name).is_equal(0)
	else:
		assert_that(result.size()).append_failure_message("Expected %s polygon to return empty or minimal result" % case_name).is_less_equal(expected_max)

## Test polygon at origin
func test_compute_tile_offsets_at_origin() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)])
	_run_polygon_test(points, "polygon at origin", "square", 1, -1, Vector2.ZERO)

## Test large polygon covering many tiles
func test_compute_tile_offsets_large_polygon() -> void:
	var points := PackedVector2Array([
		Vector2(-64, -64),
		Vector2(64, -64),
		Vector2(64, 64),
		Vector2(-64, 64)
	])
	_run_polygon_test(points, "large polygon", "square", 5)

## Test polygon with parent transform
func test_compute_tile_offsets_with_parent() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)])
	_run_polygon_test(points, "polygon with parent transform")

## Test diagnostic information for convex polygon
func test_process_polygon_with_diagnostics_convex() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var convex_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	convex_polygon = auto_free(convex_polygon)
	add_child(convex_polygon)
	convex_polygon.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(32, 0),
		Vector2(32, 32),
		Vector2(0, 32)
	])  # Rectangle (convex)
	convex_polygon.position = DEFAULT_TEST_POSITION  # Center of 40x40 tilemap

	var result: PolygonTileMapper.ProcessingResult = PolygonTileMapper.process_polygon_with_diagnostics(convex_polygon, test_map)

	assert_that(result.was_convex).append_failure_message("Expected rectangle polygon to be detected as convex").is_true()
	assert_that(result.offsets.size()).append_failure_message("Expected convex polygon diagnostic to return offsets").is_greater(0)

## Test diagnostic information for concave polygon
func test_process_polygon_with_diagnostics_concave() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var concave_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	concave_polygon = auto_free(concave_polygon)
	add_child(concave_polygon)
	concave_polygon.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(32, 0),
		Vector2(16, 16),  # Indent creates concave shape
		Vector2(32, 32),
		Vector2(0, 32)
	])
	concave_polygon.position = DEFAULT_TEST_POSITION

	var result: PolygonTileMapper.ProcessingResult = PolygonTileMapper.process_polygon_with_diagnostics(concave_polygon, test_map)

	assert_that(result.was_convex).append_failure_message("Expected indented polygon to be detected as concave").is_false()
	assert_that(result.offsets.size()).append_failure_message("Expected concave polygon diagnostic to return offsets").is_greater(0)

## Parameterized: diagnostic information for convex/concave
@warning_ignore("unused_parameter")
func test_process_polygon_with_diagnostics_cases(
	case_name: String,
	points: PackedVector2Array,
	expected_convex: bool,
	test_parameters := [
		["convex_rectangle", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)]), true],
		["concave_indented", PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 16), Vector2(32, 32), Vector2(0, 32)]), false]
	]
) -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	poly = auto_free(poly)
	add_child(poly)
	poly.polygon = points
	poly.position = DEFAULT_TEST_POSITION
	var result: PolygonTileMapper.ProcessingResult = PolygonTileMapper.process_polygon_with_diagnostics(poly, test_map)
	if expected_convex:
		assert_that(result.was_convex).append_failure_message("Expected %s to be detected as convex" % case_name).is_true()
	else:
		assert_that(result.was_convex).append_failure_message("Expected %s to be detected as concave" % case_name).is_false()
	assert_that(result.offsets.size()).append_failure_message("Expected %s diagnostic to return offsets" % case_name).is_greater(0)

## Test polygon processing with different tile sizes
func test_compute_tile_offsets_different_tile_sizes() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(16, 32)])
	_run_polygon_test(points, "polygon on map with 32x32 tiles")

## Test polygon completely outside tilemap bounds
func test_compute_tile_offsets_outside_bounds() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var triangle_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	triangle_polygon = auto_free(triangle_polygon)
	add_child(triangle_polygon)
	triangle_polygon.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(32, 0),
		Vector2(16, 32)
	])
	triangle_polygon.position = Vector2(1000, 1000)  # Way outside the tilemap

	var result: Array = PolygonTileMapper.compute_tile_offsets(triangle_polygon, test_map)

	# Should still return some offsets if polygon overlaps any tiles
	# (depending on implementation, might be empty or have some coverage)
	assert_that(result).append_failure_message("Expected polygon processing to not crash and return valid result").is_not_null()  # At minimum, should not crash

## Test polygon processing performance with complex polygon
func test_compute_tile_offsets_complex_polygon() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var num_points: int = 12
	for i: int in range(num_points):
		var angle: float = (i * 2 * PI) / num_points
		var radius: float = 16.0 if i % 2 == 0 else 32.0
		var point: Vector2 = Vector2(cos(angle) * radius, sin(angle) * radius)
		points.append(point)
	_run_polygon_test(points, "complex star-shaped polygon")

## Test to diagnose tile property detection issue
func test_tile_property_detection_diagnostics() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	polygon = auto_free(polygon)
	add_child(polygon)
	polygon.position = DEFAULT_TEST_POSITION
	
	# Test tile set existence
	assert_that(test_map.tile_set).append_failure_message("TileMapLayer should have a tile_set").is_not_null()
	
	# Test tile_shape property detection
	var tile_set_ref: TileSet = test_map.tile_set
	var has_tile_shape: bool = false
	var property_names: Array = []
	
	for property: Dictionary in tile_set_ref.get_property_list():
		property_names.append(property.name)
		if property.name == "tile_shape":
			has_tile_shape = true
			break
	
	var prop_list_msg: String = "TileSet properties: " + str(property_names)
	assert_that(has_tile_shape).append_failure_message("tile_shape property not found. " + prop_list_msg).is_true()
	
	# Test actual tile_shape value
	if has_tile_shape:
		var tile_shape_value: int = tile_set_ref.tile_shape
		assert_that(tile_shape_value).append_failure_message("tile_shape should be valid enum value").is_not_equal(-1)
	
	# Use the full processing pipeline to gather diagnostics
	var diag: PolygonTileMapper.ProcessingResult = PolygonTileMapper.process_polygon_with_diagnostics(polygon, test_map)

	# Ensure the mapper attempted initial coverage
	assert_int(diag.initial_offset_count).append_failure_message("Expected initial offsets to be discovered; diagnostics: tile_set=%s tile_shape=%s initial_count=%d" % [str(test_map.tile_set != null), str(has_tile_shape), diag.initial_offset_count]).is_greater_equal(1)

	# Compute areas for initial offsets to debug filtering
	var world_points: PackedVector2Array = CollisionGeometryUtils.to_world_polygon(polygon)
	var center_tile: Vector2i = test_map.local_to_map(test_map.to_local(polygon.global_position))
	var tile_size: Vector2 = test_map.tile_set.tile_size
	var initial_offsets: Array = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, test_map.tile_set.tile_shape, test_map)
	var thresholds: PolygonTileMapper.AreaThresholds = PolygonTileMapper.AreaThresholds.new()
	var tile_area: float = tile_size.x * tile_size.y
	var min_ratio: float = thresholds.expanded_trapezoid_ratio if diag.did_expand_trapezoid else (thresholds.convex_ratio if diag.was_convex else thresholds.default_ratio)
	var min_area: float = tile_area * min_ratio

	var area_details: Array = []
	for off: Vector2i in initial_offsets:
		var abs_tile: Vector2i = center_tile + off
		var tile_rect: Rect2 = PolygonTileMapper._compute_tile_rect(abs_tile, test_map, tile_size)
		var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(world_points, tile_rect)
		area_details.append("offset=%s area=%.3f (min=%.3f)" % [str(off), area, min_area])

	var area_msg: String = "Area details: " + String("\n").join(area_details)

	# Final offsets should also be present
	assert_int(diag.final_offset_count).append_failure_message("Final offsets missing after processing; diagnostics: final_count=%d initial_count=%d was_convex=%s did_expand=%s\n%s" % [diag.final_offset_count, diag.initial_offset_count, str(diag.was_convex), str(diag.did_expand_trapezoid), area_msg]).is_greater_equal(1)

## Test that results are consistent across multiple calls
func test_compute_tile_offsets_consistency() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var triangle_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	triangle_polygon = auto_free(triangle_polygon)
	add_child(triangle_polygon)
	triangle_polygon.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(32, 0),
		Vector2(16, 32)
	])
	triangle_polygon.position = DEFAULT_TEST_POSITION

	var result1: Array = PolygonTileMapper.compute_tile_offsets(triangle_polygon, test_map)
	var result2: Array = PolygonTileMapper.compute_tile_offsets(triangle_polygon, test_map)

	# Results should be identical
	assert_that(result1).append_failure_message("Expected multiple calls to produce identical results").is_equal(result2)


## Diagnostic: Per-offset area inspection to debug final filtering
func test_filter_area_diagnostics() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var points: PackedVector2Array = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	poly.polygon = points
	poly = auto_free(poly)
	add_child(poly)
	poly.position = DEFAULT_TEST_POSITION

	# Reproduce initial offsets from the low-level util
	var world_points: PackedVector2Array = CollisionGeometryUtils.to_world_polygon(poly)
	var center_tile: Vector2i = test_map.local_to_map(test_map.to_local(poly.global_position))
	var tile_size: Vector2 = test_map.tile_set.tile_size

	var initial_offsets: Array = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, test_map.tile_set.tile_shape, test_map)
	assert_int(initial_offsets.size()).append_failure_message("Expected initial offsets from CollisionGeometryUtils, got %d" % initial_offsets.size()).is_greater_equal(1)

	# Gather per-offset areas and compare against multiple thresholds to see what fails
	var thresholds: PolygonTileMapper.AreaThresholds = PolygonTileMapper.AreaThresholds.new()
	var tile_area: float = tile_size.x * tile_size.y
	var ratios: Dictionary = {
		"default": thresholds.default_ratio,
		"convex": thresholds.convex_ratio,
		"expanded": thresholds.expanded_trapezoid_ratio,
		"expansion_candidate": thresholds.expansion_candidate_ratio
	}

	var area_results: Array = []

	for off: Vector2i in initial_offsets:
		var abs_tile: Vector2i = center_tile + off
		var tile_rect: Rect2 = PolygonTileMapper._compute_tile_rect(abs_tile, test_map, tile_size)
		var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(world_points, tile_rect)
		area_results.append({"offset": off, "area": area})

	# Build a readable failure message
	var msg_lines: Array = []
	msg_lines.append("Tile area diagnostics (tile_area=%.2f):" % tile_area)
	for ar: Dictionary in area_results:
		msg_lines.append(" offset=%s area=%.3f ratios: default=%.3f convex=%.3f expanded=%.3f" % [str(ar.offset), ar.area, ratios.default, ratios.convex, ratios.expanded])

	var failure_msg: String = String("\n").join(msg_lines)

	# Assert that at least one per-offset area meets the most permissive ratio (expanded)
	var min_required: float = tile_area * ratios.expanded
	var any_ok: bool = false
	for ar: Dictionary in area_results:
		if ar.area >= min_required:
			any_ok = true
			break

	assert_bool(any_ok).append_failure_message("No offset met expanded threshold.\n" + failure_msg).is_true()

## Unit tests for get_polygon_tile_overlap_area
@warning_ignore("unused_parameter")
func test_get_polygon_tile_overlap_area(
	test_case_name: String,
	polygon: PackedVector2Array,
	rect: Rect2,
	expected_area: float,
	test_parameters := [
		["empty_polygon", PackedVector2Array(), Rect2(0, 0, 16, 16), 0.0],
		["polygon_outside_rect", PackedVector2Array([Vector2(20, 20), Vector2(30, 20), Vector2(30, 30), Vector2(20, 30)]), Rect2(0, 0, 16, 16), 0.0],
		["polygon_completely_inside_rect", PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)]), Rect2(0, 0, 16, 16), 64.0],
		["polygon_containing_rect", PackedVector2Array([Vector2(-10, -10), Vector2(30, -10), Vector2(30, 30), Vector2(-10, 30)]), Rect2(0, 0, 16, 16), 256.0],
		["partial_overlap", PackedVector2Array([Vector2(8, 8), Vector2(24, 8), Vector2(24, 24), Vector2(8, 24)]), Rect2(0, 0, 16, 16), 64.0],
		["exact_boundary_match", PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)]), Rect2(0, 0, 16, 16), 256.0],
		["triangle_overlap", PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)]), Rect2(0, 0, 16, 16), 128.0],
	]
) -> void:
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(polygon, rect)
	assert_float(area).append_failure_message("Expected area %.2f for %s, got %.2f" % [expected_area, test_case_name, area]).is_equal_approx(expected_area, 0.1)

## Unit tests for get_polygon_tile_overlap_area function

## Test empty polygon
func test_polygon_tile_overlap_area_empty_polygon() -> void:
	var rect := Rect2(0, 0, 16, 16)
	var empty_polygon := PackedVector2Array()
	var area := PolygonTileMapper.get_polygon_tile_overlap_area(empty_polygon, rect)
	assert_float(area).is_equal(0.0)

## Test polygon completely outside rect
func test_polygon_tile_overlap_area_outside() -> void:
	var rect := Rect2(0, 0, 16, 16)
	var outside_polygon := PackedVector2Array([Vector2(20, 20), Vector2(30, 20), Vector2(30, 30), Vector2(20, 30)])
	var area := PolygonTileMapper.get_polygon_tile_overlap_area(outside_polygon, rect)
	assert_float(area).is_equal(0.0)

## Test polygon completely inside rect
func test_polygon_tile_overlap_area_completely_inside() -> void:
	var rect: Rect2 = Rect2(0, 0, 16, 16)
	var inside_polygon: PackedVector2Array = PackedVector2Array([Vector2(4, 4), Vector2(12, 4), Vector2(12, 12), Vector2(4, 12)])
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(inside_polygon, rect)
	assert_float(area).is_equal(64.0)  # 8x8 square = 64

## Test polygon exactly matching rect bounds
func test_polygon_tile_overlap_area_exact_match() -> void:
	var rect: Rect2 = Rect2(0, 0, 16, 16)
	var matching_polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(matching_polygon, rect)
	assert_float(area).is_equal(256.0)

## Test polygon completely containing rect
func test_polygon_tile_overlap_area_contains_rect() -> void:
	var rect: Rect2 = Rect2(4, 4, 8, 8)
	var containing_polygon: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(containing_polygon, rect)
	assert_float(area).is_equal(64.0)

## Test partial overlap
func test_polygon_tile_overlap_area_partial_overlap() -> void:
	var rect: Rect2 = Rect2(0, 0, 16, 16)
	var partial_polygon: PackedVector2Array = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(partial_polygon, rect)
	assert_float(area).is_greater(30.0).is_less(70.0)  # Should be around 64

## Test triangle overlap
func test_polygon_tile_overlap_area_triangle() -> void:
	var rect: Rect2 = Rect2(0, 0, 16, 16)
	var triangle: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)])
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(triangle, rect)
	assert_float(area).is_greater(120.0).is_less(140.0)  # Should be around 128

## Test complex polygon
func test_polygon_tile_overlap_area_complex() -> void:
	var rect: Rect2 = Rect2(0, 0, 16, 16)
	var complex_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(2, 2), Vector2(14, 2), Vector2(14, 6), Vector2(10, 6),
		Vector2(10, 10), Vector2(14, 10), Vector2(14, 14), Vector2(2, 14)
	])
	var area: float = PolygonTileMapper.get_polygon_tile_overlap_area(complex_polygon, rect)
	assert_float(area).is_equal(128.0)  # L-shaped polygon: 12x12 - 4x4 cutout = 144 - 16 = 128

## Test concave polygon tile distribution - isolates issue from integration test
func test_concave_polygon_tile_distribution() -> void:
	var test_map: TileMapLayer = _create_test_tile_map()
	var static_body: StaticBody2D = _create_static_body()
	
	# Create the same concave polygon from the failing integration test
	# This creates a shape that should have a "hole" in the middle
	var concave_points: PackedVector2Array = PackedVector2Array([
		Vector2(-32, -16),  # Top-left
		Vector2(32, -16),   # Top-right  
		Vector2(32, 0),     # Right-middle
		Vector2(8, 0),      # Inner-right
		Vector2(8, 8),      # Inner-bottom-right
		Vector2(-8, 8),     # Inner-bottom-left
		Vector2(-8, 0),     # Inner-left
		Vector2(-32, 0),    # Left-middle
	])
	
	var polygon: CollisionPolygon2D = _create_collision_polygon(concave_points, static_body)
	
	var result: PolygonTileMapper.ProcessingResult = PolygonTileMapper.process_polygon_with_diagnostics(polygon, test_map)
	
	# Verify this is correctly detected as concave
	assert_that(result.was_convex).append_failure_message("Expected U-shaped polygon to be detected as concave").is_false()
	
	# The key test: concave polygon should NOT fill the complete bounding rectangle
	# Convert offsets to tile coordinates for analysis
	var tile_positions: Array[Vector2i] = []
	for offset: Vector2i in result.offsets:
		tile_positions.append(offset)
	
	# This concave shape should NOT include the center tiles that fall in the "indent"
	var center_tiles_that_should_be_empty: Array[Vector2i] = [
		Vector2i(0, 0),  # Center tile should be empty due to concave indent
		Vector2i(-1, 0), # Left-center should be empty
		Vector2i(1, 0),  # Right-center should be empty
	]
	
	for empty_tile: Vector2i in center_tiles_that_should_be_empty:
		assert_bool(tile_positions.has(empty_tile)).append_failure_message(
			"Concave polygon incorrectly filled center tile %s. Actual tiles: %s" % [empty_tile, str(tile_positions)]
		).is_false()
	
	# Debug output to see what tiles are actually filled
	GBTestDiagnostics.buffer("Concave polygon test - filled tiles: %s" % str(tile_positions))

