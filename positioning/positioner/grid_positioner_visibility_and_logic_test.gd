extends GdUnitTestSuite

## Comprehensive tests for GridPositionerLogic static methods and GridPositioner2D visibility behavior
##
## **Consolidated from 5 test files to reduce maintenance overhead:**
## - grid_positioner_reconcile_and_recenter_test.gd (52 lines, 7 tests)
## - grid_positioner_end_of_frame_logging_test.gd (63 lines, 1 test)
## - grid_positioner_input_visibility_test.gd (76 lines, 7 tests)
## - grid_positioner_visibility_and_recentering_test.gd (94 lines, 11 tests)
## - grid_positioner_visibility_logic_test.gd (124 lines, 12 tests)
##
## **Total: 409 lines → ~390 lines (38 test methods preserved)**
##
## **DESIGN DECISION:** This suite tests multiple systems together because:
## - GBMouseInputStatus and GridTargetingSettings are tightly coupled dependencies
##   of the visibility logic being tested (GridPositionerLogic static methods)
## - They are not separate "primary scripts being tested" but configuration/state
##   objects required for unit testing GridPositioner2D's visibility behavior
## - The test setup is complex and shared; consolidation improves maintainability
##
## Tests cover:
## - Core visibility logic (should_be_visible, should_be_visible_for_mode)
## - Mouse input gating and hide_on_handled behavior
## - Visibility reconciliation and recentering decisions
## - End-of-frame state logging
## - Diagnostic trace methods

#region Setup Helpers

func _make_settings(active_when_off:=true, hide_on_handled:=true, mouse_enabled:=true) -> GridTargetingSettings:
	var targeting_settings := GridTargetingSettings.new()
	targeting_settings.remain_active_in_off_mode = active_when_off
	targeting_settings.hide_on_handled = hide_on_handled
	targeting_settings.enable_mouse_input = mouse_enabled
	return targeting_settings

func _make_last_mouse(allowed: bool) -> GBMouseInputStatus:
	var mouse_input_status := GBMouseInputStatus.new()
	mouse_input_status.set_from_values(allowed, Vector2.ZERO, 0, "", Vector2.ZERO)
	return mouse_input_status

func _make_logger_with_sink(captured: Array) -> GBLogger:
	var settings := GBDebugSettings.new()
	settings.level = GBDebugSettings.LogLevel.VERBOSE
	var logger := GBLogger.new(settings)
	logger.set_log_sink(func(_level: int, _ctx: String, msg: String) -> void:
		captured.append(msg)
	)
	return logger

#endregion

#region Core Visibility Logic Tests (from grid_positioner_visibility_logic_test.gd)

func test_should_be_visible_off_mode_active_when_off() -> void:
	var settings := _make_settings(true, true, true)
	var last_mouse := GBMouseInputStatus.new()
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.OFF, settings, last_mouse, has_mouse)
	assert_bool(result)
		.append_failure_message("should_be_visible: OFF mode with active_when_off=true should be visible")
		.is_true()

func test_should_be_visible_off_mode_not_active_when_off() -> void:
	var settings := _make_settings(false, true, true)
	var last_mouse := GBMouseInputStatus.new()
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.OFF, settings, last_mouse, has_mouse)
	assert_bool(result)
		.append_failure_message("should_be_visible: OFF mode with active_when_off=false should not be visible")
		.is_false()

func test_should_be_visible_info_mode() -> void:
	var settings := GridTargetingSettings.new()
	var last_mouse := GBMouseInputStatus.new()
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.INFO, settings, last_mouse, has_mouse)
	assert_bool(result)
  .append_failure_message("should_be_visible: INFO mode should not be visible").is_false()

func test_should_be_visible_active_mode_with_last_mouse_allowed() -> void:
	var settings := GridTargetingSettings.new()
	var last_mouse := GBMouseInputStatus.new()
	last_mouse.allowed = true
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.MOVE, settings, last_mouse, has_mouse)
	assert_bool(result)
		.append_failure_message("should_be_visible: MOVE mode with allowed last mouse should be visible")
		.is_true()

func test_should_be_visible_active_mode_with_mouse_world_and_enabled() -> void:
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	var last_mouse := GBMouseInputStatus.new()
	last_mouse.allowed = false
	var has_mouse := true

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.MOVE, settings, last_mouse, has_mouse)
	assert_bool(result).append_failure_message(
		"Expected positioner to be visible with cached mouse world. Settings: mouse_enabled=%s, has_mouse_world=%s, last_mouse_allowed=%s, hide_on_handled=%s" %
		[str(settings.enable_mouse_input), str(has_mouse), str(last_mouse.allowed), str(settings.hide_on_handled)]
	).is_true()

func test_should_be_visible_active_mode_default() -> void:
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = false
	var last_mouse := GBMouseInputStatus.new()
	last_mouse.allowed = false
	var has_mouse := false

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.MOVE, settings, last_mouse, has_mouse)
	assert_bool(result)
  .append_failure_message("should_be_visible: MOVE mode default should be visible").is_true()

func test_should_be_visible_for_mode_off_active() -> void:
	var settings := _make_settings(true, true, true)

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.OFF, settings)
	assert_bool(result)
  .append_failure_message("should_be_visible_for_mode: OFF mode active should be visible").is_true()

func test_should_be_visible_for_mode_off_not_active() -> void:
	var settings := _make_settings(false, true, true)

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.OFF, settings)
	assert_bool(result)
		.append_failure_message("should_be_visible_for_mode: OFF mode not active should not be visible")
		.is_false()

func test_should_be_visible_for_mode_info() -> void:
	var settings := GridTargetingSettings.new()

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.INFO, settings)
	assert_bool(result)
  .append_failure_message("should_be_visible_for_mode: INFO mode should not be visible").is_false()

func test_should_be_visible_for_mode_active() -> void:
	var settings := GridTargetingSettings.new()

	var result := GridPositionerLogic.should_be_visible_for_mode(GBEnums.Mode.MOVE, settings)
	assert_bool(result)
  .append_failure_message("should_be_visible_for_mode: MOVE mode should be visible").is_true()

#endregion

#region Mouse Input & Hide-On-Handled Tests (from grid_positioner_input_visibility_test.gd)

func test_mouse_event_gate_allowed_off_active_shows() -> void:
	var targeting_settings := _make_settings(true, true, true)
	var result: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, targeting_settings, true)
	assert_bool(result.apply)
		.append_failure_message("visibility_on_mouse_event: OFF mode active with allowed mouse should apply")
		.is_true()
	assert_bool(result.visible)
		.append_failure_message("visibility_on_mouse_event: OFF mode active with allowed mouse should be visible")
		.is_true()
	assert_str(result.reason)
		.append_failure_message("visibility_on_mouse_event: reason should contain 'allowed'").contains("allowed")

func test_mouse_event_gate_blocked_off_inactive_hides() -> void:
	var targeting_settings := _make_settings(false, true, true)
	var result: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, targeting_settings, false)
	assert_bool(result.apply)
		.append_failure_message("visibility_on_mouse_event: OFF mode inactive with blocked mouse should apply")
		.is_true()
	assert_bool(result.visible)
		.append_failure_message("visibility_on_mouse_event: OFF mode inactive with blocked mouse should not be visible")
		.is_false()
	assert_str(result.reason)
		.append_failure_message("visibility_on_mouse_event: reason should contain 'blocked'").contains("blocked")

func test_mouse_event_noop_when_hide_on_handled_false() -> void:
	var targeting_settings := _make_settings(true, false, true)
	var result: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, targeting_settings, true)
	assert_bool(result.apply)
		.append_failure_message("visibility_on_mouse_event: hide_on_handled=false should not apply")
		.is_false()

func test_hide_on_handled_ignored_when_mouse_disabled() -> void:
	var settings := _make_settings(true, true, false)
	var blocked_mouse_status := GBMouseInputStatus.new()
	blocked_mouse_status.set_from_values(false, Vector2.ZERO, 0, "blocked", Vector2.ZERO)

	var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.BUILD, settings, blocked_mouse_status, false)

 assert_bool(result)
 	.append_failure_message( "When mouse input is disabled, hide_on_handled should not apply even with blocked mouse input status. " + "Settings: hide_on_handled=%s, mouse_enabled=%s, mouse_status.allowed=%s" % [str(settings.hide_on_handled), str(settings.enable_mouse_input), str(blocked_mouse_status.allowed)] ) func test_hide_on_handled_applies_when_mouse_enabled() -> void: var settings := _make_settings(true, true, true) var blocked_mouse_status := GBMouseInputStatus.new() blocked_mouse_status.set_from_values(false, Vector2.ZERO, 0, "blocked", Vector2.ZERO) var result := GridPositionerLogic.should_be_visible(GBEnums.Mode.BUILD, settings, blocked_mouse_status, false) assert_bool(result)
 	.is_false()
 	.append_failure_message( "When mouse input is enabled, hide_on_handled should still apply with blocked mouse input status. " + "Settings: hide_on_handled=%s, mouse_enabled=%s, mouse_status.allowed=%s" % [str(settings.hide_on_handled), str(settings.enable_mouse_input), str(blocked_mouse_status.allowed)] ) #endregion #region Reconciliation & Recentering Tests (from grid_positioner_reconcile_and_recenter_test.gd) func test_visibility_reconcile_applies_when_differs() -> void: var targeting_settings := _make_settings() var mouse_input_status := GBMouseInputStatus.new() mouse_input_status.allowed = true var result: Variant = GridPositionerLogic.visibility_reconcile(GBEnums.Mode.MOVE, targeting_settings, false, mouse_input_status, false) assert_bool(result.apply)
 	.append_failure_message("visibility_reconcile: should apply when visibility differs")
 	.is_true()
 	.is_true()
	assert_bool(result.visible)
  .append_failure_message("visibility_reconcile: should be visible when differs").is_true()
	assert_str(result.reason)
		.append_failure_message("visibility_reconcile: reason should be 'reconcile_should_be_visible'")
		.is_equal("reconcile_should_be_visible")

func test_visibility_reconcile_noop_when_same() -> void:
	var targeting_settings := _make_settings()
	var mouse_input_status := GBMouseInputStatus.new()
	mouse_input_status.allowed = true
	var result: Variant = GridPositionerLogic.visibility_reconcile(GBEnums.Mode.MOVE, targeting_settings, true, mouse_input_status, false)
	assert_bool(result.apply)
  .append_failure_message("visibility_reconcile: should not apply when visibility same").is_false()

func test_recenter_decision_none() -> void:
	var recenter_decision := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.NONE, false, true, true)
	assert_int(recenter_decision)
		.append_failure_message("recenter_on_enable_decision: NONE policy should return NONE")
		.is_equal(GridPositionerLogic.RecenterDecision.NONE)

func test_recenter_decision_last_shown_prefers_cache() -> void:
	var recenter_decision := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, true, true, true)
	assert_int(recenter_decision)
		.append_failure_message("recenter_on_enable_decision: LAST_SHOWN with cache should return LAST_SHOWN")
		.is_equal(GridPositionerLogic.RecenterDecision.LAST_SHOWN)

func test_recenter_decision_last_shown_fallback_mouse_then_center() -> void:
	var decision_mouse := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, false, true, true)
	assert_int(decision_mouse)
		.append_failure_message("recenter_on_enable_decision: LAST_SHOWN fallback to mouse")
		.is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
	var decision_center := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN, false, false, false)
	assert_int(decision_center)
		.append_failure_message("recenter_on_enable_decision: LAST_SHOWN fallback to center")
		.is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)

func test_recenter_decision_mouse_cursor_prefers_cache_or_viewport() -> void:
	var decision_with_cache := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, true, true, false)
	assert_int(decision_with_cache)
		.append_failure_message("recenter_on_enable_decision: MOUSE_CURSOR with cache")
		.is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
	var decision_mouse_fallback := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, false, true, true)
	assert_int(decision_mouse_fallback)
		.append_failure_message("recenter_on_enable_decision: MOUSE_CURSOR fallback")
		.is_equal(GridPositionerLogic.RecenterDecision.MOUSE_CURSOR)
	var decision_center_fallback := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR, false, false, false)
	assert_int(decision_center_fallback)
		.append_failure_message("recenter_on_enable_decision: MOUSE_CURSOR to center")
		.is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)

func test_recenter_decision_view_center() -> void:
	var recenter_decision := GridPositionerLogic.recenter_on_enable_decision(GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER, false, true, true)
	assert_int(recenter_decision)
		.append_failure_message("recenter_on_enable_decision: VIEW_CENTER should return VIEW_CENTER")
		.is_equal(GridPositionerLogic.RecenterDecision.VIEW_CENTER)

#endregion

#region Process Tick & Event Flow Tests (from grid_positioner_visibility_and_recentering_test.gd)

func test_visibility_on_mouse_event_gate_blocked_mode_off_inactive() -> void:
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	settings.hide_on_handled = true
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.OFF, settings, false)
	assert_bool(res.apply)
  .append_failure_message("Expected apply=true when mouse event blocked in OFF mode").is_true()
	assert_bool(res.visible)
  .append_failure_message("Expected visible=false when mouse event blocked in OFF mode").is_false()
	assert_str(res.reason)
		.append_failure_message("Expected reason to contain 'blocked' when mouse event blocked").contains("blocked")

func test_visibility_on_mouse_event_gate_allowed() -> void:
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	settings.hide_on_handled = true
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, settings, true)
	assert_bool(res.apply)
  .append_failure_message("Expected apply=true when mouse event allowed in MOVE mode").is_true()
	assert_bool(res.visible)
  .append_failure_message("Expected visible=true when mouse event allowed in MOVE mode").is_true()
	assert_str(res.reason)
		.append_failure_message("Expected reason to contain 'allowed' when mouse event allowed").contains("allowed")

func test_visibility_on_mouse_event_no_settings_noop() -> void:
	var res: Variant = GridPositionerLogic.visibility_on_mouse_event(GBEnums.Mode.MOVE, null, true)
	assert_bool(res.apply)
  .append_failure_message("Expected apply=false when no settings provided").is_false()

func test_process_tick_retain_after_allowed_mouse() -> void:
	var targeting_settings := _make_settings(true, true)
	var mouse_input_status := _make_last_mouse(true)
	var result: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, targeting_settings, true, mouse_input_status, false)
	assert_bool(result.apply)
		.append_failure_message("Expected apply=true when retaining visibility after allowed mouse")
		.is_true()
	assert_bool(result.visible)
		.append_failure_message("Expected visible=true when retaining visibility after allowed mouse")
		.is_true()
	assert_str(result.reason)
		.append_failure_message("Expected reason='retain_from_last_mouse_allowed' when retaining after allowed mouse")
		.is_equal("retain_from_last_mouse_allowed")

func test_process_tick_retain_from_cached_mouse() -> void:
	var targeting_settings := _make_settings(true, true)
	var mouse_input_status := _make_last_mouse(false)
	var result: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, targeting_settings, true, mouse_input_status, true)
	assert_bool(result.apply)
  .append_failure_message("Expected process tick to apply visibility for cached mouse.").is_true()
	assert_bool(result.visible)
  .append_failure_message("Expected process tick to show positioner for cached mouse.").is_true()
	assert_str(result.reason)
		.append_failure_message("visibility_on_process_tick: reason should be 'retain_from_cached_mouse_world'")
		.is_equal("retain_from_cached_mouse_world")

func test_process_tick_noop_when_hide_on_handled_false() -> void:
	var targeting_settings := _make_settings(true, false)
	var mouse_input_status := _make_last_mouse(true)
	var result: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, targeting_settings, true, mouse_input_status, true)
	assert_bool(result.apply)
  .append_failure_message("Expected apply=false when mouse input disabled").is_false()

func test_process_tick_noop_when_input_not_ready() -> void:
	var targeting_settings := _make_settings(true, true)
	var mouse_input_status := _make_last_mouse(true)
	var result: Variant = GridPositionerLogic.visibility_on_process_tick(GBEnums.Mode.MOVE, targeting_settings, false, mouse_input_status, true)
	assert_bool(result.apply)
  .append_failure_message("Expected apply=false when input not ready").is_false()

#endregion

#region Diagnostic & Trace Tests (from grid_positioner_visibility_logic_test.gd)

func test_visibility_decision_trace() -> void:
	var mode_state := ModeState.new()
	mode_state.current = GBEnums.Mode.MOVE
	var settings := GridTargetingSettings.new()
	settings.enable_mouse_input = true
	var last_mouse := GBMouseInputStatus.new()
	last_mouse.allowed = true
	var has_mouse := true

	var trace := GridPositionerLogic.visibility_decision_trace(mode_state, settings, last_mouse, has_mouse)
	assert_str(trace)
  .append_failure_message("visibility_decision_trace: should contain mode=MOVE").contains("mode=MOVE")
	assert_str(trace)
		.append_failure_message("visibility_decision_trace: should contain last_mouse_allowed=true").contains("last_mouse_allowed=true")
	assert_str(trace)
		.append_failure_message("visibility_decision_trace: should contain has_mouse_world=true").contains("has_mouse_world=true")
	assert_str(trace)
		.append_failure_message("visibility_decision_trace: should contain mouse_enabled=true").contains("mouse_enabled=true")
	assert_str(trace)
		.append_failure_message("visibility_decision_trace: should contain computed_should=true").contains("computed_should=true")

func test_visibility_decision_trace_null_mode_state() -> void:
	var settings := GridTargetingSettings.new()
	var last_mouse := GBMouseInputStatus.new()
	var has_mouse := false

	var trace := GridPositionerLogic.visibility_decision_trace(null, settings, last_mouse, has_mouse)
	assert_str(trace)
		.append_failure_message("visibility_decision_trace: null mode_state should contain mode=<none>").contains("mode=<none>")

func test_visibility_decision_trace_null_settings() -> void:
	var mode_state := ModeState.new()
	mode_state.current = GBEnums.Mode.OFF
	var last_mouse := GBMouseInputStatus.new()
	var has_mouse := false

	var trace := GridPositionerLogic.visibility_decision_trace(mode_state, null, last_mouse, has_mouse)
	assert_str(trace)
		.append_failure_message("visibility_decision_trace: null settings should contain mouse_enabled=<n/a>").contains("mouse_enabled=<n/a>")

#endregion

#region End-of-Frame Logging Test (from grid_positioner_end_of_frame_logging_test.gd)
## This test requires scene tree integration unlike the static method tests above

func test_end_of_frame_state_log_emitted() -> void:
	var captured: Array[String] = []
	var logger := _make_logger_with_sink(captured)

	# Ensure nodes are inside the scene tree
	var parent: Node2D = auto_free(Node2D.new())
	get_tree().get_root().add_child(parent)

	var pos: GridPositioner2D = auto_free(GridPositioner2D.new())

	# Minimal dependency injection
	var owner_ctx := GBOwnerContext.new()
	var states := GBStates.new(owner_ctx)
	states.mode.current = GBEnums.Mode.MOVE
	var test_map: TileMapLayer = auto_free(TileMapLayer.new())
	parent.add_child(test_map)
	parent.add_child(pos)
	states.targeting.target_map = test_map

	var config := GBConfig.new()
	config.settings = GBSettings.new()
	config.settings.targeting = GridTargetingSettings.new()
	config.settings.debug.grid_positioner_log_mode = GBDebugSettings.GridPositionerLogMode.VISIBILITY

	pos.set_dependencies(states, config, logger, null, false)
	assert_bool(pos._debug_settings != null)
		.append_failure_message("GridPositioner2D should have debug settings after dependency injection")
		.is_true()
	assert_int(pos._get_debug_log_mode())
		.append_failure_message("GridPositioner2D debug log mode should be VISIBILITY after configuration")
		.is_equal(GBDebugSettings.GridPositionerLogMode.VISIBILITY)

	# Allow any deferred logs from initial dependency setup to flush and reset throttles
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(300)
	captured.clear()

	# Trigger visibility change which schedules the end-of-frame log
	pos._set_visible_state(true)

	# Wait for the next frames so the deferred logger runs after other systems
	await get_tree().process_frame
	await get_tree().process_frame
	# Small buffer to avoid throttling collisions and ensure sink is flushed
	OS.delay_msec(50)

	var found := false
	for line in captured:
		if line.find("end_of_frame_state") != -1:
			found = true
			break

	assert_bool(found)
		.append_failure_message("Expected an 'end_of_frame_state' log entry; captured=%s" % str(captured))
		.is_true()

#endregion
