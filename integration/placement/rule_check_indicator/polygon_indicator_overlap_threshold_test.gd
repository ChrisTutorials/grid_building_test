## Regression test: Indicators must only be created on tiles with sufficient polygon overlap.
## This reproduces the in-game bug where extra indicators appear on tiles with negligible overlap.
extends GdUnitTestSuite

var _container : GBCompositionContainer
var _manager : IndicatorManager
var _map : TileMapLayer

func before_test():
    _container = preload("uid://dy6e5p5d6ax6n")
    
    # Create injector system for dependency injection
    _injector: Node = UnifiedTestFactory.create_test_injector(self, _container)
    
    _map = auto_free(TileMapLayer.new())
    _map.tile_set = TileSet.new()
    _map.tile_set.tile_size = Vector2tile_size
    add_child(_map)

    var tgt := _container.get_targeting_state()
    tgt.target_map = _map
    tgt.maps = [_map]
    if tgt.positioner == null:
        tgt.positioner = auto_free(Node2D.new())
        add_child(tgt.positioner)
    # Snap to a tile center for determinism
    tgt.positioner.global_position = _map.to_global(_map.map_to_local(Vector2i.ZERO))

    # Set up manipulation parent - required for IndicatorManager to have a parent node
    _container.get_states().manipulation.parent = tgt.positioner

    # Quiet debug spam
    _container.get_debug_settings().set_debug_level(GBDebugSettings.DebugLevel.ERROR)
    
    _manager = IndicatorManager.create_with_injection(_container)
    add_child(auto_free(_manager))

func _collect_indicators(pm: IndicatorManager) -> Array[Node2D][RuleCheckIndicator]:
    return pm.get_indicators() if pm else []

func _find_child_polygon(root: Node) -> CollisionPolygon2D:
    for c in root.get_children():
        if c is CollisionPolygon2D:
            return c
        var nested := _find_child_polygon(c)
        if nested:
            return nested
    return null

## Failing regression: with current mapper settings, indicators are created on tiles below a reasonable overlap threshold.
func test_polygon_preview_indicators_respect_min_overlap_ratio():
    # Arrange: create the preview under the active positioner like at runtime
    var preview: Node2D = UnifiedTestFactory.create_polygon_test_object(self)
    _container.get_targeting_state().positioner.add_child(preview)

    # Rule targeting mask bit 0 (matches demo object collision layer)
    var rule := CollisionsCheckRule.new()
    rule.apply_to_objects_mask = 1 << 0
    rule.collision_mask = 1 << 0
    var rules : Array[Node2D][PlacementRule] = [rule]
    
    # Init GBOnwner + Placer Root Node
    var placer: Node2D = auto_free(Node2D.new())
    add_child(placer)
    var gb_owner := GBOwner.new(placer)
    placer.add_child(gb_owner)
    auto_free(gb_owner)

    var setup_ok := _manager.try_setup(rules, _container.get_targeting_state(), true)
    assert_bool(setup_ok.is_successful()).append_failure_message("IndicatorManager.try_setup failed for polygon preview").is_true()

    var indicators: Array[Node2D][RuleCheckIndicator] = _collect_indicators(_manager)
    assert_array(indicators).append_failure_message("No indicators generated for polygon preview").is_not_empty()

    # Compute expected allowed tiles using a minimum overlap ratio (e.g., 12% of tile area)
    var poly := _find_child_polygon(preview)
    assert_object(poly).append_failure_message("Preview lacks CollisionPolygon2D child").is_not_null()
    var world_points := CollisionGeometryUtils.to_world_polygon(poly)
    var tile_size := Vector2(_map.tile_set.tile_size)
    var min_overlap_ratio := 0.12
    # Compute absolute tiles meeting the min overlap using calculator (area-based)
    var allowed_abs : Dictionary = {}
    var allowed_abs_tiles: Array[Node2D][Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
        world_points, tile_size, TileSet.TILE_SHAPE_SQUARE, 0.01, min_overlap_ratio
    )
    for abs_tile in allowed_abs_tiles:
        allowed_abs[str(abs_tile)] = true

    # Collect actual tiles from indicators
    var actual_tiles : Array[Node2D][Vector2i] = []
    for ind in indicators:
        var t := _map.local_to_map(_map.to_local(ind.global_position))
        if t not in actual_tiles:
            actual_tiles.append(t)

    # Any indicator tile not in allowed set is a failure (insufficient polygon overlap)
    var unexpected : Array[Node2D][Vector2i] = []
    for t in actual_tiles:
        if not allowed_abs.has(str(t)):
            unexpected.append(t)

    # This is expected to FAIL right now due to extra indicators in-game.
    assert_array(unexpected).append_failure_message(
        "Found indicators on tiles with insufficient overlap. unexpected=%s\nallowed_abs=%s\nactual=%s" % [str(unexpected), str(allowed_abs.keys()), str(actual_tiles)]
    ).is_empty()
