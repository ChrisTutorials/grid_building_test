# GdUnit generated TestSuite
class_name GBLoggerTest
extends GdUnitTestSuite

const DBG_LEVEL := GBDebugSettings.LogLevel

var _logger: GBLogger
var _received_logs: Array[Dictionary]


func before_test() -> void:
	var debug_settings := GBDebugSettings.new()
	debug_settings.level = DBG_LEVEL.DEBUG
	_logger = GBLogger.new(debug_settings)
	
	_received_logs = []
	var sink: Callable = func(level: int, context: String, message: String) -> void:
		_received_logs.append({"level": level, "context": context, "message": message})
	_logger.set_log_sink(sink)


func test_instantiation() -> void:
	assert_that(_logger).is_not_null()


func test_log_debug_once_logs_only_once() -> void:
	_logger.log_debug_once(self, "test_key", "This is a test debug message")
	_logger.log_debug_once(self, "test_key", "This is another test debug message")
	assert_that(_received_logs.size()).is_equal(1)
	assert_that(_received_logs[0]["message"]).is_equal("This is a test debug message")


func test_log_warning_once_logs_only_once() -> void:
	_logger.log_warning_once(self, "test_key", "This is a test warning message")
	_logger.log_warning_once(self, "test_key", "This is another test warning message")
	assert_that(_received_logs.size()).is_equal(1)
	assert_that(_received_logs[0]["message"]).is_equal("This is a test warning message")


func test_log_warning_once_logs_multiple_times_for_different_keys() -> void:
	_logger.log_warning_once(self, "key1", "This is a test warning message")
	_logger.log_warning_once(self, "key2", "This is another test warning message")
	assert_that(_received_logs.size()).is_equal(2)
	assert_that(_received_logs[0]["message"]).is_equal("This is a test warning message")
	assert_that(_received_logs[1]["message"]).is_equal("This is another test warning message")


func test_log_error_once_logs_only_once() -> void:
	_logger.log_error_once(self, "test_key", "This is a test error message")
	_logger.log_error_once(self, "test_key", "This is another test error message")
	assert_that(_received_logs.size()).is_equal(1)
	assert_that(_received_logs[0]["message"]).is_equal("This is a test error message")


func test_log_info_once_logs_only_once() -> void:
	_logger.log_info_once(self, "test_key", "This is a test info message")
	_logger.log_info_once(self, "test_key", "This is another test info message")
	assert_that(_received_logs.size()).is_equal(1)
	assert_that(_received_logs[0]["message"]).is_equal("This is a test info message")


func test_non_null_sender() -> void:
	_logger.log_at(DBG_LEVEL.DEBUG, self, "test")

	# Verify that context is properly set for non-null sender
	assert_that(_received_logs[0]["context"]).is_not_null()
	assert_that(_received_logs[0]["context"]).is_not_empty()
	assert_that(_received_logs[0]["context"]).is_equal("gb_logger_test")

func test_lazy_provider_not_called_when_disabled() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.WARNING

	# use container to allow mutation inside lambda
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "expensive"

	# DEBUG is disabled under WARNING level -> use lazy variant
	_logger.log_debug_lazy(self, provider)
	assert_that(called_container["v"]).append_failure_message("Provider should not be called when debug level disabled").is_false()

func test_lazy_provider_called_when_enabled_and_sink_receives_message() -> void:
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "heavy result"

	_logger.log_debug_lazy(self, provider)

	assert_that(called_container["v"]).append_failure_message("Provider should be called when DEBUG enabled").is_true()
	assert_that(_received_logs.size()).append_failure_message("Sink should have received exactly one message").is_equal(1)
	var entry: Dictionary = _received_logs[0]
	assert_that(entry["message"]).append_failure_message("Message should match the provider result").is_equal("heavy result")

func test_set_log_sink_works_for_errors() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.ERROR

	_logger.log_error(self, "problem")

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
	_logger.log_debug_lazy(self, provider)
	assert_that(called_container["v"]).append_failure_message("Provider should be called even when no sink is set").is_true()

func test_sink_cleared_is_handled_gracefully() -> void:
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "bound-sink"

	# First call: sink should receive
	_logger.log_debug_lazy(self, provider)
	assert_that(called_container["v"]).append_failure_message("Provider should be called when sink target valid").is_true()
	assert_that(_received_logs.size()).append_failure_message("Sink should receive the message when set").is_equal(1)

	# Clear the sink and ensure no crash when logging again
	_logger.set_log_sink(Callable())

	var called_container2: Dictionary = {"v": false}
	var provider2: Callable = func() -> String:
		called_container2["v"] = true
		return "after-clear"

	# This should not throw; provider should still be called even though sink cleared
	_logger.log_debug_lazy(self, provider2)
	assert_that(called_container2["v"]).append_failure_message("Provider should be called even when sink cleared").is_true()

func test_is_level_enabled_filters_correctly() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.WARNING

	assert_that(_logger.is_level_enabled(DBG_LEVEL.ERROR)).append_failure_message("ERROR should be enabled when level is WARNING").is_true()
	assert_that(_logger.is_level_enabled(DBG_LEVEL.WARNING)).append_failure_message("WARNING should be enabled when level is WARNING").is_true()
	assert_that(_logger.is_level_enabled(DBG_LEVEL.INFO)).append_failure_message("INFO should be disabled when level is WARNING").is_false()
	assert_that(_logger.is_level_enabled(DBG_LEVEL.DEBUG)).append_failure_message("DEBUG should be disabled when level is WARNING").is_false()

func test_log_at_with_string_message() -> void:
	_logger.log_at(DBG_LEVEL.DEBUG, self, "direct string")

	assert_that(_received_logs.size()).append_failure_message("Should receive one message").is_equal(1)
	assert_that(_received_logs[0]["message"]).append_failure_message("Message should be the string").is_equal("direct string")

func test_log_at_with_callable_message() -> void:
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "callable result"

	_logger.log_at(DBG_LEVEL.DEBUG, self, provider)

	assert_that(called_container["v"]).append_failure_message("Provider should be called").is_true()
	assert_that(_received_logs[0]["message"]).append_failure_message("Message should be the result").is_equal("callable result")

func test_invalid_callable_provider() -> void:
	var invalid_provider: Callable = Callable()  # empty callable

	_logger.log_at(DBG_LEVEL.DEBUG, self, invalid_provider)

	assert_that(_received_logs[0]["message"]).append_failure_message("Invalid callable should result in empty message").is_equal("")

func test_level_filtering() -> void:
	_logger.get_debug_settings().level = DBG_LEVEL.WARNING

	_logger.log_debug(self, "debug")  # should not be called
	_logger.log_warning(self, "warning")  # should be called
	_logger.log_error(self, "error")  # should be called

	assert_that(_received_logs.size()).append_failure_message("Should receive 2 messages").is_equal(2)
	assert_that(_received_logs[0]["message"]).append_failure_message("First should be warning").is_equal("warning")
	assert_that(_received_logs[1]["message"]).append_failure_message("Second should be error").is_equal("error")

func test_multiple_logs() -> void:
	_logger.log_debug(self, "first")
	_logger.log_debug(self, "second")
	_logger.log_debug(self, "third")

	assert_that(_received_logs.size()).append_failure_message("Should receive 3 messages").is_equal(3)
	assert_that(_received_logs[0]["message"]).is_equal("first")
	assert_that(_received_logs[1]["message"]).is_equal("second")
	assert_that(_received_logs[2]["message"]).is_equal("third")
