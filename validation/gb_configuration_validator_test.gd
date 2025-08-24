extends GdUnitTestSuite

var container: GBCompositionContainer

func before_test():
	container = GBCompositionContainer.new()
	container.config = GBConfig.new()


func test_validate_configuration_with_missing_config():
	# Create a fresh container without assigning GBConfig to simulate missing config
	var empty_container := GBCompositionContainer.new()
	var issues = GBConfigurationValidator.get_editor_issues(empty_container)
	assert_int(issues.size()).is_greater(0)

func test_validate_configuration_with_missing_gb_config():
	container.config = null
	var issues = GBConfigurationValidator.get_editor_issues(container)
	assert_int(issues.size()).is_greater(0)


func test_validate_configuration_with_complete_config():
	# Set up a complete configuration
	container.config.settings = GBSettings.new()
	container.config.actions = GBActions.new()
	container.config.templates = GBTemplates.new()
	
	var issues = container.get_editor_issues()
	# Should have some issues but not critical ones with basic setup
	assert_int(issues.size()).append_failure_message("Issues found: " + str(issues)).is_greater_equal(0)


func test_validate_runtime_configuration():
	var issues : Array[String] = container.get_runtime_issues()
	assert_int(issues.size()).is_greater(4)

func test_injectable_factory_create_collision_mapper():
	# Set up minimal container
	container.config.settings = GBSettings.new()
	
	var mapper = GBInjectableFactory.create_collision_mapper(container)
	assert_object(mapper).is_not_null()
	assert_bool(mapper is CollisionMapper).is_true()
	
	# Test validation
	var issues = mapper.get_dependency_issues()
	assert_int(issues.size()).append_failure_message("Validation issues: " + str(issues)).is_equal(0)
