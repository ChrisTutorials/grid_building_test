extends GdUnitTestSuite

## Focused integration test to ensure entering build mode with the Smithy placeable
## yields RuleCheckIndicators when a CollisionsCheckRule targeting layer 1 is applied.
## Relies on smithy.tscn collision_layer including layer 1 (bit 0) after patch (2561 value).

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _container: GBCompositionContainer
var building_system: BuildingSystem
var targeting_system: GridTargetingSystem
var positioner: Node2D
var tile_map_layer: TileMapLayer

func before_test():
	_container = BASE_CONTAINER.duplicate(true)
	# Basic tile map
	tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-4,5):
		for y in range(-4,5):
			tile_map_layer.set_cell(Vector2i(x,y),0,Vector2i(0,0))
	add_child(tile_map_layer)
	# Positioner
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	var targeting_state = _container.get_states().targeting
	targeting_state.set_map_objects(tile_map_layer, [tile_map_layer])
	targeting_state.positioner = positioner
	# Manipulation parent so manipulator exists for rule params consistency
	_container.get_states().manipulation.parent = positioner
	# Owner context (needed so BuildingState.get_placer() has a root)
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var mock_owner_node = auto_free(Node2D.new())
	mock_owner_node.name = "TestOwner"
	add_child(mock_owner_node)
	var gb_owner := GBOwner.new(mock_owner_node)
	auto_free(gb_owner)
	owner_context.set_owner(gb_owner)
	# Placed parent
	var placed_parent : Node2D = auto_free(Node2D.new())
	_container.get_states().building.placed_parent = placed_parent
	add_child(placed_parent)
	# Systems
	building_system = auto_free(BuildingSystem.new())
	add_child(building_system)
	building_system.resolve_gb_dependencies(_container)
	targeting_system = auto_free(GridTargetingSystem.new())
	add_child(targeting_system)
	targeting_system.resolve_gb_dependencies(_container)
	assert_array(building_system.get_dependency_issues()).is_empty()
	assert_array(targeting_system.get_dependency_issues()).is_empty()
	# Ensure placement manager exists (enter_build_mode path may lazily create)
	if _container.get_contexts().placement.get_manager() == null:
		var pm := PlacementManager.create_with_injection(_container)
		add_child(auto_free(pm))
	# Validate targeting state ready
	assert_array(_container.get_states().targeting.get_runtime_issues()).is_empty()

func test_smithy_generates_indicators_only_with_matching_rule_mask_when_ignoring_base():
	var smithy_placeable : Placeable = TestSceneLibrary.placeable_smithy
	assert_object(smithy_placeable).is_not_null()
	building_system.selected_placeable = smithy_placeable
	var entered := building_system.enter_build_mode(smithy_placeable)
	assert_bool(entered.is_successful()).is_true()
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).is_not_null()
	var manager := _container.get_contexts().placement.get_manager()
	assert_object(manager).is_not_null()
	# Re-run setup ignoring base rules with EMPTY placeable rules -> expect skip (no indicators)
	var manip_owner = _container.get_states().manipulation.get_manipulator()
	var params := RuleValidationParameters.new(manip_owner, preview, _container.get_states().targeting, _container.get_logger())
	var report_empty := manager.try_setup([], params, true)
	assert_bool(report_empty.is_successful()).is_true()
	assert_array(manager.get_indicators()).append_failure_message("Indicators should not exist when no TileCheckRules (base ignored)").is_empty()
	# Now add an explicit collisions rule overlapping smithy collision layer (bit 0) and verify indicators appear
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	var report := manager.try_setup([rule], params, true)
	assert_bool(report.is_successful()).append_failure_message("PlacementManager.try_setup failed with explicit collisions rule (ignore base): %s" % str(report.get_all_issues())).is_true()
	var indicators := manager.get_indicators()
	assert_array(indicators).append_failure_message("Expected indicators after adding explicit collisions rule").is_not_empty()
	# Sanity: at least one indicator atop center tile
	var map := _container.get_states().targeting.target_map
	var pos_tile := map.local_to_map(map.to_local(positioner.global_position))
	var any_same := false
	for ind in indicators:
		var ind_tile = map.local_to_map(map.to_local(ind.global_position))
		if ind_tile == pos_tile:
			any_same = true; break
	assert_bool(any_same).append_failure_message("No indicator aligned to center tile; indicators=%s" % [str(indicators)]).is_true()

func test_rule_layer_overlap_required_for_indicator_generation():
	var smithy_placeable : Placeable = TestSceneLibrary.placeable_smithy
	assert_object(smithy_placeable).is_not_null()
	building_system.selected_placeable = smithy_placeable
	var entered := building_system.enter_build_mode(smithy_placeable)
	assert_bool(entered.is_successful()).is_true()
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).is_not_null()
	var manager := _container.get_contexts().placement.get_manager()
	if manager == null:
		manager = PlacementManager.create_with_injection(_container)
		add_child(auto_free(manager))
	var manip_owner = _container.get_states().manipulation.get_manipulator()
	var targeting_state := _container.get_states().targeting
	var params := RuleValidationParameters.new(manip_owner, preview, targeting_state, _container.get_logger())
	# Non-overlapping rule (bit 20) ignoring base -> expect no indicators
	var rule_no_overlap := CollisionsCheckRule.new()
	rule_no_overlap.apply_to_objects_mask = 1 << 20
	rule_no_overlap.collision_mask = 1 << 20
	var report_no_overlap := manager.try_setup([rule_no_overlap], params, true)
	assert_bool(report_no_overlap.is_successful()).is_true()
	assert_array(manager.get_indicators()).append_failure_message("Expected 0 indicators when rule layer does not overlap smithy collision layers (ignore base)").is_empty()
	# Overlapping rule (bit 0) ignoring base -> expect indicators
	var rule_overlap := CollisionsCheckRule.new()
	rule_overlap.apply_to_objects_mask = 1 << 0
	rule_overlap.collision_mask = 1 << 0
	var report_overlap := manager.try_setup([rule_overlap], params, true)
	assert_bool(report_overlap.is_successful()).is_true()
	var indicators := manager.get_indicators()
	assert_array(indicators).append_failure_message("Expected indicators after applying overlapping layer rule (ignore base)").is_not_empty()
	for ind in indicators:
		assert_bool(ind.is_inside_tree()).append_failure_message("Indicator not inside tree: %s" % ind.name).is_true()
		assert_object(ind.get_parent()).append_failure_message("Indicator parent unexpected").is_equal(preview)
