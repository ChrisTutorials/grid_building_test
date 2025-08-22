extends GdUnitTestSuite

# Regression test for simple box collision detection issue
# This test reproduces the specific failure where a RigidBody2D with collision layer 513
# should generate indicators but doesn't.

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var unoccupied_space: CollisionsCheckRule = load("uid://dw6l5ddiuak8b")
var _container: GBCompositionContainer
var building_system: BuildingSystem
var positioner: Node2D
var tile_map_layer: TileMapLayer

func before_test():
	_container = BASE_CONTAINER.duplicate(true)
	
	# Create 5x5 tile map around origin
	tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-3, 4):
		for y in range(-3, 4):
			tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	add_child(tile_map_layer)
	
	# Positioner
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	
	# Set up targeting state
	var targeting_state = _container.get_states().targeting
	targeting_state.set_map_objects(tile_map_layer, [tile_map_layer])
	targeting_state.positioner = positioner
	
	# Set up manipulation parent
	_container.get_states().manipulation.parent = positioner
	
	# Set up owner context
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var owner_node = auto_free(Node2D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	var gb_owner := GBOwner.new(owner_node)
	auto_free(gb_owner)
	owner_context.set_owner(gb_owner)
	
	# Set up placed parent
	var placed_parent: Node2D = auto_free(Node2D.new())
	_container.get_states().building.placed_parent = placed_parent
	add_child(placed_parent)
	
	# Create building system
	building_system = auto_free(BuildingSystem.new())
	add_child(building_system)
	building_system.resolve_gb_dependencies(_container)
	
	# Ensure placement manager exists
	if _container.get_contexts().placement.get_manager() == null:
		var pm := PlacementManager.create_with_injection(_container)
		add_child(auto_free(pm))

func test_rigid_body_with_collision_layer_513_generates_indicators():
	# Create a simple test scene with just a collision object
	var test_box = auto_free(RigidBody2D.new())
	test_box.name = "SimpleBox"
	test_box.collision_layer = 513  # Bits 0 and 9 (layers 1 and 10)
	
	# Add collision shape
	var shape = auto_free(CollisionShape2D.new())
	var rect = RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	test_box.add_child(shape)
	add_child(test_box)
	
	# CRITICAL: Position the test box at the positioner location for collision detection
	test_box.global_position = positioner.global_position

	# Verify the collision layer matches the unoccupied space rule
	var box_layer = test_box.collision_layer
	var unoccupied_mask = unoccupied_space.apply_to_objects_mask
	var box_layer_match = (box_layer & unoccupied_mask) != 0
	assert_bool(box_layer_match).append_failure_message(
		"Box collision_layer %d does not match unoccupied space check rule apply_to_objects_mask %d" % [box_layer, unoccupied_mask]
	).is_true()

	# Create a simple placeable
	var scene = PackedScene.new()
	scene.pack(test_box)
	var placeable = Placeable.new(scene, [unoccupied_space])
	placeable.display_name = &"Simple Box"

	# Enter build mode
	building_system.selected_placeable = placeable
	var entered = building_system.enter_build_mode(placeable)
	assert_bool(entered).append_failure_message(
		"Failed to enter build mode with simple box"
	).is_true()

	# Get the preview and placement manager
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).append_failure_message(
		"No preview generated for simple box. Placeable: %s, rules: %s" % [placeable, placeable.placement_rules]
	).is_not_null()

	# Verify preview contains collision objects
	var preview_collision_objects = []
	_find_collision_objects(preview, preview_collision_objects)
	assert_array(preview_collision_objects).append_failure_message(
		"Preview should contain collision objects"
	).is_not_empty()

	# Verify GBGeometryUtils can find collision shapes in preview
	var owner_shapes: Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(preview)
	assert_int(owner_shapes.size()).append_failure_message(
		"GBGeometryUtils should find collision owners in preview"
	).is_greater(0)

	var manager := _container.get_contexts().placement.get_manager()
	assert_object(manager).append_failure_message(
		"No placement manager available"
	).is_not_null()

	# Set up rule validation parameters (same as test)
	var manip_owner = _container.get_states().manipulation.get_manipulator()
	var params := RuleValidationParameters.new(manip_owner, preview, _container.get_states().targeting, _container.get_logger())

	# Set up rules
	var setup_success = manager.try_setup(placeable.placement_rules, params, false)
	assert_bool(setup_success).append_failure_message(
		"Failed to set up rules for simple box"
	).is_true()

	# Get generated indicators - THIS IS THE REGRESSION TEST
	var indicators = manager.get_indicators()
	assert_array(indicators).append_failure_message(
		"REGRESSION: No indicators generated for simple box with collision layer 513. Preview collision objects: %d, Owner shapes: %d" % [preview_collision_objects.size(), owner_shapes.size()]
	).is_not_empty()

## Helper: Find all collision objects recursively
func _find_collision_objects(node: Node, output: Array) -> void:
	if node is CollisionObject2D or node is CollisionPolygon2D:
		output.append(node)
	for child in node.get_children():
		_find_collision_objects(child, output)
