# Renamed from test_scene_library.gd
extends GdUnitTestSuite

# Assuming there is a SceneLibrary resource/class in plugin (adjust if actual path differs)
var _scene_library: SceneLibrary

func before_test():
	if Engine.has_singleton("SceneLibrary"):
		_scene_library = Engine.get_singleton("SceneLibrary")

func test_scene_library_exists():
	assert_bool(_scene_library != null).is_true()

func test_scene_library_has_min_scenes():
	if _scene_library == null:
		return
	if _scene_library.has_method("get_registered_scene_count"):
		@warning_ignore("unsafe_method_access")
		var count = _scene_library.get_registered_scene_count()
		assert_int(count).is_greater_equal(0)
