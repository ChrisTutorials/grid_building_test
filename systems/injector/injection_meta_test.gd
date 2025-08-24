extends GdUnitTestSuite


class TestInjectable:
	extends Node
	var injected_by = null
	func resolve_gb_dependencies(_p_config):
		# No-op for test, just present
		return
	
	func get_editor_issues() -> Array[String]:
		return []

func test_injection_sets_meta_and_removes_on_exit() -> void:
	# Arrange: create injector and a test node
	var _injector : GBInjectorSystem = auto_free(UnifiedTestFactory.create_test_injector(self))

	var node := TestInjectable.new()
	auto_free(node)
	# Act: add node to root so injector will run
	add_child_to_root(node)

	# Wait a frame for injection to occur
	await get_tree().process_frame

	# Assert meta was set
	var meta_key := "gb_injection_meta"
	assert_that(node.has_meta(meta_key)).is_true()
	var meta = node.get_meta(meta_key)
	assert_that(meta).is_not_null()
	assert_that(meta.has("injector_id")).is_true()

	# Act: remove node from tree (simulate exit)
	get_tree().get_root().remove_child(node)

	# Wait a frame for exit handling
	await get_tree().process_frame

	# Assert meta removed
	assert_that(node.has_meta(meta_key)).is_false()

func add_child_to_root(node: Node) -> void:
	get_tree().get_root().add_child(node)
	node.owner = get_tree().get_root()
