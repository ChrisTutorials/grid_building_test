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

func test_create_test_static_body_with_rect_shape_frees():
	var node = GBDoubleFactory.create_test_static_body_with_rect_shape(self)
	created_nodes.append(node)
	assert_bool(node is StaticBody2D).is_true()

func test_create_test_collision_polygon_frees():
	var node = GBDoubleFactory.create_test_collision_polygon(self)
	created_nodes.append(node)
	assert_bool(node is CollisionPolygon2D).is_true()

func test_create_test_parent_with_body_and_polygon_frees():
	var node = GBDoubleFactory.create_test_parent_with_body_and_polygon(self)
	created_nodes.append(node)
	assert_bool(node is Node2D).is_true()

func test_create_test_object_with_circle_shape_frees():
	var node = GBDoubleFactory.create_test_object_with_circle_shape(self)
	created_nodes.append(node)
	assert_bool(node is Node2D).is_true()

func test_create_test_indicator_rect_frees():
	var node = GBDoubleFactory.create_test_indicator_rect(self, 16)
	created_nodes.append(node)
	assert_bool(node is RuleCheckIndicator).is_true()

func test_create_test_injector_returns_injector():
	var injector = GBDoubleFactory.create_test_injector(self, GBDoubleFactory.TEST_CONTAINER)
	assert_bool(injector is GBInjectorSystem).is_true()

func test_create_collision_object_test_setups_returns_dict():
	var obj: StaticBody2D = GBDoubleFactory.create_test_static_body_with_rect_shape(self)
	var col_objects = [obj]
	var setups = GBDoubleFactory.create_collision_object_test_setups(col_objects)
	assert_bool(setups is Dictionary).is_true()
	assert_int(setups.size()).is_equal(1)

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
