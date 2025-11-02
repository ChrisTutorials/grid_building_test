## Tests GBActionLog UI component validation and message display functionality.
##
## Validates build/validation results are displayed correctly based on ActionLogSettings.
extends GdUnitTestSuite

# Test constants for magic number elimination
const TEST_COLLISION_COUNT: int = 5
const TEST_TILE_POSITION: String = "(5, 3)"
const EXPECTED_RULE_COUNT: int = 2
const DEFAULT_BUILDING_NAME: String = "TestBuilding"
const SMITHY_BUILDING_NAME: String = "TestSmithyBuilding"
const HOUSE_BUILDING_NAME: String = "TestHouseBuilding"

# Test message constants
const COLLISION_FAILURE_REASON: String = "Colliding on 5 tile(s)"
const STRUCTURE_BLOCKING_REASON: String = "Blocked by existing structure"
const VALIDATION_FAILED_MESSAGE: String = "Placement validation failed with issues."
const COLLISION_AT_TILE_REASON: String = "Collision detected at tile (5, 3)"
const OUTSIDE_BOUNDARY_REASON: String = "Outside tilemap boundary"
const SUCCESS_VALIDATION_MESSAGE: String = "Validation passed successfully"
const NO_COLLISION_SUCCESS_REASON: String = "No collisions detected"
const WITHIN_BOUNDS_SUCCESS_REASON: String = "Position within valid bounds"

# Additional test message constants
const HIDDEN_FAILURE_REASON: String = "Should not appear in log"
const HIGH_LEVEL_ISSUE: String = "Build failed due to rule violations"
const SUCCESS_MESSAGE: String = "Success validation message"
const SECRET_FAILURE_DETAILS: String = "Secret failure details should not appear"

var action_log: GBActionLog
var message_label: RichTextLabel
var test_settings: ActionLogSettings
var test_container: GBCompositionContainer


func before_test() -> void:
	# Create test components with auto_free to prevent orphan nodes
	action_log = auto_free(GBActionLog.new())
	message_label = auto_free(RichTextLabel.new())
	action_log.message_log = message_label

	# Create test settings with failed reasons enabled
	test_settings = auto_free(ActionLogSettings.new())
	test_settings.print_failed_reasons = true
	test_settings.print_on_drag_build = false
	test_settings.show_validation_message = true

	# Create test container with proper config structure
	test_container = auto_free(GBCompositionContainer.new())
	var test_config: GBConfig = auto_free(GBConfig.new())
	var gb_settings: GBSettings = auto_free(GBSettings.new())
	test_config.settings = gb_settings
	test_container.config = test_config

	# Create mock actions
	var mock_actions: GBActions = auto_free(GBActions.new())

	# Resolve states from container instead of creating manually
	var resolved_states: GBStates = test_container.get_states()
	var building_state: BuildingState = resolved_states.building
	var manipulation_state: ManipulationState = resolved_states.manipulation

	# Set dependencies (simulating injection)
	action_log._settings = test_settings
	action_log._actions = mock_actions
	action_log._building_state = building_state
	action_log._manipulation_state = manipulation_state


func after_test() -> void:
	# Cleanup handled automatically by auto_free() in before_test()
	# No manual queue_free() needed to prevent double-free issues
	pass


#region DRY Helper Methods


## Creates a standard failed ValidationResults with collision and structure blocking issues
func _create_failed_validation_results() -> ValidationResults:
	var validation_results: ValidationResults = ValidationResults.new()
	var mock_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var rule_result: RuleResult = RuleResult.new(mock_rule)
	rule_result.issues = [COLLISION_FAILURE_REASON, STRUCTURE_BLOCKING_REASON]
	validation_results.add_rule_result(mock_rule, rule_result)
	validation_results.message = VALIDATION_FAILED_MESSAGE
	return validation_results


## Creates a successful ValidationResults with optional success reasons
func _create_successful_validation_results(include_reasons: bool = false) -> ValidationResults:
	var validation_results: ValidationResults = ValidationResults.new()
	validation_results.message = SUCCESS_VALIDATION_MESSAGE

	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var collision_result: RuleResult = RuleResult.new(collision_rule)
	collision_result.issues = []  # No issues = success

	var bounds_rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	var bounds_result: RuleResult = RuleResult.new(bounds_rule)
	bounds_result.issues = []  # No issues = success

	# Note: RuleResult doesn't currently support success reasons
	# This test validates the print_success_reasons pathway is executed
	if include_reasons:
		# Success reasons would be implemented here if RuleResult supported them
		# Currently testing pathway execution without detailed success messages
		pass

	validation_results.add_rule_result(collision_rule, collision_result)
	validation_results.add_rule_result(bounds_rule, bounds_result)
	return validation_results


## Creates a PlacementReport with specified issues
func _create_placement_report_with_issues(issues: Array[String]) -> PlacementReport:
	var placement_report: PlacementReport = PlacementReport.new(
		GBOwnerContext.new().get_owner(), null, null, GBEnums.Action.BUILD  # preview  # indicators_report
	)
	for issue in issues:
		placement_report.add_issue(issue)
	return placement_report


## Creates BuildActionData with specified placeable name and placement report
func _create_build_action_data(
	building_name: String, placement_report: PlacementReport
) -> BuildActionData:
	var test_placeable: Placeable = Placeable.new()
	test_placeable.display_name = building_name

	# Create a preview instance for proper display name
	# Use auto_free to prevent orphan nodes
	var preview_instance: Node2D = auto_free(Node2D.new())
	# Convert "Test Smithy Building" -> "TestSmithyBuildingPreview"
	preview_instance.name = building_name.replace(" ", "") + "Preview"
	placement_report.preview_instance = preview_instance

	return BuildActionData.new(test_placeable, placement_report, GBEnums.BuildType.SINGLE)


## Asserts that log contains expected failure messages with proper diagnostic context
func _assert_failure_messages_present(
	log_text: String, readable_name: String, expected_reasons: Array[String]
) -> void:
	(
		assert_str(log_text) \
		. append_failure_message(
			"Expected main failure message for '%s' in log: '%s'" % [readable_name, log_text]
		) \
		. is_not_empty()
	)
	for reason in expected_reasons:
		(
			assert_str(log_text) \
			. append_failure_message(
				"Expected failure reason '%s' in log: '%s'" % [reason, log_text]
			) \
			. contains(reason)
		)


## Asserts that log does not contain specified failure reasons
func _assert_failure_messages_absent(log_text: String, absent_reasons: Array[String]) -> void:
	for reason in absent_reasons:
		(
			assert_str(log_text) \
			. append_failure_message(
				"Expected failure reason '%s' to be hidden in log: '%s'" % [reason, log_text]
			) \
			. not_contains(reason)
		)


#endregion
#region Validation Results Tests


## Test: append_validation_results shows failed reasons when print_failed_reasons=true
## Setup: ActionLogSettings with print_failed_reasons=true, failed validation results
## Act: Call append_validation_results with failed ValidationResults
## Assert: Both validation message and detailed failure reasons appear in log
func test_append_validation_results_shows_failed_reasons_when_enabled() -> void:
	# Setup: Create validation results with failed rules
	var validation_results: ValidationResults = _create_failed_validation_results()

	# Act: Process validation results
	action_log.append_validation_results(validation_results)
	action_log.append_validation_results(validation_results)

	# Get log text for assertions
	var log_text: String = message_label.get_parsed_text()

	# Assert: Failed reasons should appear in log
	(
		assert_str(log_text) \
		. append_failure_message(
			"Expected collision failure reason in log text: '%s'" % log_text
		) \
		. contains(COLLISION_FAILURE_REASON)
	)
	(
		assert_str(log_text) \
		. append_failure_message(
			"Expected structure blocking reason in log text: '%s'" % log_text
		) \
		. contains(STRUCTURE_BLOCKING_REASON)
	)
	(
		assert_str(log_text) \
		. append_failure_message(
			"Expected validation message in log text: '%s'" % log_text
		) \
		. contains("Placement validation failed")
	)


func test_append_validation_results_respects_disabled_failed_reasons() -> void:
	# Setup: Disable failed reasons printing
	test_settings.print_failed_reasons = false

	# Create validation results with failed rules
	var validation_results: ValidationResults = ValidationResults.new()
	var mock_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	var rule_result: RuleResult = RuleResult.new(mock_rule)
	rule_result.issues = [HIDDEN_FAILURE_REASON]
	validation_results.add_rule_result(mock_rule, rule_result)

	# Act: Process validation results
	action_log.append_validation_results(validation_results)

	# Assert: Failed reasons should not appear in log
	var log_text: String = message_label.get_parsed_text()
	(
		assert_str(log_text) \
		. append_failure_message(
			(
				"Expected failed reason to be hidden when print_failed_reasons=false, but found in: '%s'"
				% log_text
			)
		) \
		. not_contains(HIDDEN_FAILURE_REASON)
	)

#endregion

#region Build Result Handler Tests

## Test: _handle_build_result shows high-level placement report issues
func test_handle_build_result_shows_placement_report_issues() -> void:
	# Setup
	var placement_report: PlacementReport = \
		_create_placement_report_with_issues([HIGH_LEVEL_ISSUE])
	var build_data: BuildActionData = \
		_create_build_action_data(DEFAULT_BUILDING_NAME, placement_report)

	# Act
	action_log._handle_build_result(build_data, false)

	# Assert
	var log_text: String = message_label.get_parsed_text()
	assert_str(log_text) \
		.append_failure_message("Expected high-level failure message in log text: '%s'" % log_text) \
		.contains(HIGH_LEVEL_ISSUE)

#endregion#endregion
