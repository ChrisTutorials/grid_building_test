## Tests for GBMetadataResolver utility
## Verifies metadata-based root node resolution for targeting system
extends GdUnitTestSuite

#region Helper Methods


## Creates a Node2D with specified name, adds to tree, and marks for auto_free
func _create_node(p_name: String, p_type: Variant = Node2D) -> Node:
	var node: Node = auto_free(p_type.new())
	node.name = p_name
	add_child(node)
	return node


## Creates a basic hierarchy: root → collision area
## Returns dictionary with 'root' and 'collision' keys
func _create_basic_collision_hierarchy(
	p_root_name: String = "Root", p_collision_name: String = "Collision"
) -> Dictionary[String, Node]:
	var root: Node2D = auto_free(Node2D.new())
	root.name = p_root_name
	add_child(root)

	var collision: Area2D = auto_free(Area2D.new())
	collision.name = p_collision_name
	root.add_child(collision)

	return {"root": root, "collision": collision}


## Creates hierarchy with Manipulatable: root → collision → manipulatable
## Returns dictionary with 'root', 'collision', 'manipulatable' keys
func _create_manipulatable_hierarchy(p_root_name: String = "Root") -> Dictionary[String, Node]:
	var result: Dictionary[String, Node] = _create_basic_collision_hierarchy(
		p_root_name, "Collision"
	)

	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = result.root
	result.collision.add_child(manipulatable)

	result.manipulatable = manipulatable
	return result


## Sets metadata on a node with optional value
func _set_node_metadata(p_node: Node, p_key: String, p_value: Variant) -> void:
	p_node.set_meta(p_key, p_value)


## Asserts that resolved node matches expected node with formatted failure message
func _assert_resolved_root(p_actual: Node2D, p_expected: Node2D, p_context: String = "") -> void:
	var message: String = "Should resolve to expected root"
	if p_context:
		message += ": " + p_context
	message += (
		". Got: %s, Expected: %s"
		% [
			GBDiagnostics.format_node_label(p_actual) if p_actual else "null",
			GBDiagnostics.format_node_label(p_expected) if p_expected else "null"
		]
	)

	assert_object(p_actual).append_failure_message(message).is_same(p_expected)


## Asserts display name matches expected value
func _assert_display_name(p_actual: String, p_expected: String, p_context: String = "") -> void:
	var message: String = "Display name should match expected value"
	if p_context:
		message += ": " + p_context
	message += ". Got: %s, Expected: %s" % [p_actual, p_expected]

	assert_str(p_actual).append_failure_message(message).is_equal(p_expected)


#endregion


func test_resolve_root_node_with_metadata_node_path() -> void:
	# Setup: Create scene structure matching Smithy
	# THISISROOTSMITHY-Node2D
	#   └─ Smithy (Area2D with metadata/root_node = NodePath(".."))

	var hierarchy: Dictionary[String, Node] = _create_basic_collision_hierarchy(
		"THISISROOTSMITHY-Node2D", "Smithy"
	)
	var root: Node2D = hierarchy.root
	var collision: Area2D = hierarchy.collision

	# Set metadata: root_node = NodePath("..") (points to parent)
	_set_node_metadata(collision, "root_node", NodePath(".."))

	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision)

	# Assert: Should resolve to root_node (THISISROOTSMITHY-Node2D)
	_assert_resolved_root(resolved, root, "via metadata/root_node")
	(
		assert_str(resolved.name)
		. append_failure_message("Resolved node name should be 'THISISROOTSMITHY-Node2D'")
		. is_equal("THISISROOTSMITHY-Node2D")
	)


func test_resolve_root_node_with_metadata_direct_node() -> void:
	# Setup: metadata/root_node can also be a Node2D directly
	var root: Node2D = _create_node("DirectRoot") as Node2D
	var collision: Area2D = _create_node("CollisionObject", Area2D) as Area2D

	# Set metadata: root_node = Node2D directly
	_set_node_metadata(collision, "root_node", root)

	# Act: Resolve root node
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision)

	# Assert: Should return the direct node
	_assert_resolved_root(resolved, root, "direct Node2D from metadata")


func test_resolve_root_node_fallback_to_collision_object() -> void:
	# Setup: No metadata, no Manipulatable - should return collision object itself
	var collision: Area2D = _create_node("SelfTargeting", Area2D) as Area2D

	# Act: Resolve root node (no metadata)
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision)

	# Assert: Should return collision object itself as fallback
	_assert_resolved_root(resolved, collision, "fallback to collision object when no metadata")


func test_resolve_root_node_with_manipulatable_sibling() -> void:
	# Setup: Manipulatable as sibling of collision object
	var root: Node2D = _create_node("ManipulatableRoot") as Node2D
	var parent: Node2D = _create_node("Parent") as Node2D

	var collision: Area2D = auto_free(Area2D.new())
	collision.name = "Collision"
	parent.add_child(collision)

	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root
	parent.add_child(manipulatable)

	# Act: Resolve root node (should find Manipulatable sibling)
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision)

	# Assert: Should resolve to Manipulatable.root
	_assert_resolved_root(resolved, root, "Manipulatable.root from sibling search")


func test_resolve_root_node_with_manipulatable_child() -> void:
	# Setup: Manipulatable as child of collision object
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "ChildManipulatableRoot"
	add_child(root_node)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionWithChild"
	add_child(collision_area)

	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root_node
	collision_area.add_child(manipulatable)

	# Act: Resolve root node (should find Manipulatable child)
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: Should resolve to Manipulatable.root
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Should resolve to Manipulatable.root from child search. Got: %s"
				% (str(resolved.name) if resolved else "null")
			)
		)
		. is_same(root_node)
	)


func test_metadata_priority_over_manipulatable() -> void:
	# Setup: Both metadata and Manipulatable present - metadata should win
	var metadata_root: Node2D = auto_free(Node2D.new())
	metadata_root.name = "MetadataRoot"
	add_child(metadata_root)

	var manipulatable_root: Node2D = auto_free(Node2D.new())
	manipulatable_root.name = "ManipulatableRoot"
	add_child(manipulatable_root)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionWithBoth"
	add_child(collision_area)

	# Set metadata (Priority 1)
	collision_area.set_meta("root_node", metadata_root)

	# Add Manipulatable child (Priority 3)
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = manipulatable_root
	collision_area.add_child(manipulatable)

	# Act: Resolve root node
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: Metadata should take priority
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Metadata should have priority over Manipulatable. Got: %s, Expected: %s"
				% [str(resolved.name) if resolved else "null", str(metadata_root.name)]
			)
		)
		. is_same(metadata_root)
	)


func test_nodepath_metadata_resolves_at_runtime_not_design_time() -> void:
	## CRITICAL TEST: Demonstrates NodePath metadata resolution behavior
	## This test simulates what happens when a scene with NodePath("..") is instantiated
	## with a name override, causing the scene root to be renamed.
	##
	## Issue: NodePath("..")` resolves at RUNTIME based on the actual scene tree,
	## not at design time. When Godot instantiates a scene with [node name="NewName" instance=...],
	## it renames the scene root, which can break NodePath assumptions.

	# Setup: Simulate scene instantiation with name override
	# Original scene structure (smithy.tscn):
	#   THISISROOTSMITHY-Node2D (root)
	#     └─ Smithy (Area2D with metadata/root_node = NodePath(".."))
	#
	# After instantiation with [node name="Smithy" instance=smithy.tscn]:
	#   Smithy (Node2D - renamed from THISISROOTSMITHY-Node2D)  ← ROOT RENAMED!
	#     └─ Smithy (Area2D with metadata/root_node = NodePath(".."))
	#
	# Result: Both root AND Area2D are named "Smithy" at runtime!

	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "Smithy"  # Simulates renamed scene root
	add_child(root_node)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "Smithy"  # Same name as parent!
	root_node.add_child(collision_area)

	# Set metadata with relative NodePath (as in smithy.tscn)
	collision_area.set_meta("root_node", NodePath(".."))

	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: NodePath("..") correctly resolves to parent at runtime
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"NodePath metadata should resolve to parent node at runtime. Got: %s"
				% GBDiagnostics.format_node_label(resolved)
			)
		)
		. is_same(root_node)
	)

	# Assert: Both nodes have same name (this is the ambiguity problem!)
	(
		assert_str(resolved.name)
		. append_failure_message("Root node name should be 'Smithy' (renamed from scene root)")
		. is_equal("Smithy")
	)

	(
		assert_str(collision_area.name)
		. append_failure_message("Collision area name should also be 'Smithy'")
		. is_equal("Smithy")
	)

	# Critical observation: NodePath resolves CORRECTLY, but name ambiguity makes debugging hard!
	# The real bug is not NodePath metadata - it's the Manipulatable root path configuration.


func test_nodepath_metadata_with_multiple_parent_levels() -> void:
	## Tests NodePath with multiple parent traversals (e.g., "../..")
	## This verifies that NodePath metadata can correctly traverse multiple levels

	# Setup: Deep hierarchy
	# GrandParent (Node2D)
	#   └─ Parent (Node2D)
	#       └─ CollisionArea (Area2D with metadata/root_node = NodePath("../.."))

	var grandparent: Node2D = auto_free(Node2D.new())
	grandparent.name = "GrandParent"
	add_child(grandparent)

	var parent: Node2D = auto_free(Node2D.new())
	parent.name = "Parent"
	grandparent.add_child(parent)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionArea"
	parent.add_child(collision_area)

	# Set metadata: root_node = NodePath("../..") (two levels up)
	collision_area.set_meta("root_node", NodePath("../.."))

	# Act: Resolve root node
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: Should resolve to grandparent (two levels up)
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"NodePath('../..') should resolve to grandparent. Got: %s, Expected: %s"
				% [GBDiagnostics.format_node_label(resolved), grandparent.name]
			)
		)
		. is_same(grandparent)
	)

	(
		assert_str(resolved.name)
		. append_failure_message("Resolved node should be GrandParent")
		. is_equal("GrandParent")
	)


func test_nodepath_metadata_with_absolute_path() -> void:
	## Tests NodePath with absolute path (e.g., "/root/RootNodeName")
	## Absolute paths are NOT recommended for reusable scenes, but should be tested

	# Setup: Scene with absolute path metadata
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "AbsoluteRoot"
	add_child(root_node)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionWithAbsolutePath"
	add_child(collision_area)

	# Set metadata: absolute NodePath (starts with /)
	# Note: This requires the node to be in the tree when get_node is called
	var absolute_path: String = root_node.get_path()
	collision_area.set_meta("root_node", NodePath(absolute_path))

	# Act: Resolve root node
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: Should resolve to root_node via absolute path
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Absolute NodePath should resolve correctly. Got: %s"
				% GBDiagnostics.format_node_label(resolved)
			)
		)
		. is_same(root_node)
	)


func test_nodepath_metadata_with_invalid_path() -> void:
	## Tests NodePath that doesn't resolve to valid Node2D
	## Should fallback gracefully

	# Setup: metadata with invalid NodePath
	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionWithBadPath"
	add_child(collision_area)

	# Set metadata: NodePath to non-existent node
	collision_area.set_meta("root_node", NodePath("NonExistentNode"))

	# Act: Resolve root node (should handle gracefully)
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: Should fallback to collision object when path invalid
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Invalid NodePath should fallback to collision object. Got: %s"
				% GBDiagnostics.format_node_label(resolved)
			)
		)
		. is_same(collision_area)
	)


func test_nodepath_metadata_resolves_to_non_node2d() -> void:
	## Tests NodePath that resolves to non-Node2D (e.g., Node or Control)
	## Should fallback gracefully since we require Node2D

	# Setup: hierarchy with Node parent (not Node2D)
	var parent_node: Node = auto_free(Node.new())
	parent_node.name = "NonNode2DParent"
	add_child(parent_node)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionUnderNonNode2D"
	parent_node.add_child(collision_area)

	# Set metadata: NodePath("..") points to Node (not Node2D)
	collision_area.set_meta("root_node", NodePath(".."))

	# Act: Resolve root node
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)

	# Assert: Should fallback to collision object when resolved node is not Node2D
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"NodePath resolving to non-Node2D should fallback. Got: %s"
				% GBDiagnostics.format_node_label(resolved)
			)
		)
		. is_same(collision_area)
	)


func test_manipulatable_root_nodepath_configuration() -> void:
	## CRITICAL TEST: Demonstrates Manipulatable component NodePath bug in smithy.tscn
	## The bug is in the .tscn file where root = NodePath("..") only goes one level up
	##
	## This test verifies the CORRECT behavior when NodePath is fixed to NodePath("../..")

	# Setup: Smithy scene structure at runtime (after name override)
	# Smithy (Node2D - scene root, renamed from THISISROOTSMITHY-Node2D)
	#   └─ Smithy (Area2D)
	#       └─ Manipulatable (root needs NodePath("../..") to reach scene root!)

	var scene_root: Node2D = auto_free(Node2D.new())
	scene_root.name = "Smithy"
	add_child(scene_root)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "Smithy"
	scene_root.add_child(collision_area)

	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	collision_area.add_child(manipulatable)

	# Test INCORRECT configuration: NodePath("..") only goes one level (to Area2D)
	var one_level_up_path: NodePath = NodePath("..")
	var incorrectly_resolved: Node = manipulatable.get_node(one_level_up_path)

	(
		assert_object(incorrectly_resolved)
		. append_failure_message(
			"BUG DEMONSTRATION: NodePath('..') only resolves to Area2D, not scene root!"
		)
		. is_same(collision_area)
	)  # ← This shows the BUG in smithy.tscn!

	# Test CORRECT configuration: NodePath("../..") reaches scene root
	var two_levels_up_path: NodePath = NodePath("../..")
	var correctly_resolved: Node = manipulatable.get_node(two_levels_up_path)

	(
		assert_object(correctly_resolved)
		. append_failure_message(
			(
				"CORRECT: NodePath('../..') should resolve to scene root. Got: %s"
				% GBDiagnostics.format_node_label(correctly_resolved)
			)
		)
		. is_same(scene_root)
	)

	# Now assign the CORRECT root to Manipulatable
	manipulatable.root = scene_root

	# Verify Manipulatable now has correct root
	(
		assert_object(manipulatable.root)
		. append_failure_message("Manipulatable.root should be scene root after correct assignment")
		. is_same(scene_root)
	)


## Tests display name resolution priority chain
## Priority: method > property > metadata > node name > fallback
## Consolidated from 8 separate tests into parameterized test
@warning_ignore("unused_parameter")
func test_display_name_resolution_priority_chain(
	p_priority_level: String,
	p_expected_name: String,
	p_has_method: bool,
	p_has_property: bool,
	p_has_metadata: bool,
	p_node_name: String,
	p_description: String = "",
	test_parameters := [
		# [priority_level, expected_name, has_method, has_property, has_metadata, node_name, description]
		[
			"method",
			"MethodDisplayName",
			true,
			true,
			true,
			"NodeName",
			"Method has highest priority"
		],
		[
			"property",
			"PropertyDisplayName",
			false,
			true,
			true,
			"NodeName",
			"Property is priority 2"
		],
		[
			"metadata_string",
			"MetadataDisplayName",
			false,
			false,
			true,
			"NodeName",
			"Metadata string is priority 3"
		],
		[
			"metadata_stringname",
			"StringNameDisplayName",
			false,
			false,
			true,
			"NodeName",
			"StringName metadata works"
		],
		[
			"node_name",
			"FallbackNodeName",
			false,
			false,
			false,
			"FallbackNodeName",
			"Node name is priority 4"
		],
		[
			"empty_strings",
			"ActualNodeName",
			false,
			false,
			false,
			"ActualNodeName",
			"Empty strings are skipped"
		],
	]
) -> void:
	# Build script dynamically based on parameters
	var script_source: String = "extends Node2D\n"

	if p_has_property:
		if p_priority_level == "empty_strings":
			script_source += 'var display_name: String = ""\n'  # Empty property
		else:
			script_source += 'var display_name: String = "PropertyDisplayName"\n'

	if p_has_method:
		script_source += "func get_display_name() -> String:\n"
		if p_priority_level == "empty_strings":
			script_source += '\treturn ""\n'  # Empty method
		else:
			script_source += '\treturn "MethodDisplayName"\n'

	# Create node with script
	var test_node: Node2D = auto_free(Node2D.new())

	if p_has_method or p_has_property:
		var test_script: GDScript = GDScript.new()
		test_script.source_code = script_source
		test_script.reload()
		test_node.set_script(test_script)

	test_node.name = p_node_name

	if p_has_metadata:
		if p_priority_level == "metadata_stringname":
			test_node.set_meta("display_name", &"StringNameDisplayName")
		elif p_priority_level == "empty_strings":
			test_node.set_meta("display_name", "")  # Empty metadata
		else:
			test_node.set_meta("display_name", "MetadataDisplayName")

	add_child(test_node)

	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)

	# Assert: Should match expected based on priority
	_assert_display_name(resolved_name, p_expected_name, p_description)


func test_display_name_resolution_null_fallback() -> void:
	## Tests display name resolution with null node using fallback parameter

	# Test custom fallback
	var resolved: String = GBMetadataResolver.resolve_display_name(null, "<custom_fallback>")
	_assert_display_name(resolved, "<custom_fallback>", "custom fallback for null node")

	# Test default fallback
	var default_resolved: String = GBMetadataResolver.resolve_display_name(null)
	_assert_display_name(default_resolved, "<none>", "default fallback for null node")


#region MANIPULATABLE HIERARCHY INDEPENDENCE TESTS


func test_manipulatable_under_scene_root_with_collision_on_child() -> void:
	## Tests that Manipulatable works when placed under scene root
	## with collision object as a sibling (separate child of root)
	##
	## Hierarchy:
	##   SceneRoot (Node2D)
	##     ├─ Manipulatable → root points to SceneRoot
	##     └─ StaticBody2D (collision object)
	##
	## This reproduces the user's bug where Manipulatable under scene root doesn't work

	# Setup: Scene root
	var scene_root: Node2D = auto_free(Node2D.new())
	scene_root.name = "SceneRoot"
	add_child(scene_root)

	# Add Manipulatable component under root
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "ManipulatableComponent"
	manipulatable.root = scene_root  # Points to scene root
	scene_root.add_child(manipulatable)

	# Add collision object as sibling
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "CollisionBody"
	scene_root.add_child(collision_body)

	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_body)

	# Assert: Should find Manipulatable and return scene root
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Should resolve to SceneRoot via Manipulatable sibling search. "
				+ (
					"Got: %s, Expected: %s (SceneRoot)"
					% [GBDiagnostics.format_node_label(resolved), scene_root.name]
				)
			)
		)
		. is_same(scene_root)
	)


func test_manipulatable_under_area2d_with_collision_on_sibling() -> void:
	## Tests that Manipulatable works when placed under Area2D
	## with StaticBody2D as a sibling collision object
	##
	## Hierarchy:
	##   SceneRoot (Node2D)
	##     ├─ Area2D
	##     │   └─ Manipulatable → root points to SceneRoot
	##     └─ StaticBody2D (collision object, different layer)
	##
	## This reproduces the user's bug where Manipulatable under Area2D doesn't work

	# Setup: Scene root
	var scene_root: Node2D = auto_free(Node2D.new())
	scene_root.name = "SceneRoot"
	add_child(scene_root)

	# Add Area2D container
	var area_container: Area2D = auto_free(Area2D.new())
	area_container.name = "AreaContainer"
	area_container.collision_layer = 0b1100000000  # Layers 10, 12
	area_container.collision_mask = 0
	scene_root.add_child(area_container)

	# Add Manipulatable under Area2D
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "ManipulatableComponent"
	manipulatable.root = scene_root  # Points to scene root
	area_container.add_child(manipulatable)

	# Add StaticBody2D as sibling (on different layer)
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "CollisionBody"
	collision_body.collision_layer = 0b1  # Layer 1
	collision_body.collision_mask = 0
	scene_root.add_child(collision_body)

	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_body)

	# Assert: Should find Manipulatable in scene tree and return scene root
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Should resolve to SceneRoot via scene tree search for Manipulatable. "
				+ (
					"Got: %s, Expected: %s (SceneRoot)"
					% [GBDiagnostics.format_node_label(resolved), scene_root.name]
				)
			)
		)
		. is_same(scene_root)
	)


func test_manipulatable_under_collision_object_still_works() -> void:
	## Tests that existing behavior (Manipulatable under collision object) still works
	## This is the current working case that should NOT break
	##
	## Hierarchy:
	##   SceneRoot (Node2D)
	##     └─ StaticBody2D (collision object)
	##         └─ Manipulatable → root points to SceneRoot

	# Setup: Scene root
	var scene_root: Node2D = auto_free(Node2D.new())
	scene_root.name = "SceneRoot"
	add_child(scene_root)

	# Add collision object
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "CollisionBody"
	scene_root.add_child(collision_body)

	# Add Manipulatable as child of collision object (current working case)
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "ManipulatableComponent"
	manipulatable.root = scene_root  # Points to scene root
	collision_body.add_child(manipulatable)

	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_body)

	# Assert: Should find Manipulatable as child and return scene root
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Should resolve to SceneRoot via child search (existing behavior). "
				+ (
					"Got: %s, Expected: %s (SceneRoot)"
					% [GBDiagnostics.format_node_label(resolved), scene_root.name]
				)
			)
		)
		. is_same(scene_root)
	)


func test_manipulatable_deep_in_hierarchy_found_via_tree_search() -> void:
	## Tests that Manipulatable can be found anywhere in the scene tree
	## Even when deeply nested away from the collision object
	##
	## Hierarchy:
	##   SceneRoot (Node2D)
	##     ├─ DeepContainer (Node2D)
	##     │   └─ AnotherContainer (Node2D)
	##     │       └─ Manipulatable → root points to SceneRoot
	##     └─ StaticBody2D (collision object)

	# Setup: Scene root
	var scene_root: Node2D = auto_free(Node2D.new())
	scene_root.name = "SceneRoot"
	add_child(scene_root)

	# Add deep nested containers
	var deep_container: Node2D = auto_free(Node2D.new())
	deep_container.name = "DeepContainer"
	scene_root.add_child(deep_container)

	var another_container: Node2D = auto_free(Node2D.new())
	another_container.name = "AnotherContainer"
	deep_container.add_child(another_container)

	# Add Manipulatable deep in hierarchy
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.name = "ManipulatableComponent"
	manipulatable.root = scene_root  # Points to scene root
	another_container.add_child(manipulatable)

	# Add collision object as sibling at root level
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "CollisionBody"
	scene_root.add_child(collision_body)

	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_body)

	# Assert: Should find Manipulatable anywhere in scene tree
	(
		assert_object(resolved)
		. append_failure_message(
			(
				"Should find Manipulatable via scene tree search, even when deeply nested. "
				+ (
					"Got: %s, Expected: %s (SceneRoot)"
					% [GBDiagnostics.format_node_label(resolved), scene_root.name]
				)
			)
		)
		. is_same(scene_root)
	)

#endregion
