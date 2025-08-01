extends GdUnitTestSuite

var state : ManipulationState

func before_test():
    state = ManipulationState.new(GBOwnerContext.new())

func test_initialization():
    assert_that(state).is_not_null()
