extends GdUnitTestSuite

## Minimal test to isolate GridTargetingState tile_size issue

func before_test() -> void:
	pass

func test_basic_targeting_state_creation() -> void:
	var owner_context := GBOwnerContext.new()
	var targeting_state := GridTargetingState.new(owner_context)
	
	# Create a basic tile map setup
	var test_map: TileMapLayer = TileMapLayer.new()
	auto_free(test_map)
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	test_map.tile_set = tile_set
	add_child(test_map)
	
	# Basic assignment - this should work fine
	targeting_state.target_map = test_map
	
		# Test tile_set access - this should work
	var retrieved_tile_set : TileSet = targeting_state.get_target_map_tile_set()
	assert_that(retrieved_tile_set).append_failure_message("Expected tile set to be available").is_not_null()
	GBTestDiagnostics.buffer("Basic GridTargetingState test completed")
	var context := GBTestDiagnostics.flush_for_assert()
	assert_that(retrieved_tile_set.tile_size).append_failure_message("Expected tile size to be 16x16. Context: %s" % context).is_equal(Vector2i(16, 16))
