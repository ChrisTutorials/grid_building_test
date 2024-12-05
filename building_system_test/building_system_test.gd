# GdUnit generated TestSuite
class_name BuildingSystemTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/system/system.gd'

var library : TestSceneLibrary
var system : BuildingSystem
var targeting_state : GridTargetingState
var user_state : UserState
var rci_manager : RuleCheckIndicatorManager
var mode_state : ModeState
var grid_positioner : Node2D
var tile_map : TileMap
var tile_set : TileSet
var placer : Node2D
var placed_parent : Node2D
var building_actions : BuildingActions

func before_test():
	library = auto_free(TestSceneLibrary.instance_library())
	placer = auto_free(Node2D.new())
	add_child(placer)
	
	placed_parent = auto_free(Node2D.new())
	add_child(placed_parent)
	
	mode_state = ModeState.new()
	system = auto_free(BuildingSystem.new())
	system.mode_state = mode_state
	add_child(system)
	
	grid_positioner = auto_free(Node2D.new())
	add_child(grid_positioner)
	
	targeting_state = auto_free(GridTargetingState.new())
	system.targeting_state = targeting_state
	system.targeting_state.positioner = grid_positioner
	user_state = UserState.new()
	user_state.user = placer
	system.targeting_state.origin_state = user_state
	
	tile_map = auto_free(TileMap.new())
	add_child(tile_map)
	tile_set = TileSet.new()
	tile_map.tile_set = tile_set
	targeting_state.target_map = tile_map
	
	
	building_actions = BuildingActions.new()
	
	system.placement_validator = PlacementValidator.new()
	rci_manager = auto_free(RuleCheckIndicatorManager.new(library.indicator, targeting_state, system.placement_validator))
	rci_manager.name = "RuleCheckIndicatorManager"
	grid_positioner.add_child(rci_manager)
	system.placement_validator.indicator_manager = rci_manager
	
	system.state = BuildingState.new()
	system.state.placer_state = user_state
	system.state.placed_parent = placed_parent
	system.settings = library.building_settings.duplicate(true)
	system.actions = building_actions
	system.mode_actions = ModeInputActions.new()
	
	var valid = system.validate_setup()
	assert_bool(valid).override_failure_message("System should be valid before running tests.").is_true()

func test_instantiate_placeable_preview() -> void:
	var null_result = system.instantiate_placeable_preview(null)
	assert_object(null_result).is_null()
	
	var preview = auto_free(system.instantiate_placeable_preview(library.placeable_2d_test))
	assert_object(preview).is_not_null()
	

func test_remove_scripts() -> void:
	var preview : Node = auto_free(library.placeable_2d_test.packed_scene.instantiate())
	add_child(preview)
	var manipulatable = GBSearchUtils.find_first(preview, Manipulatable)
	assert_object(preview).override_failure_message("Preview not instanced.").is_not_null()
	assert_object(manipulatable).is_not_null()
	
	system.remove_scripts(preview, ["Manipulatable"])
	
	var preview_script = preview.get_script()
	assert_object(preview_script).override_failure_message("[%s] Expected null script but has one" % preview_script).is_null()
	
	assert_object(manipulatable).is_not_null()
	assert_object(manipulatable.get_script()).is_not_null()
	
	system.remove_scripts(preview, [])
	assert_object(manipulatable).is_not_null()
	assert_object(manipulatable.get_script()).is_null()

func test_debug_on_shows():
	#region Setup
	system.settings.show_debug = true
	assert_object(system.placement_validator).is_not_null()
	var collision_check_rule = CollisionsCheckRule.new()
	system.placement_validator.base_rules.append(collision_check_rule)
	assert_array(system.placement_validator.base_rules).append_failure_message("Validator should have base rules setup in test.").is_not_empty()
	#endregion
	
	var set_preview = system.set_buildable_preview(library.placeable_eclipse_skew_rotate)
	assert_bool(set_preview).override_failure_message("Preview instance NOT set successfully").is_true()
	
	## If no rules, then generation area is not created
	assert_object(system.placement_validator.indicator_manager).override_failure_message("Building system has rule check indicator manager NOT set").is_not_null()
	
	system.set_buildable_preview(library.placeable_eclipse_skew_rotate)
	
	var testing_params = system.placement_validator.indicator_manager.test_setup
	
	if testing_params.is_empty():
		fail("No [testing_params]")
		return
		
	assert_object(testing_params[0]).override_failure_message("Has no valid test_params entry.").is_not_null()
	assert_object(rci_manager.get_parent()).is_not_null()


func test_unhandled_input():
	var action_event = InputEventAction.new()
	action_event.action = building_actions.confirm
	action_event.pressed = true
	
	system._unhandled_input(action_event)
	
	mode_state.mode = GBEnums.Mode.BUILD

	action_event.action = system.mode_actions.off_mode
	system._unhandled_input(action_event)

func test_validate_input_map():
	var is_input_map_validated = system.validate_input_map()
	assert_bool(is_input_map_validated).is_true()

func test_set_buildable_preview():
	var test_placeable = Placeable.new()
	test_placeable.packed_scene = library.box_scripted
	assert_bool(test_placeable.validator.validate()).is_true()
	var successful = system.set_buildable_preview(test_placeable)
	
	if(not successful):
		fail("Buildable preview should have successfully instanced")
		return
		
	var preview_instance = system.state.preview
	
	if not preview_instance:
		fail("Preview instance should have been instanced. Stopping test.")
		return 
		
	assert_object(preview_instance.get_script()).is_null()
	
	for child in preview_instance.get_children():
		assert_object(child.get_script()).is_null()

func test_set_buildable_preview_keep_script_test(p_script : Script, test_parameters = [
	[library.placeable_instance_script]
]):
	var placeable_test = Placeable.new()
	var scripted_node : Node = auto_free(library.keep_script_scene.instantiate())
	var packed_scene = PackedScene.new()
	
	# Execution
	var child_node = scripted_node.get_child(0)
	assert_object(child_node.owner).is_same(scripted_node)
	packed_scene.pack(scripted_node)
	placeable_test.packed_scene = library.keep_script_scene
	var script_type = p_script.get_global_name()
	system.settings.preview_kept_script_types.append(script_type)
	
	scripted_node.free()
	var is_preview_set = system.set_buildable_preview(placeable_test)
	assert_bool(is_preview_set).is_true()
	var preview_instance = system.state.preview
	
	assert_object(preview_instance).append_failure_message("Preview instanced should be a valid node.").is_instanceof(Node2D)
	assert_object(preview_instance.get_script()).is_same(p_script)
	
	for child in preview_instance.get_children():
		assert_object(child.get_script()).is_same(p_script)

func test_try_build(p_placeable : Placeable, p_expected : Object, test_parameters = [
	[null, null],
	[library.placeable_2d_test, any_object()]
]) -> void:
	system.selected_placeable = p_placeable
	
	if p_placeable != null && p_placeable.packed_scene != null:
		system.state.preview = p_placeable.packed_scene.instantiate()
		add_child(system.state.preview)
	
	var result = system.try_build()
	assert_object(result).is_equal(p_expected)

func test__build(p_placeable : Placeable, p_expected, test_parameters = [
	[null, null],
	[load("res://test/grid_building_test/resources/placeable/test_2d_placeable.tres"), any_object()]
]) -> void:
	system.selected_placeable = p_placeable
	
	if p_placeable != null && p_placeable.packed_scene != null:
		system.state.preview = p_placeable.packed_scene.instantiate()
		add_child(system.state.preview)
	
	var result = system._build()
	assert_object(result).is_equal(p_expected)

## Creates a node and a child node with a script attached
## Returns the root
func create_node_and_child_with_script(p_script : Script) -> Node:
	var root = auto_free(Node.new())
	add_child(root)
	root.set_script(p_script)
	var child = auto_free(Node.new())
	root.add_child(child)
	child.set_script(p_script)
	return root
