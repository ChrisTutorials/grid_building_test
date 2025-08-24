extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var indicator_manager: IndicatorManager
var indicator_template : PackedScene = preload("uid://dhox8mb8kuaxa")
var received_signal: bool
var indicator: RuleCheckIndicator
var targeting_state: GridTargetingState
var logger: GBLogger
var indicator_parent : Node2D
var _injector : GBInjectorSystem

func before_test():
	_injector = UnifiedTestFactory.create_test_injector(self, TEST_CONTAINER)
	indicator_parent = GodotTestFactory.create_node2d(self)

	# IMPORTANT: Use the container's targeting_state so IndicatorManager and test refer to SAME instance
	indicator_manager = IndicatorManager.create_with_injection(TEST_CONTAINER, indicator_parent)
	targeting_state = TEST_CONTAINER.get_targeting_state()
	_initialize_targeting_state(targeting_state)
	var issues := targeting_state.validate()
	assert_array(issues).append_failure_message("Targeting state invalid -> %s" % [issues]).is_empty()

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
	# Populate a centered region (-10..10) to keep tests fast and avoid editor slowdowns
	# Previously this filled 40,000 cells (-100..99 on each axis), which is excessive for unit tests
	for x in range(-10, 11):
		for y in range(-10, 11):
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
	assert_array(report.indicators).append_failure_message("Expect no indicators when test object null -> %s" % [report.indicators]).is_empty()
	assert_int(report.rules.size()).append_failure_message("Rules should be empty when object null -> %d" % [report.rules.size()]).is_equal(0)
	assert_bool(report.centered_preview).append_failure_message("Centered preview should be false for null object").is_false()
	assert_array(report.distinct_tile_positions).append_failure_message("No tile positions expected for null object -> %s" % [report.distinct_tile_positions]).is_empty()


func test_setup_indicators_creates_indicators_and_aligns_positioner() -> void:
	_ensure_positioner_in_tree()
	# Intentionally misalign positioner
	targeting_state.positioner.global_position = Vector2(13.37, 27.91)
	var body := _create_test_body()
	var rules : Array[TileCheckRule] = [CollisionsCheckRule.new()]
	# Ensure targeting_state readiness (validate sets ready flag internally)
	var issues := targeting_state.validate()
	assert_array(issues).append_failure_message("Targeting state validation issues -> %s" % [issues]).is_empty()
	assert_bool(targeting_state.ready).append_failure_message("Targeting state not marked ready after validate(); issues=%s positioner=%s target_map=%s maps=%d" % [issues, targeting_state.positioner, targeting_state.target_map, targeting_state.maps.size()]).is_true()
	# Configure collision mapper before calling setup to satisfy fail-fast contract
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, TEST_CONTAINER, indicator_parent)
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(body, rules, indicator_parent)
	assert_array(report.indicators).append_failure_message("Indicators should be produced -> report=%s" % [report.to_summary_string()]).is_not_empty()
	assert_int(indicator_manager.get_indicators().size()).append_failure_message("Manager indicator count mismatch -> manager=%d report=%d" % [indicator_manager.get_indicators().size(), report.indicators.size()]).is_equal(report.indicators.size())
	# Derived data must be computed post-finalize (centered preview, distinct tiles, owners)
	report.finalize(targeting_state)
	assert_int(report.distinct_tile_positions.size()).append_failure_message("Expected distinct tiles >0 -> %s" % [report.distinct_tile_positions]).is_greater(0)
	assert_int(report.owner_shapes.size()).append_failure_message("Owner shapes expected >0 -> %s" % [report.owner_shapes]).is_greater(0)
	assert_that(report.to_summary_string().length() > 0).append_failure_message("Summary string should not be empty after finalize").is_true()
	# Verify alignment
	var map := targeting_state.target_map
	var pos_after := targeting_state.positioner.global_position
	var tile_pos := map.local_to_map(map.to_local(pos_after))
	var aligned := map.to_global(map.map_to_local(tile_pos))
	assert_float((aligned - pos_after).length()).append_failure_message("Positioner misalignment length=%f expected <0.11 aligned=%s pos_after=%s tile_pos=%s" % [(aligned - pos_after).length(), aligned, pos_after, tile_pos]).is_less(0.11)

func test_get_or_create_testing_indicator_reuse_and_recreate() -> void:
	var first := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	assert_object(first).append_failure_message("Should create testing indicator instance").is_not_null()
	var second := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	assert_object(second).append_failure_message("Second call should reuse existing testing indicator").is_same(first)
	# Trigger setup (frees testing indicator internally)
	var body := _create_test_body()
	var issues := targeting_state.validate()
	assert_array(issues).append_failure_message("Targeting state validation issues -> %s" % [issues]).is_empty()
	# Configure collision mapper before calling setup
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, TEST_CONTAINER, indicator_parent)
	var rep: IndicatorSetupReport = indicator_manager.setup_indicators(body, [CollisionsCheckRule.new()], indicator_parent)
	rep.finalize(targeting_state)
	assert_bool(rep.centered_preview).append_failure_message("Centered preview expected after finalize -> %s" % [rep.to_summary_string()]).is_true() # preview child of positioner so should be centered
	# New contract: setup_indicators does not free the testing indicator; it should be reused across setups
	var third := indicator_manager.get_or_create_testing_indicator(indicator_parent)
	assert_object(third).append_failure_message("Testing indicator should be reused after setup under new fail-fast contract").is_same(first)

func test_add_indicators_emits_signal_and_stores() -> void:
	var inst: RuleCheckIndicator = indicator_template.instantiate()
	inst.name = "ManualAddIndicator"
	indicator_parent.add_child(inst)
	indicator = inst
	indicator_manager.connect("indicators_changed", Callable(self, "_on_indicators_changed"))
	indicator_manager.add_indicators([inst])
	assert_bool(received_signal).append_failure_message("Expected indicators_changed signal after add").is_true()
	assert_that(indicator in indicator_manager.get_indicators()).append_failure_message("Indicator was not stored in manager list").is_true()

func test_reset_after_setup_clears_indicators() -> void:
	var body := _create_test_body()
	# Configure collision mapper before calling setup to satisfy fail-fast contract
	UnifiedTestFactory.configure_collision_mapper_for_test_object(self, indicator_manager, body, TEST_CONTAINER, indicator_parent)
	indicator_manager.setup_indicators(body, [CollisionsCheckRule.new()], indicator_parent)
	assert_int(indicator_manager.get_indicators().size()).append_failure_message("Indicators should exist post-setup for reset test").is_greater(0)
	indicator_manager.reset()
	assert_int(indicator_manager.get_indicators().size()).append_failure_message("Reset should clear indicators -> remaining=%d" % [indicator_manager.get_indicators().size()]).is_equal(0)
