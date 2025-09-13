## Comprehensive consolidated collision mapper and polygon tile mapper tests
## Combines functionality from multiple individual test files
extends GdUnitTestSuite

# Test constants
const DEFAULT_TEST_POSITION := Vector2(64, 64)
const ORIGIN_POSITION := Vector2(0, 0)
const DEFAULT_TILE_SIZE := Vector2(32, 32)
const MAX_TILE_OFFSET := 10
const DEFAULT_COLLISION_MASK := 1

var env : CollisionTestEnvironment
var collision_mapper: CollisionMapper
var polygon_mapper: PolygonTileMapper
var logger: GBLogger
var targeting_state: GridTargetingState
var _container : GBCompositionContainer

## Test shape types enum for better type safety and maintainability
enum TestShapeType {
	RECTANGLE_SMALL,
	RECTANGLE_STANDARD, 
	RECTANGLE_LARGE,
	RECTANGLE_OFFSET,
	CIRCLE_SMALL,
	CIRCLE_MEDIUM,
	CIRCLE_LARGE,
	TRAPEZOID,
	CAPSULE
}

func before_test() -> void:
	# Create comprehensive test environment using DRY factory pattern
	env = UnifiedTestFactory.instance_collision_test_env(self, "uid://cdrtd538vrmun")
	_container = env.get_container()
	targeting_state = _container.get_states().targeting
	logger = _container.get_logger()
	collision_mapper = CollisionMapper.create_with_injection(_container)

	# Create polygon mapper from collision mapper
	polygon_mapper = PolygonTileMapper.new()

# ================================
# Comprehensive Shape Coverage Tests
# ================================

#region Comprehensive Shape Coverage Tests

## Test collision shape coverage with comprehensive shape types using enum
@warning_ignore("unused_parameter")
func test_collision_shape_coverage_comprehensive(
	shape_type: TestShapeType,
	shape_data: Dictionary,
	positioner_position: Vector2,
	expected_min_tiles: int,
	test_description: String,
	test_parameters := [
		[TestShapeType.RECTANGLE_SMALL, {"size": Vector2(16, 16)}, DEFAULT_TEST_POSITION, 1, "single_tile"],
		[TestShapeType.RECTANGLE_STANDARD, {"size": Vector2(32, 32)}, DEFAULT_TEST_POSITION, 4, "quad_tile"],
		[TestShapeType.RECTANGLE_LARGE, {"size": Vector2(64, 48)}, DEFAULT_TEST_POSITION, 8, "multi_tile"],
		[TestShapeType.CIRCLE_SMALL, {"radius": 8.0}, DEFAULT_TEST_POSITION, 1, "circular_small"],
		[TestShapeType.CIRCLE_MEDIUM, {"radius": 16.0}, DEFAULT_TEST_POSITION, 3, "circular_medium"],
		[TestShapeType.CIRCLE_LARGE, {"radius": 24.0}, DEFAULT_TEST_POSITION, 6, "circular_large"],
		[TestShapeType.TRAPEZOID, {"polygon": [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]}, DEFAULT_TEST_POSITION, 6, "complex_polygon"],
		[TestShapeType.RECTANGLE_OFFSET, {"size": Vector2(32, 32)}, ORIGIN_POSITION, 4, "origin_position"],
		[TestShapeType.CAPSULE, {"radius": 14.0, "height": 60.0}, DEFAULT_TEST_POSITION, 8, "capsule_shape"]
	]
) -> void:
	# Create test object with specified shape using enum-based helper method
	var test_object: Node2D = _create_test_object_with_shape_enum(shape_type, shape_data)
	
	# Run collision mapping test using DRY helper
	var result: Dictionary[Vector2i, Array] = _run_collision_mapping_test(test_object, expected_min_tiles)

	# Convert enum to string for error messages
	var shape_type_str : String = TestShapeType.keys()[shape_type]

	# Verify minimum tile coverage
	assert_int(result.size()).append_failure_message(
		"Expected at least %d tiles for %s shape, got %d" % [expected_min_tiles, shape_type_str, result.size()]
	).is_greater_equal(expected_min_tiles)

	# Verify position reasonableness
	var center_tile: Vector2i = env.tile_map_layer.local_to_map(test_object.global_position)
	for tile_pos : Vector2i in result.keys():
		var offset : Vector2i = tile_pos - center_tile
		assert_int(abs(offset.x)).append_failure_message(
			"Tile X offset too large for %s: %s" % [shape_type_str, offset]
		).is_less_equal(MAX_TILE_OFFSET)
		assert_int(abs(offset.y)).append_failure_message(
			"Tile Y offset too large for %s: %s" % [shape_type_str, offset]
		).is_less_equal(MAX_TILE_OFFSET)

#endregion
#region Positioner Movement Tests

## Test that collision detection updates when positioner moves
func test_positioner_movement_updates_collision() -> void:
	# Create collision object
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	
	var test_polygon := UnifiedTestFactory.create_test_collision_polygon(self)

			# Test case 3: Positioner at (0, 0)
	test_polygon.global_position = ORIGIN_POSITION
	var offsets1: Dictionary = collision_mapper.get_tile_offsets_for_collision_polygon(test_polygon, env.tile_map_layer)

	# Test case 2: Positioner at (64, 64)
	test_polygon.global_position = DEFAULT_TEST_POSITION
	var offsets2: Dictionary = collision_mapper.get_tile_offsets_for_collision_polygon(test_polygon, env.tile_map_layer)

	# Movement should produce different offsets
	assert_dict(offsets1).is_not_equal(offsets2)
	assert_dict(offsets1).is_not_empty()
	assert_dict(offsets2).is_not_empty()

## Test collision mapper tracks movement with different shapes
func test_collision_mapper_tracks_movement() -> void:
	# Create collision object
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(24, 24)
	area.add_child(collision_shape)
	env.level.add_child(area)

	# Test at different positions
	var positions: Array[Vector2] = [Vector2.ZERO, Vector2(32, 0), Vector2(64, 32)]
	var all_offsets: Array[Dictionary] = []

	for pos: Vector2 in positions:
		area.global_position = pos
		var test_setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(area, Vector2(24, 24))
		var offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		all_offsets.append(offsets)
		assert_dict(offsets).is_not_empty()

	# Each position should produce different results
	for i in range(all_offsets.size() - 1):
		assert_dict(all_offsets[i]).is_not_equal(all_offsets[i + 1])

# ================================
# Basic Collision Mapper Tests
# ================================

#region Basic Collision Mapper Tests

## Test collision mapper with polygon shapes
func test_collision_mapper_polygon() -> void:
	# Create area with polygon collision
	var area: Area2D = Area2D.new()
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-10, -10),
		Vector2(10, -10),
		Vector2(10, 10),
		Vector2(-10, 10)
	])
	area.add_child(collision_polygon)

	# Run collision mapping test using DRY helper
	_run_collision_mapping_test(area)

## Test collision mapper with multiple shapes
func test_collision_mapper_multiple_shapes() -> void:
	# Create area with multiple shapes
	var area: Area2D = Area2D.new()

	var shape1: CollisionShape2D = CollisionShape2D.new()
	shape1.shape = RectangleShape2D.new()
	shape1.shape.size = Vector2(24, 24)
	shape1.position = Vector2(-16, -16)
	area.add_child(shape1)

	var shape2: CollisionShape2D = CollisionShape2D.new()
	shape2.shape = RectangleShape2D.new()
	shape2.shape.size = Vector2(24, 24)
	shape2.position = Vector2(16, 16)
	area.add_child(shape2)

	# Run collision mapping test using DRY helper (expect more than 1 tile due to multiple shapes)
	var result: Dictionary[Vector2i, Array] = _run_collision_mapping_test(area, 2)
	assert_int(result.size()).is_greater(1)

#endregion
# ================================
# Trapezoid Regression Tests
# ================================

#region Trapezoid Regression Tests

## Test trapezoid core subset is present
func test_trapezoid_core_subset_present() -> void:
	var poly: CollisionPolygon2D = _create_trapezoid_node(true)
	var tile_dict: Dictionary = collision_mapper.get_tile_offsets_for_collision_polygon(poly, env.tile_map_layer)
	var offsets: Array[Vector2i] = []
	for k: Vector2i in tile_dict.keys(): offsets.append(k)
	offsets.sort()
	var core_required := [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]
	for req: Vector2i in core_required:
		assert_bool(offsets.has(req)).append_failure_message("Missing core tile %s -> offsets=%s" % [req, offsets]).is_true()

## Test trapezoid coverage stability
func test_trapezoid_coverage_stability() -> void:
	var poly: CollisionPolygon2D = _create_trapezoid_node(true)
	var tile_dict: Dictionary = collision_mapper.get_tile_offsets_for_collision_polygon(poly, env.tile_map_layer)
	assert_int(tile_dict.size()).is_greater_equal(6)
	assert_int(tile_dict.size()).is_less_equal(15)

#endregion
# ================================
# Polygon Tile Mapper Tests
# ================================

#region Polygon Tile Mapper Tests

## Test complete processing pipeline with representative polygon shapes
@warning_ignore("unused_parameter")
func test_process_polygon_complete_pipeline_scenarios(
	polygon_points: PackedVector2Array,
	global_position: Vector2,
	is_parented: bool,
	expected_properties: Dictionary,
	expected_min_offsets: int,
	test_description: String,
	test_parameters := [
		# Small square polygon - basic case
		[
			PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
			ORIGIN_POSITION,
			true,
			{"was_convex": true, "was_parented": true, "did_expand_trapezoid": false},
			4,
			"8x8 square at origin, parented"
		],
		# Large rectangle - should trigger area filtering
		[
			PackedVector2Array([Vector2(-32, -16), Vector2(32, -16), Vector2(32, 16), Vector2(-32, 16)]),
			ORIGIN_POSITION,
			true,
			{"was_convex": true, "was_parented": true},
			6,
			"64x32 rectangle at origin, parented"
		]
	]
) -> void:
	# Create polygon
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	poly.polygon = polygon_points
	if is_parented:
		env.level.add_child(poly)
	else:
		add_child(poly)
	poly.global_position = global_position

	# Process polygon
	var offsets: Array[Vector2i] = PolygonTileMapper.compute_tile_offsets(poly, env.tile_map_layer)

	# Verify results
	assert_int(offsets.size()).is_greater_equal(expected_min_offsets)
	assert_array(offsets).is_not_empty()

## Test tile shape drives mapping behavior
func test_tile_shape_drives_mapping() -> void:
	var map_layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	# Set tile_shape on tileset to isometric (1)
	map_layer.tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC

	# Simple square polygon centered at origin
	var poly: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

	var owner_context: GBOwnerContext = GBOwnerContext.new(null)
	var targeting_state_local: GridTargetingState = GridTargetingState.new(owner_context)
	targeting_state_local.positioner = GodotTestFactory.create_node2d(self)
	targeting_state_local.positioner.global_position = Vector2.ZERO

	var debug_settings: GBDebugSettings = GBDebugSettings.new()
	var _logger_local: GBLogger = GBLogger.new(debug_settings)
	var offsets: Array[Vector2i] = PolygonTileMapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()

## Test isometric tile shape produces offsets
func test_isometric_tile_shape_produces_offsets() -> void:
	# Create isometric tile map layer using DRY helper
	var map_layer: TileMapLayer = _create_isometric_tile_map_layer()

	# Build a simple polygon around origin (square) as CollisionPolygon2D
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	auto_free(poly)
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

	# Create dummy targeting state and positioner
	var owner_ctx: GBOwnerContext = GBOwnerContext.new(null)
	var targeting_state_local: GridTargetingState = GridTargetingState.new(owner_ctx)
	var positioner_node: Node2D = Node2D.new()
	auto_free(positioner_node)
	targeting_state_local.positioner = positioner_node
	targeting_state_local.positioner.global_position = Vector2.ZERO

	var debug_settings_local: GBDebugSettings = GBDebugSettings.new()
	var _logger_local: GBLogger = GBLogger.new(debug_settings_local)
	var offsets: Array[Vector2i] = PolygonTileMapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()

## Test tile shape preference from map
func test_tile_shape_preference_from_map() -> void:
	# Create a minimal TargetingState mock with positioner and settings
	var owner_ctx: GBOwnerContext = GBOwnerContext.new(null)
	var targeting_state_local: GridTargetingState = GridTargetingState.new(owner_ctx)

	# Create a TileSet resource and set it to ISOMETRIC
	var tileset: TileSet = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	# Create a TileMapLayer and assign tileset and tile_size
	var map: TileMapLayer = TileMapLayer.new()
	map.tile_set = tileset
	map.tile_set.tile_size = Vector2(32, 32)

	# Create a simple CollisionPolygon2D in world space near origin
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	poly.global_position = ORIGIN_POSITION

	# Mock positioner (centered over origin)
	var pos: Node2D = Node2D.new()
	pos.global_position = ORIGIN_POSITION
	targeting_state_local.positioner = pos
	targeting_state_local.target_map = map

	# Use a real logger for diagnostics
	var debug_settings_local: GBDebugSettings = GBDebugSettings.new()
	var _logger_local: GBLogger = GBLogger.new(debug_settings_local)

	var offsets: Array[Vector2i] = PolygonTileMapper.compute_tile_offsets(poly, map)
	# Expect some offsets to be returned for this small square-shaped polygon on isometric tiles
	assert_bool(offsets.size() > 0).append_failure_message("Expected offsets to be non-empty when map specifies isometric tile_shape").is_true()

#endregion
# ================================
# Helper Methods
# ================================

#region Helper Methods

## Create test object using CollisionObjectTestFactory methods directly
func _create_test_object_with_shape_enum(shape_type: TestShapeType, shape_data: Dictionary) -> Node2D:
	var test_object: Node2D
	var position: Vector2 = shape_data.get("position", Vector2.ZERO)
	
	# Use appropriate factory method based on shape type
	match shape_type:
		TestShapeType.RECTANGLE_SMALL:
			var size: Vector2 = shape_data.get("size", Vector2(16, 16))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.RECTANGLE_STANDARD:
			var size: Vector2 = shape_data.get("size", Vector2(32, 32))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.RECTANGLE_LARGE:
			var size: Vector2 = shape_data.get("size", Vector2(64, 48))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.RECTANGLE_OFFSET:
			var size: Vector2 = shape_data.get("size", Vector2(32, 32))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.CIRCLE_SMALL:
			var radius: float = shape_data.get("radius", 8.0)
			test_object = CollisionObjectTestFactory.create_static_body_with_circle(self, radius, position)
		
		TestShapeType.CIRCLE_MEDIUM:
			var radius: float = shape_data.get("radius", 16.0)
			test_object = CollisionObjectTestFactory.create_static_body_with_circle(self, radius, position)
		
		TestShapeType.CIRCLE_LARGE:
			var radius: float = shape_data.get("radius", 24.0)
			test_object = CollisionObjectTestFactory.create_static_body_with_circle(self, radius, position)
		
		TestShapeType.TRAPEZOID:
			var polygon: PackedVector2Array = PackedVector2Array(shape_data.get("polygon", [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]))
			test_object = CollisionObjectTestFactory.create_static_body_with_polygon(self, polygon, position)
		
		TestShapeType.CAPSULE:
			# Create capsule as rectangle for now (factory doesn't have capsule method)
			var size: Vector2 = shape_data.get("size", Vector2(16, 32))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
	
	# Remove from test suite parent since we'll be parenting it to the positioner
	if test_object.get_parent() == self:
		remove_child(test_object)
	
	return test_object

## Helper to robustly find a CollisionShape2D in the node hierarchy
func _find_collision_shape_2d(node: Node) -> CollisionShape2D:
	if node is CollisionShape2D:
		return node as CollisionShape2D
	
	for child in node.get_children():
		var found: CollisionShape2D = _find_collision_shape_2d(child)
		if found:
			return found
	
	return null

## Helper to robustly find a CollisionPolygon2D in the node hierarchy
func _find_collision_polygon_2d(node: Node) -> CollisionPolygon2D:
	if node is CollisionPolygon2D:
		return node as CollisionPolygon2D
	
	for child in node.get_children():
		var found: CollisionPolygon2D = _find_collision_polygon_2d(child)
		if found:
			return found
	
	return null

func _find_collision_objects(node: Node) -> Array[Node2D]:
	var collision_objects: Array[Node2D] = []
	if node is CollisionObject2D:
		collision_objects.append(node)
	for child in node.get_children():
		collision_objects.append_array(_find_collision_objects(child))
	return collision_objects

func _create_test_indicator() -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	add_child(indicator)
	return indicator

func _create_trapezoid_node(_parented := true) -> CollisionPolygon2D:
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	env.level.add_child(poly)
	return poly
	
func _create_collision_test_setup_dict(test_objects: Array[Node2D]) -> Dictionary[Node2D, IndicatorCollisionTestSetup]:
	var setup_dict: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for test_object in test_objects:
		var collision_objects: Array[Node2D] = _find_collision_objects(test_object)
		for collision_obj: Node2D in collision_objects:
			var setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(collision_obj, Vector2(32, 32))
			setup_dict[test_object] = setup
			break  # Use first collision object found for each test object
	return setup_dict

## Helper method for common collision mapping test pattern
func _run_collision_mapping_test(test_object: Node2D, expected_min_tiles: int = 1) -> Dictionary[Vector2i, Array]:
	# Add test object to level
	env.level.add_child(test_object)
	
	# Create collision test setup
	var collision_object_test_setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = _create_collision_test_setup_dict([test_object])
	var test_indicator: RuleCheckIndicator = UnifiedTestFactory.create_rule_check_indicator(self, [], self)
	
	# Setup collision mapper
	collision_mapper.setup(test_indicator, collision_object_test_setups)
	
	# Get collision results
	var result: Dictionary[Vector2i, Array] = collision_mapper.get_collision_tile_positions_with_mask([], DEFAULT_COLLISION_MASK)
	
	# Basic validation
	assert_int(result.size()).is_greater_equal(expected_min_tiles)
	assert_dict(result).is_not_empty()
	
	return result

func _create_collision_test_setup(test_object: Node2D) -> Array[Node2D]:
	var setups: Array[Node2D] = []
	var collision_objects: Array[Node2D] = _find_collision_objects(test_object)
	for collision_obj: Node2D in collision_objects:
		var setup: IndicatorCollisionTestSetup = IndicatorCollisionTestSetup.new(collision_obj, Vector2(32, 32))
		setups.append(setup)
	return setups

## Helper to create isometric TileMapLayer for testing
func _create_isometric_tile_map_layer() -> TileMapLayer:
	var map_layer: TileMapLayer = TileMapLayer.new()
	auto_free(map_layer)
	
	var tileset: TileSet = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	map_layer.tile_set = tileset
	
	return map_layer

#endregion