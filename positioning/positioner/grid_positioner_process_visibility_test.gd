extends GdUnitTestSuite

# Helper to create minimal settings
func _settings(hide_on_handled:=true, mouse_enabled:=true, active_when_off:=false) -> GridTargetingSettings:
	var s := GridTargetingSettings.new()
	s.hide_on_handled = hide_on_handled
	s.enable_mouse_input = mouse_enabled
	s.remain_active_in_off_mode = active_when_off
	return s

func test_process_tick_retain_after_allowed_mouse() -> void:
	var s := _settings(true, true)
	var last := GBMouseInputStatus.new(); last.set_from_values(true, Vector2.ZERO, 0, "", Vector2.ZERO)
	var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, true, last, false)
	assert_bool(res.apply).is_true()
	assert_bool(res.visible).is_true()
	assert_str(res.reason).is_equal("retain_from_last_mouse_allowed")

func test_process_tick_retain_from_cached_mouse() -> void:
	var s := _settings(true, true)
	var last := GBMouseInputStatus.new(); last.set_from_values(false, Vector2.ZERO, 0, "", Vector2.ZERO)
	var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, true, last, true)
	assert_bool(res.apply).append_failure_message("Expected process tick to apply visibility for cached mouse. Settings: hide_on_handled=%s, mouse_enabled=%s, has_mouse_world=true, last_mouse_allowed=%s" % [str(s.hide_on_handled), str(s.enable_mouse_input), str(last.allowed)]).is_true()
	assert_bool(res.visible).append_failure_message("Expected process tick to show positioner for cached mouse. Result: apply=%s, reason=%s" % [str(res.apply), str(res.reason)]).is_true()
	assert_str(res.reason).append_failure_message("Expected 'retain_from_cached_mouse_world' reason, got '%s'. Result: apply=%s, visible=%s" % [str(res.reason), str(res.apply), str(res.visible)]).is_equal("retain_from_cached_mouse_world")

func test_process_tick_noop_when_hide_on_handled_false() -> void:
	var s := _settings(false, true)
	var last := GBMouseInputStatus.new(); last.set_from_values(true, Vector2.ZERO, 0, "", Vector2.ZERO)
	var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, true, last, true)
	assert_bool(res.apply).is_false()

func test_process_tick_noop_when_input_not_ready() -> void:
	var s := _settings(true, true)
	var last := GBMouseInputStatus.new(); last.set_from_values(true, Vector2.ZERO, 0, "", Vector2.ZERO)
	var res: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, s, false, last, true)
	assert_bool(res.apply).is_false()
