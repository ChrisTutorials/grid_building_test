extends GdUnitTestSuite

## Consolidated tests for GridPositioner visibility logic and recenter decisions
## - Merged from several small files for maintainability
## - Keeps descriptive name (what is being tested) per repo convention

func _settings(hide_on_handled:=true, mouse_enabled:=true, active_when_off:=false) -> GridTargetingSettings:
    var s := GridTargetingSettings.new()
    s.hide_on_handled = hide_on_handled
    s.enable_mouse_input = mouse_enabled
    s.remain_active_in_off_mode = active_when_off
    return s

func _make_last_mouse(allowed: bool) -> GBMouseInputStatus:
    var last := GBMouseInputStatus.new()
    last.set_from_values(allowed, Vector2.ZERO, 0, "", Vector2.ZERO)
    return last

### Visibility on mouse event
func test_visibility_on_mouse_event_gate_blocked_mode_off_inactive() -> void:
    var settings := GridTargetingSettings.new()
    settings.enable_mouse_input = true
    settings.hide_on_handled = true
    var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, settings, false)
    assert_bool(res.apply).is_true()
    assert_bool(res.visible).is_false()
    assert_str(res.reason).contains("blocked")

func test_visibility_on_mouse_event_gate_allowed() -> void:
    var settings := GridTargetingSettings.new()
    settings.enable_mouse_input = true
    settings.hide_on_handled = true
    var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, settings, true)
    assert_bool(res.apply).is_true()
    assert_bool(res.visible).is_true()
    assert_str(res.reason).contains("allowed")

func test_visibility_on_mouse_event_no_settings_noop() -> void:
    var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, null, true)
    assert_bool(res.apply).is_false()

### Visibility on process tick
func test_process_tick_retain_after_allowed_mouse() -> void:
    var s := _settings(true, true)
    var last := _make_last_mouse(true)
    var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, true, last, false)
    assert_bool(res.apply).is_true()
    assert_bool(res.visible).is_true()
    assert_str(res.reason).is_equal("retain_from_last_mouse_allowed")

func test_process_tick_retain_from_cached_mouse() -> void:
    var s := _settings(true, true)
    var last := _make_last_mouse(false)
    var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, true, last, true)
    assert_bool(res.apply).append_failure_message("Expected process tick to apply visibility for cached mouse.").is_true()
    assert_bool(res.visible).append_failure_message("Expected process tick to show positioner for cached mouse.").is_true()
    assert_str(res.reason).is_equal("retain_from_cached_mouse_world")

func test_process_tick_noop_when_hide_on_handled_false() -> void:
    var s := _settings(false, true)
    var last := _make_last_mouse(true)
    var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, true, last, true)
    assert_bool(res.apply).is_false()

func test_process_tick_noop_when_input_not_ready() -> void:
    var s := _settings(true, true)
    var last := _make_last_mouse(true)
    var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, false, last, true)
    assert_bool(res.apply).is_false()

### Reconcile & recenter decisions
func test_visibility_reconcile_applies_when_differs() -> void:
    var s := _settings()
    var last := _make_last_mouse(true)
    var res: Variant = GridPositionerLogic.visibility_reconcile(GBEnums.Mode.MOVE, s, false, last, false)
    assert_bool(res.apply).is_true()
    assert_bool(res.visible).is_true()
    assert_str(res.reason).is_equal("reconcile_should_be_visible")

func test_visibility_reconcile_noop_when_same() -> void:
    var s := _settings()
    var last := _make_last_mouse(true)
    var res: Variant = GridPositionerLogic.visibility_reconcile(GBEnums.Mode.MOVE, s, true, last, false)
    assert_bool(res.apply).append_failure_message("Visibility reconcile should return apply=false when current visibility matches expected").is_false()

func test_recenter_decision_variants() -> void:
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.NONE, false, true, true)).is_equal(GridPositionerLogic.RecenterDecision.NONE)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, true, true, true)).is_equal(GridPositionerLogic.RecenterDecision.LAST_SHOWN)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, false, true, true)).is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, false, false, false)).is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, true, true, false)).is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, false, true, true)).is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, false, false, false)).is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)
    assert_int(GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER, false, true, true)).is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)
