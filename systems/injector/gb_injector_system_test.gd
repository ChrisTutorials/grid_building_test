extends GdUnitTestSuite

var composition_container := GBCompositionContainer.new()

# Move this mock class outside the test functions, but no decorators:
class MockInjectableNode:
	extends Node
	var called_with = null
	func resolve_gb_dependencies(arg):
		called_with = arg

func test_should_inject_existing_nodes_on_ready() -> void:
	var node := MockInjectableNode.new()
	add_child_to_root(node)

	var injector := GBInjectorSystem.new()
	injector.composition_container = composition_container
	add_child_to_root(injector)
	
	await get_tree().process_frame
	
	assert_that(node.called_with).is_equal(composition_container)

func test_should_inject_newly_added_nodes() -> void:

	var injector := GBInjectorSystem.new()
	injector.composition_container = composition_container
	add_child_to_root(injector)
	
	await get_tree().process_frame # Let injector resolve first
	
	var node := MockInjectableNode.new()
	add_child_to_root(node)
	
	await get_tree().process_frame # Wait for new nodes to resolve
	
	assert_that(node.called_with).is_equal(composition_container)

func test_should_inject_subtree_nodes() -> void:
	# Create a parent mock node with a child mock node
	var parent_node := MockInjectableNode.new()
	var child_node := MockInjectableNode.new()
	parent_node.add_child(child_node)
	
	var injector := GBInjectorSystem.new()
	injector.composition_container = composition_container
	add_child_to_root(injector)
	
	await get_tree().process_frame # Let injector initialize
	
	# Add parent_node (with child) to scene tree root
	add_child_to_root(parent_node)
	
	await get_tree().process_frame # Wait for injection to propagate
	
	# Both parent and child should be injected recursively
	assert_that(parent_node.called_with).is_equal(composition_container)
	assert_that(child_node.called_with).is_equal(composition_container)

func test_should_inject_child_when_parent_lacks_resolve_method() -> void:
	# Create a plain Node (no resolve_gb_dependencies)
	var parent_node := Node.new()
	
	# Child with resolve_gb_dependencies method
	var child_node := MockInjectableNode.new()
	parent_node.add_child(child_node)
	
	var injector := GBInjectorSystem.new()
	injector.composition_container = composition_container
	add_child_to_root(injector)
	
	await get_tree().process_frame # Let injector initialize
	
	# Add parent_node (which lacks resolve method) with child to scene root
	add_child_to_root(parent_node)
	
	await get_tree().process_frame # Wait for injection propagation
	
	# The child should still be injected despite parent lacking resolve method
	assert_that(child_node.called_with).is_equal(composition_container)

func add_child_to_root(node: Node) -> void:
	get_tree().get_root().add_child(node)
	node.owner = get_tree().get_root()
