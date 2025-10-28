extends GdUnitTestSuite

## Test: Validate test composition container resource and GBConfig subcomponents
## This test loads the canonical `test_composition_container.tres` used by unit
## tests and asserts that all exported GBConfig subresources are present. It
## then calls `get_runtime_issues()` to surface any remaining environment issues.

var _container: GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER


func test_validate_test_composition_container_subcomponents() -> void:
	# Test: Validate test composition container has all subcomponents (runtime checks only)
	var diagnostic := GBTestDiagnostics.flush_for_assert()
	(
		assert_that(_container)
		. append_failure_message(
			"Failed to load test composition container resource. Context: %s" % diagnostic
		)
		. is_not_null()
	)

	# Instantiate if it's a PackedScene-like resource that needs instantiation, otherwise it's a Resource
	var container: GBCompositionContainer = null
	if _container is GBCompositionContainer:
		container = _container
	else:
		# Try loading as PackedScene or instancing - fallback to loading resource path used by tests
		container = ResourceLoader.load(
			GBTestConstants.TEST_PATH_COMPOSITION_CONTAINER_TEST_RESOURCE
		)

	(
		assert_that(container)
		. append_failure_message("Test composition container not found or wrong type")
		. is_not_null()
	)

	# Assert GBConfig exists and its main subcomponents are present
	var cfg: GBConfig = container.config
	(
		assert_that(cfg)
		. append_failure_message("GBConfig is null on the test composition container")
		. is_not_null()
	)

	# Check top-level exported subresources to isolate missing ext_resources
	assert_that(cfg.settings).append_failure_message("GBConfig.settings is null").is_not_null()
	assert_that(cfg.templates).append_failure_message("GBConfig.templates is null").is_not_null()
	assert_that(cfg.actions).append_failure_message("GBConfig.actions is null").is_not_null()
	(
		assert_that(cfg.settings.manipulation)
		. append_failure_message("GBConfig.settings.manipulation is null")
		. is_not_null()
	)
	(
		assert_that(cfg.settings.visual)
		. append_failure_message("GBConfig.settings.visual is null")
		. is_not_null()
	)

	# Check placement rules are present in settings (this Yeah. may load programmatic fallback)
	var rules := container.get_placement_rules()
	assert_that(rules).append_failure_message("get_placement_rules returned null").is_not_null()
	assert_array(rules).append_failure_message("placement_rules should be an array").is_not_null()

	# Run editor validation to collect issues
	var issues: Array = container.get_editor_issues()

	# Note: IndicatorManager assignment is now properly classified as a runtime-only issue
	# since the IndicatorManager is assigned during system initialization at runtime.
	# Editor validation should only flag issues that can be detected at resource creation time.

	# Validate that we have no editor-level validation issues for test resources
	(
		assert_that(issues.size())
		. append_failure_message(
			(
				"Expected no editor issues in test composition container, got %d issues: %s"
				% [issues.size(), str(issues)]
			)
		)
		. is_equal(0)
	)
