## Unit tests for TargetingShapeCast2D component
##
## **DESIGN DECISION:** Tests include Manipulatable component interaction because:
## - TargetingShapeCast2D has built-in search logic for finding Manipulatable roots
## - This is core functionality being tested (not separate primary script testing)
## - The interaction tests are minimal and focused on targeting's responsibility
## - Separation would require duplicating complex setup logic for minimal benefit
extends GdUnitTestSuite

var runner: GdUnitSceneRunner

func test_force_shapecast_update_no_crash() -> void:
	# Create a TargetingShapeCast2D instance with a valid shape and ensure update_target() is safe
	var sc: TargetingShapeCast2D = TargetingShapeCast2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	sc.shape = shape
	add_child(sc)
	# No dependencies injected -> update_target() returns early without touching physics
	sc.update_target()
	assert_bool(true).is_true()

func test_is_colliding_and_get_collider_behavior() -> void:
	var sc: TargetingShapeCast2D = TargetingShapeCast2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	add_child(sc)
	# By default, no colliders present
	assert_bool(sc.is_colliding()).append_failure_message("New TargetingShapeCast2D should not be colliding by default").is_false()
	# Do not call get_collider() when not colliding; engine raises 'No collider found'
	# This assertion is sufficient for default behavior

func test_targeting_detects_static_body_with_matching_collision_layers() -> void:
	# Test: TargetingShapeCast2D with mask 513 (bits 1+9) should detect StaticBody2D on layer 513
	# Setup: Create ShapeCast2D with mask 513, create StaticBody2D with layer 513 at same position
	# Note: ShapeCast2D can ONLY detect PhysicsBody2D nodes (StaticBody2D, RigidBody2D, CharacterBody2D), NOT Area2D!
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	# Create TargetingShapeCast2D with realistic configuration
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(15.9, 15.9)  # Same as template
	sc.shape = shape
	sc.collision_mask = 513  # Bits 1+9 (same as grid_positioner_stack.tscn - detects StaticBody2D)
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create StaticBody2D target with collision layer 513 (bits 1+9, same as smithy's StaticBody2D)
	var target_body: StaticBody2D = auto_free(StaticBody2D.new())
	target_body.collision_layer = 513  # Bits 1+9: 1 + 512
	target_body.collision_mask = 0  # Body doesn't need to detect anything
	var target_shape: CollisionShape2D = CollisionShape2D.new()
	var target_rect := RectangleShape2D.new()
	target_rect.size = Vector2(64, 64)
	target_shape.shape = target_rect
	target_body.add_child(target_shape)
	add_child(target_body)
	
	# Position both at same location for guaranteed overlap
	sc.global_position = Vector2(100, 100)
	target_body.global_position = Vector2(100, 100)
	
	# Wait for physics to process
	runner.simulate_frames(2)
	
	# Act: Update target (this is what _physics_process does)
	sc.update_target()
	
	# Assert: ShapeCast should detect the StaticBody2D
	assert_bool(sc.is_colliding()).append_failure_message(
		"TargetingShapeCast2D (mask=%d) should detect StaticBody2D (layer=%d) - bits 1+9 match. ShapeCast pos=%s, Body pos=%s" % 
		[sc.collision_mask, target_body.collision_layer, str(sc.global_position), str(target_body.global_position)]
	).is_true()
	
	# Assert: GridTargetingState.target should be updated
	assert_object(targeting_state.get_target()).append_failure_message(
		"GridTargetingState.target should be set to the detected StaticBody2D after update_target(). Currently: %s" % 
		str(targeting_state.get_target())
	).is_not_null()
	
	if targeting_state.get_target() != null:
		assert_object(targeting_state.get_target()).append_failure_message(
			"GridTargetingState.target should be the StaticBody2D we created"
		).is_same(target_body)

func test_targeting_continuous_update_via_physics_process() -> void:
	# Test: _physics_process should continuously update targeting state
	# Setup: Create ShapeCast2D with dependencies and target StaticBody2D
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(15.9, 15.9)
	sc.shape = shape
	sc.collision_mask = 513  # Bits 1+9 to detect StaticBody2D
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create target StaticBody2D
	var target_body: StaticBody2D = auto_free(StaticBody2D.new())
	target_body.collision_layer = 513  # Direct match
	var target_shape: CollisionShape2D = CollisionShape2D.new()
	var target_rect := RectangleShape2D.new()
	target_rect.size = Vector2(32, 32)
	target_shape.shape = target_rect
	target_body.add_child(target_shape)
	add_child(target_body)
	
	# Position for overlap
	sc.global_position = Vector2(200, 200)
	target_body.global_position = Vector2(200, 200)
	
	# Wait for multiple physics frames - _physics_process should update automatically
	runner.simulate_frames(3)
	
	# Assert: After physics frames, target should be detected automatically
	assert_object(targeting_state.get_target()).append_failure_message(
		"After physics frames, GridTargetingState.target should be set by _physics_process. Currently: %s" % 
		str(targeting_state.get_target())
	).is_not_null()
	
	assert_bool(sc.is_colliding()).append_failure_message(
		"ShapeCast2D should be colliding with StaticBody2D after physics frames"
	).is_true()


func test_targeting_detects_object_without_leaving_collision_area() -> void:
	# Test: REGRESSION - TargetingShapeCast2D should detect object even if mouse
	# stays within collision bounds (doesn't need to leave and re-enter)
	# This reproduces the issue where hovering over an already-present object
	# doesn't set the target until mouse leaves and comes back
	
	# Setup: Create environment with ShapeCast and target object
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513  # Bits 1+9
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create target object
	var target_body: StaticBody2D = auto_free(StaticBody2D.new())
	target_body.collision_layer = 513
	var target_shape: CollisionShape2D = CollisionShape2D.new()
	var target_rect := RectangleShape2D.new()
	target_rect.size = Vector2(64, 64)
	target_shape.shape = target_rect
	target_body.add_child(target_shape)
	target_body.name = "TargetObject"
	add_child(target_body)
	
	# Scenario: Object already exists, no target set yet
	# Position ShapeCast directly over the object (mouse already hovering)
	target_body.global_position = Vector2(300, 300)
	sc.global_position = Vector2(300, 300)  # Already over the object
	
	# Verify no target set initially
	assert_object(targeting_state.get_target()).append_failure_message(
		"Initial state: target should be null before physics update"
	).is_null()
	
	# Wait for physics - this is the critical moment
	runner.simulate_frames(2)
	
	# EXPECTED: Target should now be set because ShapeCast is colliding
	# ACTUAL BUG: Target stays null until mouse moves out and back in
	assert_bool(sc.is_colliding()).append_failure_message(
		"ShapeCast should detect collision when positioned over object. " +
		"ShapeCast pos=%s, Target pos=%s, ShapeCast enabled=%s" % 
		[str(sc.global_position), str(target_body.global_position), str(sc.enabled)]
	).is_true()
	
	# This is the failing assertion that reveals the bug
	assert_object(targeting_state.get_target()).append_failure_message(
		"REGRESSION: Target should be set when ShapeCast is already over object, " +
		"without needing to move mouse out and back in. " +
		"is_colliding=%s, collider=%s, target=%s" % 
		[str(sc.is_colliding()), 
		 str(sc.get_collider(0)) if sc.is_colliding() else "none",
		 str(targeting_state.get_target())]
	).is_not_null()
	
	# Verify it's the correct target
	if targeting_state.get_target() != null:
		assert_object(targeting_state.get_target()).append_failure_message(
			"Target should be the object we positioned ShapeCast over"
		).is_same(target_body)


func test_targeting_updates_when_target_changes_to_null() -> void:
	# Test: When target is cleared (set to null), ShapeCast should detect
	# any object it's currently colliding with on the next update
	
	# Setup
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create two target objects
	var object_a: StaticBody2D = auto_free(StaticBody2D.new())
	object_a.collision_layer = 513
	object_a.name = "ObjectA"
	var shape_a: CollisionShape2D = CollisionShape2D.new()
	var rect_a := RectangleShape2D.new()
	rect_a.size = Vector2(64, 64)
	shape_a.shape = rect_a
	object_a.add_child(shape_a)
	object_a.global_position = Vector2(100, 100)
	add_child(object_a)
	
	var object_b: StaticBody2D = auto_free(StaticBody2D.new())
	object_b.collision_layer = 513
	object_b.name = "ObjectB"
	var shape_b: CollisionShape2D = CollisionShape2D.new()
	var rect_b := RectangleShape2D.new()
	rect_b.size = Vector2(64, 64)
	shape_b.shape = rect_b
	object_b.add_child(shape_b)
	object_b.global_position = Vector2(200, 200)
	add_child(object_b)
	
	# Step 1: Position over ObjectA and let it be targeted
	sc.global_position = Vector2(100, 100)
	runner.simulate_frames(2)
	
	assert_object(targeting_state.get_target()).append_failure_message(
		"Step 1: ObjectA should be targeted"
	).is_same(object_a)
	
	# Step 2: Move ShapeCast over ObjectB
	sc.global_position = Vector2(200, 200)
	runner.simulate_frames(2)
	
	# Target should automatically update to ObjectB
	assert_object(targeting_state.get_target()).append_failure_message(
		"Step 2: Target should update to ObjectB when ShapeCast moves over it. " +
		"is_colliding=%s, current_target=%s" %
		[str(sc.is_colliding()), str(targeting_state.get_target())]
	).is_same(object_b)
	
	# Step 3: Manually clear target (simulating manipulation end or other system clearing)
	targeting_state.clear()
	runner.simulate_frames(1)
	
	# Step 4: ShapeCast is STILL over ObjectB - it should re-detect it
	# This is the key scenario: after target is cleared, does ShapeCast
	# detect the object it's already hovering over?
	runner.simulate_frames(1)

	assert_object(targeting_state.get_target()).append_failure_message(
		"Step 4: After target cleared, ShapeCast should re-detect ObjectB " +
		"that it's still hovering over. is_colliding=%s, target=%s" %
		[str(sc.is_colliding()), str(targeting_state.get_target())]
	).is_same(object_b)


func test_targeting_after_external_target_clear_while_hovering() -> void:
	# Test: SPECIFIC REGRESSION - After external system clears target while
	# ShapeCast is hovering over an object, the target should be re-set
	# on the next physics frame WITHOUT needing mouse movement
	#
	# Scenario:
	# 1. Multiple objects have been manipulated/moved
	# 2. Some external system clears targeting_state.target to null
	# 3. ShapeCast is still physically hovering over an object
	# 4. Expected: Target should be detected immediately on next physics frame
	# 5. Bug: Target stays null until mouse leaves and re-enters collision shape
	
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create persistent object that will be hovered over
	var persistent_obj: StaticBody2D = auto_free(StaticBody2D.new())
	persistent_obj.collision_layer = 513
	persistent_obj.name = "PersistentObject"
	var obj_shape: CollisionShape2D = CollisionShape2D.new()
	var obj_rect := RectangleShape2D.new()
	obj_rect.size = Vector2(64, 64)
	obj_shape.shape = obj_rect
	persistent_obj.add_child(obj_shape)
	persistent_obj.global_position = Vector2(100, 100)
	add_child(persistent_obj)
	
	# Simulate: ShapeCast hovering over object and target is set
	sc.global_position = Vector2(100, 100)
	runner.simulate_frames(2)
	
	assert_object(targeting_state.get_target()).append_failure_message(
		"Setup: Target should be set to persistent object"
	).is_same(persistent_obj)
	
	# Critical step: EXTERNAL system clears target (e.g., after manipulation)
	# ShapeCast position has NOT changed - still hovering over the object
	targeting_state.clear()
	
	# Verify target is cleared
	assert_object(targeting_state.get_target()).append_failure_message(
		"After external clear: target should be null"
	).is_null()
	
	# ShapeCast should still be detecting collision
	assert_bool(sc.is_colliding()).append_failure_message(
		"ShapeCast should still be colliding with persistent object after target cleared"
	).is_true()
	
	# Now the critical moment: next physics frame
	# ShapeCast._physics_process() will call update_target()
	# Should it re-set the target even though it's the "same" object?
	runner.simulate_frames(1)
	
	# THE BUG: This assertion should pass but currently fails
	# because update_target() sees old_target (null) != promoted_target (persistent_obj)
	# Wait... that should actually work! Let me check the actual condition...
	var collider_str: String = "none"
	if sc.is_colliding():
		collider_str = str(sc.get_collider(0))
	
	var failure_msg: String = "REGRESSION: After external clear, ShapeCast should re-detect object it's still hovering over. is_colliding=%s, collider=%s, old_target_was_null=true, current_target=%s" % [str(sc.is_colliding()), collider_str, str(targeting_state.get_target())]
	
	assert_object(targeting_state.get_target()).append_failure_message(failure_msg).is_not_null()
	
	assert_object(targeting_state.get_target()).append_failure_message(
		"Re-detected target should be the persistent object"
	).is_same(persistent_obj)


#region Metadata-Based Root Targeting Tests

func test_root_node_metadata_on_collision_object_redirects_to_root() -> void:
	# Test: When collision object has root_node metadata, targeting should redirect to that node
	# Setup: Create Node2D root with Area2D child. Area2D has root_node metadata pointing to root
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513  # Bits 1+9
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create scene structure: RootNode2D -> StaticBody2D (with gb_root_node metadata)
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "LogicalRoot"
	root_node.global_position = Vector2(100, 100)
	add_child(root_node)
	
	var collision_body: StaticBody2D = StaticBody2D.new()
	collision_body.name = "CollisionChild"
	collision_body.collision_layer = 513
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(32, 32)
	body_shape.shape = body_rect
	collision_body.add_child(body_shape)
	root_node.add_child(collision_body)
	
	# Set metadata on collision body pointing to root
	collision_body.set_meta("root_node", root_node)
	
	# Position ShapeCast over collision body
	sc.global_position = Vector2(100, 100)
	runner.simulate_frames(2)
	
	# Assert: Target should be collision body, target_root should be the resolved root node
	assert_object(targeting_state.get_collider()).append_failure_message(
		"Target should be the collision body. Got: %s, ShapeCast colliding: %s" % 
		[str(targeting_state.get_collider()), str(sc.is_colliding())]
	).is_same(collision_body)
	
	assert_object(targeting_state.get_target()).append_failure_message(
		"Target root should be redirected to root node via root_node metadata. " +
		"Expected: %s, Got: %s" % 
		[root_node.name, str(targeting_state.get_target())]
	).is_same(root_node)


func test_root_node_metadata_hierarchical_search() -> void:
	# Test: Should find Manipulatable component in sibling/child hierarchy
	# Setup: Collision object with sibling Manipulatable that has root
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create hierarchy: Parent -> [Collision, Manipulatable with root]
	var parent_node: Node2D = auto_free(Node2D.new())
	parent_node.name = "ParentNode"
	parent_node.global_position = Vector2(200, 200)
	add_child(parent_node)
	
	var root_node: Node2D = Node2D.new()
	root_node.name = "ActualRoot"
	parent_node.add_child(root_node)
	
	var manipulatable: Manipulatable = Manipulatable.new()
	manipulatable.name = "ManipulatableComponent"
	manipulatable.root = root_node
	parent_node.add_child(manipulatable)
	
	var collision_body: StaticBody2D = StaticBody2D.new()
	collision_body.name = "CollisionSibling"
	collision_body.collision_layer = 513
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(32, 32)
	body_shape.shape = body_rect
	collision_body.add_child(body_shape)
	parent_node.add_child(collision_body)
	
	# Position ShapeCast
	sc.global_position = Vector2(200, 200)
	runner.simulate_frames(2)
	
	# Assert: target should be collision body, target_root should be resolved via Manipulatable
	assert_object(targeting_state.get_collider()).append_failure_message(
		"Target should be the collision body. Got: %s" % [str(targeting_state.get_collider())]
	).is_same(collision_body)
	
	assert_object(targeting_state.get_target()).append_failure_message(
		"Target root should be resolved via sibling Manipulatable search. " +
		"Expected: %s, Got: %s" % [root_node.name, str(targeting_state.get_target())]
	).is_same(root_node)


func test_root_node_metadata_max_depth_limit() -> void:
	# Test: Child search should only go 1 level deep (not recursive)
	# Setup: Collision with nested children, only direct child Manipulatable should be found
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create collision with direct child (should be found) and grandchild (should NOT be found)
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "ParentCollision"
	collision_body.collision_layer = 513
	collision_body.global_position = Vector2(300, 300)
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(32, 32)
	body_shape.shape = body_rect
	collision_body.add_child(body_shape)
	add_child(collision_body)
	
	# Add a direct child Manipulatable (1 level deep - should be found)
	var root_node: Node2D = Node2D.new()
	root_node.name = "DirectChildRoot"
	collision_body.add_child(root_node)
	
	var direct_manipulatable: Manipulatable = Manipulatable.new()
	direct_manipulatable.name = "DirectManipulatable"
	direct_manipulatable.root = root_node
	collision_body.add_child(direct_manipulatable)
	
	# Add a nested grandchild Manipulatable (2 levels deep - should NOT be found)
	var intermediate: Node2D = Node2D.new()
	intermediate.name = "IntermediateNode"
	collision_body.add_child(intermediate)
	
	var deep_root: Node2D = Node2D.new()
	deep_root.name = "DeepRoot"
	intermediate.add_child(deep_root)
	
	var deep_manipulatable: Manipulatable = Manipulatable.new()
	deep_manipulatable.name = "DeepManipulatable"
	deep_manipulatable.root = deep_root
	intermediate.add_child(deep_manipulatable)
	
	# Position ShapeCast
	sc.global_position = Vector2(300, 300)
	runner.simulate_frames(2)
	
	# Assert: target should be collision body, target_root should be resolved from direct child
	assert_object(targeting_state.get_collider()).append_failure_message(
		"Target should be the collision body. Got: %s" % [str(targeting_state.get_collider())]
	).is_same(collision_body)
	
	assert_object(targeting_state.get_target()).append_failure_message(
		"Target root should be resolved from direct child Manipulatable (1 level), not grandchild (2 levels). " +
		"Expected: %s, Got: %s" % [root_node.name, str(targeting_state.get_target())]
	).is_same(root_node)


func test_root_node_metadata_invalid_value_fallback() -> void:
	# Test: If root_node metadata exists but points to invalid node, fallback gracefully
	# Setup: Collision object with root_node metadata pointing to null/freed node
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create collision object with invalid metadata
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "InvalidMetadataBody"
	collision_body.collision_layer = 513
	collision_body.global_position = Vector2(400, 400)
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(32, 32)
	body_shape.shape = body_rect
	collision_body.add_child(body_shape)
	add_child(collision_body)
	
	# Set metadata to null (invalid)
	collision_body.set_meta("root_node", null)
	
	# Position ShapeCast
	sc.global_position = Vector2(400, 400)
	runner.simulate_frames(2)
	
	# Assert: Should fallback to collision body itself
	assert_object(targeting_state.get_target()).append_failure_message(
		"Target should fallback to collision body when metadata value is invalid (null). " +
		"Expected: %s, Got: %s" % [collision_body.name, str(targeting_state.get_target())]
	).is_same(collision_body)


func test_root_node_metadata_wrong_type_fallback() -> void:
	# Test: If root_node metadata points to non-Node2D, fallback gracefully
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create collision object with wrong type metadata
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.name = "WrongTypeMetadata"
	collision_body.collision_layer = 513
	collision_body.global_position = Vector2(500, 500)
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(32, 32)
	body_shape.shape = body_rect
	collision_body.add_child(body_shape)
	add_child(collision_body)
	
	# Set metadata to a Node (not Node2D) - wrong type
	var wrong_node := Node.new()  # Plain Node, not Node2D
	wrong_node.name = "NotANode2D"
	add_child(wrong_node)
	collision_body.set_meta("root_node", wrong_node)
	
	# Position ShapeCast
	sc.global_position = Vector2(500, 500)
	runner.simulate_frames(2)
	
	# Assert: Should fallback to collision body when metadata wrong type
	assert_object(targeting_state.get_target()).append_failure_message(
		"Target should fallback to collision body when metadata type is not Node2D. " +
		"Expected: %s, Got: %s" % [collision_body.name, str(targeting_state.get_target())]
	).is_same(collision_body)


func test_root_node_metadata_backward_compatibility() -> void:
	# Test: Existing scenes without metadata should work unchanged (backward compatibility)
	# Setup: Traditional Area2D-rooted scene with NO metadata
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Traditional structure: Area2D root with StaticBody2D child (NO metadata)
	var area_root: StaticBody2D = auto_free(StaticBody2D.new())
	area_root.name = "TraditionalStaticBody"
	area_root.collision_layer = 513
	area_root.global_position = Vector2(600, 600)
	var area_shape: CollisionShape2D = CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(32, 32)
	area_shape.shape = area_rect
	area_root.add_child(area_shape)
	add_child(area_root)
	
	# Position ShapeCast
	sc.global_position = Vector2(600, 600)
	runner.simulate_frames(2)
	
	# Assert: Should target the StaticBody2D itself (traditional behavior)
	assert_object(targeting_state.get_target()).append_failure_message(
		"Backward compatibility: Traditional scenes without metadata should target collision object. " +
		"Expected: %s, Got: %s" % [area_root.name, str(targeting_state.get_target())]
	).is_same(area_root)


func test_root_node_metadata_self_reference() -> void:
	# Test: Node can set root_node metadata to itself (common pattern for root nodes)
	var container: GBCompositionContainer = auto_free(GBCompositionContainer.new())
	var targeting_state: GridTargetingState = container.get_states().targeting
	
	var sc: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	sc.collision_mask = 513
	sc.target_position = Vector2.ZERO
	add_child(sc)
	sc.resolve_gb_dependencies(container)
	
	# Create root that is also the collision object (references itself)
	var self_root: StaticBody2D = auto_free(StaticBody2D.new())
	self_root.name = "SelfReferencingRoot"
	self_root.collision_layer = 513
	self_root.global_position = Vector2(700, 700)
	var self_shape: CollisionShape2D = CollisionShape2D.new()
	var self_rect := RectangleShape2D.new()
	self_rect.size = Vector2(32, 32)
	self_shape.shape = self_rect
	self_root.add_child(self_shape)
	add_child(self_root)
	
	# Set metadata to self
	self_root.set_meta("root_node", self_root)
	
	# Position ShapeCast
	sc.global_position = Vector2(700, 700)
	runner.simulate_frames(2)
	
	# Assert: Should resolve to self (no-op but valid)
	assert_object(targeting_state.get_target()).append_failure_message(
		"Self-referencing metadata should work (node references itself as root). " +
		"Expected: %s, Got: %s" % [self_root.name, str(targeting_state.get_target())]
	).is_same(self_root)

#endregion


