extends GdUnitTestSuite

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
