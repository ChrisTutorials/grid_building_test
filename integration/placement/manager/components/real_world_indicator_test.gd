extends GdUnitTestSuite

## Tests indicator positioning using the exact same setup as the real system
## Uses DRY factory patterns for maintainable test setup

var _setup: Dictionary
var _container: GBCompositionContainer
var indicator_manager: IndicatorManager
var targeting_state: GridTargetingState
var positioner: Node2D
var _logger: GBLogger
var _preview_ref: Node2D


func before_test():
	# Use DRY factory pattern for complete test setup
	_setup = UnifiedTestFactory.create_complete_building_test_setup(self)
	_container = _setup.container

	# Extract frequently used components to local variables for clarity
	indicator_manager = _setup.indicator_manager
	targeting_state = _container.get_states().targeting
	positioner = _setup.positioner

	# Ensure indicator template is configured using DRY pattern
	UnifiedTestFactory.ensure_indicator_template_configured(_container)

	# Initialize logger for test debugging
	_logger = _container.get_logger()

func _instantiate_preview(packed_scene: PackedScene) -> Node2D:
	## Create preview using DRY factory pattern when possible
	if packed_scene:
		return packed_scene.instantiate()

	# Use DRY factory for synthetic preview creation
	return UnifiedTestFactory.create_polygon_test_object(self)

func _get_collision_shapes_from_node(root: Node) -> Array[Node2D][Node]:
	## Helper method to collect collision shapes using DRY pattern
	var shapes: Array[Node2D][Node] = []
	var nodes_to_check: Array[Node2D][Node] = [root]

	while not nodes_to_check.is_empty():
		current: Node = nodes_to_check.pop_back()
		for child in current.get_children():
			nodes_to_check.append(child)
			if child is CollisionShape2D or child is CollisionPolygon2D:
				shapes.append(child)

	return shapes

func _find_physics_body_ancestor(node: Node) -> Node:
	## Helper method to find physics body ancestor
	var current = node.get_parent()
	while current != null:
		if current is PhysicsBody2D or current is Area2D:
			return current
		current = current.get_parent()
	return null

func _validate_indicator_positions(indicators: Array[Node2D][RuleCheckIndicator], preview: Node2D) -> void:
	## Helper method to validate indicator positioning using DRY patterns
	var sample_count = min(5, indicators.size())
	var seen_positions := {}

	for i in range(sample_count):
		var indicator = indicators[i]
		var position = indicator.global_position

		# Check for duplicate positions
		assert_bool(seen_positions.has(position)).append_failure_message(
			"Duplicate indicator position at index %d: %s" % [i, str(position)]
		).is_false()
		seen_positions[position] = true

		# Validate tile alignment using DRY pattern
		var map = targeting_state.target_map
		if map and map.tile_set:
			var tile_size: Vector2i = map.tile_set.tile_size
			var tile_origin = map.map_to_local(map.local_to_map(map.to_local(position)))
			var offset = position - tile_origin
			assert_bool(abs(offset.x) <= tile_size.x and abs(offset.y) <= tile_size.y).append_failure_message(
				"Indicator %d not within tile bounds. pos=%s origin=%s tile_size=%s" %
				[i, str(position), str(tile_origin), str(tile_size)]
			).is_true()

		# Ensure positions differ from previous indicator
		if i > 0:
			var prev_position = indicators[i-1].global_position
			assert_bool(prev_position != position).append_failure_message(
				"Indicator positions should differ: %s vs %s" % [str(prev_position), str(position)]
			).is_true()

	# Validate clustering around preview center
	var preview_center = preview.global_position
	var centroid = Vector2.ZERO
	for indicator in indicators:
		centroid += indicator.global_position
	centroid /= indicators.size()

	assert_bool((centroid - preview_center).length() < 256.0).append_failure_message(
		"Average indicator position too far from preview center. avg=%s preview=%s" %
		[str(centroid), str(preview_center)]
	).is_true()

func after_test():
	## Clean up test resources using DRY patterns
	if indicator_manager:
		indicator_manager.tear_down()
		indicator_manager.queue_free()
		indicator_manager = null

	if is_instance_valid(_preview_ref) and _preview_ref.get_parent():
		_preview_ref.queue_free()
	_preview_ref = null

	# Injector cleanup is handled automatically by UnifiedTestFactory


## EXPECTATION / PURPOSE
## This test exercises indicator generation and spatial positioning using the real IndicatorManager pipeline
## without bootstrapping the entire BuildingSystem dependency graph.
##
## Setup:
##  - A targeting state with a populated TileMapLayer (factory-created predictable 40x40 grid)
##  - A positioner Node2D assigned to the targeting state
##  - A IndicatorManager (created directly if container didn't provide one)
##  - A real placeable resource if available via TestSceneLibrary; otherwise a synthetic Placeable with a
##    simple PackedScene containing a StaticBody2D + CollisionShape2D rectangle (32x32) is created.
##
## Actions:
##  - Instantiate a preview for the (real or synthetic) placeable and parent it under the positioner
##  - Invoke indicator_manager.try_setup with either the placeable's own placement_rules or a fallback
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
	# Use DRY factory pattern for preview creation
	var preview: Node2D
	var used_real_placeable := false

	# Try to use real placeable from test library, fallback to DRY factory
	if Engine.has_singleton("TestSceneLibrary"):
		tsl: Node = Engine.get_singleton("TestSceneLibrary")
		if tsl and tsl.has_variable("placeable_eclipse") and tsl.placeable_eclipse and tsl.placeable_eclipse.packed_scene:
			preview = _instantiate_preview(tsl.placeable_eclipse.packed_scene)
			used_real_placeable = true

	if preview == null:
		# Use DRY factory for synthetic preview
		preview = UnifiedTestFactory.create_polygon_test_object(self)
		# Add secondary collision shape for multiple indicator testing
		var body = preview.get_child(0) as StaticBody2D
		if body:
			var secondary_shape := CollisionShape2D.new()
			secondary_shape.position = Vector2position
			var rect := RectangleShape2D.new()
			rect.size = Vector2size
			secondary_shape.shape = rect
			body.add_child(secondary_shape)

	# Setup validation
	assert_bool(is_instance_valid(preview)).append_failure_message(
		"Failed to create preview (real=%s)" % str(used_real_placeable)
	).is_true()

	_preview_ref = auto_free(preview)
	positioner.add_child(preview)

	# Use helper method for collision shape collection
	var collision_shapes = _get_collision_shapes_from_node(preview)
	assert_int(collision_shapes.size()).append_failure_message(
		"Preview has no CollisionShape2D or CollisionPolygon2D nodes"
	).is_greater(0)

	# Validate collision layer alignment using DRY pattern
	var tile_check_rule = UnifiedTestFactory.create_test_within_tilemap_bounds_rule()
	var has_matching_layer := false
	var physics_body_details: Array[Node2D][String] = []

	for shape in collision_shapes:
		var physics_body = _find_physics_body_ancestor(shape)
		if physics_body:
			var layer_bits = physics_body.collision_layer
			physics_body_details.append("%s(layer=%d)" % [physics_body.get_class(), layer_bits])
			if (layer_bits & tile_check_rule.apply_to_objects_mask) != 0:
				has_matching_layer = true

	assert_bool(has_matching_layer).append_failure_message(
		"No physics body has collision_layer overlapping TileCheckRule mask. Bodies: %s mask=%d" %
		[", ".join(physics_body_details), tile_check_rule.apply_to_objects_mask]
	).is_true()

	# Validate targeting state using DRY pattern
	var targeting_issues = targeting_state.get_runtime_issues()
	assert_that(targeting_issues.is_empty()).append_failure_message(
		"Targeting state issues: %s" % str(targeting_issues)
	).is_true()

	# Generate indicators using DRY pattern
	var report = indicator_manager.setup_indicators(preview, [tile_check_rule])
	var indicators: Array[Node2D][RuleCheckIndicator] = report.indicators
	assert_int(indicators.size()).append_failure_message(
		"No indicators generated for preview"
	).is_greater(0)

	# Validate indicator positioning using DRY helper methods
	_validate_indicator_positions(indicators, preview)
