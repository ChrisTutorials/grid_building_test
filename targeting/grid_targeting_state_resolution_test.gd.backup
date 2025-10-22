## Tests for GridTargetingState target/target_root auto-resolution
## Verifies that setting target automatically resolves target_root via GBMetadataResolver
extends GdUnitTestSuite

var _targeting_state: GridTargetingState
var _owner_context: GBOwnerContext

func before_test() -> void:
	_owner_context = auto_free(GBOwnerContext.new())
	_targeting_state = auto_free(GridTargetingState.new(_owner_context))


func test_setting_target_auto_resolves_target_root_with_metadata() -> void:
	# Setup: Create scene structure with metadata
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "MetadataRoot"
	add_child(root_node)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionWithMetadata"
	root_node.add_child(collision_area)
	collision_area.set_meta("root_node", NodePath(".."))

	# Act: Set collider (should auto-resolve target via metadata)
	_targeting_state.set_collider(collision_area)

	# Assert: target should be auto-resolved to root_node
	var target: Node2D = _targeting_state.get_target()
	assert_object(target).append_failure_message(
		"Target should be auto-resolved to root node via metadata. Got: %s, Expected: %s" % [
			str(target.name) if target != null else "null",
			root_node.name
		]
	).is_same(root_node)


func test_setting_target_emits_both_signals() -> void:
	# Setup: Create test objects
	var collision_object: Area2D = auto_free(Area2D.new())
	collision_object.name = "TestCollision"
	add_child(collision_object)

	var signal_data := {
		"target_changed": false,
		"target_new": null
	}

	# Connect to target_changed signal
	_targeting_state.target_changed.connect(func(new_target: Node2D, _old: Node2D) -> void:
		signal_data.target_changed = true
		signal_data.target_new = new_target
	)

	# Act: Set collider (should emit target_changed signal)
	_targeting_state.set_collider(collision_object)

	# Assert: target_changed signal should be emitted
	assert_bool(signal_data.target_changed).append_failure_message(
		"target_changed signal should be emitted"
	).is_true()

	assert_object(signal_data.target_new).append_failure_message(
		"target_changed signal should pass resolved target"
	).is_same(collision_object)


func test_setting_non_collision_target_uses_self_as_root() -> void:
	# Setup: Create non-collision Node2D
	var regular_node: Node2D = auto_free(Node2D.new())
	regular_node.name = "RegularNode"
	add_child(regular_node)

	# Act: Set non-CollisionObject2D as manual target
	_targeting_state.set_manual_target(regular_node)

	# Assert: target should be the same node (no resolution for manual targets)
	assert_object(_targeting_state.get_target()).append_failure_message(
		"Target should be set to regular node"
	).is_same(regular_node)


func test_setting_null_target_clears_both_properties() -> void:
	# Setup: Set initial target
	var test_target: Area2D = auto_free(Area2D.new())
	add_child(test_target)
	_targeting_state.set_manual_target(test_target)

	assert_object(_targeting_state.get_target()).is_not_null()

	# Act: Clear target using clear() method
	_targeting_state.clear()

	# Assert: target should be null
	assert_object(_targeting_state.get_target()).append_failure_message(
		"target should be null after clearing"
	).is_null()


func test_setting_same_target_twice_doesnt_emit_signals() -> void:
	# Setup: Create test object
	var test_target: Area2D = auto_free(Area2D.new())
	add_child(test_target)

	var signal_data := [0]  # Use array for lambda capture
	_targeting_state.target_changed.connect(func(_new: Node2D, _old: Node2D) -> void:
		signal_data[0] += 1
	)

	# Act: Set target twice
	_targeting_state.set_manual_target(test_target)
	var first_count: int = signal_data[0]

	_targeting_state.set_manual_target(test_target)  # Same target again
	var second_count: int = signal_data[0]

	# Assert: Signal should only emit once (on first set)
	assert_int(first_count).append_failure_message(
		"First target set should emit signal"
	).is_equal(1)

	assert_int(second_count).append_failure_message(
		"Setting same target again should not emit signal"
	).is_equal(1)  # Should still be 1, not 2


func test_target_root_resolution_with_manipulatable() -> void:
	# Setup: Create scene structure with Manipulatable
	var root_node: Node2D = auto_free(Node2D.new())
	root_node.name = "ManipulatableRoot"
	add_child(root_node)

	var collision_area: Area2D = auto_free(Area2D.new())
	collision_area.name = "CollisionWithManipulatable"
	add_child(collision_area)

	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = root_node
	collision_area.add_child(manipulatable)

	# Act: Set collider (should resolve via Manipulatable child)
	_targeting_state.set_collider(collision_area)

	# Assert: target should be resolved to Manipulatable.root
	var target: Node2D = _targeting_state.get_target()
	assert_object(target).append_failure_message(
		"target should be resolved via Manipulatable child. Got: %s, Expected: %s" % [
			str(target.name) if target != null else "null",
			root_node.name
		]
	).is_same(root_node)
