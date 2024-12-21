# GdUnit generated TestSuite
class_name GridTargetingStateTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/grid_targeting_system/grid_targeting_state.gd'

var state : GridTargetingState

func before_test():
	state = GridTargetingState.new()

func test_init():
	assert_object(state).is_not_null()
