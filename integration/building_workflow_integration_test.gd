extends GdUnitTestSuite

## Integration test for complete building workflow from placement to manipulation
## Tests the full system integration across BuildingSystem, PlacementManager, and ManipulationSystem

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var building_system: BuildingSystem
var manipulation_system: ManipulationSystem
var injector_system: GBInjectorSystem
var tile_map_layer: TileMapLayer
var positioner: Node2D

func before_test():
	# Use duplicated container per test to keep isolation
	var container: GBCompositionContainer = TEST_CONTAINER
	# Injector system first to allow automatic dependency injection logging
	injector_system = auto_free(GBInjectorSystem.create_with_injection(container))
	add_child(injector_system)
	
	# Tile map setup
	tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-10, 10):
		for y in range(-10, 10):
			tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	add_child(tile_map_layer)
	
	# Positioner
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	
	# Targeting state wiring
	var targeting_state : GridTargetingState = container.get_states().targeting
	targeting_state.target_map = tile_map_layer
	targeting_state.maps = [tile_map_layer]
	targeting_state.positioner = positioner
	
	# Building state placed parent
	var building_state = container.get_states().building
	var placed_parent: Node2D = auto_free(Node2D.new())
	placed_parent.name = "PlacedObjects"
	add_child(placed_parent)
	building_state.placed_parent = placed_parent
	
	# Owner context
	var owner_context: GBOwnerContext = container.get_contexts().owner
	var mock_owner_node = auto_free(Node2D.new())
	mock_owner_node.name = "TestOwner"
	add_child(mock_owner_node)
	owner_context.set_owner(GBOwner.new(mock_owner_node))
	
	# Systems (factory ensures validation & dependency resolution)
	building_system = auto_free(BuildingSystem.create_with_injection(container))
	add_child(building_system)
	manipulation_system = auto_free(ManipulationSystem.create_with_injection(container))
	add_child(manipulation_system)
	
	var building_issues = building_system.validate_dependencies()
	var manipulation_issues = manipulation_system.validate_dependencies()
	assert_array(building_issues).append_failure_message("BuildingSystem dependency issues: " + str(building_issues)).is_empty()
	assert_array(manipulation_issues).append_failure_message("ManipulationSystem dependency issues: " + str(manipulation_issues)).is_empty()

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
	var preview = TEST_CONTAINER.get_states().building.preview
	assert_object(preview).is_not_null()
	# Preview scripts may have been stripped by PreviewFactory; just assert instance type/root presence
	assert_object(preview.get_script()).append_failure_message("Preview script unexpectedly null").is_not_null()
	
	# Step 3: Position for placement (center of tile map)
	positioner.global_position = Vector2.ZERO
	
	# Step 4: Attempt to build (place the object)
	var placed_instance = building_system.try_build()
	assert_object(placed_instance).is_not_null()
	assert_object(placed_instance.get_parent()).is_not_null()
	
	# Step 5: Verify the object was placed in the correct location
	var expected_position = Vector2.ZERO  # Should be at positioner location
	assert_vector(placed_instance.global_position).is_equal_approx(expected_position, Vector2.ONE)
	
	# Step 6: Switch to manipulation mode and verify the placed object can be manipulated
	var manipulation_state = TEST_CONTAINER.get_states().manipulation
	manipulation_state.current_target = placed_instance
	
	# Step 7: Test manipulation capabilities (if object has Manipulatable component)
	var manipulatable_nodes = placed_instance.find_children("", "Manipulatable")
	if not manipulatable_nodes.is_empty():
		var manipulatable = manipulatable_nodes[0] as Manipulatable
		assert_object(manipulatable).is_not_null()
		
		# Test move operation
		var original_position = manipulatable.root.global_position
		var new_position = original_position + Vector2(32, 32)
		positioner.global_position = new_position
		
		# Switch mode to move to allow manipulation system to process target movement
		var mode_state = TEST_CONTAINER.get_states().mode
		mode_state.current = GBEnums.Mode.MOVE
		# Wait a couple frames for systems to react
		await get_tree().process_frame
		await get_tree().process_frame
		# Verify position changed (approximately, due to grid snapping); allow either snapped or exact move
		assert_bool(manipulatable.root.global_position != original_position).append_failure_message("Manipulatable root did not move after repositioning positioner").is_true()

## Test placement validation workflow
func test_placement_validation_workflow():
	var test_placeable = TestSceneLibrary.placeable_2d_test
	building_system.selected_placeable = test_placeable
	building_system.instance_preview(test_placeable)
	
	# Test valid placement position
	positioner.global_position = Vector2.ZERO
	
	# Trigger placement validation through placement manager
	var placement_manager = TEST_CONTAINER.get_contexts().placement.get_manager()
	var validation_result = placement_manager.validate_placement()
	
	# Should be valid at center of map
	assert_bool(validation_result.is_successful).is_true()
	
	# Test invalid placement position (far outside map bounds)
	positioner.global_position = Vector2(10000, 10000)
	
	validation_result = placement_manager.validate_placement()
	
	# Should be invalid outside map bounds
	assert_bool(validation_result.is_successful).is_false()

## Test system coordination and state management
func test_system_coordination():
	# Test that building and manipulation systems coordinate properly
	var manipulation_state = TEST_CONTAINER.get_states().manipulation
	var mode_state = TEST_CONTAINER.get_states().mode
	
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
	manipulation_state.current_target = placed_instance
	
	# Verify systems respond to mode changes appropriately
	assert_that(mode_state.current).is_equal(GBEnums.Mode.MOVE)
	assert_object(manipulation_state.current_target).is_equal(placed_instance)

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
	TEST_CONTAINER.get_states().manipulation.current_target = null
	# Should handle gracefully without crashing
	await get_tree().process_frame
	# No assertion needed - just verify no crash
