## GdUnit TestSuite for GBDoubleFactory node lifecycle
extends GdUnitTestSuite

var created_nodes := []

func before_test():
	created_nodes.clear()

func after_test():
	# Wait for idle frame to ensure all nodes are freed
	await get_tree().process_frame
	for node in created_nodes:
		assert_bool(!is_instance_valid(node)).append_failure_message("Node should be freed after test: %s" % node).is_true()

func test_create_test_tile_map_layer_frees():
	var node = GBDoubleFactory.create_test_tile_map_layer(self)
	created_nodes.append(node)

func test_create_double_targeting_state_returns_resource():
	var resource = GBDoubleFactory.create_double_targeting_state(self)
	assert_bool(resource is GridTargetingState).is_true()

func test_create_test_placement_manager_frees():
	var node = GBDoubleFactory.create_test_placement_manager(self)
	created_nodes.append(node)

# Optionally, test create_test_logger (not a Node, but for completeness)
func test_create_test_logger_returns_logger():
	var logger = GBDoubleFactory.create_test_logger()
	assert_bool(logger is GBLogger).is_true()
