## Unit tests for GBObjectUtils.get_display_name() with metadata support
extends GdUnitTestSuite


func test_get_display_name_uses_gb_display_name_metadata_when_present() -> void:
	# Test: When node has gb_display_name metadata, it should be used for display
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "InternalNodeName"

	# Set display name metadata
	test_node.set_meta("gb_display_name", "User-Friendly Display Name")

	# Act
	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Should use metadata value
	assert_str(display_name).append_failure_message(
		"get_display_name() should use gb_display_name metadata when present. " +
		"Expected: 'User-Friendly Display Name', Got: '%s'" % display_name
	).is_equal("User-Friendly Display Name")


func test_get_display_name_fallback_to_node_name_when_no_metadata() -> void:
	# Test: Without metadata, should fallback to node.name
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "MyNode"

	# Act
	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Should use node name (converted to readable)
	assert_str(display_name).append_failure_message(
		"get_display_name() should fallback to node.name when no metadata. " +
		"Expected: 'My Node', Got: '%s'" % display_name
	).is_equal("My Node")


func test_get_display_name_with_null_node() -> void:
	# Test: Null node should return missing_name parameter
	var display_name: String = GBObjectUtils.get_display_name(null, "<no target>")

	assert_str(display_name).append_failure_message(
		"Null node should return missing_name parameter"
	).is_equal("<no target>")


func test_get_display_name_with_empty_metadata() -> void:
	# Test: Empty string metadata should fallback to node name
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "NodeWithEmptyMeta"
	test_node.set_meta("gb_display_name", "")

	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Should fallback to node name when metadata is empty
	assert_str(display_name).append_failure_message(
		"Empty metadata should fallback to node name. " +
		"Expected: 'Node With Empty Meta', Got: '%s'" % display_name
	).is_equal("Node With Empty Meta")


func test_get_display_name_with_invalid_metadata_type() -> void:
	# Test: Non-string metadata should be handled gracefully
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "NodeWithBadMeta"
	test_node.set_meta("gb_display_name", 12345)  # Integer instead of string

	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Should fallback to node name when metadata is wrong type
	assert_str(display_name).append_failure_message(
		"Invalid metadata type should fallback to node name. " +
		"Expected: 'Node With Bad Meta', Got: '%s'" % display_name
	).is_equal("Node With Bad Meta")


func test_get_display_name_special_characters_in_metadata() -> void:
	# Test: Metadata with special characters should be preserved exactly
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "SimpleNode"
	test_node.set_meta("gb_display_name", "Smithy (Level 2) [Active]")

	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Special characters in metadata should be preserved
	assert_str(display_name).append_failure_message(
		"Metadata with special characters should be preserved exactly"
	).is_equal("Smithy (Level 2) [Active]")


func test_get_display_name_prioritizes_metadata_over_to_string() -> void:
	# Test: gb_display_name metadata should take priority over _to_string() method
	var test_node: Node = auto_free(Node.new())
	test_node.name = "CustomNode"
	test_node.set_meta("gb_display_name", "Metadata Name")

	# Note: Node doesn't have _to_string() but we can test priority logic
	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Metadata should be used
	assert_str(display_name).append_failure_message(
		"Metadata should take priority over other naming methods"
	).is_equal("Metadata Name")


func test_get_display_name_unicode_support() -> void:
	# Test: Unicode characters in metadata should work correctly
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "UnicodeNode"
	test_node.set_meta("gb_display_name", "建築物 (Building) 🏗️")

	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Unicode should be preserved
	assert_str(display_name).append_failure_message(
		"Unicode characters should be supported in display name metadata"
	).is_equal("建築物 (Building) 🏗️")


func test_get_display_name_backward_compatibility() -> void:
	# Test: Existing code without metadata should work unchanged
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "BackwardCompatNode"

	# Don't set any metadata - test backward compatibility
	var display_name: String = GBObjectUtils.get_display_name(test_node)

	# Assert: Should use node name conversion (backward compatible behavior)
	assert_str(display_name).append_failure_message(
		"Backward compatibility: nodes without metadata should work as before"
	).is_equal("Backward Compat Node")
