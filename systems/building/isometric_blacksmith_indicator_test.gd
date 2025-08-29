## IsometricBlacksmithIndicatorTest
## Consolidated test verifying isometric collision → tile position mapping.
## Uses UnifiedTestFactory building system test environment (DRY vs ad-hoc demo setup).
class_name IsometricBlacksmithIndicatorTest
extends GdUnitTestSuite

const _UnifiedTestFactoryScript = preload("res://test/grid_building_test/factories/unified_test_factory.gd")
const _CollisionObjectTestFactoryScript = preload("res://test/grid_building_test/factories/collision_object_test_factory.gd")

## Regression: Blacksmith Blue diamond polygon (approx 84x48) should map to exactly 1 tile (90x50 isometric)
func test_isometric_blacksmith_indicator_single_tile() -> void:
    # Arrange
    var env := UnifiedTestFactory.create_building_system_test_environment(self)
    var tile_map: TileMapLayer = env.tile_map_layer

    # Configure tile map with demo isometric settings
    var tileset := TileSet.new()
    tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
    tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
    tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
    tileset.tile_size = Vector2i(90, 50)
    tile_map.tile_set = tileset

    # Create blacksmith building (diamond polygon) using central factory; ensure layers match demo
    var building: StaticBody2D = CollisionObjectTestFactory.create_isometric_building_with_layers(
        self, 2560, 1536, 84.0, 48.0
    )

    # Ensure targeting state knows the tilemap
    var targeting_state: GridTargetingState = env.targeting_state
    if targeting_state != null and targeting_state.has_method("set_map_objects"):
        targeting_state.set_map_objects(tile_map, [tile_map])

    # Configure collision mapper
    var indicator_manager: IndicatorManager = env.indicator_manager
    var collision_mapper: CollisionMapper = indicator_manager.get_collision_mapper()
    var test_setup: IndicatorCollisionTestSetup = UnifiedTestFactory.create_test_indicator_collision_setup(self, building)
    collision_mapper.collision_object_test_setups[building] = test_setup

    # Act
    var tile_positions: Dictionary = collision_mapper.get_collision_tile_positions_with_mask([building], building.collision_layer)
    var tile_count := tile_positions.size()

    # Debug
    print("Isometric Blacksmith Collision Mapping:")
    print("  Tile positions found: %d" % tile_count)
    print("  Expected: 1 (single tile indicator)")
    print("  Tile size: %s" % str(tileset.tile_size))
    print("  Tile shape: %d (ISOMETRIC)" % tileset.tile_shape)
    print("  Tile layout: %d (DIAMOND_DOWN)" % tileset.tile_layout)
    print("  Tile offset axis: %d (VERTICAL)" % tileset.tile_offset_axis)

    # Assert
    assert_int(tile_count).append_failure_message(
        ("Blacksmith Blue building should generate exactly 1 indicator but got %d. " +
        "Polygon should fit within a single 90x50 isometric tile. Width=84 Height=48.") % [tile_count]
    ).is_equal(1)
