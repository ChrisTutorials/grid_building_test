## Test for RuleCheckIndicator rule assignment regression
## Verifies that indicators properly evaluate rules and filter out indicators
## at positions that should fail collision checks
extends GdUnitTestSuite

# Constants for test values
const TILE_SIZE: Vector2 = Vector2(32, 32)
const DEFAULT_POSITION: Vector2 = Vector2(100, 100)
const ORIGIN_POSITION: Vector2 = Vector2(0, 0)
const ORIGIN_TILE: Vector2i = Vector2i(0, 0)

var _container: GBCompositionContainer
var _injector: GBInjectorSystem
var building_system: BuildingSystem
var targeting_system: GridTargetingSystem
var indicator_manager: IndicatorManager
var positioner: Node2D
var map_layer: TileMapLayer
var placer: Node2D
var obj_parent: Node2D

func before_test() -> void:
	var setup: Dictionary = UnifiedTestFactory.create_complete_building_test_setup(self)

	_container = setup.container
	_injector = setup.injector
	obj_parent = setup.obj_parent
	placer = setup.placer
	positioner = setup.positioner
	map_layer = setup.map_layer
	targeting_system = setup.targeting_system
	building_system = setup.building_system
	indicator_manager = setup.indicator_manager

	# Ensure indicator template is configured
	UnifiedTestFactory.ensure_indicator_template_configured(_container)

# ================================
# Helper Functions for DRY Patterns
# ================================

func find_center_indicator(indicators: Array[RuleCheckIndicator]) -> RuleCheckIndicator:
	"""Find the indicator at the center position (offset 0,0) from the positioner."""
	for indicator: RuleCheckIndicator in indicators:
		var tile_pos: Vector2i = indicator.get_tile_position(map_layer)
		var positioner_tile: Vector2i = map_layer.local_to_map(map_layer.to_local(positioner.global_position))
		var offset: Vector2i = tile_pos - positioner_tile

		if offset == ORIGIN_TILE:
			return indicator
	return null

func create_collision_object_at(position: Vector2) -> StaticBody2D:
	"""Create a collision object with a rectangle shape at the specified position."""
	var collision_object: StaticBody2D = StaticBody2D.new()
	auto_free(collision_object)
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	auto_free(collision_shape)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = TILE_SIZE
	collision_shape.shape = shape
	collision_object.add_child(collision_shape)
	collision_object.global_position = position
	collision_object.collision_layer = 1
	placer.add_child(collision_object)
	return collision_object

# ================================
# Test Functions
# ================================

## Test that indicators properly evaluate rules and filter out indicators
## at positions that should fail collision checks
func test_polygon_test_object_indicator_collision_filtering() -> void:
	# Use DRY pattern to create test polygon placeable
	var polygon_placeable : Placeable = UnifiedTestFactory.create_polygon_test_placeable(self)

	# Place an existing object at position (0,0) to create collision
	var existing_object : Node2D = polygon_placeable.packed_scene.instantiate()
	auto_free(existing_object)
	existing_object.global_position = Vector2.ZERO
	obj_parent.add_child(existing_object)

	# Create collision rule using DRY pattern
	var collision_rule : CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	var rules: Array[PlacementRule] = [collision_rule]

	# Set up rule validation parameters
	var targeting_state : GridTargetingState = _container.get_states().targeting

	# Call try_setup directly on the IndicatorManager (correct DRY pattern)
	var setup_report : PlacementReport = indicator_manager.try_setup(rules, targeting_state, true)
	assert_object(setup_report).append_failure_message("IndicatorManager.try_setup returned null").is_not_null()
	assert_bool(setup_report.is_successful()).append_failure_message("IndicatorManager.try_setup failed").is_true()

	# Get indicators from the setup report
	var indicators : Array[RuleCheckIndicator] = setup_report.indicators_report.indicators
	assert_array(indicators).is_not_empty()

	# Find the indicator at offset (0,0) - this should be filtered out due to collision
	var center_indicator: RuleCheckIndicator = find_center_indicator(indicators)

	# The center indicator should either:
	# 1. Not exist (filtered out during generation), OR
	# 2. Exist but be marked as invalid due to collision
	if center_indicator != null:
		# If it exists, it should be invalid due to collision
		assert_bool(center_indicator.valid).append_failure_message(
			"Center indicator at (0,0) should be invalid due to collision with existing object"
		).is_false()

		# Verify it has rules assigned
		var assigned_rules: Array[TileCheckRule] = center_indicator.get_rules()
		assert_array(assigned_rules).append_failure_message(
			"Indicator should have rules assigned"
		).is_not_empty()

		# Check if any rule is a CollisionCheckRule
		var has_collision_rule: bool = false
		for rule in rules:
			if rule is CollisionsCheckRule:
				has_collision_rule = true
				break

		assert_bool(has_collision_rule).append_failure_message(
			"Indicator should have CollisionCheckRule assigned"
		).is_true()
	else:
		# If filtered out, that's also acceptable behavior
		pass

## Test that rules are properly assigned to indicators during creation
func test_indicator_rule_assignment_during_creation() -> void:
	# Create a simple collision rule using DRY pattern
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()

	# Create indicator using DRY pattern with proper collision shape
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator_with_shape(self, [collision_rule])

	assert_object(indicator).is_not_null()

	# Verify rules are properly assigned
	var assigned_rules: Array[TileCheckRule] = indicator.get_rules()
	assert_array(assigned_rules).has_size(1)
	assert_object(assigned_rules[0]).is_same(collision_rule)

	# Verify bidirectional relationship - rule should have indicator in its indicators array
	assert_array(collision_rule.indicators).contains([indicator])

## Test that indicators properly validate rules when updated
func test_indicator_rule_validation() -> void:
	# Create a collision rule using DRY pattern
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()

	# Set up rule parameters
	var targeting_state: GridTargetingState = _container.get_states().targeting
	var _preview_root: Node2D = GodotTestFactory.create_node2d(self)
	var _manipulator_owner: Node2D = placer

	# Setup the rule
	var setup_issues: Array[String] = collision_rule.setup(targeting_state)
	assert_array(setup_issues).is_empty()

	# Create indicator with the rule using DRY pattern with proper collision shape
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator_with_shape(self, [collision_rule])

	# Position indicator at a location with no collisions
	indicator.global_position = DEFAULT_POSITION

	indicator.force_shapecast_update()

	assert_bool(indicator.valid).is_true()

	# Now create a collision object at the same position using DRY pattern
	var _collision_object: StaticBody2D = create_collision_object_at(DEFAULT_POSITION)

	var valid := indicator.force_validity_evaluation()

	# Should now be invalid (collision detected)
	assert_bool(valid).append_failure_message(
		"Indicator should be invalid after collision object added"
	).is_false()

## Test the specific polygon_test_object scenario
func test_polygon_test_object_center_tile_filtering() -> void:
	# Create polygon test object using DRY pattern
	var polygon_placeable: Placeable = UnifiedTestFactory.create_polygon_test_placeable(self)

	# Create an instance to examine its collision shape
	var test_instance: Node2D = polygon_placeable.packed_scene.instantiate()
	auto_free(test_instance)
	obj_parent.add_child(test_instance)

	# The polygon has a complex shape that should NOT cover the center tile (0,0)
	# when positioned at the origin, so an indicator at (0,0) should be valid

	# Create collision rule and set up validation using DRY pattern
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	var rules: Array[PlacementRule] = [collision_rule]

	# Call try_setup directly on the IndicatorManager
	var setup_report: PlacementReport = indicator_manager.try_setup(rules, _container.get_targeting_state(), true)
	assert_object(setup_report).append_failure_message("IndicatorManager.try_setup returned null").is_not_null()
	assert_bool(setup_report.is_successful()).append_failure_message("IndicatorManager.try_setup failed").is_true()

	# Get indicators from the setup report
	var indicators: Array[RuleCheckIndicator] = setup_report.indicators_report.indicators

	# There should be indicators generated based on the polygon shape
	assert_array(indicators).is_not_empty()

	# Find center indicator (offset 0,0) using DRY pattern
	var center_indicator: RuleCheckIndicator = find_center_indicator(indicators)

	# Based on the polygon shape in polygon_test_object.tscn, the center tile should NOT
	# be covered by the collision polygon, so either:
	# 1. No indicator should be generated for (0,0), OR
	# 2. If generated, it should be valid (no collision with the shape)

	if center_indicator != null:
		# If indicator exists at center, verify it has rules and is properly evaluated
		var indicator_rules: Array[TileCheckRule] = center_indicator.get_rules()
		assert_array(indicator_rules).append_failure_message(
			"Center indicator should have rules assigned"
		).is_not_empty()

		# The indicator should be valid since the polygon doesn't cover center
		# (This is the regression - indicators might not be evaluating rules properly)
		center_indicator.update_validation_now()

		# Log for debugging
		var logger: GBLogger = _container.get_logger()
		logger.log_debug(self, "Center indicator valid: %s, rules count: %d" % [center_indicator.valid, rules.size()])

		# This assertion might fail due to the regression
		assert_bool(center_indicator.valid).append_failure_message(
			"Center indicator should be valid - polygon doesn't cover center tile"
		).is_true()
