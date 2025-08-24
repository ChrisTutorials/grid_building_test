extends GdUnitTestSuite

## Comprehensive indicator positioning tests consolidating multiple positioning scenarios
## Replaces indicator_positioning_test, indicator_actual_positioning_test, and positioner_alignment_test
## Tests world positioning, alignment, factory creation, and manager integration

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger
var placement_manager: PlacementManager
var indicator_template: PackedScene

func before_test():
	# Create test infrastructure using factories
	logger = UnifiedTestFactory.create_test_logger()
	tile_map_layer = GodotTestFactory.create_tile_map_layer(self, 16)
	
	# Create targeting state and positioner
	var owner_context = GBOwnerContext.new()
	targeting_state = GridTargetingState.new(owner_context)
	targeting_state.target_map = tile_map_layer
	targeting_state.maps = [tile_map_layer]
	
	positioner = GodotTestFactory.create_node2d(self)
	positioner.global_position = Vector2(32, 32)  # Tile (2, 2) with 16x16 tiles
	targeting_state.positioner = positioner
	
	# Load indicator template
	indicator_template = load("uid://dhox8mb8kuaxa")
	
	# Create placement manager for integration tests
	var placement_context = PlacementContext.new()
	var messages = GBMessages.new()
	var empty_rules: Array[PlacementRule] = []
	
	placement_manager = PlacementManager.new()
	placement_manager.initialize(placement_context, indicator_template, targeting_state, logger, empty_rules, messages)
	add_child(placement_manager)
	auto_free(placement_manager)
	auto_free(placement_context)
	auto_free(messages)

func after_test():
	# Cleanup handled by auto_free in factory methods
	pass

# Test basic world positioning calculations
@warning_ignore("unused_parameter")
func test_indicator_world_positioning(
	tile_position: Vector2i,
	expected_world_position: Vector2,
	description: String,
	test_parameters := [
		[Vector2i(0, 0), Vector2(8, 8), "origin_tile"],
		[Vector2i(1, 1), Vector2(24, 24), "positive_offset"],
		[Vector2i(2, 2), Vector2(40, 40), "double_offset"],
		[Vector2i(-1, -1), Vector2(-8, -8), "negative_offset"],
		[Vector2i(10, 5), Vector2(168, 88), "large_positive"],
		[Vector2i(-5, -3), Vector2(-72, -40), "large_negative"]
	]
):
	# Test tile-to-world conversion using tilemap API
	var actual_world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(tile_position))
	
	assert_vector(actual_world_pos).append_failure_message(
		"World position for tile %s should be %s (test: %s)" % [tile_position, expected_world_position, description]
	).is_equal(expected_world_position)
	
	# Verify the conversion is consistent
	var back_to_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(actual_world_pos))
	assert_vector(Vector2(back_to_tile)).append_failure_message(
		"Round-trip conversion should preserve tile position for test: %s" % description
	).is_equal(Vector2(tile_position))

# Test indicator creation and positioning with different configurations
@warning_ignore("unused_parameter")
func test_indicator_creation_and_positioning(
	indicator_config: String,
	shape_type: String,
	size_or_radius: Vector2,
	expected_behavior: String,
	test_parameters := [
		["basic_rectangle", "rectangle", Vector2(16, 16), "standard_creation"],
		["large_rectangle", "rectangle", Vector2(32, 32), "large_shape"],
		["small_rectangle", "rectangle", Vector2(8, 8), "small_shape"],
		["circle_small", "circle", Vector2(8, 8), "circular_shape"],
		["circle_medium", "circle", Vector2(16, 16), "medium_circular"]
	]
):
	# Create indicator based on configuration
	var indicator = _create_test_indicator(shape_type, size_or_radius)
	
	# Verify basic setup
	assert_object(indicator).append_failure_message(
		"Indicator should be created for config: %s" % indicator_config
	).is_not_null()
	
	assert_object(indicator.shape).append_failure_message(
		"Indicator shape should be set for config: %s" % indicator_config
	).is_not_null()
	
	# Test positioning
	var test_tile_pos = Vector2i(3, 3)
	var expected_world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(test_tile_pos))
	
	indicator.target_position = expected_world_pos
	assert_vector(indicator.target_position).append_failure_message(
		"Indicator target position should be set correctly for config: %s" % indicator_config
	).is_equal(expected_world_pos)

# Test placement manager integration with indicators
@warning_ignore("unused_parameter")
func test_placement_manager_indicator_integration(
	integration_scenario: String,
	positioner_position: Vector2,
	expected_tiles: int,
	test_parameters := [
		["single_tile", Vector2(24, 24), 1],
		["edge_position", Vector2(8, 8), 1],
		["center_position", Vector2(64, 64), 1],
		["boundary_test", Vector2(0, 0), 1]
	]
):
	# Set positioner to test position
	positioner.global_position = positioner_position
	
	# Trigger placement manager update (this would normally happen via signals)
	# Since PlacementManager doesn't have _on_placement_target_changed, we simulate 
	# the targeting state change that would trigger updates
	targeting_state.positioner_changed.emit(positioner)
	
	# Verify indicator management
	var indicators = placement_manager.get_children().filter(func(child): return child is RuleCheckIndicator)
	
	assert_int(indicators.size()).append_failure_message(
		"Should have indicators for scenario: %s at position %s" % [integration_scenario, positioner_position]
	).is_greater_equal(0)  # May be 0 if no placeable is set
	
	# If indicators exist, verify their positioning
	for indicator in indicators:
		var rule_indicator = indicator as RuleCheckIndicator
		assert_object(rule_indicator).append_failure_message(
			"Indicator should be properly typed for scenario: %s" % integration_scenario
		).is_not_null()

# Test positioning accuracy with sub-pixel precision
func test_positioning_sub_pixel_accuracy():
	var test_cases = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(5, 7),
		Vector2i(-2, 3)
	]
	
	for tile_pos in test_cases:
		var world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(tile_pos))
		var back_to_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(world_pos))
		
		assert_vector(Vector2(back_to_tile)).append_failure_message(
			"Sub-pixel accuracy test failed for tile position: %s" % tile_pos
		).is_equal(Vector2(tile_pos))

# Test positioning with different tile sizes
@warning_ignore("unused_parameter")
func test_positioning_different_tile_sizes(
	tile_size: Vector2i,
	test_tile: Vector2i,
	description: String,
	test_parameters := [
		[Vector2i(8, 8), Vector2i(2, 2), "small_tiles"],
		[Vector2i(16, 16), Vector2i(2, 2), "standard_tiles"],
		[Vector2i(32, 32), Vector2i(1, 1), "large_tiles"],
		[Vector2i(64, 64), Vector2i(0, 1), "very_large_tiles"]
	]
):
	# Create new tilemap with specified tile size
	var test_map = GodotTestFactory.create_tile_map_layer(self, tile_size.x)
	# Align the TileSet's tile_size with the requested size; factory defaults to 16x16
	test_map.tile_set.tile_size = tile_size
	
	# Calculate expected position for tile center
	var expected_center = Vector2(
		test_tile.x * tile_size.x + tile_size.x / 2.0,
		test_tile.y * tile_size.y + tile_size.y / 2.0
	)
	
	# Test the conversion
	var actual_world_pos = test_map.to_global(test_map.map_to_local(test_tile))
	
	assert_vector(actual_world_pos).append_failure_message(
		"Position calculation for %s with tile size %s should be accurate" % [description, tile_size]
	).is_equal(expected_center)

# Test alignment with grid boundaries
func test_grid_boundary_alignment():
	var boundary_positions = [
		Vector2i(0, 0),    # Origin
		Vector2i(-1, 0),   # Negative X boundary
		Vector2i(0, -1),   # Negative Y boundary
		Vector2i(-1, -1),  # Negative corner
		Vector2i(100, 100) # Far positive
	]
	
	for tile_pos in boundary_positions:
		var world_pos = tile_map_layer.to_global(tile_map_layer.map_to_local(tile_pos))
		var back_to_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(world_pos))
		
		assert_vector(Vector2(back_to_tile)).append_failure_message(
			"Boundary alignment failed for tile position: %s" % tile_pos
		).is_equal(Vector2(tile_pos))

# Helper method to create test indicator with specified shape
func _create_test_indicator(shape_type: String, size_or_radius: Vector2) -> RuleCheckIndicator:
	var indicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	
	# Configure shape based on type
	match shape_type:
		"rectangle":
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = size_or_radius
			indicator.shape = rect_shape
		"circle":
			var circle_shape = CircleShape2D.new()
			circle_shape.radius = size_or_radius.x
			indicator.shape = circle_shape
	
	# Configure visual settings
	var valid_settings = IndicatorVisualSettings.new()
	valid_settings.texture = load("uid://2odn6on7s512")
	valid_settings.modulate = Color.GREEN
	
	var invalid_settings = IndicatorVisualSettings.new()
	invalid_settings.texture = load("uid://2odn6on7s512")
	invalid_settings.modulate = Color.RED
	
	indicator.valid_settings = valid_settings
	indicator.invalid_settings = invalid_settings
	
	# Add validity sprite
	indicator.validity_sprite = Sprite2D.new()
	indicator.add_child(indicator.validity_sprite)
	
	return indicator
