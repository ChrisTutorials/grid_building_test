# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var inventory_locator: NodeLocator
var owner_node: Node2D
var item_container: Node2D

var search_owner_name = "Inventory"
var script_name = "test_item_container_owner.gd"
var owner_group = "InventoryGroup"


func before_test():
	owner_node = auto_free(Node2D.new())
	owner_node.name = search_owner_name
	owner_node.add_to_group(owner_group)
	add_child(owner_node)
	
	# Create item_container with a script so NodeLocator can find it
	item_container = auto_free(Node2D.new())
	# Create a dummy script resource for testing
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node2D"
	dummy_script.reload()
	item_container.set_script(dummy_script)
	
	# Add item_container as a child to simulate the relationship
	owner_node.add_child(item_container)
	assert_object(item_container).is_not_null()
	assert_object(item_container.get_script()).is_not_null()


func after_test():
	inventory_locator = null


func test_search_by_name():
	# Use pure logic class for searching
	var search_target = auto_free(Node2D.new())
	search_target.name = search_owner_name
	owner_node.add_child(search_target)

	var all_nodes = [owner_node, item_container, search_target]
	var found_nodes = NodeSearchLogic.find_nodes_by_name(all_nodes, search_owner_name)
	
	assert_int(found_nodes.size()).is_equal(2)  # owner_node and search_target
	assert_object(found_nodes[0]).is_not_null()


func test_search_by_script_name_with_extension():
	# Use pure logic class for searching
	var all_nodes = [owner_node, item_container]
	var found_nodes = NodeSearchLogic.find_nodes_by_script(all_nodes, item_container.get_script().get_class())
	
	assert_int(found_nodes.size()).is_equal(1)
	assert_object(found_nodes[0]).is_not_null()
	assert_object(found_nodes[0].get_script()).is_same(item_container.get_script())


@warning_ignore("unused_parameter")


func test_get_script_name(
	p_node: Object, p_expected: String, test_parameters := [[item_container, item_container.get_script().get_class()]]
) -> void:
	# Use pure logic class for getting script name
	var found: String = NodeSearchLogic.get_script_name(p_node)
	assert_str(found).is_equal(p_expected)


func test_search_by_is_in_group():
	# Use pure logic class for searching
	var all_nodes = [owner_node, item_container]
	var found_nodes = NodeSearchLogic.find_nodes_by_group(all_nodes, owner_group)
	
	assert_int(found_nodes.size()).is_equal(2)  # owner_node and item_container
	assert_object(found_nodes[0]).is_not_null()
