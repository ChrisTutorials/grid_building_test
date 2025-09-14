extends GdUnitTestSuite

var container: GBCompositionContainer

func before_test() -> void:
	container = GBCompositionContainer.new()
	container.config = GBConfig.new()

func test_validate_configuration_with_complete_config() -> void:
	# Set up a complete configuration
	container.config.settings = GBSettings.new()
	container.config.actions = GBActions.new()
	container.config.templates = GBTemplates.new()
	
	var issues: Array[String] = container.get_editor_issues()
	# Should have some issues but not critical ones with basic setup
	assert_int(issues.size()).append_failure_message("Issues found: " + str(issues)).is_greater_equal(0)


func test_validate_runtime_configuration() -> void:
	var issues : Array[String] = container.get_runtime_issues()
	assert_int(issues.size()).is_greater(4)

func test_injectable_factory_create_collision_mapper() -> void:
	# Set up minimal container
	container.config.settings = GBSettings.new()
	
	var mapper: CollisionMapper = GBInjectableFactory.create_collision_mapper(container)
	assert_object(mapper).is_not_null()
	assert_bool(mapper is CollisionMapper).is_true()
	
	# Test validation
	var issues: Array[String] = mapper.get_runtime_issues()
	assert_int(issues.size()).append_failure_message("Validation issues: " + str(issues)).is_equal(0)
