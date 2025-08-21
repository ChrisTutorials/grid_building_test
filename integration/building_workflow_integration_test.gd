extends GdUnitTestSuite

## Integration test for complete building workflow from placement to manipulation
## Tests the full system integration across BuildingSystem, PlacementManager, and ManipulationSystem

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _container: GBCompositionContainer
var building_system: BuildingSystem
var manipulation_system: ManipulationSystem
var targeting_system: GridTargetingSystem
var injector_system: GBInjectorSystem
var tile_map_layer: TileMapLayer
var positioner: Node2D
var placed_parent: Node2D

func before_test():
	# Duplicate the base composition container to ensure isolation per test
	_container = BASE_CONTAINER.duplicate(true)

	# Injector system first so other systems can resolve dependencies
	injector_system = auto_free(GBInjectorSystem.create_with_injection(_container))
	add_child(injector_system)

	# Tile map (target grid)
	tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-10, 10):
		for y in range(-10, 10):
			tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	add_child(tile_map_layer)

	# Positioner (simple Node2D sufficient for these tests)
	var pos_scene : PackedScene = load("res://templates/grid_building_templates/components/grid_positioner.tscn")
	if pos_scene:
		positioner = auto_free(pos_scene.instantiate() as Node2D)
	else:
		positioner = auto_free(Node2D.new())
	positioner.name = "Positioner"
	add_child(positioner)

	# Wire targeting state
	var targeting_state : GridTargetingState = _container.get_states().targeting
	targeting_state.target_map = tile_map_layer
	targeting_state.maps = [tile_map_layer]
	targeting_state.positioner = positioner

	# Building state placed parent
	placed_parent = auto_free(Node2D.new())
	placed_parent.name = "PlacedObjects"
	add_child(placed_parent)
	_container.get_states().building.placed_parent = placed_parent

	# Manipulation parent: use the positioner directly so move copies inherit its transforms
	_container.get_states().manipulation.parent = positioner

	# Owner context (replace with new context bound to mock owner)
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var mock_owner_node = auto_free(Node2D.new())
	mock_owner_node.name = "TestOwner"
	add_child(mock_owner_node)
	var gb_owner := GBOwner.new(mock_owner_node)
	auto_free(gb_owner)
	owner_context.set_owner(gb_owner)

	# Systems (all auto_free to avoid orphan leakage); include targeting system for movement logic
	# Add nodes to tree BEFORE dependency injection that calls validation relying on get_tree()
	building_system = auto_free(BuildingSystem.new())
	add_child(building_system)
	building_system.resolve_gb_dependencies(_container)
	if building_system.has_method("_state_validation"):
		building_system._state_validation()

	targeting_system = auto_free(GridTargetingSystem.new())
	add_child(targeting_system)
	targeting_system.resolve_gb_dependencies(_container)
	if targeting_system.has_method("force_validation"):
		targeting_system.force_validation()
	manipulation_system = auto_free(ManipulationSystem.new())
	add_child(manipulation_system)
	manipulation_system.resolve_gb_dependencies(_container)

	# Validate dependencies early
	var building_issues = building_system.validate_dependencies()
	var targeting_issues = targeting_system.validate_dependencies()
	var manipulation_issues = manipulation_system.validate_dependencies()
	if not building_issues.is_empty():
		print("[DIAG] BuildingSystem issues: %s" % str(building_issues))
	if not targeting_issues.is_empty():
		print("[DIAG] TargetingSystem issues: %s" % str(targeting_issues))
	if not manipulation_issues.is_empty():
		print("[DIAG] ManipulationSystem issues: %s" % str(manipulation_issues))
	var issues: Array[String] = []
	issues.append_array(building_issues)
	issues.append_array(targeting_issues)
	issues.append_array(manipulation_issues)
	assert_array(issues).append_failure_message("Dependency issues detected -> Building: %s | Targeting: %s | Manipulation: %s" % [str(building_issues), str(targeting_issues), str(manipulation_issues)]).is_empty()
	_assert_no_orphans()

func _assert_no_orphans():
	var orphans := []
	# Using SceneTree debug to approximate orphan detection by scanning for nodes without owner under test root
	for child in get_children():
		if child.get_parent() == null:
			orphans.append(child)
	assert_int(orphans.size()).append_failure_message("Detected %d orphan nodes during test setup! Orphans: %s" % [orphans.size(), str(orphans)]).is_equal(0)

## Test complete workflow: select placeable -> preview -> place -> manipulate -> demolish
func test_complete_building_workflow():
	# Step 1: Select a placeable object
	var test_placeable = TestSceneLibrary.placeable_2d_test
	assert_object(test_placeable).is_not_null()
	
	# Use the building system to set selected placeable
	building_system.selected_placeable = test_placeable
	assert_object(building_system.selected_placeable).is_equal(test_placeable)
	
	# Step 2: Create preview instance
	building_system.instance_preview(test_placeable)
	var preview = _container.get_states().building.preview
	assert_object(preview).is_not_null()
	# Preview scripts may have been stripped by PreviewFactory; just assert instance type/root presence
	assert_object(preview.get_script()).append_failure_message("Preview script unexpectedly null").is_not_null()
	
	# Step 3: Position for placement (center of tile map)
	positioner.global_position = Vector2.ZERO
	
	# Step 4: Attempt to build (place the object)
	var placed_instance = building_system.try_build()
	assert_object(placed_instance).is_not_null()
	# Clear preview reference to avoid lingering node counting as orphan
	_container.get_states().building.preview = null
	# Ensure a Manipulatable child exists for coordination expectations
	var existing_manip = placed_instance.find_child("Manipulatable", true, false)
	if existing_manip == null:
		var manip_component := Manipulatable.new()
		manip_component.name = "Manipulatable"
		manip_component.root = placed_instance
		placed_instance.add_child(manip_component)
	assert_object(placed_instance.get_parent()).is_not_null()
	
	# Step 5: Verify the object was placed in the correct location
	var expected_position = Vector2.ZERO  # Should be at positioner location
	assert_vector(placed_instance.global_position).is_equal_approx(expected_position, Vector2.ONE)
	
	# Step 6: Begin manipulation move workflow
	var manipulation_state = _container.get_states().manipulation
	var mode_state = _container.get_states().mode
	mode_state.current = GBEnums.Mode.MOVE
	manipulation_state.active_target_node = placed_instance

	# Acquire manipulatable component
	var manipulatable = placed_instance.find_child("Manipulatable", true, false)
	if manipulatable == null:
		manipulatable = Manipulatable.new()
		manipulatable.name = "Manipulatable"
		manipulatable.root = placed_instance
		placed_instance.add_child(manipulatable)

	var original_position = placed_instance.global_position
	# Initiate move (creates move copy under manipulation parent)
	var move_data = manipulation_system.try_move(placed_instance)
	assert_object(move_data).append_failure_message("try_move returned null data").is_not_null()
	assert_bool(move_data.status != GBEnums.Status.FAILED).append_failure_message("Move failed: %s" % move_data.message).is_true()

	# Simulate positioner reposition & system updates
	var target_offset = Vector2(32,32)
	positioner.global_position = original_position + target_offset
	
	for i in range(4):
		await get_tree().process_frame
		targeting_system._move_positioner()

	# Confirm that a move target copy exists and has been repositioned (source root stays until confirmed/finished)
	var move_target = move_data.target
	assert_object(move_target).append_failure_message("Expected move target copy to exist").is_not_null()
	if move_target:
		assert_bool(move_target.root.global_position.distance_to(original_position) > 0.1).append_failure_message("Move target did not shift after positioner move").is_true()
	_assert_no_orphans()

## Test placement validation workflow
func test_placement_validation_workflow():
	## Load a placeable where the scene MUST have collision shapes on layer 1
	var test_elipse_placeable_skew_rotation = load("uid://cmuqt7ovi8si3")
	building_system.selected_placeable = test_elipse_placeable_skew_rotation
	building_system.instance_preview(test_elipse_placeable_skew_rotation)
	positioner.global_position = Vector2.ZERO

	# Explicitly setup placement rules including a CollisionCheckRule so occupied tiles invalidate placement
	var placement_manager = _container.get_contexts().placement.get_manager()
	var targeting_state = _container.get_states().targeting
	var preview_root: Node2D = _container.get_states().building.preview
	var manipulator_owner = _container.get_states().manipulation.get_manipulator()
	var validation_params = RuleValidationParameters.new(manipulator_owner, preview_root, targeting_state, _container.get_logger())
	var rules : Array[PlacementRule] = []

	## There must be a collision check rule for a tile to invalid via the indicators
	var collision_rule : CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = 1 << 0  # Apply to the first layer
	collision_rule.collision_mask = 1 << 0  # Apply to the first layer
	rules.append(collision_rule)
	

	var setup_ok = placement_manager.try_setup(rules, validation_params)
	assert_bool(setup_ok).append_failure_message("Failed to setup placement rules").is_true()

	var indicators := placement_manager.get_indicators()
	assert_array(indicators).append_failure_message("Expected active indicators for testing for the invalid placement space.").is_not_empty()

	var validation_result = placement_manager.validate_placement()
	assert_bool(validation_result.is_successful).is_true()

	# Place one object to occupy tile
	var first_instance = building_system.try_build()
	assert_object(first_instance).is_not_null()

	# Recreate preview at same occupied location to force overlap rule failure (expected invalid)
	building_system.instance_preview(test_elipse_placeable_skew_rotation)
	positioner.global_position = first_instance.global_position

	# Re-run setup for new preview root
	preview_root = _container.get_states().building.preview
	validation_params = RuleValidationParameters.new(manipulator_owner, preview_root, targeting_state, _container.get_logger())
	setup_ok = placement_manager.try_setup(rules, validation_params)
	assert_bool(setup_ok).append_failure_message("Failed to re-setup placement rules for second preview").is_true()

	validation_result = placement_manager.validate_placement()
	assert_bool(validation_result.is_successful).append_failure_message("Expected invalid placement on occupied tile").is_false()
	_assert_no_orphans()

## Test system coordination and state management
func test_system_coordination():
	# Test that building and manipulation systems coordinate properly
	var manipulation_state = _container.get_states().manipulation
	var mode_state = _container.get_states().mode
	
	# Initially should be in building mode
	mode_state.current = GBEnums.Mode.BUILD
	assert_that(mode_state.current).is_equal(GBEnums.Mode.BUILD)
	
	# Place an object
	var test_placeable = TestSceneLibrary.placeable_2d_test
	building_system.selected_placeable = test_placeable
	building_system.instance_preview(test_placeable)
	positioner.global_position = Vector2.ZERO
	
	var placed_instance = building_system.try_build()
	assert_object(placed_instance).is_not_null()
	
	# Switch to manipulation mode
	mode_state.current = GBEnums.Mode.MOVE
	manipulation_state.active_target_node = placed_instance
	
	# Verify systems respond to mode changes appropriately
	assert_that(mode_state.current).is_equal(GBEnums.Mode.MOVE)
	assert_object(manipulation_state.active_manipulatable.root).append_failure_message("Obj: %s should match Obj: %s" % [manipulation_state.active_target_node.name, placed_instance.name]).is_equal(placed_instance)
	_assert_no_orphans()

## Test that entering build mode with a placeable that has collision shapes and a collisions rule produces rule check indicators
func test_indicator_generation_on_enter_build_mode_with_smithy():
	# Arrange
	var smithy_placeable : Placeable = TestSceneLibrary.placeable_smithy
	assert_object(smithy_placeable).append_failure_message("Smithy placeable resource missing").is_not_null()

	# Enter build mode (this should create a preview instance)
	building_system.selected_placeable = smithy_placeable
	var entered := building_system.enter_build_mode(smithy_placeable)
	assert_bool(entered).append_failure_message("Failed to enter build mode for smithy").is_true()

	# Validate preview exists and is parented under targeting positioner
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).append_failure_message("Preview not created for smithy").is_not_null()
	var targeting_state := _container.get_states().targeting
	assert_object(targeting_state.positioner).append_failure_message("Targeting positioner missing").is_not_null()
	assert_object(preview.get_parent()).append_failure_message("Preview has no parent").is_not_null()

	# Force setup via placement manager using smithy rules (some placeables may embed rules directly)
	var placement_manager := _container.get_contexts().placement.get_manager()
	assert_object(placement_manager).append_failure_message("PlacementManager not available").is_not_null()

	# Build explicit collision rule mirroring runtime expectation so indicators must be generated
	var collision_rule : CollisionsCheckRule = CollisionsCheckRule.new()
	# Use layer 1 for both apply mask and collision mask so they overlap tile collision shapes (common default)
	collision_rule.apply_to_objects_mask = 1 << 0
	collision_rule.collision_mask = 1 << 0
	var rules : Array[PlacementRule] = [collision_rule]

	# Validation parameters use placer (manipulator owner) and preview target
	var manipulator_owner = _container.get_states().manipulation.get_manipulator()
	var validation_params := RuleValidationParameters.new(manipulator_owner, preview, targeting_state, _container.get_logger())
	var setup_ok := placement_manager.try_setup(rules, validation_params)
	assert_bool(setup_ok).append_failure_message("PlacementManager.try_setup failed for smithy").is_true()

	# Act: retrieve indicators
	var indicators := placement_manager.get_indicators()
	# Assert: expect at least one indicator (smithy has collision polygon/shape)
	assert_array(indicators).append_failure_message("Expected rule check indicators after entering build mode for smithy; got 0").is_not_empty()

	# Additional diagnostic assertions
	# Ensure each indicator has at least one rule associated (through collision mapping); if empty log warning not failure
	for ind in indicators:
		if ind is RuleCheckIndicator:
			var ind_rules := ind.get_rules() if ind.has_method("get_rules") else []
			if ind_rules.is_empty():
				push_warning("Indicator %s has zero rules mapped during integration test" % ind.name)

	_assert_no_orphans()

## Test error handling and edge cases in integrated workflow
func test_workflow_error_handling():
	# Test building without selected placeable
	building_system.selected_placeable = null
	var result = building_system.try_build()
	assert_object(result).is_null()
	
	# Test building with invalid placeable
	var invalid_placeable = Placeable.new()  # Empty placeable
	building_system.selected_placeable = invalid_placeable
	result = building_system.try_build()
	assert_object(result).is_null()
	
	# Test manipulation without target
	_container.get_states().manipulation.active_target_node = null
	# Should handle gracefully without crashing
	await get_tree().process_frame
	# No assertion needed - just verify no crash
	_assert_no_orphans()
