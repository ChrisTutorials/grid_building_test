## Test suite for NodeSearchLogic pure logic class.
## Tests comprehensive node search functionality including:
## - Name-based node searching with exact and partial matches
## - Script-based searching by script file names
## - Group-based searching by group membership
## - Class-based searching by nodeclass types
## - Property-based searching with custom property values
## - Method result-based searching with dynamic return values
## - Script name extraction and validation
## - Complex search result operations (combine, filter, sort)
## - Parameter validation for search operations
## Tests pure functions without complex object setup or dependencies.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

## Test constants to eliminate magic strings
const TEST_NODE_1_NAME := "TestNode1"
const TEST_NODE_2_NAME := "TestNode2"
const TEST_NODE_3_NAME := "TestNode3"
const TEST_NODE_PREFIX := "TestNode"
const GROUP_A_NAME := "GroupA"
const GROUP_B_NAME := "GroupB"
const CUSTOM_PROPERTY_NAME := "custom_property"
const TEST_METHOD_NAME := "test_method"
const TEST_SCRIPT_SOURCE := "extends Node2D\nvar custom_property = null\nfunc test_method(): return null"
const DYNAMIC_SCRIPT_TEMPLATE := "extends Node2D\nvar %s: Variant = null\nfunc %s() -> Variant: return %s"

var test_nodes: Array[Node]

func before_test() -> void:
	# Create test nodes for searching - use typed literal initializer
	test_nodes = []

	var node1: Node = _create_test_node_with_script(TEST_NODE_1_NAME, true)
	test_nodes.append(node1)

	var node2: Node2D = _create_test_node_with_script(TEST_NODE_2_NAME, true)
	test_nodes.append(node2)

	var node3: Node2D = _create_test_node_with_script(TEST_NODE_3_NAME, false)
	test_nodes.append(node3)

	# Add nodes to groups
	node1.add_to_group(GROUP_A_NAME)
	node2.add_to_group(GROUP_A_NAME)
	node3.add_to_group(GROUP_B_NAME)

func after_test() -> void:
	# Clean up test nodes - auto_free handles this automatically
	test_nodes.clear()

## Helper Functions
## Common test utilities to reduce code duplication

# Helper for asserting search result counts with descriptive messages
func _assert_search_result_count(found_nodes: Array[Node], expected_count: int, search_description: String) -> void:
	assert_int(found_nodes.size()).append_failure_message("%s expected %d got %d -> %s" % [search_description, expected_count, found_nodes.size(), found_nodes])\
		.is_equal(expected_count)

# Helper for creating a test node with optional script
func _create_test_node_with_script(node_name: String, add_script: bool = false) -> Node2D:
	var node: Node2D = auto_free(Node2D.new())
	node.name = node_name
	if add_script:
		var script: GDScript = auto_free(GDScript.new())
		script.source_code = TEST_SCRIPT_SOURCE
		script.reload()
		node.set_script(script)
	return node

## COMPREHENSIVE PARAMETERIZED TESTS - Following DRY principles

### Name Search Tests
#region Name Search Tests
@warning_ignore("unused_parameter")
func test_name_search_scenarios(
	search_name: String,
	expected_count: int,
	expected_node_name: String,
	test_parameters := [
		[TEST_NODE_1_NAME, 1, TEST_NODE_1_NAME],
		[TEST_NODE_2_NAME, 1, TEST_NODE_2_NAME],
		[TEST_NODE_3_NAME, 1, TEST_NODE_3_NAME],
		[TEST_NODE_PREFIX, 0, ""],  # Exact match only
		["NonExistent", 0, ""],
		["", 0, ""]
	]
) -> void:
	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_name(test_nodes, search_name)
	_assert_search_result_count(found_nodes, expected_count, "Name search '%s'" % search_name)

	if expected_count > 0:
		assert_object(found_nodes[0]).append_failure_message("Name search should return valid node when expected_count > 0")\
			.is_not_null()
		assert_str(found_nodes[0].name).append_failure_message("Found node name should match expected name '%s'" % expected_node_name)\
			.is_equal(expected_node_name)

#endregion

### Script Search Tests
#region Script Search Tests
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
	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_script(test_nodes, script_name)
	_assert_search_result_count(found_nodes, expected_count, "Script search '%s'" % script_name)

	if expected_count > 0:
		assert_object(found_nodes[0]).append_failure_message("Script search should return valid node when expected_count > 0")\
			.is_not_null()
		assert_bool(found_nodes[0].get_script() != null).append_failure_message("Script presence should match expected_has_script for script '%s'" % script_name)\
			.is_equal(expected_has_script)

#endregion

### Group Search Tests
@warning_ignore("unused_parameter")
func test_group_search_scenarios(
	group_name: String,
	expected_count: int,
	expected_nodes: Array[int],
	test_parameters := [
		[GROUP_A_NAME, 2, [0, 1]],  # test_nodes[0] and test_nodes[1]
		[GROUP_B_NAME, 1, [2]],     # test_nodes[2]
		["NonExistentGroup", 0, []],
		["", 0, []]
	]
) -> void:
	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_group(test_nodes, group_name)
	_assert_search_result_count(found_nodes, expected_count, "Group search '%s'" % group_name)

	# Verify expected nodes are found
	for expected_index in expected_nodes:
		assert_bool(found_nodes.has(test_nodes[expected_index])).append_failure_message("Group search for '%s' should include expected node at index %d" % [group_name, expected_index])\
			.is_true()

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
	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_class(test_nodes, cls_name)
	_assert_search_result_count(found_nodes, expected_count, "Class search '%s'" % cls_name)

	if expected_count > 0:
		for node: Node in found_nodes:
			assert_str(node.get_class()).append_failure_message("Class search for '%s' should return nodes of correct class" % cls_name)\
				.is_equal(expected_class)

### Property Search Tests
@warning_ignore("unused_parameter")
func test_property_search_scenarios(
	property_name: String,
	property_value: Variant,
	expected_count: int,
	setup_property: bool,
	test_parameters := [
		[CUSTOM_PROPERTY_NAME, "test_value", 1, true],
		["non_existent_property", "value", 0, false],
		["", "value", 0, false]
	]
) -> void:
	# Setup property if needed
	if setup_property:
		test_nodes[0].set(property_name, property_value)

	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_property(test_nodes, property_name, property_value)
	_assert_search_result_count(found_nodes, expected_count, "Property search '%s'" % property_name)

	if expected_count > 0:
		assert_object(found_nodes[0]).append_failure_message("Property search should return valid node when expected_count > 0")\
			.is_not_null()

### Method Result Search Tests
@warning_ignore("unused_parameter")
func test_method_result_search_scenarios(
	method_name: String,
	expected_result: Variant,
	expected_count: int,
	setup_method: bool,
	test_parameters := [
		[TEST_METHOD_NAME, "expected_result", 1, true],
		["non_existent_method", "value", 0, false],
		["", "value", 0, false]
	]
) -> void:
	# Setup method by replacing script with one returning expected_result
	if setup_method:
		var dynamic_script := GDScript.new()
		var result_literal: String
		if expected_result is String:
			result_literal = '"%s"' % expected_result
		else:
			result_literal = str(expected_result)
		dynamic_script.source_code = DYNAMIC_SCRIPT_TEMPLATE % [CUSTOM_PROPERTY_NAME, TEST_METHOD_NAME, result_literal]
		dynamic_script.reload()
		test_nodes[0].set_script(dynamic_script)

	var found_nodes: Array[Node] = NodeSearchLogic.find_nodes_by_method_result(test_nodes, method_name, expected_result)
	_assert_search_result_count(found_nodes, expected_count, "Method result search '%s'" % method_name)

	if expected_count > 0:
		assert_object(found_nodes[0]).append_failure_message("Method result search should return valid node when expected_count > 0")\
			.is_not_null()

### Script Name Tests
@warning_ignore("unused_parameter")
func test_script_name_scenarios(
	node_index: int,
	expected_empty: bool,
	expected_contains: String,
	test_parameters := [
		[0, false, TEST_NODE_1_NAME],	 # Has script
		[2, true, ""],                   # No script
		[-1, true, ""]                   # Invalid index
	]
) -> void:
	var node: Node = test_nodes[node_index] if node_index >= 0 and node_index < test_nodes.size() else null
	var script_name: String = NodeSearchLogic.get_script_name(node)

	if expected_empty:
		assert_str(script_name).append_failure_message("Script name should be empty for node at index %d" % node_index).is_empty()
	else:
		assert_str(script_name).append_failure_message("Script name should not be empty for node at index %d" % node_index)\
			.is_not_empty()
		assert_str(script_name).append_failure_message("Script name should contain '%s' for node at index %d" % [expected_contains, node_index]).contains(expected_contains)

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
	var issues: Array[String] = NodeSearchLogic.validate_search_params(search_method, search_string)
	assert_bool(issues.is_empty()).append_failure_message("Validation result should match expected_valid for method %d and string '%s'" % [search_method, search_string]).is_equal(expected_valid)

	if not expected_valid:
		assert_str(issues[0]).append_failure_message("Validation error should contain expected text").contains(expected_error_contains)

### Complex Operation Tests

func test_combine_search_results() -> void:
	var result1: Array[Node] = [test_nodes[0], test_nodes[1]]
	var result2: Array[Node] = [test_nodes[1], test_nodes[2]]  # Overlap with result1

	var combined: Array[Node] = NodeSearchLogic.combine_search_results([result1, result2])

	assert_int(combined.size()).append_failure_message("Combine search expected 3 got %d -> %s" % [combined.size(), combined])\
		.is_equal(3)  # Should have all unique nodes
	assert_bool(combined.has(test_nodes[0])).append_failure_message("Combined results should contain test_nodes[0]").is_true()
	assert_bool(combined.has(test_nodes[1])).append_failure_message("Combined results should contain test_nodes[1]").is_true()
	assert_bool(combined.has(test_nodes[2])).append_failure_message("Combined results should contain test_nodes[2]").is_true()

func test_filter_search_results() -> void:
	var filter_func: Callable = func(node: Node) -> bool: return node.name.begins_with(TEST_NODE_PREFIX)

	var filtered: Array[Node] = NodeSearchLogic.filter_search_results(test_nodes, filter_func)

	assert_int(filtered.size()).append_failure_message("Filter expected 3 got %d" % filtered.size()).is_equal(3)
	for node: Node in filtered:
		assert_str(node.name).append_failure_message("Filtered node name should contain TEST_NODE_PREFIX").contains(TEST_NODE_PREFIX)

func test_sort_search_results() -> void:
	var sort_func: Callable = func(a: Node, b: Node) -> bool: return a.name < b.name

	var original_names: Array[String] = []
	for n: Node in test_nodes:
		original_names.append(String(n.name))
	var sorted: Array[Node] = NodeSearchLogic.sort_search_results(test_nodes, sort_func)
	var sorted_names: Array[String] = []
	for n: Node in sorted:
		sorted_names.append(String(n.name))

	assert_int(sorted.size()).append_failure_message("Sort expected 3 got %d original=%s sorted=%s" % [sorted.size(), original_names, sorted_names])\
		.is_equal(3)
	# Primary expectation order
	assert_str(sorted[0].name).append_failure_message("Sorted names mismatch original=%s sorted=%s" % [original_names, sorted_names])\
		.is_equal("TestNode1")
	assert_str(sorted[1].name).append_failure_message("Sorted names mismatch original=%s sorted=%s" % [original_names, sorted_names])\
		.is_equal("TestNode2")
	assert_str(sorted[2].name).append_failure_message("Sorted names mismatch original=%s sorted=%s" % [original_names, sorted_names])\
		.is_equal("TestNode3")
	# Set equality guard to surface unexpected mutation (names should match originals set)
	for expected: String in [TEST_NODE_1_NAME, TEST_NODE_2_NAME, TEST_NODE_3_NAME]:
		assert_bool(sorted_names.has(expected)).append_failure_message("Expected name '%s' not present -> originals=%s sorted=%s" % [expected, original_names, sorted_names])\
			.is_true()
