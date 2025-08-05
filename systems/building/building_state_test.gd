# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var state : BuildingState
var placer : Node2D
var _owner : GBOwner
var placed_parent : Node2D
var placer_state : GBOwnerContext

var _owner_context : GBOwnerContext

func before_test():
	placer = Node2D.new()
	_owner = GBOwner.new(placer)
	_owner_context = GBOwnerContext.new()
	state = BuildingState.new(_owner_context)
	placer_state = GBOwnerContext.new()
	state.placer_state = placer_state
	
	_owner = GBOwner.new()
	_owner.owner_root = placer
	
	add_child(placer)
	placed_parent = Node2D.new()
	add_child(placed_parent)

func after_test():
	placer.free()
	placed_parent.free()

func test_validate() -> void:
	assert_array(state.validate()).append_failure_message("Is false because placed parent etc have not been set").is_empty()
	
func test_placer_dereference_on_exit():
	var test_placer = auto_free(Node.new())
	placer_state.set_owner(test_placer)
	assert_that(placer_state.get_owner()).is_not_null()
	test_placer.free()
	assert_that(placer_state.get_owner()).is_null()
	
