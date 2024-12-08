# GdUnit generated TestSuite
class_name BuildingStateTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/building_system/building_state.gd'

var state : BuildingState
var placer : Node2D
var placed_parent : Node2D
var placer_state : UserState

func before_test():
	state = BuildingState.new()
	placer_state = UserState.new()
	state.placer_state = placer_state
	placer = Node2D.new()
	add_child(placer)
	placed_parent = Node2D.new()
	add_child(placed_parent)

func after_test():
	placer.free()
	placed_parent.free()

func test_validate() -> void:
	assert_bool(state.validate()).append_failure_message("Is false because placed parent etc have not been set").is_false()
	
func test_placer_dereference_on_exit():
	var test_placer = Node.new()
	placer_state.user = test_placer
	assert_that(placer_state.user).is_not_null()
	test_placer.free()
	assert_that(placer_state.user).is_null()
