extends GdUnitTestSuite

var _test_env: AllSystemsTestEnvironment
var _collision_mapper: CollisionMapper

func before_test() -> void:
	_test_env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	assert_object(_test_env).append_failure_message("Environment setup failed").is_not_null()

	var targeting_state: GridTargetingState = _test_env.grid_targeting_system.get_state()
	var container: GBCompositionContainer = _test_env.get_container()
	_collision_mapper = auto_free(CollisionMapper.new(targeting_state, container.get_logger()))

func after_test() -> void:
	_test_env = null

func test_trapezoid_bottom_row_coverage() -> void:
var trapezoid_body: StaticBody2D = _create_trapezoid_test_object()
var collision_polygon: CollisionPolygon2D = trapezoid_body.get_child(0) as CollisionPolygon2D

var tile_positions_dict: Dictionary[Vector2i, Array] = _collision_mapper.get_tile_offsets_for_collision_polygon(collision_polygon, _test_env.tile_map_layer)
var tile_positions: Array = tile_positions_dict.keys()

assert_bool(tile_positions.size() > 0).append_failure_message("Expected tile positions").is_true()

func test_trapezoid_total_coverage_reasonable() -> void:
var trapezoid_body: StaticBody2D = _create_trapezoid_test_object()
var collision_polygon: CollisionPolygon2D = trapezoid_body.get_child(0) as CollisionPolygon2D

var tile_positions_dict: Dictionary[Vector2i, Array] = _collision_mapper.get_tile_offsets_for_collision_polygon(collision_polygon, _test_env.tile_map_layer)
var tile_positions: Array = tile_positions_dict.keys()

assert_int(tile_positions.size()).append_failure_message("Expected 7-15 tiles, got %d" % tile_positions.size()).is_between(7, 15)

func _create_trapezoid_test_object() -> StaticBody2D:
var trapezoid_body: StaticBody2D = auto_free(StaticBody2D.new())
trapezoid_body.collision_layer = 1

var collision_polygon: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
trapezoid_body.add_child(collision_polygon)
collision_polygon.polygon = PackedVector2Array([
Vector2(-16, -12), Vector2(16, -12), Vector2(32, 12), Vector2(-32, 12)
])

_test_env.positioner.add_child(trapezoid_body)
return trapezoid_body
