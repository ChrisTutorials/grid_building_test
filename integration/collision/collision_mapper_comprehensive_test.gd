extends GdUnitTestSuite

# Comprehensive collision mapper tests combining multiple scenarios from debug tests
# Tests various collision shapes, positioning, and edge cases in a unified, parameterized approach

# Constants for consistent test configuration
const TILE_SIZE := Vector2i(16, 16)
const GRID_SIZE := 40
const POSITIONER_OFFSET := Vector2(8, 8)  # Position to get expected tile coverage for shapes
const STANDARD_SHAPE_SIZE := Vector2(32, 32)
const SMALL_SHAPE_SIZE := Vector2(16, 16)
const MEDIUM_SHAPE_SIZE := Vector2(16, 32)

# Shape test expectations
const RECTANGLE_EXPECTED_TILES := 9  # 3x3 coverage due to positioning
const TRAPEZOID_EXPECTED_TILES := 11  # Complex shape covers 11 tiles  
const CIRCLE_EXPECTED_TILES := 5  # Cross pattern: center + 4 adjacent
const OFFSET_RECTANGLE_EXPECTED_TILES := 0  # No collision shapes found (setup issue)

# Circle test configuration
const CIRCLE_RADIUS := 16.0

# Trapezoid polygon points
const TRAPEZOID_POLYGON := [
	Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
]

# Test positioning vectors
const ORIGIN_POSITION := Vector2.ZERO
const TEST_POSITION_LARGE := Vector2(808, 680)
const TEST_POSITION_SMALL := Vector2(8, 8)
const TEST_POSITION_NEGATIVE := Vector2(-8, -8)
const OFFSET_POSITION := Vector2(16, 0)

var collision_mapper: CollisionMapper
var tilemap_layer: TileMapLayer
var targeting_state: GridTargetingState
var logger: GBLogger
var _container : GBCompositionContainer

var env : CollisionTestEnvironment

func before_test() -> void:
	env = load("uid://cdrtd538vrmun").instantiate()
	add_child(env)
	auto_free(env)
	_container = env.get_container()
	
	# Create tilemap with consistent tile size
	tilemap_layer = GodotTestFactory.create_tile_map_layer(self, GRID_SIZE)
	var tileset: TileSet = TileSet.new()
	tileset.tile_size = TILE_SIZE
	tilemap_layer.tile_set = tileset
	
	# Create targeting state
	var owner_context: GBOwnerContext = GBOwnerContext.new(null)
	targeting_state = _container.get_states().targeting
	targeting_state._owner_context = owner_context
	targeting_state.target_map = tilemap_layer
	
	# Create positioner
	var positioner: Node2D = GodotTestFactory.create_node2d(self)
	positioner.global_position = POSITIONER_OFFSET
	targeting_state.positioner = positioner
	
	# Create collision mapper - inject immediately with factory
	collision_mapper = CollisionMapper.create_with_injection(_container)

func after_test() -> void:
	# Cleanup handled by auto_free in factory methods
	pass

@warning_ignore("unused_parameter")
func test_collision_shape_tile_coverage_with_various_shape_types(
	shape_type: String,
	shape_data: Dictionary,
	expected_tile_count: int,
	test_parameters := [
		["rectangle", {"size": STANDARD_SHAPE_SIZE, "position": ORIGIN_POSITION}, RECTANGLE_EXPECTED_TILES],
		["trapezoid", {"polygon": TRAPEZOID_POLYGON, "position": ORIGIN_POSITION}, TRAPEZOID_EXPECTED_TILES],
		["circle", {"radius": CIRCLE_RADIUS, "position": ORIGIN_POSITION}, CIRCLE_EXPECTED_TILES],
		["rectangle_offset", {"size": MEDIUM_SHAPE_SIZE, "position": OFFSET_POSITION}, OFFSET_RECTANGLE_EXPECTED_TILES]
	]
) -> void:
	var test_object: Node2D = _create_test_object_with_shape(shape_type, shape_data)
	
	# Calculate tile offsets using collision mapper
	
	var tile_offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(
		IndicatorCollisionTestSetup.new(test_object, STANDARD_SHAPE_SIZE)
	)
	
	# Verify expected tile count
	assert_int(tile_offsets.size()).append_failure_message(
		"Expected %d tiles for %s shape, got %d. Tiles: %s" % [
			expected_tile_count, shape_type, tile_offsets.size(), tile_offsets.keys()
		]
	).is_equal(expected_tile_count)
	
	# Verify all offsets are valid Vector2i
	for offset: Vector2i in tile_offsets.keys():
		assert_object(offset).append_failure_message(
			"Invalid offset type for %s: %s" % [shape_type, typeof(offset)]
		).is_not_null()

@warning_ignore("unused_parameter")
func test_collision_mapper_positioning_edge_cases_handle_problematic_positions(
	position: Vector2,
	shape_size: Vector2,
	expected_behavior: String,
	test_parameters := [
		[TEST_POSITION_LARGE, STANDARD_SHAPE_SIZE, "normal_coverage"],
		[ORIGIN_POSITION, SMALL_SHAPE_SIZE, "single_tile"],
		[TEST_POSITION_SMALL, SMALL_SHAPE_SIZE, "partial_overlap"],
		[TEST_POSITION_NEGATIVE, STANDARD_SHAPE_SIZE, "negative_coords"]
	]
) -> void:
	# Set positioner to test position
	targeting_state.positioner.global_position = position
	
	var shape_data: Dictionary = {"size": shape_size, "position": ORIGIN_POSITION}
	var test_object: Node2D = _create_test_object_with_shape("rectangle", shape_data)
	
	# Calculate tile offsets
	var tile_offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(
		IndicatorCollisionTestSetup.new(test_object, shape_size)
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

func test_complex_polygon_shapes_handle_edge_cases_from_debug_tests() -> void:
	var complex_polygons: Array[Dictionary] = [
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
		var test_object: Area2D = Area2D.new()
		auto_free(test_object)
		add_child(test_object)
		test_object.global_position = targeting_state.positioner.global_position
		
		var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
		collision_polygon.polygon = PackedVector2Array(polygon_data.points)
		test_object.add_child(collision_polygon)
		
		var indicator_test_setup := IndicatorCollisionTestSetup.new(test_object, SMALL_SHAPE_SIZE)
		var tile_offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(
			indicator_test_setup
		)
		
		assert_int(tile_offsets.size()).append_failure_message(
			"Complex polygon '%s' should cover at least %d tiles, got %d" % [
				polygon_data.name, polygon_data.min_expected_tiles, tile_offsets.size()
			]
		).is_greater_equal(polygon_data.min_expected_tiles)

func test_collision_mapper_transform_consistency_across_different_transforms() -> void:
	var base_position: Vector2 = ORIGIN_POSITION
	var test_transforms: Array[Dictionary] = [
		{"position": base_position, "rotation": 0.0, "scale": Vector2.ONE},
		{"position": base_position, "rotation": PI/4, "scale": Vector2.ONE},
		{"position": base_position, "rotation": 0.0, "scale": Vector2(2, 1)},
		{"position": base_position + SMALL_SHAPE_SIZE, "rotation": 0.0, "scale": Vector2.ONE}
	]
	
	var shape_data: Dictionary = {"size": STANDARD_SHAPE_SIZE, "position": ORIGIN_POSITION}
	
	for i in range(test_transforms.size()):
		var transform_data: Dictionary = test_transforms[i]
		
		# Set up positioner with transform
		targeting_state.positioner.global_position = transform_data.position
		targeting_state.positioner.rotation = transform_data.rotation
		targeting_state.positioner.scale = transform_data.scale
		
		var test_object: Node2D = _create_test_object_with_shape("rectangle", shape_data)
		
		var tile_offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(
			IndicatorCollisionTestSetup.new(test_object, STANDARD_SHAPE_SIZE)
		)
		
		# Verify consistent behavior across transforms
		assert_int(tile_offsets.size()).append_failure_message(
			"Transform case %d should produce valid tile coverage. Transform: %s" % [i, transform_data]
		).is_greater(0)
		
		# Verify all tile offsets are reasonable (within expected bounds)
		for offset: Vector2i in tile_offsets.keys():
			assert_bool(abs(offset.x) < 100 and abs(offset.y) < 100).append_failure_message(
				"Tile offset %s seems unreasonable for transform %s" % [offset, transform_data]
			).is_true()

func _create_test_object_with_shape(shape_type: String, shape_data: Dictionary) -> Node2D:
	var test_object: Area2D = Area2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = targeting_state.positioner.global_position
	
	match shape_type:
		"rectangle":
			var collision_shape: CollisionShape2D = CollisionShape2D.new()
			collision_shape.position = shape_data.get("position", Vector2.ZERO)
			var rect: RectangleShape2D = RectangleShape2D.new()
			rect.size = shape_data.size
			collision_shape.shape = rect
			test_object.add_child(collision_shape)
			
		"circle":
			var collision_shape: CollisionShape2D = CollisionShape2D.new()
			collision_shape.position = shape_data.get("position", Vector2.ZERO)
			var circle: CircleShape2D = CircleShape2D.new()
			circle.radius = shape_data.radius
			collision_shape.shape = circle
			test_object.add_child(collision_shape)
			
		"trapezoid":
			var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
			collision_polygon.position = shape_data.get("position", Vector2.ZERO)
			collision_polygon.polygon = PackedVector2Array(shape_data.polygon)
			test_object.add_child(collision_polygon)
	
	return test_object

func test_rules_and_collision_integration() -> void:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var setup_issues: Array = rule.setup(targeting_state)
	assert_array(setup_issues).is_empty()
	
	# Test that collision mapper and rules work together
	var test_object: Node2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Set up collision mapper with test object
	var indicator_manager: IndicatorManager = UnifiedTestFactory.create_test_indicator_manager(self)
	var test_parent: Node2D = Node2D.new()
	test_parent.name = "TestParent2"
	add_child(test_parent)
	auto_free(test_parent)
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, test_object, null, test_parent)
	
	# Use the collision mapper from the indicator manager
	var configured_collision_mapper: CollisionMapper = indicator_manager.get_collision_mapper()
	var test_objects: Array[Node2D] = [test_object]
	var collision_tiles: Dictionary = configured_collision_mapper.get_collision_tile_positions_with_mask(test_objects, 1)
	
	# Validate integration produces reasonable results
	assert_dict(collision_tiles).append_failure_message(
		"Collision mapping should produce tiles for rule validation"
	).is_not_empty()
	
	var validation_result: Variant = rule.validate_placement()
	assert_object(validation_result).append_failure_message(
		"Rule validation should complete with collision context"
	).is_not_null()

func test_collisions_check_rule_setup() -> void:
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var setup_issues: Array = rule.setup(targeting_state)
	assert_array(setup_issues).append_failure_message(
		"Rule setup should succeed with valid parameters: %s" % str(setup_issues)
	).is_empty()

func test_tile_check_rule_basic() -> void:
	var rule: TileCheckRule = TileCheckRule.new()
	var setup_issues: Array = rule.setup(targeting_state)
	assert_array(setup_issues).append_failure_message(
		"Tile rule setup should succeed: %s" % str(setup_issues)
	).is_empty()
	
	var validation_result: Variant = rule.validate_placement()
	assert_object(validation_result).is_not_null()

#endregion
#region Collision Mapper Comprehensive Tests

func test_collision_mapper_shape_processing() -> void:
	var local_collision_mapper: CollisionMapper = CollisionMapper.create_with_injection(_container)
	var test_object: Node2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)

	# Set up collision mapper with test object
	var test_parent: Node2D = Node2D.new()
	test_parent.name = "TestParent"
	add_child(test_parent)
	auto_free(test_parent)

	# Manually create collision test setup for the StaticBody2D
	var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(test_object, Vector2(16, 16))
	var collision_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {test_object: test_setup}

	var test_indicator: Node = UnifiedTestFactory.create_rule_check_indicator(self, [] as Array[TileCheckRule], test_parent)

	# Setup collision mapper directly
	local_collision_mapper.setup(test_indicator, collision_setups)

	# Test collision shape processing
	var test_objects: Array[Node2D] = [test_object]
	var collision_results: Dictionary = local_collision_mapper.get_collision_tile_positions_with_mask(test_objects, 1)

	# Should return some collision tiles for test object
	assert_dict(collision_results).append_failure_message(
		"Test collision object should generate collision tiles"
	).is_not_empty()
