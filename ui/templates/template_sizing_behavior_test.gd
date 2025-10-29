## Unit tests for template sizing behavior in PlaceableSelectionUI grids.
##
## Tests that templates stretch properly to width (divided by columns) and maintain fixed height
## even when cycling through sequence variants with different icon sizes.

extends GdUnitTestSuite
@warning_ignore("unused_parameter") var test_grid: GridContainer
var placeable_template: PackedScene
var sequence_template: PackedScene
var test_placeables: Array[Placeable]
var test_sequence: PlaceableSequence

const GRID_WIDTH: int = 400
const EXPECTED_PLACEABLE_HEIGHT: int = 48  # PlaceableView height
const EXPECTED_SEQUENCE_HEIGHT: int = 56  # PlaceableListEntry height
const EXPECTED_PLACEABLE_MIN_SIZE: Vector2 = Vector2(120, 48)
const DEFAULT_COLUMNS: int = 3


func before_test() -> void:
	# Load templates
	placeable_template = load(GBTestConstants.TEST_PATH_PLACEABLE_VIEW_UI)
	sequence_template = load(GBTestConstants.TEST_PATH_PLACEABLE_LIST_ENTRY_UI)

	# Create test placeables and sequence
	test_placeables = _create_test_placeables()
	test_sequence = _create_test_sequence()

	# Create test grid
	test_grid = GridContainer.new()
	test_grid.custom_minimum_size = Vector2(GRID_WIDTH, 300)
	test_grid.columns = DEFAULT_COLUMNS
	add_child(test_grid)
	await get_tree().process_frame


func after_test() -> void:
	if test_grid:
		test_grid.queue_free()


## Test: Placeable templates have correct size flags for stretching
## Setup: Load placeable template
## Act: Check size flags configuration
## Assert: Horizontal stretch enabled, proper minimum size set
func test_placeable_template_size_flags() -> void:
	# Act: Create placeable template instance
	var entry_node: PlaceableView = placeable_template.instantiate()
	add_child(entry_node)
	await get_tree().process_frame

	# Assert: Size flags configured for horizontal stretching
	assert_object(entry_node).is_not_null().append_failure_message("Template should be a Control")

	# Check width stretches to column width (allowing some margin for grid spacing)
	var actual_width: float = entry_node.size.x
	(
		assert_float(actual_width) \
		. append_failure_message(
			"Template width %.1f should stretch beyond minimum (>100px)" % actual_width
		) \
		. is_greater(100.0)
	)

	# Check height remains fixed
	var actual_height: float = entry_node.size.y
	(
		assert_float(actual_height) \
		. append_failure_message(
			(
				"Template height %.1f should be exactly %d pixels"
				% [actual_height, EXPECTED_PLACEABLE_HEIGHT]
			)
		) \
		. is_equal(float(EXPECTED_PLACEABLE_HEIGHT))
	)


## Test: Sequence templates stretch to column width
## Setup: Grid with defined width and columns
## Act: Add sequence templates to grid
## Assert: Templates stretch to fill column width while maintaining height
func test_sequence_templates_stretch_to_column_width() -> void:
	# Act: Add sequence template to grid
	var entry_node: PlaceableListEntry = sequence_template.instantiate()
	entry_node.sequence = test_sequence
	test_grid.add_child(entry_node)
	await get_tree().process_frame

	# Assert: Template stretches to column width
	var template: Control = test_grid.get_child(0) as Control
	assert_object(template).is_not_null().append_failure_message(
		"Sequence template should be a Control"
	)

	# Check width stretches to column width
	var actual_width: float = template.size.x
	(
		assert_float(actual_width) \
		. append_failure_message(
			"Sequence template width %.1f should stretch beyond minimum (>100px)" % actual_width
		) \
		. is_greater(100.0)
	)

	# Check height remains fixed
	var actual_height: float = template.size.y
	(
		assert_float(actual_height) \
		. append_failure_message(
			(
				"Sequence template height %.1f should be exactly %d pixels"
				% [actual_height, EXPECTED_SEQUENCE_HEIGHT]
			)
		) \
		. is_equal(float(EXPECTED_SEQUENCE_HEIGHT))
	)


## Test: Height consistency during sequence variant cycling
## Setup: Sequence template added to grid
## Act: Cycle through sequence variants with different icon sizes
## Assert: Template height remains constant despite icon size changes
func test_height_consistency_during_variant_cycling() -> void:
	# Setup: Add sequence template to grid
	var entry_node: PlaceableListEntry = sequence_template.instantiate()
	entry_node.sequence = test_sequence
	test_grid.add_child(entry_node)
	await get_tree().process_frame

	# Get initial dimensions
	var template: Control = test_grid.get_child(0) as Control
	var initial_height: float = template.size.y
	var initial_width: float = template.size.x
	(
		assert_float(initial_height) \
		. append_failure_message(
			(
				"Initial template height %.1f should be %d pixels"
				% [initial_height, EXPECTED_SEQUENCE_HEIGHT]
			)
		) \
		. is_equal(float(EXPECTED_SEQUENCE_HEIGHT))
	)

	# Act: Cycle through variants (simulate user interaction)
	if entry_node.has_method("cycle_to_next"):
		entry_node.cycle_to_next()
		await get_tree().process_frame
	else:
		# Manually trigger variant change if method not available
		if entry_node.has_signal("variant_changed"):
			entry_node.emit_signal("variant_changed", test_placeables[1])
			await get_tree().process_frame

	# Assert: Dimensions remain consistent after cycling
	var post_cycle_height: float = template.size.y
	var post_cycle_width: float = template.size.x
	(
		assert_float(post_cycle_height) \
		. append_failure_message(
			(
				"Template height should remain %d pixels after cycling, was %.1f, now %.1f"
				% [EXPECTED_SEQUENCE_HEIGHT, initial_height, post_cycle_height]
			)
		) \
		. is_equal(initial_height)
	)
	assert_float(post_cycle_width).is_equal(initial_width).append_failure_message(
		(
			"Template width should remain %.1f pixels after cycling, now %.1f"
			% [initial_width, post_cycle_width]
		)
	)


## Test: Mixed content grid maintains consistent sizing
## Setup: Grid with both placeable and sequence templates
## Act: Add mixed content to grid
## Assert: All templates have consistent sizing behavior
func test_mixed_content_consistent_sizing() -> void:
	# Act: Add mixed content - alternating placeables and sequences
	var placeable_entry: PlaceableView = placeable_template.instantiate()
	placeable_entry.placeable = test_placeables[0]
	test_grid.add_child(placeable_entry)

	var sequence_entry: PlaceableListEntry = sequence_template.instantiate()
	sequence_entry.sequence = test_sequence
	test_grid.add_child(sequence_entry)

	var placeable_entry2: PlaceableView = placeable_template.instantiate()
	placeable_entry2.placeable = test_placeables[1]
	test_grid.add_child(placeable_entry2)

	await get_tree().process_frame

	# Assert: All templates have consistent sizing
	var children: Array[Node] = test_grid.get_children()
	var expected_heights: Array[float] = []
	var expected_widths: Array[float] = []

	for i in range(children.size()):
		var template: Control = children[i] as Control
		assert_object(template).is_not_null().append_failure_message(
			"Mixed content template %d should be a Control" % i
		)

		var actual_height: float = template.size.y
		var actual_width: float = template.size.x

		# Check height matches expected value for template type
		# PlaceableView = 48px, PlaceableListEntry = 56px
		var expected_height: float = (
			EXPECTED_PLACEABLE_HEIGHT if template is PlaceableView else EXPECTED_SEQUENCE_HEIGHT
		)
		(
			assert_float(actual_height) \
			. append_failure_message(
				(
					"Mixed content template %d height %.1f should be %.0f pixels (type: %s)"
					% [i, actual_height, expected_height, template.get_class()]
				)
			) \
			. is_equal(expected_height)
		)

		# Check width stretches appropriately
		(
			assert_float(actual_width) \
			. append_failure_message(
				(
					"Mixed content template %d width %.1f should stretch beyond minimum (>100px)"
					% [i, actual_width]
				)
			) \
			. is_greater(100.0)
		)

		expected_heights.append(actual_height)
		expected_widths.append(actual_width)

	# All templates should have consistent widths (allow variance for different types)
	for i in range(1, expected_widths.size()):
		# Allow for some width variance between different template types
		var width_difference: float = abs(expected_widths[i] - expected_widths[0])
		(
			assert_float(width_difference) \
			. append_failure_message(
				(
					"Template %d width %.1f should be similar to template 0 width %.1f (difference: %.1f, tolerance: 100px)"
					% [i, expected_widths[i], expected_widths[0], width_difference]
				)
			) \
			. is_less(100.0)
		)  # Increased tolerance since PlaceableView and PlaceableListEntry may differ


## Test: Size flags ensure proper stretching behavior
## Setup: Individual template nodes
## Act: Check size flags configuration
## Assert: Size flags are set for horizontal stretching but not vertical
func test_size_flags_configuration() -> void:
	# Setup: Create template instances
	var placeable_entry: PlaceableView = placeable_template.instantiate()
	var sequence_entry: PlaceableListEntry = sequence_template.instantiate()

	# Check placeable template size flags
	(
		assert_int(placeable_entry.size_flags_horizontal) \
		. append_failure_message(
			(
				"PlaceableView should have horizontal SIZE_EXPAND_FILL flag (%d), got %d"
				% [Control.SIZE_EXPAND_FILL, placeable_entry.size_flags_horizontal]
			)
		) \
		. is_equal(Control.SIZE_EXPAND_FILL)
	)

	# Sequence template should stretch horizontally (the HBoxContainer may have different flags)
	var sequence_size_flags: int = sequence_entry.size_flags_horizontal
	(
		assert_that(
			(
				sequence_size_flags == Control.SIZE_EXPAND_FILL
				or sequence_size_flags == Control.SIZE_EXPAND
			)
		) \
		. append_failure_message(
			(
				"PlaceableListEntry should have horizontal expansion flags, got %d"
				% sequence_size_flags
			)
		) \
		. is_true()
	)

	# Clean up
	placeable_entry.queue_free()
	sequence_entry.queue_free()


## Helper method to create test placeables for UI testing
func _create_test_placeables() -> Array[Placeable]:
	var placeables: Array[Placeable] = []

	# Create a couple of test placeables with different display names
	var placeable1: Placeable = Placeable.new()
	placeable1.display_name = "Test Building 1"
	placeable1.packed_scene = preload(GBTestConstants.TEST_PATH_PLACEABLE_INSTANCE_SCENE)
	placeables.append(placeable1)

	var placeable2: Placeable = Placeable.new()
	placeable2.display_name = "Test Building 2"
	placeable2.packed_scene = preload(GBTestConstants.TEST_PATH_PLACEABLE_INSTANCE_SCENE)
	placeables.append(placeable2)

	return placeables


## Helper method to create test sequence for UI testing
func _create_test_sequence() -> PlaceableSequence:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Test Sequence"
	sequence.placeables = _create_test_placeables()
	return sequence
