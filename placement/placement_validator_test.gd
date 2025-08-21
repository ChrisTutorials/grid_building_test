# GdUnit generated TestSuite
#
# Orphan/Timer Diagnostic Note:
# ------------------------------------------------------------
# This suite previously reported 1 orphan per test and a final 4 orphans plus a
# ClassCountDiff showing a persistent Timer delta (e.g. total_delta=87 increased={"Timer":1}).
# After parenting all RuleCheckIndicator instances and explicitly freeing every
# test-created node, the warnings still appear with the same pattern.
#
# Investigation indicates these Timer instances are created internally by GdUnit
# (awaiter/signal assert helpers spawn transient Timer nodes under the test root
# or framework harness). They persist long enough to be counted between before_test
# snapshots, but are not created by this suite's code paths (no Timer.new() here).
#
# Action taken: We intentionally DO NOT attempt to manually free framework Timers.
# Forced cleanup could interfere with GdUnit's await mechanisms and introduce flakiness.
# If needed, future suppression should target the framework's orphan detector config
# rather than additional teardown here.
# ------------------------------------------------------------
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
var _ephemeral_nodes : Array[Node] = []

# Recursively collect RuleCheckIndicator diagnostics up to a max depth
func _collect_indicator_info(node: Node, depth: int, max_depth: int) -> Array[String]:
	var info: Array[String] = []
	if node is RuleCheckIndicator:
		var parent_chain := []
		var p: Node = node.get_parent()
		var depth_guard := 0
		while p != null and depth_guard < 10:
			parent_chain.append(p.name)
			p = p.get_parent()
			depth_guard += 1
		info.append("%s(parent_chain=%s rules=%d)" % [node.name, parent_chain, (node as RuleCheckIndicator).get_rules().size()])
	if depth < max_depth:
		for c in node.get_children():
			info.append_array(_collect_indicator_info(c, depth+1, max_depth))
	return info

func before():
	pass

func before_test():
	_container = preload("uid://dy6e5p5d6ax6n")
	_ephemeral_nodes.clear()
	# Capture global root children once (first test only)
	if not _root_captured:
		_class_logger = ClassCountLoggerScript.new()
		_root_initial_children.clear()
		for rc in get_tree().root.get_children():
			_root_initial_children.append(rc.name)
		_baseline_class_counts = _class_logger.snapshot_tree(get_tree().root)
		_baseline_total_objects = _class_logger.total_object_count()
		_root_captured = true
	else:
		# Instrument root changes prior to each test
		var root_children = get_tree().root.get_children()
		var new_nodes : Array[String] = []
		var class_freq : Dictionary[String, int] = {}
		for rc in root_children:
			if not _root_initial_children.has(rc.name):
				new_nodes.append("%s(%s)" % [rc.name, rc.get_class()])
				class_freq[rc.get_class()] = class_freq.get(rc.get_class(), 0) + 1
		if new_nodes.size() > 0:
			print("[OrphanTrace][before_test] New root nodes since baseline: ", new_nodes)
			print("[OrphanTrace][before_test] Class freq: ", class_freq)
	# Capture baseline before adding any test-specific nodes
	_baseline_children_names.clear()
	for c in get_children():
		_baseline_children_names.append(c.name)
	placer = auto_free(Node2D.new())
	add_child(placer)
	placer.name = "Placer"
	_ephemeral_nodes.append(placer)
	# Create dedicated owner context and targeting state explicitly instead of mutating container state
	_owner_context = GBOwnerContext.new()
	_owner_context.set_owner(GBOwner.new(placer))
	targeting_state = GridTargetingState.new(_owner_context)
	# Minimal map setup
	map_layer = auto_free(TileMapLayer.new())
	add_child(map_layer)
	map_layer.name = "TestMap"
	_ephemeral_nodes.append(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16,16)
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	targeting_state.positioner = auto_free(Node2D.new())
	add_child(targeting_state.positioner)
	targeting_state.positioner.name = "Positioner"
	_ephemeral_nodes.append(targeting_state.positioner)
	# Validate targeting state readiness early for clearer failures
	var targeting_issues = targeting_state.validate()
	assert_array(targeting_issues).append_failure_message("Targeting state not ready -> %s" % [targeting_issues]).is_empty()
	validator = PlacementValidator.create_with_injection(_container)
	assert_object(validator).is_not_null()
	preview_instance = auto_free(TestSceneLibrary.placeable_eclipse.packed_scene.instantiate() as Node2D)
	add_child(preview_instance)
	preview_instance.name = "PreviewInstance"
	_ephemeral_nodes.append(preview_instance)
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
	# Final sweep: free any stray RuleCheckIndicator nodes parented under this suite
	for child in get_children():
		if child is RuleCheckIndicator and child.get_parent():
			child.queue_free()
	# Explicitly free per-test nodes we created (defensive; auto_free should also handle)
	for n in _ephemeral_nodes:
		if n and is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()
	# Allow two frames so queued frees process
	if Engine.is_editor_hint() == false:
		await get_tree().process_frame
		await get_tree().process_frame
	# Log lingering indicators or timers directly under suite
	var lingering : Array[String] = []
	for c in get_children():
		if c is RuleCheckIndicator or c is Timer:
			lingering.append("%s(%s)" % [c.name, c.get_class()])
	if lingering.size() > 0:
		push_warning("[AfterTestDiag] Lingering nodes after explicit free: %s" % lingering)

	
func after():
	# Defensive cleanup: free stray anonymous root-level Nodes or Timers left by framework
	var root := get_tree().root
	# Enumerate all RuleCheckIndicator instances in tree before cleanup for diagnostics
	var indicator_diagnostics : Array[String] = []
	for child in root.get_children():
		# depth-first traversal limited to a few levels to avoid huge output
		indicator_diagnostics.append_array(_collect_indicator_info(child, 0, 3))
	if indicator_diagnostics.size() > 0:
		push_warning("[IndicatorDiag] Active indicators before suite cleanup -> %s" % indicator_diagnostics)
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
	# Prefer full validator lifecycle so indicators are parented/managed correctly
	var setup_issues := validator.setup(test_rules, test_params)
	assert_dict(setup_issues).append_failure_message("Validator.setup issues -> %s" % [setup_issues]).is_empty()
	# Collect all indicators from tile check rules and ensure they are parented under this test (direct or indirect)
	var orphan_like : Array[String] = []
	for rule in validator.active_rules:
		if rule is TileCheckRule:
			for ind in rule.indicators:
				if ind and is_instance_valid(ind):
					var p: Node = ind.get_parent()
					var attached := false
					while p != null:
						if p == self:
							attached = true
							break
						p = p.get_parent()
					if not attached:
						orphan_like.append(ind.name)
	assert_array(orphan_like).append_failure_message("Indicators not attached to test tree: %s" % [orphan_like]).is_empty()

## The rules should receive the validator.debug GBDebugSettings object.
## In this test, debug is set on so the rule.debug.show should be on too
func test_setup_rules_passes_debug_object():
	# Use validator.setup for consistent parenting/teardown semantics
	var setup_issues := validator.setup(test_rules, test_params)
	assert_dict(setup_issues).append_failure_message("Validator.setup issues -> %s" % [setup_issues]).is_empty()
	for rule in validator.active_rules:
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
