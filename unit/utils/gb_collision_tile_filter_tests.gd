extends GdUnitTestSuite

# Tests for GBCollisionTileFilter utility functions.

func test_adjust_rect_tile_range_makes_even_width_odd() -> void:
	var center: Vector2i = Vector2i(10, 10)
	# Rectangle 32 wide (2 tiles at 16) -> even; expect expansion to 3 tiles
	var tile_size: Vector2 = Vector2(16, 16)
	var rect_size: Vector2 = Vector2(32, 48) # width even (2 tiles), height 3 tiles already odd (48/16=3)
	var start: Vector2i = Vector2i(9, 9)
	var end_exclusive: Vector2i = Vector2i(11, 13) # 2x4 initial window (improper)
	var adjusted: Dictionary = GBCollisionTileFilter.adjust_rect_tile_range(rect_size, tile_size, center, start, end_exclusive)
	var new_start: Vector2i = adjusted["start"]
	var new_end: Vector2i = adjusted["end_exclusive"]
	var width_tiles: int = new_end.x - new_start.x
	var height_tiles: int = new_end.y - new_start.y
	assert_int(width_tiles).is_equal(3)
	assert_int(height_tiles).is_equal(3)
	assert_int(new_start.x).is_equal(center.x - 1)
	assert_int(new_start.y).is_equal(center.y - 1)

func test_circle_tile_allowed_filters_far_corner() -> void:
	var tile_size: Vector2 = Vector2(16, 16)
	var radius: float = 24.0
	var center: Vector2 = Vector2(0, 0)
	var near_tile_center: Vector2 = Vector2(16, 16) # inside allowance (radius + 8)
	var far_tile_center: Vector2 = Vector2(40, 40) # outside
	assert_bool(GBCollisionTileFilter.circle_tile_allowed(center, radius, near_tile_center, tile_size)).is_true()
	assert_bool(GBCollisionTileFilter.circle_tile_allowed(center, radius, far_tile_center, tile_size)).is_false()
