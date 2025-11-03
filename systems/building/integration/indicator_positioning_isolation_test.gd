extends GdUnitTestSuite

# Test to isolate the specific positioning issue where indicators might be using
# global positions instead of relative positions from their parent preview_instance

var indicator_manager: IndicatorManager
var test_object: Node2D
var composition_container: GBCompositionContainer
var targeting_state: GridTargetingState
var test_map: TileMapLayer
var positioner: Node2D


## Sets up minimal test environment: composition container, tile map, positioner, IndicatorManager, and test object with collision shapes.
func before_test() -> void:
	composition_container = GBTestConstants.TEST_COMPOSITION_CONTAINER

	# Create minimal tile map setup for testing
	test_map = auto_free(TileMapLayer.new())
	add_child(test_map)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(
		GBTestConstants.DEFAULT_TILE_SIZE.x, GBTestConstants.DEFAULT_TILE_SIZE.y
	)
	test_map.tile_set = tile_set

	# Create positioner for positioning tests
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	positioner.global_position = Vector2.ZERO

	# Create and configure targeting state with required properties
	targeting_state = GridTargetingState.new(GBOwnerContext.new())
	targeting_state.target_map = test_map
	targeting_state.maps = [test_map]
	targeting_state.positioner = positioner

	# Set up composition container with proper targeting state
	var container_targeting_state: GridTargetingState = composition_container.get_targeting_state()
	container_targeting_state.target_map = test_map
	container_targeting_state.maps = [test_map]
	container_targeting_state.positioner = positioner

	# Create IndicatorManager with dependency injection
	indicator_manager = auto_free(
		IndicatorManager.create_with_injection(composition_container, positioner)
	)

	# Create a basic test object with collision shape
	test_object = Node2D.new()
	test_object.position = GBTestConstants.OFF_GRID  # Set a specific non-zero position
	add_child(auto_free(test_object))  # Add to scene tree and auto_free it

	var area: Area2D = auto_free(Area2D.new())
	area.collision_layer = GBTestConstants.TEST_COLLISION_LAYER
	area.collision_mask = GBTestConstants.TEST_COLLISION_MASK
	test_object.add_child(area)

	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = GBTestConstants.DEFAULT_TILE_SIZE * 2  # 2x2 tiles (32x32)
	collision_shape.shape = rectangle_shape
	area.add_child(collision_shape)


## Cleans up indicator manager state; GdUnit handles node cleanup via auto_free().
func after_test() -> void:
	# Let GdUnit handle cleanup via auto_free()
	# Clean up indicator manager state explicitly
	if indicator_manager:
		indicator_manager.tear_down()
	pass
