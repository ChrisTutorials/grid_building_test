extends GdUnitTestSuite

## Tests that collision detection correctly accounts for collision shape local offsets.
## This ensures indicators appear at the correct positions relative to the actual collision shapes,
## not just the object's root position. Regression test for the positioning offset issue.

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var collision_mapper: CollisionMapper
var targeting_state: GridTargetingState
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	logger = TEST_CONTAINER.get_logger()
	targeting_state = GridTargetingState.new(GBOwnerContext.new())
	collision_mapper = CollisionMapper.new(targeting_state, logger)
	
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2i(16, 16)
	targeting_state.target_map = tile_map_layer
	
	positioner = auto_free(Node2D.new())
	targeting_state.positioner = positioner

func after_test():
	if collision_mapper:
		collision_mapper = null

## Test that CollisionPolygon2D with local offset is positioned correctly
func test_collision_polygon_with_local_offset():
	# Set positioner at a known position
	positioner.global_position = Vector2(100, 100)
	
	# Create a StaticBody2D with CollisionPolygon2D that has a local offset
	var static_body = auto_free(StaticBody2D.new())
	add_child(static_body)
	static_body.collision_layer = 1
	static_body.global_position = Vector2(50, 50)  # Different from positioner
	
	var collision_polygon = CollisionPolygon2D.new()
	static_body.add_child(collision_polygon)
	collision_polygon.position = Vector2(8, -8)  # Local offset like in the real case
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -8), Vector2(16, -8), Vector2(16, 8), Vector2(-16, 8)
	])
	
	# Set up collision mapper
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	collision_object_test_setups[collision_polygon] = null  # CollisionPolygon2D gets null setup
	
	var indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	collision_mapper.setup(indicator, collision_object_test_setups)
	
	# Get collision positions - should be relative to positioner + local offset
	var result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	
	# Verify that collision detection uses positioner position + polygon local offset
	# Expected world position: positioner (100, 100) + polygon offset (8, -8) = (108, 92)
	# The collision should be centered around this position
	assert_int(result.size()).is_greater(0)
	
	# Convert expected world position to tile coordinates
	var expected_world_center = positioner.global_position + collision_polygon.position
	var expected_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(expected_world_center))
	
	# Verify the collision is detected at the correct tile position
	assert_bool(result.has(expected_tile)).append_failure_message(
		"Expected collision at tile %s (world pos %s), but found tiles: %s" % [
			expected_tile, expected_world_center, result.keys()
		]
	).is_true()

## Test that CollisionObject2D shapes with local offsets are positioned correctly
func test_collision_object_with_local_offset():
	# Set positioner at a known position
	positioner.global_position = Vector2(200, 200)
	
	# Create Area2D with CollisionShape2D that has a local offset
	var area_2d = auto_free(Area2D.new())
	add_child(area_2d)
	area_2d.collision_layer = 1
	area_2d.global_position = Vector2(150, 150)  # Different from positioner
	
	var collision_shape = auto_free(CollisionShape2D.new())
	area_2d.add_child(collision_shape)
	collision_shape.position = Vector2(12, -6)  # Local offset
	
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	collision_shape.shape = rect_shape
	
	# Set up collision mapper with test setup
	var test_setup = IndicatorCollisionTestSetup.new(area_2d, Vector2(16, 16), logger)
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	collision_object_test_setups[area_2d] = test_setup
	
	var indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	collision_mapper.setup(indicator, collision_object_test_setups)
	
	# Get collision positions - should be relative to positioner + shape local offset
	var result = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map_layer)
	
	# Verify that collision detection uses positioner position + shape owner local offset
	assert_int(result.size()).is_greater(0)
	
	# The collision should be positioned relative to positioner + collision shape's local offset
	var expected_world_center = positioner.global_position + collision_shape.position
	var expected_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(expected_world_center))
	
	# Verify the collision is detected at the correct tile position
	assert_bool(result.has(expected_tile)).append_failure_message(
		"Expected collision at tile %s (world pos %s), but found tiles: %s" % [
			expected_tile, expected_world_center, result.keys()
		]
	).is_true()

## Test that objects without local offsets still work correctly (regression test)
func test_collision_without_offset_still_works():
	# Set positioner at a known position
	positioner.global_position = Vector2(300, 300)
	
	# Create CollisionPolygon2D without local offset
	var static_body = auto_free(StaticBody2D.new())
	add_child(static_body)
	static_body.collision_layer = 1
	
	var collision_polygon = CollisionPolygon2D.new()
	static_body.add_child(collision_polygon)
	collision_polygon.position = Vector2.ZERO  # No local offset
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	
	# Set up collision mapper
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	collision_object_test_setups[collision_polygon] = null
	
	var indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	collision_mapper.setup(indicator, collision_object_test_setups)
	
	# Get collision positions - should be exactly at positioner position
	var result = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map_layer)
	
	assert_int(result.size()).is_greater(0)
	
	# Expected position is exactly the positioner position (no offset)
	var expected_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(positioner.global_position))
	assert_bool(result.has(expected_tile)).append_failure_message(
		"Expected collision at tile %s (positioner pos %s), but found tiles: %s" % [
			expected_tile, positioner.global_position, result.keys()
		]
	).is_true()

## Test that indicator names are descriptive and useful for debugging
func test_indicator_naming_with_descriptive_debug_info():
	# This test verifies that indicators get meaningful names for debugging
	# Set positioner at a specific position
	positioner.global_position = Vector2(400, 400)
	
	# Create a simple collision object
	var static_body = auto_free(StaticBody2D.new())
	add_child(static_body)
	static_body.collision_layer = 1
	
	var collision_polygon = CollisionPolygon2D.new()
	static_body.add_child(collision_polygon)
	collision_polygon.position = Vector2(10, -5)  # Local offset for testing
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	
	# Set up collision mapper and create indicators through the full system
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	collision_object_test_setups[collision_polygon] = null
	
	var indicator = auto_free(RuleCheckIndicator.new())
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	
	# Use the targeting state's indicator manager to create properly named indicators
	var indicators_parent = auto_free(Node2D.new())
	add_child(indicators_parent)
	var indicator_manager = IndicatorManager.new(indicators_parent, targeting_state, null, logger)
	var test_rule = TileCheckRule.new()
	
	# This should create indicators with descriptive names
	var indicators = indicator_manager.setup_indicators(static_body, [test_rule], self)
	
	# Verify that at least one indicator was created with a descriptive name
	assert_int(indicators.size()).is_greater(0)
	
	for created_indicator in indicators:
		# Check that the name contains useful debug information
		var indicator_name = created_indicator.name
		assert_str(indicator_name).append_failure_message(
			"Indicator name should contain offset from preview object root, got: " + indicator_name
		).contains("Offset(")
		
		# The name should be stable and not contain world coordinates that change with mouse movement
		assert_str(indicator_name).append_failure_message(
			"Indicator name should not contain world position (changes with mouse), got: " + indicator_name
		).does_not_contain("World(")

## Test that oval/circular objects get symmetric indicator distribution
func test_symmetric_indicator_distribution_for_circular_objects():
	# This test ensures that circular/oval collision shapes get equal indicators on both sides
	positioner.global_position = Vector2(500, 500)
	
	# Create a circular Area2D similar to the gigantic egg
	var area_2d = auto_free(Area2D.new())
	add_child(area_2d)
	area_2d.collision_layer = 1
	
	var collision_shape = auto_free(CollisionShape2D.new())
	area_2d.add_child(collision_shape)
	collision_shape.position = Vector2.ZERO  # Centered
	
	# Create an oval shape like the gigantic egg (radius=48, height=128)
	var capsule_shape = CapsuleShape2D.new()
	capsule_shape.radius = 48.0
	capsule_shape.height = 128.0
	collision_shape.shape = capsule_shape
	
	# Set up collision mapper and create indicators
	var indicators_parent = auto_free(Node2D.new())
	add_child(indicators_parent)
	var indicator_manager = IndicatorManager.new(indicators_parent, targeting_state, null, logger)
	var test_rule = TileCheckRule.new()
	
	# Create indicators for the oval
	var indicators = indicator_manager.setup_indicators(area_2d, [test_rule], indicators_parent)
	
	# Analyze indicator distribution
	var left_indicators = 0
	var right_indicators = 0
	var center_indicators = 0
	
	for indicator in indicators:
		var indicator_name = indicator.name
		if indicator_name.begins_with("Offset(-"):
			left_indicators += 1
		elif indicator_name.begins_with("Offset(0,"):
			center_indicators += 1
		elif indicator_name.begins_with("Offset("):  # Positive offsets
			right_indicators += 1
	
	# For a symmetric oval, left and right should be equal (or very close)
	var difference = abs(left_indicators - right_indicators)
	assert_int(difference).append_failure_message(
		"Oval should have symmetric indicator distribution. Left: %d, Right: %d, Center: %d" % [
			left_indicators, right_indicators, center_indicators
		]
	).is_less_equal(1)  # Allow at most 1 indicator difference due to rounding
	
	# Verify we have a reasonable number of indicators (not zero)
	assert_int(indicators.size()).is_greater(10)

## Test that positioner is grid-aligned before collision calculations (prevents asymmetric results)
func test_positioner_grid_alignment_before_collision_calculations():
	# This is the critical test to prevent asymmetric indicator generation
	# The positioner must be properly grid-aligned before collision calculations
	
	# Intentionally set positioner to an off-grid position
	var off_grid_position = Vector2(543.7, 678.3)  # Fractional positioning
	positioner.global_position = off_grid_position
	
	# Create a test object
	var static_body = auto_free(StaticBody2D.new())
	add_child(static_body)
	static_body.collision_layer = 1
	
	var collision_shape = auto_free(CollisionShape2D.new())
	static_body.add_child(collision_shape)
	collision_shape.position = Vector2.ZERO
	
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	collision_shape.shape = rect_shape
	
	# Set up indicator manager
	var indicators_parent = auto_free(Node2D.new())
	add_child(indicators_parent)
	var indicator_manager = IndicatorManager.new(indicators_parent, targeting_state, null, logger)
	var test_rule = TileCheckRule.new()
	
	# Record initial position
	var initial_position = positioner.global_position
	assert_vector(initial_position).is_equal(off_grid_position)
	
	# When indicators are set up, positioner should be automatically grid-aligned
	var indicators = indicator_manager.setup_indicators(static_body, [test_rule], indicators_parent)
	
	# Verify positioner was grid-aligned
	var final_position = positioner.global_position
	var expected_tile = tile_map_layer.local_to_map(tile_map_layer.to_local(off_grid_position))
	var expected_aligned_position = tile_map_layer.to_global(tile_map_layer.map_to_local(expected_tile))
	
	assert_vector(final_position).append_failure_message(
		"Positioner should be grid-aligned. Initial: %s, Final: %s, Expected: %s" % [
			initial_position, final_position, expected_aligned_position
		]
	).is_equal_approx(expected_aligned_position, Vector2(0.1, 0.1))
	
	# Verify indicators were generated (proves the fix works)
	assert_int(indicators.size()).is_greater(0)

## Test that grid-aligned positioning produces symmetric results for circular shapes
func test_grid_aligned_positioning_produces_symmetric_results():
	# This test verifies that proper grid alignment prevents asymmetric indicator distribution
	
	# Set positioner to exact grid center
	var grid_position = Vector2(800, 600)  # Exact tile center
	positioner.global_position = grid_position
	
	# Create circular collision shape (should be symmetric)
	var area_2d = auto_free(Area2D.new())
	add_child(area_2d)
	area_2d.collision_layer = 1
	
	var collision_shape = auto_free(CollisionShape2D.new())
	area_2d.add_child(collision_shape)
	collision_shape.position = Vector2.ZERO
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 32.0  # 2 tiles radius
	collision_shape.shape = circle_shape
	
	# Set up indicator manager
	var indicators_parent = auto_free(Node2D.new())
	add_child(indicators_parent)
	var indicator_manager = IndicatorManager.new(indicators_parent, targeting_state, null, logger)
	var test_rule = TileCheckRule.new()
	
	# Generate indicators
	var indicators = indicator_manager.setup_indicators(area_2d, [test_rule], indicators_parent)
	
	# Analyze symmetry
	var left_count = 0
	var right_count = 0
	var center_count = 0
	
	for indicator in indicators:
		var indicator_name = indicator.name
		if indicator_name.begins_with("Offset(-"):
			left_count += 1
		elif indicator_name.begins_with("Offset(0,"):
			center_count += 1
		else:  # Positive offsets
			right_count += 1
	
	# For a perfect circle at grid center, left and right should be equal (or very close)
	var symmetry_difference = abs(left_count - right_count)
	assert_int(symmetry_difference).append_failure_message(
		"Circle should produce symmetric indicators. Left: %d, Right: %d, Center: %d" % [
			left_count, right_count, center_count
		]
	).is_less_equal(1)  # Allow at most 1 difference due to rounding

## Test that off-grid positioning gets corrected and produces consistent results
func test_off_grid_positioning_correction_consistency():
	# Test that the same object at different off-grid positions produces identical indicators after correction
	
	var test_positions = [
		Vector2(500.3, 400.7),   # Slightly off-grid
		Vector2(500.8, 400.2),   # Different off-grid offset
		Vector2(499.9, 399.6)    # Another off-grid position
	]
	
	var expected_results: Array[Array] = []
	
	for test_pos in test_positions:
		# Set positioner to off-grid position
		positioner.global_position = test_pos
		
		# Create identical test object
		var static_body = auto_free(StaticBody2D.new())
		add_child(static_body)
		static_body.collision_layer = 1
		
		var collision_shape = auto_free(CollisionShape2D.new())
		static_body.add_child(collision_shape)
		collision_shape.position = Vector2.ZERO
		
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(24, 24)
		collision_shape.shape = rect_shape
		
		# Set up indicator manager
		var indicators_parent = auto_free(Node2D.new())
		add_child(indicators_parent)
		var indicator_manager = IndicatorManager.new(indicators_parent, targeting_state, null, logger)
		var test_rule = TileCheckRule.new()
		
		# Generate indicators
		var indicators = indicator_manager.setup_indicators(static_body, [test_rule], indicators_parent)
		
		# Record result
		var indicator_names: Array[String] = []
		for indicator in indicators:
			indicator_names.append(indicator.name)
		indicator_names.sort()
		
		expected_results.append(indicator_names)
	
	# All results should be identical (same indicator names in same order)
	for i in range(1, expected_results.size()):
		assert_array(expected_results[i]).append_failure_message(
			"Off-grid position %s should produce same results as position %s after grid alignment" % [
				test_positions[i], test_positions[0]
			]
		).is_equal(expected_results[0])
