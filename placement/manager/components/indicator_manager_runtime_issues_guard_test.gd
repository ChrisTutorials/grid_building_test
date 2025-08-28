extends GdUnitTestSuite

const UnifiedTestFactory = preload("res://test/grid_building_test/factories/unified_test_factory.gd")

func test_setup_indicators_aborts_when_targeting_has_runtime_issues():
    # Arrange: create composition container and injector
    var container := UnifiedTestFactory.create_test_composition_container(self)
    var _injector := UnifiedTestFactory.create_test_injector(self, container)
    var targeting_state := container.get_states().targeting

    # Provide minimal valid targeting structure but inject a synthetic runtime issue
    var positioner: Node2D = GodotTestFactory.create_node2d(self)
    # Don't set tile_map to create a runtime issue (target_map will be null)
    # var tile_map: TileMapLayer = GodotTestFactory.create_tile_map_layer(self, 4)
    targeting_state.positioner = positioner
    # targeting_state.set_map_objects(tile_map, [tile_map])  # Commented out to create runtime issue

    # Don't stub get_runtime_issues() - let it naturally detect the null target_map

    # Ensure indicator template exists in container templates
    var templates := container.get_templates()
    if templates.rule_check_indicator == null:
        # Create a minimal indicator instance wrapped in a new scene to satisfy template requirement
        var indicator := UnifiedTestFactory.create_test_rule_check_indicator(self)
        var ps := PackedScene.new()
        ps.pack(indicator)
        templates.rule_check_indicator = ps

    # Create manager with injection
    var manager: IndicatorManager = auto_free(IndicatorManager.create_with_injection(container, positioner))

    # Act: attempt to setup indicators for a simple test object
    var test_obj: Node2D = GodotTestFactory.create_node2d(self)
    # Remove from test suite parent before adding to positioner
    test_obj.get_parent().remove_child(test_obj)
    positioner.add_child(test_obj)
    var rule := CollisionsCheckRule.new()
    var report: IndicatorSetupReport = manager.setup_indicators(test_obj, [rule], positioner)

    # Assert: no indicators created and report finalization did not crash
    assert_array(report.indicators).is_empty()
    # The manager should detect runtime issues (null target_map) naturally
    assert_bool(not targeting_state.get_runtime_issues().is_empty()).is_true()
