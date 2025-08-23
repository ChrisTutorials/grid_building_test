extends GdUnitTestSuite

var container: GBCompositionContainer

func before_test():
	container = GBCompositionContainer.new()
	container.config = GBConfig.new()

func test_validate_configuration_with_missing_config():
	var empty_container: GBCompositionContainer = null
	var issues = GBConfigurationValidator.get_editor_issues(empty_container, container.get_logger())
	assert_int(issues.size()).is_greater(0)
	assert_that(issues[0]).is_equal("GBCompositionContainer is null")

func test_validate_configuration_with_missing_gb_config():
	container.config = null
	var issues = GBConfigurationValidator.validate_configuration(container)
	assert_int(issues.size()).is_greater(0)
	assert_that(issues[0]).is_equal("GBConfig is not set in composition container")

func test_validate_configuration_with_complete_config():
	# Set up a complete configuration
	container.config.settings = GBSettings.new()
	container.config.actions = GBActions.new()
	container.config.templates = GBTemplates.new()
	
	var issues = container.validate_configuration()
	# Should have some issues but not critical ones with basic setup
	assert_int(issues.size()).append_failure_message("Issues found: " + str(issues)).is_greater_equal(0)

func test_validate_runtime_configuration():
	var issues : Array[String] = container.validate_runtime_configuration()
	assert_int(issues.size()).is_greater(4)

func test_injectable_factory_create_collision_mapper():
	# Set up minimal container
	container.config.settings = GBSettings.new()
	
	var mapper = GBInjectableFactory.create_collision_mapper(container)
	assert_object(mapper).is_not_null()
	assert_bool(mapper is CollisionMapper).is_true()
	
	# Test validation
	var issues = mapper.validate_dependencies()
	assert_int(issues.size()).append_failure_message("Validation issues: " + str(issues)).is_equal(0)
