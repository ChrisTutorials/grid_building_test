## Regression test: Smithy should generate a solid 7x5 grid (35) of rule check indicators over its used area.
## Current behavior only generates indicators from the polygon layer; this test is expected to FAIL until fixed.
extends GdUnitTestSuite

var _container : GBCompositionContainer
var _manager : PlacementManager
var _map : TileMapLayer

func before_test():
    _container = preload("uid://dy6e5p5d6ax6n")
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
    # Snap to tile center for determinism
    tgt.positioner.global_position = _map.to_global(_map.map_to_local(Vector2i.ZERO))

    _container.get_debug_settings().set_debug_level(GBDebugSettings.DebugLevel.ERROR)

func _collect_indicators(pm: PlacementManager) -> Array[RuleCheckIndicator]:
    return pm.get_indicators() if pm else []

## Expected FAIL: only polygon contributes currently; Area2D rectangle (112x80) should produce 7x5=35 tiles.
func test_smithy_generates_full_rectangle_of_indicators():
    # Arrange preview under the active positioner
    var smithy: Node2D = UnifiedTestFactory.create_smithy_test_object(self)
    _container.get_targeting_state().positioner.add_child(smithy)

    # Rule mask includes both Area2D (2560) and StaticBody2D (513) layers of the Smithy
    var mask := 2560 | 513
    var rule := CollisionsCheckRule.new()
    rule.apply_to_objects_mask = mask
    rule.collision_mask = mask
    var rules: Array[PlacementRule] = [rule]
    # Use a local placer to avoid dependency on BuildingState owner_root
    var placer: Node2D = auto_free(Node2D.new())
    add_child(placer)
    var params := RuleValidationParameters.new(placer, smithy, _container.get_targeting_state(), _container.get_logger())
    var setup_ok := _manager.try_setup(rules, params, true)
    assert_bool(setup_ok).append_failure_message("PlacementManager.try_setup failed for Smithy preview").is_true()

    var indicators: Array[RuleCheckIndicator] = _collect_indicators(_manager)
    assert_array(indicators).append_failure_message("No indicators generated for Smithy; rule attach failed").is_not_empty()

    # Collect unique tiles actually produced
    var tiles: Array[Vector2i] = []
    for ind in indicators:
        var t := _map.local_to_map(_map.to_local(ind.global_position))
        if t not in tiles:
            tiles.append(t)

    # Compute the expected 7x5 rectangle directly from the Area2D RectangleShape2D transform
    var shape_owner := smithy.get_node_or_null("CollisionShape2D") as CollisionShape2D
    assert_object(shape_owner).append_failure_message("Smithy scene missing CollisionShape2D").is_not_null()
    var rect_shape := shape_owner.shape as RectangleShape2D
    assert_object(rect_shape).append_failure_message("Smithy CollisionShape2D is not a RectangleShape2D").is_not_null()

    var shape_xform := CollisionGeometryUtils.build_shape_transform(smithy, shape_owner)
    var center_tile := _map.local_to_map(_map.to_local(shape_xform.origin))
    var tile_size := _map.tile_set.tile_size
    var tiles_w := int(ceil(rect_shape.size.x / tile_size.x))
    var tiles_h := int(ceil(rect_shape.size.y / tile_size.y))
    # Make odd for symmetry if even
    if tiles_w % 2 == 0: tiles_w += 1
    if tiles_h % 2 == 0: tiles_h += 1
    var exp_min_x := center_tile.x - int(floor(tiles_w/2.0))
    var exp_min_y := center_tile.y - int(floor(tiles_h/2.0))
    var exp_max_x := exp_min_x + tiles_w - 1
    var exp_max_y := exp_min_y + tiles_h - 1

    var expected_count := tiles_w * tiles_h
    var expected_width := tiles_w
    var _expected_height := tiles_h

    # Build expected tile set and compute missing within the used-space rectangle
    var expected_tiles: Array[Vector2i] = []
    for x in range(exp_min_x, exp_max_x + 1):
        for y in range(exp_min_y, exp_max_y + 1):
            expected_tiles.append(Vector2i(x,y))

    var missing: Array[Vector2i] = []
    for pt in expected_tiles:
        if pt not in tiles:
            missing.append(pt)

    # Debug extras outside the used-space rectangle without failing
    var extras_top: Array[Vector2i] = []
    var extras_bottom: Array[Vector2i] = []
    var extras_left: Array[Vector2i] = []
    var extras_right: Array[Vector2i] = []
    for t in tiles:
        var inside := (t.x >= exp_min_x and t.x <= exp_max_x and t.y >= exp_min_y and t.y <= exp_max_y)
        if not inside:
            if t.y < exp_min_y: extras_top.append(t)
            elif t.y > exp_max_y: extras_bottom.append(t)
            elif t.x < exp_min_x: extras_left.append(t)
            elif t.x > exp_max_x: extras_right.append(t)

    if not extras_top.is_empty():
        print("[Smithy Debug] Extra tiles above expected rectangle:", extras_top)
    if not extras_bottom.is_empty():
        print("[Smithy Debug] Extra tiles below expected rectangle:", extras_bottom)
    if not extras_left.is_empty():
        print("[Smithy Debug] Extra tiles left of expected rectangle:", extras_left)
    if not extras_right.is_empty():
        print("[Smithy Debug] Extra tiles right of expected rectangle:", extras_right)

    # Assert required coverage (subset): all used-space tiles must be present
    assert_array(missing).append_failure_message("Missing used-space tiles for Smithy: %s" % [missing]).is_empty()
    # Explicitly assert bottom-middle is present for easier debugging
    var mid_x := exp_min_x + int(floor(expected_width/2.0))
    var bottom_middle := Vector2i(mid_x, exp_max_y)
    assert_bool(bottom_middle in tiles).append_failure_message("Bottom-middle tile missing: %s. Missing set=%s" % [bottom_middle, missing]).is_true()
    # Optional sanity: at least the rectangle tile count should be reached (extras allowed)
    assert_int(tiles.size()).append_failure_message("Expected at least %s indicators; got=%s" % [expected_count, tiles.size()]).is_greater_equal(expected_count)
