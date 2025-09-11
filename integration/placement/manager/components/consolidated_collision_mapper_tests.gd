## Comprehensive consolidated collision mapper and polygon tile mapper tests
## Combines functionality from multiple individual test files
extends GdUnitTestSuite

var env : CollisionTestEnvironment
var collision_mapper: CollisionMapper
var polygon_mapper: PolygonTileMapper
var logger: GBLogger
var targeting_state: GridTargetingState
var _injector: GBInjectorSystem
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

func before_test():
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

## Test collision shape coverage with comprehensive shape types using enum
@warning_ignore("unused_parameter")
func test_collision_shape_coverage_comprehensive(
	shape_type: TestShapeType,
	shape_data: Dictionary,
	positioner_position: Vector2,
	expected_min_tiles: int,
	test_description: String,
	test_parameters := [
		[TestShapeType.RECTANGLE_SMALL, {"size": Vector2(16, 16)}, Vector2(64, 64), 1, "single_tile"],
		[TestShapeType.RECTANGLE_STANDARD, {"size": Vector2(32, 32)}, Vector2(64, 64), 4, "quad_tile"],
		[TestShapeType.RECTANGLE_LARGE, {"size": Vector2(64, 48)}, Vector2(64, 64), 8, "multi_tile"],
		[TestShapeType.CIRCLE_SMALL, {"radius": 8.0}, Vector2(64, 64), 1, "circular_small"],
		[TestShapeType.CIRCLE_MEDIUM, {"radius": 16.0}, Vector2(64, 64), 3, "circular_medium"],
		[TestShapeType.CIRCLE_LARGE, {"radius": 24.0}, Vector2(64, 64), 6, "circular_large"],
		[TestShapeType.TRAPEZOID, {"polygon": [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]}, Vector2(64, 64), 6, "complex_polygon"],
		[TestShapeType.RECTANGLE_OFFSET, {"size": Vector2(32, 32)}, Vector2(0, 0), 4, "origin_position"],
		[TestShapeType.CAPSULE, {"radius": 14.0, "height": 60.0}, Vector2(64, 64), 8, "capsule_shape"]
	]
):
	# Create test object with specified shape using enum-based helper method
	test_object: Node = _create_test_object_with_shape_enum(shape_type, shape_data)
	env.level.add_child(test_object)

	# Setup collision mapper with Dictionary format
	var collision_object_test_setups = _create_collision_test_setup_dict([test_object])
	var test_indicator = UnifiedTestFactory.create_rule_check_indicator(self, self, [])
	
	collision_mapper.setup(test_indicator, collision_object_test_setups)

	# Get collision results
	var result = collision_mapper.get_collision_tile_positions_with_mask([], 1)

	# Convert enum to string for error messages
	var shape_type_str = TestShapeType.keys()[shape_type]

	# Verify minimum tile coverage
	assert_int(result.size()).append_failure_message(
		"Expected at least %d tiles for %s shape, got %d" % [expected_min_tiles, shape_type_str, result.size()]
	).is_greater_equal(expected_min_tiles)

	# Verify position reasonableness
	var center_tile = env.tile_map_layer.local_to_map(test_object.global_position)
	for tile_pos in result.keys():
		var offset = tile_pos - center_tile
		assert_int(abs(offset.x)).append_failure_message(
			"Tile X offset too large for %s: %s" % [shape_type_str, offset]
		).is_less_equal(10)
		assert_int(abs(offset.y)).append_failure_message(
			"Tile Y offset too large for %s: %s" % [shape_type_str, offset]
		).is_less_equal(10)

# ================================
# Positioner Movement Tests
# ================================

## Test that collision detection updates when positioner moves
func test_positioner_movement_updates_collision():
	# Create collision object
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	
	var test_polygon := UnifiedTestFactory.create_test_collision_polygon(self)

		# Test case 1: Positioner at (0, 0)
	test_polygon.global_position = Vector2.ZERO
	var offsets1 = collision_mapper.get_tile_offsets_for_collision_polygon(test_polygon, env.tile_map_layer)

	# Test case 2: Positioner at (64, 64)
	test_polygon.global_position = Vector2global_position
	var offsets2 = collision_mapper.get_tile_offsets_for_collision_polygon(test_polygon, env.tile_map_layer)

	# Movement should produce different offsets
	assert_dict(offsets1).is_not_equal(offsets2)
	assert_dict(offsets1).is_not_empty()
	assert_dict(offsets2).is_not_empty()

## Test collision mapper tracks movement with different shapes
func test_collision_mapper_tracks_movement():
	# Create collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2size
	area.add_child(collision_shape)
	env.level.add_child(area)

	# Test at different positions
	var positions = [Vector2.ZERO, Vector2(32, 0), Vector2(64, 32)]
	var all_offsets = []

	for pos in positions:
		area.global_position = pos
		var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(24, 24))
		var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		all_offsets.append(offsets)
		assert_dict(offsets).is_not_empty()

	# Each position should produce different results
	for i in range(all_offsets.size() - 1):
		assert_dict(all_offsets[i]).is_not_equal(all_offsets[i + 1])

# ================================
# Basic Collision Mapper Tests
# ================================

## Test collision mapper with polygon shapes
func test_collision_mapper_polygon():
	# Create area with polygon collision
	var area = Area2D.new()
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-10, -10),
		Vector2(10, -10),
		Vector2(10, 10),
		Vector2(-10, 10)
	])
	area.add_child(collision_polygon)
	env.level.add_child(area)

	# Create test setup for collision mapper
	var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(32, 32))

	var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup, env.tile_map_layer)
	assert_dict(offsets).is_not_empty()

## Test collision mapper with multiple shapes
func test_collision_mapper_multiple_shapes():
	# Create area with multiple shapes
	var area = Area2D.new()

	var shape1 = CollisionShape2D.new()
	shape1.shape = RectangleShape2D.new()
	shape1.shape.size = Vector2size
	shape1.position = Vector2position
	area.add_child(shape1)

	var shape2 = CollisionShape2D.new()
	shape2.shape = RectangleShape2D.new()
	shape2.shape.size = Vector2size
	shape2.position = Vector2position
	area.add_child(shape2)
	env.level.add_child(area)

	# Create test setup for collision mapper
	var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(32, 32))

	var offsets = collision_mapper.get_tile_offsets_for_test_collisions(test_setup, env.tile_map_layer)
	assert_int(offsets.size()).is_greater(1)

# ================================
# Trapezoid Regression Tests
# ================================

## Test trapezoid core subset is present
func test_trapezoid_core_subset_present():
	var poly = _create_trapezoid_node(true)
	var tile_dict = collision_mapper.get_tile_offsets_for_collision_polygon(poly, env.tile_map_layer)
	var offsets: Array[Vector2i] = []
	for k in tile_dict.keys(): offsets.append(k)
	offsets.sort()
	var core_required := [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]
	for req in core_required:
		assert_bool(offsets.has(req)).append_failure_message("Missing core tile %s -> offsets=%s" % [req, offsets]).is_true()

## Test trapezoid coverage stability
func test_trapezoid_coverage_stability():
	var poly = _create_trapezoid_node(true)
	var tile_dict = collision_mapper.get_tile_offsets_for_collision_polygon(poly, env.tile_map_layer)
	assert_int(tile_dict.size()).is_greater_equal(6)
	assert_int(tile_dict.size()).is_less_equal(15)

# ================================
# Polygon Tile Mapper Tests
# ================================

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
			Vector2(0, 0),
			true,
			{"was_convex": true, "was_parented": true, "did_expand_trapezoid": false},
			4,
			"8x8 square at origin, parented"
		],
		# Large rectangle - should trigger area filtering
		[
			PackedVector2Array([Vector2(-32, -16), Vector2(32, -16), Vector2(32, 16), Vector2(-32, 16)]),
			Vector2(0, 0),
			true,
			{"was_convex": true, "was_parented": true},
			6,
			"64x32 rectangle at origin, parented"
		]
	]
):
	# Create polygon
	var poly = CollisionPolygon2D.new()
	poly.polygon = polygon_points
	if is_parented:
		env.level.add_child(poly)
	else:
		add_child(poly)
	poly.global_position = global_position

	# Process polygon
	var offsets = polygon_mapper.compute_tile_offsets(poly, env.tile_map_layer)

	# Verify results
	assert_int(offsets.size()).is_greater_equal(expected_min_offsets)
	assert_array(offsets).is_not_empty()

## Test tile shape drives mapping behavior
func test_tile_shape_drives_mapping():
	var map_layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	# Set tile_shape on tileset to isometric (1)
	map_layer.tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC

	# Simple square polygon centered at origin
	var poly: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

	var owner_context = GBOwnerContext.new(null)
	var targeting_state_local = GridTargetingState.new(owner_context)
	targeting_state_local.positioner = GodotTestFactory.create_node2d(self)
	targeting_state_local.positioner.global_position = Vector2.ZERO

	var debug_settings = GBDebugSettings.new()
	var logger_local = GBLogger.new(debug_settings)
	var mapper = PolygonTileMapper.new(targeting_state_local, logger_local)
	var offsets = mapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()

## Test isometric tile shape produces offsets
func test_isometric_tile_shape_produces_offsets():
	# Create a proper TileMapLayer with a TileSet that exposes tile_shape
	var map_layer = TileMapLayer.new()
	auto_free(map_layer)
	
	# Create a minimal TileSet resource and attach a tile_shape property
	var ts = TileSet.new()
	# Set tile shape to isometric
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	map_layer.tile_set = ts

	# Build a simple polygon around origin (square) as CollisionPolygon2D
	var poly = CollisionPolygon2D.new()
	auto_free(poly)
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

	# Create dummy targeting state and positioner
	var owner_ctx = GBOwnerContext.new(null)
	var targeting_state_local = GridTargetingState.new(owner_ctx)
	var positioner_node = Node2D.new()
	auto_free(positioner_node)
	targeting_state_local.positioner = positioner_node
	targeting_state_local.positioner.global_position = Vector2.ZERO

	var debug_settings_local = GBDebugSettings.new()
	var logger_local = GBLogger.new(debug_settings_local)
	var mapper = PolygonTileMapper.new(targeting_state_local, logger_local)
	var offsets = mapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()

## Test tile shape preference from map
func test_tile_shape_preference_from_map():
	# Create a minimal TargetingState mock with positioner and settings
	var owner_ctx = GBOwnerContext.new()
	var targeting_state_local = GridTargetingState.new(owner_ctx)

	# Create a TileSet resource and set it to ISOMETRIC
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	# Create a TileMapLayer and assign tileset and tile_size
	var map := TileMapLayer.new()
	map.tile_set = tileset
	map.tile_set.tile_size = Vector2tile_size

	# Create a simple CollisionPolygon2D in world space near origin
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	poly.global_position = Vector2global_position

	# Mock positioner (centered over origin)
	var pos = Node2D.new()
	pos.global_position = Vector2global_position
	targeting_state_local.positioner = pos
	targeting_state_local.target_map = map

	# Use a real logger for diagnostics
	var debug_settings_local = GBDebugSettings.new()
	var logger_local = GBLogger.new(debug_settings_local)

	var mapper = PolygonTileMapper.new(targeting_state_local, logger_local)
	var offsets = mapper.compute_tile_offsets(poly, map)
	# Expect some offsets to be returned for this small square-shaped polygon on isometric tiles
	assert_bool(offsets.size() > 0).append_failure_message("Expected offsets to be non-empty when map specifies isometric tile_shape").is_true()

# ================================
# Helper Methods
# ================================

## Create test object using CollisionObjectTestFactory methods directly
func _create_test_object_with_shape_enum(shape_type: TestShapeType, shape_data: Dictionary) -> Node2D:
	var test_object: Node2D
	var position: Vector2 = shape_data.get("position", Vector2.ZERO)
	
	# Use appropriate factory method based on shape type
	match shape_type:
		TestShapeType.RECTANGLE_SMALL:
			var size = shape_data.get("size", Vector2(16, 16))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.RECTANGLE_STANDARD:
			var size = shape_data.get("size", Vector2(32, 32))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.RECTANGLE_LARGE:
			var size = shape_data.get("size", Vector2(64, 48))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.RECTANGLE_OFFSET:
			var size = shape_data.get("size", Vector2(32, 32))
			test_object = CollisionObjectTestFactory.create_static_body_with_rect(self, size, position)
		
		TestShapeType.CIRCLE_SMALL:
			var radius = shape_data.get("radius", 8.0)
			test_object = CollisionObjectTestFactory.create_static_body_with_circle(self, radius, position)
		
		TestShapeType.CIRCLE_MEDIUM:
			var radius = shape_data.get("radius", 16.0)
			test_object = CollisionObjectTestFactory.create_static_body_with_circle(self, radius, position)
		
		TestShapeType.CIRCLE_LARGE:
			var radius = shape_data.get("radius", 24.0)
			test_object = CollisionObjectTestFactory.create_static_body_with_circle(self, radius, position)
		
		TestShapeType.TRAPEZOID:
			var polygon = PackedVector2Array(shape_data.get("polygon", [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]))
			test_object = CollisionObjectTestFactory.create_static_body_with_polygon(self, polygon, position)
		
		TestShapeType.CAPSULE:
			# Create capsule as rectangle for now (factory doesn't have capsule method)
			var size = shape_data.get("size", Vector2(16, 32))
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
		var found = _find_collision_shape_2d(child)
		if found:
			return found
	
	return null

## Helper to robustly find a CollisionPolygon2D in the node hierarchy
func _find_collision_polygon_2d(node: Node) -> CollisionPolygon2D:
	if node is CollisionPolygon2D:
		return node as CollisionPolygon2D
	
	for child in node.get_children():
		var found = _find_collision_polygon_2d(child)
		if found:
			return found
	
	return null

func _find_collision_objects(node: Node) -> Array[Node2D]:
	var collision_objects = []
	if node is CollisionObject2D:
		collision_objects.append(node)
	for child in node.get_children():
		collision_objects.append_array(_find_collision_objects(child))
	return collision_objects

func _create_test_indicator() -> RuleCheckIndicator:
	var indicator = RuleCheckIndicator.new()
	add_child(indicator)
	return indicator

func _create_trapezoid_node(parented := true) -> CollisionPolygon2D:
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	env.level.add_child(poly)
	return poly
	
func _create_collision_test_setup_dict(test_objects: Array[Node2D]) -> Dictionary[Node2D, IndicatorCollisionTestSetup]:
	var setup_dict: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	for test_object in test_objects:
		var collision_objects = _find_collision_objects(test_object)
		for collision_obj in collision_objects:
			var setup = IndicatorCollisionTestSetup.new(collision_obj, Vector2(32, 32))
			setup_dict[test_object] = setup
			break  # Use first collision object found for each test object
	return setup_dict

func _create_collision_test_setup(test_object: Node2D) -> Array[Node2D]:
	var setups = []
	var collision_objects = _find_collision_objects(test_object)
	for collision_obj in collision_objects:
		var setup = IndicatorCollisionTestSetup.new(collision_obj, Vector2(32, 32))
		setups.append(setup)
	return setups
