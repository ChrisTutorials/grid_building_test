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


func before_test():
	highlighter = TargetHighlighter.new()
	settings = HighlightSettings.new()
	composition_container = GBCompositionContainer.new()
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
	targeting_state.target = highlight_target
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
	targeting_state.target = null
	await await_idle_frame()
	assert_that(highlighter.current_target).is_null()
	assert_that(target).is_not_null()
	assert_that(target.modulate).is_equal(settings.reset_color)


@warning_ignore("unused_parameter")


func test__on_target_changed(
	p_mode: GBEnums.Mode,
	p_expected_invalid: Color,
	p_expected_valid: Color,
	test_parameters := [
		[GBEnums.Mode.OFF, settings.reset_color, settings.reset_color],
		[GBEnums.Mode.BUILD, settings.build_preview_color, settings.build_preview_color],  # NOTE: There is no invalid build preview so color is the same
		[GBEnums.Mode.MOVE, settings.move_invalid_color, settings.move_valid_color],
		[GBEnums.Mode.DEMOLISH, settings.demolish_invalid_color, settings.demolish_valid_color]
	]
) -> void:
	mode.current = p_mode

	var target = auto_free(Node2D.new())
	add_child(target)
	highlighter._on_target_changed(target, null)

	assert_object(highlighter.current_target).is_equal(target)
	assert_object(target.modulate).is_equal(p_expected_invalid)

	#region Add manipulatable to make it valid
	var manipulatable = auto_free(Manipulatable.new())
	manipulatable.settings = ManipulatableSettings.new()
	manipulatable.settings.movable = true
	manipulatable.settings.demolishable = true
	target.add_child(manipulatable)

	# Reset the target so that when it's added again, it can check for manipulatable a second time
	highlighter.current_target = null
	highlighter._on_target_changed(target, null)
	#endregion

	assert_object(target.modulate).is_equal(p_expected_valid)


@warning_ignore("unused_parameter")


func test_set_movable_display(
	p_moveable: bool,
	p_expected_color: Color,
	p_target,
	test_parameters := [
		[true, settings.move_valid_color, auto_free(Node2D.new())],
		[false, settings.move_invalid_color, auto_free(Node2D.new())],
		[false, Color.BLACK, null]  # Null target test
	]
) -> void:
	highlighter.current_target = p_target
	var result_color = highlighter.set_movable_display(p_target, p_moveable)
	assert_that(result_color).is_equal(p_expected_color)


@warning_ignore("unused_parameter")


func test_set_demolish_display(
	p_moveable: bool,
	p_expected_color: Color,
	p_target,
	test_parameters := [
		[true, settings.demolish_valid_color, auto_free(Node2D.new())],
		[false, settings.demolish_invalid_color, auto_free(Node2D.new())],
		[false, Color.BLACK, null]  # Null target test
	]
) -> void:
	var color = highlighter.set_demolish_display(p_target, p_moveable)
	assert_that(color).is_equal(p_expected_color)


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
	var canvas = auto_free(Node2D.new())
	add_child(canvas)
	highlighter.mode_state.current = p_mode

	if p_add_manipulatable_settings:
		add_child_manipulatable_with_settings(canvas)

	assert_that(highlighter.mode_state.current).is_equal(p_mode)
	assert_that(canvas.modulate).is_equal(Color.WHITE)
	var result = highlighter.set_actionable_colors(canvas)
	assert_that(result).is_equal(p_expected)


## Creates a child manipulatable with ManipulatableSettings set to default
## as a child of the p_target node
func add_child_manipulatable_with_settings(p_target: Node):
	var manipulatable = auto_free(Manipulatable.new())
	p_target.add_child(manipulatable)
	var manipulatable_settings = ManipulatableSettings.new()
	manipulatable.settings = manipulatable_settings


@warning_ignore("unused_parameter")
func test_should_highlight(
	p_data: ManipulationData,
	p_new_target: CanvasItem,
	p_expected: bool,
	p_description: String = "",
	test_parameters := [
		[null, null, false],
		[null, auto_free(Node2D.new()), true, "Target is different"],
		[data_source_is_target, auto_free(Node2D.new()), false, "Is data but target is the same as p_data target"],
		[data_source_is_target, data_source_is_target.target.root, true, "Is Data, Target is Same, but source is different"],
		[data_source_is_not_target, data_source_is_target.target.root, false, "Is Data, Target is Same, but source is different"]
	]
) -> void:
	assert_bool(highlighter.should_highlight(p_data, p_new_target)).append_failure_message("Expected: %s" % p_description).is_equal(p_expected)
	if p_new_target:
		p_new_target.free()
