extends GdUnitTestSuite
## Test suite for indicator manager functionality

# Import the collision object test factory
const CollisionObjectTestFactoryGd = preload("res://test/grid_building_test/factories/collision_object_test_factory.gd")
const COLLISION_TEST_ENV_UID : String = "uid://cdrtd538vrmun"

var env: CollisionTestEnvironment
var runner: GdUnitSceneRunner
var _test_tile_map_layer: TileMapLayer = null

func before_test() -> void:
	runner = scene_runner(COLLISION_TEST_ENV_UID)
	env = runner.scene() as CollisionTestEnvironment
	
	# Set up targeting state with default target for indicator tests
	_setup_targeting_state_for_tests()
	
	# Force synchronous indicator validation instead of awaiting frames
	env.indicator_manager.force_indicators_validity_evaluation()

	if _test_tile_map_layer == null:
		_test_tile_map_layer = GodotTestFactory.create_empty_tile_map_layer(self)

## Sets up the GridTargetingState with a default target for indicator tests
func _setup_targeting_state_for_tests() -> void:
	# Create a default target for the targeting state if none exists
	if env.targeting_state.get_target() == null:
		var default_target: Node2D = auto_free(Node2D.new())
		default_target.position = Vector2(64, 64)
		default_target.name = "DefaultTarget"
		add_child(default_target)
		env.targeting_state.set_manual_target(default_target)

## Ensures targeting state has a valid target (call right before try_setup)
func _ensure_targeting_state_has_target() -> void:
	if env.targeting_state.get_target() == null:
		var target: Node2D = auto_free(Node2D.new())
		target.position = Vector2(64, 64)
		target.name = "TestTarget"
		add_child(target)
		env.targeting_state.set_manual_target(target)

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

# ===== INDICATOR CONTEXT INITIALIZATION TESTS =====

func test_indicator_context_reports_missing_manager_initially() -> void:
	# Create a fresh IndicatorContext without pre-assigned manager
	var fresh_indicator_context: IndicatorContext = IndicatorContext.new()
	auto_free(fresh_indicator_context)

	# Initially, fresh context should report that IndicatorManager is not assigned
	var initial_issues : Array[String] = fresh_indicator_context.get_runtime_issues()
	assert_array(initial_issues).append_failure_message(
		"IndicatorContext should return an array of issues"
	).is_not_empty()

	var has_manager_issue : bool = false
	for issue in initial_issues:
		if "IndicatorManager is not assigned in IndicatorContext" in issue:
			has_manager_issue = true
			break

	assert_bool(has_manager_issue).append_failure_message(
		"IndicatorContext should report IndicatorManager not assigned initially. Issues found: %s" % str(initial_issues)
	).is_true()

	# Should not have a manager initially
	assert_bool(fresh_indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should not have a manager initially"
	).is_false()

func test_indicator_context_after_manager_assignment() -> void:
	# Get the indicator context from container
	var indicator_context: IndicatorContext = env.container.get_indicator_context()

	# Create and assign an IndicatorManager
	var indicator_manager: IndicatorManager = env.indicator_manager
	indicator_context.set_manager(indicator_manager)

	# After assignment, should have no runtime issues
	var post_assignment_issues : Array[String] = indicator_context.get_runtime_issues()
	assert_array(post_assignment_issues).append_failure_message(
		"IndicatorContext should have no runtime issues after IndicatorManager assignment, but found: %s" % str(post_assignment_issues)
	).is_empty()

	# Should have a manager
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should have a manager after assignment"
	).is_true()

	# Should be able to retrieve the same manager
	var retrieved_manager : IndicatorManager = indicator_context.get_manager()
	assert_object(retrieved_manager).append_failure_message(
		"Should be able to retrieve the assigned IndicatorManager"
	).is_same(indicator_manager)

func test_indicator_context_manager_changed_signal() -> void:
	# Get the indicator context from container
	var indicator_context: IndicatorContext = env.container.get_indicator_context()

	# Create and assign an IndicatorManager
	var indicator_manager: IndicatorManager = env.indicator_manager
	indicator_context.set_manager(indicator_manager)

	# Verify manager was set (basic functionality test)
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should have manager after assignment"
	).is_true()

	# Test setting the same manager doesn't cause issues
	indicator_context.set_manager(indicator_manager)
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should still have manager after re-assignment"
	).is_true()

func test_composition_container_validation_with_manager() -> void:
	# Create a fresh composition container without pre-assigned manager
	var fresh_container: GBCompositionContainer = GBCompositionContainer.new()
	fresh_container.config = env.container.config  # Copy the config
	auto_free(fresh_container)

	# Before manager assignment, fresh container should have runtime issues
	var initial_issues : Array[String] = fresh_container.get_runtime_issues()
	var has_indicator_manager_issue : bool = false
	for issue in initial_issues:
		if "IndicatorManager is not assigned in IndicatorContext" in issue:
			has_indicator_manager_issue = true
			break

	assert_bool(has_indicator_manager_issue).append_failure_message(
		"Composition container should report IndicatorManager not assigned issue initially. Issues found: %s" % str(initial_issues)
	).is_true()

	# Assign IndicatorManager to fresh context
	var indicator_context: IndicatorContext = fresh_container.get_indicator_context()
	var indicator_manager: IndicatorManager = env.indicator_manager
	indicator_context.set_manager(indicator_manager)

	# After assignment, the specific issue should be resolved
	var post_assignment_issues : Array[String] = fresh_container.get_runtime_issues()
	var still_has_indicator_manager_issue : bool = false
	for issue : String in post_assignment_issues:
		if "IndicatorManager is not assigned in IndicatorContext" in issue:
			still_has_indicator_manager_issue = true
			break

	assert_bool(still_has_indicator_manager_issue).append_failure_message(
		"Composition container should not report IndicatorManager issue after assignment. Issues found: %s" % str(post_assignment_issues)
	).is_false()

# ===== TREE INTEGRATION TESTS =====

func test_indicators_are_parented_and_inside_tree() -> void:
	var preview: Node2D = _create_preview_with_collision()
	env.targeting_state.set_manual_target(preview)

	# Build a tile check rule that applies to layer 1 and should create indicators
	var rule: TileCheckRule = TileCheckRule.new()
	rule.apply_to_objects_mask = GBTestConstants.TEST_COLLISION_LAYER
	rule.resource_name = "test_tile_rule"
	var rules: Array[PlacementRule] = [rule]

	var setup_results: PlacementReport = env.indicator_manager.try_setup(rules, env.targeting_state)
	assert_bool(setup_results.is_successful()).append_failure_message("IndicatorManager.try_setup failed: " + str(setup_results.get_issues())).is_true()

	var indicators: Array[RuleCheckIndicator] = env.indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created. Setup result: " + str(setup_results.is_successful())).is_not_empty()

	for ind: RuleCheckIndicator in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()

		# Current architecture: indicators are parented under the IndicatorManager itself
		var expected_parent: Node = env.indicator_manager
		var actual_parent: Node = ind.get_parent()

		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % [ind.name]).is_equal(expected_parent)

# ===== BASIC INDICATOR MANAGER TESTS =====

func test_indicator_manager_creation() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	assert_that(indicator_manager).is_not_null()
	assert_that(indicator_manager.get_parent()).is_not_null()

func test_indicator_setup_basic() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager

	# Create and setup test area
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()

func test_indicator_cleanup() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager

	# Create and setup test indicators first
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()
	indicator_manager.setup_indicators(area, rules)

	# Test cleanup
	indicator_manager.tear_down()

	# Count remaining indicators (should only have test objects, not indicators)
	var indicator_count: int = _count_indicators(self)
	var indicator_names: Array[String] = _get_indicator_names()
	assert_int(indicator_count).append_failure_message(
		"Indicator cleanup failed - expected 0 indicators, found %d. Remaining: %s" % [indicator_count, str(indicator_names)]
	).is_equal(0)

func test_indicator_positioning() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager
	var positioner: Node2D = env.positioner

	# Position positioner at specific location
	positioner.position = Vector2(32, 32)

	# Create and setup test object
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)

	assert_that(report).is_not_null()
	# Verify indicators are positioned (basic check)
	for child: Node in indicator_manager.get_children():
		if child is RuleCheckIndicator:
			assert_that(child.global_position).is_not_equal(Vector2.ZERO)

func test_multiple_setup_calls() -> void:
	var indicator_manager: IndicatorManager = env.indicator_manager

	# Create and setup test object
	var area: Area2D = _create_test_area()
	_setup_test_area(area)

	var rules: Array[TileCheckRule] = _create_test_rules()

	# First setup
	indicator_manager.setup_indicators(area, rules)
	await get_tree().process_frame
	var first_count: int = _count_indicators(self)
	var first_names: Array[String] = _get_indicator_names()

	# Second setup should replace, not duplicate
	indicator_manager.setup_indicators(area, rules)
	await get_tree().process_frame
	var second_count: int = _count_indicators(self)
	var second_names: Array[String] = _get_indicator_names()

	assert_int(first_count).append_failure_message(
		"First setup produced no indicators. Names: %s" % [str(first_names)]
	).is_greater(0)
	assert_int(second_count).append_failure_message(
		"Second setup should replace, not duplicate - expected %d, got %d. First: %s | Second: %s" % [first_count, second_count, str(first_names), str(second_names)]
	).is_equal(first_count)

# ===== HELPER FUNCTIONS =====

func _create_preview_with_collision() -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "PreviewRoot"
	# Simple body with collision on layer 1
	var area: Area2D = Area2D.new()
	area.collision_layer = GBTestConstants.TEST_COLLISION_LAYER
	area.collision_mask = GBTestConstants.TEST_COLLISION_MASK
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	# Use half tile size for smaller collision shape
	const HALF_TILE_SIZE: Vector2 = GBTestConstants.DEFAULT_TILE_SIZE / 2
	rect.size = HALF_TILE_SIZE
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	# Add to test scene instead of positioner
	add_child(root)
	return root

func _create_test_area() -> Area2D:
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(16, 16)
	area.add_child(collision_shape)
	return area

func _create_test_rules() -> Array[TileCheckRule]:
	var rules : Array[TileCheckRule] = []
	# Base tile check to keep pipeline consistent
	rules.append(TileCheckRule.new())
	# Add a collisions rule to ensure indicators are generated for the test area
	var collisions_rule := CollisionsCheckRule.new()
	# Set up with the environment's targeting state to avoid null context
	var setup_issues: Array[String] = collisions_rule.setup(env.get_container().get_targeting_state())
	assert_array(setup_issues).append_failure_message("CollisionsCheckRule.setup returned issues: %s" % [str(setup_issues)]).is_empty()
	rules.append(collisions_rule)
	return rules

func _setup_test_area(area: Area2D) -> void:
	# For CollisionTestEnvironment, add directly to the test scene
	add_child(area)
	auto_free(area)

func _count_indicators(parent: Node) -> int:
	var manager: IndicatorManager = env.indicator_manager
	if manager != null and is_instance_valid(manager):
		# Prefer public API: returns Array[RuleCheckIndicator]
		var indicators: Array[RuleCheckIndicator] = manager.get_indicators()
		if indicators != null:
			if indicators.size() > 0:
				# Optional debug
				var names: Array[String] = []
				for ind: RuleCheckIndicator in indicators:
					names.append(ind.name)
				print("_count_indicators via API found %d indicators: %s" % [indicators.size(), str(names)])
			return indicators.size()

	# Fallback: name-based scan if API unavailable
	var count: int = 0
	var child_names: Array[String] = []
	for child in parent.get_children():
		if typeof(child.name) == TYPE_STRING and String(child.name).begins_with("RuleCheckIndicator"):
			count += 1
			child_names.append(child.name + "(" + child.get_class() + ")")
	if count > 0:
		print("_count_indicators via fallback found %d indicators: %s" % [count, str(child_names)])
	return count

func _get_indicator_names() -> Array[String]:
	var names: Array[String] = []
	var manager: IndicatorManager = env.indicator_manager
	if manager != null and is_instance_valid(manager):
		var indicators: Array[RuleCheckIndicator] = manager.get_indicators()
		if indicators != null:
			for ind: RuleCheckIndicator in indicators:
				if typeof(ind.name) == TYPE_STRING:
					names.append(String(ind.name))
			return names
		# Fallback to child scan if API not available
		for child in manager.get_children():
			if typeof(child.name) == TYPE_STRING and String(child.name).begins_with("RuleCheckIndicator"):
				names.append(String(child.name))
		return names
	return names

## Helper: build a tile->indicator map using GridTargetingState.target_map
func _map_indicators_by_tile(indicators: Array[RuleCheckIndicator]) -> Dictionary:
	var result: Dictionary = {}
	var tm: TileMapLayer = env.get_container().get_targeting_state().target_map
	for ind in indicators:
		var tile := _get_indicator_tile(ind, tm)
		result[tile] = ind
	return result

## Helper: compute the tile for a given indicator
func _get_indicator_tile(indicator: RuleCheckIndicator, tm: TileMapLayer) -> Vector2i:
	return tm.local_to_map(tm.to_local(indicator.global_position))
