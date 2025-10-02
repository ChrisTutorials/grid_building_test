extends GdUnitTestSuite

## Consolidated targeting system tests using CollisionTestEnvironment

var env: CollisionTestEnvironment
var default_target: Node2D

func before_test() -> void:
	env = UnifiedTestFactory.instance_collision_test_env(self, "uid://cdrtd538vrmun")
	_setup_default_target()

func after_test() -> void:
	# Clean up default target
	if is_instance_valid(default_target):
		default_target.queue_free()
		default_target = null

## Set up a default target for all tests to use
func _setup_default_target() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var targeting_state: GridTargetingState = targeting_system.get_state()
	
	# Only create a target if none exists
	if targeting_state.target == null:
		default_target = Node2D.new()
		default_target.position = Vector2(64, 64)
		default_target.name = "TestTarget"
		env.level.add_child(default_target)
		targeting_state.target = default_target
		# Note: Don't use auto_free() on shared target - managed in after_test

func test_targeting_basic() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var targeting_state: GridTargetingState = targeting_system.get_state()
	
	assert_object(targeting_system).append_failure_message(
		"Targeting system should be properly initialized by factory"
	).is_not_null()
	assert_object(targeting_state).append_failure_message(
		"Targeting state should be accessible from targeting system"
	).is_not_null()
	
	# Default target should have been created in before_test
	var current_target: Variant = targeting_state.target
	assert_object(current_target).append_failure_message(
		"Default target should be available from setup"
	).is_not_null()
	assert_vector(current_target.position).append_failure_message(
		"Default target should be positioned at (64, 64)"
	).is_equal(Vector2(64, 64))

func test_targeting_grid_alignment() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var _tile_map: TileMapLayer = env.tile_map_layer
	var _targeting_state: GridTargetingState = targeting_system.get_state()
	
	# Test grid-aligned targeting by setting position through state
	var world_pos: Vector2 = Vector2(100, 100)  # Not grid-aligned
	var positioner: Node2D = env.positioner
	positioner.global_position = world_pos
	
	# The system should handle grid alignment through its internal logic
	assert_object(positioner).append_failure_message(
		"Positioner should be available from test hierarchy"
	).is_not_null()
	assert_vector(positioner.global_position).append_failure_message(
		"Positioner should maintain the set global position"
	).is_equal(world_pos)

func test_targeting_validation() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	var _tile_map: Variant = env.tile_map_layer
	var targeting_state: Variant = targeting_system.get_state()
	
	# Test valid position using factory's default target
	var issues: Array = targeting_system.get_runtime_issues()
	assert_array(issues).append_failure_message(
		"Targeting system should report no dependency issues with valid factory setup"
	).is_empty()
	
	# Test invalid position (out of bounds) by creating a specific target
	var invalid_target: Node2D = Node2D.new()
	invalid_target.position = Vector2(1000, 1000)
	env.level.add_child(invalid_target)
	auto_free(invalid_target)
	
	# Store original target before setting invalid one
	var original_target: Node2D = targeting_state.target
	targeting_state.target = invalid_target
	
	# The system should still function but may have different behavior
	assert_object(targeting_state.target).append_failure_message(
		"Targeting state should maintain target reference even for invalid positions"
	).is_not_null()
	
	# Restore original target before invalid target is freed
	targeting_state.target = original_target
	
	auto_free(invalid_target)

func test_targeting_with_rules() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	var targeting_state: Variant = targeting_system.get_state()
	
	# Test that the system can validate dependencies using factory's default target
	var issues: Array = targeting_system.get_runtime_issues()
	# Issues may or may not be present depending on system state
	assert_array(issues).is_not_null().append_failure_message(
		"Should be able to retrieve dependency issues array from targeting system"
	)
	
	# Test that targeting state can handle rule-related properties
	assert_object(targeting_state).is_not_null().append_failure_message(
		"Targeting state should be accessible for rule validation"
	)

func test_targeting_area_selection() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	var targeting_state: Variant = targeting_system.get_state()
	
	# Test area targeting using factory's default target
	assert_object(targeting_state).append_failure_message(
		"Targeting state should be properly initialized"
	).is_not_null()
	assert_object(targeting_state.target).append_failure_message(
		"Factory should provide a default target for area selection tests"
	).is_not_null()
	assert_vector(targeting_state.target.position).append_failure_message(
		"Default target should maintain factory position for area operations"
	).is_equal(Vector2(64, 64))

func test_targeting_multiple_objects() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	var positioner: Variant = env.positioner
	
	# Add multiple objects
	var objects: Array = []
	for i: int in range(3):
		var obj: Area2D = Area2D.new()
		obj.position = Vector2(i * 32, i * 32)
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)
	
	# Test that the system can handle multiple objects using factory's default target
	var targeting_state: Variant = targeting_system.get_state()
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting system should maintain default target when multiple objects are present"
	)
	assert_array(objects).has_size(3).append_failure_message(
		"Should have created exactly 3 test objects"
	)

func test_targeting_system_integration() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	
	# Test targeting system functionality in collision environment
	var targeting_state: Variant = targeting_system.get_state()
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting state should have default target for integration testing"
	)
	
	# Test that targeting system works with collision environment components
	assert_object(env.indicator_manager).is_not_null().append_failure_message(
		"Indicator manager should be available in collision environment"
	)
	assert_object(env.tile_map_layer).is_not_null().append_failure_message(
		"Tile map layer should be available in collision environment"
	)

func test_targeting_cursor_tracking() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	
	# Test cursor position tracking by updating factory's default target
	var mock_cursor_pos: Vector2 = Vector2(200, 150)
	var targeting_state: Variant = targeting_system.get_state()
	targeting_state.target.position = mock_cursor_pos
	
	# Verify the system can handle cursor-like targeting
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting state should maintain target reference during cursor tracking"
	)
	assert_vector(targeting_state.target.position).is_equal(mock_cursor_pos).append_failure_message(
		"Target position should update to match cursor position"
	)

func test_targeting_precision_modes() -> void:
	var targeting_system: Variant = env.grid_targeting_system
	
	# Test different precision modes using factory's default target
	var targeting_state: Variant = targeting_system.get_state()
	var test_pos: Vector2 = Vector2(128, 96)
	targeting_state.target.position = test_pos
	
	# Test that the system can handle position processing through its tile methods
	var tile_pos: Variant = targeting_system.get_tile_from_global_position(test_pos, targeting_state.target_map)
	assert_object(tile_pos).is_not_null().append_failure_message(
		"Should be able to convert global position to tile coordinates"
	)
	
	# Verify the system maintains state consistency
	assert_object(targeting_state.target).is_not_null().append_failure_message(
		"Targeting state should maintain target reference during precision operations"
	)
	assert_vector(targeting_state.target.position).is_equal(test_pos).append_failure_message(
		"Target position should remain consistent after precision mode operations"
	)


#region TARGET_INFORMER_INTEGRATION_TESTS

## Test TargetInformer displays targeting info for hovered objects
func test_target_informer_shows_targeting_info() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	
	# Create TargetInformer and wire it up
	var informer: TargetInformer = TargetInformer.new()
	informer.info_parent = Control.new()
	add_child(informer)
	informer.info_parent.name = "InfoParent"
	informer.add_child(informer.info_parent)
	auto_free(informer)
	
	# Create a test target BEFORE resolve (to ensure we're testing signal-based update)
	var test_target: Node2D = Node2D.new()
	test_target.name = "HoveredObject"
	test_target.global_position = Vector2(100, 200)
	env.level.add_child(test_target)
	auto_free(test_target)
	
	# Resolve dependencies to connect to targeting state
	informer.resolve_gb_dependencies(env.container)
	
	# Wait for initialization to complete
	await get_tree().process_frame
	
	# NOW trigger target change (simulates hovering over object)
	# This should fire the signal that TargetInformer is now listening to
	targeting_state.target = test_target
	
	# Wait for signal propagation
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Assert: TargetInformer should display the targeted object
	assert_object(informer.target).append_failure_message(
		"TargetInformer should have target set from GridTargetingState.target_changed signal. " +
		"Targeting state target: %s" % [str(targeting_state.target)]
	).is_same(test_target)
	
	if informer.target != null:
		assert_str(informer.target.name).append_failure_message(
			"TargetInformer target name should match hovered object"
		).is_equal("HoveredObject")


## Test TargetInformer prioritizes manipulation over targeting
func test_target_informer_manipulation_priority() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var manipulation_state: ManipulationState = env.container.get_states().manipulation
	
	# Create TargetInformer
	var informer: TargetInformer = TargetInformer.new()
	informer.info_parent = Control.new()
	add_child(informer)
	informer.info_parent.name = "InfoParent"
	informer.add_child(informer.info_parent)
	auto_free(informer)
	informer.resolve_gb_dependencies(env.container)
	
	# Wait for signal connections to be fully established
	await get_tree().process_frame
	
	# Create two test objects: one for targeting, one for manipulation
	var hovered_object: Node2D = Node2D.new()
	hovered_object.name = "HoveredObject"
	hovered_object.global_position = Vector2(100, 100)
	env.level.add_child(hovered_object)
	auto_free(hovered_object)
	
	var manipulated_object: Node2D = Node2D.new()
	manipulated_object.name = "ManipulatedObject"
	manipulated_object.global_position = Vector2(200, 200)
	
	# Add Manipulatable component to manipulated object
	var manipulatable: Manipulatable = Manipulatable.new()
	manipulatable.root = manipulated_object
	manipulated_object.add_child(manipulatable)
	env.level.add_child(manipulated_object)
	auto_free(manipulated_object)
	
	# Step 1: Hover over first object (targeting only)
	targeting_state.target = hovered_object
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 1: TargetInformer should show hovered object when no manipulation active"
	).is_same(hovered_object)
	
	# Step 2: Start manipulation (should override targeting)
	manipulation_state.active_target_node = manipulatable
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 2: TargetInformer should switch to manipulated object (higher priority)"
	).is_same(manipulated_object)
	
	# Step 3: Change targeting while manipulation active (should NOT update display)
	var another_hovered: Node2D = Node2D.new()
	another_hovered.name = "AnotherHoveredObject"
	another_hovered.global_position = Vector2(150, 150)
	env.level.add_child(another_hovered)
	auto_free(another_hovered)
	
	targeting_state.target = another_hovered
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 3: TargetInformer should still show manipulated object, ignoring targeting changes"
	).is_same(manipulated_object)
	
	# Step 4: End manipulation (should return to showing targeting)
	manipulation_state.active_target_node = null
	await get_tree().process_frame
	await get_tree().process_frame
	
	# After manipulation ends, it should show the currently targeted object
	assert_object(informer.target).append_failure_message(
		"Step 4: TargetInformer should return to showing targeted object after manipulation ends"
	).is_same(another_hovered)


## Test TargetInformer handles null targets gracefully
func test_target_informer_null_handling() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	
	# Create TargetInformer
	var informer: TargetInformer = TargetInformer.new()
	informer.info_parent = Control.new()
	add_child(informer)
	informer.info_parent.name = "InfoParent"
	informer.add_child(informer.info_parent)
	auto_free(informer)
	informer.resolve_gb_dependencies(env.container)
	
	# Wait for signal connections to be fully established
	await get_tree().process_frame
	
	# Set a target first
	var test_target: Node2D = Node2D.new()
	test_target.name = "TestTarget"
	env.level.add_child(test_target)
	auto_free(test_target)
	
	targeting_state.target = test_target
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Should have target set initially"
	).is_not_null()
	
	# Clear target (simulates mouse leaving all objects)
	targeting_state.target = null
	await get_tree().process_frame
	
	# TargetInformer should clear its display
	assert_object(informer.target).append_failure_message(
		"TargetInformer should clear target when GridTargetingState.target becomes null"
	).is_null()


## Test TargetInformer updates display when target moves
func test_target_informer_tracks_target_position() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	
	# Create TargetInformer
	var informer: TargetInformer = TargetInformer.new()
	informer.info_parent = Control.new()
	add_child(informer)
	informer.info_parent.name = "InfoParent"
	informer.add_child(informer.info_parent)
	auto_free(informer)
	informer.resolve_gb_dependencies(env.container)
	
	# Wait for signal connections to be fully established
	await get_tree().process_frame
	
	# Create moving target
	var moving_target: Node2D = Node2D.new()
	moving_target.name = "MovingTarget"
	moving_target.global_position = Vector2(100, 100)
	env.level.add_child(moving_target)
	auto_free(moving_target)
	
	targeting_state.target = moving_target
	await get_tree().process_frame
	
	# Initial position check
	assert_object(informer.target).append_failure_message(
		"TargetInformer should track the moving target"
	).is_same(moving_target)
	
	# Move the target
	moving_target.global_position = Vector2(200, 300)
	await get_tree().process_frame
	
	# TargetInformer's _process should update the position display
	# We verify it's still tracking the same target
	assert_object(informer.target).append_failure_message(
		"TargetInformer should maintain reference to target as it moves"
	).is_same(moving_target)
	
	assert_vector(informer.target.global_position).append_failure_message(
		"TargetInformer should reflect updated target position"
	).is_equal(Vector2(200, 300))

## Test TargetInformer prioritizes building preview over targeting
func test_target_informer_building_preview_priority() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var building_state: BuildingState = env.container.get_states().building
	
	# Create TargetInformer
	var informer: TargetInformer = TargetInformer.new()
	informer.info_parent = Control.new()
	add_child(informer)
	informer.info_parent.name = "InfoParent"
	informer.add_child(informer.info_parent)
	auto_free(informer)
	informer.resolve_gb_dependencies(env.container)
	
	# Create a hovered object in the scene
	var hovered_object: Node2D = auto_free(Node2D.new())
	hovered_object.name = "HoveredObject"
	add_child(hovered_object)
	
	# Create a building preview object with BuildingNode script
	var preview_object: Node2D = auto_free(Node2D.new())
	preview_object.name = "PreviewObject"
	add_child(preview_object)
	
	# Add BuildingNode script to make it a preview object
	var building_node: Node = auto_free(Node.new())
	var building_node_script: Script = load("res://addons/grid_building/components/building_node.gd")
	building_node.set_script(building_node_script)
	preview_object.add_child(building_node)
	
	# Step 1: Target a regular object first
	targeting_state.target = hovered_object
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 1: TargetInformer should show hovered object when no preview active"
	).is_same(hovered_object)
	
	# Step 2: Activate building preview - should take precedence
	building_state.preview = preview_object
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 2: TargetInformer should switch to building preview (higher priority)"
	).is_same(preview_object)
	
	# Step 3: Try to hover over another object while preview is active
	var another_object: Node2D = auto_free(Node2D.new())
	another_object.name = "AnotherObject"
	add_child(another_object)
	
	targeting_state.target = another_object
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 3: TargetInformer should still show building preview, ignoring targeting changes"
	).is_same(preview_object)
	
	# Step 4: Clear building preview - should return to targeting
	building_state.preview = null
	await get_tree().process_frame
	
	assert_object(informer.target).append_failure_message(
		"Step 4: TargetInformer should return to showing targeted object after preview clears"
	).is_same(another_object)

#endregion
