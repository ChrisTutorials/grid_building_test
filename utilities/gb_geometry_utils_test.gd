## GdUnit TestSuite for GBGeometryUtils.get_all_collision_objects
extends GdUnitTestSuite





func test_get_all_collision_objects_for_all_scenes():
	var scene_uids := [
		"uid://bqq7otaevtlqu", # offset_logo.tscn
		"uid://blgwelirrimr1", # test_rect_15_tiles.tscn
		"uid://j5837ml5dduu",  # test_elipse.tscn
		"uid://b82nv1wlsv8wa", # test_skew_rotation_rect.tscn
		"uid://de1ck3cvdtww0", # 2d_test_object.tscn
		"uid://c673aj2ivgljp", # smithy.tscn
		"uid://cdb08p0iy3vjy", # test_pillar.tscn
		"uid://be5sd0kpcvj0h", # isometric_building.tscn
	]
	for scene_uid in scene_uids:
		print("[DEBUG] Attempting to load UID: ", scene_uid)
		var scene_resource = load(scene_uid)
		assert_object(scene_resource).append_failure_message("Scene failed to load: " + scene_uid).is_not_null()
		var scene_instance = auto_free(scene_resource.instantiate())
		add_child(scene_instance)
		var collision_objects = GBGeometryUtils.get_all_collision_objects(scene_instance)
		assert_int(collision_objects.size()).is_greater(0)
