## Test for RuleCheckIndicator rule assignment regression
## Verifies that indicators properly evaluate rules and filter out indicators
## at positions that should fail collision checks
extends GdUnitTestSuite

# Use constants from GBTestConstants for consistency
const TILE_SIZE: Vector2 = GBTestConstants.DEFAULT_TILE_SIZE
const DEFAULT_POSITION: Vector2 = GBTestConstants.CENTER
const ORIGIN_POSITION: Vector2 = GBTestConstants.OFF_GRID
const ORIGIN_TILE: Vector2i = Vector2i(0, 0)

var _env : BuildingTestEnvironment
var _container : GBCompositionContainer
var _state : GridTargetingState
var building_system: BuildingSystem
var targeting_system: GridTargetingSystem
var indicator_manager: IndicatorManager
var positioner: Node2D
var map_layer: TileMapLayer
var placer: Node2D
var obj_parent: Node2D

func before_test() -> void:
	_env = EnvironmentTestFactory.create_building_system_test_environment(self)
	_state = _env.grid_targeting_system.get_state()
	_container = _env.get_container()
	obj_parent = _env.objects_parent
	placer = _env.placer
	positioner = _env.positioner
	map_layer = _env.tile_map_layer
	targeting_system = _env.grid_targeting_system
	building_system = _env.building_system
	indicator_manager = _env.indicator_manager

	assert_array(_env.get_issues()).is_empty().append_failure_message("Test environment should initialize without issues")

#region Helper Functions

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

#endregion

#region Test Functions

## Test that indicators properly evaluate rules and filter out indicators
## at positions that should fail collision checks
func test_polygon_test_object_indicator_collision_filtering() -> void:
	# Use DRY pattern to create test polygon placeable
	var polygon_placeable : Placeable = PlaceableTestFactory.create_polygon_test_placeable(self)

	# Place an existing object at position (0,0) to create collision
	var existing_object : Node2D = polygon_placeable.packed_scene.instantiate()
	auto_free(existing_object)
	existing_object.global_position = Vector2.ZERO
	obj_parent.add_child(existing_object)

	# Create and set a preview/target instance so the targeting state points to the test object
	var preview_instance: Node2D = polygon_placeable.packed_scene.instantiate()
	auto_free(preview_instance)
	preview_instance.global_position = Vector2.ZERO
	obj_parent.add_child(preview_instance)
	_state.set_manual_target(preview_instance)

	# Position the positioner at a valid location
	positioner.global_position = Vector2(64, 64)

	# Use the container's placement rules instead of creating new ones
	# This ensures we test the actual integration with ExtResource resolution
	var rules: Array[PlacementRule] = _container.get_placement_rules()

	# Diagnostic: log rule types and counts before setup
	var logger: GBLogger = _container.get_logger()
	if logger != null:
		logger.log_debug( "indicator_rule_assignment: rules count=%d" % [rules.size()])
	else:
		GBTestDiagnostics.buffer("indicator_rule_assignment: rules count=%d" % [rules.size()])

	# Set up rule validation parameters
	var targeting_state : GridTargetingState = _container.get_states().targeting

	# Setup the collision rules (ensure each rule has its targeting context initialized)
	for rule: PlacementRule in rules:
		if logger != null:
			logger.log_debug( "  rule: %s" % [rule.get_class()])
		if rule is CollisionsCheckRule:
			var setup_issues: Array[String] = rule.setup(targeting_state)
			assert_array(setup_issues).append_failure_message("Rule.setup failed for %s" % [rule.get_class()]).is_empty()

	# Call try_setup directly on the IndicatorManager (correct DRY pattern)
	# Diagnostic: dump rule runtime info before calling try_setup
	for i in range(rules.size()):
		var r: PlacementRule = rules[i]
		if logger != null:
			logger.log_debug( "  rule[%d] class=%s, is_Collisions=%s, is_TileCheck=%s, is_valid=%s" % [i, r.get_class(), str(r is CollisionsCheckRule), str(r is TileCheckRule), str(is_instance_valid(r))])
		else:
			GBTestDiagnostics.buffer("rule[%d] class=%s, is_Collisions=%s, is_TileCheck=%s, is_valid=%s" % [i, r.get_class(), str(r is CollisionsCheckRule), str(r is TileCheckRule), str(is_instance_valid(r))])

	var setup_report : PlacementReport = indicator_manager.try_setup(rules, targeting_state, true)

	# Diagnostic: report summary
	if setup_report != null:
		var diag_logger: GBLogger = _container.get_logger()
		if diag_logger != null:
			diag_logger.log_debug( "setup_report success=%s, indicators=%d" % [str(setup_report.is_successful()), setup_report.indicators_report.indicators.size() if setup_report.indicators_report != null else 0])
		else:
			GBTestDiagnostics.buffer("setup_report success=%s, indicators=%d" % [str(setup_report.is_successful()), setup_report.indicators_report.indicators.size() if setup_report.indicators_report != null else 0])

	var context := GBTestDiagnostics.flush_for_assert()
	assert_object(setup_report).append_failure_message("IndicatorManager.try_setup returned null. Context: %s" % context).is_not_null()
	assert_bool(setup_report.is_successful()).append_failure_message("IndicatorManager.try_setup failed. Context: %s" % context).is_true()

	# Get indicators from the setup report
	var indicators : Array[RuleCheckIndicator] = setup_report.indicators_report.indicators
 assert_array(indicators).append_failure_message("Setup should generate at least one indicator").is_not_empty()

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
	var collision_rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()

	# Create indicator using DRY pattern with proper collision shape
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	var _rect_shape2 := RectangleShape2D.new()
	_rect_shape2.size = TILE_SIZE
	indicator.shape = _rect_shape2
	indicator.target_position = Vector2.ZERO  # Set for proper test alignment
	indicator.collision_mask = 1
	add_child(indicator)
	auto_free(indicator)

	# Assign the collision rule to the indicator
	indicator.add_rule(collision_rule)

 assert_object(indicator).append_failure_message("Indicator should be created successfully").is_not_null()

	# Verify rules are properly assigned
	var assigned_rules: Array[TileCheckRule] = indicator.get_rules()
	assert_array(assigned_rules).has_size(1)

	assert_object(assigned_rules.get(0)).is_same(collision_rule).append_failure_message("First assigned rule should be the collision rule")

	# Verify bidirectional relationship - rule should have indicator in its indicators array
	assert_array(collision_rule.indicators).contains([indicator])

## Test that indicators properly validate rules when updated
func test_indicator_rule_validation() -> void:
	# Create a collision rule using DRY pattern
	var collision_rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	# For this test we expect the indicator to become invalid when a collision is present
	# Ensure the rule is configured to fail on collision
	collision_rule.pass_on_collision = false

	# Set up rule parameters
	var targeting_state: GridTargetingState = _container.get_states().targeting
	var _preview_root: Node2D = GodotTestFactory.create_node2d(self)
	var _manipulator_owner: Node2D = placer

	# Setup the rule
	var setup_issues: Array[String] = collision_rule.setup(targeting_state)
 assert_array(setup_issues).append_failure_message("Collision rule setup should complete without issues").is_empty()

	# Create indicator with the rule using DRY pattern with proper collision shape
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	# Assign a rectangle shape sized to one tile so collisions are detected correctly
	var _rect_shape := RectangleShape2D.new()
	_rect_shape.size = TILE_SIZE
	indicator.shape = _rect_shape
	indicator.target_position = Vector2.ZERO  # Set for proper test alignment
	# Ensure indicator queries the default collision layer used by test objects
	indicator.collision_mask = 1
	add_child(indicator)
	auto_free(indicator)

	# Assign the collision rule to the indicator
	indicator.add_rule(collision_rule)

	# Position indicator at a location with no collisions
	indicator.global_position = DEFAULT_POSITION

	indicator.force_shapecast_update()

 assert_bool(indicator.valid).append_failure_message("Indicator should be valid when no collision object is present").is_true()

	# Now create a collision object at the same position using DRY pattern
	var _collision_object: StaticBody2D = create_collision_object_at(DEFAULT_POSITION)

	var valid := indicator.force_validity_evaluation()

	# Should now be invalid (collision detected)
	var fail_parts: Array[String] = []
	fail_parts.append("Indicator should be invalid after collision object added")
	fail_parts.append("indicator_pos=%s" % [str(indicator.global_position)])
	fail_parts.append("indicator_tile=%s" % [str(indicator.get_tile_position(map_layer))])
	fail_parts.append("indicator_collision_mask=%s" % [str(indicator.collision_mask)])
	fail_parts.append("collision_object_pos=%s" % [str(_collision_object.global_position)])
	fail_parts.append("collision_object_layer=%s" % [str(_collision_object.collision_layer)])
	fail_parts.append("indicator_get_collision_count=%s" % [str(indicator.get_collision_count())])
	assert_bool(valid).append_failure_message("\n".join(fail_parts)).is_false()

## Test the specific polygon_test_object scenario
func test_polygon_test_object_center_tile_filtering() -> void:
	# Create polygon test object using DRY pattern
	var polygon_placeable: Placeable = PlaceableTestFactory.create_polygon_test_placeable(self)

	# Create an instance to examine its collision shape
	var test_instance: Node2D = polygon_placeable.packed_scene.instantiate()
	auto_free(test_instance)
	obj_parent.add_child(test_instance)

	# The polygon has a complex shape that should NOT cover the center tile (0,0)
	# when positioned at the origin, so an indicator at (0,0) should be valid

	# Use the container's placement rules instead of creating new ones
	var rules: Array[PlacementRule] = _container.get_placement_rules()

	# Setup the collision rules
	for rule: PlacementRule in rules:
		if rule is CollisionsCheckRule:
			var setup_issues: Array[String] = rule.setup(_container.get_targeting_state())
   assert_array(setup_issues).append_failure_message("Collision rule setup should complete without issues for rule: %s" % rule.get_class().is_empty()

	# Call try_setup directly on the IndicatorManager
	# Ensure the targeting state has the test instance as the current target
	_container.get_targeting_state().set_manual_target(test_instance)

	# Position the positioner at a valid location
	positioner.global_position = Vector2.ZERO

	var setup_report: PlacementReport = indicator_manager.try_setup(rules, _container.get_targeting_state(), true)
	assert_object(setup_report).append_failure_message("IndicatorManager.try_setup returned null").is_not_null()
	assert_bool(setup_report.is_successful()).append_failure_message("IndicatorManager.try_setup failed").is_true()

	# Get indicators from the setup report
	var indicators: Array[RuleCheckIndicator] = setup_report.indicators_report.indicators

	# There should be indicators generated based on the polygon shape
 assert_array(indicators).append_failure_message("Setup should generate indicators for polygon shape").is_not_empty()

	# Find center indicator (offset 0,0) using DRY pattern
	var center_indicator: RuleCheckIndicator = find_center_indicator(indicators)

	# Based on current polygon_test_object.tscn, the concave shape does overlap the center tile.
	# Therefore an indicator at (0,0) must be invalid due to collision, or filtered out entirely.

	if center_indicator != null:
		# If indicator exists at center, verify it has rules and is properly evaluated
		var indicator_rules: Array[TileCheckRule] = center_indicator.get_rules()
		assert_array(indicator_rules).append_failure_message(
			"Center indicator should have rules assigned"
		).is_not_empty()

		# The indicator should be invalid since the polygon overlaps the center tile
		center_indicator.force_validity_evaluation()

		# Log for debugging
		var logger: GBLogger = _container.get_logger()
		logger.log_debug( "Center indicator valid: %s, rules count: %d" % [center_indicator.valid, rules.size()])

		# This assertion might fail due to the regression
		var dbg_parts: Array[String] = []
		dbg_parts.append("Center indicator should be invalid - polygon overlaps center tile")
		dbg_parts.append("indicator_pos=%s" % [str(center_indicator.global_position)])
		dbg_parts.append("indicator_tile=%s" % [str(center_indicator.get_tile_position(map_layer))])
		dbg_parts.append("indicator_collision_mask=%s" % [str(center_indicator.collision_mask)])
		dbg_parts.append("indicator_valid=%s" % [str(center_indicator.valid)])
		# Include polygon points if available
		for c in test_instance.get_children():
			if c is CollisionPolygon2D:
				dbg_parts.append("polygon_points=%s" % [(c as CollisionPolygon2D).polygon])
		assert_bool(center_indicator.valid).append_failure_message("\n".join(dbg_parts)).is_false()
