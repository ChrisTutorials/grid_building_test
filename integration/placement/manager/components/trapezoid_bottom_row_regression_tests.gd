## Refactored trapezoid test that uses public API instead of private properties
extends GdUnitTestSuite

const DebugHelpers = preload("res://test/grid_building_test/integration/placement/manager/components/debug_helpers/test_debug_helpers.gd")

var _test_env: AllSystemsTestEnvironment
var _collision_mapper: CollisionMapper

func before_test() -> void:
	# Use standardized test environment setup
	_test_env = DebugHelpers.create_minimal_test_environment(self)
	
	# Get targeting state from the environment  
	var targeting_state: GridTargetingState = _test_env.grid_targeting_system.get_state()
	var container: GBCompositionContainer = _test_env.get_container()
	
	# Create collision mapper with proper cleanup
	_collision_mapper = auto_free(CollisionMapper.new(targeting_state, container.get_logger()))

func after_test() -> void:
	# Clean up to prevent orphans
	if _collision_mapper:
		_collision_mapper = null
	
	# Test environment will be auto-freed by the test framework
	_test_env = null

func test_trapezoid_bottom_row_coverage() -> void:
	"""Test that trapezoid produces expected bottom row coverage using public API"""
	
	# Create trapezoid shape that should produce 4 bottom-row tiles
	var trapezoid_body: StaticBody2D = _create_trapezoid_test_object()
	
	# Get the CollisionPolygon2D child to pass to collision mapper
	var collision_polygon: CollisionPolygon2D = trapezoid_body.get_child(0) as CollisionPolygon2D
	
	# Use the specific polygon method for CollisionPolygon2D 
	var tile_positions_dict: Dictionary[Vector2i, Array] = _collision_mapper.get_tile_offsets_for_collision_polygon(collision_polygon, _test_env.tile_map_layer)
	var tile_positions: Array = tile_positions_dict.keys()
	
	assert_bool(tile_positions.size() > 0)\
		.append_failure_message("Expected trapezoid to generate at least some tile positions")\
		.is_true()
	
	# Analyze coverage by row
	var coverage_by_row: Dictionary = _analyze_tile_coverage_by_row(tile_positions)
	var rows: Array = coverage_by_row.keys()
	rows.sort()
	
	assert_bool(rows.size() >= 2)\
		.append_failure_message("Expected trapezoid to span at least 2 rows, got %d rows: %s" % [rows.size(), str(rows)])\
		.is_true()
	
	# Get bottom row
	var bottom_row: int = rows[rows.size() - 1]
	var bottom_row_tiles: Array = coverage_by_row[bottom_row]
	bottom_row_tiles.sort()
	
	# Expected bottom row should have 4 tiles: x = -2, -1, 0, 1
	var expected_bottom_tiles: Array = [-2, -1, 0, 1]
	
	assert_int(bottom_row_tiles.size())\
		.append_failure_message("Expected 4 bottom-row tiles, got %d: %s (all positions: %s)" % [bottom_row_tiles.size(), str(bottom_row_tiles), str(tile_positions)])\
		.is_equal(4)
	
	# Verify specific expected tiles are present
	for expected_x : int in expected_bottom_tiles:
		assert_bool(bottom_row_tiles.has(expected_x))\
			.append_failure_message("Missing expected bottom-row tile x=%d; actual bottom row: %s" % [expected_x, str(bottom_row_tiles)])\
			.is_true()
	
	# Verify problematic x=2 tile is not present (should have zero geometric overlap)
	assert_bool(not bottom_row_tiles.has(2))\
		.append_failure_message("Bottom row should not include x=2 as it has zero geometric overlap; actual: %s" % str(bottom_row_tiles))\
		.is_true()

func test_trapezoid_total_coverage_reasonable() -> void:
	"""Unit test: Trapezoid should generate reasonable total tile count"""
	
	var trapezoid_body: StaticBody2D = _create_trapezoid_test_object()
	# Get the CollisionPolygon2D child to pass to collision mapper
	var collision_polygon: CollisionPolygon2D = trapezoid_body.get_child(0) as CollisionPolygon2D
	
	# Use the specific polygon method for CollisionPolygon2D 
	var tile_positions_dict: Dictionary[Vector2i, Array] = _collision_mapper.get_tile_offsets_for_collision_polygon(collision_polygon, _test_env.tile_map_layer)
	var tile_positions: Array = tile_positions_dict.keys()
	
	# Trapezoid should generate between 7-15 tiles total (reasonable range)
	assert_int(tile_positions.size())\
		.append_failure_message("Trapezoid should generate reasonable tile count, got %d tiles" % tile_positions.size())\
		.is_between(7, 15)

## Helper to create trapezoid test object with proper cleanup
func _create_trapezoid_test_object() -> StaticBody2D:
	var trapezoid_body: StaticBody2D = auto_free(StaticBody2D.new())
	trapezoid_body.name = "TrapezoidTestBody"
	trapezoid_body.collision_layer = 1  # Set collision layer for mask matching
	
	var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	trapezoid_body.add_child(collision_polygon)
	
	# Define trapezoid that spans from x=-32 to x=32 at bottom, x=-16 to x=16 at top
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -12),  # Top left
		Vector2(16, -12),   # Top right  
		Vector2(32, 12),    # Bottom right
		Vector2(-32, 12)    # Bottom left
	])
	
	_test_env.positioner.add_child(trapezoid_body)
	return trapezoid_body

## DRY helper to analyze tile coverage by row
func _analyze_tile_coverage_by_row(tile_positions: Array) -> Dictionary:
	var coverage_by_row: Dictionary = {}
	
	for pos : Vector2i in tile_positions:
		var row: int = pos.y
		if not coverage_by_row.has(row):
			coverage_by_row[row] = []
		coverage_by_row[row].append(pos.x)
	
	return coverage_by_row

## Parameterized test for different trapezoid shapes
@warning_ignore("unused_parameter")
func test_trapezoid_shapes(shape_name: String, polygon: PackedVector2Array, expected_bottom_count: int, expected_total_range: Array) -> void:
	"""Parameterized test for different trapezoid configurations"""
	
	var trapezoid_body: StaticBody2D = auto_free(StaticBody2D.new())
	trapezoid_body.name = "Trapezoid_%s" % shape_name
	
	var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	collision_polygon.polygon = polygon
	trapezoid_body.add_child(collision_polygon)
	_test_env.positioner.add_child(trapezoid_body)
	
	var collision_objects: Array[Node2D] = [trapezoid_body]
	var tile_positions_dict: Dictionary[Vector2i, Array] = _collision_mapper.get_collision_tile_positions_with_mask(collision_objects, trapezoid_body.collision_layer)
	var tile_positions: Array = tile_positions_dict.keys()
	var coverage_by_row: Dictionary = _analyze_tile_coverage_by_row(tile_positions)
	
	# Verify total tile count is in expected range
	assert_int(tile_positions.size())\
		.append_failure_message("%s: Expected %d-%d total tiles, got %d" % [shape_name, expected_total_range[0], expected_total_range[1], tile_positions.size()])\
		.is_between(expected_total_range[0], expected_total_range[1])
	
	# Verify bottom row tile count
	var rows: Array = coverage_by_row.keys()
	if rows.size() > 0:
		rows.sort()
		var bottom_row: int = rows[rows.size() - 1]
		var bottom_count: int = coverage_by_row[bottom_row].size()
		
		assert_int(bottom_count)\
			.append_failure_message("%s: Expected %d bottom-row tiles, got %d" % [shape_name, expected_bottom_count, bottom_count])\
			.is_equal(expected_bottom_count)

## Test parameters for parameterized trapezoid shapes
func test_trapezoid_shapes_parameters() -> Array:
	return [
		["Standard", PackedVector2Array([Vector2(-16, -12), Vector2(16, -12), Vector2(32, 12), Vector2(-32, 12)]), 4, [8, 15]],
		["Wide", PackedVector2Array([Vector2(-8, -12), Vector2(8, -12), Vector2(48, 12), Vector2(-48, 12)]), 6, [10, 20]],
		["Narrow", PackedVector2Array([Vector2(-24, -12), Vector2(24, -12), Vector2(16, 12), Vector2(-16, 12)]), 2, [6, 12]]
	]
