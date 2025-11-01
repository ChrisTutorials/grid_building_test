extends GdUnitTestSuite

# High-value unit tests for IndicatorManager to catch failures in indicator generation and management.
# Focus areas:
#  - IndicatorManager.try_setup generates indicators with valid setup
#  - IndicatorManager handles collision layer/mask matching correctly
#  - IndicatorManager reports issues when setup fails
#  - IndicatorManager manages indicator lifecycle properly

var _logger: GBLogger


func before_test() -> void:
	_logger = GBLogger.new(GBDebugSettings.new())


func test_build_failed_report_returns_expected_issues() -> void:
	# Arrange: Create a fresh IndicatorManager with only logger and owner context set
	var manager: IndicatorManager = IndicatorManager.new()
	auto_free(manager)
	add_child(manager)
	manager._logger = _logger
	var gb_owner: GBOwner = GBOwner.new()
	manager._owner_context = GBOwnerContext.new(gb_owner)
	auto_free(gb_owner)
	var dummy_target: Node2D = auto_free(Node2D.new())
	add_child(dummy_target)
	var issues: Dictionary[String, Array] = {"RuleA": ["A failed"], "RuleB": ["B failed", "B extra"]}

	# Act
	var report: PlacementReport = manager._build_failed_report(issues, dummy_target)

	# Assert
	(
		assert_object(report) \
		. append_failure_message("_build_failed_report should return a non-null PlacementReport") \
		. is_not_null()
	)
	(
		assert_array(report.issues) \
		. append_failure_message("Failed report should contain issues array") \
		. is_not_empty()
	)
	(
		assert_that(report.issues[0]) \
		. append_failure_message(
			"First issue should contain 'A failed' - Issues: %s" % str(report.issues)
		) \
		. contains("A failed")
	)
	(
		assert_that(report.issues[1]) \
		. append_failure_message(
			"Second issue should contain validation setup failure - Issues: %s" % str(report.issues)
		) \
		. contains("Placement validation setup failed")
	)
	(
		assert_that(report.issues[2]) \
		. append_failure_message(
			"Third issue should contain 'Rule ' - Issues: %s" % str(report.issues)
		) \
		. contains("Rule ")
	)
