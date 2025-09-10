## GdUnit TestSuite for IndicatorManager indicator creation
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")
 
# Minimal, parameterized, and double-factory-based IndicatorManager tests
var indicator_manager: IndicatorManager
var map_layer: TileMapLayer
var col_checking_rules: Array[TileCheckRule]
var global_snap_pos: Vector2
var offset_logo = load("uid://bqq7otaevtlqu")

# Access to indicator template and other test scenes; avoid name clash with global class_name
const TestSceneLibraryScene := preload("res://test/grid_building_test/scenes/test_scene_library.tscn")

var _positioner : Node2D
var _injector: GBInjectorSystem
var _container : GBCompositionContainer

func before_test():
	_container = TEST_CONTAINER.duplicate()
	_setup_targeting_state()
	_setup_indicator_manager()

func _setup_targeting_state():
	# Step 1: Set up the targeting state with its runtime dependencies (map objects and positioner).
	# This must be done first so that IndicatorManager receives a fully initialized targeting state.
	_injector = auto_free(GBInjectorSystem.create_with_injection(self, _container))
	add_child(_injector)
	map_layer = auto_free(TileMapLayer.new())
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16, 16)
	var targeting_state = _container.get_states().targeting
	var map_layers : Array[TileMapLayer] = [map_layer]
	targeting_state.set_map_objects(map_layer, map_layers)
	_positioner = Node2D.new()
	auto_free(_positioner)
	# GridTargetingState exposes 'positioner' as a property; assign directly instead of calling missing method
	targeting_state.positioner = _positioner

func _setup_indicator_manager():
	# Step 2: Create IndicatorManager with dependency injection.
	indicator_manager = auto_free(IndicatorManager.create_with_injection(_container, _positioner))
	# Avoid double-parenting; create_with_injection may already attach to provided parent
	if indicator_manager.get_parent() == null:
		add_child(indicator_manager)

	# Assert indicator template validity early  
	var indicator_template: PackedScene = _container.get_templates().rule_check_indicator
	var template_instance: Node = indicator_template.instantiate()
	(
		assert_bool(template_instance is RuleCheckIndicator)
		.append_failure_message("Indicator template root must be RuleCheckIndicator. Template=%s Root=%s" % [str(indicator_template), str(template_instance)])
		.is_true()
	)
	template_instance.queue_free()
	
	global_snap_pos = map_layer.map_to_local(Vector2i(0,0))
	col_checking_rules = RuleFilters.only_tile_check([CollisionsCheckRule.new()])
	(
		assert_int(col_checking_rules.size())
		.append_failure_message("Expected at least one TileCheckRule from RuleFilters.only_tile_check; rules=%s" % str(col_checking_rules))
		.is_greater(0)
	)

	# Validate targeting state readiness
	var targeting_state := _container.get_states().targeting
	var targeting_issues := targeting_state.get_runtime_issues()
	(
		assert_bool(targeting_issues.is_empty())
		.append_failure_message("Targeting state not ready. Issues=%s" % str(targeting_issues))
		.is_true()
	)

func after_test():
	if is_instance_valid(indicator_manager):
		indicator_manager.queue_free()
	indicator_manager = null

func after() -> void:
	assert_object(_injector).is_null()
	assert_object(indicator_manager).is_null()
	assert_object(map_layer).is_null()
	assert_object(_positioner).is_null()

## Should be handled by the GBInjectorSystem automatically
func test_indicator_manager_dependencies_initialized():
	# Test that the IndicatorManager can actually function instead of testing private properties
	# Create a test scene and verify indicators are generated
	var shape_scene = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos

	# Pre-assert the scene has at least one collision shape/polygon
	var collision_shape_count := _count_collision_shapes(shape_scene)
	(
		assert_int(collision_shape_count)
		.append_failure_message("Eclipse scene has no collision shapes; cannot generate indicators")
		.is_greater(0)
	)

	# Attempt physics body layer overlap prerequisite; don't hard fail if only raw shapes exist.
	var overlap_ok = _collision_layer_overlaps(shape_scene, col_checking_rules)
	if not overlap_ok:
		print("[TEST][indicator_manager] WARNING: No physics body layer overlap for eclipse_scene; proceeding (shape-only scene)")

	var indicators_report : IndicatorSetupReport = indicator_manager.setup_indicators(shape_scene, col_checking_rules)
	var indicators = indicators_report.indicators
	var summary = indicators_report.to_summary_string()
	
	# Assert that indicators were created (this tests the internal functionality without exposing private properties)
	(
		assert_int(indicators.size())
		.append_failure_message("No indicators generated for eclipse_scene. shapes=%d rules=%s summary=%s" % [collision_shape_count, str(col_checking_rules), summary])
		.is_greater(0)
	)
	
	# Test that the manager can get colliding indicators
	var colliding_indicators = indicator_manager.get_colliding_indicators()
	# Initially there should be no colliding indicators since we just set them up
	assert_int(colliding_indicators.size()).is_equal(0)

@warning_ignore("unused_parameter")
func test_indicator_count_for_shapes(scene_resource: PackedScene, expected: int, test_parameters := [
	[UnifiedTestFactory.create_test_eclipse_packed_scene(self), 31],  # Adjusted after RectangleShape2D size fix (extents->size reduced coverage)
	[offset_logo, 4]
]):
	var shape_scene = auto_free(scene_resource.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos

	var collision_shape_count := _count_collision_shapes(shape_scene)
	(
		assert_int(collision_shape_count)
		.append_failure_message("Test parameter scene lacks collision shapes; expected >0 for indicator generation")
		.is_greater(0)
	)
	var _overlap_ok = _collision_layer_overlaps(shape_scene, col_checking_rules)
	var report : IndicatorSetupReport = indicator_manager.setup_indicators(shape_scene, col_checking_rules)
	var indicators = report.indicators
	var summary = report.to_summary_string()
	(
		assert_int(indicators.size())
		.append_failure_message("Generated indicator count mismatch. expected=%d actual=%d shapes=%d scene=%s summary=%s" % [expected, indicators.size(), collision_shape_count, str(scene_resource), summary])
		.is_equal(expected)
	)

func test_indicator_positions_are_unique():
	var shape_scene = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var collision_shape_count := _count_collision_shapes(shape_scene)
	(
		assert_int(collision_shape_count)\
			.append_failure_message("No collision shapes in eclipse_scene for uniqueness test")\
			.is_greater(0)
	)
	var report : IndicatorSetupReport = indicator_manager.setup_indicators(shape_scene, col_checking_rules)
	var indicators = report.indicators
	var summary = report.to_summary_string()
	(
		assert_int(indicators.size())
		.append_failure_message("No indicators to test uniqueness. shapes=%d summary=%s" % [collision_shape_count, summary])
		.is_greater(0)
	)
	var positions = []
	for indicator in indicators:
		positions.append(indicator.global_position)
	# Remove duplicates manually
	var unique_positions = []
	for pos in positions:
		if not unique_positions.has(pos):
			unique_positions.append(pos)
	(
		assert_int(positions.size())
		.append_failure_message("Indicator positions not unique; total=%d unique=%d" % [positions.size(), unique_positions.size()])
		.is_equal(unique_positions.size())
	)

func test_no_indicators_for_empty_scene():
	var empty_node = auto_free(Node2D.new())
	add_child(empty_node)
	var report : IndicatorSetupReport = indicator_manager.setup_indicators(empty_node, col_checking_rules)
	var indicators = report.indicators
	var summary = report.to_summary_string()
	(
		assert_int(indicators.size())
		.append_failure_message("Indicators should be zero for empty scene but were %d summary=%s" % [indicators.size(), summary])
		.is_equal(0)
	)

@warning_ignore("unused_parameter")
func test_indicator_generation_distance(scene_resource: PackedScene, expected_distance: float, test_parameters := [
	[UnifiedTestFactory.create_test_eclipse_packed_scene(self), 16.0]
]):
	var shape_scene = auto_free(scene_resource.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var report : IndicatorSetupReport = indicator_manager.setup_indicators(shape_scene, col_checking_rules)
	var indicators = report.indicators
	var summary = report.to_summary_string()
	(
		assert_int(indicators.size())
		.append_failure_message("Need at least 2 indicators for distance test. actual=%d scene=%s summary=%s" % [indicators.size(), str(scene_resource), summary])
		.is_greater(1)
	)
	var indicator_0 = indicators[0]
	var indicator_1 = indicators[1]
	var distance_to = indicator_0.global_position.distance_to(indicator_1.global_position)
	(
		assert_float(distance_to)
		.append_failure_message("Indicator spacing mismatch. expected=%f actual=%f scene=%s" % [expected_distance, distance_to, str(scene_resource)])
		.is_equal(expected_distance)
	)

func test_indicators_are_freed_on_reset():
	var shape_scene = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var report : IndicatorSetupReport = indicator_manager.setup_indicators(shape_scene, col_checking_rules)
	var indicators = report.indicators
	var summary = report.to_summary_string()
	(
		assert_int(indicators.size())
		.append_failure_message("No indicators generated before reset; shapes=%d summary=%s" % [_count_collision_shapes(shape_scene), summary])
		.is_greater(0)
	)
	indicator_manager.tear_down()
	# After tear_down, call setup on empty to confirm no indicators remain
	var cleared := indicator_manager.get_colliding_indicators()
	(
		assert_int(cleared.size())
		.append_failure_message("Indicators not cleared after tear_down; remaining=%d" % cleared.size())
		.is_equal(0)
	)
	# Also check main indicator list is empty
	(
		assert_int(indicator_manager.get_indicators().size())
		.append_failure_message("indicator_manager.get_indicators() not empty after tear_down")
		.is_equal(0)
	)

# -------------------------
# Helper diagnostics
# -------------------------
func _count_collision_shapes(root: Node) -> int:
	var count := 0
	var stack : Array = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			if child is CollisionShape2D or child is CollisionPolygon2D:
				count += 1
	return count

func _assert_collision_layer_overlaps(root: Node, tile_rules: Array[TileCheckRule], scene_label: String):
	if tile_rules.is_empty():
		return
	var mask := tile_rules[0].apply_to_objects_mask
	var overlapping := false
	var body_layers : Array[String] = []
	var stack : Array = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			if child is PhysicsBody2D or child is Area2D:
				var layer_bits = child.collision_layer
				body_layers.append("%s(layer=%d)" % [child.get_class(), layer_bits])
				if (layer_bits & mask) != 0:
					overlapping = true
	(
		assert_bool(overlapping)
		.append_failure_message("No physics body with collision_layer overlapping TileCheckRule mask=%d in scene=%s bodies=%s" % [mask, scene_label, ", ".join(body_layers)])
		.is_true()
	)

# Non-asserting overlap check used for optional prerequisite logic.
func _collision_layer_overlaps(root: Node, tile_rules: Array[TileCheckRule]) -> bool:
	if tile_rules.is_empty():
		return false
	var mask := tile_rules[0].apply_to_objects_mask
	var stack : Array = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			if child is PhysicsBody2D or child is Area2D:
				if ((child as CollisionObject2D).collision_layer & mask) != 0:
					return true
	return false
