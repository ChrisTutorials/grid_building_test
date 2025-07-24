extends GutTest

@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

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

# Path to default preview script
var default_preview_script : GDScript = load("uid://cufp4o5ctq6ak")

func before_each():
	library = self.gut.autofree(TestSceneLibrary.instance_library())

	placer = self.gut.add_child_autofree(Node2D.new())
	placed_parent = self.gut.add_child_autofree(Node2D.new())
	grid_positioner = self.gut.add_child_autofree(Node2D.new())
	tile_map = self.gut.add_child_autofree(TileMap.new())
	
	tile_set = self.gut.autofree(TileSet.new())
	tile_map.tile_set = tile_set
	
	targeting_state = self.gut.autofree(GridTargetingState.new())
	targeting_state.positioner = grid_positioner
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]
	
	mode_state = self.gut.autofree(ModeState.new())
	
	system = self.gut.add_child_autofree(BuildingSystem.new())
	
	building_actions = self.gut.autofree(BuildingActions.new())
	system.actions = building_actions
	system.mode_actions = self.gut.autofree(ModeInputActions.new())
	system.mode_state = mode_state
	
	system.state = self.gut.autofree(BuildingState.new())
	system.placement_validator = self.gut.autofree(PlacementValidator.new())
	system.targeting_state = targeting_state

	system.debug = self.gut.autofree(GBDebugSettings.new(true))
	
	user_state = self.gut.autofree(UserState.new())
	user_state.user = placer
	system.targeting_state.origin_state = user_state
	
	rci_manager = self.gut.autofree(RuleCheckIndicatorManager.new(library.indicator, targeting_state, system.placement_validator))
	rci_manager.name = "RuleCheckIndicatorManager"
	grid_positioner.add_child(rci_manager)
	system.placement_validator.indicator_manager = rci_manager
	
	system.state.placer_state = user_state
	system.state.placed_parent = placed_parent
	
	system.settings = self.gut.autofree(library.building_settings.duplicate(true))
	
func test_before_test_setup():
	self.gut.assert_object(system).is_not_null()
	var problems = system.validate()
	self.gut.assert_array(problems).is_empty()

func test_instantiate_placeable_preview_fails(test_data):
	var p_placeable = test_data[0]
	var p_warning = test_data[1]
	self.gut.use_parameters([
		[null, system._WARNING_INVALID_PLACEABLE],
	])

	var instantiate = func(): system.instantiate_placeable_preview(p_placeable)
	self.gut.auto_free(await self.gut.assert_error(instantiate).is_push_warning(p_warning % p_placeable))

func test_instantiate_placeable_preview(test_data):
	var p_placeable = test_data[0]
	self.gut.use_parameters([
		[library.placeable_2d_test]
	])

	var preview = self.gut.auto_free(system.instantiate_placeable_preview(p_placeable))
	self.gut.assert_object(preview).is_not_null()
	

func test_remove_scripts() -> void:
	var preview : Node = self.gut.add_child_autofree(library.placeable_2d_test.packed_scene.instantiate())
	
	var manipulatable = GBSearchUtils.find_first(preview, Manipulatable)
	self.gut.assert_object(preview).override_failure_message("Preview not instanced.").is_not_null()
	self.gut.assert_object(manipulatable).is_not_null()
	
	system.remove_scripts(preview, ["Manipulatable"])
	
	var preview_script = preview.get_script()
	self.gut.assert_object(preview_script).override_failure_message("[%s] Expected null script but has one" % preview_script).is_null()
	
	self.gut.assert_object(manipulatable).is_not_null()
	self.gut.assert_object(manipulatable.get_script()).is_not_null()
	
	system.remove_scripts(preview, [])
	self.gut.assert_object(manipulatable).is_not_null()
	self.gut.assert_object(manipulatable.get_script()).is_null()

func test_unhandled_input():
	var action_event = self.gut.autofree(InputEventAction.new()) 
	action_event.action = building_actions.confirm
	action_event.pressed = true
	
	system._unhandled_input(action_event)
	
	mode_state.mode = GBEnums.Mode.BUILD

	action_event.action = system.mode_actions.off_mode
	system._unhandled_input(action_event)

func test_validate_input_map():
	var is_input_map_validated = system.validate_input_map()
	self.gut.assert_bool(is_input_map_validated).is_true()

func test_set_buildable_preview():
	var test_placeable = self.gut.autofree(Placeable.new())
	test_placeable.packed_scene = library.box_scripted
	self.gut.assert_bool(test_placeable.validate()).is_true()
	var successful = system.set_buildable_preview(test_placeable)
	
	if not successful:
		self.gut.fail("Buildable preview should have successfully instanced")
		return
		
	var preview_instance = system.state.preview
	
	if not preview_instance:
		self.gut.fail("Preview instance should have been instanced. Stopping test.")
		return 
	
	self.gut.autoqfree(preview_instance)
	
	var source_code : String = preview_instance.get_script().source_code
	self.gut.assert_str(source_code).is_equal(default_preview_script.source_code)
	
	for child in preview_instance.get_children():
		self.gut.assert_object(child.get_script()).is_null()

@warning_ignore("unused_parameter")
func test_set_buildable_preview_keep_script_test(test_data):
	var p_script = test_data[0]
	self.gut.use_parameters([
		[library.placeable_instance_script]
	])

	var placeable_test = self.gut.autofree(Placeable.new())
	
	var scripted_node : Node = self.gut.autofree(library.keep_script_scene.instantiate())
	var packed_scene = self.gut.autofree(PackedScene.new())
	
	var child_node = scripted_node.get_child(0)
	self.gut.assert_object(child_node.owner).is_same(scripted_node)
	packed_scene.pack(scripted_node)
	placeable_test.packed_scene = library.keep_script_scene
	var script_type = p_script.get_global_name()
	system.settings.preview_kept_script_types.append(script_type)
	
	scripted_node.free()
	var is_preview_set = system.set_buildable_preview(placeable_test)
	self.gut.assert_bool(is_preview_set).is_true()
	var preview_instance = system.state.preview
	
	self.gut.assert_object(preview_instance).append_failure_message("Preview instanced should be a valid node.").is_instanceof(Node2D)
	self.gut.assert_object(preview_instance.get_script()).is_same(p_script)
	
	for child in preview_instance.get_children():
		self.gut.assert_object(child.get_script()).is_same(p_script)

@warning_ignore("unused_parameter")
func test_try_build(test_data):
	var p_placeable = test_data[0]
	var p_expected = test_data[1]
	self.gut.use_parameters([
		[null, null],
		[library.placeable_2d_test, self.gut.any_object()]
	])

	system.selected_placeable = p_placeable
	
	if p_placeable != null && p_placeable.packed_scene != null:
		system.state.preview = self.gut.add_child_autofree(p_placeable.packed_scene.instantiate())
	
	var result = system.try_build()
	self.gut.assert_object(result).is_equal(p_expected)

@warning_ignore("unused_parameter")
func test__build(test_data):
	var p_placeable = test_data[0]
	var p_expected = test_data[1]
	self.gut.use_parameters([
		[null, null],
		[load("uid://jgmywi04ib7c"), self.gut.any_object()]
	])

	system.selected_placeable = p_placeable
	
	if p_placeable != null && p_placeable.packed_scene != null:
		system.state.preview = self.gut.add_child_autofree(p_placeable.packed_scene.instantiate())
	
	var result = system._build()
	self.gut.assert_object(result).is_equal(p_expected)

func create_node_and_child_with_script(p_script : Script) -> Node:
	var root = self.gut.add_child_autofree(Node.new())
	root.set_script(p_script)
	var child = self.gut.auto_free(Node.new())
	root.add_child(child)
	child.set_script(p_script)
	return root
