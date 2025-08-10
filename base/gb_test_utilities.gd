class_name GBTestUtilities
extends RefCounted

## Test utilities providing common test data, constants, and helper functions
## for Grid Building tests

# ================================
# Common Test Constants
# ================================

const DEFAULT_TILE_SIZE: int = 16
const DEFAULT_GRID_SIZE: int = 40
const DEFAULT_COLLISION_EXTENTS: Vector2 = Vector2(8, 8)
const DEFAULT_CIRCLE_RADIUS: float = 8.0
const DEFAULT_CAPSULE_RADIUS: float = 48.0
const DEFAULT_CAPSULE_HEIGHT: float = 128.0

# ================================
# Common Test Data
# ================================

## Default triangle polygon for collision testing
static func get_default_triangle_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(8, 16)])

## Default rectangle polygon for collision testing
static func get_default_rectangle_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])

## Default test tile data for placement rules
static func get_default_test_tile_data() -> Dictionary:
	return {
		"valid": true,
		"type": "test",
		"properties": {}
	}

## Default test placement context data
static func get_default_placement_context_data() -> Dictionary:
	return {
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"valid": true
	}

## Default test manipulation data
static func get_default_manipulation_data() -> Dictionary:
	return {
		"action": GBEnums.Action.BUILD,
		"source": null,
		"target": null,
		"valid": true
	}

# ================================
# Test Validation Helpers
# ================================

## Assert that a node has the expected type
static func assert_node_type(node: Node, expected_type: GDScript, test: GdUnitTestSuite) -> void:
	test.assert_bool(node is expected_type).is_true()

## Assert that a node has the expected name
static func assert_node_name(node: Node, expected_name: String, test: GdUnitTestSuite) -> void:
	test.assert_str(node.name).is_equal(expected_name)

## Assert that a node has the expected parent
static func assert_node_parent(node: Node, expected_parent: Node, test: GdUnitTestSuite) -> void:
	test.assert_object(node.get_parent()).is_equal(expected_parent)

## Assert that a node has the expected child count
static func assert_node_child_count(node: Node, expected_count: int, test: GdUnitTestSuite) -> void:
	test.assert_int(node.get_child_count()).is_equal(expected_count)

## Assert that a node has a child with the expected name
static func assert_node_has_child_with_name(node: Node, child_name: String, test: GdUnitTestSuite) -> void:
	var child = node.get_node_or_null(child_name)
	test.assert_object(child).is_not_null()

## Assert that a node has a child of the expected type
static func assert_node_has_child_of_type(node: Node, child_type: GDScript, test: GdUnitTestSuite) -> void:
	var found = false
	for child in node.get_children():
		if child is child_type:
			found = true
			break
	test.assert_bool(found).is_true()

## Assert that a transform has the expected origin
static func assert_transform_origin(transform: Transform2D, expected_origin: Vector2, test: GdUnitTestSuite) -> void:
	test.assert_vector2(transform.origin).is_equal(expected_origin)

## Assert that a transform has the expected rotation
static func assert_transform_rotation(transform: Transform2D, expected_rotation: float, test: GdUnitTestSuite) -> void:
	test.assert_float(transform.get_rotation()).is_equal(expected_rotation)

## Assert that a transform has the expected scale
static func assert_transform_scale(transform: Transform2D, expected_scale: Vector2, test: GdUnitTestSuite) -> void:
	test.assert_vector2(transform.get_scale()).is_equal(expected_scale)

# ================================
# Test Setup Helpers
# ================================

## Create a test scene with multiple nodes of the same type
static func create_test_scene_with_nodes(
	test: GdUnitTestSuite,
	node_type: GDScript,
	node_count: int,
	parent: Node = null
) -> Array:
	var nodes = []
	var target_parent = parent if parent else test
	
	for i in range(node_count):
		var node = node_type.new()
		test.auto_free(node)
		target_parent.add_child(node)
		node.name = "TestNode_%d" % i
		nodes.append(node)
	
	return nodes

## Create a test hierarchy with specified depth and children per level
static func create_test_hierarchy(
	test: GdUnitTestSuite,
	depth: int,
	children_per_level: int,
	parent: Node = null
) -> Node:
	var target_parent = parent if parent else test
	var root = Node2D.new()
	test.auto_free(root)
	target_parent.add_child(root)
	root.name = "Root"
	
	if depth > 0:
		for i in range(children_per_level):
			var child = create_test_hierarchy(test, depth - 1, children_per_level, root)
			child.name = "Child_%d" % i
	
	return root

## Create a test grid of nodes
static func create_test_grid(
	test: GdUnitTestSuite,
	width: int,
	height: int,
	spacing: Vector2 = Vector2(32, 32),
	parent: Node = null
) -> Array:
	var nodes = []
	var target_parent = parent if parent else test
	
	for x in range(width):
		for y in range(height):
			var node = Node2D.new()
			test.auto_free(node)
			target_parent.add_child(node)
			node.name = "GridNode_%d_%d" % [x, y]
			node.position = Vector2(x * spacing.x, y * spacing.y)
			nodes.append(node)
	
	return nodes

# ================================
# Test Cleanup Helpers
# ================================

## Safely remove a node from its parent
static func safe_remove_node(node: Node) -> void:
	if node and node.get_parent():
		node.get_parent().remove_child(node)

## Safely free a node and its children
static func safe_free_node(node: Node) -> void:
	if node:
		# Remove from parent first
		safe_remove_node(node)
		# Free the node
		node.queue_free()

## Clean up a test scene dictionary
static func cleanup_test_scene(scene: Dictionary) -> void:
	for key in scene:
		var value = scene[key]
		if value is Node:
			safe_free_node(value)
	scene.clear()

# ================================
# Test Data Generators
# ================================

## Generate test positions in a grid pattern
static func generate_test_positions(
	start_pos: Vector2,
	end_pos: Vector2,
	step: Vector2
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var current = start_pos
	
	while current.x <= end_pos.x and current.y <= end_pos.y:
		positions.append(current)
		current += step
	
	return positions

## Generate test transforms with variations
static func generate_test_transforms(
	base_transform: Transform2D,
	position_variations: Array[Vector2],
	rotation_variations: Array[float],
	scale_variations: Array[Vector2]
) -> Array[Transform2D]:
	var transforms: Array[Transform2D] = []
	
	for pos in position_variations:
		for rot in rotation_variations:
			for scale in scale_variations:
				var transform = base_transform
				transform.origin = pos
				transform = transform.rotated(rot)
				transform = transform.scaled(scale)
				transforms.append(transform)
	
	return transforms

## Generate test collision shapes with different sizes
static func generate_test_collision_shapes(
	base_size: Vector2,
	size_multipliers: Array[float]
) -> Array[RectangleShape2D]:
	var shapes: Array[RectangleShape2D] = []
	
	for multiplier in size_multipliers:
		var shape = RectangleShape2D.new()
		shape.extents = base_size * multiplier
		shapes.append(shape)
	
	return shapes

# ================================
# Test Assertion Helpers
# ================================

## Assert that all nodes in an array are valid
static func assert_all_nodes_valid(nodes: Array, test: GdUnitTestSuite) -> void:
	for node in nodes:
		test.assert_object(node).is_not_null()

## Assert that all nodes in an array have the expected type
static func assert_all_nodes_of_type(nodes: Array, expected_type: GDScript, test: GdUnitTestSuite) -> void:
	for node in nodes:
		assert_node_type(node, expected_type, test)

## Assert that all nodes in an array have unique names
static func assert_all_nodes_have_unique_names(nodes: Array, test: GdUnitTestSuite) -> void:
	var names = []
	for node in nodes:
		test.assert_bool(names.has(node.name)).is_false()
		names.append(node.name)

## Assert that a node tree has the expected structure
static func assert_node_tree_structure(
	root: Node,
	expected_structure: Dictionary,
	test: GdUnitTestSuite
) -> void:
	# This is a recursive helper to validate node tree structure
	_validate_node_structure_recursive(root, expected_structure, test)

static func _validate_node_structure_recursive(
	node: Node,
	expected: Dictionary,
	test: GdUnitTestSuite
) -> void:
	# Validate node name if specified
	if expected.has("name"):
		assert_node_name(node, expected.name, test)
	
	# Validate node type if specified
	if expected.has("type"):
		assert_node_type(node, expected.type, test)
	
	# Validate child count if specified
	if expected.has("child_count"):
		assert_node_child_count(node, expected.child_count, test)
	
	# Validate children if specified
	if expected.has("children"):
		var children = expected.children
		test.assert_int(node.get_child_count()).is_equal(children.size())
		
		for i in range(children.size()):
			var child_expected = children[i]
			var child_node = node.get_child(i)
			_validate_node_structure_recursive(child_node, child_expected, test)

# ================================
# Test Setup Validation
# ================================

## Validate that a test setup has all required components
static func validate_test_setup(setup: Dictionary, required_keys: Array[String], test: GdUnitTestSuite) -> void:
	for key in required_keys:
		test.assert_bool(setup.has(key)).is_true()
		test.assert_object(setup[key]).is_not_null()

## Validate that a system has no dependency issues
static func assert_system_dependencies_valid(system: Node, test: GdUnitTestSuite) -> void:
	if system.has_method("validate_dependencies"):
		var issues = system.validate_dependencies()
		test.assert_array(issues).is_empty()

## Validate that a system has expected dependency issues
static func assert_system_dependencies_have_issues(system: Node, expected_issue_count: int, test: GdUnitTestSuite) -> void:
	if system.has_method("validate_dependencies"):
		var issues = system.validate_dependencies()
		test.assert_int(issues.size()).is_greater_equal(expected_issue_count)

## Validate that a node has all required properties
static func assert_node_has_required_properties(node: Node, required_properties: Array[String], test: GdUnitTestSuite) -> void:
	for property in required_properties:
		test.assert_bool(node.get(property) != null).is_true()

# ================================
# Test Resource Management
# ================================

## Create a test resource with proper cleanup
static func create_test_resource(resource_type: GDScript, test: GdUnitTestSuite) -> Resource:
	var resource = resource_type.new()
	test.auto_free(resource)
	return resource

## Create a test script with proper cleanup
static func create_test_script(script_path: String, test: GdUnitTestSuite) -> GDScript:
	var script = load(script_path)
	test.assert_object(script).is_not_null()
	return script

## Create a test packed scene with proper cleanup
static func create_test_packed_scene(scene_path: String, test: GdUnitTestSuite) -> PackedScene:
	var scene = load(scene_path)
	test.assert_object(scene).is_not_null()
	return scene

# ================================
# Test State Management
# ================================

## Create a test state object with default values
static func create_test_state(state_type: GDScript, test: GdUnitTestSuite) -> Object:
	var state = state_type.new()
	test.auto_free(state)
	return state

## Create a test context object with default values
static func create_test_context(context_type: GDScript, test: GdUnitTestSuite) -> Object:
	var context = context_type.new()
	test.auto_free(context)
	return context

## Create a test configuration object with default values
static func create_test_config(config_type: GDScript, test: GdUnitTestSuite) -> Object:
	var config = config_type.new()
	test.auto_free(config)
	return config

# ================================
# Test Error Handling
# ================================

## Assert that a function call produces the expected error
static func assert_function_error(
	func_call: Callable,
	expected_error: String,
	test: GdUnitTestSuite
) -> void:
	var error_occurred = false
	var error_message = ""
	
	# Set up error handler
	var error_handler = func(message: String):
		error_occurred = true
		error_message = message
	
	# Call the function and check for errors
	func_call.call()
	
	test.assert_bool(error_occurred).is_true()
	if expected_error != "":
		test.assert_str(error_message).contains(expected_error)

## Assert that a function call produces no errors
static func assert_function_no_error(
	func_call: Callable,
	test: GdUnitTestSuite
) -> void:
	var error_occurred = false
	
	# Set up error handler
	var error_handler = func(message: String):
		error_occurred = true
	
	# Call the function and check for no errors
	func_call.call()
	
	test.assert_bool(error_occurred).is_false()

# ================================
# Test Performance Helpers
# ================================

## Measure execution time of a function
static func measure_execution_time(
	func_call: Callable,
	test: GdUnitTestSuite
) -> float:
	var start_time = Time.get_ticks_msec()
	func_call.call()
	var end_time = Time.get_ticks_msec()
	return (end_time - start_time) / 1000.0

## Assert that a function executes within expected time
static func assert_execution_time_within_limit(
	func_call: Callable,
	max_time_seconds: float,
	test: GdUnitTestSuite
) -> void:
	var execution_time = measure_execution_time(func_call, test)
	test.assert_float(execution_time).is_less_equal(max_time_seconds)

# ================================
# Test Data Persistence
# ================================

## Save test data to a temporary file
static func save_test_data_to_file(data: Dictionary, file_path: String, test: GdUnitTestSuite) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	test.assert_object(file).is_not_null()
	file.store_string(JSON.stringify(data))
	file.close()

## Load test data from a file
static func load_test_data_from_file(file_path: String, test: GdUnitTestSuite) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	test.assert_object(file).is_not_null()
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	test.assert_int(parse_result).is_equal(OK)
	
	return json.data

## Clean up temporary test files
static func cleanup_test_files(file_paths: Array[String]) -> void:
	for file_path in file_paths:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)

# ================================
# Test Randomization
# ================================

## Set a fixed seed for reproducible tests
static func set_fixed_random_seed(seed_value: int) -> void:
	seed(seed_value)
	randi() # Initialize the random number generator

## Generate random test data within bounds
static func generate_random_test_data(
	min_values: Dictionary,
	max_values: Dictionary
) -> Dictionary:
	var data = {}
	for key in min_values:
		if key in max_values:
			if min_values[key] is int:
				data[key] = randi_range(min_values[key], max_values[key])
			elif min_values[key] is float:
				data[key] = randf_range(min_values[key], max_values[key])
			elif min_values[key] is Vector2:
				data[key] = Vector2(
					randf_range(min_values[key].x, max_values[key].x),
					randf_range(min_values[key].y, max_values[key].y)
				)
	return data

# ================================
# Test Documentation Helpers
# ================================

## Generate a test summary report
static func generate_test_summary(
	test_name: String,
	setup_time: float,
	execution_time: float,
	cleanup_time: float,
	success: bool
) -> String:
	var summary = "Test: %s\n" % test_name
	summary += "Setup Time: %.3f seconds\n" % setup_time
	summary += "Execution Time: %.3f seconds\n" % execution_time
	summary += "Cleanup Time: %.3f seconds\n" % cleanup_time
	summary += "Total Time: %.3f seconds\n" % (setup_time + execution_time + cleanup_time)
	summary += "Status: %s\n" % ("PASSED" if success else "FAILED")
	return summary

## Log test execution details
static func log_test_execution(
	test_name: String,
	details: Dictionary,
	test: GdUnitTestSuite
) -> void:
	var log_message = "Test Execution: %s\n" % test_name
	for key in details:
		log_message += "  %s: %s\n" % [key, details[key]]
	
	# Use test's logging if available, otherwise print
	if test.has_method("log"):
		test.log(log_message)
	else:
		print(log_message)
