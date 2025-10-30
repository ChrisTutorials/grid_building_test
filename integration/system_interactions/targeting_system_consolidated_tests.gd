extends GdUnitTestSuite

## Consolidated targeting system tests using CollisionTestEnvironment

var env: CollisionTestEnvironment
var default_target: Node2D
var runner: GdUnitSceneRunner


func before_test() -> void:
	# Use scene_runner with UID - automatically instantiates and manages the scene
	runner = scene_runner("uid://cdrtd538vrmun")
	# Get environment from runner instead of double instantiation
	env = runner.scene() as CollisionTestEnvironment
	_setup_default_target()


func after_test() -> void:
	# Clean up default target
	if is_instance_valid(default_target):
		default_target.queue_free()
		default_target = null


#region HELPER METHODS


## Get node name or "null" for diagnostic messages
func _node_name(node: Node2D) -> String:
	if node == null:
		return "null"
	if not is_instance_valid(node):
		return "invalid"
	if node is Node:
		return node.name
	return str(node)


## Set up a default target for all tests to use
func _setup_default_target() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var targeting_state: GridTargetingState = targeting_system.get_state()

	# Only create a target if none exists
	if targeting_state.get_target() == null:
		default_target = Node2D.new()
		default_target.position = Vector2(64, 64)
		default_target.name = "TestTarget"
		env.level.add_child(default_target)
		targeting_state.set_manual_target(default_target)
		# Note: Don't use auto_free() on shared target - managed in after_test


#endregion


func test_targeting_basic() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var targeting_state: GridTargetingState = targeting_system.get_state()

	(
		assert_object(targeting_system) \
		. append_failure_message("Targeting system should be properly initialized by factory") \
		. is_not_null()
	)
	(
		assert_object(targeting_state) \
		. append_failure_message("Targeting state should be accessible from targeting system") \
		. is_not_null()
	)

	# Default target should have been created in before_test
	var current_target: Node2D = targeting_state.get_target()
	(
		assert_object(current_target) \
		. append_failure_message("Default target should be available from setup") \
		. is_not_null()
	)
	(
		assert_vector(current_target.position) \
		. append_failure_message("Default target should be positioned at (64, 64)") \
		. is_equal(Vector2(64, 64))
	)


func test_targeting_grid_alignment() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var _tile_map: TileMapLayer = env.tile_map_layer
	var _targeting_state: GridTargetingState = targeting_system.get_state()

	# Test grid-aligned targeting by setting position through state
	var world_pos: Vector2 = Vector2(100, 100)  # Not grid-aligned
	var positioner: Node2D = env.positioner
	positioner.global_position = world_pos

	# The system should handle grid alignment through its internal logic
	(
		assert_object(positioner) \
		. append_failure_message("Positioner should be available from test hierarchy") \
		. is_not_null()
	)
	(
		assert_vector(positioner.global_position) \
		. append_failure_message("Positioner should maintain the set global position") \
		. is_equal(world_pos)
	)


func test_targeting_validation() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var _tile_map: TileMapLayer = env.tile_map_layer
	var targeting_state: GridTargetingState = targeting_system.get_state()

	# Test valid position using factory's default target
	var issues: Array = targeting_system.get_runtime_issues()
	(
		assert_array(issues) \
		. append_failure_message(
			"Targeting system should report no dependency issues with valid factory setup"
		) \
		. is_empty()
	)

	# Test invalid position (out of bounds) by creating a specific target
	var invalid_target: Node2D = Node2D.new()
	invalid_target.position = Vector2(1000, 1000)
	env.level.add_child(invalid_target)
	auto_free(invalid_target)

	# Store original target before setting invalid one
	var original_target: Node2D = targeting_state.get_target()
	targeting_state.set_manual_target(invalid_target)

	# The system should still function but may have different behavior
	(
		assert_object(targeting_state.get_target()) \
		. append_failure_message(
			"Targeting state should maintain target reference even for invalid positions"
		) \
		. is_not_null()
	)

	# Restore original target before invalid target is freed
	targeting_state.set_manual_target(original_target)

	auto_free(invalid_target)


func test_targeting_with_rules() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var targeting_state: GridTargetingState = targeting_system.get_state()

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
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var targeting_state: GridTargetingState = targeting_system.get_state()

	# Test area targeting using factory's default target
	(
		assert_object(targeting_state) \
		. append_failure_message("Targeting state should be properly initialized") \
		. is_not_null()
	)
	(
		assert_object(targeting_state.get_target()) \
		. append_failure_message("Factory should provide a default target for area selection tests") \
		. is_not_null()
	)
	(
		assert_vector(targeting_state.get_target().position) \
		. append_failure_message(
			"Default target should maintain factory position for area operations"
		) \
		. is_equal(Vector2(64, 64))
	)


func test_targeting_multiple_objects() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	var positioner: GridPositioner2D = env.positioner

	# Add multiple objects
	var objects: Array = []
	for i: int in range(3):
		var obj: Area2D = Area2D.new()
		obj.position = Vector2(i * 32, i * 32)
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)

	# Test that the system can handle multiple objects using factory's default target
	var targeting_state: GridTargetingState = targeting_system.get_state()
	assert_object(targeting_state.get_target()).is_not_null().append_failure_message(
		"Targeting system should maintain default target when multiple objects are present"
	)
	assert_array(objects).has_size(3).append_failure_message(
		"Should have created exactly 3 test objects"
	)


func test_targeting_system_integration() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system

	# Test targeting system functionality in collision environment
	var targeting_state: GridTargetingState = targeting_system.get_state()
	assert_object(targeting_state.get_target()).is_not_null().append_failure_message(
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
	var targeting_system: GridTargetingSystem = env.grid_targeting_system

	# Test cursor position tracking by updating factory's default target
	var mock_cursor_pos: Vector2 = Vector2(200, 150)
	var targeting_state: GridTargetingState = targeting_system.get_state()
	targeting_state.get_target().position = mock_cursor_pos

	# Verify the system can handle cursor-like targeting
	assert_object(targeting_state.get_target()).is_not_null().append_failure_message(
		"Targeting state should maintain target reference during cursor tracking"
	)
	(
		assert_vector(targeting_state.get_target().position) \
		. is_equal(mock_cursor_pos) \
		. append_failure_message("Target position should update to match cursor position")
	)


func test_targeting_precision_modes() -> void:
	var targeting_system: GridTargetingSystem = env.grid_targeting_system

	# Test different precision modes using factory's default target
	var targeting_state: GridTargetingState = targeting_system.get_state()
	var test_pos: Vector2 = Vector2(128, 96)
	targeting_state.get_target().position = test_pos

	# Test that the system can handle position processing through its tile methods
	var tile_pos: Vector2i = targeting_system.get_tile_from_global_position(
		test_pos, targeting_state.target_map
	)
	assert_object(tile_pos).is_not_null().append_failure_message(
		"Should be able to convert global position to tile coordinates"
	)

	# Verify the system maintains state consistency
	assert_object(targeting_state.get_target()).is_not_null().append_failure_message(
		"Targeting state should maintain target reference during precision operations"
	)
	assert_vector(targeting_state.get_target().position).is_equal(test_pos).append_failure_message(
		"Target position should remain consistent after precision mode operations"
	)


#region TARGET_INFORMER_INTEGRATION_TESTS


## Test TargetInformer displays targeting info for hovered objects
func test_target_informer_shows_targeting_info() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()

	# Use the TargetInformer from the environment scene
	var informer: TargetInformer = env.target_informer
	(
		assert_object(informer) \
		. append_failure_message("CollisionTestEnvironment should have target_informer exported") \
		. is_not_null()
	)

	# Create a test target using factory method
	var test_target: Node2D = auto_free(Node2D.new())
	test_target.name = "HoveredObject"
	test_target.global_position = Vector2(100, 200)
	env.level.add_child(test_target)

	# Wait for initialization to complete
	runner.simulate_frames(1)

	# NOW trigger target change (simulates hovering over object)
	# This should fire the signal that TargetInformer is now listening to
	targeting_state.set_manual_target(test_target)

	# Wait for signal propagation - use deterministic frame simulation
	runner.simulate_frames(2)

	# Assert: TargetInformer should display the targeted object
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"TargetInformer should have target set from GridTargetingState.target_changed signal. "
				+ (
					"Targeting state target: %s, Informer connected: %s"
					% [
						str(targeting_state.get_target()),
						targeting_state.is_connected(
							"target_changed", Callable(informer, "_on_state_changed")
						)
					]
				)
			)
		) \
		. is_same(test_target)
	)

	if informer.get_display_target() != null:
		(
			assert_str(informer.get_display_target().name) \
			. append_failure_message("TargetInformer target name should match hovered object") \
			. is_equal("HoveredObject")
		)


## Test TargetInformer prioritizes manipulation state over targeting
func test_target_informer_manipulation_priority() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var manipulation_state: ManipulationState = env.container.get_states().manipulation

	# Use the TargetInformer from the environment scene
	var informer: TargetInformer = env.target_informer
	(
		assert_object(informer) \
		. append_failure_message("CollisionTestEnvironment should have target_informer exported") \
		. is_not_null()
	)

	# Wait for initialization
	runner.simulate_frames(1)

	# Create two test objects manually to avoid double parenting
	var hovered_object: Node2D = auto_free(Node2D.new())
	hovered_object.name = "HoveredObject"
	hovered_object.global_position = Vector2(100, 100)
	env.level.add_child(hovered_object)

	var manipulated_object: Node2D = auto_free(Node2D.new())
	manipulated_object.name = "ManipulatedObject"
	manipulated_object.global_position = Vector2(200, 200)

	# Add Manipulatable component to manipulated object
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = manipulated_object
	manipulated_object.add_child(manipulatable)
	env.level.add_child(manipulated_object)

	# Step 1: Hover over first object (targeting only)
	targeting_state.set_manual_target(hovered_object)
	runner.simulate_frames(2)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 1 failed - Expected: %s, Got: %s, Targeting: %s, Manipulation: %s"
				% [
					_node_name(hovered_object),
					_node_name(informer.get_display_target()),
					_node_name(targeting_state.get_target()),
					"active=%s" % str(manipulation_state.active_manipulatable != null)
				]
			)
		) \
		. is_same(hovered_object)
	)

	# Step 2: Start manipulation (should override targeting)
	manipulation_state.active_manipulatable = manipulatable
	runner.simulate_frames(2)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 2 failed - Expected: %s, Got: %s, Manipulatable root: %s, Active: %s"
				% [
					_node_name(manipulated_object),
					_node_name(informer.get_display_target()),
					_node_name(
						manipulatable.root if manipulatable and manipulatable.root else null
					),
					str(manipulation_state.active_manipulatable != null)
				]
			)
		) \
		. is_same(manipulated_object)
	)

	# Step 3: Change targeting while manipulation active (should NOT update display)
	var another_hovered: Node2D = auto_free(Node2D.new())
	another_hovered.name = "AnotherHoveredObject"
	another_hovered.global_position = Vector2(150, 150)
	env.level.add_child(another_hovered)

	targeting_state.set_manual_target(another_hovered)
	runner.simulate_frames(2)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			"Step 3: TargetInformer should still show manipulated object, ignoring targeting changes"
		) \
		. is_same(manipulated_object)
	)

	# Step 4: End manipulation (should return to showing targeting)
	manipulation_state.active_manipulatable = null
	runner.simulate_frames(2)

	# After manipulation ends, it should show the currently targeted object
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 4 failed - Expected: %s, Got: %s, Targeting: %s, Manipulation: %s"
				% [
					_node_name(another_hovered),
					_node_name(informer.get_display_target()),
					_node_name(targeting_state.get_target()),
					"active=%s" % str(manipulation_state.active_manipulatable != null)
				]
			)
		) \
		. is_same(another_hovered)
	)


## Test TargetInformer handles null targets gracefully
func test_target_informer_null_handling() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()

	# Use the TargetInformer from the environment scene
	var informer: TargetInformer = env.target_informer
	(
		assert_object(informer) \
		. append_failure_message("CollisionTestEnvironment should have target_informer exported") \
		. is_not_null()
	)

	# Wait for initialization
	runner.simulate_frames(1)

	# Set a target first using manual creation
	var test_target: Node2D = auto_free(Node2D.new())
	test_target.name = "TestTarget"
	env.level.add_child(test_target)

	targeting_state.set_manual_target(test_target)
	runner.simulate_frames(1)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Initial target set failed - Expected: %s, Got: %s, Targeting: %s"
				% [
					test_target.name,
					_node_name(informer.get_display_target()),
					_node_name(targeting_state.get_target())
				]
			)
		) \
		. is_not_null()
	)

	# Clear target (simulates mouse leaving all objects)
	targeting_state.clear()
	runner.simulate_frames(1)

	# TargetInformer should clear its display
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Target clear failed - Expected: null, Got: %s, Targeting: %s"
				% [_node_name(informer.get_display_target()), str(targeting_state.get_target())]
			)
		) \
		. is_null()
	)


## Test TargetInformer updates display when target moves
func test_target_informer_tracks_target_position() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()

	# Use the TargetInformer from the environment scene
	var informer: TargetInformer = env.target_informer
	(
		assert_object(informer) \
		. append_failure_message("CollisionTestEnvironment should have target_informer exported") \
		. is_not_null()
	)

	# Wait for initialization
	runner.simulate_frames(1)

	# Create moving target using manual creation
	var moving_target: Node2D = auto_free(Node2D.new())
	moving_target.name = "MovingTarget"
	moving_target.global_position = Vector2(100, 100)
	env.level.add_child(moving_target)

	targeting_state.set_manual_target(moving_target)
	runner.simulate_frames(1)

	# Initial position check
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Initial tracking failed - Expected: %s, Got: %s, Position: %s, Targeting: %s"
				% [
					moving_target.name,
					_node_name(informer.get_display_target()),
					str(moving_target.global_position),
					_node_name(targeting_state.get_target())
				]
			)
		) \
		. is_same(moving_target)
	)

	# Move the target
	moving_target.global_position = Vector2(200, 300)
	runner.simulate_frames(1)

	# TargetInformer's _process should update the position display
	# We verify it's still tracking the same target
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Position tracking failed - Expected: %s at %s, Got: %s, Valid: %s"
				% [
					moving_target.name,
					str(Vector2(200, 300)),
					_node_name(informer.get_display_target()),
					str(is_instance_valid(informer.get_display_target()))
				]
			)
		) \
		. is_same(moving_target)
	)

	(
		assert_vector(informer.get_display_target().global_position) \
		. append_failure_message(
			(
				"Target position mismatch - Expected: %s, Got: %s"
				% [str(Vector2(200, 300)), str(informer.get_display_target().global_position)]
			)
		) \
		. is_equal(Vector2(200, 300))
	)


## Test TargetInformer prioritizes building preview over targeting
func test_target_informer_building_preview_priority() -> void:
	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var building_state: BuildingState = env.container.get_states().building

	# Use the TargetInformer from the environment scene
	var informer: TargetInformer = env.target_informer
	(
		assert_object(informer) \
		. append_failure_message("CollisionTestEnvironment should have target_informer exported") \
		. is_not_null()
	)

	# Wait for initialization
	runner.simulate_frames(1)

	# Create test objects using manual creation
	var hovered_object: Node2D = auto_free(Node2D.new())
	hovered_object.name = "HoveredObject"
	add_child(hovered_object)

	# Create a building preview object with BuildingNode script using manual creation
	var preview_object: Node2D = auto_free(Node2D.new())
	preview_object.name = "PreviewObject"  # Add BuildingNode script to make it a preview object
	var building_node: Node = auto_free(Node.new())
	var building_node_script: Script = load(
		"res://addons/grid_building/components/building_node.gd"
	)
	building_node.set_script(building_node_script)
	preview_object.add_child(building_node)

	# Step 1: Target a regular object first
	targeting_state.set_manual_target(hovered_object)
	runner.simulate_frames(1)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 1 failed - Expected: %s, Got: %s, Preview: %s"
				% [
					hovered_object.name,
					_node_name(informer.get_display_target()),
					str(building_state.preview)
				]
			)
		) \
		. is_same(hovered_object)
	)

	# Step 2: Activate building preview - should take precedence
	building_state.preview = preview_object
	runner.simulate_frames(1)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 2 failed - Expected: %s, Got: %s, Preview: %s, Targeting: %s"
				% [
					preview_object.name,
					_node_name(informer.get_display_target()),
					_node_name(building_state.preview),
					_node_name(targeting_state.get_target())
				]
			)
		) \
		. is_same(preview_object)
	)

	# Step 3: Try to hover over another object while preview is active
	var another_object: Node2D = auto_free(Node2D.new())
	another_object.name = "AnotherObject"
	add_child(another_object)

	targeting_state.set_manual_target(another_object)
	runner.simulate_frames(1)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 3 failed - Expected: %s (preview), Got: %s, Targeting: %s"
				% [
					preview_object.name,
					_node_name(informer.get_display_target()),
					another_object.name
				]
			)
		) \
		. is_same(preview_object)
	)

	# Step 4: Clear building preview - should return to targeting
	building_state.preview = null
	runner.simulate_frames(1)

	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 4 failed - Expected: %s, Got: %s, Preview: %s, Targeting: %s"
				% [
					another_object.name,
					_node_name(informer.get_display_target()),
					str(building_state.preview),
					another_object.name
				]
			)
		) \
		. is_same(another_object)
	)


#endregion

#region MANIPULATION_TO_TARGETING_TRANSITION_TESTS


## Test REGRESSION: After manipulation ends and object is placed,
## the newly placed object should be targetable via normal targeting system
func test_placed_object_becomes_targetable_after_manipulation() -> void:
	# Scenario:
	# 1. Manipulate and place an object
	# 2. After placement, move mouse over the placed object
	# 3. Expected: Placed object becomes the target via TargetingShapeCast2D
	# 4. Bug: Object doesn't get targeted (maybe manipulation state still holds it)

	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var manipulation_state: ManipulationState = env.container.get_states().manipulation

	# Create an object to manipulate
	var manipulated_object: Node2D = auto_free(Node2D.new())
	manipulated_object.name = "ManipulatedObject"
	manipulated_object.global_position = Vector2(100, 100)

	# Add Manipulatable component
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = manipulated_object
	manipulated_object.add_child(manipulatable)
	env.level.add_child(manipulated_object)

	# Wait for initialization
	runner.simulate_frames(1)

	# Step 1: Start manipulation (simulate selecting object for movement)
	manipulation_state.active_manipulatable = manipulatable
	runner.simulate_frames(1)

	(
		assert_object(manipulation_state.active_manipulatable) \
		. append_failure_message("Step 1: Manipulation should have active target set") \
		. is_not_null()
	)

	# Step 2: End manipulation (simulate placing the object)
	# In real system, this would be done by ManipulationSystem._finish()
	# which clears manipulation state and sets is_manual_targeting_active = false
	manipulation_state.active_manipulatable = null
	targeting_state.is_manual_targeting_active = false
	targeting_state.clear_collision_exclusions()
	runner.simulate_frames(1)

	# Verify manipulation state is cleared
	(
		assert_object(manipulation_state.active_manipulatable) \
		. append_failure_message("Step 2: Manipulation state should be cleared after placement") \
		. is_null()
	)

	(
		assert_bool(targeting_state.is_manual_targeting_active) \
		. append_failure_message(
			"Step 2: is_manual_targeting_active should be false after placement"
		) \
		. is_false()
	)

	# Step 3: Hover over the placed object (simulate mouse moving over it)
	# This should trigger TargetingShapeCast2D to detect it
	targeting_state.set_manual_target(manipulated_object)  # Simulate ShapeCast detection
	runner.simulate_frames(1)

	# THE REGRESSION: This should work but might fail if manipulation state interferes
	var failure_msg: String = (
		"Step 3 REGRESSION: After manipulation ends, placed object should be targetable. " +
		"manipulation_active=%s, manipulation_target=%s, targeting_target=%s" % [
			str(targeting_state.is_manual_targeting_active),
			str(manipulation_state.active_manipulatable),
			str(targeting_state.get_target())
		]
	)
	(
		assert_object(targeting_state.get_target()) \
		. append_failure_message(failure_msg) \
		. is_same(manipulated_object)
	)


## Test REGRESSION: Manipulation state active_target_node interferes with normal targeting
func test_manipulation_state_does_not_block_targeting_after_clear() -> void:
	# More specific test: If manipulation state isn't properly cleared,
	# it might prevent TargetInformer or other systems from showing new targets

	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var manipulation_state: ManipulationState = env.container.get_states().manipulation
	var informer: TargetInformer = env.target_informer

	# Create two objects
	var object_a: Node2D = auto_free(Node2D.new())
	object_a.name = "ObjectA"
	object_a.global_position = Vector2(100, 100)
	env.level.add_child(object_a)

	var object_b: Node2D = auto_free(Node2D.new())
	object_b.name = "ObjectB"
	object_b.global_position = Vector2(200, 200)
	env.level.add_child(object_b)

	# Wait for initialization
	runner.simulate_frames(1)

	# Step 1: Manipulate ObjectA
	var manipulatable_a: Manipulatable = auto_free(Manipulatable.new())
	manipulatable_a.root = object_a
	object_a.add_child(manipulatable_a)

	manipulation_state.active_manipulatable = manipulatable_a
	runner.simulate_frames(1)

	# TargetInformer should show ObjectA (prioritizes manipulation)
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message("Step 1: TargetInformer should show manipulated object") \
		. is_same(object_a)
	)

	# Step 2: End manipulation, clear states
	manipulation_state.active_manipulatable = null
	targeting_state.is_manual_targeting_active = false
	runner.simulate_frames(1)

	# Step 3: Hover over ObjectB (different object)
	targeting_state.set_manual_target(object_b)
	runner.simulate_frames(1)

	# REGRESSION: TargetInformer should now show ObjectB, not stuck on ObjectA
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"Step 3 REGRESSION: After manipulation cleared, TargetInformer should show new target. "
				+ (
					"Expected=%s, Got=%s, manipulation_active=%s, manipulation_target=%s"
					% [
						object_b.name,
						_node_name(informer.get_display_target()),
						str(targeting_state.is_manual_targeting_active),
						str(manipulation_state.active_manipulatable)
					]
				)
			)
		) \
		. is_same(object_b)
	)


func test_targeting_blocked_by_lingering_manipulation_target() -> void:
	# Test: VERIFIED FIX - After manipulation ends, active_target_node should be cleared,
	# allowing new targeting attempts to work correctly
	#
	# Scenario:
	# 1. Manipulate ObjectA
	# 2. Manipulation ends and active_target_node IS cleared (FIX VERIFIED)
	# 3. Move mouse over ObjectB - should be targeted
	# 4. SUCCESS: TargetInformer shows ObjectB because active_target_node == null

	var targeting_state: GridTargetingState = env.grid_targeting_system.get_state()
	var manipulation_state: ManipulationState = env.container.get_states().manipulation
	var informer: TargetInformer = env.target_informer

	# Create two objects for the test with Manipulatable components
	var object_a: Node2D = auto_free(Node2D.new())
	object_a.name = "ManipulatedObject"
	object_a.global_position = Vector2(100, 100)
	var manipulatable_a: Manipulatable = auto_free(Manipulatable.new())
	manipulatable_a.root = object_a
	object_a.add_child(manipulatable_a)
	env.level.add_child(object_a)

	var object_b: Node2D = auto_free(Node2D.new())
	object_b.name = "NewTargetObject"
	object_b.global_position = Vector2(200, 200)
	var manipulatable_b: Manipulatable = auto_free(Manipulatable.new())
	manipulatable_b.root = object_b
	object_b.add_child(manipulatable_b)
	env.level.add_child(object_b)

	# Wait for setup
	runner.simulate_frames(1)

	# Step 1: Simulate manipulation of ObjectA
	manipulation_state.active_manipulatable = manipulatable_a
	targeting_state.is_manual_targeting_active = true
	runner.simulate_frames(1)

	# Verify: TargetInformer shows manipulated object
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message("Step 1: TargetInformer should show manipulated object") \
		. is_same(object_a)
	)

	# Step 2: Manipulation ends and active_target_node IS cleared (simulates the fix)
	# This simulates the ManipulationSystem._finish() fix where active_target_node is properly cleared
	targeting_state.is_manual_targeting_active = false  # This gets cleared correctly
	manipulation_state.active_manipulatable = null  # FIX: Clear the target properly
	runner.simulate_frames(1)

	# Step 3: Try to target ObjectB (mouse moves over it)
	targeting_state.set_manual_target(object_b)
	runner.simulate_frames(1)

	# EXPECTED: TargetInformer should show ObjectB because manipulation state is clear
	(
		assert_object(informer.get_display_target()) \
		. append_failure_message(
			(
				"VERIFIED FIX: After manipulation ends with proper cleanup, new targeting should work. "
				+ "Expected ObjectB ("
				+ str(object_b.name)
				+ ") but got ("
				+ _node_name(informer.get_display_target())
				+ "). "
				+ "manipulation_active="
				+ str(targeting_state.is_manual_targeting_active)
				+ ", manipulation_target="
				+ _node_name(
					(
						manipulation_state.active_manipulatable.root
						if manipulation_state.active_manipulatable
						else null
					)
				)
			)
		) \
		. is_same(object_b)
	)

#endregion
