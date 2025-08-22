## Test suite validating RuleCheckIndicator generation for a concave CollisionPolygon2D based placeable.
extends GdUnitTestSuite

var _container : GBCompositionContainer
var _validator : PlacementValidator
var _targeting : GridTargetingState
var _owner_ctx : GBOwnerContext
var _placer : Node2D
var _map : TileMapLayer
var _preview : Node2D
var _rules : Array[PlacementRule]
var _manager : PlacementManager

func before_test():
	# Use the shared test container (injected resource) and its targeting state so internal systems see configured maps
	_container = preload("uid://dy6e5p5d6ax6n")
	_manager = PlacementManager.create_with_injection(_container)
	add_child(auto_free(_manager))
	_validator = PlacementValidator.create_with_injection(_container)

	# Acquire container states and configure targeting (positioner, target map, maps) just like integration helpers do
	_targeting = _container.get_states().targeting
	_map = auto_free(TileMapLayer.new())
	_map.tile_set = TileSet.new()
	_map.tile_set.tile_size = Vector2(16,16)
	add_child(_map)
	_targeting.target_map = _map
	_targeting.maps = [_map]
	if _targeting.positioner == null:
		_targeting.positioner = auto_free(Node2D.new())
		add_child(_targeting.positioner)

	# Basic placer/owner context (building state not needed for indicator setup)
	_placer = auto_free(Node2D.new())
	add_child(_placer)
	_owner_ctx = GBOwnerContext.new()
	var gb_owner: Node = auto_free(GBOwner.new(_placer))
	_placer.add_child(gb_owner)
	_owner_ctx.set_owner(gb_owner)

	# Instantiate concave polygon test object and parent under positioner to mimic runtime placement preview hierarchy
	_preview = UnifiedTestFactory.create_polygon_test_object(self)
	_targeting.positioner.add_child(_preview)

	# Reduce debug verbosity to avoid unrelated formatting/log noise during this focused geometry test
	var dbg = _container.get_debug_settings()
	dbg.set_debug_level(GBDebugSettings.DebugLevel.ERROR)
	# Build explicit collisions rule with mask bit 0
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1 << 0
	rule.collision_mask = 1 << 0
	_rules = [rule]
	var params := RuleValidationParameters.new(_placer, _preview, _targeting, _container.get_logger())
	var setup_ok := _manager.try_setup(_rules, params, true)
	assert_bool(setup_ok).append_failure_message("PlacementManager.try_setup failed for concave polygon test").is_true()

func after_test():
	if _validator:
		_validator.tear_down()
	if _manager:
		_manager.tear_down()

func _collect_indicators() -> Array[RuleCheckIndicator]:
	return _manager.get_indicators() if _manager else []

## Expect multiple indicators but not a full bounding box fill (which would indicate concavity not handled)
func test_concave_polygon_generates_expected_indicator_distribution():
	var indicators := _collect_indicators()
	
	assert_array(indicators).append_failure_message("No indicators generated for concave polygon – investigate rule attach path. Indicators not generated; test pending implementation.").is_not_empty()

	var tiles : Array[Vector2i] = []
	for ind in indicators:
		var tile := _map.local_to_map(_map.to_local(ind.global_position))
		if tile not in tiles:
			tiles.append(tile)
	var min_x = 9999 
	var max_x = -9999 
	var min_y = 9999 
	var max_y = -9999

	for t in tiles:
		min_x = min(min_x,t.x) 
		max_x = max(max_x,t.x) 
		min_y = min(min_y,t.y) 
		max_y = max(max_y,t.y)

	var bbox_cells = (max_x-min_x+1)*(max_y-min_y+1)
	var is_size_less_than_bbox_cells = tiles.size() < bbox_cells
	assert_bool(is_size_less_than_bbox_cells).append_failure_message("Concavity not reflected; full rectangle filled. tiles=%s" % [tiles]).is_true()
