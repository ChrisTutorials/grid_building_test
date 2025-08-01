extends GdUnitTestSuite

var indicator_manager: IndicatorManager
var indicator_template : PackedScene = preload("uid://dhox8mb8kuaxa")
var received_signal: bool
var indicator: RuleCheckIndicator
var _injector : GBInjectorSystem

func before_test():
	_injector = GBDoubleFactory.create_test_injector(self)
	indicator_manager = IndicatorManager.new()
	add_child(indicator_manager) # Must add to scene tree for signals, add_child, free etc to work
	
	received_signal = false
	indicator = null

func after_test():
	indicator_manager.free()

func _create_real_indicator() -> RuleCheckIndicator:
	var instance = indicator_template.instantiate() as RuleCheckIndicator
	instance.name = "TestIndicator"
	add_child(instance) # add to scene so it's in scene tree
	return instance

func test_setup_indicators_generates_expected_indicators() -> void:
	var test_object := Node2D.new()
	add_child(test_object)

	# Set up a dummy collision shape (required by get_all_collision_objects)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	test_object.add_child(collision_shape)

	var rule := TileCheckRule.new()
	var rules : Array[TileCheckRule] = [rule]

	var indicators := indicator_manager.setup_indicators(test_object, rules)

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

func test_free_indicators_removes_and_frees() -> void:
	var ind = _create_real_indicator()
	indicator_manager.add_indicators([ind])
	assert_that(ind in indicator_manager.get_indicators()).is_true()
	
	indicator_manager._free_indicators([ind]) # note this is private in your code; if it's private,_

func _on_indicators_changed(updated: Array[RuleCheckIndicator]) -> void:
	received_signal = true
	assert_that(indicator in updated).is_true()
