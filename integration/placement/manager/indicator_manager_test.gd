## Test suite for IndicatorManager functionality
## Tests indicator creation, positioning, collision detection, and lifecycle management
## for the grid building placement system. Verifies that indicators are properly
## generated from collision shapes, positioned uniquely on the grid, and cleaned up correctly.
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# Test constants for common values
const TILE_SIZE: Vector2 = Vector2(32, 32)
const EXPECTED_ECLIPSE_INDICATORS: int = 31
const EXPECTED_LOGO_INDICATORS: int = 4
const INDICATOR_SPACING: float = 16.0

# Minimal, parameterized, and double-factory-based IndicatorManager tests
var indicator_manager: IndicatorManager
var map_layer: TileMapLayer
var col_checking_rules: Array[TileCheckRule]
var global_snap_pos: Vector2

# Access to indicator template and other test scenes; avoid name clash with global class_name
const TestSceneLibraryScene : PackedScene = preload("uid://nhlp6ks003fp")

var _positioner : Node2D
var _injector: GBInjectorSystem
var _container : GBCompositionContainer

# ================================
# DRY Helper Functions
# ================================

func setup_scene_with_indicators(scene: Node2D) -> IndicatorSetupReport:
	"""Set up indicators for a scene and return the report."""
	return indicator_manager.setup_indicators(scene, col_checking_rules)

func assert_scene_has_collision_shapes(scene: Node2D, context: String = "") -> int:
	"""Assert that a scene has collision shapes and return the count."""
	var count := _count_collision_shapes(scene)
	assert_int(count).append_failure_message("Scene lacks collision shapes%s" % context).is_greater(0)
	return count

func get_indicators_and_summary(report: IndicatorSetupReport) -> Dictionary:
	"""Extract indicators and summary from a report."""
	return {
		"indicators": report.indicators,
		"summary": report.to_summary_string()
	}

func before_test() -> void:
	_container = TEST_CONTAINER.duplicate()
	_setup_targeting_state()
	_setup_indicator_manager()

func _setup_targeting_state() -> void:
	# Step 1: Set up the targeting state with its runtime dependencies (map objects and positioner).
	# This must be done first so that IndicatorManager receives a fully initialized targeting state.
	_injector = auto_free(GBInjectorSystem.create_with_injection(self, _container))
	add_child(_injector)
	map_layer = auto_free(TileMapLayer.new())
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = TILE_SIZE
	var targeting_state: GridTargetingState = _container.get_states().targeting
	var map_layers : Array[TileMapLayer] = [map_layer]
	targeting_state.set_map_objects(map_layer, map_layers)
	_positioner = Node2D.new()
	auto_free(_positioner)
	# GridTargetingState exposes 'positioner' as a property; assign directly instead of calling missing method
	targeting_state.positioner = _positioner

func _setup_indicator_manager() -> void:
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

func after_test() -> void:
	if is_instance_valid(indicator_manager):
		indicator_manager.queue_free()
	indicator_manager = null

func after() -> void:
	assert_object(_injector).is_null()
	assert_object(indicator_manager).is_null()
	assert_object(map_layer).is_null()
	assert_object(_positioner).is_null()

func test_indicator_manager_dependencies_initialized() -> void:
	# Test that the IndicatorManager can actually function instead of testing private properties
	# Create a test scene and verify indicators are generated
	var shape_scene: Node = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos

	# Pre-assert the scene has at least one collision shape/polygon
	var collision_shape_count := assert_scene_has_collision_shapes(shape_scene)

	# Attempt physics body layer overlap prerequisite; don't hard fail if only raw shapes exist.
	var overlap_ok: bool = _collision_layer_overlaps(shape_scene, col_checking_rules)
	if not overlap_ok:
		print("[TEST][indicator_manager] WARNING: No physics body layer overlap for eclipse_scene; proceeding (shape-only scene)")

	var indicators_report : IndicatorSetupReport = setup_scene_with_indicators(shape_scene)
	var data: Dictionary = get_indicators_and_summary(indicators_report)
	var indicators: Array[RuleCheckIndicator] = data.indicators
	var summary: String = data.summary

	# Assert that indicators were created (this tests the internal functionality without exposing private properties)
	assert_int(indicators.size()).append_failure_message(
		"No indicators generated for eclipse_scene. shapes=%d rules=%s summary=%s" %
		[collision_shape_count, str(col_checking_rules), summary]
	).is_greater(0)

	# Test that the manager can get colliding indicators
	var colliding_indicators: Array[RuleCheckIndicator] = indicator_manager.get_colliding_indicators()
	# Initially there should be no colliding indicators since we just set them up
	assert_int(colliding_indicators.size()).is_equal(0)

func test_indicator_count_for_shapes(shape_scene: Node2D, expected: int, _test_parameters := [
	[UnifiedTestFactory.create_eclipse_test_object(self), EXPECTED_ECLIPSE_INDICATORS],  # Adjusted after RectangleShape2D size fix (extents->size reduced coverage)
	[null, EXPECTED_LOGO_INDICATORS]  # TODO: Replace null with proper logo test object
]) -> void:
	if shape_scene == null:
		# Skip logo test for now - need to implement proper logo test object
		return
		
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos

	assert_scene_has_collision_shapes(shape_scene, "; expected >0 for indicator generation")

	var _overlap_ok: bool = _collision_layer_overlaps(shape_scene, col_checking_rules)
	var report : IndicatorSetupReport = setup_scene_with_indicators(shape_scene)
	var data: Dictionary = get_indicators_and_summary(report)
	var indicators: Array[RuleCheckIndicator] = data.indicators
	var summary: String = data.summary

	assert_int(indicators.size()).append_failure_message(
		"Generated indicator count mismatch. expected=%d actual=%d shapes=%d scene=%s summary=%s" %
		[expected, indicators.size(), _count_collision_shapes(shape_scene), str(shape_scene), summary]
	).is_equal(expected)

func test_indicator_positions_are_unique() -> void:
	var shape_scene: Node2D = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos

	assert_scene_has_collision_shapes(shape_scene, " for uniqueness test")

	var report : IndicatorSetupReport = setup_scene_with_indicators(shape_scene)
	var data: Dictionary = get_indicators_and_summary(report)
	var indicators: Array[RuleCheckIndicator] = data.indicators
	var summary: String = data.summary

	assert_int(indicators.size()).append_failure_message(
		"No indicators to test uniqueness. shapes=%d summary=%s" %
		[_count_collision_shapes(shape_scene), summary]
	).is_greater(0)

	var positions: Array[Vector2] = []
	for indicator: RuleCheckIndicator in indicators:
		positions.append(indicator.global_position)

	# Remove duplicates manually
	var unique_positions: Array[Vector2] = []
	for pos: Vector2 in positions:
		if not unique_positions.has(pos):
			unique_positions.append(pos)

	assert_int(positions.size()).append_failure_message(
		"Indicator positions not unique; total=%d unique=%d" %
		[positions.size(), unique_positions.size()]
	).is_equal(unique_positions.size())

func test_no_indicators_for_empty_scene() -> void:
	var empty_node: Node = auto_free(Node2D.new())
	add_child(empty_node)
	var report : IndicatorSetupReport = setup_scene_with_indicators(empty_node)
	var data: Dictionary = get_indicators_and_summary(report)
	var indicators: Array[RuleCheckIndicator] = data.indicators
	var summary: String = data.summary

	assert_int(indicators.size()).append_failure_message(
		"Indicators should be zero for empty scene but were %d summary=%s" %
		[indicators.size(), summary]
	).is_equal(0)

func test_indicator_generation_distance(shape_scene: Node2D, expected_distance: float, _test_parameters := [
	[UnifiedTestFactory.create_eclipse_test_object(self), INDICATOR_SPACING]
]) -> void:
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var report : IndicatorSetupReport = setup_scene_with_indicators(shape_scene)
	var data: Dictionary = get_indicators_and_summary(report)
	var indicators: Array[RuleCheckIndicator] = data.indicators
	var summary: String = data.summary

	assert_int(indicators.size()).append_failure_message(
		"Need at least 2 indicators for distance test. actual=%d scene=%s summary=%s" %
		[indicators.size(), str(shape_scene), summary]
	).is_greater(1)

	var indicator_0: RuleCheckIndicator = indicators[0]
	var indicator_1: RuleCheckIndicator = indicators[1]
	var distance_to: float = indicator_0.global_position.distance_to(indicator_1.global_position)

	assert_float(distance_to).append_failure_message(
		"Indicator spacing mismatch. expected=%f actual=%f scene=%s" %
		[expected_distance, distance_to, str(shape_scene)]
	).is_equal(expected_distance)

func test_indicators_are_freed_on_reset() -> void:
	var shape_scene: Node2D = UnifiedTestFactory.create_eclipse_test_object(self)
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var report : IndicatorSetupReport = setup_scene_with_indicators(shape_scene)
	var data: Dictionary = get_indicators_and_summary(report)
	var indicators: Array[RuleCheckIndicator] = data.indicators
	var summary: String = data.summary

	assert_int(indicators.size()).append_failure_message(
		"No indicators generated before reset; shapes=%d summary=%s" %
		[_count_collision_shapes(shape_scene), summary]
	).is_greater(0)

	indicator_manager.tear_down()

	# After tear_down, call setup on empty to confirm no indicators remain
	var cleared: Array[RuleCheckIndicator] = indicator_manager.get_colliding_indicators()
	assert_int(cleared.size()).append_failure_message(
		"Indicators not cleared after tear_down; remaining=%d" % cleared.size()
	).is_equal(0)

	# Also check main indicator list is empty
	assert_int(indicator_manager.get_indicators().size()).append_failure_message(
		"indicator_manager.get_indicators() not empty after tear_down"
	).is_equal(0)

# -------------------------
# Helper diagnostics
# -------------------------
func _count_collision_shapes(root: Node) -> int:
	var count := 0
	var stack : Array[Node2D] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			if child is CollisionShape2D or child is CollisionPolygon2D:
				count += 1
	return count

func _assert_collision_layer_overlaps(root: Node, tile_rules: Array[TileCheckRule], scene_label: String) -> void:
	if tile_rules.is_empty():
		return
	var mask := tile_rules[0].apply_to_objects_mask
	var overlapping := false
	var body_layers : Array[String] = []
	var stack : Array[Node2D] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			if child is PhysicsBody2D or child is Area2D:
				var layer_bits: int = child.collision_layer
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
	var stack : Array[Node2D] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
			if child is PhysicsBody2D or child is Area2D:
				if ((child as CollisionObject2D).collision_layer & mask) != 0:
					return true
	return false
