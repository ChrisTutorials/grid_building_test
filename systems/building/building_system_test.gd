# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var system: BuildingSystem
var targeting_state: GridTargetingState
var user_state: GBOwnerContext
var placement_manager: PlacementManager
var mode_state: ModeState
var grid_positioner: Node2D
var map_layer: TileMapLayer
var tile_set: TileSet
var placer: Node2D
var placed_parent: Node2D
var _placement_context: PlacementContext
var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var placeable_instance_script: Script = load("uid://dvt7wrugafo5o")
var placeable_2d_test: Placeable = load("uid://jgmywi04ib7c")
var default_preview_script: GDScript = load("uid://cufp4o5ctq6ak")


func before_test():
	placer = GodotTestFactory.create_node2d(self)

	placed_parent = GodotTestFactory.create_node2d(self)

	grid_positioner = GodotTestFactory.create_node2d(self)

	map_layer = GodotTestFactory.create_tile_map_layer(self)
	var states := _container.get_states()
	targeting_state = auto_free(states.targeting)
	targeting_state.positioner = grid_positioner
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]

	mode_state = ModeState.new()
	system = auto_free(BuildingSystem.create_with_injection(_container))
	system.mode_state = mode_state
	# Removed back-compat alias usage
	# system.state = states.building
	# system.targeting_state = targeting_state

	## Turn debug on for testing
	system.debug = GBDebugSettings.new(GBDebugSettings.DebugLevel.INFO)

	add_child(system)

	user_state = GBOwnerContext.new()
	var gb_owner := GBOwner.new(placer)
	user_state.set_owner(gb_owner)
	system.targeting_state.origin_state = user_state

	_placement_context = PlacementContext.new()
	placement_manager = auto_free(PlacementManager.new())
	placement_manager.resolve_gb_dependencies(_container)
	grid_positioner.add_child(placement_manager)

	# Assign building state via container directly
	states.building.placer_state = user_state
	states.building.placed_parent = placed_parent
	system.settings = TestSceneLibrary.building_settings.duplicate(true)


func test_before_test_setup():
	assert_object(system).is_not_null()
	var issues = system.validate_dependencies()
	assert_array(issues).is_empty()


@warning_ignore("unused_parameter")


func test_instance_preview_fails(
	p_placeable: Variant,
	p_warning: String,
	test_parameters := [
		[null, system._WARNING_INVALID_PLACEABLE],
	]
):
	var instantiate = func(): system.instance_preview(p_placeable)
	assert_error(instantiate).is_push_warning(p_warning % p_placeable)


@warning_ignore("unused_parameter")


func test_instance_preview() -> void:
	var placeable = TestSceneLibrary.placeable_2d_test
	var preview = auto_free(system.instance_preview(placeable))
	assert_object(preview).is_not_null()


func test_remove_scripts() -> void:
	var preview: Node = auto_free(TestSceneLibrary.placeable_2d_test.packed_scene.instantiate())
	add_child(preview)
	var manipulatable = GBSearchUtils.find_first(preview, Manipulatable)
	assert_object(preview).override_failure_message("Preview not instanced.").is_not_null()
	assert_object(manipulatable).is_not_null()

	system.remove_scripts(preview, ["Manipulatable"])

	var preview_script = preview.get_script()
	(
		assert_object(preview_script)
		. override_failure_message("[%s] Expected null script but has one" % preview_script)
		. is_null()
	)

	assert_object(manipulatable).is_not_null()
	assert_object(manipulatable.get_script()).is_not_null()

	system.remove_scripts(preview, [])
	assert_object(manipulatable).is_not_null()
	assert_object(manipulatable.get_script()).is_null()


func test_unhandled_input():
	var test_actions = _container.config.actions
	var action_event = InputEventAction.new()
	action_event.action = test_actions.confirm
	action_event.pressed = true

	system._unhandled_input(action_event)

	mode_state.current = GBEnums.Mode.BUILD

	action_event.action = system.mode_actions.off_mode
	system._unhandled_input(action_event)


func test_validate_input_map():
	var is_input_map_validated = system.validate_input_map()
	assert_bool(is_input_map_validated).is_true()


func test_set_buildable_preview():
	var test_placeable = Placeable.new()
	test_placeable.packed_scene = TestSceneLibrary.box_scripted
	assert_bool(test_placeable.validate()).is_true()
	var successful = system.set_buildable_preview(test_placeable)

	if not successful:
		fail("Buildable preview should have successfully instanced")
		return

	var preview_instance = _container.get_states().building.preview

	if not preview_instance:
		fail("Preview instance should have been instanced. Stopping test.")
		return

	var source_code: String = preview_instance.get_script().source_code
	assert_str(source_code).is_equal(default_preview_script.source_code)

	for child in preview_instance.get_children():
		assert_object(child.get_script()).is_null()


@warning_ignore("unused_parameter")


func test_set_buildable_preview_keep_script_test(
	p_script: Script, test_parameters := [[placeable_instance_script]]
):
	var placeable_test = Placeable.new()
	var scripted_node: Node = auto_free(TestSceneLibrary.keep_script_scene.instantiate())
	var packed_scene = PackedScene.new()

	# Execution
	var child_node = scripted_node.get_child(0)
	assert_object(child_node.owner).is_same(scripted_node)
	packed_scene.pack(scripted_node)
	placeable_test.packed_scene = TestSceneLibrary.keep_script_scene
	var script_type = p_script.get_global_name()
	system.settings.preview_kept_script_types.append(script_type)

	scripted_node.free()
	var is_preview_set = system.set_buildable_preview(placeable_test)
	assert_bool(is_preview_set).is_true()
	var preview_instance = _container.get_states().building.preview

	(
		assert_object(preview_instance)
		. append_failure_message("Preview instanced should be a valid node.")
		. is_instanceof(Node2D)
	)
	assert_object(preview_instance.get_script()).is_same(p_script)

	for child in preview_instance.get_children():
		assert_object(child.get_script()).is_same(p_script)


@warning_ignore("unused_parameter")


func test_try_build(
	p_placeable: Placeable,
	ex_null_result: bool,
	test_parameters := [[null, true], [placeable_2d_test, false]]
) -> void:
	system.selected_placeable = p_placeable

	if p_placeable != null && p_placeable.packed_scene != null:
		_container.get_states().building.preview = p_placeable.packed_scene.instantiate()
		add_child(_container.get_states().building.preview)

	var result = system.try_build()
	assert_bool(result == null).is_equal(ex_null_result)


@warning_ignore("unused_parameter")


func test__build(
	p_placeable: Placeable,
	p_expected: Variant,
	test_parameters := [[null, null], [load("uid://jgmywi04ib7c"), any_object()]]
) -> void:
	system.selected_placeable = p_placeable

	if p_placeable != null && p_placeable.packed_scene != null:
		_container.get_states().building.preview = auto_free(p_placeable.packed_scene.instantiate())
		add_child(_container.get_states().building.preview)

	var result = system._build()
	assert_object(result).is_equal(p_expected)


## Creates a node and a child node with a script attached
## Returns the root
func create_node_and_child_with_script(p_script: Script) -> Node:
	var root = auto_free(Node.new())
	add_child(root)
	root.set_script(p_script)
	var child = auto_free(Node.new())
	root.add_child(child)
	child.set_script(p_script)
	return root
