# Test Suite: Debug Coordinate Transformation Tests
# This test suite validates coordinate transformation logic between world space,
# local space, and tilemap coordinates. It examines polygon positioning, tile
# offset calculations, and collision geometry utilities to ensure correct
# spatial transformations in the grid building system.

extends GdUnitTestSuite

#region Constants
const TILEMAP_SIZE: int = 40
const TILE_SIZE: Vector2i = GBTestConstants.DEFAULT_TILE_SIZE_I
const POLYGON_POSITION: Vector2 = GBTestConstants.DEFAULT_TEST_POSITION
const CENTER_TILE: Vector2i = Vector2i(20, 20)
#endregion

#region Test Variables
var polygon_points: PackedVector2Array = PackedVector2Array([
	Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
])
var expected_world_points: PackedVector2Array = PackedVector2Array([
	Vector2(304, 304), Vector2(336, 304), Vector2(336, 336), Vector2(304, 336)
])
#endregion

#region Test Functions
## Debug test to examine coordinate transformation issue
func test_debug_coordinate_transformation() -> void:
	# Create the same setup as the failing tests
	var test_map: TileMapLayer = GodotTestFactory.create_top_down_tile_map_layer(self, TILEMAP_SIZE)
	var polygon: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, polygon_points)
	polygon.position = POLYGON_POSITION

	# Validate basic setup
 assert_that(polygon.position)
  .append_failure_message("Polygon position should be set correctly").is_equal(POLYGON_POSITION)
 assert_that(polygon.global_position).append_failure_message("Polygon global_position should match position when no parent transform").is_equal(POLYGON_POSITION)
 assert_that(polygon.polygon)
  .append_failure_message("Polygon points should match input").is_equal(polygon_points)
 assert_that(test_map.tile_set.tile_size)
  .append_failure_message("Tilemap should have 16x16 tile size").is_equal(TILE_SIZE)
 assert_that(test_map.position)
  .append_failure_message("Tilemap should be at origin").is_equal(Vector2.ZERO)
 assert_that(test_map.global_position)
  .append_failure_message("Tilemap global_position should be at origin").is_equal(Vector2.ZERO)

	# Test coordinate transformations
	var center_tile: Vector2i = test_map.local_to_map(test_map.to_local(polygon.global_position))
 assert_that(world_points[i]).append_failure_message( "World point %d should be transformed correctly: expected %s, got %s" % [i, expected_world_points[i], world_points[i]]) # Test CollisionGeometryUtils.compute_polygon_tile_offsets var tile_size: Vector2 = Vector2(test_map.tile_set.tile_size) var tile_shape_val: int = test_map.tile_set.tile_shape assert_that(tile_size).is_equal(Vector2(TILE_SIZE)).append_failure_message("Tile size should be 16x16") assert_that(tile_shape_val).append_failure_message("Tile shape should be square").is_equal(TileSet.TILE_SHAPE_SQUARE) var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, tile_shape_val, test_map) assert_that(offsets.size()).is_greater_equal(1).append_failure_message( "Should produce tile offsets for 32x32 polygon at center of tilemap. " + "World points: %s, tile_size: %s, center_tile: %s, result: %s" % [world_points, tile_size, center_tile, offsets]).is_equal(expected_world_points[i])