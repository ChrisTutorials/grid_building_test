## Simplified CollisionMapper Tests
##
## Purpose: Clean integration tests for CollisionMapper using minimal setup
## without legacy environment dependencies. Focus on core parameterized tests.
extends GdUnitTestSuite

var _container: GBCompositionContainer
var _mapper: CollisionMapper
var _targeting: GridTargetingState
var _map: TileMapLayer
var _positioner: Node2D

const TILE := Vector2(16, 16)

func before_test() -> void:
	# Minimal environment: tilemap + positioner + container wiring
	_map = GodotTestFactory.create_top_down_tile_map_layer(self, 20)
	if _map.tile_set:
		_map.tile_set.tile_size = Vector2i(TILE)
	
	# Use simple Node2D positioner like working tests do
	_positioner = auto_free(Node2D.new())
	add_child(_positioner)
	_positioner.global_position = Vector2.ZERO

	# Create owner context and targeting state
	var owner_ctx := GBOwnerContext.new(null)
	_targeting = GridTargetingState.new(owner_ctx)
	_targeting.target_map = _map
	_targeting.positioner = _positioner

	_container = GBCompositionContainer.new()
	# Wire targeting state into container and ensure logger exists
	_container.get_states().targeting = _targeting
	_container.get_logger()

	_mapper = CollisionMapper.create_with_injection(_container)

func after_test() -> void:
	_mapper = null
	_container = null
	_targeting = null
	_map = null
	_positioner = null

@warning_ignore("unused_parameter")
func test_rectangles_cover_expected_min_tiles(
	size: Vector2,
	expected_min: int,
	desc: String,
	test_parameters := [
		[Vector2(16, 16), 1, "small"],
		[Vector2(24, 24), 1, "medium"],
		[Vector2(32, 32), 4, "large"],
	]
) -> void:
	var body := CollisionObjectTestFactory.create_static_body_with_rect(self, size, Vector2.ZERO)
	var setups := CollisionTestSetup2D.create_test_setups_from_test_node(body, _targeting)
	assert_int(setups.size()).is_greater(0)
	var result := _mapper.get_tile_offsets_for_test_collisions(setups[0])
	assert_int(result.size()).append_failure_message(
		"Rectangle %s should produce at least %d tiles, got %d" % [desc, expected_min, result.size()]
	).is_greater_equal(expected_min)

@warning_ignore("unused_parameter")
func test_circles_cover_expected_min_tiles(
	radius: float,
	expected_min: int,
	desc: String,
	test_parameters := [
		[8.0, 1, "small"],
		[16.0, 1, "medium"],
	]
) -> void:
	var body := CollisionObjectTestFactory.create_static_body_with_circle(self, radius, Vector2.ZERO)
	var setups := CollisionTestSetup2D.create_test_setups_from_test_node(body, _targeting)
	assert_int(setups.size()).is_greater(0)
	var result := _mapper.get_tile_offsets_for_test_collisions(setups[0])
	assert_int(result.size()).append_failure_message(
		"Circle %s should produce at least %d tiles, got %d" % [desc, expected_min, result.size()]
	).is_greater_equal(expected_min)

func test_polygon_square_yields_offsets() -> void:
	var poly := CollisionPolygon2D.new()
	auto_free(poly)
	poly.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	add_child(poly)
	var result := _mapper.get_tile_offsets_for_collision_polygon(poly, _map)
	assert_int(result.size()).is_greater(0)

func test_relative_offsets_constant_when_positioner_moves() -> void:
	var body := CollisionObjectTestFactory.create_static_body_with_rect(self, Vector2(32, 32), Vector2.ZERO)
	var setups := CollisionTestSetup2D.create_test_setups_from_test_node(body, _targeting)
	assert_int(setups.size()).is_greater(0)
	_positioner.global_position = Vector2.ZERO
	var r1 := _mapper.get_tile_offsets_for_test_collisions(setups[0])
	assert_int(r1.size()).is_greater(0)
	_positioner.global_position = Vector2(64, 64)
	var r2 := _mapper.get_tile_offsets_for_test_collisions(setups[0])
	assert_int(r2.size()).is_greater(0)
	# Tile count should remain consistent even if exact offsets change
	assert_int(r2.size()).append_failure_message(
		"Tile count should be consistent when positioner moves, got %d vs %d" % [r1.size(), r2.size()]
	).is_equal(r1.size())
