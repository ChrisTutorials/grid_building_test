## Unit tests focusing on GridPositioner2D diagnostics output paths.
extends GdUnitTestSuite

func _make_logger_with_sink(captured: Array) -> GBLogger:
	var settings := GBDebugSettings.new()
	settings.level = GBDebugSettings.LogLevel.VERBOSE
	var logger := GBLogger.new(settings)
	logger.set_log_sink(func(_level: int, _ctx: String, msg: String) -> void:
		captured.append("[" + _ctx + "] " + msg)
	)
	return logger

func test_positioner_logs_screen_state_when_enabled() -> void:
	var captured: Array[String] = []
	var logger := _make_logger_with_sink(captured)
	# Create a parent so nodes are inside the scene tree (validate_dependencies calls get_path)
	var parent: Node2D = auto_free(Node2D.new())
	get_tree().get_root().add_child(parent)
	var pos: GridPositioner2D = auto_free(GridPositioner2D.new())
	# Inject minimal deps
	var owner_ctx := GBOwnerContext.new()
	var states := GBStates.new(owner_ctx)
	# Mode is initialized by GBStates; ensure it's set as expected
	states.mode.current = GBEnums.Mode.MOVE
	# Use a TileMapLayer so GridTargetingState types are satisfied
	var test_map: TileMapLayer = auto_free(TileMapLayer.new())
	parent.add_child(test_map)
	parent.add_child(pos)
	states.targeting.target_map = test_map
	var cfg := GBConfig.new()
	cfg.settings = GBSettings.new()
	cfg.settings.targeting = GridTargetingSettings.new()
	cfg.settings.debug.grid_positioner_log_mode = GBDebugSettings.GridPositionerLogMode.MOUSE_INPUT
	pos.set_dependencies(states, cfg, logger, null, false)
	# Force call
	pos._set_visible_state(true)
	# Wait past throttle window and emit screen_state from a distinct callsite
	OS.delay_msec(300)
	pos._log_screen_and_mouse_state()
	# Expect at least one screen_state entry, even without a camera the helper prints <no camera>
	var found := false
	for line in captured:
		if line.find("screen_state") != -1:
			found = true
			break
	# Also verify we captured any logs
	assert_int(captured.size()).append_failure_message("No logs captured: %s" % str(captured)).is_greater(0)
	assert_bool(found).append_failure_message("Expected a 'screen_state' log entry; captured=%s" % str(captured)).is_true()
