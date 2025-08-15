extends GdUnitTestSuite

var _injector : GBInjectorSystem

const TEST_CONTAINER : GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")


# Move this mock class outside the test functions, but no decorators:
class MockInjectableNode:
	extends Node
	var called_with = null

	func resolve_gb_dependencies(p_container : GBCompositionContainer):
		called_with = p_container

func before_test():
	# Use the preloaded TEST_CONTAINER if available; otherwise create a simple fallback
	var container := TEST_CONTAINER if TEST_CONTAINER != null else GBCompositionContainer.new()
	_injector = auto_free(GBInjectorSystem.new(container))
	_injector.name = "GBInjectorSystem"
	add_child(_injector)

func test_should_inject_existing_nodes_on_ready() -> void:
	var node : Node = auto_free(MockInjectableNode.new())
	node.name = "MockInjectableNode"
	add_child_to_root(node)

	await get_tree().process_frame

	assert_that(node.called_with).append_failure_message("Expected to call resolve_gb_dependencies with TEST_CONTAINER").is_equal(TEST_CONTAINER)


func test_should_inject_newly_added_nodes() -> void:

	await get_tree().process_frame  # Let injector resolve first

	var node : Node = auto_free(MockInjectableNode.new())
	node.name = "MockInjectableNode"
	add_child_to_root(node)

	await get_tree().process_frame  # Wait for new nodes to resolve

	assert_that(node.called_with).append_failure_message("Expected to call resolve_gb_dependencies with TEST_CONTAINER").is_equal(TEST_CONTAINER)


func test_should_inject_subtree_nodes() -> void:
	# Create a parent mock node with a child mock node
	var parent_node := MockInjectableNode.new()
	parent_node.name = "MockInjectableNode"
	var child_node := MockInjectableNode.new()
	child_node.name = "MockInjectableNode_Child"
	parent_node.add_child(child_node)


	await get_tree().process_frame  # Let injector initialize

	# Add parent_node (with child) to scene tree root
	add_child_to_root(parent_node)

	await get_tree().process_frame  # Wait for injection to propagate

	# Both parent and child should be injected recursively
	assert_that(parent_node.called_with).append_failure_message("Expected to call resolve_gb_dependencies with TEST_CONTAINER").is_equal(TEST_CONTAINER)
	assert_that(child_node.called_with).append_failure_message("Expected to call resolve_gb_dependencies with TEST_CONTAINER").is_equal(TEST_CONTAINER)


func test_should_inject_child_when_parent_lacks_resolve_method() -> void:
	# Create a plain Node (no resolve_gb_dependencies)
	var parent_node := Node.new()
	parent_node.name = "MockInjectableNode_Parent"

	# Child with resolve_gb_dependencies method
	var child_node := MockInjectableNode.new()
	child_node.name = "MockInjectableNode_Child"
	parent_node.add_child(child_node)

	await get_tree().process_frame  # Let injector initialize

	# Add parent_node (which lacks resolve method) with child to scene root
	add_child_to_root(parent_node)

	await get_tree().process_frame  # Wait for injection propagation

	# The child should still be injected despite parent lacking resolve method
	assert_that(child_node.called_with).append_failure_message("Expected to call resolve_gb_dependencies with TEST_CONTAINER").is_equal(TEST_CONTAINER)


func add_child_to_root(node: Node) -> void:
	get_tree().get_root().add_child(node)
	node.owner = get_tree().get_root()


func test_injects_nodes_added_to_configured_roots() -> void:
	# Parameterized-style test: verify injection happens when nodes are added to
	# (1) the default scene root, and (2) a custom configured injection root.

	# Prepare custom scope and ensure it's in the scene
	var custom_scope : Node = auto_free(Node.new())
	custom_scope.name = "CustomScope"
	add_child_to_root(custom_scope)

	var roots := [ get_tree().get_root(), custom_scope ]

	for root in roots:
		if root != get_tree().get_root():
			_injector.injection_roots = [ root ]

		await get_tree().process_frame # Let injector initialize and connect signals

		# Add a mock injectable node to the scoped root
		var node := MockInjectableNode.new()
		node.name = "MockInjectableNode"
		# Add to either the scene root or the custom scope accordingly
		if root == get_tree().get_root():
			add_child_to_root(node)
		else:
			root.add_child(node)
			node.owner = root

		await get_tree().process_frame # Wait for new node injection

		assert_that(node.called_with).append_failure_message("Expected to call resolve_gb_dependencies with TEST_CONTAINER").is_equal(TEST_CONTAINER)

		# Cleanup node only; keep injector alive for next iteration
		if is_instance_valid(node):
			node.queue_free()

	# Final cleanup of injector and custom scope after loop completes
	if is_instance_valid(_injector):
		_injector.queue_free()
	if is_instance_valid(custom_scope):
		custom_scope.queue_free()
