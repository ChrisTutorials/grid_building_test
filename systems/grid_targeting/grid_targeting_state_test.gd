# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

var state : GridTargetingState

func before_test():
	state = GridTargetingState.new(GBOwnerContext.new())

func test_init():
	assert_object(state).is_not_null()
