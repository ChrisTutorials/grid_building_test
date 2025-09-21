extends GdUnitTestSuite

# Simple unit tests to ensure RuleCheckIndicator reads values from GBDebugSettings

func before_test() -> void:
    pass

func after_test() -> void:
    pass

## We'll use the real GBLogger class for typed compatibility
var _GBLoggerScript := preload("res://addons/grid_building/logging/gb_logger.gd")

func _make_test_logger_with_settings(p_settings: GBDebugSettings) -> GBLogger:
    # GBLogger._init accepts a GBDebugSettings param
    var logger: GBLogger = _GBLoggerScript.new(p_settings)
    return logger


func test_debug_setting_float_and_color_are_read() -> void:
    # Create a GBDebugSettings resource with known values
    var SettingsScript := preload("res://addons/grid_building/debug/gb_debug_settings.gd")
    var settings: GBDebugSettings = SettingsScript.new()
    settings.indicator_collision_point_min_radius = 7.5
    settings.indicator_connection_line_scale = 0.33
    settings.indicator_connection_line_color = Color(0.1, 0.2, 0.3, 1.0)

    # Create GBLogger with our settings
    var test_logger: GBLogger = _make_test_logger_with_settings(settings)

    # Instantiate a RuleCheckIndicator scene
    var IndicatorScene: PackedScene = preload("res://templates/grid_building_templates/indicator/rule_check_indicator_16x16.tscn")
    var indicator: Node = IndicatorScene.instantiate() as Node

    # Inject the logger by setting the _logger field directly (tests may do this)
    indicator._logger = test_logger

    # Call internal helper methods via call() to verify they read from settings
    var f_val_float: float = float(indicator.call("_debug_setting_float_or", 1.0, "indicator_collision_point_min_radius"))
    assert_float(f_val_float).is_equal_approx(7.5, 0.0001).append_failure_message("Expected float debug setting to be read from GBDebugSettings")

    var c_val_color: Color = indicator.call("_debug_setting_color_or", Color.RED, "indicator_connection_line_color") as Color
    assert_float(c_val_color.r).is_equal_approx(0.1, 0.0001).append_failure_message("Expected color.r to match setting")
    assert_float(c_val_color.g).is_equal_approx(0.2, 0.0001).append_failure_message("Expected color.g to match setting")
    assert_float(c_val_color.b).is_equal_approx(0.3, 0.0001).append_failure_message("Expected color.b to match setting")

    # Also verify a fallback occurs when requesting a non-existent property
    var fallback_val: float = float(indicator.call("_debug_setting_float_or", 2.25, "non_existent_property"))
    assert_float(fallback_val).is_equal_approx(2.25, 0.0001).append_failure_message("Expected fallback default when setting missing")

    # Clean up
    if is_instance_valid(indicator):
        indicator.queue_free()
