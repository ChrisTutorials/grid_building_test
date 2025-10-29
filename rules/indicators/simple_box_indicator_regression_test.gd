# Test Suite: Simple Box Indicator Regression Tests
# This test suite validates regression fixes for indicator generation with simple
# box collision objects. It specifically tests that RigidBody2D objects with
# collision layer 513 generate proper placement indicators through the indicator
# manager and collision geometry utilities.

extends GdUnitTestSuite

#region Constants
const TEST_COLLISION_LAYER: int = 513  # Bits 0 and 9 (layers 1 and 10)
const TILEMAP_SIZE: int = 7  # 5x5 around origin (-3 to 3)
const TILEMAP_OFFSET: int = -3
const COLLISION_SHAPE_SIZE: Vector2 = Vector2(32, 32)  # Use reasonable size instead of 1x1
#endregion

#region Test Variables
var unoccupied_space: CollisionsCheckRule = load("uid://dw6l5ddiuak8b")
var _container: GBCompositionContainer
var building_system: BuildingSystem
var positioner: Node2D
var tile_map_layer: TileMapLayer
var _injector: GBInjectorSystem
var _gts: GridTargetingState
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Create environment using premade scene
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	assert_that(env_scene).is_not_null()
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)

	_container = env.get_container()
	_injector = env.injector
	_gts = env.grid_targeting_system.get_state()

	# Create 5x5 tile map around origin
	# Use pre-validated test tilemap from GBTestConstants to avoid missing atlas issues
	var packed_tilemap: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	assert_object(packed_tilemap) \
		.append_failure_message("GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE must be defined and preloadable") \
		.is_not_null()
	tile_map_layer = auto_free(packed_tilemap.instantiate() as TileMapLayer)
	# Ensure tilemap is parented for scene tree operations
	add_child(tile_map_layer)

	# Positioner
	positioner = auto_free(Node2D.new())
	add_child(positioner)

	# Set up targeting state
	var targeting_state: GridTargetingState = _container.get_states().targeting
	targeting_state.set_map_objects(tile_map_layer, [tile_map_layer])
	targeting_state.positioner = positioner

	# Note: AllSystemsTestEnvironment already provides ManipulationParent setup via injection

	# Set up owner context
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var owner_node: Node2D = auto_free(Node2D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	var gb_owner := GBOwner.new(owner_node)
	auto_free(gb_owner)
	owner_context.set_owner(gb_owner)

	# Set up placed parent
	var placed_parent: Node2D = auto_free(Node2D.new())
	_container.get_states().building.placed_parent = placed_parent
	add_child(placed_parent)

	# Use building system from AllSystemsTestEnvironment
	building_system = env.building_system
	assert_object(building_system).append_failure_message(
		"AllSystemsTestEnvironment should provide BuildingSystem"
	).is_not_null()

	# Ensure placement manager exists
	if _container.get_contexts().indicator.get_manager() == null:
		var pm := IndicatorManager.create_with_injection(_container)
		add_child(auto_free(pm))
#endregion

#region Test Functions
func test_rigid_body_with_collision_layer_513_generates_indicators() -> void:
	# Create a simple test scene with just a collision object
	# NOTE: Don't use auto_free for nodes that will be packed into PackedScene
	var test_box: RigidBody2D = RigidBody2D.new()
	test_box.name = "SimpleBox"
	test_box.collision_layer = TEST_COLLISION_LAYER  # Bits 0 and 9 (layers 1 and 10)

	# Add collision shape
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = COLLISION_SHAPE_SIZE
	shape.shape = rect
	test_box.add_child(shape)

	# CRITICAL: Set owner for PackedScene to include the collision shape
	shape.owner = test_box

	add_child(test_box)

	# CRITICAL: Position the test box at the positioner location for collision detection
	test_box.global_position = positioner.global_position

	# Verify the collision layer matches the unoccupied space rule
	var box_layer: int = test_box.collision_layer
	var unoccupied_mask: int = unoccupied_space.apply_to_objects_mask
	var box_layer_match: bool = (box_layer & unoccupied_mask) != 0
	assert_bool(box_layer_match).append_failure_message(
		"Box collision_layer %d does not match unoccupied space check rule apply_to_objects_mask %d" % [box_layer, unoccupied_mask]
	).is_true()

	# Create a simple placeable
	var scene: PackedScene = PackedScene.new()
	scene.pack(test_box)
	var placeable: Placeable = Placeable.new(scene, [unoccupied_space])
	placeable.display_name = &"Simple Box"

	# Guard assertion - ensure building system is properly initialized
	assert_object(building_system).append_failure_message(
		"BuildingSystem should be initialized in before_test()"
	).is_not_null()

	# Enter build mode
	building_system.selected_placeable = placeable
	var entered: PlacementReport = building_system.enter_build_mode(placeable)
	assert_bool(entered.is_successful()).append_failure_message(
		"Failed to enter build mode with simple box"
	).is_true()

	# Get the preview and placement manager
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).append_failure_message(
		"No preview generated for simple box. Placeable: %s, rules: %s" % [placeable, placeable.placement_rules]
	).is_not_null()

	# Verify preview contains collision objects
	var preview_collision_objects: Array[Node2D] = []
	_find_collision_objects(preview, preview_collision_objects)
	assert_array(preview_collision_objects).append_failure_message(
		"Preview should contain collision objects"
	).is_not_empty()

	# Debug the preview structure - this should contain collision objects
	var collision_object_details: Array[String] = []
	for i in range(preview_collision_objects.size()):
		var obj: Node2D = preview_collision_objects[i]
		var detail: String = "%s (%s)" % [obj.name, obj.get_class()]
		if obj is CollisionObject2D:
			detail += " [layer: %d, shape_owners: %s]" % [obj.collision_layer, obj.get_shape_owners()]
			var shapes_from_owner: Array = GBGeometryUtils.get_shapes_from_owner(obj)
			detail += " [shapes: %d]" % shapes_from_owner.size()
			# Debug children
			var children_info: Array[String] = []
			for child: Node in obj.get_children():
				if child is CollisionShape2D:
					var child_detail: String = "%s: shape=%s" % [child.name, child.shape != null]
					children_info.append(child_detail)
			if not children_info.is_empty():
				detail += " [children: %s]" % [children_info]
		collision_object_details.append(detail)

	# Verify GBGeometryUtils can find collision shapes in preview
	var owner_shapes: Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(preview)

	# This assertion should fail and expose the root cause
	assert_int(owner_shapes.size()).append_failure_message(
		"CORE ISSUE: GBGeometryUtils.get_all_collision_shapes_by_owner() returns 0 owners despite preview having %d collision objects: %s" % [preview_collision_objects.size(), collision_object_details]
	).is_greater(0)

	var manager := _container.get_contexts().indicator.get_manager()
	assert_object(manager).append_failure_message(
		"No placement manager available"
	).is_not_null()

	# Set up rule validation parameters (same as test)
	var _manip_owner: Node = _container.get_states().manipulation.get_manipulator()

	# Set up rules
	var setup_success: PlacementReport = manager.try_setup(placeable.placement_rules, _gts, false)
	assert_bool(setup_success.is_successful()).append_failure_message(
		"Failed to set up rules for simple box"
	).is_true()

	# Get generated indicators - THIS IS THE REGRESSION TEST
	var indicators: Array[RuleCheckIndicator] = manager.get_indicators()
	assert_array(indicators).append_failure_message(
		"REGRESSION: No indicators generated for simple box with collision layer 513. Preview collision objects: %d, Owner shapes: %d" % [preview_collision_objects.size(), owner_shapes.size()]
	).is_not_empty()
#endregion

#region Helper Functions
## Helper: Find all collision objects recursively
func _find_collision_objects(node: Node, output: Array[Node2D]) -> void:
	if node is CollisionObject2D or node is CollisionPolygon2D:
		output.append(node)
	for child in node.get_children():
		_find_collision_objects(child, output)

## Helper: Debug node structure recursively (for append_failure_message context)
func _debug_node_recursively(node: Node, depth: int) -> String:
	var indent: String = "  ".repeat(depth)
	var node_info: String = "%s%s (%s)" % [indent, node.name, node.get_class()]
	if node is CollisionObject2D:
		node_info += " [layer: %d]" % node.collision_layer
	var result := node_info
	for child in node.get_children():
		result += "\n" + _debug_node_recursively(child, depth + 1)
	return result
#endregion