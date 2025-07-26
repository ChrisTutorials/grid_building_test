extends GdUnitTestSuite

var dummy_targeting_state: GridTargetingState = GridTargetingState.new()

# Returns [Node parent, DragBuildManager | null internal_var]
func _create_test_parent_node(with_existing: bool) -> Array:
	var parent: Node = Node.new()
	add_child(parent)

	var internal_var: DragBuildManager = null

	if with_existing:
		var existing: DragBuildManager = DragBuildManager.new()
		existing.name = "DragBuild"
		existing.targeting_state = dummy_targeting_state
		parent.add_child(existing)
		internal_var = existing

	return [parent, internal_var]

# Parameterized test case
func test_lazy_load_drag_build_manager_case(with_existing: bool, expected_child_count: int, test_parameters := [
	[false, 1],  # create new
	[true, 1],   # reuse existing
]):
	var result: Array = _create_test_parent_node(with_existing)
	var parent: Node = result[0]
	var internal_var: DragBuildManager = result[1]

	var loaded: DragBuildManager = GBLazyLoadUtils.get_or_create_component(
		parent,
		internal_var,
		DragBuildManager,
		"DragBuild",
		func(comp):
			comp.targeting_state = dummy_targeting_state
	)

	assert_that(loaded).is_not_null()
	assert_that(loaded).is_instanceof(DragBuildManager)
	assert_that(loaded.targeting_state).is_equal(dummy_targeting_state)
	assert_that(parent.get_child_count()).is_equal(expected_child_count)
