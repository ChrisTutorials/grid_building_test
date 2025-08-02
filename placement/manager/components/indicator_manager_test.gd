extends GdUnitTestSuite

var indicator_manager: IndicatorManager
var indicator_template : PackedScene = preload("uid://dhox8mb8kuaxa")
var received_signal: bool
var indicator: RuleCheckIndicator
var targeting_state: GridTargetingState
var logger: GBLogger
var indicator_parent : Node2D

func before_test():
	indicator_parent = Node2D.new()
	add_child(indicator_parent)

	# Create dependencies manually
	targeting_state = GridTargetingState.new(GBOwnerContext.new())
	logger = GBDoubleFactory.create_test_logger()
	indicator_manager = IndicatorManager.new(indicator_parent, targeting_state, indicator_template, logger)

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
	var map := GBDoubleFactory.create_test_tile_map_layer(self)
	p_targeting_state.set_map_objects(
		map, [map]
	)

	var positioner : Node2D = auto_free(Node2D.new())
	p_targeting_state.positioner = positioner

func test_setup_indicators_generates_expected_indicators() -> void:
	var test_object := Node2D.new()
	add_child(test_object)

	# Create a collision object (StaticBody2D) and add a collision shape
	var body := StaticBody2D.new()
	test_object.add_child(body)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	body.add_child(collision_shape)

	var rule := TileCheckRule.new()
	var rules : Array[TileCheckRule] = [rule]

	var indicators := indicator_manager.setup_indicators(test_object, rules, self)

	assert_int(indicators.size()).is_greater(0)
	assert_int(indicator_manager.get_indicators().size()).is_greater(indicators.size())

	# Optional: check that each indicator has the expected rule attached
	for indi in indicators:
		assert_that(indi.get_rules().size()).is_greater_than(0)

func test_add_indicators_adds_and_emits_signal() -> void:
	indicator = _create_real_indicator()
	indicator_manager.indicators_changed.connect(_on_indicators_changed)
	indicator_manager.add_indicators([indicator])
	
	assert_that(indicator in indicator_manager.get_indicators()).is_true()
	assert_that(received_signal).is_true()

func test_reset_frees_indicators() -> void:
	var ind = _create_real_indicator()
	indicator_manager.add_indicators([ind])
	assert_that(ind in indicator_manager.get_indicators()).is_true()
	indicator_manager.reset()

func _on_indicators_changed(updated: Array[RuleCheckIndicator]) -> void:
	received_signal = true
	assert_that(indicator in updated).is_true()
