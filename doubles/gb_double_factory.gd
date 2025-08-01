class_name GBDoubleFactory

static func create_double_targeting_state(test : GdUnitTestSuite) -> GridTargetingState:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())
	test.auto_free(targeting_state)

	var positioner := Node2D.new()
	targeting_state.positioner = positioner
	targeting_state.add_child(positioner)
	test.auto_free(positioner)

	var target_map := TileMapLayer.new()
	targeting_state.target_map = target_map
	targeting_state.add_child(target_map)
	test.auto_free(target_map)

	var layer1 := TileMapLayer.new()
	var layer2 := TileMapLayer.new()
	targeting_state.maps = [layer1, layer2]
	targeting_state.add_child(layer1)
	targeting_state.add_child(layer2)
	test.auto_free(layer1)
	test.auto_free(layer2)

	return targeting_state


static func create_test_logger() -> GBLogger:
	var debug_settings := GBDebugSettings.new()
	debug_settings.level = GBDebugSettings.DebugLevel.VERBOSE
	return GBLogger.new(debug_settings)
