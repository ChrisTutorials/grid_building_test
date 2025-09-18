extends GdUnitTestSuite

# High-value unit tests targeting failures seen in integration:
# - PlacementReport.is_successful / get_issues
# - RuleResult backward compatibility (is_empty alias)
# - ValidationResults aggregation using mixed RuleResult API

var _dummy_rule : PlacementRule

func before_test() -> void:
	_dummy_rule = PlacementRule.new()

func after_test() -> void:
	_dummy_rule = null

func test_rule_result_backward_compatibility_is_empty() -> void:
	var rr := RuleResult.new(_dummy_rule)
	assert_that(rr.is_empty()).is_true()
	assert_that(rr.get_issues()).is_empty()
	rr.add_issue("failure A")
	assert_that(rr.is_empty()).is_false()
	assert_array(rr.get_issues()).has_size(1)

func test_validation_results_mixed_api_support() -> void:
	var rr1 := RuleResult.new(_dummy_rule) # empty success
	var rr2 := RuleResult.new(_dummy_rule)
	rr2.add_issue("problem")
	var vr := ValidationResults.new(true, "", { _dummy_rule: rr2 })
	vr.add_rule_result(_dummy_rule, rr1) # overwrite with success version
	assert_that(vr.has_failing_rules()).is_false()
	assert_that(vr.is_successful()).is_true()
	# Re-add failing
	vr.add_rule_result(_dummy_rule, rr2)
	assert_that(vr.has_failing_rules()).is_true()
	assert_array(vr.get_issues()).has_size(1)

func test_placement_report_aggregates_indicator_and_primary_issues() -> void:
	var rr := RuleResult.new(_dummy_rule)
	rr.add_issue("rule collision fail")
	var _vr := ValidationResults.new(false, "", { _dummy_rule: rr })
	# Use real IndicatorSetupReport with no rules -> will produce built-in issues
	var ind_report := IndicatorSetupReport.new([], null, null)
	# Manually add an indicator-level issue
	ind_report.add_issue("indicator generation fail")
	var dummy_owner_root: Node2D = auto_free(Node2D.new())
	var dummy_owner : GBOwner = auto_free(GBOwner.new())
	dummy_owner.owner_root = dummy_owner_root
	var preview: Node2D = auto_free(Node2D.new())
	var report := PlacementReport.new(dummy_owner, preview, ind_report, GBEnums.Action.BUILD)
	report.add_issue("primary fail")
	var issues := report.get_issues()
	# Expect at least the manually added and primary issue; rule collision fail comes via ValidationResults only if indicators_report exposes it.
	assert_that(issues.size() > 1).is_true()
