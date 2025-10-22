extends GdUnitTestSuite

## Example test demonstrating the new static factory method pattern for GBInjectable objects

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var container: GBCompositionContainer
var targeting_state: GridTargetingState


func before_test() -> void:
	container = TEST_CONTAINER
	# Create targeting state directly instead of using factory
	targeting_state = auto_free(GridTargetingState.new(GBOwnerContext.new()))
	var positioner: Node2D = auto_free(Node2D.new())
	targeting_state.positioner = positioner
	var target_map: TileMapLayer = auto_free(TileMapLayer.new())
	add_child(target_map)
	target_map.tile_set = TileSet.new()
	target_map.tile_set.tile_size = Vector2(32, 32)
	targeting_state.target_map = target_map
	var layer1: TileMapLayer = auto_free(TileMapLayer.new())
	var layer2: TileMapLayer = auto_free(TileMapLayer.new())
	targeting_state.maps = [layer1, layer2]


func test_collision_mapper_static_factory() -> void:
	# Test the new static factory method
	var collision_mapper: CollisionMapper = CollisionMapper.create_with_injection(container)

	assert_that(collision_mapper).append_failure_message("CollisionMapper factory should create non-null instance").is_not_null()
	assert_that(collision_mapper).append_failure_message("Factory should create CollisionMapper instance").is_instanceof(CollisionMapper)

	# Verify dependencies were injected
	var validation_issues: Array = collision_mapper.get_runtime_issues()
	assert_that(validation_issues).append_failure_message("CollisionMapper should have no runtime issues after injection").is_empty()


func test_placement_validator_static_factory() -> void:
	# Test the new static factory method
	var validator: PlacementValidator = PlacementValidator.create_with_injection(container)

	assert_that(validator).append_failure_message("PlacementValidator factory should create non-null instance").is_not_null()
	assert_that(validator).append_failure_message("Factory should create PlacementValidator instance").is_instanceof(PlacementValidator)

	# Verify dependencies were injected
	var validation_issues: Array = validator.get_runtime_issues()
	assert_that(validation_issues).append_failure_message("PlacementValidator should have no runtime issues after injection").is_empty()


func test_test_setup_factory_static_factory() -> void:
	# Test the new static factory method
	var factory: TestSetupFactory = TestSetupFactory.create_with_injection(container)

	assert_that(factory).append_failure_message("TestSetupFactory factory should create non-null instance").is_not_null()
	assert_that(factory).append_failure_message("Factory should create TestSetupFactory instance").is_instanceof(TestSetupFactory)

	# Verify dependencies were injected
	var validation_issues: Array = factory.get_runtime_issues()
	assert_that(validation_issues).append_failure_message("TestSetupFactory should have no runtime issues after injection").is_empty()


func test_unified_factory_wrapper_methods() -> void:
	# Test direct static factory method calls instead of wrapper methods
	var collision_mapper: CollisionMapper = CollisionMapper.create_with_injection(container)
	var validator: PlacementValidator = PlacementValidator.create_with_injection(container)

	assert_that(collision_mapper).append_failure_message("CollisionMapper factory should create non-null instance").is_not_null()
	assert_that(validator).append_failure_message("PlacementValidator factory should create non-null instance").is_not_null()

	# Both should have valid dependencies
	assert_that(collision_mapper.get_runtime_issues()).append_failure_message("CollisionMapper should have no runtime issues after injection").is_empty()
	assert_that(validator.get_runtime_issues()).append_failure_message("PlacementValidator should have no runtime issues after injection").is_empty()
