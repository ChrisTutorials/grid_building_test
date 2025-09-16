extends GdUnitTestSuite

# Unit tests for GBLogger lazy logging and pluggable sink behavior

# Local constants to avoid magic numbers in tests
const DBG_LEVEL = GBDebugSettings.Level

func _before_test() -> void:
	# fresh logger instances will be created per-test; keep setup minimal
	return

func make_logger(p_level: int) -> GBLogger:
	var debug_settings: GBDebugSettings = GBDebugSettings.new()
	debug_settings.level = p_level
	return GBLogger.new(debug_settings)

func test_non_null_sender() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var received: Array[Dictionary] = []
	var sink: Callable = func(_level: int, _context: String, message: String) -> void:
		received.append({"context": _context, "message": message})

	logger.set_log_sink(sink)
	logger.log_at(DBG_LEVEL.DEBUG, self, "test")

	# Verify that context is properly set for non-null sender
	assert_that(received[0]["context"]).is_not_null()
	assert_that(received[0]["context"]).is_not_empty()
	assert_that(received[0]["context"]).is_equal("[gb_logger_unit_test]")

func test_lazy_provider_not_called_when_disabled() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.WARNING)

	# use container to allow mutation inside lambda
	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "expensive"

	# DEBUG is disabled under WARNING level -> use lazy variant
	logger.log_debug_lazy(self, provider)
	assert_that(called_container["v"]).append_failure_message("Provider should not be called when debug level disabled").is_false()

func test_lazy_provider_called_when_enabled_and_sink_receives_message() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "heavy result"

	var received: Array[Dictionary] = []
	var sink: Callable = func(level: int, context: String, message: String) -> void:
		var entry_dict: Dictionary = {"level": level, "context": context, "message": message}
		received.append(entry_dict)
		return

	logger.set_log_sink(sink)
	logger.log_debug_lazy(self, provider)

	assert_that(called_container["v"]).append_failure_message("Provider should be called when DEBUG enabled").is_true()
	assert_that(received.size()).append_failure_message("Sink should have received exactly one message").is_equal(1)
	var entry: Dictionary = received[0]
	assert_that(entry["message"]).append_failure_message("Message should match the provider result").is_equal("heavy result")

func test_set_log_sink_works_for_errors() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.ERROR)

	var received: Array[Dictionary] = []
	var sink: Callable = func(level: int, context: String, message: String) -> void:
		var entry: Dictionary = {"level": level, "context": context, "message": message}
		received.append(entry)
		return

	logger.set_log_sink(sink)
	logger.log_error(self, "problem")

	assert_that(received.size()).append_failure_message("Sink should receive one message for error log").is_equal(1)
	var e: Dictionary = received[0]
	assert_that(e["level"]).append_failure_message("Log level should be ERROR").is_equal(DBG_LEVEL.ERROR)
	assert_that(e["message"]).append_failure_message("Log message should match input").is_equal("problem")

func test_default_emission_without_sink_calls_provider_and_does_not_crash() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "no-sink"

	# Do not set a sink. Should materialize provider and not throw.
	logger.log_debug_lazy(self, provider)
	assert_that(called_container["v"]).append_failure_message("Provider should be called even when no sink is set").is_true()

func test_sink_cleared_is_handled_gracefully() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var received: Array[Dictionary] = []
	var sink: Callable = func(level: int, context: String, message: String) -> void:
		received.append({"level": level, "context": context, "message": message})
		return

	logger.set_log_sink(sink)

	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "bound-sink"

	# First call: sink should receive
	logger.log_debug_lazy(self, provider)
	assert_that(called_container["v"]).append_failure_message("Provider should be called when sink target valid").is_true()
	assert_that(received.size()).append_failure_message("Sink should receive the message when set").is_equal(1)

	# Clear the sink and ensure no crash when logging again
	logger.set_log_sink(Callable())

	var called_container2: Dictionary = {"v": false}
	var provider2: Callable = func() -> String:
		called_container2["v"] = true
		return "after-clear"

	# This should not throw; provider should still be called even though sink cleared
	logger.log_debug_lazy(self, provider2)
	assert_that(called_container2["v"]).append_failure_message("Provider should be called even when sink cleared").is_true()

func test_is_level_enabled_filters_correctly() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.WARNING)

	assert_that(logger.is_level_enabled(DBG_LEVEL.ERROR)).append_failure_message("ERROR should be enabled when level is WARNING").is_true()
	assert_that(logger.is_level_enabled(DBG_LEVEL.WARNING)).append_failure_message("WARNING should be enabled when level is WARNING").is_true()
	assert_that(logger.is_level_enabled(DBG_LEVEL.INFO)).append_failure_message("INFO should be disabled when level is WARNING").is_false()
	assert_that(logger.is_level_enabled(DBG_LEVEL.DEBUG)).append_failure_message("DEBUG should be disabled when level is WARNING").is_false()

func test_log_at_with_string_message() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var received: Array[Dictionary] = []
	var sink: Callable = func(level: int, context: String, message: String) -> void:
		received.append({"level": level, "context": context, "message": message})

	logger.set_log_sink(sink)
	logger.log_at(DBG_LEVEL.DEBUG, self, "direct string")

	assert_that(received.size()).append_failure_message("Should receive one message").is_equal(1)
	assert_that(received[0]["message"]).append_failure_message("Message should be the string").is_equal("direct string")

func test_log_at_with_callable_message() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var called_container: Dictionary = {"v": false}
	var provider: Callable = func() -> String:
		called_container["v"] = true
		return "callable result"

	var received: Array[Dictionary] = []
	var sink: Callable = func(_level: int, _context: String, message: String) -> void:
		received.append({"message": message})

	logger.set_log_sink(sink)
	logger.log_at(DBG_LEVEL.DEBUG, self, provider)

	assert_that(called_container["v"]).append_failure_message("Provider should be called").is_true()
	assert_that(received[0]["message"]).append_failure_message("Message should be the result").is_equal("callable result")

func test_invalid_callable_provider() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var invalid_provider: Callable = Callable()  # empty callable

	var received: Array[Dictionary] = []
	var sink: Callable = func(_level: int, _context: String, message: String) -> void:
		received.append({"message": message})

	logger.set_log_sink(sink)
	logger.log_at(DBG_LEVEL.DEBUG, self, invalid_provider)

	assert_that(received[0]["message"]).append_failure_message("Invalid callable should result in empty message").is_equal("")

func test_level_filtering() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.WARNING)

	var received: Array[String] = []
	var sink: Callable = func(_level: int, _context: String, message: String) -> void:
		received.append(message)

	logger.set_log_sink(sink)

	logger.log_debug(self, "debug")  # should not be called
	logger.log_warning(self, "warning")  # should be called
	logger.log_error(self, "error")  # should be called

	assert_that(received.size()).append_failure_message("Should receive 2 messages").is_equal(2)
	assert_that(received[0]).append_failure_message("First should be warning").is_equal("warning")
	assert_that(received[1]).append_failure_message("Second should be error").is_equal("error")

func test_multiple_logs() -> void:
	var logger: GBLogger = make_logger(DBG_LEVEL.DEBUG)

	var received: Array[String] = []
	var sink: Callable = func(_level: int, _context: String, message: String) -> void:
		received.append(message)

	logger.set_log_sink(sink)

	logger.log_debug(self, "first")
	logger.log_debug(self, "second")
	logger.log_debug(self, "third")

	assert_that(received.size()).append_failure_message("Should receive 3 messages").is_equal(3)
	assert_that(received[0]).is_equal("first")
	assert_that(received[1]).is_equal("second")
	assert_that(received[2]).is_equal("third")
