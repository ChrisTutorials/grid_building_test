## test_manipulation_system.gd
extends GdUnitTestSuite

var manipulation_system : ManipulationSystem
var state : ManipulationState
var mode_state : ModeState
var messages : ManipulationMessages
var targeting_state : GridTargetingState
var system_parent : Node2D
var placement_validator : PlacementValidator

func before():
	state = auto_free(ManipulationState.new())
	mode_state = auto_free(ModeState.new())
	messages = auto_free(ManipulationMessages.new())
	targeting_state = auto_free(GridTargetingState.new())
	placement_validator = auto_free(PlacementValidator.new())
	system_parent = auto_free(Node2D.new())
	manipulation_system = auto_free(ManipulationSystem.new())
	
	add_child(system_parent)
	
	# Setup basic requirements
	manipulation_system.state = state
	manipulation_system.mode_state = mode_state
	manipulation_system.messages = messages
	manipulation_system.targeting_state = targeting_state
	manipulation_system.placement_validator = placement_validator
	manipulation_system.settings = auto_free(ManipulationSettings.new())
	manipulation_system.actions = auto_free(ManipulationActions.new())
	manipulation_system.mode_actions = auto_free(ModeInputActions.new())
	state.parent = system_parent
	
	## Add at the end after the system has had it's dependencies added in
	add_child(manipulation_system)

func after():
	manipulation_system.free()

func test_validate():
	var problems := manipulation_system.validate()
	
	assert_array(problems).append_failure_message("Found problems when expecting proper setup").is_empty()

@warning_ignore("unused_parameter")
func test_demolish(
	p_demolishable : bool,
	p_ex_result : bool,
	test_parameters := [
	[true, true],
	[false, false]
]):
	manipulation_system.messages = messages
	
	# Setup test object
	var test_node = Node2D.new()
	test_node.name = "TestObject"
	var manipulatable = Manipulatable.new()
	manipulatable.settings = ManipulatableSettings.new()
	manipulatable.settings.demolishable = p_demolishable
	manipulatable.root = test_node
	test_node.add_child(manipulatable)
	
	# Execute demolish
	var result = await manipulation_system.demolish(manipulatable)
	
	# Verify results
	assert_that(result).is_equal(p_ex_result)
	
	if p_ex_result:
		# Verify object was actually deleted
		assert_that(test_node).is_null()
	else:
		# Verify object still exists for failed demolish
		assert_that(test_node).is_not_null()
		
	# Clean up if not demolished
	if is_instance_valid(test_node):
		test_node.free()

func test_demolish_null_manipulatable():
	var result = await manipulation_system.demolish(null)
	assert_that(result).is_false()
