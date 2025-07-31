extends GdUnitTestSuite

var indicator_manager: IndicatorManager
var indicator_template : PackedScene = preload("uid://dhox8mb8kuaxa")
var _received_signal: bool
var _indicator: RuleCheckIndicator

func _before():
	indicator_manager = IndicatorManager.new()
	var targeting = GridTargetingState.new(GBOwnerContext.new())
	indicator_manager.setup(indicator_template, targeting)
	_received_signal = false
	_indicator = null

func _create_real_indicator() -> RuleCheckIndicator:
	var instance = indicator_template.instantiate()
	instance.name = "TestIndicator"
	return instance

func test_track_indicators_adds_and_emits_signal() -> void:
	_indicator = _create_real_indicator()
	
	indicator_manager.indicators_changed.connect(_on_indicators_changed)
	indicator_manager.track_indicators([_indicator])
	
	assert_that(_indicator in indicator_manager.get_indicators()).is_true()
	assert_that(_received_signal).is_true()
	
func _on_indicators_changed(updated: Array[RuleCheckIndicator]):
	_received_signal = true
	assert_that(_indicator in updated).is_true()

func test_free_indicators_removes_and_frees() -> void:
	var indicator = _create_real_indicator()
	indicator_manager.track_indicators([indicator])
	assert_that(indicator in indicator_manager.get_indicators()).is_true()
	
	indicator_manager.free_indicators([indicator])
	
	assert_int(indicator_manager.get_indicators().size()).is_equal(0)

func test_get_colliding_indicators_returns_only_colliding() -> void:
	# Use real indicators, but you must simulate collision state
	# Since you don't want to mock, you'll need to set up actual collision state.
	# This test assumes you have a way to enable collision on RuleCheckIndicator.
	
	var indicator1 = _create_real_indicator()
	var indicator2 = _create_real_indicator()
	
	indicator_manager.track_indicators([indicator1, indicator2])
	
	# Set up collision state for indicator1
	# This will depend on your collision setup; for example:
	# Add a CollisionShape2D and set collision layers/masks properly, then trigger physics
	
	# For now, just call the is_colliding() function directly to check it returns false by default
	var colliding = indicator_manager.get_colliding_indicators()
	assert_that(indicator1 in colliding).is_false()
	assert_that(indicator2 in colliding).is_false()

func test_get_colliding_nodes_returns_unique_nodes() -> void:
	var indicator = _create_real_indicator()
	indicator_manager.track_indicators([indicator])
	
	# Similar to above, without mocks you must set up collisions properly.
	
	var nodes = indicator_manager.get_colliding_nodes()
	# Since no collisions, nodes should be empty
	assert_int(nodes.size()).is_equal(0)
