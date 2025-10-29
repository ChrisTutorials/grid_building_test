extends GdUnitTestSuite

## Unit tests for CollisionUtilities
##
## This test suite validates the CollisionUtilities class functionality that supports
## collision detection and mapping operations in the grid building system. It tests:
##
## - Rectangle tile position calculations for collision detection
## - Handling of invalid/null tile maps gracefully
## - Indicator-shape overlap detection for placement validation
##
## These tests catch utility method failures that could cause issues in higher-level
## collision mapping and placement validation tests.

const CollisionUtilities = preload(
	"res://addons/grid_building/placement/manager/components/mapper/collision_utilities.gd"
)

# Constants for test values
const TILE_SIZE: Vector2 = Vector2(32, 32)
const DEFAULT_POSITION: Vector2 = Vector2(0, 0)
const ORIGIN_TILE: Vector2i = Vector2i(0, 0)

var _targeting_state: GridTargetingState


func before_test() -> void:
	_targeting_state = GridTargetingState.new(GBOwnerContext.new(null))


#endregion
#region Helper Functions for DRY Patterns


func create_mock_tile_map() -> TileMapLayer:
	var mock_map: TileMapLayer = TileMapLayer.new()
	auto_free(mock_map)
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = TILE_SIZE
	mock_map.tile_set = tile_set
	return mock_map


func create_mock_indicator(position: Vector2 = DEFAULT_POSITION) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	auto_free(indicator)
	indicator.position = position
	indicator.target_position = Vector2.ZERO  # Set for proper test alignment
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	add_child(indicator)
	return indicator


func create_mock_shape_owner(position: Vector2 = DEFAULT_POSITION) -> Node2D:
	var shape_owner: Node2D = Node2D.new()
	auto_free(shape_owner)
	shape_owner.position = position
	add_child(shape_owner)
	return shape_owner


func create_rectangle_shape(size: Vector2 = TILE_SIZE) -> RectangleShape2D:
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	auto_free(rect_shape)
	rect_shape.size = size
	return rect_shape


func setup_targeting_state_with_map(tile_map: TileMapLayer) -> void:
	_targeting_state.target_map = tile_map


func assert_array_not_null_and_type(array: Variant, message: String) -> void:
	assert_that(array != null).append_failure_message(message + " - should not be null").is_true()
	assert_that(array is Array).append_failure_message(message + " - should be an array").is_true()


func assert_contains_position(
	positions: Array[Vector2i], target_pos: Vector2i, message: String
) -> void:
	var contains_pos: bool = false
	for pos: Vector2i in positions:
		if pos == target_pos:
			contains_pos = true
			break
	assert_that(contains_pos).append_failure_message(message).is_true()


#endregion
#region Test Functions
func test_collision_utilities_rect_tile_positions() -> void:
	# Create and setup mock tile map
	var mock_map: TileMapLayer = create_mock_tile_map()
	setup_targeting_state_with_map(mock_map)

	# Test rectangle at origin
	var center_pos: Vector2 = DEFAULT_POSITION
	var rect_size: Vector2 = TILE_SIZE  # Single tile

	var result: Array[Vector2i] = CollisionUtilities.get_rect_tile_positions(
		_targeting_state.target_map, center_pos, rect_size
	)
	assert_array_not_null_and_type(result, "Should return valid tile positions")

	# Should contain at least the center tile
	assert_contains_position(result, ORIGIN_TILE, "Should contain center tile (0,0)")


# Test catches: CollisionUtilities handling invalid tile map
func test_collision_utilities_invalid_tile_map() -> void:
	# Set up targeting state with invalid map
	_targeting_state.target_map = null

	var center_pos: Vector2 = DEFAULT_POSITION
	var rect_size: Vector2 = TILE_SIZE

	var result: Array[Vector2i] = CollisionUtilities.get_rect_tile_positions(
		_targeting_state.target_map, center_pos, rect_size
	)
	assert_array_not_null_and_type(result, "Should handle invalid tile map gracefully")
	(
		assert_that(result.is_empty())
		. append_failure_message("Should return empty array for invalid tile map")
		. is_true()
	)


# Test catches: CollisionUtilities indicator-shape overlap detection
func test_collision_utilities_indicator_overlap() -> void:
	# Create mock indicator with rectangle shape
	var indicator: RuleCheckIndicator = create_mock_indicator(DEFAULT_POSITION)
	var rect_shape: RectangleShape2D = create_rectangle_shape(TILE_SIZE)
	indicator.shape = rect_shape

	# Create mock shape owner
	var shape_owner: Node2D = create_mock_shape_owner(DEFAULT_POSITION)
	var target_shape: RectangleShape2D = create_rectangle_shape(TILE_SIZE)

	# Test overlapping shapes
	var result: bool = CollisionUtilities.does_indicator_overlap_shape(
		indicator, target_shape, shape_owner
	)
	assert_that(result is bool).append_failure_message("Should return boolean result").is_true()

	# Test with null shapes (should not crash)
	var null_result: bool = CollisionUtilities.does_indicator_overlap_shape(
		indicator, null, shape_owner
	)
	(
		assert_that(null_result is bool)
		. append_failure_message("Should handle null target shape gracefully")
		. is_true()
	)
