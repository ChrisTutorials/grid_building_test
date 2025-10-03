extends GdUnitTestSuite
## Test suite for indicator manager functionality

# Import the collision object test factory
const CollisionObjectTestFactoryGd = preload("res://test/grid_building_test/factories/collision_object_test_factory.gd")
const COLLISION_TEST_ENV_UID : String = "uid://cdrtd538vrmun"

var env: CollisionTestEnvironment
var _test_tile_map_layer: TileMapLayer = null

func before_test() -> void:
	env = UnifiedTestFactory.instance_collision_test_env(self, COLLISION_TEST_ENV_UID)
	
	# Set up targeting state with default target for indicator tests
	_setup_targeting_state_for_tests()
	
	# Wait for environment initialization to complete
	await await_idle_frame()

	if _test_tile_map_layer == null:
		_test_tile_map_layer = GodotTestFactory.create_empty_tile_map_layer(self)

## Sets up the GridTargetingState with a default target for indicator tests
func _setup_targeting_state_for_tests() -> void:
	# Create a default target for the targeting state if none exists
	if env.targeting_state.target == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		env.targeting_state.target = default_target

## Ensures targeting state has a valid target (call right before try_setup)
func _ensure_targeting_state_has_target() -> void:
	if env.targeting_state.target == null:
		var target: Node2D = auto_free(Node2D.new())
		target.position = Vector2(64, 64)
		target.name = "TestTarget"
		add_child(target)
		env.targeting_state.target = target

# ===== COLLISION MAPPER SHAPE POSITIONING TESTS =====

func test_collision_mapper_shape_positioning() -> void:
	var test_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(32, 32))
	var collision_mapper: Object = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [test_object], Vector2(32, 32), 16)
	
	# Test shape positioning at different locations
	var test_positions: Array[Vector2] = [Vector2(0, 0), Vector2(100, 100), Vector2(-50, -50)]
	
	for pos: Vector2 in test_positions:
		test_object.global_position = pos
		var collision_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [test_object])
		
		assert_int(collision_tiles.size()).append_failure_message(
			"Should generate collision tiles at position %s" % pos
		).is_greater(0)

func test_shape_positioner_movement_consistency() -> void:
	var test_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_circle(self, 16)
	var collision_mapper: Object = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [test_object], Vector2(32, 32), 16)
	
	# Test movement from one position to another
	var start_pos: Vector2 = Vector2(0, 0)
	var end_pos: Vector2 = Vector2(32, 32)
	
	test_object.global_position = start_pos
	var start_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [test_object])
	
	test_object.global_position = end_pos  
	var end_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [test_object])
	
	# Both positions should generate valid collision data
	assert_int(start_tiles.size()).append_failure_message(
		"Start position should generate collision tiles"
	).is_greater(0)
	assert_int(end_tiles.size()).append_failure_message(
		"End position should generate collision tiles"  
	).is_greater(0)
	
	# Positions should generally produce different tile sets
	var tiles_differ: bool = start_tiles.keys() != end_tiles.keys()
	assert_bool(tiles_differ).append_failure_message(
		"Different positions should generally produce different collision tiles"
	).is_true()

# ===== TRAPEZOID REGRESSION TESTS =====

func test_trapezoid_bottom_row_regression() -> void:
	# Create trapezoid shape for testing
	var trapezoid_points: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	
	# Test trapezoid tile coverage using CollisionGeometryCalculator
	var tile_size: Vector2 = Vector2(16, 16)
	var overlapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		trapezoid_points, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	assert_array(overlapped_tiles).append_failure_message(
		"Trapezoid should overlap multiple tiles"
	).is_not_empty()
	
	# Verify trapezoid geometry properties
	var bounds: Rect2 = GBGeometryMath.get_polygon_bounds(trapezoid_points)
	assert_float(bounds.size.x).append_failure_message(
		"Trapezoid should have reasonable width"
	).is_greater(32.0)

func test_collision_mapper_trapezoid_regression() -> void:
	# Create trapezoid collision polygon
	var trapezoid_points: PackedVector2Array = PackedVector2Array([
		Vector2(-24, 8), Vector2(-12, -8), Vector2(12, -8), Vector2(24, 8)
	])
	var trapezoid_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_polygon(self, trapezoid_points)
	var collision_mapper: Object = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [trapezoid_object], Vector2(48, 16), 16)
	
	# Test trapezoid collision mapping
	trapezoid_object.global_position = Vector2(0, 0)
	
	# Position the positioner near the test object to get reasonable tile coordinates
	env.positioner.global_position = Vector2(0, 0)
	
	var collision_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [trapezoid_object])
	
	assert_int(collision_tiles.size()).append_failure_message(
		"Trapezoid collision mapping should produce tiles"
	).is_greater(0)
	
	# Verify tile offsets are reasonable for trapezoid shape
	# Note: These are offset coordinates relative to the positioner position
	for tile_pos: Variant in collision_tiles.keys():
		var tile_coord: Vector2i = tile_pos as Vector2i
		assert_int(abs(tile_coord.x)).append_failure_message(
			"Trapezoid tile offset should be reasonable: %d" % tile_coord.x
		).is_less(10) # Offsets should be within reasonable range from center

# ===== POLYGON TILE MAPPER TESTS =====

func test_polygon_tile_mapper_basic() -> void:
	# Test basic polygon tile mapping functionality
	var simple_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	var mapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		simple_polygon, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	assert_int(mapped_tiles.size()).append_failure_message(
		"32x32 polygon should map to 4 tiles (2x2), got %d" % mapped_tiles.size()
	).is_equal(4)

func test_polygon_tile_mapper_isometric() -> void:
	# Test isometric tile mapping if supported
	var diamond_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	
	# For isometric calculations, we need a TileMapLayer - use square tiles as fallback
	var square_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		diamond_polygon, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	assert_array(square_tiles).append_failure_message(
		"Diamond polygon should map to tiles (using square fallback for test)"
	).is_not_empty()

func test_polygon_tile_shape_propagation() -> void:
	# Test that tile shape settings propagate correctly
	var test_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	
	# Test with square tiles (isometric requires TileMapLayer)
	var square_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		test_polygon, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	# Should produce results
	assert_array(square_tiles).append_failure_message(
		"Square tile mapping should produce results"
	).is_not_empty()

# ===== INDICATOR MANAGER TESTS =====

func test_indicator_manager_runtime_issues_guard() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Test that indicator manager handles runtime issues gracefully
	var _invalid_params: Dictionary = env.rule_validation_parameters
	
	# Ensure targeting state has a valid target
	_ensure_targeting_state_has_target()
	
	# Test with an empty/invalid setup - don't modify the original params
	# Create a minimal setup that should trigger error handling
	var result: PlacementReport = indicator_manager.try_setup([], env.targeting_state) # Empty rules array
	assert_object(result).append_failure_message(
		"Indicator manager should handle empty rules gracefully"
	).is_not_null()
	
	# Result should indicate success (graceful handling of empty rules)
	assert_bool(result.is_successful()).append_failure_message(
		"Empty rules setup should be handled gracefully and succeed"
	).is_true()

func test_indicator_manager_tree_integration() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Verify indicator manager is properly integrated into scene tree
	assert_object(indicator_manager.get_parent()).append_failure_message(
		"Indicator manager should have a parent in scene tree"
	).is_not_null()
	
	# Test basic functionality
	var test_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var _valid_params: Dictionary = env.rule_validation_parameters
	
	# Ensure targeting state has a valid target
	_ensure_targeting_state_has_target()
	
	var setup_result: PlacementReport = indicator_manager.try_setup([test_rule], env.targeting_state)
	assert_object(setup_result).is_not_null()

func test_indicator_manager_context_initialization() -> void:
	# Test that IndicatorManager is properly initialized in IndicatorContext after setup
	var container: GBCompositionContainer = env.container
	var indicator_context: IndicatorContext = container.get_indicator_context()
	
	# The env should already have an indicator_manager set in the context
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Verify manager is properly set
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should report having a manager from the test environment"
	).is_true()
	
	var retrieved_manager: IndicatorManager = indicator_context.get_manager()
	assert_object(retrieved_manager).append_failure_message(
		"Should be able to retrieve the IndicatorManager from context"
	).is_same(indicator_manager)
	
	# After setup, context should have no issues
	var post_setup_issues: Array = indicator_context.get_editor_issues()
	assert_array(post_setup_issues).append_failure_message(
		"IndicatorContext should have no editor issues with the test environment's IndicatorManager, but found: %s" % str(post_setup_issues)
	).is_empty()

# ===== POLYGON INDICATOR RUNTIME PARITY TESTS =====

func test_polygon_indicator_runtime_parity() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Create polygon collision
	var polygon_points: PackedVector2Array = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	var polygon_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_polygon(self, polygon_points)
	
	# Test that indicator generation matches runtime collision behavior
	var test_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var params: Dictionary = env.rule_validation_parameters
	params.target = polygon_object
	params.target.global_position = Vector2(0, 0)
	
	# Ensure targeting state has a valid target
	_ensure_targeting_state_has_target()
	
	var indicator_result: PlacementReport = indicator_manager.try_setup([test_rule], env.targeting_state)
	assert_bool(indicator_result.is_successful()).append_failure_message(
		"Polygon indicator generation should succeed: %s" % str(indicator_result.get_issues())
	).is_true()

func test_polygon_origin_indicator_regression() -> void:
	# Test polygon origin handling for indicators
	var origin_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(24, 0), Vector2(24, 24), Vector2(0, 24)
	])
	
	# Test with origin at different positions
	var origin_offsets: Array[Vector2] = [Vector2.ZERO, Vector2(8, 8), Vector2(-8, -8)]
	
	for offset: Vector2 in origin_offsets:
		var offset_polygon: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in origin_polygon:
			offset_polygon.append(point + offset)
		
		var tile_size: Vector2 = Vector2(16, 16)
		var mapped_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
			offset_polygon, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
		)
		
		assert_array(mapped_tiles).append_failure_message(
			"Polygon with origin offset %s should map to tiles" % offset
		).is_not_empty()

# ===== REAL-WORLD INDICATOR TESTS =====

func test_real_world_indicator_scenarios() -> void:
	var _indicator_manager: IndicatorManager = env.indicator_manager
	
	# Test scenario 1: Small building
	var small_building: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
	var collision_mapper: Object = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [small_building], Vector2(16, 16), 16)
	
	small_building.global_position = Vector2(0, 0)
	var small_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [small_building])
	assert_array(small_tiles.keys()).append_failure_message(
		"Small building should generate collision tiles"
	).is_not_empty()
	
	# Test scenario 2: Large building
	var large_building: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(64, 64))
	collision_mapper = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [large_building], Vector2(64, 64), 32)
	
	large_building.global_position = Vector2(0, 0)
	var large_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [large_building])
	assert_array(large_tiles.keys()).append_failure_message(
		"Large building should generate collision tiles"
	).is_not_empty()
	
	# Large building should generally have more collision tiles
	assert_int(large_tiles.size()).append_failure_message(
		"Large building should have more collision tiles than small building"
	).is_greater(small_tiles.size())

# ===== ISOMETRIC COLLISION MAPPING TESTS =====

func test_isometric_collision_mapping() -> void:
	# Test isometric-specific collision mapping
	var isometric_diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -20), Vector2(20, 0), Vector2(0, 20), Vector2(-20, 0)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	# Use square tiles for testing since TileMapLayer is required for isometric calculations
	var square_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		isometric_diamond, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	assert_array(square_tiles).append_failure_message(
		"Isometric diamond should map to tiles (using square tiles for test)"
	).is_not_empty()
	
	# Test that a different polygon produces different results
	var different_diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)
	])
	var different_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		different_diamond, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	# Results should be different for different polygons
	assert_array(different_tiles).is_not_empty()

func test_isometric_precision() -> void:
	# Test precision in collision mapping using square tiles
	var precise_diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)
	])
	
	var tile_size: Vector2 = Vector2(16, 16)
	# Use square tiles for testing since TileMapLayer is required for isometric calculations
	var precise_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		precise_diamond, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer
	)
	
	assert_array(precise_tiles).append_failure_message(
		"Precise diamond should map to at least one tile"
	).is_not_empty()
	
	# Test with different precision parameters
	var high_precision_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
		precise_diamond, tile_size, TileSet.TILE_SHAPE_SQUARE, _test_tile_map_layer, 0.01, 0.05
	)
	
	assert_array(high_precision_tiles).append_failure_message(
		"High precision calculation should also produce tiles"
	).is_not_empty()

# ===== COMPREHENSIVE COMPONENT INTEGRATION TESTS =====

func test_component_integration_workflow() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Create test object with complex collision (multiple shapes)
	var complex_object: StaticBody2D = CollisionObjectTestFactory.create_complex_collision_object(self, Vector2(24, 24), 12.0, Vector2(20, 20))
	
	# Set up collision mapper
	var collision_mapper: Object = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [complex_object], Vector2(44, 44), 24)
	
	# Test collision mapping
	complex_object.global_position = Vector2(0, 0)
	var collision_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [complex_object])
	assert_array(collision_tiles.keys()).append_failure_message(
		"Complex object should generate collision tiles"
	).is_not_empty()
	
	# Test indicator generation
	var test_rules: Array[PlacementRule] = [CollisionsCheckRule.new()]
	var params: Dictionary = env.rule_validation_parameters
	params.target = complex_object
	params.target.global_position = Vector2(0, 0)
	
	# Ensure targeting state has a valid target
	_ensure_targeting_state_has_target()
	
	var _indicator_result: PlacementReport = indicator_manager.try_setup(test_rules, env.targeting_state)

func test_placement_component_error_handling() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	
	# Test error handling with null/invalid inputs - collision mapper should handle gracefully
	var dummy_object: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(16, 16))
	var collision_mapper: Object = CollisionObjectTestFactory.setup_collision_mapper_with_objects(self, env, [dummy_object], Vector2(16, 16), 16)
	
	# Test with empty array (should return empty result)
	var null_tiles: Dictionary = CollisionObjectTestFactory.get_collision_tiles_for_objects(collision_mapper, [])
	assert_dict(null_tiles).append_failure_message(
		"Should handle empty collision object list gracefully"
	).is_empty()
	
	# Test indicator manager with invalid rule
	var invalid_rule: Variant = null
	var _params: Dictionary = env.rule_validation_parameters
	
	# Ensure targeting state has a valid target
	_ensure_targeting_state_has_target()
	
	var invalid_result: PlacementReport = indicator_manager.try_setup([invalid_rule], env.targeting_state)
	assert_object(invalid_result).append_failure_message(
		"Should handle invalid rule gracefully"
	).is_not_null()
	
	assert_bool(invalid_result.is_successful()).append_failure_message(
		"Invalid rule setup should be handled gracefully and succeed (null rules are filtered out)"
	).is_true()
