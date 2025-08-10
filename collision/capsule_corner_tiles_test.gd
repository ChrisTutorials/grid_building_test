# Renamed from test_capsule_corner_tiles.gd
extends GdUnitTestSuite

func test_capsule_shape_extents():
	var capsule := GodotTestFactory.create_capsule_shape(8.0, 24.0)
	assert_float(capsule.radius).is_equal(8.0)
	assert_float(capsule.height).is_equal(24.0)
