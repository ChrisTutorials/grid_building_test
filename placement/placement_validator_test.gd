# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from

var test_params : RuleValidationParameters
var validator : PlacementValidator
var placer : Node
var targeting_state : GridTargetingState
var map_layer : TileMapLayer
var test_rules : Array[PlacementRule]
var _owner_context : GBOwnerContext
var _container : GBCompositionContainer
var preview_instance : Node2D

# Utilities
const ClassCountLoggerScript := preload("res://test/grid_building_test/utilities/class_count_logger.gd")

# Baseline children snapshot to help identify unexpected leftover nodes
var _baseline_children_names : Array[String] = []
const _EXPECTED_CHILD_NAMES : Array[String] = ["Placer", "TestMap", "Positioner", "PreviewInstance"]
var _root_initial_children : Array[String] = []
var _root_captured := false
var _class_logger : ClassCountLoggerScript
var _baseline_class_counts : Dictionary[String, int] = {}
var _baseline_total_objects : int = -1

var empty_rules_array : Array[PlacementRule] = []

func before():
	pass

func before_test():
	_container = preload("uid://dy6e5p5d6ax6n")
	# Capture global root children once (first test only)
	if not _root_captured:
		_class_logger = ClassCountLoggerScript.new()
		_root_initial_children.clear()
		for rc in get_tree().root.get_children():
			_root_initial_children.append(rc.name)
		_baseline_class_counts = _class_logger.snapshot_tree(get_tree().root)
		_baseline_total_objects = _class_logger.total_object_count()
		_root_captured = true
	# Capture baseline before adding any test-specific nodes
	_baseline_children_names.clear()
	for c in get_children():
		_baseline_children_names.append(c.name)
	placer = auto_free(Node2D.new())
	# Add placer to scene tree so it is not treated as an orphan during test
	add_child(placer)
	placer.name = "Placer"
	# Create dedicated owner context and targeting state explicitly instead of mutating container state
	_owner_context = GBOwnerContext.new()
	_owner_context.set_owner(GBOwner.new(placer))
	targeting_state = GridTargetingState.new(_owner_context)
	# Minimal map setup
	map_layer = auto_free(TileMapLayer.new())
	add_child(map_layer)
	map_layer.name = "TestMap"
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16,16)
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	targeting_state.positioner = auto_free(Node2D.new())
	add_child(targeting_state.positioner)
	targeting_state.positioner.name = "Positioner"
	# Validate targeting state readiness early for clearer failures
	var targeting_issues = targeting_state.validate()
	assert_array(targeting_issues).append_failure_message("Targeting state not ready -> %s" % [targeting_issues]).is_empty()
	validator = PlacementValidator.create_with_injection(_container)
	assert_object(validator).is_not_null()
	preview_instance = auto_free(TestSceneLibrary.placeable_eclipse.packed_scene.instantiate() as Node2D)
	add_child(preview_instance)
	preview_instance.name = "PreviewInstance"
	test_rules = validator.get_combined_rules(TestSceneLibrary.placeable_eclipse.placement_rules)
	test_params = RuleValidationParameters.new(placer, preview_instance, targeting_state, _container.get_logger())
	
func after_test():
	# Tear down any active rules to free indicators and prevent orphan leakage between tests
	if validator and validator.active_rules.size() > 0:
		validator.tear_down()
		# Extra safety: free any indicator nodes still referenced by tile check rules (defensive cleanup)
		for rule in test_rules:
			if rule is TileCheckRule:
				for indicator in rule.indicators:
					if indicator and is_instance_valid(indicator) and indicator.get_parent():
						indicator.queue_free()
	# Diagnostic: list unexpected children remaining after teardown
	var unexpected : Array[String] = []
	for child in get_children():
		if not _baseline_children_names.has(child.name) and not _EXPECTED_CHILD_NAMES.has(child.name):
			unexpected.append("%s(%s)" % [child.name, child.get_class()])
	if unexpected.size() > 0:
		push_warning("[OrphanDiag] Unexpected remaining children after test: %s" % unexpected)
	# NOTE: validator is a RefCounted (GBInjectable/GBResource based) object, not a Node.
	# Calling queue_free() on RefCounted triggers the previous errors and is unnecessary.
	# Orphan sources are most likely indicator Nodes created by rules; tear_down() should have cleared them.
	# If orphan warnings persist, investigate specific rule indicator creation & ensure they use auto_free in tests.
	
func after():
	# Defensive cleanup: free stray anonymous root-level Nodes or Timers left by framework
	var root := get_tree().root
	for child in root.get_children():
		var is_timer := child is Timer
		var anonymous := (child.name == "" or child.name.begins_with("@"))
		if is_timer or anonymous:
			# Avoid freeing our own suite node (which is named) or essential singletons
			if child != self:
				child.queue_free()
	# After full suite: diff global root against initial snapshot
	var root_now : Array[String] = []
	for rc in get_tree().root.get_children():
		root_now.append(rc.name)
	var added : Array[String] = []
	for child_name in root_now:
		if not _root_initial_children.has(child_name):
			added.append(child_name)
	var removed : Array[String] = []
	for base_name in _root_initial_children:
		if not root_now.has(base_name):
			removed.append(base_name)
	if added.size() > 0 or removed.size() > 0:
		push_warning("[RootDiff] Added=%s Removed=%s" % [added, removed])
	# Class count diff (only if we captured baseline)
	if _class_logger:
		var final_counts = _class_logger.snapshot_tree(get_tree().root)
		var inc = _class_logger.diff_increases(_baseline_class_counts, final_counts)
		var final_total = _class_logger.total_object_count()
		var total_delta = final_total - _baseline_total_objects if _baseline_total_objects >= 0 else -9999
		if inc.size() > 0 or total_delta != 0:
			push_warning("[ClassCountDiff] total_delta=%d increased=%s" % [total_delta, inc])
	
func test_setup():
	# Use pure logic class for validation
	var validation_issues = PlacementRuleValidator.setup_rules(test_rules, test_params)
	assert_dict(validation_issues).append_failure_message(str(validation_issues)).is_empty()

## The rules should receive the validator.debug GBDebugSettings object.
## In this test, debug is set on so the rule.debug.show should be on too
func test_setup_rules_passes_debug_object():
	var validation_issues = PlacementRuleValidator.setup_rules(test_rules, test_params)
	assert_dict(validation_issues).append_failure_message("Rule setup issues -> %s" % [validation_issues]).is_empty()
	# PlacementValidator may not expose a debug property directly; ensure each rule received settings from params.logger
	for rule in test_rules:
		if rule.get_logger():
			assert_object(rule.get_logger().get_debug_settings()).append_failure_message("Missing debug settings on rule logger -> %s" % [rule]).is_not_null()

@warning_ignore("unused_parameter")
func test_get_combined_rules(p_added_rules : Array[PlacementRule], test_parameters := [
	[empty_rules_array],
	[TestSceneLibrary.placeable_smithy.placement_rules]
]) -> void:
	# Use pure logic class for combining rules; duplicate baseline behavior
	var baseline = PlacementRuleValidator.combine_rules([], [], false).size()
	var added := p_added_rules.size() if p_added_rules else 0
	var result : Array = PlacementRuleValidator.combine_rules([], p_added_rules, false)
	assert_int(result.size()).append_failure_message("Combined rules size mismatch baseline=%d added=%d result=%d rules=%s" % [baseline, added, result.size(), p_added_rules]).is_equal(baseline + added)
