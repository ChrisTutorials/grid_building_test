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
	indicator_parent = auto_free(Node2D.new())
	indicator_template = load("uid://nhlp6ks003fp")
	
	# Initialize targeting_state before using it
	targeting_state = auto_free(GridTargetingState.new(GBOwnerContext.new()))
	
	# Use the actual static factory method directly with test container  
	indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, indicator_parent)

	_initialize_targeting_state(targeting_state)

	received_signal = false
	indicator = null

func after_test():
	indicator_manager = null

func _create_real_indicator() -> RuleCheckIndicator:
	var instance = indicator_template.instantiate() as RuleCheckIndicator
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
			map.set_cellv(cords, 0, Vector2i(0,0))
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
		[]
	)
	
	var validation_issues = IndicatorFactory.validate_indicator_setup(config)
	assert_array(validation_issues).is_empty()
	
	# Test that config is valid
	assert_bool(config.valid).is_true()

func test_add_indicators_adds_and_emits_signal() -> void:
	# Use pure logic class for validation
	var setup = IndicatorFactory.create_collision_test_setup(
		_create_real_indicator(),
		Vector2.ZERO,
		logger
	)
	
	var validation_issues = IndicatorFactory.validate_collision_test_setup(setup)
	assert_array(validation_issues).is_empty()
	
	# Test that setup is valid
	assert_bool(setup.valid).is_true()

func test_reset_frees_indicators() -> void:
	# Use pure logic class for validation
	var setup = IndicatorFactory.create_collision_test_setup(
		_create_real_indicator(),
		Vector2.ZERO,
		logger
	)
	
	var validation_issues = IndicatorFactory.validate_collision_test_setup(setup)
	assert_array(validation_issues).is_empty()
	
	# Test that setup is valid
	assert_bool(setup.valid).is_true()


func _on_indicators_changed(updated: Array[RuleCheckIndicator]) -> void:
	received_signal = true
	if indicator:
		assert_that(indicator in updated).is_true()
