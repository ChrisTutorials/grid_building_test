# Renamed from test_trapezoid.gd
extends GdUnitTestSuite

var trapezoid: Trapezoid

func before_test():
	trapezoid = Trapezoid.new()
	trapezoid.height = 10
	trapezoid.top_length = 5
	trapezoid.bottom_length = 15

func test_area_positive():
	if trapezoid.has_method("area"):
		@warning_ignore("unsafe_method_access")
		var a = trapezoid.area()
		assert_float(a).is_greater(0.0)

func test_height_assignment():
	assert_int(trapezoid.height).is_equal(10)
