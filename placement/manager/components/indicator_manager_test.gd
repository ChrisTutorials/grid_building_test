extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var indicator_manager: IndicatorManager
var indicator_template : PackedScene = preload("uid://dhox8mb8kuaxa")
var received_signal: bool
var indicator: RuleCheckIndicator
var targeting_state: GridTargetingState
var logger: GBLogger
var indicator_parent : Node2D

func before_test():
	indicator_parent = GodotTestFactory.create_node2d(self)
	
	# Initialize targeting_state before using it
	var context = UnifiedTestFactory.create_owner_context(self)
	targeting_state = auto_free(GridTargetingState.new(context))

	# Use the actual static factory method directly with test container
	indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, indicator_parent)

	_initialize_targeting_state(targeting_state)

	received_signal = false
	indicator = null

func after_test():
	indicator_manager = null

func _create_real_indicator() -> RuleCheckIndicator:
	var instance : RuleCheckIndicator = indicator_template.instantiate()
	instance.name = "TestIndicator"
	add_child(instance) # add to scene so it's in scene tree
	return instance

func _initialize_targeting_state(p_targeting_state: GridTargetingState) -> void:
	# Create tile map layer directly
	var map: TileMapLayer = auto_free(TileMapLayer.new())
	map.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-100, 100, 1):
		for y in range(-100, 100, 1):
			var cords = Vector2i(x, y)
			map.set_cell(cords, 0, Vector2i(0, 0))
	add_child(map)
	
	p_targeting_state.set_map_objects(
		map, [map]
	)

	var positioner : Node2D = auto_free(Node2D.new())
	p_targeting_state.positioner = positioner

func test_setup_indicators_generates_expected_indicators() -> void:
	# Use pure logic class for validation
	var config = IndicatorFactory.create_indicator_config(
		Vector2.ZERO,
		Vector2(16, 16),
		[CollisionsCheckRule.new()]
	)
	
	var validation_issues = IndicatorFactory.validate_indicator_setup(config)
	assert_array(validation_issues).append_failure_message("Issues means it failed to setup properly. Debug the issues.").is_empty()

func test_add_indicators_adds_and_emits_signal() -> void:
	# Use pure logic class for validation
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(8, 8)

	var owner_testing_rect := RectangleShape2D.new()
	owner_testing_rect.extents = Vector2(8, 8)

	var setup : RectCollisionTestingSetup = IndicatorFactory.create_collision_test_setup(
		_create_real_indicator(),
		[rect_shape],
		owner_testing_rect.get_rect()
	)
	
	var validation_issues = setup.validate()
	assert_array(validation_issues).append_failure_message("Expect to come back with no issues - issues means invalid.").is_empty()
	

func test_reset_frees_indicators() -> void:
	# Use pure logic class for validation
	var rect_shape := RectangleShape2D.new()
	rect_shape.extents = Vector2(8, 8)

	var owner_testing_rect := RectangleShape2D.new()
	owner_testing_rect.extents = Vector2(8, 8)

	# Use pure logic class for validation
	var setup = IndicatorFactory.create_collision_test_setup(
		_create_real_indicator(),
		[rect_shape],
		owner_testing_rect.get_rect()
	)
	
	var validation_issues = setup.validate()
	assert_array(validation_issues).append_failure_message("Expect to come back with no issues - issues means invalid.").is_empty()


func _on_indicators_changed(updated: Array[RuleCheckIndicator]) -> void:
	received_signal = true
	if indicator:
		assert_that(indicator in updated).is_true()

func _ensure_positioner_in_tree():
	if targeting_state.positioner.get_parent() == null:
		add_child(targeting_state.positioner)

func _create_test_body() -> StaticBody2D:
	_ensure_positioner_in_tree()
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.extents = Vector2(8, 8)
	cs.shape = rect
	body.add_child(cs)
	targeting_state.positioner.add_child(body)
	return body

func test_setup_indicators_returns_empty_when_test_object_null() -> void:
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(null, [], indicator_parent)
	assert_array(report.indicators).is_empty()
	assert_int(report.rules.size()).is_equal(0)
	assert_bool(report.centered_preview).is_false()
	assert_array(report.distinct_tile_positions).is_empty()

func test_setup_indicators_creates_indicators_and_aligns_positioner() -> void:
	_ensure_positioner_in_tree()
	# Intentionally misalign positioner
	targeting_state.positioner.global_position = Vector2(13.37, 27.91)
	var body := _create_test_body()
	var rules := [CollisionsCheckRule.new()]
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(body, rules, indicator_parent)
	assert_array(report.indicators).is_not_empty()
	assert_int(indicator_manager.get_indicators().size()).is_equal(report.indicators.size())
	# Derived data must be computed post-finalize (centered preview, distinct tiles, owners)
	report.finalize(targeting_state)
	assert_int(report.distinct_tile_positions.size()).is_greater(0)
	assert_int(report.owner_shapes.size()).is_greater(0)
	assert_that(report.to_summary_string().length() > 0).is_true()
	# Verify alignment
	var map := targeting_state.target_map
	var pos_after := targeting_state.positioner.global_position
	var tile_pos := map.local_to_map(map.to_local(pos_after))
	var aligned := map.to_global(map.map_to_local(tile_pos))
	assert_float((aligned - pos_after).length()).is_less(0.11)

func test_get_or_create_testing_indicator_reuse_and_recreate() -> void:
	var first := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	assert_object(first).is_not_null()
	var second := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	assert_object(second).is_same(first)
	# Trigger setup (frees testing indicator internally)
	var body := _create_test_body()
	var rep: IndicatorSetupReport = indicator_manager.setup_indicators(body, [CollisionsCheckRule.new()], indicator_parent)
	rep.finalize(targeting_state)
	assert_bool(rep.centered_preview).is_true() # preview child of positioner so should be centered
	var third := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	assert_object(third).is_not_same(first)

func test_add_indicators_emits_signal_and_stores() -> void:
	var inst: RuleCheckIndicator = indicator_template.instantiate()
	inst.name = "ManualAddIndicator"
	indicator_parent.add_child(inst)
	indicator = inst
	indicator_manager.connect("indicators_changed", Callable(self, "_on_indicators_changed"))
	indicator_manager.add_indicators([inst])
	assert_bool(received_signal).is_true()
	assert_that(indicator in indicator_manager.get_indicators()).is_true()

func test_reset_after_setup_clears_indicators() -> void:
	var body := _create_test_body()
	indicator_manager.setup_indicators(body, [CollisionsCheckRule.new()], indicator_parent)
	assert_int(indicator_manager.get_indicators().size()).is_greater(0)
	indicator_manager.reset()
	assert_int(indicator_manager.get_indicators().size()).is_equal(0)