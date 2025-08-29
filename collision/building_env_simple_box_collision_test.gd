extends GdUnitTestSuite
# Simple test to validate rule setup with collision objects works

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var unoccupied_space : CollisionsCheckRule = load("uid://dw6l5ddiuak8b")
var be_on_buildable : CollisionsCheckRule = load("uid://d4l1gimbn05kb")

var _container: GBCompositionContainer
var _injector : GBInjectorSystem
var env : BuildingTestEnvironment

func before_test():
	env = load("uid://c4ujk08n8llv8").instantiate()
	add_child(env)
	auto_free(env)
	_container = env.get_container()
	assert_array(env.get_issues()).is_empty()

func test_simple_collision_object_generates_indicators():
	# Create a simple test scene with just a collision object
	# NOTE: Don't use auto_free for nodes that will be packed into PackedScene
	var test_box = RigidBody2D.new()
	test_box.name = "SimpleBox"
	test_box.collision_layer = 513  # Bits 0 and 9 (layers 0 and 9), matching UNOCCUPIED_RULE.apply_to_objects_mask
	# Add collision shape
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	test_box.add_child(shape)
	
	# CRITICAL: Set owner for PackedScene to include the collision shape
	shape.owner = test_box
	
	add_child(test_box)
	
	# CRITICAL: Position the test box at the positioner location for collision detection
	test_box.global_position = env.positioner.global_position

	# Assert collision layer is correct
	assert_int(test_box.collision_layer).append_failure_message(
		"Test box collision_layer should be 513 (bits 0 and 9), got %d" % [test_box.collision_layer]
	).is_equal(513)

	# Assert box collision layer matches unoccupied space check rule's apply_to_objects_mask
	var box_layer = test_box.collision_layer
	var unoccupied_mask = unoccupied_space.apply_to_objects_mask # Fail fast if property doesnt exist
	var box_layer_match = (box_layer & unoccupied_mask) != 0
	assert_bool(box_layer_match).append_failure_message(
		"Box collision_layer %d (%s) does not match unoccupied space check rule apply_to_objects_mask %d (%s)" % [box_layer, _bitmask_to_layers_str(box_layer), unoccupied_mask, _bitmask_to_layers_str(unoccupied_mask)]
	).is_true()

	# Create a simple placeable
	var scene = PackedScene.new()
	scene.pack(test_box)
	var placeable = Placeable.new(scene, [unoccupied_space])
	placeable.display_name = &"Simple Box"

	# Enter build mode
	var entered_report = env.building_system.enter_build_mode(placeable)
	assert_bool(entered_report.is_successful()).append_failure_message(
		"Failed to enter build mode with simple box: %s" % str(entered_report.get_all_issues())
	).is_true()

	# Get the preview and placement manager
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).append_failure_message(
		"No preview generated for simple box. Placeable: %s, rules: %s" % [placeable, str(placeable.placement_rules)]
	).is_not_null()

	# Check preview collision objects and layers
	var preview_collision_objects : Array[Node] = _find_collision_objects(preview)
	
	var preview_layers = []
	for obj in preview_collision_objects:
		# Direct access for collision layer
		preview_layers.append(int(obj.get_collision_layer()))
	var preview_layers_str = []
	for mask in preview_layers:
		preview_layers_str.append(_bitmask_to_layers_str(mask))
	assert_bool(preview_layers.has(513)).append_failure_message(
		"Preview collision objects missing expected layer 513 (bits 0+9). Found layers: %s" % [preview_layers_str]
	).is_true()

	# If BuildableCheck Area2D exists, assert its collision layer matches buildable rule
	var buildable_rule = null
	if Engine.has_singleton("ResourceLoader"):
		buildable_rule = load("res://demos/platformer/rules/must_be_on_buildable.tres")
	if buildable_rule != null and buildable_rule.apply_to_objects_mask != 0:
		var buildable_check = null
		for obj in preview_collision_objects:
			if obj is Area2D and obj.name == "BuildableCheck":
				buildable_check = obj
				break
		if buildable_check != null:
			var buildable_layer = buildable_check.collision_layer
			var buildable_mask = buildable_rule.apply_to_objects_mask
			var buildable_layer_match = (buildable_layer & buildable_mask) != 0
			assert_bool(buildable_layer_match).append_failure_message(
				"BuildableCheck Area2D collision_layer %d (%s) does not match buildable rule apply_to_objects_mask %d (%s)" % [buildable_layer, _bitmask_to_layers_str(buildable_layer), buildable_mask, _bitmask_to_layers_str(buildable_mask)]
			).is_true()

	assert_object(env.indicator_manager).append_failure_message(
		"No placement manager available"
	).is_not_null()

	# Set up rule validation parameters
	var manip_owner = _container.get_states().manipulation.get_manipulator()
	var params := RuleValidationParameters.new(manip_owner, preview, _container.get_states().targeting, _container.get_logger())

	# Set up rules
	var setup_report = env.indicator_manager.try_setup(placeable.placement_rules, params, false)
	assert_bool(setup_report.is_successful()).append_failure_message(
		"Failed to set up rules for simple box: %s" % str(setup_report.get_all_issues())
	).is_true()

	# Get generated indicators
	var indicators = env.indicator_manager.get_indicators()
	assert_array(indicators).append_failure_message(
		"No indicators generated for simple box with collision layer 513 (bits 0+9). Preview layers: %s, rules: %s" % [preview_layers_str, str(placeable.placement_rules)]
	).is_not_empty()

	# Should have at least 1 indicator
	assert_int(indicators.size()).append_failure_message(
		"Expected at least 1 indicator, got %d. Indicators: %s, Preview layers: %s" % [indicators.size(), str(indicators), preview_layers_str]
	).is_greater_equal(1)

	# The indicator should have the unoccupied rule
	var found_unoccupied_rule = false
	var indicator_debug_info = []
	for indicator in indicators:
		var rules = indicator.get_rules()
		indicator_debug_info.append("Indicator %s rules: %s" % [indicator, str(rules)])
		for rule in rules:
			if rule == unoccupied_space:
				found_unoccupied_rule = true
				break

	assert_bool(found_unoccupied_rule).append_failure_message(
		"No indicator found with the unoccupied space rule. Indicators: %s, Preview layers: %s, Placeable rules: %s" % [str(indicator_debug_info), preview_layers_str, str(placeable.placement_rules)]
	).is_true()

	# Extra: Assert at least one indicator has a rule with collision_mask 1 (bit 0)
	var found_layer0_rule = false
	for indicator in indicators:
		var rules = indicator.get_rules()
		for rule in rules:
			if rule.collision_mask == 1:
				found_layer0_rule = true
				break
	assert_bool(found_layer0_rule).append_failure_message(
		"No indicator found with a rule for collision_mask 1 (bit 0). Indicators: %s" % [str(indicator_debug_info)]
	).is_true()

## Helper: Convert bitmask to layer string (e.g. 513 -> 'bits 0+9')
func _bitmask_to_layers_str(mask: int) -> String:
	var bits = []
	for i in range(32):
		if mask & (1 << i):
			bits.append(str(i))
	return "bits " + "+".join(bits)

## Helper: Find all collision objects recursively
func _find_collision_objects(node: Node) -> Array[Node]:
	var collision_nodes : Array[Node] = []
	
	if node == null:
		return collision_nodes
	
	if node is CollisionObject2D or node is CollisionPolygon2D:
		collision_nodes.append(node)
		
	for child in node.get_children():
		collision_nodes.append_array(_find_collision_objects(child))
	
	return collision_nodes
