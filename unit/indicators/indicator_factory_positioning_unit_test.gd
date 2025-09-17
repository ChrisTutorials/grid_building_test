## Unit tests for IndicatorFactory positioning logic
## Tests coordinate transformation, parent-child relationships, and grid distribution
## to debug indicator clustering vs proper distribution issues
extends GdUnitTestSuite

# Test constants matching GBTestConstants but for isolated testing
const TILE_SIZE: Vector2 = Vector2(16, 16)
const TEST_POSITIONS: Array[Vector2i] = [
	Vector2i(0, 0),   # Center
	Vector2i(1, 0),   # Right
	Vector2i(0, 1),   # Down
	Vector2i(-1, 0),  # Left
	Vector2i(0, -1),  # Up
	Vector2i(1, 1),   # Diagonal
	Vector2i(-1, -1)  # Opposite diagonal
]

# Test environment components
var _tile_map: TileMapLayer
var _tile_set: TileSet
var _targeting_state: GridTargetingState
var _positioner: Node2D
var _parent_node: Node2D
var _indicator_template: PackedScene
var _test_object: Node2D

func before_test() -> void:
	# Create minimal tile map setup
	_tile_set = TileSet.new()
	_tile_set.tile_size = TILE_SIZE
	
	_tile_map = auto_free(TileMapLayer.new())
	add_child(_tile_map)
	_tile_map.tile_set = _tile_set
	
	# Create positioner at specific location for predictable testing
	_positioner = auto_free(Node2D.new())
	add_child(_positioner)
	_positioner.global_position = Vector2(64, 48)  # Position at tile (4, 3) for non-zero baseline
	
	# Create targeting state - requires GBOwnerContext for constructor
	var owner_context: GBOwnerContext = GBOwnerContext.new()
	_targeting_state = GridTargetingState.new(owner_context)
	_targeting_state.target_map = _tile_map
	_targeting_state.maps = [_tile_map]
	_targeting_state.positioner = _positioner
	
	# Create parent node for indicators
	_parent_node = auto_free(Node2D.new())
	add_child(_parent_node)
	
	# Create test object for positioning relative to
	_test_object = auto_free(Node2D.new())
	add_child(_test_object)
	_test_object.global_position = Vector2(80, 80)  # Position at a known location
	
	# Load indicator template from correct path
	_indicator_template = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	
	# Validate setup
	assert_that(_indicator_template).append_failure_message("Failed to load indicator template").is_not_null()
	assert_that(_tile_map.tile_set).append_failure_message("TileSet not properly assigned").is_not_null()

func test_coordinate_transformation_pipeline() -> void:
	# Test the key positioning calculation from IndicatorFactory.generate_indicators()
	var test_position: Vector2i = Vector2i(2, -1)  # Arbitrary offset
	
	# Step 1: Calculate positioner tile position
	var positioner_tile: Vector2i = _tile_map.local_to_map(_tile_map.to_local(_positioner.global_position))
	
	# Step 2: Calculate target tile by adding offset
	var target_tile: Vector2i = positioner_tile + test_position
	
	# Step 3: Convert back to world coordinates
	var expected_global_pos: Vector2 = _tile_map.to_global(_tile_map.map_to_local(target_tile))
	
	# Verify each step produces reasonable results
	assert_that(positioner_tile).append_failure_message("Positioner tile calculation failed").is_not_null()
	assert_that(target_tile).append_failure_message("Target tile calculation failed").is_not_null()
	assert_that(expected_global_pos).append_failure_message("Global position calculation failed").is_not_null()
	
	# Verify the offset was applied correctly
	var expected_target: Vector2i = positioner_tile + test_position
	assert_that(target_tile).append_failure_message(
		"Target tile should equal positioner_tile + offset: %s + %s = %s, got %s" % [positioner_tile, test_position, expected_target, target_tile]
	).is_equal(expected_target)
	
	# Verify global position is different from positioner position (not clustered at origin)
	var distance_from_positioner: float = expected_global_pos.distance_to(_positioner.global_position)
	assert_that(distance_from_positioner).append_failure_message(
		"Expected global position %s should be different from positioner position %s (distance: %f)" % [expected_global_pos, _positioner.global_position, distance_from_positioner]
	).is_greater(0.1)

func test_generate_indicators_positions_correctly() -> void:
	# Create position rules map with multiple positions
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	for pos in TEST_POSITIONS:
		position_rules_map[pos] = []  # Empty rules array for positioning test
	
	# Generate indicators
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	# Verify correct number of indicators created
	assert_that(indicators.size()).append_failure_message(
		"Expected %d indicators for %d positions" % [TEST_POSITIONS.size(), TEST_POSITIONS.size()]
	).is_equal(TEST_POSITIONS.size())
	
	# Collect actual positions for analysis
	var indicator_positions: Array[Vector2] = []
	for indicator in indicators:
		indicator_positions.append(indicator.global_position)
	
	# Verify indicators are not clustered at same position
	_verify_indicators_not_clustered(indicator_positions)
	
	# Verify indicators are properly distributed
	_verify_indicators_distributed_on_grid(indicators, TEST_POSITIONS)

func test_positioner_position_affects_indicator_positions() -> void:
	# Test with positioner at origin
	_positioner.global_position = Vector2.ZERO
	var position_at_origin: Vector2i = Vector2i(1, 1)
	var position_rules_map_origin: Dictionary[Vector2i, Array] = {position_at_origin: []}
	
	var indicators_at_origin: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map_origin,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	var origin_indicator_pos: Vector2 = indicators_at_origin[0].global_position if indicators_at_origin.size() > 0 else Vector2.ZERO
	
	# Move positioner to different location
	_positioner.global_position = Vector2(100, 100)
	var indicators_at_offset: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map_origin,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	var offset_indicator_pos: Vector2 = indicators_at_offset[0].global_position if indicators_at_offset.size() > 0 else Vector2.ZERO
	
	# Verify positions are different (not clustered)
	var position_difference: float = origin_indicator_pos.distance_to(offset_indicator_pos)
	assert_that(position_difference).append_failure_message(
		"Indicator positions should change when positioner moves: origin=%s, offset=%s, difference=%f" % [origin_indicator_pos, offset_indicator_pos, position_difference]
	).is_greater(10.0)  # Should be significantly different

func test_indicators_use_global_positioning() -> void:
	# Test that indicators use global_position correctly, not relative positioning that could cause clustering
	var test_positions: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 2)]
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	for pos in test_positions:
		position_rules_map[pos] = []
	
	# Generate indicators
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	assert_that(indicators.size()).is_equal(2)
	
	# Verify indicators have different global positions
	var pos1: Vector2 = indicators[0].global_position
	var pos2: Vector2 = indicators[1].global_position
	
	assert_that(pos1).append_failure_message(
		"First indicator should have valid global position"
	).is_not_equal(Vector2.ZERO)
	
	assert_that(pos2).append_failure_message(
		"Second indicator should have valid global position"
	).is_not_equal(Vector2.ZERO)
	
	assert_that(pos1.distance_to(pos2)).append_failure_message(
		"Indicators should be positioned at different locations: pos1=%s, pos2=%s" % [pos1, pos2]
	).is_greater(TILE_SIZE.x)  # Should be at least one tile apart

func test_parent_transforms_do_not_interfere() -> void:
	# Apply transform to parent node to test if it interferes with indicator positioning
	_parent_node.position = Vector2(50, 25)
	_parent_node.rotation = 0.5
	_parent_node.scale = Vector2(1.2, 1.2)
	
	var test_position: Vector2i = Vector2i(1, 0)
	var position_rules_map: Dictionary[Vector2i, Array] = {test_position: []}
	
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	assert_that(indicators.size()).is_equal(1)
	
	# Calculate expected position based on tile grid, ignoring parent transform
	var positioner_tile: Vector2i = _tile_map.local_to_map(_tile_map.to_local(_positioner.global_position))
	var target_tile: Vector2i = positioner_tile + test_position
	var expected_global_pos: Vector2 = _tile_map.to_global(_tile_map.map_to_local(target_tile))
	
	var actual_global_pos: Vector2 = indicators[0].global_position
	var position_error: float = expected_global_pos.distance_to(actual_global_pos)
	
	# The global_position should match expected regardless of parent transform
	assert_that(position_error).append_failure_message(
		"Indicator global_position should not be affected by parent transform: expected=%s, actual=%s, error=%f" % [expected_global_pos, actual_global_pos, position_error]
	).is_less(1.0)  # Allow small floating point error

# Helper methods for validation

func _verify_indicators_not_clustered(positions: Array[Vector2]) -> void:
	# Check that no two indicators are at the same position (clustering)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var distance: float = positions[i].distance_to(positions[j])
			assert_that(distance).append_failure_message(
				"Indicators should not cluster: position[%d]=%s, position[%d]=%s, distance=%f" % [i, positions[i], j, positions[j], distance]
			).is_greater(1.0)  # Should be more than 1 pixel apart

func _verify_indicators_distributed_on_grid(indicators: Array[RuleCheckIndicator], expected_positions: Array[Vector2i]) -> void:
	# Verify that indicators are positioned according to expected grid offsets
	var positioner_tile: Vector2i = _tile_map.local_to_map(_tile_map.to_local(_positioner.global_position))
	
	for i in range(indicators.size()):
		var indicator: RuleCheckIndicator = indicators[i]
		var expected_offset: Vector2i = expected_positions[i]
		var expected_tile: Vector2i = positioner_tile + expected_offset
		var expected_world_pos: Vector2 = _tile_map.to_global(_tile_map.map_to_local(expected_tile))
		
		var actual_pos: Vector2 = indicator.global_position
		var position_error: float = expected_world_pos.distance_to(actual_pos)
		
		assert_that(position_error).append_failure_message(
			"Indicator %d should be at grid position: expected_offset=%s, expected_tile=%s, expected_world=%s, actual=%s, error=%f" % [i, expected_offset, expected_tile, expected_world_pos, actual_pos, position_error]
		).is_less(2.0)  # Allow small error for floating point precision

# REGRESSION TEST for 800+ pixel offset positioning bug
# Reproduces runtime scene analysis issue where indicators appear at wrong positions
func test_indicator_positioning_regression_800_pixel_offset() -> void:
	# Set test object and positioner at specific coordinates that match runtime analysis
	var expected_pos := Vector2(456.0, 552.0)  # From runtime scene analysis
	_test_object.global_position = expected_pos
	_positioner.global_position = expected_pos
	
	# Create simple single-indicator test
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[Vector2i(0, 0)] = []  # Single indicator at same tile as positioner
	
	# Generate indicator
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	# Validate basic generation
	assert_that(indicators.size()).is_equal(1).append_failure_message("Expected exactly 1 indicator")
	
	var indicator: RuleCheckIndicator = indicators[0]
	var indicator_pos: Vector2 = indicator.global_position
	var distance: float = indicator_pos.distance_to(expected_pos)
	
	# Log detailed positioning data for analysis (matches runtime analysis format)
	print("=== POSITIONING REGRESSION TEST ===")
	print("Distance: %.1f pixels" % distance)
	print("Offset vector: ", indicator_pos - expected_pos)

	assert_vector(expected_pos).append_failure_message("Expected position for indicator").is_equal(indicator_pos)
	
	# Key assertion: This should FAIL if 800+ pixel regression is present
	# If indicators appear at positions like (1272.0, 888.0), the distance will be ~800+ pixels
	assert_that(distance).is_less(100.0).append_failure_message(
		"REGRESSION DETECTED: Indicator positioned at (%s), expected near (%s). " % [indicator_pos, expected_pos] +
		"Distance is %.1f pixels. The 800+ pixel offset regression means indicators appear far from expected positions." % distance
	)

# DEBUG TEST to investigate what position data comes from collision system
func test_debug_collision_position_mapping() -> void:
	# This test simulates the full collision pipeline to see what position offsets are generated
	
	# Set up a realistic scenario matching the runtime environment
	_test_object.global_position = Vector2(456.0, 552.0)  # From runtime analysis
	_positioner.global_position = Vector2(456.0, 552.0)
	
	# Mock a collision position that would cause the 800+ pixel offset
	# From runtime analysis: local position (816.0, 336.0) results in global (1272.0, 888.0)
	# So the offset being passed to IndicatorFactory might be (816/16, 336/16) = (51, 21) tiles
	var suspicious_offset := Vector2i(51, 21)  # This should cause 816+ pixel offset
	
	# Test with the suspicious offset to see if this reproduces the issue
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[suspicious_offset] = []
	
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	assert_that(indicators.size()).is_equal(1)
	
	var indicator: RuleCheckIndicator = indicators[0]
	var expected_pos := Vector2(456.0, 552.0)
	var actual_pos := indicator.global_position
	var distance := actual_pos.distance_to(expected_pos)
	
	print("=== COLLISION POSITION MAPPING DEBUG ===")
	print("Suspicious offset: ", suspicious_offset)
	print("Expected position: ", expected_pos)
	print("Actual position: ", actual_pos)
	print("Distance: %.1f pixels" % distance)
	print("Local position offset: ", actual_pos - expected_pos)
	
	# After the fix, this should no longer create a massive offset
	if distance > 800.0:
		print("REGRESSION STILL PRESENT: Large offset detected - collision system still generating wrong tile positions")
		print("Tile offset %s creates %.1f pixel displacement" % [suspicious_offset, distance])
		assert_that(false).append_failure_message("Fix didn't work - still getting 800+ pixel offsets").is_true()
	else:
		print("POTENTIALLY FIXED: This offset doesn't reproduce the massive displacement issue")
	
	# Test with a small relative offset to ensure normal behavior still works
	var small_offset := Vector2i(1, 0)  # Should create ~16 pixel offset
	var small_position_rules_map: Dictionary[Vector2i, Array] = {}
	small_position_rules_map[small_offset] = []
	
	var small_indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		small_position_rules_map,
		_indicator_template,
		_parent_node,
		_targeting_state,
		_test_object
	)
	
	assert_that(small_indicators.size()).is_equal(1)
	
	var small_indicator := small_indicators[0]
	var small_distance := small_indicator.global_position.distance_to(expected_pos)
	
	print("Small offset test: ", small_offset, " creates ", small_distance, " pixel distance")
	
	# Small offsets should create reasonable distances (~16 pixels for 1 tile)
	assert_that(small_distance).is_greater(10.0).is_less(30.0).append_failure_message(
		"Small offset should create reasonable distance, got %.1f pixels" % small_distance
	)
