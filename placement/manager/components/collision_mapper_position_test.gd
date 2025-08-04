class_name CollisionMapperPositionTest
extends GdUnitTestSuite

## Tests that CollisionMapper calculates collision positions relative to the target position (positioner),
## not the preview object's current world position. This ensures indicators appear at the correct locations
## where the object will be placed, not where the preview object currently exists.

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	logger = GBDoubleFactory.create_test_logger()
	targeting_state = auto_free(GridTargetingState.new(auto_free(GBOwnerContext.new())))
	tile_map_layer = GBDoubleFactory.create_test_tile_map_layer(self)
	targeting_state.target_map = tile_map_layer
	
	# Create positioner and set it to a specific target position
	positioner = auto_free(Node2D.new())
	positioner.global_position = Vector2(32, 32)  # Target position at tile (2, 2) with 16x16 tiles
	targeting_state.positioner = positioner
	
	collision_mapper = CollisionMapper.new(targeting_state, logger)

func after_test():
	if collision_mapper:
		collision_mapper = null

## Test that CollisionPolygon2D collision detection uses positioner position, not object's current position
func test_collision_polygon_uses_target_position():
	# Create a CollisionPolygon2D with simple rectangle shape at origin
	var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	
	# Position the collision polygon at a different location than the target
	collision_polygon.global_position = Vector2(100, 100)  # Far from target position
	
	# Setup collision mapper
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	test_indicator.shape = auto_free(RectangleShape2D.new())
	collision_mapper.setup(test_indicator, {})
	
	# Get collision positions - should be relative to positioner (32, 32), not object position (100, 100)
	var result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	
	# Debug: print actual results to understand what's happening
	print("Positioner position: ", positioner.global_position)
	print("Collision polygon position: ", collision_polygon.global_position)
	print("Result keys: ", result.keys())
	
	# The collision should be detected at tiles around the positioner position (32, 32)
	# With positioner at (32, 32) and shape spanning -8 to +8, it should affect tiles around (2, 2)
	var expected_tiles = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2)]
	
	# Verify that collision is detected at positioner position, not object's current position
	assert_that(result.keys()).append_failure_message("Should detect collision at target position").contains_same(expected_tiles)
	assert_that(result).append_failure_message("Should not detect collision at object's current position").not_contains_keys([Vector2i(6, 6)])  # 100/16 = 6

## Test that CollisionObject2D shapes use positioner position for collision detection
func test_collision_object_uses_target_position():
	# Create CollisionObject2D with shape
	var static_body: StaticBody2D = auto_free(StaticBody2D.new())
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rectangle_shape: RectangleShape2D = auto_free(RectangleShape2D.new())
	rectangle_shape.size = Vector2(16, 16)
	collision_shape.shape = rectangle_shape
	collision_shape.position = Vector2(0, 0)  # Centered on object
	static_body.add_child(collision_shape)
	
	# Position the object far from target position
	static_body.global_position = Vector2(200, 200)
	
	# Create test setup using the correct constructor
	var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(static_body, Vector2(0, 0), logger)
	
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	test_indicator.shape = auto_free(RectangleShape2D.new())
	collision_mapper.setup(test_indicator, {static_body: test_setup})
	
	# Get collision positions - should be relative to positioner (32, 32)
	var result = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map_layer)
	
	# Should detect collision at positioner position, not object's current position
	var expected_tile = Vector2i(2, 2)  # positioner at 32, 32 -> tile 2, 2
	
	print("CollisionObject2D result keys: ", result.keys())
	
	assert_that(result.keys()).append_failure_message("Should detect collision at target position").contains([expected_tile])
	assert_that(result.keys()).append_failure_message("Should not detect collision at object's current position").not_contains([Vector2i(12, 12)])  # 200/16 = 12

## Test position calculation with different positioner positions
func test_collision_position_follows_positioner_movement():
	# Test different positioner positions
	# Note: shape spans from -4 to +4, so it affects tiles based on overlap with 16x16 grid
	var test_cases = [
		[Vector2(0, 0), Vector2i(-1, -1)],    # At origin, shape from -4,-4 to 4,4 affects tile (-1,-1)
		[Vector2(16, 16), Vector2i(0, 0)],    # At 16,16, shape from 12,12 to 20,20 affects tile (0,0)
		[Vector2(48, 64), Vector2i(2, 3)]     # At 48,64, shape from 44,60 to 52,68 affects tile (2,3)
	]
	
	for test_case in test_cases:
		var positioner_pos = test_case[0] as Vector2
		var expected_tile = test_case[1] as Vector2i
		
		# Move positioner to test position
		positioner.global_position = positioner_pos
		
		# Create simple collision polygon
		var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
		collision_polygon.polygon = PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		])
		collision_polygon.global_position = Vector2(1000, 1000)  # Far from any expected position
		
		# Setup and test
		var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
		test_indicator.shape = auto_free(RectangleShape2D.new())
		collision_mapper.setup(test_indicator, {})
		
		var result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
		
		print("Positioner pos: %s, Expected: %s, Actual: %s" % [positioner_pos, expected_tile, result.keys()])
		assert_that(result.keys()).append_failure_message("Should detect collision at expected tile for positioner position %s" % positioner_pos).contains([expected_tile])
