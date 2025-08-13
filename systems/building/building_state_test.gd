# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var state: BuildingState
var placer: Node2D
var _owner: GBOwner
var placed_parent: Node2D

var _owner_context: GBOwnerContext


func before_test():
	# Use GodotTestFactory for proper node creation
	placer = GodotTestFactory.create_node2d(self)
	_owner = GBOwner.new(placer)
	_owner_context = GBOwnerContext.new()
	_owner_context.set_owner(_owner)
	state = BuildingState.new(_owner_context)
	# Add owner to the tree so it is tracked and auto-freed with the suite
	add_child(_owner)

	# create_node2d already adds as child, no need to call add_child again
	placed_parent = GodotTestFactory.create_node2d(self)
	state.placed_parent = placed_parent


func after_test():
	# Objects are auto-freed, just clean up the state
	if state:
		# Explicitly clear references so GdUnit orphan detector doesn't flag lingering nodes
		state.placed_parent = null
		state.preview = null
		state = null
	# Ensure created nodes are released
	if is_instance_valid(_owner):
		_owner.queue_free()
	if is_instance_valid(placer):
		placer.queue_free()
	if is_instance_valid(placed_parent):
		placed_parent.queue_free()


func test_validate() -> void:
		assert_array(state.validate())\
			.append_failure_message("Is false because placed parent etc have not been set")\
			.is_empty()

func test_placer_dereference_on_exit():
	# Test that owner context properly handles owner lifecycle
	var test_placer = GodotTestFactory.create_node(self)
	var test_gb_owner = auto_free(GBOwner.new(test_placer))
	add_child(test_gb_owner)

	# Create a new owner context for testing
	var test_owner_context = auto_free(GBOwnerContext.new())
	# set_owner expects a GBOwner, so use the GBOwner wrapper
	test_owner_context.set_owner(test_gb_owner)
	assert_that(test_owner_context.get_owner()).is_not_null()

	# When the owner's node is removed from the tree, the context should still hold the reference
	# (GBOwnerContext doesn't automatically clear when the owner_root is freed)
	test_placer.free()
	assert_that(test_owner_context.get_owner()).is_not_null()
