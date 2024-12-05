# GdUnit generated TestSuite
class_name SpendMaterialsRuleGenericTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/placement/placement_rules/template_rules/spend_materials_rule_generic.gd'

var generic_rule : SpendMaterialsRuleGeneric
var building_state : BuildingState
var positioner : Node2D
var test_map : Node2D
var test_item : Resource
var test_stack : ResourceStack
var test_item_name : String = "Test Item"

func before():
	var inventory_locator = NodeLocator.new(NodeLocator.SEARCH_METHOD.SCRIPT_NAME_WITH_EXTENSION, "item_container.gd")
	
	test_item = Resource.new()
	test_stack = ResourceStack.new(test_item, 1)
	generic_rule = SpendMaterialsRuleGeneric.new(
		[test_stack],
		inventory_locator)
	
func before_test():
	test_map = auto_free(TileMap.new())
	test_map.tile_set = TileSet.new()
	test_map.tile_set.tile_size = Vector2i(16,16)
	add_child(test_map)
	
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	
	#inventory_node = create_node_with_inventory_child()
	#
	#building_state = mock(BuildingState)
	#building_state.placed_parent = self
	#do_return(node_with_inventory).on(building_state).get_placer()
	
	# Fails with Mock: assert_bool(building_state.validator.validate()).append_failure_message("Building state should pass validation before tests start").is_true()
	
func test__init() -> void:
	var rule_init = SpendMaterialsRuleGeneric.new()
	assert_object(rule_init).is_not_null()
	
func test_execute_rule_with_grid_builder_inventory(p_rule_params : RuleValidationParameters, test_parameters = [
	[create_spend_test_parameters()]
]):
	var setup_success = generic_rule.setup(p_rule_params)
	assert_bool(setup_success).append_failure_message("Was the setup call on the spend_rules_resource successful?").is_true()
	
	var fail_results : RuleResult = generic_rule.validate_condition()
	
	assert_bool(fail_results.is_successful).append_failure_message("Validation Unsuccessful? Message : "  + fail_results.reason).is_false()
	
	var item_container : ItemContainer = GBSearchUtils.find_first(p_rule_params.placer, ItemContainer)
	assert_int(item_container.try_add(test_item, 1)).append_failure_message( "Add 1 item to inventory successfully").is_equal(1)
	
	var succeed_results : RuleResult = generic_rule.validate_condition()
	
	assert_bool(succeed_results.is_successful).append_failure_message("Validation Successful when Inventory has 1 item? Message : "  + succeed_results.reason).is_true()

func test_get_material_name_from_base_item():
	var found_name = generic_rule._get_material_name(test_item)
	assert_str(found_name).is_equal(test_item_name)

func test_get_material_name_from_generic_resource():
	var test_resource = Resource.new()
	var resource_name = generic_rule._get_material_name(test_resource)
	assert_str(resource_name).is_not_null()

func test_spend_resources(p_inventory_node : Node, p_items_in_inventory : int, p_stacks_spent : int, test_parameters = [
	[null, 0, 0], # Return false because there is no container
	[auto_free(ItemContainer.new()), 0, 0],
	[auto_free(ItemContainer.new()), 1, 1]
]) -> void:
	if p_items_in_inventory > 0:
		p_inventory_node.try_add(test_item, p_items_in_inventory)
	
	var spent : Array[ResourceStack] = generic_rule.spend_resources(p_inventory_node)
	assert_int(spent.size()).is_equal(p_stacks_spent)

func create_spend_test_parameters() -> RuleValidationParameters:
	var preview_instance = auto_free(Node2D.new())
	add_child(preview_instance)
	
	return RuleValidationParameters.new(
		create_node_with_inventory_child(),
		preview_instance,
		null
	)
	
func create_node_with_inventory_child() -> Node:
	var test_node = auto_free(Node.new())
	test_node.name = "TestNode_NoInventory"
	add_child(test_node)
	
	var inventory_node = auto_free(ItemContainer.new())
	test_node.add_child(inventory_node)
	
	return test_node
