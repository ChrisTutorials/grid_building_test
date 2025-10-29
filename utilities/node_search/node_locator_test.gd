# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

var inventory_locator: NodeLocator
var owner_node: Node2D
var item_container: Node2D

var search_owner_name: String = "Inventory"
var script_name: String = "test_item_container_owner.gd"
var owner_group: String = "InventoryGroup"


func before_test() -> void:
	owner_node = auto_free(Node2D.new())
	owner_node.name = search_owner_name
	owner_node.add_to_group(owner_group)
	add_child(owner_node)

	# Create item_container with a script so NodeLocator can find it
	item_container = auto_free(Node2D.new())
	# Create a dummy script resource for testing
	var dummy_script := GDScript.new()
	dummy_script.source_code = "extends Node2D"
	dummy_script.reload()
	item_container.set_script(dummy_script)

	# Add item_container as a child to simulate the relationship
	owner_node.add_child(item_container)
	# Ensure both parent and child share the search group for group search test expectations
	item_container.add_to_group(owner_group)
	assert_object(item_container).is_not_null()
	assert_object(item_container.get_script()).is_not_null()


func after_test() -> void:
	inventory_locator = null


func test_search_by_name() -> void:
	# Use pure logic class for searching
	var search_target : Node2D = auto_free(Node2D.new())
	search_target.name = search_owner_name
	owner_node.add_child(search_target)

	var all_nodes: Array[Node] = [owner_node, item_container, search_target]
	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_name(all_nodes, search_owner_name)

	assert_int(found_nodes.size()).append_failure_message(
		"find_nodes_by_name('%s') expected 2 (owner + target) got %d -> %s" % [search_owner_name, found_nodes.size(), found_nodes]
	).is_equal(2)
	assert_object(found_nodes[0]).append_failure_message(
		"First found node should not be null").is_not_null()


func test_search_by_script_name_with_extension() -> void:
	# Use pure logic class for searching. Provide detailed failure diagnostics.
	var all_nodes: Array[Node] = [owner_node, item_container]
	# NodeSearchLogic.get_script_name returns the script file name if resource_path set, else NodeName.gd fallback.
	# Our in-memory script has no resource_path so expected synthetic fallback "<NodeName>.gd"
		var expected_script_name := "%s.gd" % item_container.name
		var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_script(all_nodes, expected_script_name)
		
		assert_int(found_nodes.size()).append_failure_message(
			"find_nodes_by_script('%s') expected 1 got %d -> %s (available=%s)" % [expected_script_name, found_nodes.size(), found_nodes, all_nodes]
		).is_equal(1)
		
		if found_nodes.size() == 1:
			assert_object(found_nodes[0]).append_failure_message(
				"Result node was null despite size==1").is_not_null()
			assert_object(found_nodes[0].get_script()).append_failure_message(
				"Result node script should not be null").is_not_null()

@warning_ignore("unused_parameter")
func test_get_script_name(
	p_node: Object, p_expected: String, test_parameters := [[item_container, "%s.gd" % item_container.name]]
) -> void:
	# Use pure logic class for getting script name with contextual message on mismatch
	var found: String = NodeSearchLogic.get_script_name(p_node)
	assert_str(found).append_failure_message("Script name mismatch expected=%s got=%s" % [p_expected, found])
		.is_equal(p_expected)


func test_search_by_is_in_group() -> void:
	# Use pure logic class for searching. Provide group membership diagnostics.
	var all_nodes: Array[Node] = [owner_node, item_container]
	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_group(all_nodes, owner_group)
	var membership: Array[String] = []
	for n in all_nodes:
		membership.append("%s:%s" % [n.name, n.is_in_group(owner_group)])
	assert_int(found_nodes.size()).append_failure_message("find_nodes_by_group('%s') expected 2 (owner + child) got %d -> %s memberships=%s" % [owner_group, found_nodes.size(), found_nodes, membership])
		.is_equal(2)
	if found_nodes.size() == 2:
		assert_object(found_nodes[0]).append_failure_message("First found node should not be null").is_not_null()
