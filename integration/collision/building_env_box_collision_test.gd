extends GdUnitTestSuite
## Test suite for validating collision-based placement rules and indicator generation
##
## This suite tests the integration between collision objects, placement rules, and visual indicators
## in the building system. It ensures that collision detection rules properly generate visual feedback
## to users about valid/invalid placement locations based on collision layers and masks.
##
## Key scenarios tested:
## - Collision objects with specific layers generate appropriate indicators
## - Placement rules correctly evaluate collision state
## - Indicator manager properly creates and manages rule check indicators
## - Build mode integration with collision detection works end-to-end

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# Test constants for collision layers and object dimensions
const TEST_COLLISION_LAYER: int = 513  # Bits 0 and 9 (layers 0 and 9)
const TEST_BOX_SIZE: Vector2 = Vector2(16, 16)  # Standard tile size
const TEST_POSITION: Vector2 = Vector2(0, 0)  # Origin position for collision testing

var unoccupied_space : CollisionsCheckRule = CollisionsCheckRule.new()
var be_on_buildable : CollisionsCheckRule = load("uid://d4l1gimbn05kb")

var _container: GBCompositionContainer
var env : BuildingTestEnvironment
var _gts : GridTargetingState

#region Test Setup
func before_test() -> void:
	env = load("uid://c4ujk08n8llv8").instantiate()
	add_child(env)
	auto_free(env)
	_container = env.get_container()
	assert_array(env.get_issues()).is_empty()
	_gts = _container.get_states().targeting

	# Configure the test collision rule
	unoccupied_space.collision_mask = TEST_COLLISION_LAYER
	unoccupied_space.apply_to_objects_mask = TEST_COLLISION_LAYER

func after_test() -> void:
	# Clean up any remaining indicators and state
	if env and env.indicator_manager:
		env.indicator_manager.clear()

	# Reset targeting state
	if _gts:
		_gts.target = null
#endregion

#region Test Cases

## Test that collision objects are created with correct properties
func test_collision_object_creation() -> void:
	var test_box: RigidBody2D = _create_test_collision_box()

	# Assert collision layer is correct
	assert_int(test_box.collision_layer)\
		.append_failure_message("Test box collision_layer should be %d (%s), got %d" % [TEST_COLLISION_LAYER, _bitmask_to_layers_str(TEST_COLLISION_LAYER), test_box.collision_layer])\
		.is_equal(TEST_COLLISION_LAYER)

	# Assert collision shape properties
	var shape: CollisionShape2D = test_box.get_child(0)
	assert_object(shape).is_not_null()
	assert_object(shape.shape).is_not_null()
	if shape.shape is RectangleShape2D:
		assert_vector(shape.shape.size)\
			.append_failure_message("Collision shape size should be %s, got %s" % [TEST_BOX_SIZE, shape.shape.size])\
			.is_equal(TEST_BOX_SIZE)

## Test that build mode can be entered successfully with collision objects
func test_build_mode_entry() -> void:
	var test_box: RigidBody2D = _create_test_collision_box()
	var placeable: Placeable = _create_placeable_from_node(test_box, [unoccupied_space])

	# Enter build mode
	var entered_report: PlacementReport = env.building_system.enter_build_mode(placeable)
	assert_bool(entered_report.is_successful())\
		.append_failure_message("Failed to enter build mode: %s" % str(entered_report.get_issues()))\
		.is_true()

	# Verify preview was created
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview)\
		.append_failure_message("No preview generated for placeable")\
		.is_not_null()

## Test that indicators are generated for collision objects
func test_indicator_generation() -> void:
	var test_box: RigidBody2D = _create_test_collision_box()
	var placeable: Placeable = _create_placeable_from_node(test_box, [unoccupied_space])

	# Enter build mode and set up targeting
	env.building_system.enter_build_mode(placeable)
	var preview: Node2D = _container.get_states().building.preview
	_gts.target = preview

	# Set up rules and check indicators
	var setup_report: PlacementReport = env.indicator_manager.try_setup(placeable.placement_rules, _gts, false)
	assert_bool(setup_report.is_successful())\
		.append_failure_message("Failed to set up rules: %s" % str(setup_report.get_issues()))\
		.is_true()

	# Verify indicators were generated
	var indicators: Array[RuleCheckIndicator] = env.indicator_manager.get_indicators()
	assert_array(indicators)\
		.append_failure_message("No indicators generated for collision object")\
		.is_not_empty()

	assert_int(indicators.size())\
		.append_failure_message("Expected at least 1 indicator, got %d" % indicators.size())\
		.is_greater_equal(1)

## Test that generated indicators have correct collision rules
func test_indicator_rules() -> void:
	var test_box: RigidBody2D = _create_test_collision_box()
	var placeable: Placeable = _create_placeable_from_node(test_box, [unoccupied_space])

	# Enter build mode and set up targeting
	env.building_system.enter_build_mode(placeable)
	var preview: Node2D = _container.get_states().building.preview
	_gts.target = preview

	# Generate indicators
	env.indicator_manager.try_setup(placeable.placement_rules, _gts, false)
	var indicators: Array[RuleCheckIndicator] = env.indicator_manager.get_indicators()

	# Verify at least one indicator has the unoccupied space rule
	var found_unoccupied_rule: bool = false
	for indicator in indicators:
		var rules: Array[TileCheckRule] = indicator.get_rules()
		if rules.has(unoccupied_space):
			found_unoccupied_rule = true
			break

	assert_bool(found_unoccupied_rule)\
		.append_failure_message("No indicator found with the unoccupied space rule")\
		.is_true()

	# Verify at least one indicator has correct collision mask
	var found_correct_mask: bool = false
	for indicator in indicators:
		var rules: Array[TileCheckRule] = indicator.get_rules()
		for rule: TileCheckRule in rules:
			if rule is CollisionsCheckRule && rule.collision_mask == TEST_COLLISION_LAYER:
				found_correct_mask = true
				break
		if found_correct_mask:
			break

	assert_bool(found_correct_mask)\
		.append_failure_message("No indicator found with collision_mask %d" % TEST_COLLISION_LAYER)\
		.is_true()

#endregion

#region Helper Methods

## Create a test collision box with standard properties
func _create_test_collision_box() -> RigidBody2D:
	var test_box: RigidBody2D = RigidBody2D.new()
	test_box.name = "TestCollisionBox"
	test_box.collision_layer = TEST_COLLISION_LAYER

	# Add collision shape
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = TEST_BOX_SIZE
	shape.shape = rect
	test_box.add_child(shape)

	# Set owner for PackedScene and position
	shape.owner = test_box
	test_box.global_position = TEST_POSITION

	add_child(test_box)
	return test_box

## Create a Placeable from a Node with given rules
func _create_placeable_from_node(node: Node, rules: Array[TileCheckRule]) -> Placeable:
	var scene: PackedScene = PackedScene.new()
	var result: int = scene.pack(node)
	assert_int(result).is_zero()  # PACKED_SCENE_PACK_OK = 0

	var placement_rules: Array[PlacementRule] = []
	for rule in rules:
		placement_rules.append(rule as PlacementRule)

	var placeable: Placeable = Placeable.new(scene, placement_rules)
	placeable.display_name = &"Test Placeable"
	return placeable

## Helper: Convert bitmask to layer string (e.g. 513 -> 'bits 0+9')
func _bitmask_to_layers_str(mask: int) -> String:
	var bits: Array[String] = []
	for i in range(32):
		if mask & (1 << i):
			bits.append(str(i))
	return "bits " + "+".join(bits)

## Helper: Find all collision objects recursively
func _find_collision_objects(node: Node) -> Array[Node]:
	var collision_nodes: Array[Node] = []

	if node == null:
		return collision_nodes

	if node is CollisionObject2D or node is CollisionPolygon2D:
		collision_nodes.append(node)

	for child in node.get_children():
		collision_nodes.append_array(_find_collision_objects(child))

	return collision_nodes

#endregion
