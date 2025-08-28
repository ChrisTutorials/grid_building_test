extends GdUnitTestSuite

## Comprehensive consolidated collision mapper and polygon tile mapper tests
## Combines functionality from multiple individual test files:
## - collision_mapper_consolidated_comprehensive_test.gd
## - collision_mapper_positioner_movement_refactored.gd
## - collision_mapper_refactored.gd
## - collision_mapper_trapezoid_regression_test.gd
## - polygon_tile_mapper_test.gd
## - polygon_tile_mapper_tile_shape_test.gd
## - polygon_tile_mapper_tile_shape_propagation_test.gd
## - polygon_tile_mapper_isometric_test.gd

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var test_hierarchy: Dictionary
var collision_mapper: CollisionMapper
var polygon_mapper: PolygonTileMapper
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger
var targeting_state: GridTargetingState
var _injector: GBInjectorSystem

func before_test():
	# Create test infrastructure using factories
	_injector = UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)

	# Create tilemap with standard 16x16 tiles
	tile_map_layer = GodotTestFactory.create_tile_map_layer(self, 40)

	# Create positioner at test position near origin for predictable offsets
	positioner = GodotTestFactory.create_node2d(self)
	positioner.global_position = Vector2(64, 64)  # Tile (4, 4) for reasonable offsets

	# Create targeting state
	var owner_context = GBOwnerContext.new(null)
	targeting_state = TEST_CONTAINER.get_states().targeting
	targeting_state._owner_context = owner_context
	targeting_state.target_map = tile_map_layer
	targeting_state.positioner = positioner
	targeting_state.maps = [tile_map_layer]

	# Create collision mapper and polygon mapper
	collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)
	polygon_mapper = PolygonTileMapper.new(targeting_state, logger)

	# Store in test hierarchy for compatibility
	test_hierarchy = {
		"collision_mapper": collision_mapper,
		"polygon_mapper": polygon_mapper,
		"tile_map": tile_map_layer,
		"positioner": positioner,
		"logger": logger,
		"targeting_state": targeting_state
	}

func after_test():
	# Cleanup handled by auto_free in factory methods
	pass

# ================================
# Collision Shape Coverage Tests
# ================================

## Test collision shape coverage with various shapes and positions
@warning_ignore("unused_parameter")
func test_collision_shape_coverage_comprehensive(
	shape_type: String,
	shape_data: Dictionary,
	positioner_position: Vector2,
	expected_min_tiles: int,
	expected_behavior: String,
	test_parameters := [
		["rectangle_small", {"size": Vector2(16, 16)}, Vector2(64, 64), 1, "single_tile"],
		["rectangle_standard", {"size": Vector2(32, 32)}, Vector2(64, 64), 4, "quad_tile"],
		["rectangle_large", {"size": Vector2(64, 48)}, Vector2(64, 64), 8, "multi_tile"],
		["circle_small", {"radius": 8.0}, Vector2(64, 64), 1, "circular_small"],
		["circle_medium", {"radius": 16.0}, Vector2(64, 64), 3, "circular_medium"],
		["circle_large", {"radius": 24.0}, Vector2(64, 64), 6, "circular_large"],
		["trapezoid", {"polygon": [Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]}, Vector2(64, 64), 6, "complex_polygon"],
		["rectangle_offset", {"size": Vector2(32, 32)}, Vector2(0, 0), 4, "origin_position"],
		["capsule", {"radius": 14.0, "height": 60.0}, Vector2(64, 64), 8, "capsule_shape"]
	]
):
	# Set positioner position for test
	positioner.global_position = positioner_position

	# Create test object with specified shape
	var test_object = _create_test_object_with_shape(shape_type, shape_data)

	# Setup collision mapper
	var collision_object_test_setups = _create_collision_test_setup(test_object)
	var test_indicator = _create_test_indicator()
	collision_mapper.setup(test_indicator, collision_object_test_setups)

	# Get collision tile positions
	var result = collision_mapper.get_collision_tile_positions_with_mask([test_object], 1)

	# Verify expected behavior
	assert_int(result.size()).append_failure_message(
		"Expected at least %d tiles for %s shape, got %d" % [expected_min_tiles, shape_type, result.size()]
	).is_greater_equal(expected_min_tiles)

	# Verify position reasonableness
	var center_tile = tile_map_layer.local_to_map(positioner_position)
	for tile_pos in result.keys():
		var offset = tile_pos - center_tile
		assert_int(abs(offset.x)).append_failure_message(
			"Tile X offset too large for %s: %s" % [shape_type, offset]
		).is_less_equal(10)
		assert_int(abs(offset.y)).append_failure_message(
			"Tile Y offset too large for %s: %s" % [shape_type, offset]
		).is_less_equal(10)

# ================================
# Positioner Movement Tests
# ================================

## Test that collision detection updates when positioner moves
func test_positioner_movement_updates_collision():
	var positioner = test_hierarchy.positioner
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map

	# Create collision object
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	positioner.add_child(collision_polygon)

	# Test case 1: Positioner at (0, 0)
	positioner.global_position = Vector2(0, 0)
	var offsets1 = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map)

	# Test case 2: Positioner moved to (32, 32)
	positioner.global_position = Vector2(32, 32)
	var offsets2 = collision_mapper._get_tile_offsets_for_collision_polygon(collision_polygon, tile_map)

	# Movement should produce different offsets
	assert_dict(offsets1).is_not_equal(offsets2)
	assert_dict(offsets1).is_not_empty()
	assert_dict(offsets2).is_not_empty()

## Test collision mapper tracks movement with different shapes
func test_collision_mapper_tracks_movement():
	var positioner = test_hierarchy.positioner
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map

	# Create collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(24, 24)
	area.add_child(collision_shape)
	positioner.add_child(area)

	# Test at different positions
	var positions = [Vector2.ZERO, Vector2(32, 0), Vector2(64, 32)]
	var all_offsets = []

	for pos in positions:
		positioner.position = pos
		var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(24, 24), test_hierarchy.logger)
		var offsets = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map)
		all_offsets.append(offsets)
		assert_dict(offsets).is_not_empty()

	# Each position should produce different results
	for i in range(all_offsets.size() - 1):
		assert_dict(all_offsets[i]).is_not_equal(all_offsets[i + 1])

# ================================
# Basic Collision Mapper Tests
# ================================

## Test basic collision mapper functionality
func test_collision_mapper_basic():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner

	# Create simple collision object
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	collision_shape.shape.size = Vector2(32, 32)
	area.add_child(collision_shape)
	positioner.add_child(area)

	# Create test setup for collision mapper
	var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(32, 32), test_hierarchy.logger)

	# Test basic collision mapping
	var offsets = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map)
	assert_dict(offsets).is_not_empty()

## Test collision mapper with polygon shapes
func test_collision_mapper_polygon():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner

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

	positioner.add_child(area)

	# Create test setup for collision mapper
	var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(32, 32), test_hierarchy.logger)

	var offsets = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map)
	assert_dict(offsets).is_not_empty()

## Test collision mapper with multiple shapes
func test_collision_mapper_multiple_shapes():
	var collision_mapper = test_hierarchy.collision_mapper
	var tile_map = test_hierarchy.tile_map
	var positioner = test_hierarchy.positioner

	# Create area with multiple shapes
	var area = Area2D.new()

	var shape1 = CollisionShape2D.new()
	shape1.shape = RectangleShape2D.new()
	shape1.shape.size = Vector2(16, 16)
	shape1.position = Vector2(-20, 0)
	area.add_child(shape1)

	var shape2 = CollisionShape2D.new()
	shape2.shape = RectangleShape2D.new()
	shape2.shape.size = Vector2(16, 16)
	shape2.position = Vector2(20, 0)
	area.add_child(shape2)

	positioner.add_child(area)

	# Create test setup for collision mapper
	var test_setup = IndicatorCollisionTestSetup.new(area, Vector2(32, 32), test_hierarchy.logger)

	var offsets = collision_mapper._get_tile_offsets_for_collision_object(test_setup, tile_map)
	assert_int(offsets.size()).is_greater(1)

# ================================
# Trapezoid Regression Tests
# ================================

## Test trapezoid core subset is present
func test_trapezoid_core_subset_present():
	var poly = _create_trapezoid_node(true)
	var tile_dict = collision_mapper._get_tile_offsets_for_collision_polygon(poly, tile_map_layer)
	var offsets: Array[Vector2i] = []
	for k in tile_dict.keys(): offsets.append(k)
	offsets.sort()
	var core_required := [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]
	for req in core_required:
		assert_bool(offsets.has(req)).append_failure_message("Missing core tile %s -> offsets=%s" % [req, offsets]).is_true()

## Test trapezoid coverage stability
func test_trapezoid_coverage_stability():
	var poly = _create_trapezoid_node(true)
	var tile_dict = collision_mapper._get_tile_offsets_for_collision_polygon(poly, tile_map_layer)
	assert_int(tile_dict.size()).is_greater_equal(6)
	assert_int(tile_dict.size()).is_less_equal(15)

# ================================
# Polygon Tile Mapper Tests
# ================================

## Test complete processing pipeline with representative polygon shapes
@warning_ignore("unused_parameter")
func test_process_polygon_complete_pipeline_scenarios(
	polygon_points: PackedVector2Array,
	positioner_pos: Vector2,
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
	# Set positioner position
	positioner.global_position = positioner_pos

	# Create polygon
	var poly = CollisionPolygon2D.new()
	poly.polygon = polygon_points
	if is_parented:
		positioner.add_child(poly)
	else:
		add_child(poly)

	# Process polygon
	var offsets = polygon_mapper.compute_tile_offsets(poly, tile_map_layer)

	# Verify results
	assert_int(offsets.size()).is_greater_equal(expected_min_offsets)
	assert_array(offsets).is_not_empty()

## Test tile shape drives mapping behavior
func test_tile_shape_drives_mapping():
	var map_layer: TileMapLayer = GodotTestFactory.create_empty_tile_map_layer(self)
	# Set tile_shape on tileset to isometric (1)
	map_layer.tile_set.tile_shape = TileSet.TileShape.TILE_SHAPE_ISOMETRIC

	# Simple square polygon centered at origin
	var poly: CollisionPolygon2D = GodotTestFactory.create_collision_polygon(self, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

	var owner_context = GBOwnerContext.new(null)
	var targeting_state = GridTargetingState.new(owner_context)
	targeting_state.positioner = GodotTestFactory.create_node2d(self)
	targeting_state.positioner.global_position = Vector2.ZERO

	var debug_settings = GBDebugSettings.new()
	var logger = GBLogger.new(debug_settings)
	var mapper = PolygonTileMapper.new(targeting_state, logger)
	var offsets = mapper.compute_tile_offsets(poly, map_layer)
	assert_array(offsets).is_not_empty()

## Test isometric tile shape produces offsets
func test_isometric_tile_shape_produces_offsets():
	# Create fake TileMapLayer with a TileSet that exposes tile_shape
	var map_layer = Node.new() as TileMapLayer
	# Create a minimal TileSet resource and attach a tile_shape property
	var ts = TileSet.new()
	# Set tile shape to isometric
	ts.tile_shape = TileSet.TileShape.TILE_SHAPE_ISOMETRIC
	map_layer.tile_set = ts

	# Build a simple polygon around origin (square) as CollisionPolygon2D
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

	# Create dummy targeting state and positioner
	var owner_ctx = GBOwnerContext.new(null)
	var targeting_state_local = GridTargetingState.new(owner_ctx)
	targeting_state_local.positioner = Node2D.new()
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
	map.tile_set.tile_size = Vector2(32, 32)

	# Create a simple CollisionPolygon2D in world space near origin
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	poly.global_position = Vector2(0,0)

	# Mock positioner (centered over origin)
	var pos = Node2D.new()
	pos.global_position = Vector2(0,0)
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

func _create_test_object_with_shape(shape_type: String, shape_data: Dictionary) -> Node2D:
	var test_object = Node2D.new()
	add_child(test_object)

	match shape_type:
		"rectangle_small", "rectangle_standard", "rectangle_large", "rectangle_offset":
			var collision_shape = CollisionShape2D.new()
			collision_shape.shape = RectangleShape2D.new()
			collision_shape.shape.size = shape_data.size
			test_object.add_child(collision_shape)
		"circle_small", "circle_medium", "circle_large":
			var collision_shape = CollisionShape2D.new()
			collision_shape.shape = CircleShape2D.new()
			collision_shape.shape.radius = shape_data.radius
			test_object.add_child(collision_shape)
		"capsule":
			var collision_shape = CollisionShape2D.new()
			collision_shape.shape = CapsuleShape2D.new()
			collision_shape.shape.radius = shape_data.radius
			collision_shape.shape.height = shape_data.height
			test_object.add_child(collision_shape)
		"trapezoid":
			var collision_polygon = CollisionPolygon2D.new()
			collision_polygon.polygon = PackedVector2Array(shape_data.polygon)
			test_object.add_child(collision_polygon)

	positioner.add_child(test_object)
	return test_object

func _create_collision_test_setup(test_object: Node2D) -> Array:
	var setups = []
	var collision_objects = _find_collision_objects(test_object)
	for collision_obj in collision_objects:
		var setup = IndicatorCollisionTestSetup.new(collision_obj, Vector2(32, 32), logger)
		setups.append(setup)
	return setups

func _find_collision_objects(node: Node) -> Array:
	var collision_objects = []
	if node is CollisionObject2D:
		collision_objects.append(node)
	for child in node.get_children():
		collision_objects.append_array(_find_collision_objects(child))
	return collision_objects

func _create_test_indicator() -> Node2D:
	var indicator = Node2D.new()
	add_child(indicator)
	return indicator

func _create_trapezoid_node(parented := true) -> CollisionPolygon2D:
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)])
	if parented:
		positioner.add_child(poly)
	else:
		add_child(poly)
	return poly
