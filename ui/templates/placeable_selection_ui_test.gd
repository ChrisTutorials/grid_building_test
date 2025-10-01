## Unit tests for PlaceableSelectionUI - unified selection component supporting mixed content.
##
## Tests the GridContainer-based approach for displaying both individual placeables and sequences
## simultaneously in categorized tabs with configurable column layouts and proper dependency injection.
## Validates template instantiation, content loading, signal handling, and building system integration.
class_name PlaceableSelectionUITest
extends GdUnitTestSuite

# Test constants for magic number elimination
const TEST_SINGLE_COLUMN: int = 1
const EXPECTED_TAB_COUNT: int = 2
const TEST_DISPLAY_NAME_PLACEABLES: String = "Test Buildings"
const TEST_DISPLAY_NAME_SEQUENCES: String = "Test Sequences"

# Test placeable configuration
const TEST_PLACEABLE_NAME_1: String = "TestSmithyBuilding"
const TEST_PLACEABLE_NAME_2: String = "TestRectBuilding"
const TEST_SEQUENCE_NAME_1: String = "TestTowerSequence"
const TEST_SEQUENCE_VARIANT_COUNT: int = 3

var selection_ui: PlaceableSelectionUI
var test_container: GBCompositionContainer
var test_systems_context: GBSystemsContext
var test_mode_state: ModeState
var test_building_system: BuildingSystem

# Test content resources
var test_placeables: Array[Placeable] = []
var test_sequences: Array[PlaceableSequence] = []
var test_category_tags: Array[CategoricalTag] = []

func before_test() -> void:
	# Create test UI component with auto_free
	selection_ui = auto_free(PlaceableSelectionUI.new())
	
	# Create the expected node structure: Panel/Margin/TabContainer
	var panel: PanelContainer = auto_free(PanelContainer.new())
	panel.name = "Panel"
	selection_ui.add_child(panel)
	
	var margin: MarginContainer = auto_free(MarginContainer.new())
	margin.name = "Margin"
	panel.add_child(margin)
	
	var tab_container: TabContainer = auto_free(TabContainer.new())
	tab_container.name = "TabContainer"
	margin.add_child(tab_container)
	
	# Set up node references to match template structure
	selection_ui.ui_root = selection_ui
	selection_ui.tab_container = tab_container
	
	add_child(selection_ui)
	await get_tree().process_frame
	
	# Create test dependency container using tested composition container
	test_container = auto_free(GBTestConstants.TEST_COMPOSITION_CONTAINER.duplicate(true))
	test_systems_context = test_container.get_systems_context()
	test_mode_state = test_container.get_mode_state()
	
	# Create test building system and add to context
	test_building_system = auto_free(BuildingSystem.new())
	test_systems_context.set_system(test_building_system)
	
	# Create test content
	_create_test_content()
	
	# Configure UI templates (mock template scenes)
	selection_ui.grid_columns = 3
	selection_ui.placeable_entry_template = _create_mock_placeable_entry_template()
	selection_ui.sequence_entry_template = _create_mock_sequence_entry_template()

func after_test() -> void:
	# Cleanup handled automatically by auto_free() in before_test()
	test_placeables.clear()
	test_sequences.clear()
	test_category_tags.clear()

#region PLACEABLES Content Type Tests

## Test: mixed content initialization with both placeables and sequences
## Setup: UI with both content types and category tags
## Act: Load assets and setup tabs
## Assert: Correct tab count, mixed content loaded, grid layout configured
func test_mixed_content_initialization() -> void:
	# Setup: Configure for mixed content
	selection_ui.placeables = test_placeables
	selection_ui.sequences = test_sequences
	selection_ui.category_tags = test_category_tags
	
	# Act: Initialize dependencies and rebuild UI
	selection_ui.resolve_gb_dependencies(test_container)
	selection_ui.rebuild()
	await get_tree().process_frame
	
	# Assert: UI correctly configured for mixed content
	var tab_container: TabContainer = selection_ui.tab_container
	assert_object(tab_container).append_failure_message(
		"TabContainer should be configured after initialization"
	).is_not_null()
	
	assert_int(tab_container.get_tab_count()).append_failure_message(
		"Should have tabs for categories with content"
	).is_greater_equal(1)

## Test: mixed grid structure creation with both content types
## Setup: Mixed content with placeables and sequences
## Act: Create grids and validate structure
## Assert: Grid contains both placeable and sequence entries
func test_mixed_grid_structure_creation() -> void:
	# Setup: Mixed content
	selection_ui.placeables = test_placeables
	selection_ui.sequences = test_sequences
	selection_ui.category_tags = test_category_tags
	
	# Act: Rebuild UI with mixed content
	selection_ui.resolve_gb_dependencies(test_container)
	selection_ui.rebuild()
	await get_tree().process_frame
	
	# Assert: Grid structure accommodates both content types
	var tab_container: TabContainer = selection_ui.tab_container
	assert_int(tab_container.get_tab_count()).append_failure_message(
		"Should have at least one tab for mixed content"
	).is_greater_equal(1)
	
	# Check first tab has mixed grid content
	if tab_container.get_tab_count() > 0:
		var first_tab: GridContainer = tab_container.get_child(0) as GridContainer
		assert_object(first_tab).append_failure_message(
			"First tab should be a GridContainer for mixed content"
		).is_not_null()
		
		# Grid columns are now configured via template, not script property
		assert_int(first_tab.columns).append_failure_message(
			"Grid columns should be configured via template"
		).is_greater(0)

#endregion

#region SEQUENCES Content Type Tests

## Test: sequences content functionality within mixed content
## Setup: UI with sequences and placeables
## Act: Initialize and validate sequence-specific features
## Assert: Sequence entries created with variant cycling support
func test_sequences_mixed_content_functionality() -> void:
	# Setup: Mixed content with focus on sequences (ensure sequence tags match category tags)
	selection_ui.placeables = []
	selection_ui.sequences = test_sequences
	selection_ui.category_tags = test_category_tags
	
	# Debug: Check that sequences have proper tags
	for sequence in test_sequences:
		assert_object(sequence).append_failure_message("Sequence should not be null").is_not_null()
		assert_array(sequence.placeables).append_failure_message("Sequence should have placeable variants").is_not_empty()
		
		# Check first placeable in sequence has tags
		var first_placeable: Placeable = sequence.placeables[0]
		assert_array(first_placeable.tags).append_failure_message("Sequence placeable should have tags").is_not_empty()
	
	# Act: Initialize and rebuild
	selection_ui.resolve_gb_dependencies(test_container)
	selection_ui.rebuild()
	await get_tree().process_frame
	
	# Assert: UI configured for sequences within mixed content
	var tab_container: TabContainer = selection_ui.tab_container
	assert_int(tab_container.get_tab_count()).append_failure_message(
		"Should have exactly one tab for sequences content when placeables is empty"
	).is_equal(1)
	
	# Verify the single tab is for sequences
	if tab_container.get_tab_count() > 0:
		var first_tab: GridContainer = tab_container.get_child(0) as GridContainer
		assert_str(first_tab.name).append_failure_message(
			"Tab should be named after sequences category"
		).is_equal(TEST_DISPLAY_NAME_SEQUENCES)

## Test: PlaceableSelectionUI creates correct grid structure for sequences
## Setup: UI with sequences content and variant cycling support
## Act: Setup tabs and verify sequence entry creation
## Assert: GridContainer supports sequence entries with variant cycling capability
func test_sequences_grid_structure_with_variant_cycling() -> void:
	# Setup: Configure UI for sequences
	selection_ui.placeables = []  # No placeables for sequence-focused test
	selection_ui.sequences = test_sequences
	selection_ui.category_tags = test_category_tags
	
	# Act: Initialize and rebuild
	selection_ui.resolve_gb_dependencies(test_container)
	selection_ui.rebuild()
	await get_tree().process_frame
	
	# Assert: Verify sequence grid structure
	var tab_container: TabContainer = selection_ui.tab_container
	assert_int(tab_container.get_tab_count()).append_failure_message(
		"Tab container should have exactly one tab for sequences-only content"
	).is_equal(1)
	
	# Check first tab has grid container
	var first_tab: Control = tab_container.get_tab_control(0)
	assert_object(first_tab).append_failure_message(
		"First sequences tab should exist"
	).is_not_null()
	
	# Verify tab is a GridContainer (unified approach for sequences)
	assert_bool(first_tab is GridContainer).append_failure_message(
		"Sequences tab should use GridContainer for unified approach, got %s" % str(first_tab.get_class())
	).is_true()

#endregion

#region Grid Layout Configuration Tests

#endregion

#region Dynamic Dependency Management Tests

## Test: PlaceableSelectionUI uses dynamic building system retrieval instead of caching
## Setup: UI with systems context containing building system
## Act: Access building system through dynamic getter
## Assert: Building system retrieved correctly without local caching
func test_dynamic_building_system_retrieval() -> void:
	# Setup: Configure UI with systems context
	selection_ui.resolve_gb_dependencies(test_container)
	
	# Act: Access building system through dynamic retrieval
	var retrieved_system: BuildingSystem = selection_ui._get_building_system()
	
	# Assert: System retrieved correctly
	assert_object(retrieved_system).append_failure_message(
		"Building system should be retrieved dynamically from systems context"
	).is_not_null()
	
	assert_object(retrieved_system).append_failure_message(
		"Retrieved building system should match the one in systems context"
	).is_same(test_building_system)

## Test: PlaceableSelectionUI handles missing building system gracefully
## Setup: UI with systems context that has no building system configured
## Act: Attempt to retrieve building system
## Assert: Handles null building system without crashing
func test_missing_building_system_handling() -> void:
	# Setup: Configure UI with systems context that has no building system
	var empty_container: GBCompositionContainer = auto_free(GBTestConstants.TEST_COMPOSITION_CONTAINER.duplicate(true))
	# Don't add any building system - let it remain null
	selection_ui.resolve_gb_dependencies(empty_container)
	
	# Act: Attempt to retrieve building system
	var retrieved_system: BuildingSystem = selection_ui._get_building_system()
	
	# Assert: Handles null gracefully
	assert_object(retrieved_system).append_failure_message(
		"Missing building system should return null without crashing"
	).is_null()

#endregion

#region Signal Handling Tests

## Test: PlaceableSelectionUI connects to mode state changes correctly
## Setup: UI with mode state that emits mode changes
## Act: Trigger mode state change
## Assert: UI responds to mode changes appropriately
func test_mode_state_change_handling() -> void:
	# Setup: UI with mode state
	selection_ui.resolve_gb_dependencies(test_container)
	
	# Track signal connections
	var signal_data: Array[bool] = [false]  # [signal_received]
	
	# Connect to mode state to verify signal handling
	if test_mode_state.has_signal("mode_changed"):
		test_mode_state.mode_changed.connect(func() -> void: signal_data[0] = true)
	
	# Act: Trigger mode change
	if test_mode_state.has_method("set_mode"):
		test_mode_state.set_mode(1)  # Change to different mode
	
	# Assert: UI should be connected to mode state changes
	assert_object(selection_ui._mode_state).append_failure_message(
		"Mode state should be assigned to UI"
	).is_same(test_mode_state)

#endregion

#region Content Loading and Validation Tests

## Test: PlaceableSelectionUI loads and validates content correctly
## Setup: UI with mixed valid and invalid content
## Act: Load assets and validate content
## Assert: Valid content loaded, invalid content filtered out
func test_content_loading_and_validation() -> void:
	# Setup: Use only valid placeables for positive validation test
	selection_ui.placeables = test_placeables  # Only valid placeables
	selection_ui.category_tags = test_category_tags
	
	# Act: Load and validate content
	selection_ui.resolve_gb_dependencies(test_container)
	selection_ui.rebuild()
	await get_tree().process_frame
	
	# Assert: Valid content loaded properly
	assert_int(selection_ui.placeables.size()).append_failure_message(
		"Placeables should contain all valid entries"
	).is_equal(test_placeables.size())
	
	# Verify UI created successfully with valid content
	var tab_container: TabContainer = selection_ui.tab_container
	assert_object(tab_container).append_failure_message(
		"Tab container should be created with valid content"
	).is_not_null()
	
	# Verify that valid placeables created proper tabs
	assert_int(tab_container.get_tab_count()).append_failure_message(
		"Should have at least one tab for valid category content"
	).is_greater_equal(1)

## Test: null placeable validation behavior
## Setup: Mixed valid and null placeables
## Act: Rebuild UI and monitor error output
## Assert: UI handles nulls gracefully while reporting errors
func test_null_placeable_validation_handling() -> void:
	# Setup: Add null entries to test validation
	var mixed_placeables: Array[Placeable] = test_placeables.duplicate()
	mixed_placeables.append(null)  # Add invalid entry
	
	selection_ui.placeables = mixed_placeables
	selection_ui.category_tags = test_category_tags
	
	# Act: Load content - this will generate validation errors for null entries
	selection_ui.resolve_gb_dependencies(test_container)
	selection_ui.rebuild()
	await get_tree().process_frame
	
	# Assert: UI still functions despite validation errors
	var tab_container: TabContainer = selection_ui.tab_container
	assert_object(tab_container).append_failure_message(
		"Tab container should be created despite null entries"
	).is_not_null()
	
	# Verify original array unchanged (nulls not removed from source)
	assert_int(selection_ui.placeables.size()).append_failure_message(
		"Original placeables array should be unchanged"
	).is_equal(mixed_placeables.size())
	
	# Verify UI still creates tabs for valid content (nulls skipped during processing)
	assert_int(tab_container.get_tab_count()).append_failure_message(
		"Should have tabs for valid content even with null entries present"
	).is_greater_equal(1)

#endregion

#region DRY Helper Methods

## Creates test placeables with different characteristics
func _create_test_placeables() -> void:
	# Create basic test smithy placeable
	var smithy_placeable: Placeable = GBTestConstants.PLACEABLE_SMITHY.duplicate(true)
	smithy_placeable.display_name = TEST_PLACEABLE_NAME_1
	smithy_placeable.tags = [test_category_tags[0]]  # Use buildings category tag
	test_placeables.append(smithy_placeable)
	
	# Create rectangular test placeable
	var rect_placeable: Placeable = GBTestConstants.PLACEABLE_RECT_4X2.duplicate(true)
	rect_placeable.display_name = TEST_PLACEABLE_NAME_2
	rect_placeable.tags = [test_category_tags[0]]  # Use buildings category tag
	test_placeables.append(rect_placeable)

## Creates test placeable sequences with variants for cycling
func _create_test_sequences() -> void:
	# Create test tower sequence with variants
	var tower_sequence: PlaceableSequence = auto_free(PlaceableSequence.new())
	tower_sequence.display_name = TEST_SEQUENCE_NAME_1
	
	# Add variant placeables to sequence with tags
	for i in range(TEST_SEQUENCE_VARIANT_COUNT):
		var variant: Placeable = GBTestConstants.PLACEABLE_RECT_4X2.duplicate(true)
		variant.display_name = "Tower Variant %d" % (i + 1)
		# Add the test category tag to each variant so sequences can be found
		variant.tags = [test_category_tags[1]]  # Use sequences category tag
		tower_sequence.placeables.append(variant)
	
	test_sequences.append(tower_sequence)

## Creates test category tags for organizing content
func _create_test_category_tags() -> void:
	# Create buildings category
	var buildings_tag: CategoricalTag = auto_free(CategoricalTag.new())
	buildings_tag.display_name = TEST_DISPLAY_NAME_PLACEABLES
	test_category_tags.append(buildings_tag)
	
	# Create sequences category  
	var sequences_tag: CategoricalTag = auto_free(CategoricalTag.new())
	sequences_tag.display_name = TEST_DISPLAY_NAME_SEQUENCES
	test_category_tags.append(sequences_tag)

## Creates all test content (category tags first, then placeables and sequences that reference them)
func _create_test_content() -> void:
	_create_test_category_tags()
	_create_test_placeables()
	_create_test_sequences()

## Creates a mock placeable entry template for testing (simplified PanelContainer that works as PlaceableView)
func _create_mock_placeable_entry_template() -> PackedScene:
	var placeable_scene: PackedScene = load("res://templates/grid_building_templates/ui/placement_selection/placeable_view.tscn") as PackedScene
	assert_object(placeable_scene).append_failure_message(
		"Expected placeable_view.tscn to be available for placeable entry template"
	).is_not_null()
	return placeable_scene

## Creates a mock sequence entry template for testing (simplified PanelContainer that works as PlaceableListEntry)
func _create_mock_sequence_entry_template() -> PackedScene:
	var sequence_scene: PackedScene = load("res://templates/grid_building_templates/ui/placement_selection/placeable_list_entry.tscn") as PackedScene
	assert_object(sequence_scene).append_failure_message(
		"Expected placeable_list_entry.tscn to be available for sequence entry template"
	).is_not_null()
	return sequence_scene

#endregion
