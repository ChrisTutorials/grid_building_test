# GdUnit generated TestSuite
class_name BuildingStateTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var state : BuildingState
var placer : Node2D
var placed_parent : Node2D
var placer_state : GBOwnerContext

func before_test():
	state = BuildingState.new()
	placer_state = GBOwnerContext.new()
	state.placer_state = placer_state
	placer = Node2D.new()
	add_child(placer)
	placed_parent = Node2D.new()
	add_child(placed_parent)
	placer_state.user = placer

func after_test():
	placer.free()
	placed_parent.free()

func test_validate() -> void:
	assert_array(state.validate()).append_failure_message("Is false because placed parent etc have not been set").is_empty()
	
func test_placer_dereference_on_exit():
	var test_placer = Node.new()
	placer_state.user = test_placer
	assert_that(placer_state.user).is_not_null()
	test_placer.free()
	assert_that(placer_state.user).is_null()
	
