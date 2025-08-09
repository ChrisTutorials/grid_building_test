# GdUnit Test: Verifies that placeable-only rules receive initialize() before setup.
# Failing test documenting GH Issue: Placement rules from placeable instances are not initialized.
extends GdUnitTestSuite

const TestSceneLibraryRef = preload("res://test/grid_building_test/scenes/test_scene_library.gd")

class InitFlagRule:
	extends PlacementRule
	var initialized := false
	func initialize(_p_logger: GBLogger):
		initialized = true

	func validate_condition() -> RuleResult:
		# Use guard to mimic typical implementations relying on _logger
		var reason := "" if initialized else "Rule not initialized"
		return RuleResult.new(self, initialized, reason)

var _container : GBCompositionContainer
var _placement_manager : PlacementManager
var _placer : Node
var _targeting_state : GridTargetingState
var _preview_scene : PackedScene
var _preview_instance : Node2D
var _map_layer : TileMapLayer

var _custom_rule : InitFlagRule

func before_test():
	_container = GBCompositionContainer.new()
	# Create minimal targeting state with required owner context
	var owner_context := GBOwnerContext.new()
	_targeting_state = GridTargetingState.new(owner_context)
	_placer = auto_free(Node.new())
	_map_layer = TileMapLayer.new()
	add_child(_map_layer)
	_map_layer.tile_set = TileSet.new()
	_map_layer.tile_set.tile_size = Vector2i(16, 16)
	_targeting_state.target_map = _map_layer
	_targeting_state.maps = [_map_layer]
	_targeting_state.positioner = auto_free(Node2D.new())
	add_child(_targeting_state.positioner)
	# Owner context is internally managed by state/container for this test scope; no manual assignment needed.

	_preview_scene = TestSceneLibrary.placeable_eclipse.packed_scene
	_preview_instance = _preview_scene.instantiate() as Node2D
	add_child(_preview_instance)

	_custom_rule = InitFlagRule.new()

	# Create placement manager manually without container injection (avoids needing full config)
	_placement_manager = PlacementManager.new()
	var logger := GBLogger.new(GBDebugSettings.new())
	var indicator_template := TestSceneLibraryRef.indicator_min
	var base_rules : Array[PlacementRule] = []
	# Initialize with no base rules; messages null (manager fallback creates internal components)
	_placement_manager.initialize(null, indicator_template, _targeting_state, logger, base_rules, null, null)

func after_test():
	if is_instance_valid(_preview_instance):
		_preview_instance.queue_free()
	if is_instance_valid(_map_layer):
		_map_layer.queue_free()
	if is_instance_valid(_placement_manager):
		_placement_manager.tear_down()
		_placement_manager.queue_free()
	# Free positioner created on targeting state
	if _targeting_state and is_instance_valid(_targeting_state.positioner):
		_targeting_state.positioner.queue_free()

func test_placeable_only_rule_should_be_initialized_before_setup():
	var params = RuleValidationParameters.new(_placer, _preview_instance, _targeting_state)
	# Simulate try_setup with only the custom rule as placeable-specific
	var _setup_success := _placement_manager.try_setup([_custom_rule], params)
	# Current BUG expectation: setup_success may be true but rule not initialized
	# Document failing expectation:
	assert_bool(_custom_rule.initialized).is_true().append_failure_message("Custom placeable rule was not initialized before setup (see issue: placement_rules_initialization_injection_issue_2025_08_09)")
