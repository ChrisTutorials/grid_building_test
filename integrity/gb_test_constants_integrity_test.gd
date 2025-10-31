## GBTestConstants Integrity Test Suite
##
## Validates the integrity of GBTestConstants to ensure:
## - No naked string UIDs (all UIDs must be declared as constants)
## - Each UID is declared exactly once (no duplicates)
##
## This prevents maintenance issues where UIDs are hardcoded or duplicated.

extends GdUnitTestSuite

const GB_TEST_CONSTANTS_PATH: String = "res://test/helpers/gb_test_constants.gd"
const UID_REGEX_PATTERN: String = r'"uid://[a-z0-9]+"'
const NAKED_UID_ERROR_TEMPLATE: String = "Naked UID '%s' on line: %s. Must be constant."
const DUPLICATE_UID_ERROR_TEMPLATE: String = "UID '%s' declared multiple times."

# region Test Cases

## Test that no naked string UIDs exist in the codebase
## This forces all UIDs to be declared as constants for maintainability
func test_no_naked_string_uids() -> void:
	var source_code := _load_gb_test_constants_source()
	var uid_pattern := RegEx.new()
	uid_pattern.compile(UID_REGEX_PATTERN)

	var matches := uid_pattern.search_all(source_code)
	for match_obj in matches:
		var uid_string: String = match_obj.get_string()
		var line := _get_line_containing(source_code, uid_string)

		# Skip comments and documentation
		if line.strip_edges().begins_with("##") or line.strip_edges().begins_with("#"):
			continue

		var is_constant_declaration := line.contains("const ") and \
			line.contains(": String = " + uid_string)

		# Allow preload statements (they're the source of truth)
		var is_preload_statement := line.contains("preload(" + uid_string + ")")

		assert_bool(is_constant_declaration or is_preload_statement)\
			.append_failure_message(NAKED_UID_ERROR_TEMPLATE % [uid_string, line.strip_edges()])\
			.is_true()

## Test that each UID is declared exactly once
## Prevents maintenance issues where the same UID is defined multiple times
func test_each_uid_declared_once() -> void:
	var source_code := _load_gb_test_constants_source()
	var string_constant_uids := _collect_string_constant_uids(source_code)
	_assert_no_duplicate_uids(string_constant_uids)

# endregion

# region Helper Methods

## Load the GBTestConstants source code for analysis
static func _load_gb_test_constants_source() -> String:
	var file := FileAccess.open(GB_TEST_CONSTANTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open GBTestConstants file: " + GB_TEST_CONSTANTS_PATH)
		return ""

	var content := file.get_as_text()
	file.close()
	return content

## Collect all UIDs that appear in string constants (excluding preloads and comments)
static func _collect_string_constant_uids(source_code: String) -> Array[String]:
	var string_constant_uids: Array[String] = []
	var lines := source_code.split("\n")

	for line in lines:
		# Skip comments and documentation
		var trimmed_line := line.strip_edges()
		if trimmed_line.begins_with("##") or trimmed_line.begins_with("#"):
			continue

		# Skip preload statements
		if line.contains("preload("):
			continue

		# Look for string constants containing UIDs
		var uid_pattern := RegEx.new()
		uid_pattern.compile(UID_REGEX_PATTERN)
		var matches := uid_pattern.search_all(line)

		for match_obj in matches:
			var uid_string: String = match_obj.get_string()
			# Check if this is a string constant declaration
			if line.contains("const ") and line.contains(": String = " + uid_string):
				string_constant_uids.append(uid_string)

	return string_constant_uids

## Assert that no UIDs are duplicated in the provided array
func _assert_no_duplicate_uids(string_constant_uids: Array[String]) -> void:
	var seen_uids: Dictionary[String, bool] = {}
	for uid in string_constant_uids:
		assert_bool(!seen_uids.has(uid))\
			.append_failure_message(DUPLICATE_UID_ERROR_TEMPLATE % uid)\
			.is_true()
		seen_uids[uid] = true

## Get the line containing the specified text
static func _get_line_containing(source: String, text: String) -> String:
	var lines := source.split("\n")
	for line in lines:
		if line.contains(text):
			return line
	return ""

# endregion