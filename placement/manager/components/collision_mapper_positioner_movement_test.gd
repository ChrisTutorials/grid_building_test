extends GdUnitTestSuite

## Simple test to verify collision mapper positioning logic

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	logger = UnifiedTestFactory.create_test_logger()
	targeting_state = auto_free(GridTargetingState.new(auto_free(GBOwnerContext.new())))
	tile_map_layer = UnifiedTestFactory.create_test_tile_map_layer(self)
	targeting_state.target_map = tile_map_layer
	
	positioner = auto_free(Node2D.new())
	targeting_state.positioner = positioner
	
	collision_mapper = CollisionMapper.new(targeting_state, logger)

## Test that collision detection updates when positioner moves
func test_positioner_movement_updates_collision():
	# Test case 1: Positioner at (0, 0)
	positioner.global_position = Vector2(0, 0)
	
	var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	])
	collision_polygon.global_position = Vector2(1000, 1000)  # Far from positioner
	
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	test_indicator.shape = auto_free(RectangleShape2D.new())
	collision_mapper.setup(test_indicator, {})
	
	var result1 = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	print("Positioner at (0,0): ", result1.keys())
	
	# Test case 2: Move positioner to (32, 32)
	positioner.global_position = Vector2(32, 32)
	
	var result2 = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	print("Positioner at (32,32): ", result2.keys())
	
	# The results should be different since the positioner moved
	assert_that(result1.keys()).append_failure_message("Results should be different when positioner moves").not_equals(result2.keys())
