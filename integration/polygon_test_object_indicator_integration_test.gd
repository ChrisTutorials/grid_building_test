## Integration test: Ensure polygon_test_object concave CollisionPolygon2D produces <=12 indicators (was 19 runtime).
extends GdUnitTestSuite

const PLACEABLE_SCENE := preload("res://demos/top_down/objects/polygon_test_object.tscn")
const CONFIG_RES := preload("res://demos/top_down/placement/placeables/placeable_polygon_test_object.tres")

var _container : GBCompositionContainer
var _manager : PlacementManager
var _targeting : GridTargetingState
var _map : TileMapLayer

func before_test():
	# Use shared test container (uid preload if available); fallback skip if not present
	if ResourceLoader.exists("uid://dy6e5p5d6ax6n"):
		_container = preload("uid://dy6e5p5d6ax6n")
	else:
		return
	_manager = PlacementManager.create_with_injection(_container)
	add_child(auto_free(_manager))
	_targeting = _container.get_targeting_state()
	_map = _targeting.target_map
	# Ensure positioner exists; some test containers may require explicit creation
	if _targeting.positioner == null:
		var pos := Node2D.new()
		pos.name = "GridPositionerTest"
		pos.position = Vector2.ZERO
		add_child(pos)
		_targeting.positioner = pos

func _spawn_preview_instance() -> Node2D:
	var scene : PackedScene = PLACEABLE_SCENE
	var inst = scene.instantiate()
	if _targeting and _targeting.positioner:
		inst.global_position = _targeting.positioner.global_position
	add_child(inst)
	return inst

func test_concave_polygon_indicator_count_pruned():
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	var inst = _spawn_preview_instance()
	var poly : CollisionPolygon2D = null
	if inst.has_node("CollisionPolygon2D"):
		poly = inst.get_node("CollisionPolygon2D")
	assert_object(poly).append_failure_message("Test instance missing CollisionPolygon2D child").is_not_null()
	var mapper := CollisionMapper.create_with_injection(_container)
	# Provide a dummy rule so map_collision_positions_to_rules path executes
	var fake_rule := CollisionsCheckRule.new()
	var positions_to_rules := mapper.map_collision_positions_to_rules([poly], [fake_rule])
	var indicator_tile_count := positions_to_rules.size()
	assert_bool(indicator_tile_count <= 12).append_failure_message("Expected <=12 tiles for concave polygon but got %d with keys: %s" % [indicator_tile_count, positions_to_rules.keys()]).is_true()
	assert_int(indicator_tile_count).append_failure_message("Legacy over-generation (19) still present").is_not_equal(19)
	if indicator_tile_count > 12:
		print("Polygon indicator over-count debug: tiles=", positions_to_rules.keys())
