extends GdUnitTestSuite

## Test: Validate test composition container resource and GBConfig subcomponents
## This test loads the canonical `test_composition_container.tres` used by unit
## tests and asserts that all exported GBConfig subresources are present. It
## then calls `get_runtime_issues()` to surface any remaining environment issues.

var _container : GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER 

func test_validate_test_composition_container_subcomponents() -> void:
	assert_that(_container).append_failure_message("Failed to load test composition container resource: %s" % GBTestConstants.TEST_COMPOSITION_CONTAINER.resource_path).is_not_null()

	# Instantiate if it's a PackedScene-like resource that needs instantiation, otherwise it's a Resource
	var container: GBCompositionContainer = null
	if _container is GBCompositionContainer:
		container = _container
	else:
		# Try loading as PackedScene or instancing - fallback to loading resource path used by tests
		container = ResourceLoader.load("res://test/grid_building_test/resources/composition_containers/test_composition_container.tres")

	assert_that(container).append_failure_message("Test composition container not found or wrong type").is_not_null()

	# Assert GBConfig exists and its main subcomponents are present
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig is null on the test composition container").is_not_null()

	# Check top-level exported subresources to isolate missing ext_resources
	assert_that(cfg.settings).append_failure_message("GBConfig.settings is null").is_not_null()
	assert_that(cfg.templates).append_failure_message("GBConfig.templates is null").is_not_null()
	assert_that(cfg.actions).append_failure_message("GBConfig.actions is null").is_not_null()
	assert_that(cfg.settings.visual).append_failure_message("GBConfig.settings.visual is null").is_not_null()

	# Check placement rules are present in settings (this may load programmatic fallback)
	var rules := container.get_placement_rules()
	assert_that(rules).append_failure_message("get_placement_rules returned null").is_not_null()
	assert_array(rules).append_failure_message("placement_rules should be an array").is_not_null()

	# Finally, run EDITOR validation to collect issues (tests can inspect reported issues)
	var issues: Array = container.get_editor_issues()
	# Attach issues to assertion message for easy triage
	assert_that(issues).append_failure_message("Editor issues: %s" % str(issues)).is_not_null()

	# For test hygiene, expect editor issues to be empty in a well-formed test container
	assert_that(issues.size()).append_failure_message("Expected no editor issues in test composition container: %s" % GBConfigurationValidator.editor_diagnostic(container)).is_equal(0)
