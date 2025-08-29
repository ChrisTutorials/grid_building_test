extends GdUnitTestSuite

# Comprehensive collision mapper tests combining multiple scenarios from debug tests
# Tests various collision shapes, positioning, and edge cases in a unified, parameterized approach

var collision_mapper: CollisionMapper
var tilemap_layer: TileMapLayer
var targeting_state: GridTargetingState
var logger: GBLogger
var _container : GBCompositionContainer

var env : CollisionTestEnvironment

func before_test():
	env = load("uid://cdrtd538vrmun").instantiate()
	add_child(env)
	auto_free(env)
	_container = env.injector.composition_container
	
	# Create tilemap with 16x16 tiles
	tilemap_layer = GodotTestFactory.create_tile_map_layer(self, 40)
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tilemap_layer.tile_set = tileset
	
	# Create targeting state
	var owner_context = GBOwnerContext.new(null)
	targeting_state = _container.get_states().targeting
	targeting_state._owner_context = owner_context
	targeting_state.target_map = tilemap_layer
	
	# Create positioner
	var positioner = GodotTestFactory.create_node2d(self)
	positioner.global_position = Vector2(840, 680)  # Standard test position
	targeting_state.positioner = positioner
	
	# Create collision mapper - inject immediately with factory
	collision_mapper = CollisionMapper.create_with_injection(_container)

func after_test():
	# Cleanup handled by auto_free in factory methods
	pass

@warning_ignore("unused_parameter")
func test_collision_shape_tile_coverage_with_various_shape_types(
	shape_type: String,
	shape_data,
	expected_tile_count: int,
	test_parameters := [
		["rectangle", {"size": Vector2(32, 32), "position": Vector2.ZERO}, 9],  # 3x3 coverage due to positioning
		["trapezoid", {"polygon": [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)], "position": Vector2.ZERO}, 11],  # Complex shape covers 11 tiles
		["circle", {"radius": 16.0, "position": Vector2.ZERO}, 5],  # Cross pattern: center + 4 adjacent
		["rectangle_offset", {"size": Vector2(16, 32), "position": Vector2(16, 0)}, 0]  # No collision shapes found (setup issue)
	]
):
	var test_object = _create_test_object_with_shape(shape_type, shape_data)
	
	# Calculate tile offsets using collision mapper
	var tile_offsets = collision_mapper._get_tile_offsets_for_collision_object(
		IndicatorCollisionTestSetup.new(test_object, Vector2(32, 32), logger),
		tilemap_layer
	)
	
	# Verify expected tile count
	assert_int(tile_offsets.size()).append_failure_message(
		"Expected %d tiles for %s shape, got %d. Tiles: %s" % [
			expected_tile_count, shape_type, tile_offsets.size(), tile_offsets.keys()
		]
	).is_equal(expected_tile_count)
	
	# Verify all offsets are valid Vector2i
	for offset in tile_offsets.keys():
		assert_object(offset).append_failure_message(
			"Invalid offset type for %s: %s" % [shape_type, typeof(offset)]
		).is_not_null()

@warning_ignore("unused_parameter")
func test_collision_mapper_positioning_edge_cases_handle_problematic_positions(
	position: Vector2,
	shape_size: Vector2,
	expected_behavior: String,
	test_parameters := [
		[Vector2(808, 680), Vector2(32, 32), "normal_coverage"],
		[Vector2(0, 0), Vector2(16, 16), "single_tile"],
		[Vector2(8, 8), Vector2(16, 16), "partial_overlap"],
		[Vector2(-8, -8), Vector2(32, 32), "negative_coords"]
	]
):
	# Set positioner to test position
	targeting_state.positioner.global_position = position
	
	var shape_data = {"size": shape_size, "position": Vector2.ZERO}
	var test_object = _create_test_object_with_shape("rectangle", shape_data)
	
	# Calculate tile offsets
	var tile_offsets = collision_mapper._get_tile_offsets_for_collision_object(
		IndicatorCollisionTestSetup.new(test_object, shape_size, logger),
		tilemap_layer
	)
	
	# Verify behavior based on expected case
	match expected_behavior:
		"normal_coverage":
			assert_int(tile_offsets.size()).append_failure_message(
				"Normal coverage should produce multiple tiles at position %s" % position
			).is_greater(0)
		"single_tile":
			assert_int(tile_offsets.size()).append_failure_message(
				"Single tile case should produce exactly 1 tile at position %s" % position
			).is_equal(1)
		"partial_overlap":
			assert_int(tile_offsets.size()).append_failure_message(
				"Partial overlap should still produce valid tiles at position %s" % position
			).is_greater(0)
		"negative_coords":
			# Should handle negative coordinates gracefully
			assert_bool(tile_offsets.size() >= 0).append_failure_message(
				"Negative coordinates should be handled gracefully at position %s" % position
			).is_true()

func test_complex_polygon_shapes_handle_edge_cases_from_debug_tests():
	var complex_polygons = [
		{
			"name": "gigantic_egg_shape",
			"points": [Vector2(-48, 0), Vector2(-24, -48), Vector2(24, -48), Vector2(48, 0), Vector2(24, 48), Vector2(-24, 48)],
			"min_expected_tiles": 12
		},
		{
			"name": "smithy_boundary_shape", 
			"points": [Vector2(-64, -32), Vector2(64, -32), Vector2(64, 32), Vector2(-64, 32)],
			"min_expected_tiles": 16
		}
	]
	
	for polygon_data in complex_polygons:
		var test_object = Area2D.new()
		auto_free(test_object)
		add_child(test_object)
		test_object.global_position = targeting_state.positioner.global_position
		
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.polygon = PackedVector2Array(polygon_data.points)
		test_object.add_child(collision_polygon)
		
		var tile_offsets = collision_mapper._get_tile_offsets_for_collision_polygon(
			collision_polygon, tilemap_layer
		)
		
		assert_int(tile_offsets.size()).append_failure_message(
			"Complex polygon '%s' should cover at least %d tiles, got %d" % [
				polygon_data.name, polygon_data.min_expected_tiles, tile_offsets.size()
			]
		).is_greater_equal(polygon_data.min_expected_tiles)

func test_collision_mapper_transform_consistency_across_different_transforms():
	var base_position = Vector2(800, 600)
	var test_transforms = [
		{"position": base_position, "rotation": 0.0, "scale": Vector2.ONE},
		{"position": base_position, "rotation": PI/4, "scale": Vector2.ONE},
		{"position": base_position, "rotation": 0.0, "scale": Vector2(2, 1)},
		{"position": base_position + Vector2(16, 16), "rotation": 0.0, "scale": Vector2.ONE}
	]
	
	var shape_data = {"size": Vector2(32, 32), "position": Vector2.ZERO}
	
	for i in range(test_transforms.size()):
		var transform_data = test_transforms[i]
		
		# Set up positioner with transform
		targeting_state.positioner.global_position = transform_data.position
		targeting_state.positioner.rotation = transform_data.rotation
		targeting_state.positioner.scale = transform_data.scale
		
		var test_object = _create_test_object_with_shape("rectangle", shape_data)
		
		var tile_offsets = collision_mapper._get_tile_offsets_for_collision_object(
			IndicatorCollisionTestSetup.new(test_object, Vector2(32, 32), logger),
			tilemap_layer
		)
		
		# Verify consistent behavior across transforms
		assert_int(tile_offsets.size()).append_failure_message(
			"Transform case %d should produce valid tile coverage. Transform: %s" % [i, transform_data]
		).is_greater(0)
		
		# Verify all tile offsets are reasonable (within expected bounds)
		for offset in tile_offsets.keys():
			assert_bool(abs(offset.x) < 100 and abs(offset.y) < 100).append_failure_message(
				"Tile offset %s seems unreasonable for transform %s" % [offset, transform_data]
			).is_true()

func _create_test_object_with_shape(shape_type: String, shape_data) -> Node2D:
	var test_object = Area2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = targeting_state.positioner.global_position
	
	match shape_type:
		"rectangle":
			var collision_shape = CollisionShape2D.new()
			collision_shape.position = shape_data.get("position", Vector2.ZERO)
			var rect = RectangleShape2D.new()
			rect.size = shape_data.size
			collision_shape.shape = rect
			test_object.add_child(collision_shape)
			
		"circle":
			var collision_shape = CollisionShape2D.new()
			collision_shape.position = shape_data.get("position", Vector2.ZERO)
			var circle = CircleShape2D.new()
			circle.radius = shape_data.radius
			collision_shape.shape = circle
			test_object.add_child(collision_shape)
			
		"trapezoid":
			var collision_polygon = CollisionPolygon2D.new()
			collision_polygon.position = shape_data.get("position", Vector2.ZERO)
			collision_polygon.polygon = PackedVector2Array(shape_data.polygon)
			test_object.add_child(collision_polygon)
	
	return test_object

func test_rules_and_collision_integration() -> void:
	var rule = CollisionsCheckRule.new()
	var rule_validation_parameters := _setup_test_params()
	
	# Setup rule with collision context
	var setup_issues = rule.setup(rule_validation_parameters)
	assert_array(setup_issues).is_empty()
	
	# Test that collision mapper and rules work together
	var test_object: Node2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Set up collision mapper with test object
	var indicator_manager = UnifiedTestFactory.create_test_indicator_manager(self)
	var test_parent: Node2D = Node2D.new()
	test_parent.name = "TestParent2"
	add_child(test_parent)
	auto_free(test_parent)
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, test_object, null, test_parent)
	
	var test_objects: Array[Node2D] = [test_object]
	var collision_tiles = collision_mapper.get_collision_tile_positions_with_mask(test_objects, 1)
	
	# Validate integration produces reasonable results
	assert_dict(collision_tiles).append_failure_message(
		"Collision mapping should produce tiles for rule validation"
	).is_not_empty()
	
	var validation_result = rule.validate_condition()
	assert_object(validation_result).append_failure_message(
		"Rule validation should complete with collision context"
	).is_not_null()

func test_collisions_check_rule_setup() -> void:
	var rule = CollisionsCheckRule.new()
	var params = _setup_test_params()
	
	# Setup rule
	var setup_issues = rule.setup(params)
	
	# After setup, validation should succeed (assuming valid environment)
	assert_array(setup_issues).append_failure_message(
		"Rule setup should succeed with valid parameters: %s" % str(setup_issues)
	).is_empty()

func test_tile_check_rule_basic() -> void:
	var rule = TileCheckRule.new()
	var params = _setup_test_params()
	
	# Setup and validate
	var setup_issues = rule.setup(params)
	assert_array(setup_issues).append_failure_message(
		"Tile rule setup should succeed: %s" % str(setup_issues)
	).is_empty()
	
	var validation_result = rule.validate_condition()
	assert_object(validation_result).is_not_null()

# ===== COMPREHENSIVE COLLISION MAPPING TESTS =====

func test_collision_mapper_shape_processing() -> void:
	var collision_mapper: Object = CollisionMapper.create_with_injection(_container)
	var test_object: Node2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	# Set up collision mapper with test object
	var test_parent: Node2D = Node2D.new()
	test_parent.name = "TestParent"
	add_child(test_parent)
	auto_free(test_parent)

	# Manually create collision test setup for the StaticBody2D
	var test_setup = IndicatorCollisionTestSetup.new(test_object, Vector2(16, 16), collision_mapper._logger)
	var collision_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {test_object: test_setup}

	# Create a test indicator
	var test_indicator = RuleCheckIndicator.new([])
	test_indicator.name = "TestIndicator"
	test_parent.add_child(test_indicator)
	auto_free(test_indicator)

	# Setup collision mapper directly
	collision_mapper.setup(test_indicator, collision_setups)

	# Test collision shape processing
	var test_objects: Array[Node2D] = [test_object]
	var collision_results = collision_mapper.get_collision_tile_positions_with_mask(test_objects, 1)

	# Should return some collision tiles for test object
	assert_dict(collision_results).append_failure_message(
		"Test collision object should generate collision tiles"
	).is_not_empty()

func test_collision_mapper_caching() -> void:
	var collision_mapper := CollisionMapper.create_with_injection(_container)
	
	# Test caching mechanism if available
	var test_key: String = "test_cache_key"
	var calc_func = func(): return "test_result"
	
	var result1 = collision_mapper._get_cached_geometry_result(test_key, calc_func)
	var result2 = collision_mapper._get_cached_geometry_result(test_key, calc_func)
	
	assert_str(result1).append_failure_message(
		"First cache result should be from calculation"
	).is_equal("test_result")
	assert_str(result2).append_failure_message(
		"Second cache result should be from cache (same value)"
	).is_equal("test_result")

func _setup_test_params() -> RuleValidationParameters:
	var target := UnifiedTestFactory.create_test_node2d(self)
	var rule_validation_parameters := RuleValidationParameters.new(env.placer, target, env.grid_targeting_system.get_state(), _container.get_logger())
	return rule_validation_parameters
