class_name DRYTestPatternsDemo
extends GdUnitTestSuite

## Demonstration of DRY (Don't Repeat Yourself) test patterns using UnifiedTestFactory
## This shows how the new helper methods reduce code duplication and improve maintainability

var _container: GBCompositionContainer
var _test_parent: Node2D

func before() -> void:
	_container = UnifiedTestFactory.TEST_CONTAINER.duplicate(true)
	_test_parent = Node2D.new()
	_test_parent.name = "TestParent"
	add_child(_test_parent)

func after() -> void:
	_test_parent.queue_free()

# ================================
# EXAMPLE: Using DRY Helper Methods
# ================================

## Example 1: Polygon setup with standardized rules
func test_polygon_setup_with_standardized_rules() -> void:
	# OLD WAY (repetitive code):
	# var polygon_obj = create_polygon_test_object(self)
	# _test_parent.add_child(polygon_obj)
	# polygon_obj.position = Vector2(100, 100)
	# var rule = CollisionsCheckRule.new()
	# rule.apply_to_objects_mask = 1
	# rule.collision_mask = 1
	# var rules = [rule]
	
	# NEW WAY (DRY using helper):
	var setup = UnifiedTestFactory.create_polygon_test_setup(self, _test_parent, Vector2(100, 100))
	var polygon_obj = setup.polygon_obj
	var rules = setup.rules
	
	# Test logic (much cleaner)
	assert_object(polygon_obj).is_not_null()
	assert_array(rules).has_size(1)
	assert_object(rules[0]).is_instanceof(CollisionsCheckRule)

## Example 2: Indicator setup with validation
func test_indicator_setup_with_validation() -> void:
	# Setup using DRY helpers
	var polygon_setup = UnifiedTestFactory.create_polygon_test_setup(self, _test_parent)
	var indicator_setup = UnifiedTestFactory.create_indicator_test_setup(
		self, _container, polygon_setup.polygon_obj, polygon_setup.rules
	)
	
	# Use standardized assertions
	UnifiedTestFactory.assert_indicator_count(indicator_setup.report, 1, "single polygon test")
	
	# Verify parent architecture
	var manipulation_parent = _container.get_states().manipulation.parent
	UnifiedTestFactory.assert_parent_architecture(
		indicator_setup.indicator_manager, 
		manipulation_parent, 
		indicator_setup.indicators,
		"indicator hierarchy test"
	)

## Example 3: Collision-based testing environment
func test_collision_indicator_environment() -> void:
	# Create comprehensive test environment in one call
	var env = UnifiedTestFactory.create_collision_indicator_test_environment(self, _container)
	
	# All necessary components are available
	assert_object(env.collision_setup).is_not_null()
	assert_object(env.collision_mapper).is_not_null()
	assert_object(env.targeting_state).is_not_null()
	assert_object(env.tile_map).is_not_null()
	
	# Can immediately use for testing
	var polygon_setup = UnifiedTestFactory.create_polygon_test_setup(self, _test_parent)
	var indicator_setup = UnifiedTestFactory.create_indicator_test_setup(
		self, _container, polygon_setup.polygon_obj, polygon_setup.rules
	)
	
	# Validate collision layer setup
	for indicator in indicator_setup.indicators:
		UnifiedTestFactory.assert_collision_layer_setup(indicator, 1, "standard collision layer")

## Example 4: Rule validation testing
func test_rule_validation_with_standardized_assertions() -> void:
	var _env = UnifiedTestFactory.create_collision_indicator_test_environment(self, _container)
	var _polygon_setup = UnifiedTestFactory.create_polygon_test_setup(self, _test_parent)
	
	# Simulate rule validation result
	var validation_result = {
		"valid": true,
		"message": "Test validation passed"
	}
	
	# Use standardized assertion
	UnifiedTestFactory.assert_rule_validation_result(validation_result, true, "rule validation test")

# ================================
# MAINTAINABILITY BENEFITS DEMO
# ================================

## Shows how the DRY patterns reduce code duplication
func test_maintainability_improvements() -> void:
	# Before: Each test would need 10-15 lines of setup code
	# After: One line creates complete test environment
	
	var _env = UnifiedTestFactory.create_collision_indicator_test_environment(self, _container)
	var _polygon_setup = UnifiedTestFactory.create_polygon_test_setup(self, _test_parent)
	var indicator_setup = UnifiedTestFactory.create_indicator_test_setup(
		self, _container, _polygon_setup.polygon_obj, _polygon_setup.rules
	)
	
	# All assertions use standardized, reusable methods
	UnifiedTestFactory.assert_indicator_count(indicator_setup.report, 1)
	UnifiedTestFactory.assert_parent_architecture(
		indicator_setup.indicator_manager,
		_container.get_states().manipulation.parent,
		indicator_setup.indicators
	)
	
	# Benefits:
	# 1. Consistent setup across all tests
	# 2. Standardized assertions reduce bugs
	# 3. Easy to maintain - change helper once, affects all tests
	# 4. Self-documenting test code
	# 5. Faster test writing and debugging
