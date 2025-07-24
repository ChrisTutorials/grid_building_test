extends GutTest

# Test suite for BuildingState
var state : BuildingState
var placer : Node2D
var placed_parent : Node2D
var placer_state : UserState

func before_each():
	# Initialize objects before each test
	state = BuildingState.new()
	placer_state = UserState.new()
	state.placer_state = placer_state

	placer = autofree(Node2D.new())
	# Add to the current test scene; GUT will automatically queue_free it after the test
	add_child(placer)

	placed_parent = autofree(Node2D.new())
	# Add to the current test scene; GUT will automatically queue_free it after the test
	
	add_child(placed_parent)

	placer_state.user = placer

# No after_each() needed for placer and placed_parent because add_child_to_current_scene()
# handles their cleanup automatically after each test.

func test_validate():
	# Assert that the validation result is an empty array, with a custom failure message
	assert_eq(state.validate(), [], "Validation should be empty when placed_parent is not set.")

func test_placer_dereference_on_exit():
	var test_placer = Node.new()
	# GUT does not have auto_free in the same way as GdUnit, but for a node
	# that is immediately freed, manual free() is appropriate.
	placer_state.user = test_placer

	# Assert that placer_state.user is not null initially
	assert_not_null(placer_state.user)

	# Free the test placer node
	test_placer.free()

	# Assert that placer_state.user is now null (due to dereferencing after freeing)
	assert_null(placer_state.user)