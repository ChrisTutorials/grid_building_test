extends GdUnitTestSuite


func test_test_composition_container_loads_and_has_placement_rules() -> void:
	# 1) Use GBTestConstants preloaded reference
	var repo_res: GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER
	assert_object(repo_res).is_not_null().append_failure_message("GBTestConstants.TEST_COMPOSITION_CONTAINER must be a valid resource")
	var pr: Array = repo_res.get_placement_rules()
	var pr_count: int = pr.size() if pr else 0
	print("[TEST_DIAG] GBTestConstants.TEST_COMPOSITION_CONTAINER placement_rules_count=%s" % str(pr_count))
	assert_int(pr_count).is_greater(0).append_failure_message("Expected repo composition container to contain placement rules")

	# 2) Duplicate and verify deep-duplicate preserves placement_rules
	var dup: GBCompositionContainer = repo_res.duplicate(true)
	assert_object(dup).is_not_null()
	var pr_dup: Array = dup.get_placement_rules()
	var pr_dup_count: int = pr_dup.size() if pr_dup else 0
	print("[TEST_DIAG] duplicated container placement_rules_count=%s" % str(pr_dup_count))
	assert_int(pr_dup_count).is_greater(0).append_failure_message("Duplicated container should retain placement rules")

	# 3) Load from disk by path to ensure ResourceLoader returns expected data
	var path: String = "res://test/grid_building_test/resources/composition_containers/test_composition_container.tres"
	var loaded: Resource = ResourceLoader.load(path)
	assert_object(loaded).append_failure_message("ResourceLoader failed to load %s" % path).is_not_null()
	var pr_loaded: Array = loaded.get_placement_rules() if loaded and loaded.has_method("get_placement_rules") else []
	var pr_loaded_count: int = pr_loaded.size() if pr_loaded else 0
	print("[TEST_DIAG] ResourceLoader loaded placement_rules_count=%s" % str(pr_loaded_count))
	assert_int(pr_loaded_count).is_greater(0).append_failure_message("Loaded resource should have placement rules")
