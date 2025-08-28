## Consolidated Placement Management Tests
## Combines placement_manager, indicator_positioning, and indicator_manager integration tests
extends GdUnitTestSuite

var test_hierarchy: Dictionary
var indicator_manager: IndicatorManager
var targeting_state: GridTargetingState
var signal_received: bool

func before_test() -> void:
	# Use the indicator test hierarchy factory for consistent setup
	test_hierarchy = UnifiedTestFactory.create_indicator_test_hierarchy(self)
	
	# Extract components for easy access
	targeting_state = test_hierarchy.targeting_state
	indicator_manager = test_hierarchy.indicator_manager
	signal_received = false

func after_test() -> void:
	test_hierarchy = {}

func _on_indicators_changed(_indicators):
	signal_received = true

func _create_test_body() -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.extents = Vector2(8, 8)
	cs.shape = rect
	body.add_child(cs)
	targeting_state.positioner.add_child(body)
	return body

# ================================
# Indicator Manager Core Tests
# ================================

func test_indicator_manager_initialization() -> void:
	assert_object(indicator_manager).is_not_null()
	assert_object(test_hierarchy.container).is_not_null()
	assert_object(targeting_state).is_not_null()

func test_indicator_manager_handles_basic_setup() -> void:
	# Test that indicator manager properly handles basic setup
	var _body := _create_test_body()
	var rules: Array = [CollisionsCheckRule.new()]
	
	# Get components from hierarchy
	var indicator_parent = test_hierarchy.indicator_parent
	var container: GBCompositionContainer = test_hierarchy.container
	
	# Configure collision mapper
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, _body, container, indicator_parent)
	
	# Test indicator manager setup
	var _report = indicator_manager.setup_indicators(_body, rules)
	assert_that(_report.is_successful()).is_true()

# ================================
# Indicator Positioning Tests
# ================================

func test_indicator_positioning_comprehensive() -> void:
	# Test comprehensive positioning scenarios
	var _body := _create_test_body()
	
	# Test different positions
	var test_positions: Array = [Vector2.ZERO, Vector2(32, 32), Vector2(-16, 16)]
	
	for pos: Dictionary in test_positions:
		targeting_state.positioner.global_position = pos
		
		# Validate positioning works for this position
		var issues = targeting_state.validate_runtime()
		assert_array(issues).append_failure_message("Position %s should be valid" % [pos]).is_empty()

func test_indicator_positioning_alignment() -> void:
	# Test that indicators align properly to grid
	var body := _create_test_body()
	
	# Intentionally misalign positioner
	targeting_state.positioner.global_position = Vector2(13.37, 27.91)
	
	var rules: Array = [CollisionsCheckRule.new()]
	var indicator_parent = test_hierarchy.indicator_parent
	var container: GBCompositionContainer = test_hierarchy.container
	
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, container, indicator_parent)
	var _report = indicator_manager.setup_indicators(body, rules)
	
	# Verify alignment occurred
	var map := targeting_state.target_map
	var pos_after := targeting_state.positioner.global_position
	var tile_pos := map.local_to_map(map.to_local(pos_after))
	var aligned := map.to_global(map.map_to_local(tile_pos))
	assert_float((aligned - pos_after).length()).is_less(0.11)

# ================================
# Indicator Manager Integration Tests
# ================================

func test_indicator_manager_setup_and_reset_cycle() -> void:
	# Test complete setup/reset cycle
	var body := _create_test_body()
	var rules: Array = [CollisionsCheckRule.new()]
	var indicator_parent = test_hierarchy.indicator_parent
	var container: GBCompositionContainer = test_hierarchy.container
	
	# Setup indicators
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, container, indicator_parent)
	var report = indicator_manager.setup_indicators(body, rules)
	
	assert_that(report.is_successful()).is_true()
	assert_int(indicator_manager.get_indicators().size()).is_greater(0)
	
	# Reset and verify cleanup
	indicator_manager.reset()
	assert_int(indicator_manager.get_indicators().size()).is_equal(0)

func test_indicator_manager_signal_emission() -> void:
	var indicator_parent = test_hierarchy.indicator_parent
	
	# Connect to signal using method reference instead of lambda
	indicator_manager.connect("indicators_changed", Callable(self, "_on_indicators_changed"))
	
	# Create and add indicator manually
	var indicator_template = preload("uid://dhox8mb8kuaxa")
	var inst: RuleCheckIndicator = indicator_template.instantiate()
	inst.name = "TestSignalIndicator"
	indicator_parent.add_child(inst)
	
	indicator_manager.add_indicators([inst])
	
	assert_bool(signal_received).is_true()

func test_indicator_manager_testing_indicator_reuse() -> void:
	var indicator_parent = test_hierarchy.indicator_parent
	
	var first := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	var second := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	
	# Should reuse same instance
	assert_object(second).is_same(first)

# ================================
# Performance and Edge Case Tests
# ================================

func test_placement_multiple_objects() -> void:
	# Test handling multiple objects efficiently
	var bodies: Array = []
	for i in range(5):
		var body = _create_test_body()
		body.global_position = Vector2(i * 32, 0)
		bodies.append(body)
	
	# Each should be handled correctly
	var indicator_parent = test_hierarchy.indicator_parent
	var container: GBCompositionContainer = test_hierarchy.container
	
	for body in bodies:
		UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, container, indicator_parent)
		var report = indicator_manager.setup_indicators(body, [CollisionsCheckRule.new()])
		assert_that(report.is_successful()).is_true()

func test_placement_null_object_handling() -> void:
	# Test graceful handling of null objects
	var report = indicator_manager.setup_indicators(null, [])
	
	# Should handle gracefully without errors
	assert_array(report.indicators).is_empty()
	assert_int(report.rules.size()).is_equal(0)

func test_placement_empty_rules_handling() -> void:
	# Test handling empty rule arrays
	var body := _create_test_body()
	var indicator_parent = test_hierarchy.indicator_parent
	var container: GBCompositionContainer = test_hierarchy.container
	
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, container, indicator_parent)
	var report = indicator_manager.setup_indicators(body, [])
	
	# Should complete successfully even with no rules
	assert_that(report.is_successful()).is_true()
