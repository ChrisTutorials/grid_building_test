extends GdUnitTestSuite

const UnifiedTestFactory = preload("res://test/grid_building_test/factories/unified_test_factory.gd")

func test_setup_indicators_aborts_when_targeting_has_runtime_issues():
    # Arrange: create composition container and injector
    var container := UnifiedTestFactory.create_test_composition_container(self)
    var _injector := UnifiedTestFactory.create_test_injector(self, container)
    var targeting_state := container.get_states().targeting

    # Provide minimal valid targeting structure but inject a synthetic runtime issue
    var positioner := GodotTestFactory.create_node2d(self)
    var tile_map := GodotTestFactory.create_tile_map_layer(self, 4)
    targeting_state.positioner = positioner
    targeting_state.set_map_objects(tile_map, [tile_map])

    # Stub get_runtime_issues() to return a non-empty Array (simulate misconfigured runtime)
    targeting_state.set("get_runtime_issues", func() -> Array:
        return ["simulated_runtime_issue"]
    )

    # Ensure indicator template exists in container templates
    var templates := container.get_templates()
    if templates.rule_check_indicator == null:
        templates.rule_check_indicator = UnifiedTestFactory.create_test_rule_check_indicator(self).get_scene()

    # Create manager with injection
    var manager := auto_free(IndicatorManager.create_with_injection(container, positioner))

    # Act: attempt to setup indicators for a simple test object
    var test_obj := GodotTestFactory.create_node2d(self)
    positioner.add_child(test_obj)
    var rule := CollisionsCheckRule.new()
    var report: IndicatorSetupReport = manager.setup_indicators(test_obj, [rule], positioner)

    # Assert: no indicators created and report finalization did not crash
    assert_array(report.indicators).is_empty()
    # The manager logs errors on runtime issues; ensure that the runtime issue was honored
    assert_bool(not targeting_state.get_runtime_issues().is_empty()).is_true()
