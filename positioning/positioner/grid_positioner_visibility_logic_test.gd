## Unit tests for GridPositionerLogic static functions.
##
## Tests visibility computation logic in isolation without requiring
## a full GridPositioner2D instance.
##
## ⚠️ NOTE: This file's tests may be partially duplicated in
## grid_positioner_visibility_and_logic_test.gd (consolidated suite).
## Consider merging redundant test cases or removing this file if fully superseded.
extends GdUnitTestSuite

func test_should_be_visible_off_mode_active_when_off() -> void:
	var settings := GridTargetingSettings.new()
	settings.remain_active_in_off_mode = true
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.OFF, settings, last_mouse, has_mouse)
	assert_bool(result).append_failure_message("Positioner should be visible in OFF mode when remain_active_in_off_mode is true").is_true()

func test_should_be_visible_off_mode_not_active_when_off() -> void:
	var settings := GridTargetingSettings.new()
	settings.remain_active_in_off_mode = false
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.OFF, settings, last_mouse, has_mouse)
	assert_bool(result).append_failure_message("Positioner should be hidden in OFF mode when remain_active_in_off_mode is false").is_false()

func test_should_be_visible_info_mode() -> void:
	var settings := GridTargetingSettings.new()
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.INFO, settings, last_mouse, has_mouse)
	assert_bool(result).append_failure_message("Positioner should be hidden in INFO mode").is_false()



func test_should_be_visible_active_mode_with_last_mouse_allowed() -> void:
	var settings := GridTargetingSettings.new()
	# continuous follow removed; only last_mouse_allowed and has_mouse_world paths apply
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	last_mouse.allowed = true
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.MOVE, settings, last_mouse, has_mouse)
	assert_bool(result).append_failure_message("Positioner should be visible in MOVE mode when last_mouse is allowed").is_true()

func test_should_be_visible_active_mode_with_mouse_world_and_enabled() -> void:
	var settings := GridTargetingSettings.new()
	# continuous follow removed
	settings.enable_mouse_input = true
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	last_mouse.allowed = false
	var has_mouse := true

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.MOVE, settings, last_mouse, has_mouse)
	assert_bool(result).append_failure_message("Expected positioner to be visible with cached mouse world. Settings: mouse_enabled=%s, has_mouse_world=%s, last_mouse_allowed=%s, hide_on_handled=%s" % [str(settings.enable_mouse_input), str(has_mouse), str(last_mouse.allowed), str(settings.hide_on_handled)]).is_true()

func test_should_be_visible_active_mode_default() -> void:
	var settings := GridTargetingSettings.new()
	# continuous follow removed
	settings.enable_mouse_input = false
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	last_mouse.allowed = false
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.MOVE, settings, last_mouse, has_mouse)
	assert_bool(result)
  .append_failure_message("Positioner should be visible in MOVE mode by default").is_true()

func test_should_be_visible_for_mode_off_active() -> void:
	var settings := GridTargetingSettings.new()
	settings.remain_active_in_off_mode = true

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.OFF, settings)
	assert_bool(result).append_failure_message("Positioner should be visible for OFF mode when remain_active_in_off_mode is true").is_true()

func test_should_be_visible_for_mode_off_not_active() -> void:
	var settings := GridTargetingSettings.new()
	settings.remain_active_in_off_mode = false

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.OFF, settings)
	assert_bool(result).append_failure_message("Positioner should be hidden for OFF mode when remain_active_in_off_mode is false").is_false()

func test_should_be_visible_for_mode_info() -> void:
	var settings := GridTargetingSettings.new()

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.INFO, settings)
	assert_bool(result).append_failure_message("Positioner should be hidden for INFO mode").is_false()

func test_should_be_visible_for_mode_active() -> void:
	var settings := GridTargetingSettings.new()

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.MOVE, settings)
	assert_bool(result).append_failure_message("Positioner should be visible for MOVE mode").is_true()

func test_visibility_decision_trace() -> void:
	var mode_state := ModeState.new()
	mode_state.current = GBEnums.Mode.MOVE
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	last_mouse.allowed = true
	var has_mouse := true

	var trace := GridPositionerLogic.visibility_decision_trace(mode_state, settings, last_mouse, has_mouse)
	assert_str(trace)
  .append_failure_message("Visibility trace should contain current mode").contains("mode=MOVE")
	assert_str(trace).append_failure_message("Visibility trace should contain last_mouse_allowed status").contains("last_mouse_allowed=true")
	assert_str(trace).append_failure_message("Visibility trace should contain has_mouse_world status").contains("has_mouse_world=true")
	assert_str(trace).append_failure_message("Visibility trace should contain mouse_enabled status").contains("mouse_enabled=true")
	assert_str(trace).append_failure_message("Visibility trace should contain computed visibility result").contains("computed_should=true")

func test_visibility_decision_trace_null_mode_state() -> void:
	var settings := GridTargetingSettings.new()
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	var has_mouse := false

	var trace := GridPositionerLogic.visibility_decision_trace(null, settings, last_mouse, has_mouse)
	assert_str(trace).append_failure_message("Visibility trace should handle null mode_state gracefully").contains("mode=<none>")

func test_visibility_decision_trace_null_settings() -> void:
	var mode_state := ModeState.new()
	mode_state.current = GBEnums.Mode.OFF
	var last_mouse: GBMouseInputStatus = GBMouseInputStatus.new()
	var has_mouse := false

	var trace := GridPositionerLogic.visibility_decision_trace(mode_state, null, last_mouse, has_mouse)
	assert_str(trace).append_failure_message("Visibility trace should handle null settings gracefully").contains("mouse_enabled=<n/a>")
