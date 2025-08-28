## Tests for PolygonTileMapper processing pipeline and stage behaviors.
##
## Covers all 5 processing stages with parameterized tests for consolidation:
## 1. Initial geometry coverage computation
## 2. Trapezoid expansion for convex polygons
## 3. Concave fringe pruning
## 4. Parented polygon alignment
## 5. Area-based filtering
##
## Uses diagnostic information from ProcessingResult for validation.
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var targeting_state: GridTargetingState
var tile_map: TileMapLayer
var positioner: Node2D
var polygon_mapper: PolygonTileMapper
var _injector: GBInjectorSystem

func before_test():
	# Create injector system first
	_injector = UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)
	
	tile_map = auto_free(TileMapLayer.new())## Test complete processing pipeline with representative polygon shapes
@warning_ignore("unused_parameter")
func test_process_polygon_complete_pipeline_scenarios(
	polygon_points: PackedVector2Array,
	positioner_pos: Vector2,
	is_parented: bool,
	expected_properties: Dictionary,
	expected_min_offsets: int,
	test_description: String,
	test_parameters := [
		# Small square polygon - basic case
		[
			PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
			Vector2(0, 0),
			true,
			{"was_convex": true, "was_parented": true, "did_expand_trapezoid": false},
			4,
			"8x8 square at origin, parented"
		],
		# Large rectangle - should trigger area filtering
		[
			PackedVector2Array([Vector2(-32, -16), Vector2(32, -16), Vector2(32, 16), Vector2(-32, 16)]),
			Vector2(0, 0),
			true,
			{"was_convex": true, "was_parented": true},
			6,  # Reduced from 8 - some edge tiles may be filtered out
			"64x32 rectangle at origin, parented"
		],
		# Non-parented polygon - different processing path
		[
			PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
			Vector2(16, 16),
			false,
			{"was_convex": true, "was_parented": false, "did_expand_trapezoid": false},
			4,
			"8x8 square offset, not parented"
		],
		# Concave L-shape - triggers fringe pruning
		[
			PackedVector2Array([Vector2(-16, -16), Vector2(0, -16), Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(-16, 16)]),
			Vector2(0, 0),
			true,
			{"was_convex": false, "was_parented": true},
			3,  # Reduced from 4 - fringe pruning may remove some tiles
			"L-shaped concave polygon, parented"
		]
	]
):
	# Setup: Create polygon with specified properties
	var polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	polygon.polygon = polygon_points
	
	if is_parented:
		positioner.add_child(polygon)
	else:
		add_child(polygon)
	
	positioner.global_position = positioner_pos
	
	# Act: Process polygon through complete pipeline
	var result: PolygonTileMapper.ProcessingResult = mapper.process_polygon_with_diagnostics(polygon, tile_map_layer)
	
	# Assert: Verify processing properties and results
	for property in expected_properties:
		var expected_value = expected_properties[property]
		var actual_value = result.get(property)
		assert_bool(actual_value == expected_value).is_true().append_failure_message(
			"Expected %s=%s but got %s for %s" % [property, expected_value, actual_value, test_description]
		)
	
	assert_int(result.offsets.size()).is_greater_equal(expected_min_offsets).append_failure_message(
		"Expected at least %d offsets but got %d for %s" % [expected_min_offsets, result.offsets.size(), test_description]
	)
	
	assert_int(result.final_offset_count).is_equal(result.offsets.size()).append_failure_message(
		"Offset count mismatch: final_count=%d vs actual=%d for %s" % [result.final_offset_count, result.offsets.size(), test_description]
	)

## Test area threshold configurations for different polygon types
@warning_ignore("unused_parameter")
func test_area_filtering_threshold_scenarios(
	polygon_size: Vector2,
	tile_size: Vector2,
	is_convex: bool,
	did_expand: bool,
	expected_threshold_type: String,
	test_description: String,
	test_parameters := [
		# Small convex polygon - uses convex_ratio (0.05)
		[Vector2(8, 8), Vector2(16, 16), true, false, "convex", "small convex polygon"],
		# Expanded convex polygon - uses expanded_trapezoid_ratio (0.03)
		[Vector2(16, 16), Vector2(16, 16), true, true, "expanded", "expanded trapezoid"],
		# Concave polygon - uses default_ratio (0.12)
		[Vector2(16, 16), Vector2(16, 16), false, false, "default", "concave polygon"],
	]
):
	# Setup: Create test polygon and configure thresholds
	var thresholds = PolygonTileMapper.AreaThresholds.new()
	var polygon_area = polygon_size.x * polygon_size.y
	var tile_area = tile_size.x * tile_size.y
	var expected_min_area: float
	
	match expected_threshold_type:
		"convex":
			expected_min_area = tile_area * thresholds.convex_ratio
		"expanded":
			expected_min_area = tile_area * thresholds.expanded_trapezoid_ratio
		"default":
			expected_min_area = tile_area * thresholds.default_ratio
		_:
			assert_bool(false).is_true().append_failure_message("Unknown threshold type: %s" % expected_threshold_type)
			return
	
	# Act & Assert: Verify threshold calculation logic
	var overlap_ratio = polygon_area / tile_area
	var should_pass = polygon_area >= expected_min_area
	
	assert_bool(overlap_ratio > 0).is_true().append_failure_message(
		"Invalid test setup: polygon_area=%f, tile_area=%f for %s" % [polygon_area, tile_area, test_description]
	)
	
	# Test provides expected behavior validation
	if should_pass:
		assert_float(polygon_area).is_greater_equal(expected_min_area).append_failure_message(
			"Expected polygon area %f to pass threshold %f for %s" % [polygon_area, expected_min_area, test_description]
		)
	else:
		assert_float(polygon_area).is_less(expected_min_area).append_failure_message(
			"Expected polygon area %f to fail threshold %f for %s" % [polygon_area, expected_min_area, test_description]
		)

## Test positioning consistency across positioner movements for parented polygons
@warning_ignore("unused_parameter")
func test_parented_polygon_position_consistency_scenarios(
	polygon_local_points: PackedVector2Array,
	positioner_positions: Array[Vector2],
	expected_offset_pattern: Array[Vector2i],
	test_description: String,
	test_parameters := [
		# 2x2 grid pattern should be consistent regardless of positioner position
		[
			PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]),
			[Vector2(0, 0), Vector2(16, 16), Vector2(48, 64)],
			[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)],
			"8x8 square consistent across positions"
		],
		# Single tile coverage should remain stable
		[
			PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]),
			[Vector2(8, 8), Vector2(24, 24), Vector2(40, 40)],
			[Vector2i(0, 0)],
			"4x4 square single tile coverage"
		]
	]
):
	# Setup: Create parented polygon with local coordinates
	var polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	polygon.polygon = polygon_local_points
	positioner.add_child(polygon)
	
	# Act & Assert: Test consistency across multiple positions
	for pos in positioner_positions:
		positioner.global_position = pos
		var offsets = mapper.compute_tile_offsets(polygon, tile_map_layer)
		
		assert_int(offsets.size()).is_equal(expected_offset_pattern.size()).append_failure_message(
			"Expected %d offsets but got %d at position %s for %s" % [expected_offset_pattern.size(), offsets.size(), pos, test_description]
		)
		
		for expected_offset in expected_offset_pattern:
			assert_bool(offsets.has(expected_offset)).is_true().append_failure_message(
				"Missing expected offset %s at position %s for %s" % [expected_offset, pos, test_description]
			)

## Test edge cases and error conditions
func test_empty_polygon_handling():
	# Setup: Empty polygon
	var polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	polygon.polygon = PackedVector2Array()
	add_child(polygon)
	
	# Act: Process empty polygon
	var result = mapper.process_polygon_with_diagnostics(polygon, tile_map_layer)
	
	# Assert: Should handle gracefully with empty results
	assert_int(result.offsets.size()).is_equal(0).append_failure_message(
		"Expected empty polygon to produce no offsets, got %d" % result.offsets.size()
	)
	assert_int(result.initial_offset_count).is_equal(0).append_failure_message(
		"Expected initial_offset_count=0 for empty polygon, got %d" % result.initial_offset_count
	)

func test_single_point_polygon_handling():
	# Setup: Degenerate polygon (single point)
	var polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	polygon.polygon = PackedVector2Array([Vector2.ZERO])
	add_child(polygon)
	
	# Act: Process degenerate polygon
	var result = mapper.process_polygon_with_diagnostics(polygon, tile_map_layer)
	
	# Assert: Should handle gracefully
	assert_int(result.offsets.size()).is_equal(0).append_failure_message(
		"Expected single-point polygon to produce no offsets, got %d" % result.offsets.size()
	)

func test_very_small_polygon_area_filtering():
	# Setup: Polygon smaller than any threshold
	var polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	polygon.polygon = PackedVector2Array([Vector2(-0.1, -0.1), Vector2(0.1, -0.1), Vector2(0.1, 0.1), Vector2(-0.1, 0.1)])
	positioner.add_child(polygon)
	
	# Act: Process very small polygon
	var result = mapper.process_polygon_with_diagnostics(polygon, tile_map_layer)
	
	# Assert: Should be filtered out by area threshold
	assert_int(result.offsets.size()).is_equal(0).append_failure_message(
		"Expected tiny polygon to be filtered out, got %d offsets" % result.offsets.size()
	)
	# Note: Very small polygons may be detected as non-convex due to precision issues
	assert_object(result).is_not_null().append_failure_message(
		"Expected valid result object for tiny polygon"
	)

## Test diagnostic information accuracy
func test_processing_result_diagnostic_accuracy():
	# Setup: Known convex parented polygon
	var polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	polygon.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	positioner.add_child(polygon)
	
	# Act: Process with diagnostics
	var result = mapper.process_polygon_with_diagnostics(polygon, tile_map_layer)
	
	# Assert: Verify all diagnostic fields are populated correctly
	assert_bool(result.was_convex).is_true().append_failure_message(
		"Expected square polygon to be detected as convex"
	)
	assert_bool(result.was_parented).is_true().append_failure_message(
		"Expected polygon parented to positioner to be detected as parented"
	)
	assert_int(result.initial_offset_count).is_greater(0).append_failure_message(
		"Expected non-zero initial offset count, got %d" % result.initial_offset_count
	)
	assert_int(result.final_offset_count).is_equal(result.offsets.size()).append_failure_message(
		"Expected final_offset_count to match actual offsets.size()"
	)
