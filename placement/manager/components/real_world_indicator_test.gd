extends GdUnitTestSuite

## Tests indicator positioning using the exact same setup as the real system

var placement_manager: PlacementManager
var targeting_state: GridTargetingState
var _container : GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")
var _injector: GBInjectorSystem
var positioner: Node2D
var _logger: GBLogger
var _preview_ref: Node2D


func before_test():
	# Create the exact same setup as the real system would use
	# Use preloaded test container with proper config/resources
	_injector = auto_free(GBInjectorSystem.create_with_injection(_container))
	add_child(_injector)
	targeting_state = _container.get_states().targeting

	# Create tile map layer using factory (handles tile set & population)
	var tile_map_layer: TileMapLayer = GodotTestFactory.create_tile_map_layer(self, 40)
	var positioner_node: Node2D = auto_free(Node2D.new())
	positioner = positioner_node
	targeting_state.positioner = positioner_node
	targeting_state.set_map_objects(tile_map_layer, [tile_map_layer])

	_logger = GBLogger.new(GBDebugSettings.new())

 	# Skip full BuildingSystem to avoid deep dependency graph; we'll exercise PlacementManager directly

	# Initialize a dedicated PlacementManager mirroring placement_manager_test.gd
	placement_manager = auto_free(PlacementManager.new())
	add_child(placement_manager)
	var placement_context := PlacementContext.new(); auto_free(placement_context)
	# Load primary indicator template and validate root type; fallback to alternate UID if needed
	var indicator_template := TestSceneLibrary.indicator
	var fallback_indicator_template := TestSceneLibrary.indicator_min
	var chosen_template := indicator_template
	if chosen_template:
		var temp_instance = chosen_template.instantiate()
		if not (temp_instance is RuleCheckIndicator):
			# Try fallback
			if fallback_indicator_template:
				var fallback_instance = fallback_indicator_template.instantiate()
				if fallback_instance is RuleCheckIndicator:
					chosen_template = fallback_indicator_template
					fallback_instance.queue_free()
				else:
					fallback_instance.queue_free()
			temp_instance.queue_free()
	else:
		chosen_template = fallback_indicator_template
	indicator_template = chosen_template
	var rules: Array[PlacementRule] = []
	var messages := GBMessages.new()
	placement_manager.initialize(placement_context, indicator_template, targeting_state, _logger, rules, messages)
	# Assert template validity (public side-effect: ability to create a RuleCheckIndicator via instantiate)
	var validate_instance = indicator_template.instantiate()
	assert_bool(validate_instance is RuleCheckIndicator).append_failure_message("Indicator template root is not RuleCheckIndicator. Template=%s" % [str(indicator_template)]).is_true()
	validate_instance.queue_free()

func _instantiate_preview(packed_scene: PackedScene) -> Node2D:
	if packed_scene:
		return packed_scene.instantiate()
	# Synthetic preview with one collision shape
	var preview := Node2D.new()
	var body := StaticBody2D.new()
	body.collision_layer = 1 # Ensure default layer so TileCheckRule mask (default 1) matches
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32,32)
	shape_node.shape = rect
	body.add_child(shape_node)
	preview.add_child(body)
	return preview


## EXPECTATION / PURPOSE
## This test exercises indicator generation and spatial positioning using the real PlacementManager pipeline
## without bootstrapping the entire BuildingSystem dependency graph.
##
## Setup:
##  - A targeting state with a populated TileMapLayer (factory-created predictable 40x40 grid)
##  - A positioner Node2D assigned to the targeting state
##  - A PlacementManager (created directly if container didn't provide one)
##  - A real placeable resource if available via TestSceneLibrary; otherwise a synthetic Placeable with a
##    simple PackedScene containing a StaticBody2D + CollisionShape2D rectangle (32x32) is created.
##
## Actions:
##  - Instantiate a preview for the (real or synthetic) placeable and parent it under the positioner
##  - Invoke placement_manager.try_setup with either the placeable's own placement_rules or a fallback
##    simple TileCheckRule to force indicator creation
##
## Assertions / Success Criteria:
##  1. At least one indicator is generated (indicators.size() > 0) - requires >=1 TileCheckRule.
##  2. Preview (or its descendants) contains >=1 CollisionShape2D or CollisionPolygon2D.
##  3. At least one ancestor physics body (StaticBody2D/Area2D/RigidBody2D/CharacterBody2D) of those shapes has a collision_layer bit
##     overlapping the TileCheckRule.apply_to_objects_mask (defaults: layer=1, mask=1).
##  4. Among the sampled first N (<=5) indicators, global positions are unique (no duplicate clustering).
##  5. Each sampled indicator lies within one tile-size bounds of its computed tile origin (basic grid alignment).
##  6. Sampled indicators mutually differ (redundant safeguard vs uniqueness map).
##  7. The average (centroid) of all indicator positions is within 256 world units of the preview's center
##     (ensures indicators relate spatially to the preview, not scattered far away).
##  8. Targeting state validation reports no issues (positioner and target_map assigned, maps non-empty).
## Notes:
##  - Indicators only generate if there is at least one TileCheckRule present.
##  - Collision layer/mask alignment is a hard precondition: without a matching layer->mask bitwise AND, no indicators spawn.
##
## Rationale:
##  This codifies a "real world" integration slice focused on indicator placement semantics while staying
##  resilient to missing higher-level systems. The explicit spread + proximity constraints give early signal
##  if collision-to-indicator mapping regresses, offsets break, or manager setup silently fails.
func test_real_world_indicator_positioning():
	# Try to acquire a real placeable; if unavailable create synthetic preview directly
	var preview: Node2D
	var used_real_placeable := false
	if Engine.has_singleton("TestSceneLibrary"):
		var tsl = Engine.get_singleton("TestSceneLibrary")
		if tsl and tsl.has_variable("placeable_eclipse") and tsl.placeable_eclipse and tsl.placeable_eclipse.packed_scene:
			preview = _instantiate_preview(tsl.placeable_eclipse.packed_scene)
			used_real_placeable = true
	if preview == null:
		# Direct synthetic preview with collision body & shape
		preview = Node2D.new()
		var static_body_for_preview := StaticBody2D.new(); static_body_for_preview.collision_layer = 1
		var primary_collision_shape := CollisionShape2D.new(); var primary_rectangle_shape := RectangleShape2D.new(); primary_rectangle_shape.size = Vector2(32,32)
		primary_collision_shape.shape = primary_rectangle_shape; static_body_for_preview.add_child(primary_collision_shape); preview.add_child(static_body_for_preview)
		# Add a second collision shape to ensure potential for multiple indicators
		var secondary_collision_shape := CollisionShape2D.new(); secondary_collision_shape.position = Vector2(40,0)
		var secondary_rectangle_shape := RectangleShape2D.new(); secondary_rectangle_shape.size = Vector2(16,16)
		secondary_collision_shape.shape = secondary_rectangle_shape; static_body_for_preview.add_child(secondary_collision_shape)

	assert_bool(is_instance_valid(preview)).append_failure_message("Failed to create preview (real=%s)" % str(used_real_placeable)).is_true()
	_preview_ref = auto_free(preview)
	assert_that(preview).append_failure_message("Preview instantiation failed").is_not_null()
	# Parent preview under positioner for real-world parity
	if preview.get_parent() != positioner:
		positioner.add_child(preview)

	# Collect collision shape/polygon nodes (iterative traversal to avoid recursive lambda scoping issues)
	var collected_collision_shape_nodes: Array = []
	var breadth_nodes: Array = [preview]
	while not breadth_nodes.is_empty():
		var current_node: Node = breadth_nodes.pop_back()
		for child_node in current_node.get_children():
			breadth_nodes.append(child_node)
			if child_node is CollisionShape2D or child_node is CollisionPolygon2D:
				collected_collision_shape_nodes.append(child_node)
	assert_int(collected_collision_shape_nodes.size()).append_failure_message("Preview has no CollisionShape2D or CollisionPolygon2D nodes; indicators cannot generate").is_greater(0)

	# Verify at least one physics body ancestor has collision_layer matching rule mask (we set body layer=1 in synthetic preview)
	var find_body = func(node: Node) -> Node:
		var current = node.get_parent()
		while current != null:
			if current is PhysicsBody2D or current is Area2D:
				return current
			current = current.get_parent()
		return null

	# Prepare the tile rule early so we can validate mask alignment before indicator generation
	var tile_check_rule := TileCheckRule.new()
	var matching_collision_layer_found := false
	var physics_body_layer_details: Array[String] = []
	for shape_node_entry in collected_collision_shape_nodes:
		var ancestor_physics_body = find_body.call(shape_node_entry)
		if ancestor_physics_body:
			var layer_bits = ancestor_physics_body.collision_layer
			physics_body_layer_details.append("%s(layer=%d)" % [ancestor_physics_body.get_class(), layer_bits])
			if (layer_bits & tile_check_rule.apply_to_objects_mask) != 0:
				matching_collision_layer_found = true
	assert_bool(matching_collision_layer_found).append_failure_message("No physics body ancestor has collision_layer overlapping TileCheckRule mask. Bodies observed: %s mask=%d" % [", ".join(physics_body_layer_details), tile_check_rule.apply_to_objects_mask]).is_true()

	# Ensure targeting state readiness
	var targeting_issues = targeting_state.get_runtime_issues()
	assert_that(targeting_issues.is_empty()).append_failure_message("Targeting state issues: %s" % str(targeting_issues)).is_true()

	# Direct indicator setup (TileCheckRule already created above)
	var report := placement_manager.setup_indicators(preview, [tile_check_rule])
	var indicators : Array[RuleCheckIndicator] = report.indicators
	assert_int(indicators.size()).append_failure_message("No indicators generated for preview; expected at least one from TileCheckRule").is_greater(0)

	# Assert uniqueness among first N indicator positions (spread) and that they are near tile centers
	var sample_count = min(5, indicators.size())
	var seen_positions := {}
	for i in range(sample_count):
		var indicator_node: Node2D = indicators[i]
		var indicator_global_position := indicator_node.global_position
		assert_bool(seen_positions.has(indicator_global_position)).append_failure_message("Duplicate indicator position encountered at index %d: %s" % [i, str(indicator_global_position)]).is_false()
		seen_positions[indicator_global_position] = true
		# Tile center alignment approximate check
		var map := targeting_state.target_map
		if map and map.tile_set:
			var tile_size: Vector2i = map.tile_set.tile_size
			var tile_origin := map.map_to_local(map.local_to_map(map.to_local(indicator_global_position)))
			var dx = abs(indicator_global_position.x - tile_origin.x)
			var dy = abs(indicator_global_position.y - tile_origin.y)
			assert_bool(dx <= tile_size.x and dy <= tile_size.y).append_failure_message("Indicator %d not within one tile cell of computed origin. pos=%s origin=%s tile_size=%s" % [i, str(indicator_global_position), str(tile_origin), str(tile_size)]).is_true()
		if i > 0:
			var previous_indicator_position = indicators[i-1].global_position
			assert_bool(previous_indicator_position != indicator_global_position).append_failure_message("Indicator positions %s and %s (indices %d,%d) should differ" % [str(previous_indicator_position), str(indicator_global_position), i-1, i]).is_true()

	# Basic relative positioning: indicators should cluster around preview
	var preview_center := preview.global_position
	var average_indicator_position := Vector2.ZERO
	for indicator_node in indicators:
		average_indicator_position += indicator_node.global_position
	average_indicator_position /= indicators.size()
	assert_bool((average_indicator_position - preview_center).length() < 256.0).append_failure_message("Average indicator position too far from preview center. avg=%s preview=%s" % [str(average_indicator_position), str(preview_center)]).is_true()

func after_test():
	# Ensure indicators are cleaned up to avoid orphan warnings
	if placement_manager:
		placement_manager.tear_down()
		placement_manager.queue_free()
		placement_manager = null
	# Preview already registered with auto_free; explicit queue_free if still valid
	if is_instance_valid(_preview_ref) and _preview_ref.get_parent():
		_preview_ref.queue_free()
	_preview_ref = null
