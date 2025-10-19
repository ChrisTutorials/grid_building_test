# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var highlighter: TargetHighlighter
var settings: HighlightSettings
var manipulation_state: ManipulationState
var mode: ModeState
var targeting_state: GridTargetingState

var highlight_target: Node2D

var data_source_is_target: ManipulationData
var data_source_is_not_target: ManipulationData
var composition_container: GBCompositionContainer

# ================================
# Helper Functions for DRY Patterns
# ================================

func create_test_target_with_manipulatable() -> Node2D:
	"""Create a test target Node2D with a manipulatable child for valid state testing."""
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.settings = create_default_manipulatable_settings()
	target.add_child(manipulatable)
	return target

func create_default_manipulatable_settings() -> ManipulatableSettings:
	"""Create default ManipulatableSettings with movable and demolishable enabled."""
	var manipulatable_settings: ManipulatableSettings = ManipulatableSettings.new()
	manipulatable_settings.movable = true
	manipulatable_settings.demolishable = true
	return manipulatable_settings

func create_test_preview_object() -> Node2D:
	"""Create a test preview object with building_node script attached."""
	var preview_object: Node2D = auto_free(Node2D.new())
	add_child(preview_object)
	
	# Add building_node script to make it a preview object
	var building_node: Node = auto_free(Node.new())
	var building_node_script: Script = load("res://addons/grid_building/components/building_node.gd")
	building_node.set_script(building_node_script)
	preview_object.add_child(building_node)
	
	return preview_object

func assert_color_equal(actual: Color, expected: Color, context: String = "") -> void:
	"""Assert that two colors are equal with optional context."""
	assert_that(actual).append_failure_message("Color assertion failed: %s" % context).is_equal(expected)

func setup_mode_and_assert_initial_state(mode_value: GBEnums.Mode, canvas: Node2D) -> void:
	"""Set the mode and assert initial canvas state."""
	highlighter.mode_state.current = mode_value
	assert_that(highlighter.mode_state.current).is_equal(mode_value)
	assert_color_equal(canvas.modulate, Color.WHITE, "Initial canvas modulate should be white")


func before_test() -> void:
	highlighter = TargetHighlighter.new()
	settings = HighlightSettings.new()
	composition_container = GBTestConstants.TEST_COMPOSITION_CONTAINER.duplicate(true)
	var states := composition_container.get_states()
	manipulation_state = states.manipulation
	highlighter.targeting_state = states.targeting
	highlighter.highlight_settings = settings
	highlighter.manipulation_state = manipulation_state
	mode = ModeState.new()
	highlighter.mode_state = mode
	add_child(highlighter)

	#region targeting setup
	targeting_state = states.targeting
	highlighter.targeting_state = targeting_state

	highlight_target = auto_free(Node2D.new())
	add_child(highlight_target)
	targeting_state.set_manual_target(highlight_target)
	#endregion

	# Create manipulatables using factory
	var same_mani: Manipulatable = GodotTestFactory.create_manipulatable(self, "ManipulatableRoot")
	data_source_is_target = ManipulationData.new(
		auto_free(Node.new()), same_mani, same_mani, GBEnums.Action.BUILD
	)

	var mani_dif_1: Manipulatable = GodotTestFactory.create_manipulatable(
		self, "ManipulatableRoot1"
	)
	mani_dif_1.name = "Manipulatable1"

	var mani_dif_2: Manipulatable = GodotTestFactory.create_manipulatable(
		self, "ManipulatableRoot2"
	)
	mani_dif_2.name = "Manipulatable2"

	data_source_is_not_target = ManipulationData.new(
		auto_free(Node.new()), mani_dif_1, mani_dif_2, GBEnums.Action.BUILD
	)


func test_target_modulate_clears_on_target_null() -> void:
	var target: CanvasItem = highlighter.current_target
	target.modulate = Color.AQUAMARINE
	assert_object(target).is_not_null()
	assert_that(target.modulate).is_not_equal(settings.reset_color)
	targeting_state.clear()
	await await_idle_frame()
	assert_that(highlighter.current_target).is_null() \
		.append_failure_message("Highlighter's current_target should be null after targeting_state.clear()")
	assert_that(target).is_not_null() \
		.append_failure_message("Original target reference should still be valid")
	assert_color_equal(target.modulate, settings.reset_color, "Target modulate should reset to reset_color after targeting state cleared")


@warning_ignore("unused_parameter")


func test__on_target_changed(
	p_mode: GBEnums.Mode,
	p_expected_invalid: Color,
	p_expected_valid: Color,
	test_parameters := [
		[GBEnums.Mode.OFF, settings.reset_color, settings.reset_color],
		[GBEnums.Mode.BUILD, settings.reset_color, settings.reset_color],  # Regular objects don't get highlighted in BUILD mode (only preview objects do)
		[GBEnums.Mode.MOVE, settings.move_invalid_color, settings.move_valid_color],
		[GBEnums.Mode.DEMOLISH, settings.demolish_invalid_color, settings.demolish_valid_color]
	]
) -> void:
	mode.current = p_mode

	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	highlighter._on_target_changed(target, null)

	assert_object(highlighter.current_target).is_equal(target)
	assert_color_equal(target.modulate, p_expected_invalid, "Target should have invalid color initially")

	#region Add manipulatable to make it valid
	var target_with_manipulatable: Node2D = create_test_target_with_manipulatable()

	# Reset the target so that when it's added again, it can check for manipulatable a second time
	highlighter.current_target = null
	highlighter._on_target_changed(target_with_manipulatable, null)
	#endregion

	assert_color_equal(target_with_manipulatable.modulate, p_expected_valid, "Target with manipulatable should have valid color")


@warning_ignore("unused_parameter")


func test_set_movable_display(
	p_moveable: bool,
	p_expected_color: Color,
	p_target: Node2D,
	test_parameters := [
		[true, settings.move_valid_color, auto_free(Node2D.new())],
		[false, settings.move_invalid_color, auto_free(Node2D.new())],
		[false, Color.BLACK, null]  # Null target test
	]
) -> void:
	highlighter.current_target = p_target
	var result_color: Color = highlighter.set_movable_display(p_target, p_moveable)
	assert_color_equal(result_color, p_expected_color)


@warning_ignore("unused_parameter")


func test_set_demolish_display(
	p_moveable: bool,
	p_expected_color: Color,
	p_target: Node2D,
	test_parameters := [
		[true, settings.demolish_valid_color, auto_free(Node2D.new())],
		[false, settings.demolish_invalid_color, auto_free(Node2D.new())],
		[false, Color.BLACK, null]  # Null target test
	]
) -> void:
	var color: Color = highlighter.set_demolish_display(p_target, p_moveable)
	assert_color_equal(color, p_expected_color)


@warning_ignore("unused_parameter")


func test_set_actionable_colors(
	p_mode: GBEnums.Mode,
	p_add_manipulatable_settings: bool,
	p_expected: Color,
	test_parameters := [
		[GBEnums.Mode.OFF, false, Color.WHITE],
		[GBEnums.Mode.MOVE, false, settings.move_invalid_color],
		[GBEnums.Mode.DEMOLISH, false, settings.demolish_invalid_color],
		[GBEnums.Mode.MOVE, true, settings.move_valid_color],
		[GBEnums.Mode.DEMOLISH, true, settings.demolish_valid_color],
	]
) -> void:
	var canvas: Node2D = auto_free(Node2D.new())
	add_child(canvas)
	setup_mode_and_assert_initial_state(p_mode, canvas)

	if p_add_manipulatable_settings:
		add_child_manipulatable_with_settings(canvas)

	var result: Color = highlighter.set_actionable_colors(canvas)
	assert_color_equal(result, p_expected)


## Creates a child manipulatable with ManipulatableSettings set to default
## as a child of the p_target node
func add_child_manipulatable_with_settings(p_target: Node) -> void:
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	p_target.add_child(manipulatable)
	var manipulatable_settings: ManipulatableSettings = create_default_manipulatable_settings()
	manipulatable.settings = manipulatable_settings


@warning_ignore("unused_parameter")
func test_should_highlight(
	p_data: ManipulationData,
	p_new_target: CanvasItem,
	p_expected: bool,
	p_description: String = "",
	test_parameters := [
		[null, null, false, "Both data and target are null"],
		[null, auto_free(Node2D.new()), true, "Target is different"],
		[data_source_is_target, auto_free(Node2D.new()), false, "Is data but target is the same as p_data move_copy"],
		[data_source_is_target, data_source_is_target.move_copy.root, true, "Is Data, Target is Same, but source is different"],
		[data_source_is_not_target, data_source_is_target.move_copy.root, false, "Is Data, Target is Same, but source is different"]
	]
) -> void:
	assert_bool(highlighter.should_highlight(p_data, p_new_target)).append_failure_message("Expected: %s" % p_description).is_equal(p_expected)
	if p_new_target:
		p_new_target.free()

func test_build_mode_preview_objects_still_highlighted() -> void:
	"""Test that preview objects in BUILD mode still get highlighted correctly."""
	# Setup BUILD mode
	highlighter.mode_state.current = GBEnums.Mode.BUILD
	
	# Create a preview object (has BuildingNode script attached)
	var preview_object: Node2D = create_test_preview_object()
	
	# Create a regular object (no BuildingNode script)
	var regular_object: Node2D = auto_free(Node2D.new())
	add_child(regular_object)
	
	# Test that preview object gets highlighted in BUILD mode
	highlighter.set_actionable_colors(preview_object)
	assert_color_equal(
		preview_object.modulate, 
		settings.build_preview_color,
		"Preview object should get build_preview_color in BUILD mode"
	)
	
	# Test that regular object does NOT get highlighted in BUILD mode
	highlighter.set_actionable_colors(regular_object)
	assert_color_equal(
		regular_object.modulate,
		settings.reset_color,
		"Regular object should get reset_color in BUILD mode"
	)
