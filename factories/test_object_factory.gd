class_name TestObjectFactory
extends RefCounted

## Centralized factory for creating test objects with proper dependencies
## This factory pattern simplifies test setup and ensures consistency across all test suites

# ================================
# Core System Objects
# ================================

## Creates a fully configured BuildingSystem for testing
static func create_building_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> BuildingSystem:
	var _container = container if container != null else GBCompositionContainer.new()
	var system := BuildingSystem.new()
	
	# Set up required dependencies
	system.actions = GBActions.new()
	system.mode_state = ModeState.new()
	system.state = _container.get_states().building
	system.targeting_state = _container.get_states().targeting
	system.debug = GBDebugSettings.new(GBDebugSettings.DebugLevel.INFO)
	
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a fully configured ManipulationSystem for testing
static func create_manipulation_system(test: GdUnitTestSuite, container: GBCompositionContainer = null) -> ManipulationSystem:
	var _container = container if container != null else GBCompositionContainer.new()
	var system := ManipulationSystem.new()
	
	# Use dependency injection to set up the system
	system.resolve_gb_dependencies(_container)
	
	test.auto_free(system)
	test.add_child(system)
	return system

## Creates a fully configured PlacementManager for testing
static func create_placement_manager(test: GdUnitTestSuite, targeting_state: GridTargetingState = null) -> PlacementManager:
	var manager := PlacementManager.new()
	
	# Set up dependencies
	var placement_context := PlacementContext.new()
	var indicator_template := load("uid://nhlp6ks003fp")
	var state := targeting_state if targeting_state != null else create_targeting_state(test)
	var logger := GBDoubleFactory.create_test_logger()
	var rules: Array[PlacementRule] = []
	var messages := GBMessages.new()
	
	manager.initialize(placement_context, indicator_template, state, logger, rules, messages)
	
	test.auto_free(manager)
	test.auto_free(placement_context)
	test.add_child(manager)
	return manager

# ================================
# State Objects
# ================================

## Creates a fully configured GridTargetingState for testing
static func create_targeting_state(test: GdUnitTestSuite, owner_context: GBOwnerContext = null) -> GridTargetingState:
	var context := owner_context if owner_context != null else create_owner_context(test)
	var targeting_state := GridTargetingState.new(context)
	
	# Set up required components
	var positioner := Node2D.new()
	test.auto_free(positioner)
	test.add_child(positioner)
	targeting_state.positioner = positioner
	
	var map_layer := create_tile_map_layer(test)
	targeting_state.set_map_objects(map_layer, [map_layer])
	
	test.auto_free(targeting_state)
	return targeting_state

## Creates a fully configured GBOwnerContext for testing
static func create_owner_context(test: GdUnitTestSuite) -> GBOwnerContext:
	var context := GBOwnerContext.new()
	var user := Node2D.new()
	test.auto_free(user)
	test.add_child(user)
	context.user = user
	return context

# ================================
# Validation Objects
# ================================

## Creates a PlacementValidator with proper dependencies
static func create_placement_validator(_test: GdUnitTestSuite, rules: Array[PlacementRule] = []) -> PlacementValidator:
	var messages := GBMessages.new()
	var logger := GBDoubleFactory.create_test_logger()
	return PlacementValidator.new(rules, messages, logger)

## Creates an IndicatorManager with proper dependencies
static func create_indicator_manager(test: GdUnitTestSuite, targeting_state: GridTargetingState = null) -> IndicatorManager:
	var parent := Node2D.new()
	test.auto_free(parent)
	test.add_child(parent)
	
	var template := load("uid://nhlp6ks003fp")
	var state := targeting_state if targeting_state != null else create_targeting_state(test)
	var logger := GBDoubleFactory.create_test_logger()
	
	return IndicatorManager.new(parent, state, template, logger)

# ================================
# Rule Objects
# ================================

## Creates rule objects with proper initialization
static func create_rule_with_logger(rule_class: GDScript) -> PlacementRule:
	var rule: PlacementRule = rule_class.new()
	var logger := GBDoubleFactory.create_test_logger()
	rule.initialize(logger)
	return rule

## Creates a RuleCheckIndicator with proper dependencies
static func create_rule_check_indicator(test: GdUnitTestSuite, rules: Array[TileCheckRule] = []) -> RuleCheckIndicator:
	var logger := GBDoubleFactory.create_test_logger()
	var indicator := RuleCheckIndicator.new(rules, logger)
	test.auto_free(indicator)
	test.add_child(indicator)
	return indicator

# ================================
# Test Environment Objects
# ================================

## Creates a TileMapLayer for testing
static func create_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	return GBDoubleFactory.create_test_tile_map_layer(test)

## Creates test collision objects
static func create_collision_test_setup(test: GdUnitTestSuite, collision_object: CollisionObject2D = null) -> IndicatorCollisionTestSetup:
	return GBDoubleFactory.create_test_indicator_collision_setup(test, collision_object)

# ================================
# Validation Parameters
# ================================

## Creates properly structured RuleValidationParameters
static func create_rule_validation_params(test: GdUnitTestSuite, target: Node2D = null, targeting_state: GridTargetingState = null) -> RuleValidationParameters:
	var placer := Node2D.new()
	test.auto_free(placer)
	test.add_child(placer)
	
	var test_target := target if target != null else Node2D.new()
	if target == null:
		test.auto_free(test_target)
		test.add_child(test_target)
	
	var state := targeting_state if targeting_state != null else create_targeting_state(test)
	
	return RuleValidationParameters.new(placer, test_target, state)
