## Tests for GBMetadataResolver utility
## Verifies metadata-based root node resolution for targeting system
extends GdUnitTestSuite

func test_resolve_root_node_with_metadata_node_path() -> void:
	# Setup: Create scene structure matching Smithy
	# THISISROOTSMITHY-Node2D
	#   └─ Smithy (Area2D with metadata/root_node = NodePath(".."))
	
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "THISISROOTSMITHY-Node2D"
	add_child(root_node)
	
	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "Smithy"
	root_node.add_child(collision_area)
	
	# Set metadata: root_node = NodePath("..") (points to parent)
	collision_area.set_meta("root_node", NodePath(".."))
	
	# Act: Resolve root node from collision object
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)
	
	# Assert: Should resolve to root_node (THISISROOTSMITHY-Node2D)
	assert_object(resolved).append_failure_message(
		"Should resolve to root node via metadata/root_node. Got: %s" % 
		(resolved.name if resolved else "null")
	).is_same(root_node)
	
	assert_str(resolved.name).append_failure_message(
		"Resolved node name should be 'THISISROOTSMITHY-Node2D'"
	).is_equal("THISISROOTSMITHY-Node2D")


func test_resolve_root_node_with_metadata_direct_node() -> void:
	# Setup: metadata/root_node can also be a Node2D directly
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "DirectRoot"
	add_child(root_node)
	
	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionObject"
	add_child(collision_area)
	
	# Set metadata: root_node = Node2D directly
	collision_area.set_meta("root_node", root_node)
	
	# Act: Resolve root node
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)
	
	# Assert: Should return the direct node
	assert_object(resolved).append_failure_message(
		"Should resolve to direct Node2D from metadata. Got: %s" % 
		(resolved.name if resolved else "null")
	).is_same(root_node)


func test_resolve_root_node_fallback_to_collision_object() -> void:
	# Setup: No metadata, no Manipulatable - should return collision object itself
	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "SelfTargeting"
	add_child(collision_area)
	
	# Act: Resolve root node (no metadata)
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)
	
	# Assert: Should return collision object itself as fallback
	assert_object(resolved).append_failure_message(
		"Should fallback to collision object when no metadata. Got: %s" % 
		(resolved.name if resolved else "null")
	).is_same(collision_area)


func test_resolve_root_node_with_manipulatable_sibling() -> void:
	# Setup: Manipulatable as sibling of collision object
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "ManipulatableRoot"
	add_child(root_node)
	
	var parent: Node2D = auto_free(Node2D.new())
	parent.name = "Parent"
	add_child(parent)
	
	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "Collision"
	parent.add_child(collision_area)
	
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root_node
	parent.add_child(manipulatable)
	
	# Act: Resolve root node (should find Manipulatable sibling)
	var resolved: Node2D = GBMetadataResolver.resolve_root_node(collision_area)
	
	# Assert: Should resolve to Manipulatable.root
	assert_object(resolved).append_failure_message(
		"Should resolve to Manipulatable.root from sibling search. Got: %s" % 
		(resolved.name if resolved else "null")
	).is_same(root_node)


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
	assert_object(resolved).append_failure_message(
		"Should resolve to Manipulatable.root from child search. Got: %s" % 
		(resolved.name if resolved else "null")
	).is_same(root_node)


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
	assert_object(resolved).append_failure_message(
		"Metadata should have priority over Manipulatable. Got: %s, Expected: %s" % 
		[resolved.name if resolved else "null", metadata_root.name]
	).is_same(metadata_root)


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
	assert_object(resolved).append_failure_message(
		"NodePath metadata should resolve to parent node at runtime. Got: %s" % 
		GBDiagnostics.format_node_label(resolved)
	).is_same(root_node)
	
	# Assert: Both nodes have same name (this is the ambiguity problem!)
	assert_str(resolved.name).append_failure_message(
		"Root node name should be 'Smithy' (renamed from scene root)"
	).is_equal("Smithy")
	
	assert_str(collision_area.name).append_failure_message(
		"Collision area name should also be 'Smithy'"
	).is_equal("Smithy")
	
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
	assert_object(resolved).append_failure_message(
		"NodePath('../..') should resolve to grandparent. Got: %s, Expected: %s" % 
		[GBDiagnostics.format_node_label(resolved), grandparent.name]
	).is_same(grandparent)
	
	assert_str(resolved.name).append_failure_message(
		"Resolved node should be GrandParent"
	).is_equal("GrandParent")


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
	assert_object(resolved).append_failure_message(
		"Absolute NodePath should resolve correctly. Got: %s" % 
		GBDiagnostics.format_node_label(resolved)
	).is_same(root_node)


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
	assert_object(resolved).append_failure_message(
		"Invalid NodePath should fallback to collision object. Got: %s" % 
		GBDiagnostics.format_node_label(resolved)
	).is_same(collision_area)


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
	assert_object(resolved).append_failure_message(
		"NodePath resolving to non-Node2D should fallback. Got: %s" % 
		GBDiagnostics.format_node_label(resolved)
	).is_same(collision_area)


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
	
	assert_object(incorrectly_resolved).append_failure_message(
		"BUG DEMONSTRATION: NodePath('..') only resolves to Area2D, not scene root!"
	).is_same(collision_area)  # ← This shows the BUG in smithy.tscn!
	
	# Test CORRECT configuration: NodePath("../..") reaches scene root
	var two_levels_up_path: NodePath = NodePath("../..")
	var correctly_resolved: Node = manipulatable.get_node(two_levels_up_path)
	
	assert_object(correctly_resolved).append_failure_message(
		"CORRECT: NodePath('../..') should resolve to scene root. Got: %s" %
		GBDiagnostics.format_node_label(correctly_resolved)
	).is_same(scene_root)
	
	# Now assign the CORRECT root to Manipulatable
	manipulatable.root = scene_root
	
	# Verify Manipulatable now has correct root
	assert_object(manipulatable.root).append_failure_message(
		"Manipulatable.root should be scene root after correct assignment"
	).is_same(scene_root)


func test_display_name_resolution_method_priority() -> void:
	## Tests display name resolution with get_display_name() method having highest priority
	## Priority: method > property > metadata > node name > fallback
	
	# Setup: Create a test class with get_display_name() method
	var test_script: GDScript = GDScript.new()
	test_script.source_code = """
extends Node2D

var display_name: String = "PropertyDisplayName"

func get_display_name() -> String:
	return "MethodDisplayName"
"""
	test_script.reload()
	
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.set_script(test_script)
	test_node.name = "NodeName"
	test_node.set_meta("display_name", "MetadataDisplayName")
	add_child(test_node)
	
	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)
	
	# Assert: Should use method (highest priority)
	assert_str(resolved_name).append_failure_message(
		"Display name should use get_display_name() method (priority 1). Got: %s" % resolved_name
	).is_equal("MethodDisplayName")


func test_display_name_resolution_property_priority() -> void:
	## Tests display name resolution with property having second priority
	## Priority: method > property > metadata > node name > fallback
	
	# Setup: Node with display_name property but NO method
	var test_script: GDScript = GDScript.new()
	test_script.source_code = """
extends Node2D

var display_name: String = "PropertyDisplayName"
"""
	test_script.reload()
	
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.set_script(test_script)
	test_node.name = "NodeName"
	test_node.set_meta("display_name", "MetadataDisplayName")
	add_child(test_node)
	
	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)
	
	# Assert: Should use property (priority 2)
	assert_str(resolved_name).append_failure_message(
		"Display name should use display_name property (priority 2). Got: %s" % resolved_name
	).is_equal("PropertyDisplayName")


func test_display_name_resolution_metadata_priority() -> void:
	## Tests display name resolution with metadata having third priority
	## Priority: method > property > metadata > node name > fallback
	
	# Setup: Node with display_name metadata (no method or property)
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "NodeName"
	test_node.set_meta("display_name", "MetadataDisplayName")
	add_child(test_node)
	
	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)
	
	# Assert: Should use metadata (priority 3)
	assert_str(resolved_name).append_failure_message(
		"Display name should use metadata/display_name (priority 3). Got: %s" % resolved_name
	).is_equal("MetadataDisplayName")


func test_display_name_resolution_stringname_support() -> void:
	## Tests that display name resolution accepts StringName in metadata
	## StringName (&"text") should work the same as String
	
	# Setup: Node with StringName metadata
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "NodeName"
	test_node.set_meta("display_name", &"StringNameDisplayName")  # StringName literal
	add_child(test_node)
	
	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)
	
	# Assert: Should convert StringName to String and use it
	assert_str(resolved_name).append_failure_message(
		"Display name should accept StringName metadata. Got: %s" % resolved_name
	).is_equal("StringNameDisplayName")


func test_display_name_resolution_node_name_fallback() -> void:
	## Tests display name resolution fallback to node.name
	## Priority: method > property > metadata > node name > fallback
	
	# Setup: Node with no display_name method, property, or metadata
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.name = "FallbackNodeName"
	add_child(test_node)
	
	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)
	
	# Assert: Should fallback to node.name (priority 4)
	assert_str(resolved_name).append_failure_message(
		"Display name should fallback to node.name (priority 4). Got: %s" % resolved_name
	).is_equal("FallbackNodeName")


func test_display_name_resolution_ultimate_fallback() -> void:
	## Tests display name resolution with null node using ultimate fallback
	## Priority: method > property > metadata > node name > fallback
	
	# Setup: Null node
	var null_node: Node = null
	
	# Act: Resolve display name with custom fallback
	var resolved_name: String = GBMetadataResolver.resolve_display_name(null_node, "<custom_fallback>")
	
	# Assert: Should use provided fallback (priority 5)
	assert_str(resolved_name).append_failure_message(
		"Display name should use fallback for null node (priority 5). Got: %s" % resolved_name
	).is_equal("<custom_fallback>")
	
	# Test default fallback
	var default_resolved: String = GBMetadataResolver.resolve_display_name(null_node)
	assert_str(default_resolved).append_failure_message(
		"Display name should use default '<none>' fallback. Got: %s" % default_resolved
	).is_equal("<none>")


func test_display_name_resolution_empty_string_handling() -> void:
	## Tests that empty strings at any priority level are skipped
	## Empty strings should cause fallback to next priority level
	
	# Setup: Node with empty string method
	var test_script: GDScript = GDScript.new()
	test_script.source_code = """
extends Node2D

var display_name: String = ""  # Empty property

func get_display_name() -> String:
	return ""  # Empty method result
"""
	test_script.reload()
	
	var test_node: Node2D = auto_free(Node2D.new())
	test_node.set_script(test_script)
	test_node.name = "ActualNodeName"
	test_node.set_meta("display_name", "")  # Empty metadata
	add_child(test_node)
	
	# Act: Resolve display name
	var resolved_name: String = GBMetadataResolver.resolve_display_name(test_node)
	
	# Assert: Should skip all empty strings and fall back to node.name
	assert_str(resolved_name).append_failure_message(
		"Empty strings should be skipped, should use node.name. Got: %s" % resolved_name
	).is_equal("ActualNodeName")


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
	assert_object(resolved).append_failure_message(
		"Should resolve to SceneRoot via Manipulatable sibling search. " +
		"Got: %s, Expected: %s (SceneRoot)" % 
		[GBDiagnostics.format_node_label(resolved), scene_root.name]
	).is_same(scene_root)


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
	assert_object(resolved).append_failure_message(
		"Should resolve to SceneRoot via scene tree search for Manipulatable. " +
		"Got: %s, Expected: %s (SceneRoot)" % 
		[GBDiagnostics.format_node_label(resolved), scene_root.name]
	).is_same(scene_root)


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
	assert_object(resolved).append_failure_message(
		"Should resolve to SceneRoot via child search (existing behavior). " +
		"Got: %s, Expected: %s (SceneRoot)" % 
		[GBDiagnostics.format_node_label(resolved), scene_root.name]
	).is_same(scene_root)


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
	assert_object(resolved).append_failure_message(
		"Should find Manipulatable via scene tree search, even when deeply nested. " +
		"Got: %s, Expected: %s (SceneRoot)" % 
		[GBDiagnostics.format_node_label(resolved), scene_root.name]
	).is_same(scene_root)

#endregion
