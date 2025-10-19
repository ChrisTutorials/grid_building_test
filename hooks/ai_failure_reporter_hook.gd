## AI-focused test failure reporter hook
## Reports only failures, errors, and skipped tests for efficient AI analysis
## Generates JSON output focused on issues that need fixing
class_name GdUnitAIFailureReporterHook
extends GdUnitTestSessionHook

var _failures: Array[Dictionary] = []
var _errors: Array[Dictionary] = []
var _skipped: Array[Dictionary] = []

## Property setter pattern that manages signal connection automatically
var test_session: GdUnitTestSession:
	get:
		return test_session
	set(value):
		# Disconnect previous session if exists
		if test_session != null:
			test_session.test_event.disconnect(_on_test_event)
		# Connect to new session
		test_session = value
		if test_session != null:
			test_session.test_event.connect(_on_test_event)

func _init() -> void:
	super("GdUnit AI Failure Reporter", "Reports only test failures and errors for AI analysis")

func startup(session: GdUnitTestSession) -> GdUnitResult:
	# Use property setter to establish connection
	test_session = session
	_failures.clear()
	_errors.clear()
	_skipped.clear()
	return GdUnitResult.success()

func shutdown(session: GdUnitTestSession) -> GdUnitResult:
	# Write the report
	var issues: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"timestamp_unix": Time.get_ticks_msec(),
		"error_count": _errors.size(),
		"failure_count": _failures.size(),
		"skipped_count": _skipped.size(),
		"total_issues": _errors.size() + _failures.size() + _skipped.size(),
		"errors": _errors,
		"failures": _failures,
		"skipped": _skipped
	}
	
	var json_output := JSON.stringify(issues, "\t")
	var report_path := session.report_path.get_basename() + "_ai_issues.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(json_output)
		file.close()
		# Always report the file location, even if no issues
		if issues["total_issues"] > 0:
			session.send_message("AI Issues Report: file://%s | Issues: %d (E:%d F:%d S:%d)" % [
				report_path,
				issues["total_issues"],
				issues["error_count"],
				issues["failure_count"],
				issues["skipped_count"]
			])
		else:
			session.send_message("AI Issues Report: file://%s | All tests passed!" % report_path)
	else:
		push_error("Failed to write AI issues report to: %s" % report_path)
	
	# Clear session reference (property setter will handle disconnection)
	test_session = null
	
	return GdUnitResult.success()

func _on_test_event(event: GdUnitEvent) -> void:
	# Only process test completion events
	if event.type() != GdUnitEvent.TESTCASE_AFTER:
		return
	
	# Get test info from session using GUID
	var test := test_session.find_test_by_id(event.guid())
	if test == null:
		push_warning("AI Hook: Could not find test for GUID: %s" % event.guid())
		return
	
	# Clean up file path
	var file_path: String = test.source_file
	if file_path.find("res://") == 0:
		file_path = file_path.substr(6)
	
	var test_info: Dictionary = {
		"test_name": test.display_name,
		"suite_name": test.suite_name,
		"file": file_path,
		"duration_ms": event.elapsed_time(),
		"orphans": event.orphan_nodes(),
		"reports": []
	}
	
	# Collect reports
	for report in event.reports():
		test_info["reports"].append({
			"message": report.message(),
			"line": report.line_number()
		})
	
	# Only store failed/errored tests (skip passed tests)
	if event.is_error():
		test_info["category"] = "error"
		_errors.append(test_info)
	elif event.is_failed():
		test_info["category"] = "failure"
		_failures.append(test_info)
	elif event.is_skipped():
		test_info["category"] = "skipped"
		_skipped.append(test_info)
