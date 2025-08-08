extends GdUnitTestSuite

var targeting_state: GridTargetingState
var placement_manager: PlacementManager
var indicator_template: PackedScene

func before_test():
	# Create a minimal test setup with a TileMapLayer
	var tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	
	# Create owner context and targeting state
	var owner_context = auto_free(GBOwnerContext.new())
	targeting_state = GridTargetingState.new(owner_context)
	targeting_state.target_map = tile_map_layer
	targeting_state.positioner = auto_free(Node2D.new())
	
	# Create placement manager 
	placement_manager = auto_free(PlacementManager.new())
	placement_manager.targeting_state = targeting_state
	
	# Load the indicator template
	indicator_template = load("uid://dhox8mb8kuaxa")

## Test that created indicators have the correct global positions in the scene tree
func test_actual_indicator_positioning():
	# Create a simple test rule
	var test_rule = auto_free(TileCheckRule.new())
	test_rule.initialize_with_params("test_rule", [], [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)])
	
	# Create a collision object to trigger indicator generation
	var collision_object = auto_free(RigidBody2D.new())
	var collision_shape = auto_free(CollisionShape2D.new())
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	collision_shape.shape = rect_shape
	collision_object.add_child(collision_shape)
	
	# Position the collision object at a known location
	collision_object.global_position = Vector2(24, 24)  # Should be at tile (1,1) center
	
	# Create indicators for the collision object
	var indicators = placement_manager.create_indicators(
		[collision_object],
		[test_rule],
		placement_manager
	)
	
	# Verify we got indicators
	assert_that(indicators.size()).is_greater(0)
	
	# Check the positions of created indicators
	for i in range(min(3, indicators.size())):
		var indicator = indicators[i] as RuleCheckIndicator
		var expected_positions = [Vector2(8, 8), Vector2(24, 24), Vector2(40, 40)]  # Tile centers for (0,0), (1,1), (2,2)
		
		print("Indicator %d: global_position = %s (expected %s)" % [i, indicator.global_position, expected_positions[i]])
		
		# Check that the indicator is positioned at the expected tile center
		assert_that(indicator.global_position.x).append_failure_message("Indicator %d X position should match tile center" % i).is_equal_approx(expected_positions[i].x, 0.1)
		assert_that(indicator.global_position.y).append_failure_message("Indicator %d Y position should match tile center" % i).is_equal_approx(expected_positions[i].y, 0.1)
