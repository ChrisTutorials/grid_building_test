extends GdUnitTestSuite

func _settings(active_when_off:=false, mouse_enabled:=true) -> GridTargetingSettings:
    var s := GridTargetingSettings.new()
    s.remain_active_in_off_mode = active_when_off
    s.enable_mouse_input = mouse_enabled
    return s

func test_visibility_reconcile_applies_when_differs() -> void:
    var s := _settings()
    var last := GBMouseInputStatus.new()
    last.allowed = true
    var res: Variant = GridPositionerLogic.visibility_reconcile(GBEnums.Mode.MOVE, s, false, last, false)
    assert_bool(res.apply).is_true()
    assert_bool(res.visible).is_true()
    assert_str(res.reason).is_equal("reconcile_should_be_visible")

func test_visibility_reconcile_noop_when_same() -> void:
    var s := _settings()
    var last := GBMouseInputStatus.new()
    last.allowed = true  # Set to true so should_be_visible returns true
    var res: Variant = GridPositionerLogic.visibility_reconcile(GBEnums.Mode.MOVE, s, true, last, false)
    assert_bool(res.apply).append_failure_message(
        "Visibility reconcile should return apply=false when current visibility matches expected - Mode: %s, CurrentVisible: %s, MouseAllowed: %s, ShouldBeVisible: should match CurrentVisible" % 
        [GBEnums.Mode.MOVE, true, last.allowed]
    ).is_false()

func test_recenter_decision_none() -> void:
    var d := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.NONE, false, true, true)
    assert_int(d).is_equal(GridPositionerLogic.RecenterDecision.NONE)

func test_recenter_decision_last_shown_prefers_cache() -> void:
    var d := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, true, true, true)
    assert_int(d).is_equal(GridPositionerLogic.RecenterDecision.LAST_SHOWN)

func test_recenter_decision_last_shown_fallback_mouse_then_center() -> void:
    var d1 := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, false, true, true)
    assert_int(d1).is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
    var d2 := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, false, false, false)
    assert_int(d2).is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)

func test_recenter_decision_mouse_cursor_prefers_cache_or_viewport() -> void:
    var d1 := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, true, true, false)
    assert_int(d1).is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
    var d2 := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, false, true, true)
    assert_int(d2).is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
    var d3 := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, false, false, false)
    assert_int(d3).is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)

func test_recenter_decision_view_center() -> void:
    var d := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER, false, true, true)
    assert_int(d).is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)
