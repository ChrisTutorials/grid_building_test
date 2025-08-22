# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# Verifies end-to-end pipeline:
# ShapeCast (GridPositioner2D) -> GridTargetingState.target -> ManipulationSystem.active_target_node
# -> TargetHighlighter color selection in MOVE & DEMOLISH modes.

var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var positioner: GridPositioner2D
var manipulation_system: ManipulationSystem
var highlighter: TargetHighlighter

var mode_state: ModeState
var targeting_state: GridTargetingState
var manipulation_state: ManipulationState
var highlight_settings: HighlightSettings


func before_test():
	# Acquire states & settings from composition container
	var states = _container.get_states()
	mode_state = states.mode
	targeting_state = states.targeting
	manipulation_state = states.manipulation

	# Provide a parent for manipulation operations (mirrors other tests)
	var manipulation_parent: Node2D = auto_free(Node2D.new())
	add_child(manipulation_parent)
	manipulation_state.parent = manipulation_parent

	# Acquire highlight settings via composition container (fail-fast expectation is that config supplies it)
	highlight_settings = _container.get_visual_settings().highlight
	if highlight_settings == null:
		# Backfill missing highlight settings into container visual configuration to mimic runtime setup
		var visual_settings := _container.get_visual_settings()
		visual_settings.highlight = HighlightSettings.new()
		highlight_settings = visual_settings.highlight
	(
		assert_object(highlight_settings)
		. append_failure_message(
			"Composition container should supply (or accept injected) highlight settings"
		)
		. is_not_null()
	)

	# Instance the template positioner scene to inherit proper collision_mask & flags
	positioner = UnifiedTestFactory.create_grid_positioner_2d(self, _container)
	add_child(positioner)

	# Create manipulation system (add to tree before dependency resolution)
	manipulation_system = ManipulationSystem.new()
	add_child(manipulation_system)
	manipulation_system.resolve_gb_dependencies(_container)

	# Highlighter setup (let it pull highlight settings from container)
	highlighter = TargetHighlighter.new()
	add_child(highlighter)
	highlighter.resolve_gb_dependencies(_container)

	# Sanity validation
	assert_array(positioner.validate_dependencies()).is_empty()

	# Allow _ready callbacks & signal hookups to process before tests run
	await await_idle_frame()


func after_test():
	# Clear strong refs (nodes are auto_free registered)
	positioner = null
	manipulation_system = null
	highlighter = null
	mode_state = null
	targeting_state = null
	manipulation_state = null
	highlight_settings = null


## Creates a targetable manipulatable root Area2D with collision and settings.
func create_targetable_manipulatable(p_movable: bool, p_demolishable: bool) -> Area2D:
	var root: Area2D = auto_free(Area2D.new())
	root.name = "TargetRoot"
	# Configure physics layers (1, 10=UsedSpace, 12=Targetable)
	root.set_collision_layer_value(1, true)
	root.set_collision_layer_value(10, true)
	root.set_collision_layer_value(12, true)

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	cs.shape = rect
	root.add_child(cs)

	var manipulatable := Manipulatable.new()
	manipulatable.name = "Manipulatable"
	var m_settings := ManipulatableSettings.new()
	m_settings.movable = p_movable
	m_settings.demolishable = p_demolishable
	manipulatable.settings = m_settings
	manipulatable.root = root
	root.add_child(manipulatable)

	add_child(root)
	return root


@warning_ignore("unused_parameter")


func test_positioner_to_highlight_pipeline(
	p_mode: GBEnums.Mode,
	p_movable: bool,
	p_demolishable: bool,
	test_parameters := [
		[GBEnums.Mode.MOVE, true, true],
		[GBEnums.Mode.MOVE, false, true],
		[GBEnums.Mode.DEMOLISH, true, true],
		[GBEnums.Mode.DEMOLISH, true, false]
	]
) -> void:
	# Arrange
	mode_state.current = p_mode
	var target_root := create_targetable_manipulatable(p_movable, p_demolishable)
	# Center positioner over target
	positioner.global_position = target_root.global_position
	# Update ShapeCast & target
	positioner.force_shapecast_update()
	positioner._update_target()  # Direct call is acceptable within test context
	await await_idle_frame()

	# Retry a few frames if manipulation_state.active_target_node not yet populated
	var attempts := 0
	while manipulation_state.active_target_node == null and attempts < 3:
		positioner._update_target()
		await await_idle_frame()
		attempts += 1

	# Assert targeting state updated
	(
		assert_object(targeting_state.target)
		. append_failure_message("GridTargetingState.target should be collider root")
		. is_equal(target_root)
	)
	# Manipulation system should have resolved a manipulatable
	(
		assert_object(manipulation_state.active_target_node)
		. append_failure_message(
			"ManipulationState.active_target_node was not set after target change (attempts=%s)" % attempts
		)
		. is_not_null()
	)
	if manipulation_state.active_target_node:
		assert_that(manipulation_state.active_target_node.root).is_equal(target_root)

	# Highlighter should color target according to mode & settings
	(
		assert_object(highlighter.current_target)
		. append_failure_message("Highlighter current_target should track targeting state")
		. is_equal(target_root)
	)
	# Determine expected actionable color dynamically
	var expected_color: Color
	match p_mode:
		GBEnums.Mode.MOVE:
			expected_color = (
				highlight_settings.move_valid_color
				if p_movable
				else highlight_settings.move_invalid_color
			)
		GBEnums.Mode.DEMOLISH:
			expected_color = (
				highlight_settings.demolish_valid_color
				if p_demolishable
				else highlight_settings.demolish_invalid_color
			)
	(
		assert_object(target_root.modulate)
		. append_failure_message("Target color should match expected actionable highlight")
		. is_equal(expected_color)
	)

	# Changing mode should update color (secondary verification)
	if p_mode == GBEnums.Mode.MOVE:
		mode_state.current = GBEnums.Mode.DEMOLISH
	elif p_mode == GBEnums.Mode.DEMOLISH:
		mode_state.current = GBEnums.Mode.MOVE
	positioner._update_target()
	await await_idle_frame()
	# After mode swap, ensure color updated to one of the valid/invalid sets for new mode
	match mode_state.current:
		GBEnums.Mode.MOVE:
			if p_movable:
				assert_object(target_root.modulate).is_equal(highlight_settings.move_valid_color)
			else:
				assert_object(target_root.modulate).is_equal(highlight_settings.move_invalid_color)
		GBEnums.Mode.DEMOLISH:
			if p_demolishable:
				assert_object(target_root.modulate).is_equal(
					highlight_settings.demolish_valid_color
				)
			else:
				assert_object(target_root.modulate).is_equal(
					highlight_settings.demolish_invalid_color
				)
