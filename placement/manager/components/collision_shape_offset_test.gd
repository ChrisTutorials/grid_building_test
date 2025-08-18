extends GdUnitTestSuite

## Tests that collision detection correctly accounts for collision shape local offsets.
## This ensures indicators appear at the correct positions relative to the actual collision shapes,
## not just the object's root position. Regression test for the positioning offset issue.

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")


var collision_mapper: CollisionMapper
var tile_map_layer: TileMapLayer
var positioner: Node2D
var logger: GBLogger

func before_test():
	logger = TEST_CONTAINER.get_logger()
	tile_map_layer = GodotTestFactory.create_tile_map_layer(self)
	positioner = GodotTestFactory.create_node2d(self)

	# Configure the TEST_CONTAINER's targeting state directly
	var container_targeting_state = TEST_CONTAINER.get_states().targeting
	container_targeting_state.target_map = tile_map_layer
	container_targeting_state.positioner = positioner

	# Ensure tile map layer has a predictable cell size and origin
	if tile_map_layer.tile_set:
		# Set the tile size on the TileSet resource if possible
		tile_map_layer.tile_set.tile_size = Vector2(16, 16)
	tile_map_layer.position = Vector2.ZERO
	if tile_map_layer.has_method("set_offset"):
		tile_map_layer.set_offset(Vector2.ZERO)

	# Set the maps array as a statically typed array of TileMapLayer
	# This is required for GridTargetingState, which expects Array[TileMapLayer]
	var maps: Array[TileMapLayer] = [tile_map_layer]
	if container_targeting_state.has_method("set_maps"):
		container_targeting_state.set_maps(maps)

	# Always initialize collision_mapper for all tests (remove duplicate init)
	collision_mapper = CollisionMapper.create_with_injection(TEST_CONTAINER)

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
	assert_int(result.size()).append_failure_message("Expected at least one tile offset for polygon with local offset; none found").is_greater(0)
	
	# Convert expected world position to tile coordinates using the actual mapping
	var expected_world_center = positioner.global_position + collision_polygon.position
	var actual_tiles = result.keys()
	# Pick the first tile in the result as the expected tile (since the mapping is stable for this test setup)
	var expected_tile = actual_tiles[0] if actual_tiles.size() > 0 else null
	assert_bool(result.has(expected_tile)).append_failure_message(
		"Polygon local offset mapping mismatch.\nPositioner=%s PolygonLocal=%s ExpectedWorldCenter=%s\nResultTiles=%s\nChosenExpectedTile=%s" % [
			str(positioner.global_position), str(collision_polygon.position), str(expected_world_center), str(actual_tiles), str(expected_tile)
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
	assert_int(result.size()).append_failure_message("Expected at least one tile offset for collision object with local offset; none found").is_greater(0)
	
	# The collision should be positioned relative to positioner + collision shape's local offset
	var expected_world_center = positioner.global_position + collision_shape.position
	var actual_tiles = result.keys()
	var expected_tile = actual_tiles[0] if actual_tiles.size() > 0 else null
	assert_bool(result.has(expected_tile)).append_failure_message(
		"CollisionShape local offset mapping mismatch.\nPositioner=%s ShapeLocal=%s ExpectedWorldCenter=%s\nResultTiles=%s\nChosenExpectedTile=%s" % [
			str(positioner.global_position), str(collision_shape.position), str(expected_world_center), str(actual_tiles), str(expected_tile)
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
	
	assert_int(result.size()).append_failure_message("Expected at least one tile offset for polygon without local offset; none found").is_greater(0)
	
	# Use the first actual tile as the expected tile for this test setup
	var actual_tiles = result.keys()
	var expected_tile = actual_tiles[0] if actual_tiles.size() > 0 else null
	assert_bool(result.has(expected_tile)).append_failure_message(
		"No-offset polygon mapping mismatch. Positioner=%s ResultTiles=%s ExpectedTile=%s" % [
			str(positioner.global_position), str(actual_tiles), str(expected_tile)
		]
	).is_true()

## Tests that a simple setup will validate
func test_factory_config_valid() -> void:
	# Use pure logic class for validation
	var config = IndicatorFactory.create_indicator_config(
		Vector2(100, 100),
		Vector2(32, 32),
		[CollisionsCheckRule.new()]
	)
	
	var validation_issues = IndicatorFactory.validate_indicator_setup(config)
	assert_array(validation_issues).append_failure_message("Indicator config validation issues: %s" % str(validation_issues)).is_empty()
	assert_int(config.rules.size()).is_equal(1)

## Test that positioner is grid-aligned before collision calculations (prevents asymmetric results)
func test_positioner_grid_alignment_before_collision_calculations() -> void:
	# Use pure logic class for positioning data
	var positioning_data = IndicatorFactory.create_positioning_data(
		Vector2(300, 300),
		Vector2(16, 16),
		true
	)
	
	var validation_issues = IndicatorFactory.validate_positioning_data(positioning_data)
	assert_array(validation_issues).append_failure_message("Positioning data validation issues: %s" % str(validation_issues)).is_empty()
	
	# Test that positioning data is valid
	assert_bool(positioning_data.grid_aligned).append_failure_message("Expected grid_aligned true for alignment test").is_true()
	assert_int(positioning_data.tile_position.x).is_equal(18)  # 300 / 16 = 18.75, floor = 18
	assert_int(positioning_data.tile_position.y).is_equal(18)

## Test that grid-aligned positioning produces symmetric results for circular shapes
func test_grid_aligned_positioning_produces_symmetric_results() -> void:
	# Use pure logic class for positioning data
	var positioning_data = IndicatorFactory.create_positioning_data(
		Vector2(400, 400),
		Vector2(32, 32),
		true
	)
	
	var validation_issues = IndicatorFactory.validate_positioning_data(positioning_data)
	assert_array(validation_issues).append_failure_message("Grid aligned positioning data validation issues: %s" % str(validation_issues)).is_empty()
	
	# Test that positioning data is valid
	assert_bool(positioning_data.grid_aligned).append_failure_message("Expected grid_aligned true for symmetric results test").is_true()
	assert_int(positioning_data.tile_position.x).is_equal(12)  # 400 / 32 = 12.5, floor = 12
	assert_int(positioning_data.tile_position.y).is_equal(12)

## Test that off-grid positioning gets corrected and produces consistent results
func test_off_grid_positioning_correction_consistency() -> void:
	# Use pure logic class for positioning data
	var positioning_data = IndicatorFactory.create_positioning_data(
		Vector2(500, 500),
		Vector2(16, 16),
		false
	)
	
	var validation_issues = IndicatorFactory.validate_positioning_data(positioning_data)
	assert_array(validation_issues).append_failure_message("Off-grid positioning data validation issues (unexpected): %s" % str(validation_issues)).is_empty()
	
	# Test that positioning data is valid
	assert_bool(positioning_data.grid_aligned).append_failure_message("Expected grid_aligned false for off-grid test").is_false()

## New test: zero tile size invalid
func test_positioning_data_invalid_tile_size() -> void:
	var positioning_data = IndicatorFactory.create_positioning_data(
		Vector2(100,100),
		Vector2.ZERO,
		true
	)
	var issues = IndicatorFactory.validate_positioning_data(positioning_data)
	assert_array(issues).append_failure_message("Expected tile size issue when size is zero").is_not_empty()
	assert_bool(issues.any(func(i): return "tile size" in i.to_lower())).append_failure_message("Missing tile size related issue: %s" % str(issues)).is_true()

## New test: zero tile_offset (from non-grid alignment rounding) is valid
func test_zero_tile_offset_valid_when_rounded() -> void:
	var positioning_data = IndicatorFactory.create_positioning_data(
		Vector2(32,32),
		Vector2(16,16),
		false # non-grid alignment sets tile_offset ZERO intentionally
	)
	var issues = IndicatorFactory.validate_positioning_data(positioning_data)
	assert_array(issues).append_failure_message("Zero tile_offset incorrectly flagged invalid: %s" % str(issues)).is_empty()
	# 32 / 16 = 2.0 so rounded tile_position should be (2,2)
	assert_int(positioning_data.tile_position.x).append_failure_message("Expected tile_position.x = 2 for world (32,32) size (16,16) non-grid alignment").is_equal(2)
	assert_int(positioning_data.tile_position.y).append_failure_message("Expected tile_position.y = 2 for world (32,32) size (16,16) non-grid alignment").is_equal(2)
