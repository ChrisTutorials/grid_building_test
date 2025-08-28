extends GdUnitTestSuite

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _container: GBCompositionContainer
var indicator_manager: IndicatorManager
var targeting_state: GridTargetingState
var positioner: Node2D
var tile_map: TileMapLayer
var _injector : GBInjectorSystem

func before_test():
	_container = BASE_CONTAINER.duplicate(true)
	_injector = UnifiedTestFactory.create_test_injector(self, _container)
	# Minimal tile map
	tile_map = auto_free(TileMapLayer.new())
	tile_map.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-2, 3):
		for y in range(-2, 3):
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0,0))
	add_child(tile_map)

	# Positioner
	positioner = auto_free(Node2D.new())
	positioner.name = "Positioner"
	positioner.global_position = Vector2.ZERO
	add_child(positioner)

	targeting_state = _container.get_states().targeting
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]
	targeting_state.positioner = positioner

	indicator_manager = IndicatorManager.create_with_injection(_container)
	add_child(auto_free(indicator_manager))

func _create_preview_with_collision() -> Node2D:
	var root := Node2D.new()
	root.name = "PreviewRoot"
	# Simple body with collision on layer 1
	var area := Area2D.new()
	area.collision_layer = 1
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.extents = Vector2(8,8)
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	positioner.add_child(root) # center on positioner
	return root

func test_indicators_are_parented_and_inside_tree():
	var preview = _create_preview_with_collision()
	targeting_state.target = preview
	# Build a collisions rule that applies to layer 1
	var rule: CollisionsCheckRule = CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var rules: Array[PlacementRule] = [rule]
	var logger = _container.get_logger()
	var params := RuleValidationParameters.new(positioner, preview, targeting_state, logger)
	var setup_ok := indicator_manager.try_setup(rules, params)
	assert_bool(setup_ok.is_successful()).append_failure_message("IndicatorManager.try_setup failed").is_true()
	var indicators := indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message("No indicators created").is_not_empty()
	for ind in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator has no parent: %s" % ind.name).is_not_null()
		assert_object(ind.get_parent()).append_failure_message("Unexpected parent for indicator: %s" % ind.name).is_equal(_container.get_states().manipulation.parent)
