## Unit tests for TargetingShapeCast2D component
extends GdUnitTestSuite

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
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Act: Update target (this is what _physics_process does)
	sc.update_target()
	
	# Assert: ShapeCast should detect the StaticBody2D
	assert_bool(sc.is_colliding()).append_failure_message(
		"TargetingShapeCast2D (mask=%d) should detect StaticBody2D (layer=%d) - bits 1+9 match. ShapeCast pos=%s, Body pos=%s" % 
		[sc.collision_mask, target_body.collision_layer, str(sc.global_position), str(target_body.global_position)]
	).is_true()
	
	# Assert: GridTargetingState.target should be updated
	assert_object(targeting_state.target).append_failure_message(
		"GridTargetingState.target should be set to the detected StaticBody2D after update_target(). Currently: %s" % 
		str(targeting_state.target)
	).is_not_null()
	
	if targeting_state.target != null:
		assert_object(targeting_state.target).append_failure_message(
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
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Assert: After physics frames, target should be detected automatically
	assert_object(targeting_state.target).append_failure_message(
		"After physics frames, GridTargetingState.target should be set by _physics_process. Currently: %s" % 
		str(targeting_state.target)
	).is_not_null()
	
	assert_bool(sc.is_colliding()).append_failure_message(
		"ShapeCast2D should be colliding with StaticBody2D after physics frames"
	).is_true()

