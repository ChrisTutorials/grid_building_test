## Indicator Manager Tree Integration Test
## Tests that indicators are properly parented and integrated into the scene tree
## when created by the IndicatorManager, ensuring they exist in the correct hierarchy
## and are accessible for manipulation and rendering
extends GdUnitTestSuite

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _container: GBCompositionContainer
var indicator_manager: IndicatorManager
var targeting_state: GridTargetingState
var positioner: Node2D
var tile_map: TileMapLayer
var _injector: GBInjectorSystem
var manipulation_parent: Node2D

func before_test() -> void:
	# Use comprehensive factory method for complete indicator manager tree test setup
	var test_env: Dictionary = UnifiedTestFactory.create_indicator_test_environment(self, BASE_CONTAINER.duplicate(true))
	
	# Extract setup components for test access
	_container = test_env.container
	targeting_state = test_env.targeting_state
	positioner = test_env.positioner
	tile_map = test_env.tile_map
	manipulation_parent = test_env.objects_parent
	_injector = test_env.injector
	indicator_manager = test_env.indicator_manager

# region Helper functions
func _create_preview_with_collision() -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "PreviewRoot"
	# Simple body with collision on layer 1
	var area: Area2D = Area2D.new()
	area.collision_layer = 1
	area.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	positioner.add_child(root) # center on positioner
	return root
# endregion

func test_indicators_are_parented_and_inside_tree() -> void:
	var preview: Node2D = _create_preview_with_collision()
	targeting_state.target = preview
	# Build a collisions rule that applies to layer 1
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var rules: Array[PlacementRule] = [rule]
	var setup_results: PlacementReport = indicator_manager.try_setup(rules, targeting_state)
	assert_bool(setup_results.is_successful()).append_failure_message("IndicatorManager.try_setup failed").is_true()
	var indicators: Array[RuleCheckIndicator] = indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created").is_not_empty()
	for ind: RuleCheckIndicator in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()
		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % ind.name).is_equal(_container.get_states().manipulation.parent)
