## Test for RuleCheckIndicator rule assignment regression
## Verifies that indicators properly evaluate CollisionCheckRule and other rules assigned to them
extends GdUnitTestSuite

var _container: GBCompositionContainer
var _injector: GBInjectorSystem
var building_system: BuildingSystem
var targeting_system: GridTargetingSystem
var placement_manager: IndicatorManager
var positioner: Node2D
var map_layer: TileMapLayer
var placer: Node2D
var obj_parent: Node2D

func before_test():
	var setup = UnifiedTestFactory.create_complete_building_test_setup(self)
	
	_container = setup.container
	_injector = setup.injector
	obj_parent = setup.obj_parent
	placer = setup.placer
	positioner = setup.positioner
	map_layer = setup.map_layer
	targeting_system = setup.targeting_system
	building_system = setup.building_system
	placement_manager = setup.placement_manager

func after_test():
	if _injector and _injector.has_method("cleanup"):
		_injector.cleanup()

## Test that indicators created for polygon_test_object properly evaluate CollisionCheckRule
## and filter out indicators at positions that should fail collision checks
func test_polygon_test_object_indicator_collision_filtering():
	# Load the polygon test object placeable resource
	var polygon_placeable = load("res://demos/top_down/placement/placeables/placeable_polygon_test_object.tres")
	assert_object(polygon_placeable).is_not_null()
	
	# Place an existing object at position (0,0) to create collision
	var existing_object = polygon_placeable.packed_scene.instantiate()
	auto_free(existing_object)
	existing_object.global_position = Vector2.ZERO
	obj_parent.add_child(existing_object)
	
	# Enter build mode with the placeable resource
	building_system.selected_placeable = polygon_placeable
	building_system.enter_build_mode(polygon_placeable)
	
	# Position the positioner at (0,0) where there should be collision
	positioner.global_position = Vector2.ZERO
	
	# Wait for indicator setup
	await get_tree().process_frame
	
	# Get the indicators that were generated
	var indicators = placement_manager.get_indicators()
	assert_array(indicators).is_not_empty()
	
	# Find the indicator at offset (0,0) - this should be filtered out due to collision
	var center_indicator: RuleCheckIndicator = null
	for indicator in indicators:
		var tile_pos = indicator.get_tile_position(map_layer)
		var positioner_tile = map_layer.local_to_map(map_layer.to_local(positioner.global_position))
		var offset = tile_pos - positioner_tile
		
		if offset == Vector2i(0, 0):
			center_indicator = indicator
			break
	
	# The center indicator should either:
	# 1. Not exist (filtered out during generation), OR
	# 2. Exist but be marked as invalid due to collision
	if center_indicator != null:
		# If it exists, it should be invalid due to collision
		assert_bool(center_indicator.valid).append_failure_message(
			"Center indicator at (0,0) should be invalid due to collision with existing object"
		).is_false()
		
		# Verify it has rules assigned
		var rules = center_indicator.get_rules()
		assert_array(rules).append_failure_message(
			"Indicator should have rules assigned"
		).is_not_empty()
		
		# Check if any rule is a CollisionCheckRule
		var has_collision_rule = false
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
func test_indicator_rule_assignment_during_creation():
	# Create a simple collision rule
	var collision_rule = CollisionsCheckRule.new()
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	
	# Create indicator template
	var indicator_template = load("res://addons/grid_building/placement/rule_check_indicator/rule_check_indicator.tscn")
	
	# Create indicator using IndicatorFactory
	var rules: Array[TileCheckRule] = [collision_rule]
	var indicator = IndicatorFactory.create_indicator(
		Vector2i(0, 0),
		rules,
		indicator_template,
		placer
	)
	
	assert_object(indicator).is_not_null()
	
	# Verify rules are properly assigned
	var assigned_rules = indicator.get_rules()
	assert_array(assigned_rules).has_size(1)
	assert_object(assigned_rules[0]).is_same(collision_rule)
	
	# Verify bidirectional relationship - rule should have indicator in its indicators array
	assert_array(collision_rule.indicators).contains([indicator])

## Test that indicators properly validate rules when updated
func test_indicator_rule_validation():
	# Create a collision rule that expects no collisions
	var collision_rule = CollisionsCheckRule.new()
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	
	# Set up rule parameters
	var targeting_state = _container.get_states().targeting
	var preview_root = GodotTestFactory.create_node2d(self)
	var manipulator_owner = placer
	var validation_params = RuleValidationParameters.new(manipulator_owner, preview_root, targeting_state, _container.get_logger())
	
	# Setup the rule
	var setup_issues = collision_rule.setup(validation_params)
	assert_array(setup_issues).is_empty()
	
	# Create indicator with the rule
	var indicator_template = load("res://addons/grid_building/placement/rule_check_indicator/rule_check_indicator.tscn")
	var indicator = IndicatorFactory.create_indicator(
		Vector2i(0, 0),
		[collision_rule],
		indicator_template,
		placer
	)
	
	# Position indicator at a location with no collisions
	indicator.global_position = Vector2(1000, 1000)
	
	# Wait for physics update
	await get_tree().process_frame
	
	# Update validation
	indicator.update_validation_now()
	
	# Should be valid (no collisions)
	assert_bool(indicator.valid).is_true()
	
	# Now create a collision object at the same position
	var collision_object = StaticBody2D.new()
	auto_free(collision_object)
	var collision_shape = CollisionShape2D.new()
	auto_free(collision_shape)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision_shape.shape = shape
	collision_object.add_child(collision_shape)
	collision_object.global_position = Vector2(1000, 1000)
	collision_object.collision_layer = 1
	placer.add_child(collision_object)
	
	# Wait for physics update
	await get_tree().process_frame
	
	# Update validation again
	indicator.update_validation_now()
	
	# Should now be invalid (collision detected)
	assert_bool(indicator.valid).append_failure_message(
		"Indicator should be invalid after collision object added"
	).is_false()

## Test the specific polygon_test_object scenario
func test_polygon_test_object_center_tile_filtering():
	# Load polygon test object placeable resource
	var polygon_placeable = load("res://demos/top_down/placement/placeables/placeable_polygon_test_object.tres")
	
	# Create an instance to examine its collision shape
	var test_instance = polygon_placeable.packed_scene.instantiate()
	auto_free(test_instance)
	obj_parent.add_child(test_instance)
	
	# The polygon has a complex shape that should NOT cover the center tile (0,0)
	# when positioned at the origin, so an indicator at (0,0) should be valid
	
	# Enter build mode with placeable resource
	building_system.selected_placeable = polygon_placeable
	building_system.enter_build_mode(polygon_placeable)
	
	# Position at origin
	positioner.global_position = Vector2.ZERO
	
	# Wait for setup
	await get_tree().process_frame
	
	# Get indicators
	var indicators = placement_manager.get_indicators()
	
	# There should be indicators generated based on the polygon shape
	assert_array(indicators).is_not_empty()
	
	# Find center indicator (offset 0,0)
	var center_indicator: RuleCheckIndicator = null
	for indicator in indicators:
		var tile_pos = indicator.get_tile_position(map_layer)
		var positioner_tile = map_layer.local_to_map(map_layer.to_local(positioner.global_position))
		var offset = tile_pos - positioner_tile
		
		if offset == Vector2i(0, 0):
			center_indicator = indicator
			break
	
	# Based on the polygon shape in polygon_test_object.tscn, the center tile should NOT
	# be covered by the collision polygon, so either:
	# 1. No indicator should be generated for (0,0), OR
	# 2. If generated, it should be valid (no collision with the shape)
	
	if center_indicator != null:
		# If indicator exists at center, verify it has rules and is properly evaluated
		var rules = center_indicator.get_rules()
		assert_array(rules).append_failure_message(
			"Center indicator should have rules assigned"
		).is_not_empty()
		
		# The indicator should be valid since the polygon doesn't cover center
		# (This is the regression - indicators might not be evaluating rules properly)
		center_indicator.update_validation_now()
		
		# Log for debugging
		var logger = _container.get_logger()
		logger.log_debug(self, "Center indicator valid: %s, rules count: %d" % [center_indicator.valid, rules.size()])
		
		# This assertion might fail due to the regression
		assert_bool(center_indicator.valid).append_failure_message(
			"Center indicator should be valid - polygon doesn't cover center tile"
		).is_true()
