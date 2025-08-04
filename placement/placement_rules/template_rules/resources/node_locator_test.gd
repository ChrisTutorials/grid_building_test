# GdUnit generated TestSuite
class_name NodeLocatorTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

var inventory_locator : NodeLocator
var owner_node : TestItemContainerOwner
var item_container : Node

var search_owner_name = "Inventory"
var script_name = "test_item_container_owner.gd"
var owner_group = "InventoryGroup"

func before_test():
	owner_node = auto_free(TestItemContainerOwner.new())
	owner_node.name = search_owner_name
	owner_node.add_to_group(owner_group)
	add_child(owner_node)
	item_container = auto_free(TestItemContainerOwner.new())
	owner_node.item_container = item_container
	assert_object(owner_node.item_container).is_same(item_container)
	assert_object(item_container.get_script()).is_not_null()
	
func after_test():
	inventory_locator = null
	
func test_search_by_name():
	inventory_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.NODE_NAME, search_owner_name)
	item_container.name = search_owner_name
	
	var found_node = inventory_locator.locate_container(owner_node, GBDoubleFactory.create_test_logger())
	
	assert_object(found_node).is_not_null()
	
func test_search_by_script_name_with_extension():
	var item_container_script_name = script_name
	inventory_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.SCRIPT_NAME_WITH_EXTENSION, item_container_script_name)
	
	var found_script_name : StringName = inventory_locator.get_script_name(item_container)
	assert_str(found_script_name).is_not_empty()
	var found_node_1 = inventory_locator.locate_container(owner_node, GBDoubleFactory.create_test_logger())
	assert_object(found_node_1).is_not_null()
	assert_object(found_node_1.get_script()).is_same(owner_node.get_script())

@warning_ignore("unused_parameter")
func test_get_script_name(p_node : Object, p_expected : String, test_parameters := [
	[item_container, script_name]
]):
	var test_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.SCRIPT_NAME_WITH_EXTENSION, "")
	var found : String = test_locator.get_script_name(p_node)
	assert_str(found).is_equal(p_expected)

func test_search_by_is_in_group():
	var search_group = owner_group
	inventory_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.IS_IN_GROUP, search_group)
	item_container.add_to_group(search_group)
	
	var found_node_1 = inventory_locator.locate_container(owner_node, GBDoubleFactory.create_test_logger())
	
	assert_object(found_node_1).is_not_null()
