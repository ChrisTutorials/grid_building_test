## Core test for isometric collision mapping accuracy
## Tests that isometric coordinate transformations don't generate excessive tile positions
class_name IsometricCollisionMappingTest
extends GdUnitTestSuite

const TestFactory = preload("res://test/grid_building_test/factories/unified_test_factory.gd")

var _injector: GBInjectorSystem
var _tile_map : TileMapLayer

func before_test():
	_injector = TestFactory.create_test_injector(self)
	_tile_map = auto_free(UnifiedTestFactory.create_isometric_tilemap(self))

## Test that isometric collision mapping generates precise tile position counts
func test_isometric_collision_mapping_precision() -> void:
	# Test data: building polygons that should generate exactly 1 tile position
	var test_buildings: Array = [
		{
			"name": "Small Diamond (Blacksmith-style)",
			"polygon": PackedVector2Array([Vector2(-42, 0), Vector2(0, -24), Vector2(42, 0), Vector2(0, 24)]),
			"expected_tiles": 1,
			"description": "84x48px diamond should fit in single 90x50 tile"
		},
		{
			"name": "Medium Diamond (Mill-style)", 
			"polygon": PackedVector2Array([Vector2(-48, -16), Vector2(0, -44), Vector2(48, -16), Vector2(0, 12)]),
			"expected_tiles": 1, # This currently fails due to excessive padding
			"description": "96x56px diamond should fit in single 90x50 tile with proper calculation"
		},
		{
			"name": "Square Building",
			"polygon": PackedVector2Array([Vector2(-40, -20), Vector2(40, -20), Vector2(40, 20), Vector2(-40, 20)]),
			"expected_tiles": 1,
			"description": "80x40px square should fit in single 90x50 tile"
		}
	]
	
	var results = {}
	var total_expected = 0
	var total_actual = 0
	
	for building_data in test_buildings:
		var building_name = building_data.name
		var polygon = building_data.polygon
		var expected_count = building_data.expected_tiles
		var description = building_data.description
		
		total_expected += expected_count
		
		# Create test building
		var building = auto_free(UnifiedTestFactory.create_static_body_with_polygon(self, polygon))
		add_child(building)
		
		# Test collision mapping
		var actual_count = get_tile_position_count(building, _tile_map)
		total_actual += actual_count
		results[building_name] = {
			"expected": expected_count,
			"actual": actual_count,
			"description": description
		}
		
		print("Building: %s" % building_name)
		print("  Description: %s" % description)
		print("  Polygon: %s" % str(polygon))
		print("  Expected tiles: %d, Actual tiles: %d" % [expected_count, actual_count])
		
		# Building will be auto-freed by GdUnit
	
	print("\nSummary:")
	print("  Total expected: %d tiles, Total actual: %d tiles" % [total_expected, total_actual])
	
	# Assert each building generates the expected tile count
	for building_name in results.keys():
		var result = results[building_name]
		assert_int(result.actual).append_failure_message(
			"Isometric collision mapping for '%s' should generate %d tile position(s) but generated %d. %s. This indicates the isometric coordinate transformation padding is too aggressive, causing false positives in adjacent tiles." % [
				building_name, result.expected, result.actual, result.description
			]
		).is_equal(result.expected)



## Get tile position count for a building using collision mapper
func get_tile_position_count(building: StaticBody2D, tilemap: TileMapLayer) -> int:
	# Create targeting state with positioner
	var targeting_state = auto_free(GridTargetingState.new(GBOwnerContext.new()))
	var positioner = auto_free(Node2D.new())
	positioner.global_position = Vector2(100, 100)  # Set position for calculations
	targeting_state.positioner = positioner
	
	# Create properly typed array for maps
	var maps_array: Array = [tilemap]
	targeting_state.set_map_objects(tilemap, maps_array)
	
	# Create collision mapper directly
	var debug_settings = auto_free(GBDebugSettings.new())
	var logger = auto_free(GBLogger.new(debug_settings))
	var collision_mapper = auto_free(CollisionMapper.new(targeting_state, logger))
	
	var test_setup = TestFactory.create_test_indicator_collision_setup(self, building)
	collision_mapper.collision_object_test_setups[building] = test_setup
	
	# Calculate tile positions
	var collision_objects: Array[Node2D] = [building]
	var tile_positions = collision_mapper.get_collision_tile_positions_with_mask(collision_objects, building.collision_layer)
	
	return tile_positions.size()

## Test that validates isometric padding reduction fix
func test_isometric_padding_fix() -> void:
	
	# Mill Big Green polygon (slightly larger than single tile)
	var mill_polygon = PackedVector2Array([Vector2(-48, -16), Vector2(0, -44), Vector2(48, -16), Vector2(0, 12)])
	var building = auto_free(UnifiedTestFactory.create_static_body_with_polygon(self, mill_polygon))
	add_child(building)
	
	var tile_count = get_tile_position_count(building, _tile_map)
	
	print("Mill Big Green Padding Fix Test:")
	print("  Polygon: %s (96x56px)" % str(mill_polygon))
	print("  Tile size: 90x50px")
	print("  Calculated tile positions: %d" % tile_count)
	print("  Expected: 1 (with proper isometric calculation)")
	
	# This should pass after the padding fix from 2 to 1
	assert_int(tile_count).append_failure_message(
		"Mill Big Green building (96x56px) should generate exactly 1 tile position with proper isometric calculation, but generated %d. The previous padding value of 2 was too aggressive and caused false positives in adjacent tiles. With padding reduced to 1, buildings that are slightly larger than a single tile should still map to 1 tile when the actual overlap calculation is precise." % tile_count
	).is_equal(1)
