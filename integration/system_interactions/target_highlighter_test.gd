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

## Helper functions for DRY test patterns.

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
	assert_that(highlighter.mode_state.current).append_failure_message("Mode should be set to %s" % mode_value).is_equal(mode_value)
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

	# Create small Manipulatable instances with explicit root nodes so move_copy.root is available
	var same_root: Node2D = auto_free(Node2D.new())
	same_root.name = "ManipulatableRoot"
	add_child(same_root)

	var same_mani: Manipulatable = auto_free(Manipulatable.new())
	same_mani.root = same_root

	data_source_is_target = ManipulationData.new(
		auto_free(Node.new()), same_mani, same_mani, GBEnums.Action.BUILD
	)

	var diff_root_1: Node2D = auto_free(Node2D.new())
	diff_root_1.name = "ManipulatableRoot1"
	add_child(diff_root_1)

	var mani_dif_1: Manipulatable = auto_free(Manipulatable.new())
	mani_dif_1.root = diff_root_1

	var diff_root_2: Node2D = auto_free(Node2D.new())
	diff_root_2.name = "ManipulatableRoot2"
	add_child(diff_root_2)

	var mani_dif_2: Manipulatable = auto_free(Manipulatable.new())
	mani_dif_2.root = diff_root_2

	data_source_is_not_target = ManipulationData.new(
		auto_free(Node.new()), mani_dif_1, mani_dif_2, GBEnums.Action.BUILD
	)


func test_target_modulate_clears_on_target_null() -> void:
	var target: CanvasItem = highlighter.current_target
	target.modulate = Color.AQUAMARINE
	assert_object(target).append_failure_message("Target should exist before clearing").is_not_null()
	assert_that(target.modulate).append_failure_message("Target modulate should be set to aquamarine").is_not_equal(settings.reset_color)
	targeting_state.clear()
	assert_that(highlighter.current_target).is_null().append_failure_message("Highlighter's current_target should be null after targeting_state.clear()")
	assert_that(target).is_not_null().append_failure_message("Original target reference should still be valid")
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

	assert_object(highlighter.current_target).append_failure_message("Highlighter should have target set after _on_target_changed")\
		.is_equal(target)
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
@warning_ignore("unused_parameter")
func test_should_highlight(
	p_data: Variant,
	p_target_builder: Callable,
	p_expected: bool,
	p_desc: String = "",
	test_parameters := [
		# Both data and target are null
	[null, Callable(self, "_build_null_target"), false, "Both data and target are null"],
		# Target is different (no data)
	[null, Callable(self, "_build_new_target"), true, "Target is different"],
		# Data is present, but target is not the move_copy.root -> should not highlight
	["DATA_SOURCE_IS_TARGET", Callable(self, "_build_new_target"), false, "Is data but target is the same as p_data move_copy"],
		# Data is present, target is move_copy.root and source differs -> should highlight
	["DATA_SOURCE_IS_TARGET", Callable(self, "_build_move_copy_root_target"), true, "Is Data, Target is Same, but source is different"],
		# Different data, target is move_copy.root for other data -> should not highlight
	["DATA_SOURCE_IS_NOT_TARGET", Callable(self, "_build_move_copy_root_target"), false, "Is Data, Target is Same, but source is different"]
	]
) -> void:
	# Resolve sentinel values into actual objects created at runtime
	var d: ManipulationData = null
	if p_data == "DATA_SOURCE_IS_TARGET":
		d = data_source_is_target
	elif p_data == "DATA_SOURCE_IS_NOT_TARGET":
		d = data_source_is_not_target

	# Build or obtain the target via the callable to ensure unique instances where needed
	var t: CanvasItem = null
	if p_target_builder != null:
		t = p_target_builder.call()

	# Run assertion
	assert_bool(highlighter.should_highlight(d, t)).append_failure_message("should_highlight failed - %s" % p_desc).is_equal(p_expected)

	# Cleanup: free dynamically created targets that are not owned elsewhere
	if t != null:
		var is_owned: bool = false
		if is_instance_valid(data_source_is_target) and data_source_is_target.move_copy != null and is_instance_valid(data_source_is_target.move_copy.root):
			if t == data_source_is_target.move_copy.root:
				is_owned = true
		if is_instance_valid(data_source_is_not_target) and data_source_is_not_target.move_copy != null and is_instance_valid(data_source_is_not_target.move_copy.root):
			if t == data_source_is_not_target.move_copy.root:
				is_owned = true
		if not is_owned:
			t.free()

func _build_null_target() -> CanvasItem:
	return null

func _build_new_target() -> CanvasItem:
	var n: Node2D = auto_free(Node2D.new())
	add_child(n)
	return n

func _build_move_copy_root_target() -> CanvasItem:
	# Return the move_copy.root of data_source_is_target if available, otherwise create a new Node
	if is_instance_valid(data_source_is_target) and data_source_is_target.move_copy != null and is_instance_valid(data_source_is_target.move_copy.root):
		return data_source_is_target.move_copy.root
	var fallback: Node2D = auto_free(Node2D.new())
	add_child(fallback)
	return fallback

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
