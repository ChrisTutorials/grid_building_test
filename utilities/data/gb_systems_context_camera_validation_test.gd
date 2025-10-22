## Unit tests for GBSystemsContext Camera2D validation functionality
extends GdUnitTestSuite

var test_context: GBSystemsContext
var test_logger: GBLogger
var test_runtime_checks: GBRuntimeChecks

func before_test() -> void:
	# Setup test logger with debug settings
	var debug_settings := GBDebugSettings.new()
	debug_settings.level = GBDebugSettings.LogLevel.VERBOSE
	test_logger = GBLogger.new(debug_settings)

	# Create test context
	test_context = GBSystemsContext.new(test_logger)

	# Create runtime checks with Camera2D enabled
	test_runtime_checks = GBRuntimeChecks.new()
	test_runtime_checks.camera_2d = true

func after_test() -> void:
	if test_context:
		test_context = null
	if test_logger:
		test_logger = null
	if test_runtime_checks:
		test_runtime_checks = null

## Test: Camera2D validation detects missing Camera2D
## Setup: Context with no Camera2D in viewport
## Act: Get runtime issues with camera_2d check enabled
## Assert: Issue reported about missing Camera2D
func test_camera_2d_validation_detects_missing_camera() -> void:
	var issues: Array[String] = test_context.get_runtime_issues(test_runtime_checks)

	# Should report Camera2D missing
	var has_camera_issue: bool = false
	for issue in issues:
		if "Camera2D not found in viewport" in issue:
			has_camera_issue = true
			break

	assert_bool(has_camera_issue).is_true().append_failure_message(
		"Expected Camera2D validation issue to be reported. Issues: %s" % [str(issues)]
	)

## Test: Camera2D validation skipped when disabled
## Setup: Context with camera_2d check disabled
## Act: Get runtime issues with camera_2d = false
## Assert: No Camera2D issues reported
func test_camera_2d_validation_skipped_when_disabled() -> void:
	test_runtime_checks.camera_2d = false

	var issues: Array[String] = test_context.get_runtime_issues(test_runtime_checks)

	# Should NOT report Camera2D missing
	var has_camera_issue: bool = false
	for issue in issues:
		if "Camera2D not found in viewport" in issue:
			has_camera_issue = true
			break

	assert_bool(has_camera_issue).is_false().append_failure_message(
		"Camera2D validation should be skipped when disabled. Issues: %s" % [str(issues)]
	)

## Test: Camera2D detection helper handles missing viewport gracefully
## Setup: Context with no systems to provide viewport access
## Act: Call helper method directly
## Assert: Returns false without crashing
func test_camera_2d_helper_handles_missing_viewport() -> void:
	# This should not crash and should return false
	var has_camera: bool = test_context._has_camera_2d_in_viewport()

	assert_bool(has_camera).is_false().append_failure_message(
		"Expected _has_camera_2d_in_viewport to return false when no viewport is available"
	)

## Test: Runtime checks validation with all systems disabled
## Setup: Context with all system validation disabled
## Act: Get runtime issues
## Assert: Only Camera2D issue reported (if enabled)
func test_runtime_checks_with_all_systems_disabled() -> void:
	test_runtime_checks.building_system = false
	test_runtime_checks.targeting_system = false
	test_runtime_checks.manipulation_system = false
	test_runtime_checks.camera_2d = true

	var issues: Array[String] = test_context.get_runtime_issues(test_runtime_checks)

	# Should only report Camera2D missing, not system issues
	var camera_issue_count: int = 0
	var system_issue_count: int = 0

	for issue in issues:
		if "Camera2D not found in viewport" in issue:
			camera_issue_count += 1
		elif "system is not set" in issue:
			system_issue_count += 1

	assert_int(camera_issue_count).is_equal(1).append_failure_message(
		"Expected exactly one Camera2D issue. Issues: %s" % [str(issues)]
	)
	assert_int(system_issue_count).is_equal(0).append_failure_message(
		"Expected no system issues when all system checks are disabled. Issues: %s" % [str(issues)]
	)