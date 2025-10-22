extends GdUnitTestSuite

## Parameterized tests that lock in current behavior around small-overlap thresholds.
## These assert the behavior of CollisionGeometryCalculator.polygon_overlaps_rect when
## the overlap area is near configured min_overlap_ratio values (especially <= 0.05).

@warning_ignore("unused_parameter")
func test_polygon_overlap_threshold(
    points_array: Array[Vector2],
    min_overlap_ratio: float,
    expected: bool,
    description: String = "",
    test_parameters := [
        # 1) large triangle (area 0.5) should pass any small threshold
        [[Vector2(0,0), Vector2(1,0), Vector2(0,1)], 0.05, true, "half-area triangle (0.5) vs 5%"],
        # 2) small triangle area=0.04 (base=1, height=0.08) -- below 5% but epsilon logic applies
        [[Vector2(0,0), Vector2(1,0), Vector2(0,0.08)], 0.05, true, "area=0.04 vs 5% (epsilon path)"],
        # 3) same small triangle but higher threshold (10%) -> should fail
        [[Vector2(0,0), Vector2(1,0), Vector2(0,0.08)], 0.10, false, "area=0.04 vs 10% (strict)"],
        # 4) triangle area=0.3125 (base=1, height=0.625) -> passes 25%
        [[Vector2(0,0), Vector2(1,0), Vector2(0,0.625)], 0.25, true, "area=0.3125 vs 25%"],
        # 5) same triangle but threshold 35% -> fail
        [[Vector2(0,0), Vector2(1,0), Vector2(0,0.625)], 0.35, false, "area=0.3125 vs 35%"],
        # 6) very small triangle area=0.0125 (base=1, height=0.025) -> epsilon path should allow
        [[Vector2(0,0), Vector2(1,0), Vector2(0,0.025)], 0.05, true, "area=0.0125 vs 5% (epsilon)"],
        # 7) same tiny triangle but threshold above epsilon applicability -> fail
        [[Vector2(0,0), Vector2(1,0), Vector2(0,0.025)], 0.06, false, "area=0.0125 vs 6% (strict)"],
    ]
) -> void:
    # Arrange
    var poly: PackedVector2Array = PackedVector2Array()
    for i in range(points_array.size()):
        var p: Vector2 = points_array[i]
        poly.append(p)

    var rect := Rect2(Vector2(0,0), Vector2(1,1))

    # Act
    var result: bool = CollisionGeometryCalculator.polygon_overlaps_rect(poly, rect, 0.01, min_overlap_ratio)

    # For helpful diagnostics include computed clipped area in messages
    var clipped := CollisionGeometryCalculator.clip_polygon_to_rect(poly, rect)
    clipped = CollisionGeometryCalculator._sanitize_polygon(clipped)
    var clipped_area := CollisionGeometryCalculator.polygon_area(clipped)

    # Assert
    assert_bool(result).append_failure_message(
        "%s | clipped_area=%.6f min_ratio=%.3f expected=%s" % [description, clipped_area, min_overlap_ratio, str(expected)]
    ).is_equal(expected)