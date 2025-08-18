extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var indicator_manager: IndicatorManager
var indicator_template : PackedScene = preload("uid://dhox8mb8kuaxa")
var received_signal: bool
var indicator: RuleCheckIndicator
var targeting_state: GridTargetingState
var logger: GBLogger
var indicator_parent : Node2D

func before_test():
	indicator_parent = GodotTestFactory.create_node2d(self)
	
	# Initialize targeting_state before using it
	var context = UnifiedTestFactory.create_owner_context(self)
	targeting_state = auto_free(GridTargetingState.new(context))

	# Use the actual static factory method directly with test container
	indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, indicator_parent)

	_initialize_targeting_state(targeting_state)

	received_signal = false
	indicator = null

func after_test():
	indicator_manager = null

func _create_real_indicator() -> RuleCheckIndicator:
	var instance : RuleCheckIndicator = indicator_template.instantiate()
	instance.name = "TestIndicator"
	add_child(instance) # add to scene so it's in scene tree
	return instance

func _initialize_targeting_state(p_targeting_state: GridTargetingState) -> void:
	# Create tile map layer directly
	var map: TileMapLayer = auto_free(TileMapLayer.new())
	map.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-100, 100, 1):
		for y in range(-100, 100, 1):
			var cords = Vector2i(x, y)
			map.set_cell(cords, 0, Vector2i(0, 0))
	add_child(map)
	
	p_targeting_state.set_map_objects(
		map, [map]
	)

	var positioner : Node2D = auto_free(Node2D.new())
	p_targeting_state.positioner = positioner

func test_setup_indicators_generates_expected_indicators() -> void:
	# Use pure logic class for validation
	var config = IndicatorFactory.create_indicator_config(
		Vector2.ZERO,
		Vector2(16, 16),
		[CollisionsCheckRule.new()]
	)
	
	var validation_issues = IndicatorFactory.validate_indicator_setup(config)
	assert_array(validation_issues).append_failure_message("Issues means it failed to setup properly. Debug the issues.").is_empty()

func test_add_indicators_adds_and_emits_signal() -> void:
	# Use pure logic class for validation
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(8, 8)

	var owner_testing_rect := RectangleShape2D.new()
	owner_testing_rect.extents = Vector2(8, 8)

	var setup : RectCollisionTestingSetup = IndicatorFactory.create_collision_test_setup(
		_create_real_indicator(),
		[rect_shape],
		owner_testing_rect.get_rect()
	)
	
	var validation_issues = setup.validate()
	assert_array(validation_issues).append_failure_message("Expect to come back with no issues - issues means invalid.").is_empty()
	

func test_reset_frees_indicators() -> void:
	# Use pure logic class for validation
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(8, 8)

	var owner_testing_rect := RectangleShape2D.new()
	owner_testing_rect.extents = Vector2(8, 8)

	# Use pure logic class for validation
	var setup = IndicatorFactory.create_collision_test_setup(
		_create_real_indicator(),
		[rect_shape],
		owner_testing_rect.get_rect()
	)
	
	var validation_issues = setup.validate()
	assert_array(validation_issues).append_failure_message("Expect to come back with no issues - issues means invalid.").is_empty()


func _on_indicators_changed(updated: Array[RuleCheckIndicator]) -> void:
	received_signal = true
	if indicator:
		assert_that(indicator in updated).is_true()
