extends GdUnitTestSuite

func test_visibility_on_mouse_event_gate_blocked_mode_off_inactive() -> void:
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	settings.hide_on_handled = true
	var gate := MouseGateResult.new(false, GBEnums.MouseGateReason.MODE_OFF_INACTIVE, GridPositionerLogic.mouse_gate_reason_to_string(GBEnums.MouseGateReason.MODE_OFF_INACTIVE))
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, settings, gate)
	assert_bool(res.apply).is_true()
	assert_bool(res.visible).is_false()
	assert_str(res.reason).contains("mode_off_inactive")

func test_visibility_on_mouse_event_gate_allowed() -> void:
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	settings.hide_on_handled = true
	var gate := MouseGateResult.new(true, GBEnums.MouseGateReason.OK, GridPositionerLogic.mouse_gate_reason_to_string(GBEnums.MouseGateReason.OK))
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, settings, gate)
	assert_bool(res.apply).is_true()
	assert_bool(res.visible).is_true()
	assert_str(res.reason).contains("OK")

func test_visibility_on_mouse_event_no_settings_noop() -> void:
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, null, MouseGateResult.new(true, GBEnums.MouseGateReason.OK, "OK"))
	assert_bool(res.apply).is_false()
