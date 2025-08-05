# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var test_positions = [
	Vector2(0,0), 
	Vector2(-100, 50), 
	Vector2(2000, 50000)
	]
var tile_size = Vector2(16,16)

func test_grow_rect2_to_increment():
	for pos in test_positions:
		for size in range(-100, 100, 3):
			var start_rect = Rect2(pos, Vector2(size, size))
			var rect_result : Rect2 = GBGeometryUtils.grow_rect2_to_increment(start_rect, tile_size)
			var abs_size = abs(start_rect.size)
			var abs_size_result = abs(rect_result.size)
		
			assert_bool(abs_size_result.x >= abs_size.x).append_failure_message("Size X: " + str(abs_size_result.x) + " >= " + str(abs_size.x)).is_true()
			assert(abs_size_result.x >= abs_size.x)
			assert_bool(abs_size_result.y >= abs_size.y).append_failure_message("Size Y: " + str(abs_size_result.y) + " >= " + str(abs_size.y)).is_true()
			var max_resize = abs_size + tile_size
			assert_bool(abs_size_result.x <= max_resize.x).append_failure_message("Size X: " + str(abs_size_result.x) + " <= " + str(max_resize.x)).is_true()
			assert_bool(abs_size_result.y <= max_resize.y).append_failure_message("Size Y: " + str(abs_size_result.y) + " <= " + str(max_resize.y)).is_true()
				
func test_grow_rect2_to_square():
	for pos in test_positions:
		for i in range(0,25,1):
			var rand_x = randf()
			var rand_y = randf()
	
			var start_rect = Rect2(pos, Vector2(rand_x, rand_y))
			var rect_result = GBGeometryUtils.grow_rect2_to_square(start_rect)

			assert_bool(rect_result.size >= start_rect.size).is_true()
			assert_float(rect_result.size.x).is_equal(rect_result.size.y)
