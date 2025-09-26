
## Unit test verifying end-of-frame visibility/state logging from GridPositioner2D.
extends GdUnitTestSuite

func _make_logger_with_sink(captured: Array) -> GBLogger:
    var settings := GBDebugSettings.new()
    settings.level = GBDebugSettings.LogLevel.VERBOSE
    var logger := GBLogger.new(settings)
    logger.set_log_sink(func(_level: int, _ctx: String, msg: String) -> void:
        captured.append(msg)
    )
    return logger

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

    var cfg := GBConfig.new()
    cfg.settings = GBSettings.new()
    cfg.settings.targeting = GridTargetingSettings.new()
    cfg.settings.debug.grid_positioner_log_mode = GBDebugSettings.GridPositionerLogMode.VISIBILITY

    pos.set_dependencies(states, cfg, logger, null, false)
    assert_bool(pos._debug_settings != null).is_true()
    assert_int(pos._get_debug_log_mode()).is_equal(GBDebugSettings.GridPositionerLogMode.VISIBILITY)

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

    assert_bool(found).append_failure_message("Expected an 'end_of_frame_state' log entry; captured=%s" % str(captured)).is_true()
