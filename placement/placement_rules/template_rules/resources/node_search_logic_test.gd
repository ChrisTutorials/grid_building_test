## Test suite for NodeSearchLogic pure logic class.
## Tests pure functions without complex object setup.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

var test_nodes: Array[Node]

func before_test() -> void:
	# Create test nodes for searching
	test_nodes = []
	
	var node1 = auto_free(Node2D.new())
	node1.name = "TestNode1"
	test_nodes.append(node1)
	
	var node2 = auto_free(Node2D.new())
	node2.name = "TestNode2"
	test_nodes.append(node2)
	
	var node3 = auto_free(Node2D.new())
	node3.name = "TestNode3"
	test_nodes.append(node3)
	
	# Add scripts to some nodes
	var script1 = auto_free(GDScript.new())
	script1.source_code = "extends Node2D"
	script1.reload()
	node1.set_script(script1)
	
	var script2 = auto_free(GDScript.new())
	script2.source_code = "extends Node2D"
	script2.reload()
	node2.set_script(script2)
	
	# Add nodes to groups
	node1.add_to_group("GroupA")
	node2.add_to_group("GroupA")
	node3.add_to_group("GroupB")

func after_test() -> void:
	# Clean up test nodes - auto_free handles this automatically
	test_nodes.clear()

## COMPREHENSIVE PARAMETERIZED TESTS - Following DRY principles

### Name Search Tests
@warning_ignore("unused_parameter")
func test_name_search_scenarios(
	search_name: String,
	expected_count: int,
	expected_node_name: String,
	test_parameters := [
		["TestNode1", 1, "TestNode1"],
		["TestNode2", 1, "TestNode2"],
		["TestNode3", 1, "TestNode3"],
		["TestNode", 0, ""],  # Exact match only
		["NonExistent", 0, ""],
		["", 0, ""]
	]
) -> void:
	var found_nodes = NodeSearchLogic.find_nodes_by_name(test_nodes, search_name)
	assert_int(found_nodes.size()).is_equal(expected_count)
	
	if expected_count > 0:
		assert_object(found_nodes[0]).is_not_null()
		assert_str(found_nodes[0].name).is_equal(expected_node_name)

### Script Search Tests
@warning_ignore("unused_parameter")
func test_script_search_scenarios(
	script_name: String,
	expected_count: int,
	expected_has_script: bool,
	test_parameters := [
		["TestNode1.gd", 1, true],
		["TestNode2.gd", 1, true],
		["TestNode3.gd", 0, false],  # No script
		["NonExistent.gd", 0, false],
		["", 0, false]
	]
) -> void:
	var found_nodes = NodeSearchLogic.find_nodes_by_script(test_nodes, script_name)
	assert_int(found_nodes.size()).is_equal(expected_count)
	
	if expected_count > 0:
		assert_object(found_nodes[0]).is_not_null()
		assert_bool(found_nodes[0].get_script() != null).is_equal(expected_has_script)

### Group Search Tests
@warning_ignore("unused_parameter")
func test_group_search_scenarios(
	group_name: String,
	expected_count: int,
	expected_nodes: Array[Node],
	test_parameters := [
		["GroupA", 2, [0, 1]],  # test_nodes[0] and test_nodes[1]
		["GroupB", 1, [2]],     # test_nodes[2]
		["NonExistentGroup", 0, []],
		["", 0, []]
	]
) -> void:
	var found_nodes = NodeSearchLogic.find_nodes_by_group(test_nodes, group_name)
	assert_int(found_nodes.size()).is_equal(expected_count)
	
	# Verify expected nodes are found
	for expected_index in expected_nodes:
		assert_bool(found_nodes.has(test_nodes[expected_index])).is_true()

### Class Search Tests
@warning_ignore("unused_parameter")
func test_class_search_scenarios(
	cls_name: String,
	expected_count: int,
	expected_class: String,
	test_parameters := [
		["Node2D", 3, "Node2D"],
		["Node", 0, ""],  # Node2D is the actual class, not Node
		["NonExistentClass", 0, ""],
		["", 0, ""]
	]
) -> void:
	var found_nodes = NodeSearchLogic.find_nodes_by_class(test_nodes, cls_name)
	assert_int(found_nodes.size()).is_equal(expected_count)
	
	if expected_count > 0:
		for node in found_nodes:
			assert_str(node.get_class()).is_equal(expected_class)

### Property Search Tests
@warning_ignore("unused_parameter")
func test_property_search_scenarios(
	property_name: String,
	property_value: Variant,
	expected_count: int,
	setup_property: bool,
	test_parameters := [
		["custom_property", "test_value", 1, true],
		["non_existent_property", "value", 0, false],
		["", "value", 0, false]
	]
) -> void:
	# Setup property if needed
	if setup_property:
		test_nodes[0].set(property_name, property_value)
	
	var found_nodes = NodeSearchLogic.find_nodes_by_property(test_nodes, property_name, property_value)
	assert_int(found_nodes.size()).is_equal(expected_count)
	
	if expected_count > 0:
		assert_object(found_nodes[0]).is_not_null()

### Method Result Search Tests
@warning_ignore("unused_parameter")
func test_method_result_search_scenarios(
	method_name: String,
	expected_result: Variant,
	expected_count: int,
	setup_method: bool,
	test_parameters := [
		["test_method", "expected_result", 1, true],
		["non_existent_method", "value", 0, false],
		["", "value", 0, false]
	]
) -> void:
	# Setup method if needed
	if setup_method:
		test_nodes[0].set_meta(method_name, func(): return expected_result)
	
	var found_nodes = NodeSearchLogic.find_nodes_by_method_result(test_nodes, method_name, expected_result)
	assert_int(found_nodes.size()).is_equal(expected_count)
	
	if expected_count > 0:
		assert_object(found_nodes[0]).is_not_null()

### Script Name Tests
@warning_ignore("unused_parameter")
func test_script_name_scenarios(
	node_index: int,
	expected_empty: bool,
	expected_contains: String,
	test_parameters := [
		[0, false, "TestNode1"],  # Has script
		[2, true, ""],            # No script
		[-1, true, ""]            # Invalid index
	]
) -> void:
	var node = test_nodes[node_index] if node_index >= 0 and node_index < test_nodes.size() else null
	var script_name = NodeSearchLogic.get_script_name(node)
	
	if expected_empty:
		assert_str(script_name).is_empty()
	else:
		assert_str(script_name).is_not_empty()
		assert_str(script_name).contains(expected_contains)

### Validation Tests
@warning_ignore("unused_parameter")
func test_validation_scenarios(
	search_method: int,
	search_string: String,
	expected_valid: bool,
	expected_error_contains: String,
	test_parameters := [
		[0, "valid_string", true, ""],
		[1, "another_valid", true, ""],
		[0, "", false, "cannot be empty"],  # Empty string invalid
		[-1, "any_string", false, "must be non-negative"],  # Negative method invalid
		[-5, "any_string", false, "must be non-negative"]   # Very negative method invalid
	]
) -> void:
	var issues = NodeSearchLogic.validate_search_params(search_method, search_string)
	assert_bool(issues.is_empty()).is_equal(expected_valid)
	
	if not expected_valid:
		assert_str(issues[0]).contains(expected_error_contains)

### Complex Operation Tests

func test_combine_search_results() -> void:
	var result1 = [test_nodes[0], test_nodes[1]]
	var result2 = [test_nodes[1], test_nodes[2]]  # Overlap with result1
	
	var combined = NodeSearchLogic.combine_search_results([result1, result2])
	
	assert_int(combined.size()).is_equal(3)  # Should have all unique nodes
	assert_bool(combined.has(test_nodes[0])).is_true()
	assert_bool(combined.has(test_nodes[1])).is_true()
	assert_bool(combined.has(test_nodes[2])).is_true()

func test_filter_search_results() -> void:
	var filter_func = func(node: Node) -> bool: return node.name.begins_with("TestNode")
	
	var filtered = NodeSearchLogic.filter_search_results(test_nodes, filter_func)
	
	assert_int(filtered.size()).is_equal(3)
	for node in filtered:
		assert_str(node.name).contains("TestNode")

func test_sort_search_results() -> void:
	var sort_func = func(a: Node, b: Node) -> bool: return a.name < b.name
	
	var sorted = NodeSearchLogic.sort_search_results(test_nodes, sort_func)
	
	assert_int(sorted.size()).is_equal(3)
	assert_str(sorted[0].name).is_equal("TestNode1")
	assert_str(sorted[1].name).is_equal("TestNode2")
	assert_str(sorted[2].name).is_equal("TestNode3")
