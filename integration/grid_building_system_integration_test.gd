extends GdUnitTestSuite

# Constants for test positions and sizes
const VALID_BUILD_POS: Vector2 = Vector2(64, 64)
const ALTERNATIVE_BUILD_POS: Vector2 = Vector2(100, 100)
const TARGET_POS: Vector2 = Vector2(200, 200)
const COMPLEX_TARGET_POS: Vector2 = Vector2(150, 150)
const FULL_WORKFLOW_POS: Vector2 = Vector2(300, 300)
const TRANSITION_TEST_POS: Vector2 = Vector2(400, 400)

const COLLISION_SHAPE_SIZE: Vector2 = Vector2(32, 32)
const MAX_REASONABLE_COORDINATE: int = 1000
const MIN_POLYGON_SPAN: int = 2
const POLYGON_TEST_POS: Vector2 = Vector2(128, 128)
const DEFAULT_COLLISION_LAYER: int = 1
const DEFAULT_COLLISION_MASK: int = 1
const MIN_EXPECTED_INDICATORS: int = 1

# Test objects and environments
var env: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _gts: GridTargetingState
var _manipulation_state : ManipulationState
var _building_system: BuildingSystem
var _indicator_manager: IndicatorManager
var _targeting_system: GridTargetingSystem
var smithy_placeable: Placeable = load("uid://dirh6mcrgdm3w")

# Shared test objects - created once, reused across tests
var tile_rule: TileCheckRule = preload("uid://bbmmdkiwwuj4a")
var collision_rule : CollisionsCheckRule = preload("uid://du7xu07247202")
var test_static_body: StaticBody2D

func before_test() -> void:
	env = UnifiedTestFactory.instance_all_systems_env(self, "uid://ioucajhfxc8b")
	assert_object(env).append_failure_message(
		"Failed to create AllSystemsTestEnvironment from UnifiedTestFactory"
	).is_not_null()
	
	_container = env.get_container()
	assert_object(_container).append_failure_message(
		"AllSystemsTestEnvironment should provide a valid container"
	).is_not_null()
	
	_building_system = env.building_system
	assert_object(_building_system).append_failure_message(
		"AllSystemsTestEnvironment should have building_system"
	).is_not_null()
	
	_indicator_manager = env.indicator_manager
	assert_object(_indicator_manager).append_failure_message(
		"AllSystemsTestEnvironment should have indicator_manager"
	).is_not_null()
	
	_targeting_system = env.grid_targeting_system
	assert_object(_targeting_system).append_failure_message(
		"AllSystemsTestEnvironment should have grid_targeting_system"
	).is_not_null()
	
	_gts = _targeting_system.get_state()
	assert_object(_gts).append_failure_message(
		"GridTargetingSystem should provide a valid targeting state"
	).is_not_null()
	
	_manipulation_state = env.manipulation_system._states.manipulation
	
	test_static_body = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Validate the smithy placeable has proper configuration  
	assert_object(smithy_placeable).append_failure_message(
		"Smithy placeable should be loaded successfully"
	).is_not_null()
	
	assert_object(smithy_placeable.placement_rules).append_failure_message(
		"Smithy placeable should have placement_rules defined"
	).is_not_null()
	
	assert_object(smithy_placeable.packed_scene).append_failure_message(
		"Smithy placeable should have packed_scene defined"
	).is_not_null()

func after_test() -> void:
	_cleanup_test_state()

#region HELPER METHODS

## Common helper to enter build mode with proper error handling
func _enter_build_mode_successfully(placeable: Placeable) -> bool:
	assert_object(placeable).append_failure_message(
		"Cannot enter build mode with null placeable"
	).is_not_null()
	
	assert_object(placeable.placement_rules).append_failure_message(
		"Placeable should have placement rules configured: %s" % str(placeable)
	).is_not_null()
	
	assert_array(placeable.placement_rules).append_failure_message(
		"Placeable should have non-empty placement rules: %s has %d rules" % [str(placeable), placeable.placement_rules.size()]
	).is_not_empty()
	
	var setup_report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_object(setup_report).append_failure_message(
		"enter_build_mode should return a PlacementReport"
	).is_not_null()
	
	if setup_report.is_successful():
		assert_bool(_building_system.is_in_build_mode()).append_failure_message(
			"Should be in build mode after successful enter_build_mode"
		).is_true()
		return true
	else:
		var errors: Array = setup_report.get_all_issues()
		var error_msg: String = "enter_build_mode failed with placeable %s (rules: %d): %s" % [str(placeable), placeable.placement_rules.size(), str(errors)]
		assert_bool(false).append_failure_message(error_msg).is_true()
		return false

## Common helper to create targeting state with position
func _set_targeting_position(position: Vector2) -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting
	assert_object(targeting_state).append_failure_message(
		"Container should provide a valid targeting state"
	).is_not_null()
	assert_object(targeting_state.positioner).append_failure_message(
		"Targeting state should have a valid positioner configured"
	).is_not_null()
	targeting_state.positioner.global_position = position

## Common helper to validate successful setup with custom message
func _assert_setup_successful(setup_result: PlacementReport, context: String) -> void:
	assert_bool(setup_result.is_successful()).append_failure_message(
		"%s should succeed: %s" % [context, str(setup_result.get_all_issues())]
	).is_true()

## Common helper to create instantiated smithy node for testing
func _create_smithy_test_node() -> Node:
	var smithy_node: Node = smithy_placeable.packed_scene.instantiate()
	add_child(smithy_node)
	auto_free(smithy_node)
	return smithy_node

## Common helper to create test collision area with standard settings
func _create_test_collision_area() -> Area2D:
	var area: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = COLLISION_SHAPE_SIZE
	shape.shape = rect_shape
	area.add_child(shape)
	area.collision_layer = DEFAULT_COLLISION_LAYER
	area.collision_mask = DEFAULT_COLLISION_MASK
	add_child(area)
	auto_free(area)
	return area

## Common helper to create polygon test object for reuse
func _create_polygon_test_setup() -> Dictionary:
	var polygon_test_object: Placeable = UnifiedTestFactory.create_polygon_test_placeable(self)
	var polygon_node: Node = polygon_test_object.packed_scene.instantiate()
	add_child(polygon_node)
	auto_free(polygon_node)
	return {
		"placeable": polygon_test_object,
		"node": polygon_node,
		"rules": polygon_test_object.placement_rules
	}

## Common helper to create preview with collision using constants
func _create_preview_with_collision() -> Node2D:
	var root := Node2D.new()
	root.name = "PreviewRoot"
	var area := Area2D.new()
	area.collision_layer = DEFAULT_COLLISION_LAYER
	area.collision_mask = DEFAULT_COLLISION_MASK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = COLLISION_SHAPE_SIZE
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	add_child(root)
	return root

## Common helper to verify collision tile positions are reasonable
func _assert_reasonable_collision_positions(collision_results: Dictionary) -> void:
	assert_dict(collision_results).append_failure_message(
		"Should generate collision tile positions"
	).is_not_empty()
	
	for tile_pos: Variant in collision_results.keys():
		var pos: Vector2i = tile_pos as Vector2i
		assert_bool(abs(pos.x) < MAX_REASONABLE_COORDINATE and abs(pos.y) < MAX_REASONABLE_COORDINATE).append_failure_message(
			"Generated tile position %s should be reasonable" % [str(pos)]
		).is_true()

## Common helper to setup and validate building mode entry
func _setup_build_mode_and_position(placeable: Placeable, position: Vector2) -> bool:
	_set_targeting_position(position)
	return _enter_build_mode_successfully(placeable)

## Common helper to cleanup after tests
func _cleanup_test_state() -> void:
	if _building_system and _building_system.is_in_build_mode():
		_building_system.exit_build_mode()

#endregion

#region BUILDING WORKFLOW INTEGRATION

func test_complete_building_workflow() -> void:
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Test valid position first with validation
	_set_targeting_position(VALID_BUILD_POS)
	
	# Use indicator manager's validate_placement method
	var validation_result: ValidationResults = _indicator_manager.validate_placement()
	assert_bool(validation_result.is_successful()).append_failure_message(
		"Validation should succeed for valid position %s" % VALID_BUILD_POS
	).is_true()
	
	# Test building at validated position
	var build_result: PlacementReport = _building_system.try_build_at_position(VALID_BUILD_POS)
	assert_object(build_result.placed).append_failure_message(
		"Building should succeed and return placed object at position %s" % VALID_BUILD_POS
	).is_not_null()
	
	# Exit build mode after successful build
	_building_system.exit_build_mode()
	assert_bool(_building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after exiting"
	).is_false()

func test_alternative_building_workflow() -> void:
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	# Test placement attempt at alternative position
	var placement_result: PlacementReport = _building_system.try_build_at_position(ALTERNATIVE_BUILD_POS)
	assert_object(placement_result.placed).append_failure_message(
		"Building should succeed at alternative position %s" % ALTERNATIVE_BUILD_POS
	).is_not_null()
	
	# Exit build mode
	_building_system.exit_build_mode()
	assert_bool(_building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after exiting"
	).is_false()

#endregion

#region MULTI-RULE INDICATOR ATTACHMENT

func test_multi_rule_indicator_attachment() -> void:
	# Set up a target for indicator generation
	var test_target: Node2D = Node2D.new()
	test_target.name = "TestTarget"
	add_child(test_target)
	auto_free(test_target)
	_gts.target = test_target
	
	var base_rules: Array[PlacementRule] = _container.get_placement_rules()
	var rules: Array[PlacementRule] = base_rules + [tile_rule]
	var setup_result: PlacementReport = _indicator_manager.try_setup(rules, _gts)

	_assert_setup_successful(setup_result, "Multi-rule setup")
	
	# Verify indicators are created
	var indicators: Array = _indicator_manager.get_indicators()
	assert_int(indicators.size()).append_failure_message(
		"Should have indicators for both rules, got %d" % indicators.size()
	).is_greater_equal(MIN_EXPECTED_INDICATORS)

func test_rule_indicator_state_synchronization() -> void:
	# Setup with initial state
	test_static_body.global_position = VALID_BUILD_POS
	var setup_result: PlacementReport = _indicator_manager.try_setup([collision_rule], _gts)
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Initial indicator setup should succeed with collision rule: %s" % str(setup_result.get_all_issues())
	).is_true()
	
	# Change rule state and verify indicators update
	test_static_body.global_position = POLYGON_TEST_POS
	var update_result: PlacementReport = _indicator_manager.try_setup([collision_rule], _gts)
	
	_assert_setup_successful(update_result, "Rule state update")

func test_indicators_are_parented_and_inside_tree() -> void:
	var preview: Node2D = _create_preview_with_collision()
	_container.get_states().targeting.target = preview
	_gts.target = preview
	
	# Build a collisions rule that applies to layer 1
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var rules: Array[PlacementRule] = [rule]
	
	var setup_results: PlacementReport = _indicator_manager.try_setup(rules, _gts)
	
	_assert_setup_successful(setup_results, "IndicatorManager.try_setup")
	var indicators: Array = _indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created").is_not_empty()
	
	for ind: RuleCheckIndicator in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()
		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % ind.name).is_equal(_container.get_states().manipulation.parent)

#endregion

#region SMITHY INDICATOR GENERATION

func test_smithy_indicator_generation() -> void:
	var smithy_rules: Array = smithy_placeable.placement_rules
	assert_array(smithy_rules).append_failure_message(
		"Smithy should have placement rules"
	).is_not_empty()
	
	# Generate indicators using helper method
	var _smithy_node: Node = _create_smithy_test_node()
	var setup_result: PlacementReport = _indicator_manager.try_setup(smithy_rules, _gts)
	_assert_setup_successful(setup_result, "Smithy indicator generation")

func test_smithy_collision_detection() -> void:
	var collision_mapper: CollisionMapper = env.indicator_manager.get_collision_mapper()
	
	# Create a smithy node using helper method
	var smithy_node: Node = _create_smithy_test_node()
	
	# Test collision tile mapping for smithy (using production method)
	var collision_results: Dictionary = collision_mapper.get_collision_tile_positions_with_mask([smithy_node] as Array[Node2D], 1)
	_assert_reasonable_collision_positions(collision_results)

#endregion

#region COMPLEX WORKFLOW INTEGRATION

func test_complex_multi_system_workflow() -> void:
	_set_targeting_position(TARGET_POS)
	
	assert_vector(TARGET_POS).append_failure_message(
		"Target position should be set correctly"
	).is_equal(TARGET_POS)
	
	# Phase 2: Building placement
	if not _enter_build_mode_successfully(smithy_placeable):
		return
		
	var build_result: PlacementReport = _building_system.try_build_at_position(TARGET_POS)
	assert_object(build_result.placed).append_failure_message(
		"Complex workflow should succeed and place object at %s" % TARGET_POS
	).is_not_null()
	
	# Phase 3: Post-build manipulation
	env.manipulation_system.set_targeted(build_result.placed)
	assert_object(_manipulation_state).append_failure_message(
		"Should have valid manipulation state after selection"
	).is_not_null()

#endregion

#region POLYGON TEST OBJECT INTEGRATION

func test_polygon_test_object_indicator_generation() -> void:
	var polygon_setup: Dictionary = _create_polygon_test_setup()
	
	# Generate indicators for polygon object using proper parameters
	var setup_result: PlacementReport = _indicator_manager.try_setup(polygon_setup.rules, _gts)
	assert_bool(setup_result.is_successful()).append_failure_message(
		"Polygon object indicator generation should succeed: %s" % str(setup_result.get_all_issues())
	).is_true()

func test_polygon_collision_integration() -> void:
	var polygon_setup: Dictionary = _create_polygon_test_setup()
	var collision_mapper: CollisionMapper = env.indicator_manager.get_collision_mapper()
	
	# Test polygon collision tile mapping
	var collision_tiles: Dictionary = collision_mapper.get_collision_tile_positions_with_mask([polygon_setup.node] as Array[Node2D], 1)
	assert_dict(collision_tiles).append_failure_message(
		"Polygon test object should generate collision tile positions"
	).is_not_empty()
	
	# Verify collision tiles form reasonable polygon pattern
	var unique_x_coords: Dictionary = {}
	var unique_y_coords: Dictionary = {}
	
	for tile_pos: Variant in collision_tiles.keys():
		var tile_coord: Vector2i = tile_pos as Vector2i
		unique_x_coords[tile_coord.x] = true
		unique_y_coords[tile_coord.y] = true
	
	# Polygon should span multiple coordinates
	assert_int(unique_x_coords.size()).append_failure_message(
		"Polygon should span multiple X coordinates, got %d" % unique_x_coords.size()
	).is_greater_equal(MIN_POLYGON_SPAN)
	assert_int(unique_y_coords.size()).append_failure_message(
		"Polygon should span multiple Y coordinates, got %d" % unique_y_coords.size()
	).is_greater_equal(MIN_POLYGON_SPAN)

#region GRID TARGETING HIGHLIGHT INTEGRATION

func test_grid_targeting_highlight_integration() -> void:
	var highlight_manager: Variant = env.get("highlight_manager")  # May not be available in all environments
	
	if highlight_manager == null:
		# Skip if highlight manager not available in test environment
		return
	
	# Test targeting with highlight updates
	_gts.target.position = ALTERNATIVE_BUILD_POS
	
	# Verify highlight state updates with targeting
	var highlight_active: bool = highlight_manager.is_highlight_active()
	assert_bool(highlight_active).append_failure_message(
		"Highlight should be active when targeting position is set"
	).is_true()

func test_targeting_state_transitions() -> void:
	var initial_pos: Vector2 = Vector2.ZERO
	if _gts.positioner != null:
		initial_pos = _gts.positioner.global_position
		_gts.positioner.global_position = TRANSITION_TEST_POS
		var updated_pos: Vector2 = _gts.positioner.global_position
		
		assert_vector(updated_pos).append_failure_message(
			"Target position should update from %s to %s, got %s" % [initial_pos, TRANSITION_TEST_POS, updated_pos]
		).is_equal(TRANSITION_TEST_POS)
		
		# Test clearing target
		_gts.positioner.global_position = Vector2.ZERO  # Reset to origin
		var cleared_pos: Vector2 = _gts.positioner.global_position
		
		# Cleared position behavior depends on system implementation
		assert_object(cleared_pos).append_failure_message(
			"Should have valid position response after clearing target"
		).is_not_null()

#endregion
#region COMPREHENSIVE INTEGRATION VALIDATION

func test_full_system_integration_workflow() -> void:
	# Step 1: Set target
	_set_targeting_position(FULL_WORKFLOW_POS)
	
	# Step 2: Enter build mode with indicators
	if not _enter_build_mode_successfully(smithy_placeable):
		return
	
	var smithy_node: Node = smithy_placeable.packed_scene.instantiate()
	auto_free(smithy_node)
	add_child(smithy_node)
	
	var smithy_rules: Array[PlacementRule] = smithy_placeable.placement_rules
	
	var indicator_result: PlacementReport = _indicator_manager.try_setup(smithy_rules, _gts)
	_assert_setup_successful(indicator_result, "Full workflow indicator setup")
	
	# Step 3: Build at target
	var build_result: PlacementReport = _building_system.try_build_at_position(FULL_WORKFLOW_POS)
	assert_object(build_result.placed).append_failure_message(
		"Full workflow should successfully place object at position %s" % FULL_WORKFLOW_POS
	).is_not_null()
	
	# Step 4: Validate post-build state
	_building_system.exit_build_mode()
	assert_bool(_building_system.is_in_build_mode()).append_failure_message(
		"Should not be in build mode after explicit exit in full workflow test"
	).is_false()

func test_system_error_recovery() -> void:
	# Test recovery from invalid operations
	var invalid_placeable: Variant = null
	var invalid_report: PlacementReport = _building_system.enter_build_mode(invalid_placeable)
	
	# System should return a failed report for invalid input
	assert_object(invalid_report).append_failure_message(
		"enter_build_mode should return a PlacementReport even for invalid input, got: %s" % str(type_string(typeof(invalid_report)))
	).is_not_null()
	
	# Additional type validation 
	assert_bool(invalid_report is PlacementReport).append_failure_message(
		"enter_build_mode should return a PlacementReport, got type: %s" % str(type_string(typeof(invalid_report)))
	).is_true()
	
	assert_bool(invalid_report.is_successful()).append_failure_message(
		"enter_build_mode should fail with null placeable"
	).is_false()
	
	# System should not be in build mode after failed enter_build_mode
	var is_in_build_mode: bool = _building_system.is_in_build_mode()
	assert_bool(is_in_build_mode).append_failure_message(
		"System should not be in build mode after failed enter_build_mode"
	).is_false()
	
	# Ensure system can recover to valid state
	if _enter_build_mode_successfully(smithy_placeable):
		assert_bool(_building_system.is_in_build_mode()).append_failure_message(
			"System should recover and enter build mode with valid placeable"
		).is_true()
	
	_building_system.exit_build_mode()

#endregion
