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
	item_container = auto_free(Node2D.new())
	# Add item_container as a child to simulate the relationship
	owner_node.add_child(item_container)
	assert_object(item_container).is_not_null()
	assert_object(item_container.get_script()).is_not_null()


func after_test():
	inventory_locator = null


func test_search_by_name():
	inventory_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.NODE_NAME, search_owner_name)
	# The NodeLocator looks for nodes that match the search criteria
	# We need to make sure the search target matches what we're looking for
	var search_target = auto_free(Node2D.new())
	search_target.name = search_owner_name
	owner_node.add_child(search_target)

	var found_node = inventory_locator.locate_container(owner_node, TEST_CONTAINER.get_logger())

	assert_object(found_node).is_not_null()


func test_search_by_script_name_with_extension():
	var item_container_script_name = script_name
	inventory_locator = NodeLocator.new(
		NodeLocator.SEARCH_METHOD.SCRIPT_NAME_WITH_EXTENSION, item_container_script_name
	)

	var found_script_name: StringName = inventory_locator.get_script_name(item_container)
	assert_str(found_script_name).is_not_empty()
	var found_node_1 = inventory_locator.locate_container(owner_node, TEST_CONTAINER.get_logger())
	assert_object(found_node_1).is_not_null()
	assert_object(found_node_1.get_script()).is_same(owner_node.get_script())


@warning_ignore("unused_parameter")


func test_get_script_name(
	p_node: Object, p_expected: String, test_parameters := [[item_container, script_name]]
) -> void:
	var test_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.SCRIPT_NAME_WITH_EXTENSION, "")
	var found: String = test_locator.get_script_name(p_node)
	assert_str(found).is_equal(p_expected)


func test_search_by_is_in_group():
	var search_group = owner_group
	inventory_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.IS_IN_GROUP, search_group)
	item_container.add_to_group(search_group)

	var found_node_1 = inventory_locator.locate_container(owner_node, TEST_CONTAINER.get_logger())

	assert_object(found_node_1).is_not_null()
