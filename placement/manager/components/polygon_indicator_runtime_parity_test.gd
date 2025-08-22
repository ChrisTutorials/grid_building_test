## Ensures runtime indicator generation matches polygon overlap semantics and preview alignment.
extends GdUnitTestSuite

var _container : GBCompositionContainer
var _building : BuildingSystem
var _manager : PlacementManager
var _map : TileMapLayer

func before_test():
	_container = preload("uid://dy6e5p5d6ax6n")
	_building = BuildingSystem.create_with_injection(_container)
	add_child(auto_free(_building))
	_manager = PlacementManager.create_with_injection(_container)
	add_child(auto_free(_manager))
	_map = auto_free(TileMapLayer.new())
	_map.tile_set = TileSet.new()
	_map.tile_set.tile_size = Vector2(16,16)
	add_child(_map)
	var tgt := _container.get_targeting_state()
	tgt.target_map = _map
	tgt.maps = [_map]
	if tgt.positioner == null:
		tgt.positioner = auto_free(Node2D.new())
		add_child(tgt.positioner)
	# Snap positioner to (0,0) center tile
	tgt.positioner.global_position = _map.to_global(_map.map_to_local(Vector2i.ZERO))

func _collect_indicators(pm: PlacementManager) -> Array[RuleCheckIndicator]:
	return pm.get_indicators() if pm else []

func test_polygon_object_only_generates_overlapping_indicators_and_aligns_preview():
	var placeable := Placeable.new()
	placeable.packed_scene = load("res://demos/top_down/objects/polygon_test_object.tscn")
	var ok := _building.enter_build_mode(placeable)
	assert_bool(ok).append_failure_message("enter_build_mode failed").is_true()

	# Acquire preview and set up indicators via PlacementManager
	var preview := _container.get_building_state().preview as Node2D
	assert_object(preview).append_failure_message("Preview missing after enter_build_mode").is_not_null()

	# Build basic collisions rule targeting layer bit 0 (to match demo object)
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var rules : Array[PlacementRule] = [rule]
	var params := RuleValidationParameters.new(_container.get_building_state().get_placer(), preview, _container.get_targeting_state(), _container.get_logger())
	var setup_ok := _manager.try_setup(rules, params, true)
	assert_bool(setup_ok).append_failure_message("PlacementManager.try_setup failed").is_true()

	var indicators := _collect_indicators(_manager)
	assert_array(indicators).append_failure_message("No indicators generated for polygon preview").is_not_empty()

	# Compute world polygon for overlap checks
	var poly: CollisionPolygon2D = null
	for c in preview.get_children():
		if c is CollisionPolygon2D:
			poly = c; break
	assert_object(poly).append_failure_message("Preview lacks CollisionPolygon2D child").is_not_null()
	var gx := poly.get_global_transform()
	var world_points := PackedVector2Array()
	for p in poly.polygon:
		world_points.append(gx * p)

	var tile_size := Vector2(16,16)
	var min_area := tile_size.x * tile_size.y * 0.05
	var non_overlapping : Array[String] = []
	for ind in indicators:
		var center: Vector2 = ind.global_position
		var top_left := center - tile_size*0.5
		var area := GBGeometryMath.intersection_area_with_tile(world_points, top_left, tile_size, 0)
		if area < min_area:
			non_overlapping.append("%s@%s area=%.3f" % [ind.name, str(_map.local_to_map(_map.to_local(center))), area])

	assert_int(non_overlapping.size())\
		.append_failure_message("Found indicators on tiles without sufficient overlap (>=5%%); details=\n" + "\n".join(non_overlapping))\
		.is_equal(0)

	# Alignment: at least one indicator should share the positioner center tile
	var center_tile := _map.local_to_map(_container.get_targeting_state().positioner.global_position)
	var any_center := false
	for ind in indicators:
		var t := _map.local_to_map(ind.global_position)
		if t == center_tile:
			any_center = true; break
	assert_bool(any_center).append_failure_message("No indicator aligned to positioner center tile").is_true()
