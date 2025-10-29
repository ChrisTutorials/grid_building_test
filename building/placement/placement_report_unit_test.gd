extends GdUnitTestSuite

# High-value unit tests targeting failures seen in integration:
# - PlacementReport.is_successful / get_issues
# - RuleResult backward compatibility (is_empty alias)
# - ValidationResults aggregation using mixed RuleResult API

var _dummy_rule: PlacementRule


func before_test() -> void:
	_dummy_rule = PlacementRule.new()


func after_test() -> void:
	_dummy_rule = null


func test_rule_result_backward_compatibility_is_empty() -> void:
	var rr := RuleResult.new(_dummy_rule)
	(
		assert_that(rr.is_empty()) \
		. append_failure_message("RuleResult should be empty initially") \
		. is_true()
	)
	(
		assert_that(rr.get_issues()) \
		. append_failure_message("RuleResult should have no issues initially") \
		. is_empty()
	)
	rr.add_issue("failure A")
	(
		assert_that(rr.is_empty()) \
		. append_failure_message("RuleResult should not be empty after adding issue") \
		. is_false()
	)
	(
		assert_array(rr.get_issues()) \
		. append_failure_message("RuleResult should have exactly one issue") \
		. has_size(1)
	)


func test_validation_results_mixed_api_support() -> void:
	var rr1 := RuleResult.new(_dummy_rule)  # empty success
	var rr2 := RuleResult.new(_dummy_rule)
	rr2.add_issue("problem")
	var vr := ValidationResults.new(true, "", {_dummy_rule: rr2})
	vr.add_rule_result(_dummy_rule, rr1)  # overwrite with success version
	(
		assert_that(vr.has_failing_rules()) \
		. append_failure_message(
			"ValidationResults should not have failing rules after adding success result"
		) \
		. is_false()
	)
	(
		assert_that(vr.is_successful()) \
		. append_failure_message(
			"ValidationResults should be successful after adding success result"
		) \
		. is_true()
	)
	# Re-add failing
	vr.add_rule_result(_dummy_rule, rr2)
	(
		assert_that(vr.has_failing_rules()) \
		. append_failure_message(
			"ValidationResults should have failing rules after adding failing result"
		) \
		. is_true()
	)
	(
		assert_array(vr.get_issues()) \
		. append_failure_message("ValidationResults should have exactly one issue") \
		. has_size(1)
	)


func test_placement_report_aggregates_indicator_and_primary_issues() -> void:
	var rr := RuleResult.new(_dummy_rule)
	rr.add_issue("rule collision fail")
	var _vr := ValidationResults.new(false, "", {_dummy_rule: rr})
	# Use real IndicatorSetupReport with no rules -> will produce built-in issues
	var ind_report := IndicatorSetupReport.new([], null, null)
	# Manually add an indicator-level issue
	ind_report.add_issue("indicator generation fail")
	var dummy_owner_root: Node2D = auto_free(Node2D.new())
	var dummy_owner: GBOwner = auto_free(GBOwner.new())
	dummy_owner.owner_root = dummy_owner_root
	var preview: Node2D = auto_free(Node2D.new())
	var report := PlacementReport.new(dummy_owner, preview, ind_report, GBEnums.Action.BUILD)
	report.add_issue("primary fail")
	var issues := report.get_issues()
	# Expect at least the manually added and primary issue; rule collision fail comes via ValidationResults only if indicators_report exposes it.
	(
		assert_that(issues.size() > 1) \
		. append_failure_message(
			"PlacementReport should aggregate multiple issues from indicator and primary sources"
		) \
		. is_true()
	)


func test_validation_results_stores_both_errors_and_issues() -> void:
	# Test: ValidationResults should expose both configuration errors and rule validation failures
	# Setup: Create ValidationResults with both error types
	# Act: Call get_errors() and get_issues()
	# Assert: Both types of problems are captured separately

	var validation_results := ValidationResults.new(false, "", {})

	# Add configuration error
	validation_results.add_error("Camera2D not found in viewport")

	# Add a rule with validation issues
	var rule_with_issues := RuleResult.new(_dummy_rule)
	rule_with_issues.add_issue("collision detected on tile (5,7)")
	rule_with_issues.add_issue("boundary violation at position X")
	validation_results.add_rule_result(_dummy_rule, rule_with_issues)

	# Act: Get both error types
	var config_errors: Array[String] = validation_results.get_errors()
	var validation_issues: Array[String] = validation_results.get_issues()

	# Assert: Configuration errors are captured
	(
		assert_array(config_errors) \
		. contains_exactly(["Camera2D not found in viewport"]) \
		. append_failure_message("Expected configuration error to be captured in get_errors()")
	)

	# Assert: Rule validation issues are captured
	var expected_issues: Array[String] = [
		"collision detected on tile (5,7)", "boundary violation at position X"
	]
	assert_array(validation_issues).contains_exactly(expected_issues).append_failure_message(
		"Expected rule validation failures to be captured in get_issues()"
	)

	# Assert: Both collections should be non-empty when both error types exist
	assert_bool(config_errors.is_empty()).is_false().append_failure_message(
		"Configuration errors should not be empty"
	)
	assert_bool(validation_issues.is_empty()).is_false().append_failure_message(
		"Validation issues should not be empty"
	)


func test_placement_report_collects_validation_results_comprehensively() -> void:
	# Test: PlacementReport should collect issues from ValidationResults.get_errors() AND get_issues()
	# Setup: ValidationResults with both configuration errors and rule validation failures
	# Act: Create PlacementReport and check collected issues
	# Assert: Both error types appear in PlacementReport.get_issues()

	var validation_results := ValidationResults.new(false, "", {})

	# Add configuration error
	validation_results.add_error("Camera2D not found in viewport")

	# Add rule validation failures
	var collision_rule := RuleResult.new(_dummy_rule)
	collision_rule.add_issue("Colliding on 8 tile(s)")
	validation_results.add_rule_result(_dummy_rule, collision_rule)

	# Create indicator report (minimal, just test the core concept)
	var dummy_tile_rules: Array[TileCheckRule] = []
	var dummy_targeting_state: GridTargetingState = null
	var dummy_template: PackedScene = null
	var clean_indicator_report := IndicatorSetupReport.new(
		dummy_tile_rules, dummy_targeting_state, dummy_template
	)

	# Create PlacementReport and simulate BuildingSystem.try_build() behavior
	var dummy_owner_root: Node2D = auto_free(Node2D.new())
	var dummy_owner: GBOwner = auto_free(GBOwner.new())
	dummy_owner.owner_root = dummy_owner_root
	var preview: Node2D = auto_free(Node2D.new())

	var placement_report := PlacementReport.new(
		dummy_owner, preview, clean_indicator_report, GBEnums.Action.BUILD
	)

	# Simulate the fixed BuildingSystem.try_build() logic: collect BOTH error types
	var config_errors: Array[String] = validation_results.get_errors()
	var validation_issues: Array[String] = validation_results.get_issues()

	# Add both to PlacementReport (as BuildingSystem now does)
	for error in config_errors:
		placement_report.add_issue(error)
	for issue in validation_issues:
		placement_report.add_issue(issue)

	# Act: Get all issues from PlacementReport
	var all_issues: Array[String] = placement_report.get_issues()

	# Assert: Both configuration errors and validation issues are present
	assert_bool(all_issues.has("Camera2D not found in viewport")).is_true().append_failure_message(
		"Expected configuration error in PlacementReport. Got: %s" % str(all_issues)
	)

	assert_bool(all_issues.has("Colliding on 8 tile(s)")).is_true().append_failure_message(
		"Expected validation issue in PlacementReport. Got: %s" % str(all_issues)
	)

	# Assert: PlacementReport correctly reports failure status
	assert_bool(placement_report.is_successful()).is_false().append_failure_message(
		"PlacementReport should report failure when validation issues exist"
	)
