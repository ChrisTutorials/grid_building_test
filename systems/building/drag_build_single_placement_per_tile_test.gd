extends GdUnitTestSuite

## Regression test for drag building issue where multiple objects can be placed on the same tile
## when a placeable has no placement rules (no CollisionsCheckRule or TileCheckRule).
## Expected behavior: Only one placement attempt per tile switch, even without rules.

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _container: GBCompositionContainer
var building_system: BuildingSystem
var targeting_system: GridTargetingSystem
var positioner: Node2D
var tile_map_layer: TileMapLayer
var placed_parent: Node2D

# Track successful placements for verification
var placement_count: int = 0
var placed_positions: Array[Vector2] = []

func before_test():
	_container = BASE_CONTAINER.duplicate(true)
	placement_count = 0
	placed_positions.clear()
	
	# Create tile map
	tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-5, 6):
		for y in range(-5, 6):
			tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	add_child(tile_map_layer)
	
	# Positioner
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	
	# Set up targeting state
	var targeting_state = _container.get_states().targeting
	targeting_state.set_map_objects(tile_map_layer, [tile_map_layer])
	targeting_state.positioner = positioner
	
	# Set up manipulation parent
	_container.get_states().manipulation.parent = positioner
	
	# Set up owner context
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var owner_node = auto_free(Node2D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	var gb_owner := GBOwner.new(owner_node)
	auto_free(gb_owner)
	owner_context.set_owner(gb_owner)
	
	# Set up placed parent
	placed_parent = auto_free(Node2D.new())
	_container.get_states().building.placed_parent = placed_parent
	add_child(placed_parent)
	
	# Create building system with drag building enabled
	_container.config.settings.building.drag_multi_build = true
	
	# Ensure placement manager exists BEFORE creating building system
	if _container.get_contexts().placement.get_manager() == null:
		var pm := PlacementManager.create_with_injection(_container)
		add_child(auto_free(pm))
	
	building_system = auto_free(BuildingSystem.new())
	add_child(building_system)
	building_system.resolve_gb_dependencies(_container)
	
	# Create targeting system
	targeting_system = auto_free(GridTargetingSystem.new())
	add_child(targeting_system)
	targeting_system.resolve_gb_dependencies(_container)
	
	# Connect to build success signal to track placements
	building_system.get_building_state().success.connect(_on_build_success)
	
	# Validate setup
	assert_array(building_system.get_dependency_issues()).append_failure_message(
		"Building system dependencies not properly set up"
	).is_empty()

func _on_build_success(build_action_data: BuildActionData):
	placement_count += 1
	if build_action_data.placed:
		placed_positions.append(build_action_data.placed.global_position)

func _create_placeable_with_no_rules() -> Placeable:
	"""Create a simple placeable with no placement rules to test the issue"""
	# Create a simple Node2D scene
	var simple_node = Node2D.new()
	simple_node.name = "SimpleBox"
	
	# Create PackedScene and pack the node
	var packed_scene = PackedScene.new()
	packed_scene.pack(simple_node)
	
	# Create placeable with NO rules - this is the key to the test
	var placeable = Placeable.new(packed_scene, [])  # Empty rules array
	placeable.display_name = "No Rules Box"
	
	# Clean up the temporary node
	simple_node.queue_free()
	
	return placeable

func test_drag_build_single_placement_per_tile_with_no_rules():
	"""
	FAILING TEST: Demonstrates that drag building can place multiple objects on same tile
	when placeable has no rules. Should only place one object per tile switch.
	"""
	var placeable = _create_placeable_with_no_rules()
	
	# Enter build mode
	building_system.selected_placeable = placeable
	var entered = building_system.enter_build_mode(placeable)
	assert_bool(entered).is_true()
	
	# Position at tile (0, 0)
	positioner.global_position = Vector2.ZERO
	targeting_system._process(0.0)  # Force targeting update
	
	# Start drag building
	building_system._start_drag()
	
	# First placement: Simulate drag targeting to tile (0, 0)
	var target_tile = Vector2i(0, 0)
	var old_tile = Vector2i(-1, -1)  # Previous tile (different)
	var targeting_state = _container.get_states().targeting
	var drag_data = DragPathData.new(positioner, targeting_state)
	building_system._on_drag_targeting_new_tile(drag_data, target_tile, old_tile)
	
	# Should have placed one object
	assert_int(placement_count).is_equal(1)
	
	# Second attempt: Simulate targeting the SAME tile again
	# This should NOT create another object since we haven't moved to a new tile
	building_system._on_drag_targeting_new_tile(drag_data, target_tile, target_tile)
	
	# REGRESSION TEST: Currently this will place another object, but it shouldn't
	# Expected: No additional placement should occur
	# Actual: Additional placement occurs, creating multiple objects on same tile
	
	# THIS IS THE FAILING ASSERTION - it will fail until we fix the issue
	if placement_count > 1:
		assert_that("REGRESSION").append_failure_message(
			"REGRESSION: Multiple objects placed on same tile during drag build. " +
			"Expected: no placement on same tile. " +
			"Actual placement count: %d, positions: %s" % [placement_count, placed_positions]
		).is_null()
	
	# Additional verification: should only have 1 placement total
	assert_int(placement_count).append_failure_message(
		"Expected only 1 placement per tile, got %d placements at positions: %s" % [placement_count, placed_positions]
	).is_equal(1)

func test_drag_build_allows_placement_after_tile_switch():
	"""
	Verify that after moving to a different tile, placement should be allowed again
	"""
	var placeable = _create_placeable_with_no_rules()
	
	# Enter build mode and start drag
	building_system.selected_placeable = placeable
	building_system.enter_build_mode(placeable)
	building_system._start_drag()
	
	# First placement at tile (0, 0)
	var targeting_state = _container.get_states().targeting
	var drag_data = DragPathData.new(positioner, targeting_state)
	var first_tile = Vector2i(0, 0)
	var old_tile = Vector2i(-1, -1)
	building_system._on_drag_targeting_new_tile(drag_data, first_tile, old_tile)
	
	# Should have 1 placement
	assert_int(placement_count).is_equal(1)
	
	# Switch to different tile (1, 0) - this should allow another placement
	var second_tile = Vector2i(1, 0)
	building_system._on_drag_targeting_new_tile(drag_data, second_tile, first_tile)
	
	# This should succeed since we moved to a different tile
	assert_int(placement_count).is_equal(2)
	
	# Should have 2 placements at different positions
	if placed_positions.size() >= 2:
		assert_that(placed_positions[0]).is_not_equal(placed_positions[1])
	
	# Move back to original tile (0, 0) - should allow placement again
	building_system._on_drag_targeting_new_tile(drag_data, first_tile, second_tile)
	
	# This should succeed since we're revisiting a previously visited tile
	assert_int(placement_count).is_equal(3)
	
	# Should have 3 placements total
	assert_int(placement_count).is_equal(3)
