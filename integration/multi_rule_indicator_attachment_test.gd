extends GdUnitTestSuite

# Verifies that multiple TileCheckRules matching the SAME collision layer bits
# produce a single indicator per covered tile, with both rules attached instead
# of duplicating indicators.

const BASE_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _container: GBCompositionContainer
var building_system: BuildingSystem
var positioner: Node2D
var tile_map_layer: TileMapLayer

func before_test():
	_container = BASE_CONTAINER.duplicate(true)
	# Basic tile map 5x5 around origin
	tile_map_layer = auto_free(TileMapLayer.new())
	tile_map_layer.tile_set = load("uid://d11t2vm1pby6y")
	for x in range(-3,4):
		for y in range(-3,4):
			tile_map_layer.set_cell(Vector2i(x,y),0,Vector2i(0,0))
	add_child(tile_map_layer)
	# Positioner
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	var targeting_state = _container.get_states().targeting
	targeting_state.set_map_objects(tile_map_layer, [tile_map_layer])
	targeting_state.positioner = positioner
	# Manipulation parent
	_container.get_states().manipulation.parent = positioner
	# Owner context
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var owner_node = auto_free(Node2D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	var gb_owner := GBOwner.new(owner_node)
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
	assert_array(building_system.get_dependency_issues()).is_empty()
	# Ensure placement manager exists
	if _container.get_contexts().placement.get_manager() == null:
		var pm := PlacementManager.create_with_injection(_container)
		add_child(auto_free(pm))
	assert_array(_container.get_states().targeting.validate()).is_empty()

func test_multiple_matching_rules_attach_to_single_indicator_instances():
	var smithy_placeable : Placeable = TestSceneLibrary.placeable_smithy
	assert_object(smithy_placeable).is_not_null()
	building_system.selected_placeable = smithy_placeable
	var entered := building_system.enter_build_mode(smithy_placeable)
	assert_bool(entered).is_true()
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).is_not_null()
	var manager := _container.get_contexts().placement.get_manager()
	assert_object(manager).is_not_null()
	var manip_owner = _container.get_states().manipulation.get_manipulator()
	var params := RuleValidationParameters.new(manip_owner, preview, _container.get_states().targeting, _container.get_logger())
	# Two rules targeting the same collision layer bit (0). Distinguish via visual_priority.
	var rule_a := CollisionsCheckRule.new()
	rule_a.apply_to_objects_mask = 1 << 0
	rule_a.collision_mask = 1 << 0
	rule_a.visual_priority = 1
	var rule_b := CollisionsCheckRule.new()
	rule_b.apply_to_objects_mask = 1 << 0
	rule_b.collision_mask = 1 << 0
	rule_b.visual_priority = 2
	var ok := manager.try_setup([rule_a, rule_b], params, true) # ignore base to isolate
	assert_bool(ok).is_true()
	var indicators := manager.get_indicators()
	assert_array(indicators).append_failure_message("Expected indicators to be generated for overlapping rules").is_not_empty()
	# Every indicator should have BOTH rules in its rule list (order not guaranteed).
	for ind in indicators:
		var attached_rules = ind.get_rules() if ind.has_method("get_rules") else ind.rules if ind.has_property("rules") else []
		assert_int(attached_rules.size()).append_failure_message("Indicator %s missing one of the two rules" % ind.name).is_greater_equal(2)
		# Check presence by identity
		var found_a := false
		var found_b := false
		for r in attached_rules:
			if r == rule_a: found_a = true
			elif r == rule_b: found_b = true
		assert_bool(found_a).append_failure_message("Indicator %s missing rule_a" % ind.name).is_true()
		assert_bool(found_b).append_failure_message("Indicator %s missing rule_b" % ind.name).is_true()
	# Ensure there are NO duplicate indicators for the same tile position (by name prefix Offset(x,y)).
	var seen_offsets := {}
	for ind in indicators:
		var name_parts = ind.name.split("_")
		if name_parts.size() > 0:
			var offset_part = name_parts[0] # e.g., "Offset(1,2)"
			assert_bool(not seen_offsets.has(offset_part)).append_failure_message("Duplicate indicator for tile: %s" % offset_part).is_true()
			seen_offsets[offset_part] = true
