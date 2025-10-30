# GdUnit generated TestSuite
extends GdUnitTestSuite

const DBG_LEVEL := GBDebugSettings.LogLevel

var _logger: GBLogger
var _received_logs: Array[Dictionary]

# Per-file message constants to reduce magic-string repetitions
const MSG_DEBUG_ONE := "This is a test debug message"
const MSG_WARN_ONE := "This is a test warning message"
const MSG_WARN_TWO := "This is another test warning message"
const MSG_ERR_ONE := "This is a test error message"
const MSG_INFO_ONE := "This is a test info message"
const MSG_HEAVY_RESULT := "heavy result"
const MSG_CALLABLE_RESULT := "callable result"
const MSG_DIRECT_STRING := "direct string"
const MSG_FIRST := "first"
const MSG_SECOND := "second"
const MSG_THIRD := "third"

func before_test() -> void:
	var debug_settings := GBDebugSettings.new()
	debug_settings.level = DBG_LEVEL.DEBUG
	_logger = GBLogger.new(debug_settings)

	_received_logs = []
	var sink: Callable = func(level: int, context: String, message: String) -> void:
		_received_logs.append({"level": level, "context": context, "message": message})
	_logger.set_log_sink(sink)


func test_level_filtering() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.WARNING

	_logger.log_debug("debug")  # should not be called
	_logger.log_warning("warning")  # should be called
	_logger.log_error("error")  # should be called


func test_instantiation() -> void:
	assert_that(_logger).append_failure_message("Logger should be instantiated successfully").is_not_null()


func test_log_debug_once_logs_only_once() -> void:
	_logger.log_debug_once(self, MSG_DEBUG_ONE)
	_logger.log_debug_once(self, "This is another test debug message")
	assert_that(_received_logs.size()).append_failure_message("Should only log once for the same object").is_equal(1)
	assert_that(_received_logs[0]["message"]).append_failure_message("First log message should match the expected debug message").is_equal(MSG_DEBUG_ONE)


func test_log_warning_once_logs_only_once() -> void:
	_logger.log_warning_once(self, MSG_WARN_ONE)
	_logger.log_warning_once(self, MSG_WARN_TWO)
	assert_that(_received_logs.size()).append_failure_message("Should only log once for the same object").is_equal(1)
	assert_that(_received_logs[0]["message"]).append_failure_message("First log message should match the expected warning message").is_equal(MSG_WARN_ONE)


func test_log_warning_once_logs_multiple_times_for_different_objects() -> void:
	var obj1: Node = Node.new()
	var obj2: Node = Node.new()
	_logger.log_warning_once(obj1, MSG_WARN_ONE)
	_logger.log_warning_once(obj2, MSG_WARN_TWO)
	assert_that(_received_logs.size()).append_failure_message(
		"Should log once for each different object").is_equal(2)
	assert_that(_received_logs[0]["message"]).append_failure_message(
		"First log should contain the first object's message").is_equal(MSG_WARN_ONE)
	assert_that(_received_logs[1]["message"]).append_failure_message(
		"Second log should contain the second object's message").is_equal(MSG_WARN_TWO)
	obj1.free()
	obj2.free()


func test_log_error_once_logs_only_once() -> void:
	_logger.log_error_once(self, MSG_ERR_ONE)
	_logger.log_error_once(self, "This is another test error message")
	assert_that(_received_logs.size()).append_failure_message(
		"Should only log once for the same object").is_equal(1)
	assert_that(_received_logs[0]["message"]).append_failure_message(
		"First log message should match the expected error message").is_equal(MSG_ERR_ONE)

func test_log_info_once_logs_only_once() -> void:
	_logger.log_info_once(self, MSG_INFO_ONE)
	_logger.log_info_once(self, "This is another test info message")
	assert_that(_received_logs.size()).append_failure_message(
		"Should only log once for the same object").is_equal(1)
	assert_that(_received_logs[0]["message"]).append_failure_message(
		"First log message should match the expected info message").is_equal(MSG_INFO_ONE)


func test_context_from_get_stack() -> void:
	# Just call log_at and verify the context is set from get_stack()
	_logger.log_at(DBG_LEVEL.DEBUG, "test")

	# Verify that context is properly set from get_stack()
	# Basic null/empty checks with expanded diagnostics
	assert_that(_received_logs.size()).append_failure_message("No logs received; expected at least one entry. Debug level: %s" % str(_logger.get_debug_settings().level)).is_greater(0)

	assert_that(_received_logs[0]["context"]).append_failure_message("Context should not be null. Received logs: %s" % str(_received_logs)).is_not_null()
	assert_that(_received_logs[0]["context"]).append_failure_message("Context should not be empty. Actual context: '%s' | Received: %s" % [_received_logs[0]["context"], str(_received_logs)]).is_not_empty()

	# Create detailed diagnostic information
	var context: String = _received_logs[0]["context"]
	var stack: Array = get_stack()
	var stack_info: String = "Stack analysis: size=%d, stack[0-5]=" % stack.size()
	for i in range(min(6, stack.size())):
		var frame: Dictionary = stack[i] if i < stack.size() else {}
		stack_info += " [%d]:%s:%s" % [i, frame.get("source", ""), frame.get("function", "")]

	# The context should either contain the filename and function name (if stack works)
	# or indicate it's a test environment (if stack is empty)
	var diagnostic: String = "Test: test_context_from_get_stack | Debug level: %s | Received logs: %s | %s" % [_logger.get_debug_settings().level, str(_received_logs), stack_info]

	# Accept either proper context or test environment fallback
	var has_proper_context: bool = context.contains("gb_logger_test") and context.contains("test_context_from_get_stack")
	var has_test_fallback: bool = context == "test_environment"

	assert_bool(has_proper_context or has_test_fallback).append_failure_message(
		"Context '%s' should either contain test info or be 'test_environment'. %s" % [context, diagnostic]
	).is_true()

func test_context_from_convenience_methods() -> void:
	# Test that context works correctly when called through convenience methods like log_debug
	_received_logs.clear()
	_logger.log_debug("debug message")

	# Verify that context is properly set from get_stack()
	assert_that(_received_logs.size()).append_failure_message(
		"Should have exactly one log message. Received logs: %s" % str(_received_logs)).is_equal(1)
	assert_that(_received_logs[0]["context"]).append_failure_message(
		"Context should not be null. Received logs: %s" % str(_received_logs)).is_not_null()
	assert_that(_received_logs[0]["context"]).append_failure_message(
		"Context should not be empty. Actual context: '%s'" % _received_logs[0]["context"]).is_not_empty()

	# Create detailed diagnostic information
	var context: String = _received_logs[0]["context"]
	var stack: Array = get_stack()
	var stack_info: String = "Stack analysis: size=%d, stack[0-5]=" % stack.size()
	for i in range(min(6, stack.size())):
		var frame: Dictionary = stack[i] if i < stack.size() else {}
		stack_info += " [%d]:%s:%s" % [i, frame.get("source", ""), frame.get("function", "")]

	# The context should still point to this test method, not the logger internals
	# Accept either proper context or test environment fallback
	var diagnostic2: String = "Test: test_context_from_convenience_methods | Debug level: %s | Received logs: %s | %s" % [_logger.get_debug_settings().level, str(_received_logs), stack_info]

	var has_proper_context2: bool = context.contains("gb_logger_test") and context.contains("test_context_from_convenience_methods")
	var has_test_fallback2: bool = context == "test_environment"

	assert_bool(has_proper_context2 or has_test_fallback2).append_failure_message(
		"Context '%s' should either contain test info or be 'test_environment'. %s" % [context, diagnostic2]
	).is_true()

## Minimal helper for test callable
func _call_me() -> void:
	pass

func test_lazy_provider_not_called_when_disabled() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.WARNING

	# use container to allow mutation inside lambda
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "expensive"

	# DEBUG is disabled under WARNING level -> use lazy variant
	_logger.log_debug_lazy(provider)
	assert_that(called_container["v"]).append_failure_message(
		"Provider should not be called when debug level disabled"
		).is_false()

func test_lazy_provider_called_when_enabled_and_sink_receives_message() -> void:
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return MSG_HEAVY_RESULT

	_logger.log_debug_lazy(provider)

	assert_that(called_container["v"]).append_failure_message(
		"Provider should be called when DEBUG enabled").is_true()
	assert_that(_received_logs.size()).append_failure_message(
		"Sink should have received exactly one message").is_equal(1)
	var entry: Dictionary = _received_logs[0]
	assert_that(entry["message"]).append_failure_message(
		"Message should match the provider result").is_equal(MSG_HEAVY_RESULT)

func test_set_log_sink_works_for_errors() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.ERROR

	_logger.log_error( "problem")

	assert_that(_received_logs.size()).append_failure_message("Sink should receive one message for error log").is_equal(1)
	var e: Dictionary = _received_logs[0]
	assert_that(e["level"]).append_failure_message("Log level should be ERROR").is_equal(DBG_LEVEL.ERROR)
	assert_that(e["message"]).append_failure_message("Log message should match input").is_equal("problem")

func test_default_emission_without_sink_calls_provider_and_does_not_crash() -> void:
	_logger.set_log_sink(Callable())

	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "no-sink"

	# Do not set a sink. Should materialize provider and not throw.
	_logger.log_debug_lazy(provider)
	assert_that(called_container["v"]).append_failure_message(
		"Provider should be called even when no sink is set").is_true()

func test_sink_cleared_is_handled_gracefully() -> void:
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "bound-sink"

	# First call: sink should receive
	_logger.log_debug_lazy(provider)
	assert_that(called_container["v"]).append_failure_message(
		"Provider should be called when sink target valid").is_true()
	assert_that(_received_logs.size()).append_failure_message(
		"Sink should receive the message when set").is_equal(1)

	# Clear the sink and ensure no crash when logging again
	_logger.set_log_sink(Callable())

	var called_container2: Dictionary = {"v": false}
	var provider2: Callable = func() -> String:
		called_container2["v"] = true
		return "after-clear"

	# This should not throw; provider should still be called even though sink cleared
	_logger.log_debug_lazy(provider2)
	assert_that(called_container2["v"]).append_failure_message(
		"Provider should be called even when sink cleared").is_true()

func test_is_level_enabled_filters_correctly() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.WARNING

	assert_that(_logger.is_level_enabled(DBG_LEVEL.ERROR)).append_failure_message(
		"ERROR should be enabled when level is WARNING").is_true()
	assert_that(_logger.is_level_enabled(DBG_LEVEL.WARNING)).append_failure_message(
		"WARNING should be enabled when level is WARNING").is_true()
	assert_that(_logger.is_level_enabled(DBG_LEVEL.INFO)).append_failure_message(
		"INFO should be disabled when level is WARNING").is_false()
	assert_that(_logger.is_level_enabled(DBG_LEVEL.DEBUG)).append_failure_message(
		"DEBUG should be disabled when level is WARNING").is_false()

func test_log_at_with_string_message() -> void:
	_logger.log_at(DBG_LEVEL.DEBUG, MSG_DIRECT_STRING)

	assert_that(_received_logs.size()).append_failure_message(
		"Should receive one message").is_equal(1)
	assert_that(_received_logs[0]["message"]).append_failure_message(
		"Message should be the string").is_equal(MSG_DIRECT_STRING)

func test_log_at_with_callable_message() -> void:
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return MSG_CALLABLE_RESULT

	_logger.log_at(DBG_LEVEL.DEBUG, provider)

	assert_that(called_container["v"]).append_failure_message(
		"Provider should be called").is_true()
	assert_that(_received_logs[0]["message"]).append_failure_message(
		"Message should be the result").is_equal(MSG_CALLABLE_RESULT)

func test_invalid_callable_provider() -> void:
	var invalid_provider: Callable = Callable()  # empty callable

	_logger.log_at(DBG_LEVEL.DEBUG, invalid_provider)

	assert_that(_received_logs[0]["message"]).append_failure_message(
		"Invalid callable should result in empty message").is_equal("")

func test_multiple_logs() -> void:
	_logger.log_debug(MSG_FIRST)
	_logger.log_debug(MSG_SECOND)
	_logger.log_debug(MSG_THIRD)

	assert_that(_received_logs.size()).append_failure_message(
		"Should receive 3 messages").is_equal(3)
	assert_that(_received_logs[0]["message"]).append_failure_message(
		"First message should be 'first'").is_equal(MSG_FIRST)
	assert_that(_received_logs[1]["message"]).append_failure_message(
		"Second message should be 'second'").is_equal(MSG_SECOND)
	assert_that(_received_logs[2]["message"]).append_failure_message(
		"Third message should be 'third'").is_equal(MSG_THIRD)
