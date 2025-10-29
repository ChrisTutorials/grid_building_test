## Test suite validating RuleCheckIndicator generation for a concave CollisionPolygon2D based placeable.
extends GdUnitTestSuite

const DEFAULT_TILE_SIZE: Vector2 = Vector2(16, 16)
const BBOX_INIT_HIGH: int = 9999
const BBOX_INIT_LOW: int = -9999

var _container : GBCompositionContainer
var _validator : PlacementValidator
var _targeting : GridTargetingState
var _placer : Node2D
var _map : TileMapLayer
var _preview : Node2D
var _rules : Array[PlacementRule]
var _manager : IndicatorManager

func before_test() -> void:
	# Use the shared test container (injected resource) and its targeting state so internal systems see configured maps
	_container = GBTestConstants.TEST_COMPOSITION_CONTAINER.duplicate(true)

	# Acquire container states and configure targeting FIRST (positioner, target map, maps)
	_targeting = _container.get_states().targeting

	# Create tilemap with cells covering the concave polygon's bounding box
	# Concave polygon spans from (-32, -16) to (32, 16), which at 16x16 tile size covers:
	# tile coords: (-2, -1) to (2, 1) - a 5x3 grid centered around origin
	_map = GodotTestFactory.create_populated_tile_map_layer(
		self,
		Rect2i(-2, -1, 5, 3),  # position: (-2, -1), size: 5x3
		0,
		Vector2i.ZERO
	)
	_targeting.target_map = _map
	_targeting.maps = [_map]

	# Create proper GridPositioner2D with TargetingShapeCast2D child (matching template scene configuration)
	if _targeting.positioner == null:
		var grid_positioner: GridPositioner2D = auto_free(GridPositioner2D.new())
		add_child(grid_positioner)

		# Add TargetingShapeCast2D child with proper RectangleShape2D (matching grid_positioner_stack_2d.tscn)
		var targeting_shapecast: TargetingShapeCast2D = auto_free(TargetingShapeCast2D.new())
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = Vector2(16, 16)  # Match template scene configuration
		targeting_shapecast.shape = rect_shape
		targeting_shapecast.collision_mask = 4294967295  # Match template scene configuration
		grid_positioner.add_child(targeting_shapecast)

		# Resolve dependencies
		targeting_shapecast.resolve_gb_dependencies(_container)

		_targeting.positioner = grid_positioner

	# Set up manipulation parent - required for IndicatorManager to have a parent node
	var manipulation_parent: ManipulationParent = auto_free(ManipulationParent.new())
	_targeting.positioner.add_child(manipulation_parent)
	_container.get_states().manipulation.parent = manipulation_parent

	# Basic placer/owner context (building state not needed for indicator setup)
	_placer = auto_free(Node2D.new())
	add_child(_placer)

	# NOW create the IndicatorManager after targeting is set up
	_manager = IndicatorManager.create_with_injection(_container)
	add_child(auto_free(_manager))
	_validator = PlacementValidator.create_with_injection(_container)

	# Instantiate concave polygon test object and parent under positioner to mimic runtime placement preview hierarchy
	# Note: create_polygon_test_object already adds to parent, so we don't call add_child again
	_preview = CollisionObjectTestFactory.create_polygon_test_object(self, _targeting.positioner)

	# Critical: make the preview the active target so IndicatorManager maps indicators for it
	_targeting.set_manual_target(_preview)

	# Reduce debug verbosity to avoid unrelated formatting/log noise during this focused geometry test
	var dbg: GBDebugSettings = _container.get_debug_settings()
	dbg.set_debug_level(GBDebugSettings.LogLevel.ERROR)
	# Use canonical collisions rule from test constants to match injection expectations
	# Create a fresh collisions rule with proper script class
	var rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	_rules = [rule]
	# Ensure rule is setup for the targeting state
	var setup_issues: Array[String] = rule.setup(_container.get_targeting_state())
	assert_array(setup_issues).append_failure_message("Concave test: rule.setup reported issues").is_empty()
	var setup_ok := _manager.try_setup(_rules, _container.get_targeting_state(), true)
	assert_bool(setup_ok.is_successful()).append_failure_message("IndicatorManager.try_setup failed for concave polygon test").is_true()

func after_test() -> void:
	if _validator:
		_validator.tear_down()
	if _manager:
		_manager.tear_down()

func _collect_indicators() -> Array[RuleCheckIndicator]:
	var indicators: Array[RuleCheckIndicator] = []
	if _manager:
		indicators = _manager.get_indicators()
	return indicators


## Diagnostic helpers to keep tests concise and consistent
func _format_indicator_debug(indicators: Array) -> Array[String]:
	var ind_dbg: Array[String] = []
	for i in range(indicators.size()):
		var ind: RuleCheckIndicator = indicators[i]
		ind_dbg.append("%d:(pos=%s,tile=%s,valid=%s,colliding=%s)" % [i, str(ind.global_position), str(_map.local_to_map(_map.to_local(ind.global_position))), str(ind.valid), str(ind.is_colliding())])
	return ind_dbg

func _build_concave_failure_message(tiles: Array, indicators: Array[RuleCheckIndicator]) -> String:
	var failure_msg_parts: Array[String] = []
	failure_msg_parts.append("Concavity not reflected; full rectangle filled.")
	failure_msg_parts.append("tiles=%s" % [tiles])

	# Compute bbox for human-readable context
	var min_x: int = BBOX_INIT_HIGH
	var max_x: int = BBOX_INIT_LOW
	var min_y: int = BBOX_INIT_HIGH
	var max_y: int = BBOX_INIT_LOW
	for t:Vector2i in tiles:
		min_x = min(min_x,t.x)
		max_x = max(max_x,t.x)
		min_y = min(min_y,t.y)
		max_y = max(max_y,t.y)
	var bbox_cells: int = (max_x-min_x+1)*(max_y-min_y+1)
	failure_msg_parts.append("bbox_min=(%d,%d) bbox_max=(%d,%d) bbox_cells=%d" % [min_x, min_y, max_x, max_y, bbox_cells])

	# Include polygon debug info if available on preview
	if _preview and _preview is CollisionObject2D:
		var poly_nodes := []
		for c in _preview.get_children():
			if c is CollisionPolygon2D:
				poly_nodes.append(str((c as CollisionPolygon2D).polygon))
		if poly_nodes.size() > 0:
			failure_msg_parts.append("collision_polygons=%s" % [poly_nodes])

	# Map diagnostics
	if _map:
		failure_msg_parts.append("map_used_rect=%s" % [_map.get_used_rect()])
		var tile_size: Vector2 = DEFAULT_TILE_SIZE
		if _map.tile_set:
			tile_size = _map.tile_set.tile_size
		failure_msg_parts.append("tile_size=%s" % [tile_size])

	# Indicator diagnostics
	var ind_dbg: Array[String] = _format_indicator_debug(indicators)
	failure_msg_parts.append("indicators=[%s]" % [ind_dbg])

	return "\n".join(failure_msg_parts)

## Expect multiple indicators but not a full bounding box fill (which would indicate concavity not handled)
func test_concave_polygon_generates_expected_indicator_distribution() -> void:
	var indicators: Array[RuleCheckIndicator] = _collect_indicators()

	assert_array(indicators).append_failure_message("No indicators generated for concave polygon – investigate rule attach path. Indicators not generated; test pending implementation.")\
		.is_not_empty()

	var tiles: Array[Vector2i] = []
	for ind in indicators:
		var tile := _map.local_to_map(_map.to_local(ind.global_position))
		if tile not in tiles:
			tiles.append(tile)
	var failure_msg: String = _build_concave_failure_message(tiles, indicators)
	var is_size_less_than_bbox_cells: bool = false
	# compute bbox cells again to determine relation between tiles and bbox
	if tiles.size() > 0:
		var min_x: int = BBOX_INIT_HIGH
		var max_x: int = BBOX_INIT_LOW
		var min_y: int = BBOX_INIT_HIGH
		var max_y: int = BBOX_INIT_LOW
		for t:Vector2i in tiles:
			min_x = min(min_x,t.x)
			max_x = max(max_x,t.x)
			min_y = min(min_y,t.y)
			max_y = max(max_y,t.y)
		var bbox_cells: int = (max_x-min_x+1)*(max_y-min_y+1)
		is_size_less_than_bbox_cells = tiles.size() < bbox_cells

	assert_bool(is_size_less_than_bbox_cells).append_failure_message(failure_msg).is_true()
