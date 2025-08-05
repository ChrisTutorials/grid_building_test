extends GdUnitTestSuite

## Example test demonstrating the new static factory method pattern for GBInjectable objects

var container: GBCompositionContainer
var targeting_state: GridTargetingState
var logger: GBLogger

func before_test():
	container = UnifiedTestFactory.TEST_CONTAINER
	targeting_state = UnifiedTestFactory.create_double_targeting_state(self)
	logger = UnifiedTestFactory.create_test_logger()

func test_collision_mapper_static_factory():
	# Test the new static factory method
	var collision_mapper = CollisionMapper.create_with_injection(container)
	
	assert_that(collision_mapper).is_not_null()
	assert_that(collision_mapper).is_instance_of(CollisionMapper)
	
	# Verify dependencies were injected
	var validation_issues = collision_mapper.validate_dependencies()
	assert_that(validation_issues).is_empty()

func test_placement_validator_static_factory():
	# Test the new static factory method
	var validator = PlacementValidator.create_with_injection(container)
	
	assert_that(validator).is_not_null()
	assert_that(validator).is_instance_of(PlacementValidator)
	
	# Verify dependencies were injected
	var validation_issues = validator.validate_dependencies()
	assert_that(validation_issues).is_empty()

func test_test_setup_factory_static_factory():
	# Test the new static factory method
	var factory = TestSetupFactory.create_with_injection(container)
	
	assert_that(factory).is_not_null()
	assert_that(factory).is_instance_of(TestSetupFactory)
	
	# Verify dependencies were injected
	var validation_issues = factory.validate_dependencies()
	assert_that(validation_issues).is_empty()

func test_unified_factory_wrapper_methods():
	# Test direct static factory method calls instead of wrapper methods
	var collision_mapper = CollisionMapper.create_with_injection(container)
	var validator = PlacementValidator.create_with_injection(container)
	
	assert_that(collision_mapper).is_not_null()
	assert_that(validator).is_not_null()
	
	# Both should have valid dependencies
	assert_that(collision_mapper.validate_dependencies()).is_empty()
	assert_that(validator.validate_dependencies()).is_empty()
