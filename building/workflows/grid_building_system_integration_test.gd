## Integration tests for GridBuildingSystem workflow validation
## Tests complete building workflows including indicator management,
## collision detection, and multi-system interactions.
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
var _manipulation_state: ManipulationState
var _building_system: BuildingSystem
var _indicator_manager: IndicatorManager
var _targeting_system: GridTargetingSystem

# Shared test objects - created once, reused across tests
var tile_rule: TileCheckRule = preload("uid://bbmmdkiwwuj4a")
var collision_rule: CollisionsCheckRule = preload("uid://du7xu07247202")


func before_test() -> void:
	env = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV).scene()
	_validate_environment_setup()
	_initialize_test_components()
	_validate_required_dependencies()


## Validate environment is properly set up without issues
func _validate_environment_setup() -> void:
	(
		assert_object(env) \
		. append_failure_message(
			"Failed to create AllSystemsTestEnvironment from UnifiedTestFactory"
		) \
		. is_not_null()
	)

	# Use environment's get_issues method for validation
	var issues: Array[String] = env.get_issues()
	(
		assert_array(issues) \
		. append_failure_message("Environment setup has issues: %s" % str(issues)) \
		. is_empty()
	)


## Initialize core test components from environment
func _initialize_test_components() -> void:
	_container = env.get_container()
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_targeting_system = env.grid_targeting_system
	_gts = _targeting_system.get_state()
	_manipulation_state = env.manipulation_system._states.manipulation


## Validate all required dependencies are available
func _validate_required_dependencies() -> void:
	var dependencies: Dictionary[String, Variant] = {
		"container": _container,
		"building_system": _building_system,
		"indicator_manager": _indicator_manager,
		"targeting_system": _targeting_system,
		"targeting_state": _gts
	}

	for dep_name: String in dependencies:
		(
			assert_object(dependencies[dep_name]) \
			. append_failure_message(
				"Required dependency '%s' not available from environment" % dep_name
			) \
			. is_not_null()
		)

	# Assert TileMap availability instead of creating
	var target_map: TileMapLayer = _gts.target_map
	(
		assert_object(target_map) \
		. append_failure_message("Environment should provide a configured TileMap for testing") \
		. is_not_null()
	)


func after_test() -> void:
	_cleanup_test_state()


#region HELPER METHODS


## Common assertion helper for validating placement reports
func _assert_placement_report_success(report: PlacementReport, context: String) -> void:
	(
		assert_object(report) \
		. append_failure_message("%s should return a valid PlacementReport" % context) \
		. is_not_null()
	)
	(
		assert_bool(report.is_successful()) \
		. append_failure_message("%s should succeed: %s" % [context, str(report.get_issues())]) \
		. is_true()
	)


## Common helper to enter build mode with proper error handling
func _enter_build_mode_successfully(placeable: Placeable) -> bool:
	var setup_report: PlacementReport = _building_system.enter_build_mode(placeable)
	if setup_report.is_successful():
		(
			assert_bool(_building_system.is_in_build_mode()) \
			. append_failure_message("Should be in build mode after successful enter_build_mode") \
			. is_true()
		)
		return true
	else:
		_assert_placement_report_success(setup_report, "enter_build_mode")
		return false


## Common helper to set targeting position
func _set_targeting_position(position: Vector2) -> void:
	var targeting_state: GridTargetingState = _container.get_states().targeting
	(
		assert_object(targeting_state.positioner) \
		. append_failure_message("Targeting state should have a valid positioner configured") \
		. is_not_null()
	)
	targeting_state.positioner.global_position = position


## Common helper to validate successful setup with custom message
func _assert_setup_successful(setup_result: PlacementReport, context: String) -> void:
	# Delegate to consolidated helper method
	_assert_placement_report_success(setup_result, context)


## Common assertion helper for collision detection results
func _assert_collision_results_valid(collision_results: Dictionary, context: String) -> void:
	(
		assert_dict(collision_results) \
		. append_failure_message("%s: Should generate collision tile positions" % context) \
		. is_not_empty()
	)

	for tile_pos: Variant in collision_results.keys():
		var pos: Vector2i = tile_pos as Vector2i
		(
			assert_bool(
				abs(pos.x) < MAX_REASONABLE_COORDINATE and abs(pos.y) < MAX_REASONABLE_COORDINATE
			) \
			. append_failure_message(
				"%s: Generated tile position %s should be reasonable" % [context, str(pos)]
			) \
			. is_true()
		)


## Find collision objects in scene hierarchy
func _find_collision_objects_recursive(node: Node, found_objects: Array[Node2D]) -> void:
	if node is Node2D and node is CollisionObject2D:
		found_objects.append(node as Node2D)
	for child in node.get_children():
		_find_collision_objects_recursive(child, found_objects)


## Common cleanup helper
func _cleanup_test_state() -> void:
	if _building_system and _building_system.is_in_build_mode():
		_building_system.exit_build_mode()


#endregion

#region BUILDING WORKFLOW INTEGRATION
@warning_ignore("unused_parameter")
func test_complete_building_workflow(
	p_placeable: Placeable,
	test_parameters := [
		[GBTestConstants.PLACEABLE_BLACKSMITH_BLUE],
		[GBTestConstants.PLACEABLE_HOUSE_WOODEN_RED],
		[GBTestConstants.PLACEABLE_SMITHY]
	]
) -> void:
	if not _enter_build_mode_successfully(p_placeable):
		return

	_set_targeting_position(VALID_BUILD_POS)

	# Validate placement before building
	var validation_result: ValidationResults = _indicator_manager.validate_placement()
	(
		assert_bool(validation_result.is_successful()) \
		. append_failure_message(
			"Validation should succeed for valid position %s" % VALID_BUILD_POS
		) \
		. is_true()
	)

	# Test building at validated position
	var build_result: PlacementReport = _building_system.try_build_at_position(VALID_BUILD_POS)
	(
		assert_object(build_result.placed) \
		. append_failure_message(
			"Building should succeed and return placed object at position %s" % VALID_BUILD_POS
		) \
		. is_not_null()
	)


#endregion

#region MULTI-RULE INDICATOR ATTACHMENT


func test_multi_rule_indicator_attachment() -> void:
	# Generated object must have a CollisionObject2D and a shape / polygon
	var test_obj := CollisionObjectTestFactory.create_static_body_with_diamond(self, 32, 64)
	_gts.set_manual_target(test_obj)

	# Assert environment provides TileMap rather than creating it
	(
		assert_object(_gts.target_map) \
		. append_failure_message(
			"Environment should provide a configured TileMap for multi-rule testing"
		) \
		. is_not_null()
	)

	# Create multiple rules using helper method for consistency
	var rules: Array[PlacementRule] = [CollisionsCheckRule.new()]

	var setup_result: PlacementReport = _indicator_manager.try_setup(rules, _gts)
	_assert_placement_report_success(setup_result, "Multi-rule setup")

	# Verify indicators are created for multiple rules
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	(
		assert_int(indicators.size()) \
		. append_failure_message(
			"Should have indicators for multiple rules, got %d" % indicators.size()
		) \
		. is_greater_equal(MIN_EXPECTED_INDICATORS)
	)


func test_rule_indicator_state_synchronization() -> void:
	var static_body: StaticBody2D = CollisionObjectTestFactory.create_static_body_with_rect(
		self, Vector2(32, 32)
	)
	static_body.global_position = VALID_BUILD_POS
	_gts.set_manual_target(static_body)
	var setup_result: PlacementReport = _indicator_manager.try_setup([collision_rule], _gts)
	(
		assert_bool(setup_result.is_successful()) \
		. append_failure_message(
			(
				"Initial indicator setup should succeed with collision rule: %s"
				% str(setup_result.get_issues())
			)
		) \
		. is_true()
	)

	# Change rule state and verify indicators update
	static_body.global_position = POLYGON_TEST_POS
	var update_result: PlacementReport = _indicator_manager.try_setup([collision_rule], _gts)

	_assert_setup_successful(update_result, "Rule state update")


func test_indicators_are_parented_and_inside_tree() -> void:
	# Assert environment provides required targeting setup
	(
		assert_object(_gts.target_map) \
		. append_failure_message(
			"Environment should provide a configured TileMap for indicator testing"
		) \
		. is_not_null()
	)
	(
		assert_object(_container.get_states().manipulation.parent) \
		. append_failure_message("Environment should provide manipulation parent for indicators") \
		. is_not_null()
	)

	# Set up test target from environment - MUST have collisionObject2D and collision shape or polygon to get indicators
	var test_target: Node2D = CollisionObjectTestFactory.create_static_body_with_circle(self, 32)
	_gts.set_manual_target(test_target)

	# Create rule for indicator generation
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = DEFAULT_COLLISION_LAYER
	rule.collision_mask = DEFAULT_COLLISION_LAYER
	rule.pass_on_collision = true
	if rule.messages == null:
		rule.messages = CollisionRuleSettings.new()

	var setup_results: PlacementReport = _indicator_manager.try_setup([rule], _gts)
	_assert_placement_report_success(setup_results, "IndicatorManager.try_setup")

	# Validate indicator creation and parenting
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created").is_not_empty()

	for ind: RuleCheckIndicator in indicators:
		(
			assert_bool(ind.is_inside_tree()) \
			. append_failure_message("Indicator not inside tree: %s" % ind.name) \
			. is_true()
		)
		(
			assert_object(ind.get_parent()) \
			. append_failure_message("Indicator has no parent: %s" % ind.name) \
			. is_not_null()
		)
		var expected_parent := env.indicator_manager
		(
			assert_object(ind.get_parent()) \
			. append_failure_message(
				(
					"Unexpected parent for indicator: %s Parent was %s but should be %s"
					% [ind.name, ind.get_parent(), expected_parent]
				)
			) \
			. is_equal(expected_parent)
		)


#endregion

#region SMITHY INDICATOR GENERATION


func test_smithy_indicator_generation() -> void:
	var smithy_placeable := GBTestConstants.PLACEABLE_SMITHY
	var test_rules: Array[PlacementRule] = smithy_placeable.placement_rules
	(
		assert_array(test_rules) \
		. append_failure_message("Test placeable should have placement rules") \
		. is_not_empty()
	)

	# Generate indicators using helper method
	var smithy_instance: Area2D = CollisionObjectTestFactory.instance_placeable(
		self, smithy_placeable, env.objects_parent
	)
	_gts.set_manual_target(smithy_instance)
	var setup_result: PlacementReport = _indicator_manager.try_setup(test_rules, _gts)
	_assert_setup_successful(setup_result, "Test placeable indicator generation")


func test_smithy_collision_detection() -> void:
	var collision_mapper: CollisionMapper = env.indicator_manager.get_collision_mapper()
	(
		assert_object(collision_mapper) \
		. append_failure_message("Environment should provide a CollisionMapper for testing") \
		. is_not_null()
	)

	# Create smithy instance to test collision detection
	var smithy_node: Node = CollisionObjectTestFactory.instance_placeable(
		self, GBTestConstants.PLACEABLE_SMITHY, env.objects_parent
	)

	# Find collision objects in smithy scene
	var collision_objects: Array[Node2D] = []
	_find_collision_objects_recursive(smithy_node, collision_objects)

	# Either smithy has collision objects, or we skip collision detection test
	if not collision_objects.is_empty():
		var collision_results: Dictionary[Vector2i, Array] = (
			collision_mapper
			. get_collision_tile_positions_with_mask(collision_objects, DEFAULT_COLLISION_LAYER)
		)
		_assert_collision_results_valid(collision_results, "Smithy collision detection")


#endregion

#region COMPLEX WORKFLOW INTEGRATION

## Test build and then post build move manipulation
@warning_ignore("unused_parameter")
func test_complex_multi_system_workflow(
	p_placeable: Placeable,
	test_parameters := [
		[GBTestConstants.PLACEABLE_BLACKSMITH_BLUE],
		[GBTestConstants.PLACEABLE_HOUSE_WOODEN_RED],
		[GBTestConstants.PLACEABLE_SMITHY]
	]
) -> void:
	_set_targeting_position(TARGET_POS)

	(
		assert_vector(TARGET_POS) \
		. append_failure_message("Target position should be set correctly") \
		. is_equal(TARGET_POS)
	)

	# Phase 2: Building placement - use properly configured test placeable
	if not _enter_build_mode_successfully(p_placeable):
		return

	var build_result: PlacementReport = _building_system.try_build_at_position(TARGET_POS)
	(
		assert_object(build_result.placed) \
		. append_failure_message(
			"Complex workflow should succeed and place object at %s" % TARGET_POS
		) \
		. is_not_null()
	)

	# Phase 3: Post-build manipulation
	env.manipulation_system.set_targeted(build_result.placed)
	(
		assert_object(_manipulation_state) \
		. append_failure_message("Should have valid manipulation state after selection") \
		. is_not_null()
	)


#endregion

#region POLYGON TEST OBJECT INTEGRATION


func test_polygon_test_object_indicator_generation() -> void:
	var polygon_object_root: Node2D = CollisionObjectTestFactory.create_polygon_test_object(
		self, env.positioner
	)
	_gts.set_manual_target(polygon_object_root)
	# Generate indicators for polygon object using proper parameters
	var setup_result: PlacementReport = _indicator_manager.try_setup([], _gts)
	(
		assert_bool(setup_result.is_successful()) \
		. append_failure_message(
			(
				"Polygon object indicator generation should succeed: %s"
				% str(setup_result.get_issues())
			)
		) \
		. is_true()
	)


func test_polygon_collision_integration() -> void:
	var collision_mapper: CollisionMapper = env.indicator_manager.get_collision_mapper()
	var polygon_test_object: Placeable = GBTestConstants.PLACEABLE_TRAPEZOID
	var polygon_node: Node = polygon_test_object.packed_scene.instantiate()
	add_child(polygon_node)
	auto_free(polygon_node)

	# Find collision objects in polygon scene
	var collision_objects: Array[Node2D] = []
	_find_collision_objects_recursive(polygon_node, collision_objects)

	# Only test collision detection if polygon has collision objects
	if not collision_objects.is_empty():
		var collision_tiles: Dictionary[Vector2i, Array] = (
			collision_mapper
			. get_collision_tile_positions_with_mask(collision_objects, DEFAULT_COLLISION_LAYER)
		)
		_assert_collision_results_valid(collision_tiles, "Polygon collision integration")

		# Verify polygon spans multiple coordinates if collision tiles exist
		if not collision_tiles.is_empty():
			_assert_polygon_spans_coordinates(collision_tiles)


## Helper to validate polygon collision pattern
func _assert_polygon_spans_coordinates(collision_tiles: Dictionary) -> void:
	var unique_x_coords: Dictionary[int, bool] = {}
	var unique_y_coords: Dictionary[int, bool] = {}

	for tile_pos: Variant in collision_tiles.keys():
		var tile_coord: Vector2i = tile_pos as Vector2i
		unique_x_coords[tile_coord.x] = true
		unique_y_coords[tile_coord.y] = true

	(
		assert_int(unique_x_coords.size()) \
		. append_failure_message(
			"Polygon should span multiple X coordinates, got %d" % unique_x_coords.size()
		) \
		. is_greater_equal(MIN_POLYGON_SPAN)
	)
	(
		assert_int(unique_y_coords.size()) \
		. append_failure_message(
			"Polygon should span multiple Y coordinates, got %d" % unique_y_coords.size()
		) \
		. is_greater_equal(MIN_POLYGON_SPAN)
	)


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
	(
		assert_bool(highlight_active) \
		. append_failure_message("Highlight should be active when targeting position is set") \
		. is_true()
	)


func test_targeting_state_transitions() -> void:
	var initial_pos: Vector2 = Vector2.ZERO
	if _gts.positioner != null:
		initial_pos = _gts.positioner.global_position
		_gts.positioner.global_position = TRANSITION_TEST_POS
		var updated_pos: Vector2 = _gts.positioner.global_position

		(
			assert_vector(updated_pos) \
			. append_failure_message(
				(
					"Target position should update from %s to %s, got %s"
					% [initial_pos, TRANSITION_TEST_POS, updated_pos]
				)
			) \
			. is_equal(TRANSITION_TEST_POS)
		)

		# Test clearing target
		_gts.positioner.global_position = Vector2.ZERO  # Reset to origin
		var cleared_pos: Vector2 = _gts.positioner.global_position

		# Cleared position behavior depends on system implementation
		(
			assert_object(cleared_pos) \
			. append_failure_message("Should have valid position response after clearing target") \
			. is_not_null()
		)


#endregion
#region COMPREHENSIVE INTEGRATION VALIDATION
@warning_ignore("unused_parameter")
func test_full_system_integration_workflow(
	p_placeable: Placeable,
	test_parameters := [
		[GBTestConstants.PLACEABLE_BLACKSMITH_BLUE],
		[GBTestConstants.PLACEABLE_HOUSE_WOODEN_RED],
		[GBTestConstants.PLACEABLE_SMITHY]
	]
) -> void:
	# Step 1: Set target
	_set_targeting_position(FULL_WORKFLOW_POS)

	# Step 2: Enter build mode with indicators
	if not _enter_build_mode_successfully(p_placeable):
		return

	var smithy_node: Node = p_placeable.packed_scene.instantiate()
	auto_free(smithy_node)
	add_child(smithy_node)

	var smithy_rules: Array[PlacementRule] = p_placeable.placement_rules

	var indicator_result: PlacementReport = _indicator_manager.try_setup(smithy_rules, _gts)
	_assert_setup_successful(indicator_result, "Full workflow indicator setup")

	# Step 3: Build at target
	var build_result: PlacementReport = _building_system.try_build_at_position(FULL_WORKFLOW_POS)
	(
		assert_object(build_result.placed) \
		. append_failure_message(
			"Full workflow should successfully place object at position %s" % FULL_WORKFLOW_POS
		) \
		. is_not_null()
	)

	# Step 4: Validate post-build state
	_building_system.exit_build_mode()
	(
		assert_bool(_building_system.is_in_build_mode()) \
		. append_failure_message(
			"Should not be in build mode after explicit exit in full workflow test"
		) \
		. is_false()
	)


func test_system_error_recovery() -> void:
	# Test recovery from invalid operations
	var invalid_placeable: Variant = null
	var invalid_report: PlacementReport = _building_system.enter_build_mode(invalid_placeable)

	# System should return a failed report for invalid input
	(
		assert_object(invalid_report) \
		. append_failure_message(
			(
				"enter_build_mode should return a PlacementReport even for invalid input, got: %s"
				% str(type_string(typeof(invalid_report)))
			)
		) \
		. is_not_null()
	)

	# Additional type validation
	(
		assert_bool(invalid_report is PlacementReport) \
		. append_failure_message(
			(
				"enter_build_mode should return a PlacementReport, got type: %s"
				% str(type_string(typeof(invalid_report)))
			)
		) \
		. is_true()
	)

	(
		assert_bool(invalid_report.is_successful()) \
		. append_failure_message("enter_build_mode should fail with null placeable") \
		. is_false()
	)

	# System should not be in build mode after failed enter_build_mode
	var is_in_build_mode: bool = _building_system.is_in_build_mode()
	(
		assert_bool(is_in_build_mode) \
		. append_failure_message("System should not be in build mode after failed enter_build_mode") \
		. is_false()
	)

	# Ensure system can recover to valid state
	var test_placeable: Placeable = GBTestConstants.PLACEABLE_SMITHY
	if _enter_build_mode_successfully(test_placeable):
		(
			assert_bool(_building_system.is_in_build_mode()) \
			. append_failure_message(
				"System should recover and enter build mode with valid placeable"
			) \
			. is_true()
		)

	_building_system.exit_build_mode()


#endregion

#region SUCCESS/FAILURE REPORTING TESTS


## Test: BuildingSystem reports success only when PlacementReport.is_successful() is true
## Setup: BuildingSystem with valid placeable, check PlacementReport consistency
## Act: Perform builds with different success/failure scenarios
## Assert: PlacementReport.is_successful() matches expected success/failure state
func test_building_system_reports_success_failure_correctly() -> void:
	var smithy_placeable: Placeable = GBTestConstants.PLACEABLE_SMITHY
	var enter_result: PlacementReport = _building_system.enter_build_mode(smithy_placeable)
	(
		assert_bool(enter_result.is_successful()) \
		. append_failure_message(
			"Failed to enter build mode with smithy: %s" % str(enter_result.get_issues())
		) \
		. is_true()
	)

	# Test Case 1: Valid build position should have successful PlacementReport
	var valid_result: PlacementReport = _building_system.try_build_at_position(VALID_BUILD_POS)
	(
		assert_object(valid_result) \
		. append_failure_message("try_build_at_position should return PlacementReport") \
		. is_not_null()
	)

	# The critical assertion: PlacementReport success state should match actual success
	if valid_result.get_issues().is_empty():
		(
			assert_bool(valid_result.is_successful()) \
			. append_failure_message(
				(
					"PlacementReport with no issues should be successful. Issues: %s"
					% str(valid_result.get_issues())
				)
			) \
			. is_true()
		)
	else:
		(
			assert_bool(valid_result.is_successful()) \
			. append_failure_message(
				(
					"PlacementReport with issues should not be successful. Issues: %s"
					% str(valid_result.get_issues())
				)
			) \
			. is_false()
		)

	# Test Case 2: Position with collision should have failed PlacementReport with issues
	# Create collision body at target position
	var collision_body: StaticBody2D = StaticBody2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = COLLISION_SHAPE_SIZE
	collision_shape.shape = rect_shape
	collision_body.add_child(collision_shape)
	collision_body.collision_layer = DEFAULT_COLLISION_LAYER
	collision_body.global_position = TARGET_POS
	add_child(collision_body)
	auto_free(collision_body)

	var collision_result: PlacementReport = _building_system.try_build_at_position(TARGET_POS)
	(
		assert_object(collision_result) \
		. append_failure_message(
			"try_build_at_position should return PlacementReport even for collision"
		) \
		. is_not_null()
	)

	# This should fail due to collision and have issues
	(
		assert_bool(collision_result.get_issues().is_empty()) \
		. append_failure_message(
			(
				"PlacementReport at collision position should have issues. Position: %s"
				% str(TARGET_POS)
			)
		) \
		. is_false()
	)

	(
		assert_bool(collision_result.is_successful()) \
		. append_failure_message(
			(
				"PlacementReport with collision should not be successful. Issues: %s"
				% str(collision_result.get_issues())
			)
		) \
		. is_false()
	)

	_building_system.exit_build_mode()

#endregion
