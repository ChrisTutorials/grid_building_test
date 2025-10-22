extends GdUnitTestSuite

## Test for verifying IndicatorManager initialization in IndicatorContext
## This addresses the issue: "IndicatorManager is not assigned in IndicatorContext"
## found in demo composition containers

var env : BuildingTestEnvironment
var _container: GBCompositionContainer

func before_test() -> void:
	# Use a basic test environment
	var runner: GdUnitSceneRunner = scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID)
	env = runner.scene() as BuildingTestEnvironment
	await_idle_frame()
	_container = env.get_container()

func after_test() -> void:
	_container = null

func test_indicator_context_reports_missing_manager_initially() -> void:
	# Create a fresh IndicatorContext without pre-assigned manager
	var fresh_indicator_context: IndicatorContext = IndicatorContext.new()
	auto_free(fresh_indicator_context)

	# Initially, fresh context should report that IndicatorManager is not assigned
	var initial_issues : Array[String] = fresh_indicator_context.get_runtime_issues()
	assert_array(initial_issues).append_failure_message(
		"IndicatorContext should return an array of issues"
	).is_not_empty()

	var has_manager_issue : bool = false
	for issue in initial_issues:
		if "IndicatorManager is not assigned in IndicatorContext" in issue:
			has_manager_issue = true
			break

	assert_bool(has_manager_issue).append_failure_message(
		"IndicatorContext should report IndicatorManager not assigned initially. Issues found: %s" % str(initial_issues)
	).is_true()

	# Should not have a manager initially
	assert_bool(fresh_indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should not have a manager initially"
	).is_false()

func test_indicator_context_after_manager_assignment() -> void:
	# Get the indicator context from container
	var indicator_context: IndicatorContext = _container.get_indicator_context()

	# Create and assign an IndicatorManager
	var indicator_manager: IndicatorManager = env.indicator_manager
	indicator_context.set_manager(indicator_manager)

	# After assignment, should have no runtime issues
	var post_assignment_issues : Array[String] = indicator_context.get_runtime_issues()
	assert_array(post_assignment_issues).append_failure_message(
		"IndicatorContext should have no runtime issues after IndicatorManager assignment, but found: %s" % str(post_assignment_issues)
	).is_empty()

	# Should have a manager
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should have a manager after assignment"
	).is_true()

	# Should be able to retrieve the same manager
	var retrieved_manager : IndicatorManager = indicator_context.get_manager()
	assert_object(retrieved_manager).append_failure_message(
		"Should be able to retrieve the assigned IndicatorManager"
	).is_same(indicator_manager)

func test_indicator_context_manager_changed_signal() -> void:
	# Get the indicator context from container
	var indicator_context: IndicatorContext = _container.get_indicator_context()

	# Create and assign an IndicatorManager
	var indicator_manager: IndicatorManager = env.indicator_manager
	indicator_context.set_manager(indicator_manager)

	# Verify manager was set (basic functionality test)
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should have manager after assignment"
	).is_true()

	# Test setting the same manager doesn't cause issues
	indicator_context.set_manager(indicator_manager)
	assert_bool(indicator_context.has_manager()).append_failure_message(
		"IndicatorContext should still have manager after re-assignment"
	).is_true()

func test_composition_container_validation_with_manager() -> void:
	# Create a fresh composition container without pre-assigned manager
	var fresh_container: GBCompositionContainer = GBCompositionContainer.new()
	fresh_container.config = _container.config  # Copy the config
	auto_free(fresh_container)

	# Before manager assignment, fresh container should have runtime issues
	var initial_issues : Array[String] = fresh_container.get_runtime_issues()
	var has_indicator_manager_issue : bool = false
	for issue in initial_issues:
		if "IndicatorManager is not assigned in IndicatorContext" in issue:
			has_indicator_manager_issue = true
			break

	assert_bool(has_indicator_manager_issue).append_failure_message(
		"Composition container should report IndicatorManager not assigned issue initially. Issues found: %s" % str(initial_issues)
	).is_true()

	# Assign IndicatorManager to fresh context
	var indicator_context: IndicatorContext = fresh_container.get_indicator_context()
	var indicator_manager: IndicatorManager = env.indicator_manager
	indicator_context.set_manager(indicator_manager)

	# After assignment, the specific issue should be resolved
	var post_assignment_issues : Array[String] = fresh_container.get_runtime_issues()
	var still_has_indicator_manager_issue : bool = false
	for issue : String in post_assignment_issues:
		if "IndicatorManager is not assigned in IndicatorContext" in issue:
			still_has_indicator_manager_issue = true
			break

	assert_bool(still_has_indicator_manager_issue).append_failure_message(
		"Composition container should not report IndicatorManager issue after assignment. Issues found: %s" % str(post_assignment_issues)
	).is_false()
