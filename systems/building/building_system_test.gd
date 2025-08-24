# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var system: BuildingSystem
var targeting_state: GridTargetingState
var mode_state: ModeState
var grid_positioner: Node2D
var map_layer: TileMapLayer
var placer: Node2D
var placed_parent: Node2D
var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var placeable_2d_test: Placeable = load("uid://jgmywi04ib7c")


func before_test():
	placer = GodotTestFactory.create_node2d(self)
	placed_parent = GodotTestFactory.create_node2d(self)
	grid_positioner = GodotTestFactory.create_node2d(self)
	# Tile map layer used for targeting
	map_layer = GodotTestFactory.create_empty_tile_map_layer(self)

	var states := _container.get_states()
	targeting_state = states.targeting
	targeting_state.positioner = grid_positioner
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	mode_state = states.mode

	# Proper owner: create GBOwner node and inject so BuildingState can resolve owner_root
	var gb_owner := GBOwner.new(placer)
	add_child(gb_owner)
	gb_owner.resolve_gb_dependencies(_container)

	# Create placement manager BEFORE building system creation
	var _placement_manager = UnifiedTestFactory.create_test_placement_manager(self, _container)

	# Create building system via factory (injects dependencies & ensures placement manager)
	system = auto_free(BuildingSystem.create_with_injection(_container))
	add_child(system)

	states.building.placed_parent = placed_parent


func test_before_test_setup():
	assert_object(system).is_not_null()
	var issues = system.get_dependency_issues()
	assert_array(issues).is_empty()


@warning_ignore("unused_parameter")


func test_enter_build_mode_rejects_null():
	var ok = system.enter_build_mode(null)
	assert_bool(ok).is_false()


@warning_ignore("unused_parameter")


func test_enter_build_mode_creates_preview() -> void:
	var ok = system.enter_build_mode(TestSceneLibrary.placeable_2d_test)
	assert_bool(ok).is_true()
	var preview = _container.get_states().building.preview
	assert_object(preview).is_not_null()


func test_enter_build_mode_valid_placeable():
	var ok = system.enter_build_mode(TestSceneLibrary.placeable_2d_test)
	assert_bool(ok).is_true()
	assert_object(_container.get_states().building.preview).is_not_null()


func test_unhandled_input():
	# Verify build confirm triggers try_build when in build mode
	var actions = _container.config.actions
	var placeable = TestSceneLibrary.placeable_2d_test
	system.enter_build_mode(placeable)
	var event = InputEventAction.new()
	event.action = actions.confirm_build
	event.pressed = true
	system._unhandled_input(event)


func test_get_dependency_issues():
	var issues = system.get_dependency_issues()
	assert_array(issues).is_empty()


func test_enter_build_mode_sets_preview():
	var ok = system.enter_build_mode(TestSceneLibrary.placeable_2d_test)
	assert_bool(ok).is_true()
	var preview_instance = _container.get_states().building.preview
	assert_object(preview_instance).is_not_null()


@warning_ignore("unused_parameter")


func test_enter_build_mode_idempotent():
	# Enter build mode twice with same placeable; second call should still succeed and have a preview
	var ok1 = system.enter_build_mode(TestSceneLibrary.placeable_2d_test)
	assert_bool(ok1).is_true()
	var preview1 = _container.get_states().building.preview
	assert_object(preview1).is_not_null()
	var ok2 = system.enter_build_mode(TestSceneLibrary.placeable_2d_test)
	assert_bool(ok2).is_true()
	var preview2 = _container.get_states().building.preview
	assert_object(preview2).is_not_null()
	assert_object(preview2).is_not_same(preview1)


@warning_ignore("unused_parameter")


func test_try_build(
	p_placeable: Placeable,
	ex_null_result: bool,
	test_parameters := [[null, true], [placeable_2d_test, false]]
) -> void:
	if p_placeable:
		system.enter_build_mode(p_placeable)
	var result = system.try_build()
	assert_bool(result == null).is_equal(ex_null_result)


@warning_ignore("unused_parameter")


func test_build_instance_internal(
	p_placeable: Placeable,
	p_expect_null: bool,
	test_parameters := [[null, true], [load("uid://jgmywi04ib7c"), false]]
) -> void:
	if p_placeable:
		system.enter_build_mode(p_placeable)
	var result = system.try_build()
	assert_bool(result == null).is_equal(p_expect_null)


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
