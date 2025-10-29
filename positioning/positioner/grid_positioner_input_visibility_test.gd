extends GdUnitTestSuite

func _make_settings(active_when_off:=true, hide_on_handled:=true, mouse_enabled:=true) -> GridTargetingSettings:
	var s := GridTargetingSettings.new()
	s.remain_active_in_off_mode = active_when_off
	s.hide_on_handled = hide_on_handled
	s.enable_mouse_input = mouse_enabled
	return s

func test_off_mode_active_should_be_visible() -> void:
	var s := _make_settings(true, true, true)
	var last := GBMouseInputStatus.new(); last.set_from_values(false, Vector2.ZERO, 0, "", Vector2.ZERO)
	assert_bool(GridPositionerLogic.should_be_visible(GBEnums.Mode.OFF, s, last, false)).append_failure_message("OFF mode with active_when_off=true should be visible").is_true()
	assert_bool(GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.OFF, s)).append_failure_message("OFF mode with active_when_off=true should be visible for mode only")\
		.is_true()

func test_off_mode_inactive_should_be_hidden() -> void:
	var s := _make_settings(false, true, true)
	var last := GBMouseInputStatus.new(); last.set_from_values(false, Vector2.ZERO, 0, "", Vector2.ZERO)
	assert_bool(GridPositionerLogic.should_be_visible(GBEnums.Mode.OFF, s, last, false)).append_failure_message("OFF mode with active_when_off=false should be hidden").is_false()
	assert_bool(GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.OFF, s)).append_failure_message("OFF mode with active_when_off=false should be hidden for mode only")\
		.is_false()

func test_mouse_event_gate_allowed_off_active_shows() -> void:
	var s := _make_settings(true, true, true)
	# Test allowed input
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, s, true)
	assert_bool(res.apply).append_failure_message("Allowed mouse event in OFF mode should apply visibility change").is_true()
	assert_bool(res.visible).append_failure_message("Allowed mouse event in OFF mode should show positioner").is_true()
	assert_str(res.reason).contains("allowed")

func test_mouse_event_gate_blocked_off_inactive_hides() -> void:
	var s := _make_settings(false, true, true)
	# Test blocked input
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, s, false)
	assert_bool(res.apply).append_failure_message("Blocked mouse event in OFF mode should apply visibility change").is_true()
	assert_bool(res.visible).append_failure_message("Blocked mouse event in OFF mode should hide positioner").is_false()
	assert_str(res.reason).contains("blocked")

func test_mouse_event_noop_when_hide_on_handled_false() -> void:
	var s := _make_settings(true, false, true)
	# When hide_on_handled is false, should not apply any visibility changes
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, s, true)
	assert_bool(res.apply).append_failure_message("When hide_on_handled=false, mouse events should not apply visibility changes")\
		.is_false()

# Test: hide_on_handled should not apply when mouse input is disabled
# Setup: hide_on_handled=true, mouse_enabled=false, blocked mouse input status
# Act: Call should_be_visible in BUILD mode
# Assert: Should remain visible despite blocked mouse input
func test_hide_on_handled_ignored_when_mouse_disabled() -> void:
	var settings := _make_settings(true, true, false)  # active_when_off=true, hide_on_handled=true, mouse_enabled=false
	var blocked_mouse_status := GBMouseInputStatus.new()
	blocked_mouse_status.set_from_values(false, Vector2.ZERO, 0, "blocked", Vector2.ZERO)  # blocked input

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.BUILD, settings, blocked_mouse_status, false)

 assert_bool(result).append_failure_message( "When mouse input is disabled, hide_on_handled should not apply even with blocked mouse input status. " + "Settings: hide_on_handled=%s, mouse_enabled=%s, mouse_status.allowed=%s" % [str(settings.hide_on_handled), str(settings.enable_mouse_input), str(blocked_mouse_status.allowed)] ) # Test: hide_on_handled should still apply when mouse input is enabled (regression test) # Setup: hide_on_handled=true, mouse_enabled=true, blocked mouse input status # Act: Call should_be_visible in BUILD mode # Assert: Should be hidden due to blocked mouse input func test_hide_on_handled_applies_when_mouse_enabled() -> void: var settings := _make_settings(true, true, true) # active_when_off=true, hide_on_handled=true, mouse_enabled=true var blocked_mouse_status := GBMouseInputStatus.new() blocked_mouse_status.set_from_values(false, Vector2.ZERO, 0, "blocked", Vector2.ZERO) # blocked input var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.BUILD, settings, blocked_mouse_status, false) assert_bool(result)\
	.is_false().append_failure_message( "When mouse input is enabled, hide_on_handled should still apply with blocked mouse input status. " + "Settings: hide_on_handled=%s, mouse_enabled=%s, mouse_status.allowed=%s" % [str(settings.hide_on_handled), str(settings.enable_mouse_input), str(blocked_mouse_status.allowed)] ).is_true()