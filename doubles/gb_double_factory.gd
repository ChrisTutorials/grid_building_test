
class_name GBDoubleFactory

## Factory for creating doubles for testing purposes
const DEFAULT_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

static func create_test_injector(test: GdUnitTestSuite, container: GBCompositionContainer = DEFAULT_CONTAINER) -> GBInjectorSystem:
	var injector := GBInjectorSystem.new(container)
	test.add_child(injector)
	test.auto_free(injector)
	return injector

static func create_double_targeting_state(test : GdUnitTestSuite) -> GridTargetingState:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())
	test.auto_free(targeting_state)

	var positioner := Node2D.new()
	test.auto_free(positioner)
	targeting_state.positioner = positioner

	var target_map := create_test_tile_map_layer(test)
	targeting_state.target_map = target_map

	var layer1 := TileMapLayer.new()
	var layer2 := TileMapLayer.new()
	test.auto_free(layer1)
	test.auto_free(layer2)
	targeting_state.maps = [layer1, layer2]

	return targeting_state

static func create_test_logger() -> GBLogger:
	var debug_settings := GBDebugSettings.new()
	debug_settings.level = GBDebugSettings.DebugLevel.VERBOSE
	return GBLogger.new(debug_settings)

static func create_test_placement_manager(test: GdUnitTestSuite) -> PlacementManager:
	# Create PlacementContext
	var context := PlacementContext.new()
	test.auto_free(context)

	var indicator_template := load("uid://nhlp6ks003fp")
	var targeting_state := GBDoubleFactory.create_double_targeting_state(test)
	var logger := create_test_logger()
	var rules: Array[PlacementRule] = []
	var messages: GBMessages = GBMessages.new()

	var manager : PlacementManager = PlacementManager.new()
	test.auto_free(manager)
	manager.initialize(context, indicator_template, targeting_state, logger, rules, messages)
	test.add_child(manager)
	return manager

static func create_test_tile_map_layer(test: GdUnitTestSuite) -> TileMapLayer:
	var map_layer: TileMapLayer = TileMapLayer.new()
	map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-100, 100, 1):
		for y in range(-100, 100, 1):
			var cords = Vector2i(x, y)
			map_layer.set_cell(cords, 0, Vector2i(0,0))
	test.add_child(map_layer)
	test.auto_free(map_layer)
	return map_layer
