## Indicator Manager Tree Integration Test
## Tests that indicators are properly parented and integrated into the scene tree
## when created by the IndicatorManager, ensuring they exist in the correct hierarchy
## and are accessible for manipulation and rendering
extends GdUnitTestSuite

var _container: GBCompositionContainer
var indicator_manager: IndicatorManager
var targeting_state: GridTargetingState
var positioner: Node2D
var tile_map: TileMapLayer
var _injector: GBInjectorSystem
var manipulation_parent: Node2D

func before_test() -> void:
	# Use GBTestConstants for premade environment instead of UnifiedTestFactory
	var test_env: AllSystemsTestEnvironment = load(GBTestConstants.ALL_SYSTEMS_ENV_UID).instantiate()
	add_child(test_env)
	
	# Extract setup components for test access
	_container = test_env.get_container()
	targeting_state = _container.get_states().targeting
	positioner = test_env.positioner
	tile_map = test_env.tile_map_layer
	manipulation_parent = test_env.objects_parent
	_injector = test_env.injector
	indicator_manager = test_env.indicator_manager

# region Helper functions
func _create_preview_with_collision() -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "PreviewRoot"
	# Simple body with collision on layer 1
	var area: Area2D = Area2D.new()
	area.collision_layer = GBTestConstants.TEST_COLLISION_LAYER
	area.collision_mask = GBTestConstants.TEST_COLLISION_MASK
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	# Use half tile size for smaller collision shape
	const HALF_TILE_SIZE: Vector2 = GBTestConstants.DEFAULT_TILE_SIZE / 2
	rect.size = HALF_TILE_SIZE
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	positioner.add_child(root) # center on positioner
	return root
# endregion

func test_indicators_are_parented_and_inside_tree() -> void:
	var preview: Node2D = _create_preview_with_collision()
	targeting_state.target = preview
	# Build a tile check rule that applies to layer 1 and should create indicators
	var rule: TileCheckRule = TileCheckRule.new()
	rule.apply_to_objects_mask = GBTestConstants.TEST_COLLISION_LAYER
	rule.resource_name = "test_tile_rule"
	var rules: Array[PlacementRule] = [rule]
	var setup_results: PlacementReport = indicator_manager.try_setup(rules, targeting_state)
	assert_bool(setup_results.is_successful()).append_failure_message("IndicatorManager.try_setup failed: " + str(setup_results.get_all_issues())).is_true()
	var indicators: Array[RuleCheckIndicator] = indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created. Setup result: " + str(setup_results.is_successful())).is_not_empty()
	for ind: RuleCheckIndicator in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()
		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % ind.name).is_equal(_container.get_states().manipulation.parent)
