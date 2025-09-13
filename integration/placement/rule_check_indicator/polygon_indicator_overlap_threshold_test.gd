## Polygon Indicator Overlap Threshold Test
## Tests that indicators are only created on tiles with sufficient polygon overlap,
## preventing extra indicators from appearing on tiles with negligible overlap.
## This regression test reproduces and validates the fix for the in-game bug
## where indicators appeared on tiles below the minimum overlap threshold.
extends GdUnitTestSuite

const TILE_SIZE: Vector2 = Vector2(16, 16)
const MIN_OVERLAP_RATIO: float = 0.12
const COLLISION_LAYER_MASK: int = 1 << 0

var _container: GBCompositionContainer
var _manager: IndicatorManager
var _map: TileMapLayer

func before_test() -> void:
    _container = preload("uid://dy6e5p5d6ax6n")
    
    # Create injector system for dependency injection
    var _injector: Node = UnifiedTestFactory.create_test_injector(self, _container)
    
    _map = auto_free(TileMapLayer.new())
    _map.tile_set = TileSet.new()
    _map.tile_set.tile_size = TILE_SIZE
    add_child(_map)

    var tgt: GridTargetingState = _container.get_targeting_state()
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

# region Helper functions
func _collect_indicators(pm: IndicatorManager) -> Array[RuleCheckIndicator]:
    return pm.get_indicators() if pm else []

func _find_child_polygon(root: Node) -> CollisionPolygon2D:
    for c: Node in root.get_children():
        if c is CollisionPolygon2D:
            return c
        var nested: CollisionPolygon2D = _find_child_polygon(c)
        if nested:
            return nested
    return null

func _create_collision_rule() -> CollisionsCheckRule:
    var rule: CollisionsCheckRule = CollisionsCheckRule.new()
    rule.apply_to_objects_mask = COLLISION_LAYER_MASK
    rule.collision_mask = COLLISION_LAYER_MASK
    return rule

func _setup_gb_owner() -> GBOwner:
    var placer: Node2D = auto_free(Node2D.new())
    add_child(placer)
    var gb_owner: GBOwner = GBOwner.new(placer)
    placer.add_child(gb_owner)
    auto_free(gb_owner)
    return gb_owner
# endregion

## Failing regression: with current mapper settings, indicators are created on tiles below a reasonable overlap threshold.
func test_polygon_preview_indicators_respect_min_overlap_ratio() -> void:
    # Arrange: create the preview under the active positioner like at runtime
    var preview: Node2D = UnifiedTestFactory.create_polygon_test_object(self)
    _container.get_targeting_state().positioner.add_child(preview)

    # Create collision rule using helper
    var rule: CollisionsCheckRule = _create_collision_rule()
    var rules: Array[PlacementRule] = [rule]
    
    # Setup GB owner using helper
    var _gb_owner: GBOwner = _setup_gb_owner()

    var setup_ok: PlacementReport = _manager.try_setup(rules, _container.get_targeting_state(), true)
    assert_bool(setup_ok.is_successful()).append_failure_message("IndicatorManager.try_setup failed for polygon preview").is_true()

    var indicators: Array[RuleCheckIndicator] = _collect_indicators(_manager)
    assert_array(indicators).append_failure_message("No indicators generated for polygon preview").is_not_empty()

    # Compute expected allowed tiles using a minimum overlap ratio
    var poly: CollisionPolygon2D = _find_child_polygon(preview)
    assert_object(poly).append_failure_message("Preview lacks CollisionPolygon2D child").is_not_null()
    var world_points: PackedVector2Array = CollisionGeometryUtils.to_world_polygon(poly)
    var tile_size: Vector2 = Vector2(_map.tile_set.tile_size)
    # Compute absolute tiles meeting the min overlap using calculator (area-based)
    var allowed_abs: Dictionary = {}
    var allowed_abs_tiles: Array[Vector2i] = CollisionGeometryCalculator.calculate_tile_overlap(
        world_points, tile_size, TileSet.TILE_SHAPE_SQUARE, 0.01, MIN_OVERLAP_RATIO
    )
    for abs_tile: Vector2i in allowed_abs_tiles:
        allowed_abs[str(abs_tile)] = true

    # Collect actual tiles from indicators
    var actual_tiles: Array[Vector2i] = []
    for ind: RuleCheckIndicator in indicators:
        var t: Vector2i = _map.local_to_map(_map.to_local(ind.global_position))
        if t not in actual_tiles:
            actual_tiles.append(t)

    # Any indicator tile not in allowed set is a failure (insufficient polygon overlap)
    var unexpected: Array[Vector2i] = []
    for t: Vector2i in actual_tiles:
        if not allowed_abs.has(str(t)):
            unexpected.append(t)

    # This is expected to FAIL right now due to extra indicators in-game.
    assert_array(unexpected).append_failure_message(
        "Found indicators on tiles with insufficient overlap. unexpected=%s\nallowed_abs=%s\nactual=%s" % [str(unexpected), str(allowed_abs.keys()), str(actual_tiles)]
    ).is_empty()
