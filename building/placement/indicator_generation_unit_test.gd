## Unit test to reproduce indicator generation emptiness
## This test creates a minimal environment via EnvironmentTestFactory,
## ensures the environment contains the indicator manager and container,
## then attempts to run IndicatorManager.try_setup with placement rules from
## GBTestConstants and verifies that indicators are produced.
extends GdUnitTestSuite

const DEFAULT_POSITION: Vector2 = Vector2.ZERO

var _env: BuildingTestEnvironment
var _manager: IndicatorManager
var _container: GBCompositionContainer
var _state: GridTargetingState


func before_test() -> void:
	_env = EnvironmentTestFactory.create_building_system_test_environment(self)
	_manager = _env.indicator_manager
	_container = _env.get_container()
	_state = _env.grid_targeting_system.get_state()
	(
		assert_object(_manager)
		. append_failure_message("IndicatorManager should be available in test environment")
		. is_not_null()
	)
	(
		assert_object(_container)
		. append_failure_message("CompositionContainer should be available in test environment")
		. is_not_null()
	)
	(
		assert_object(_state)
		. append_failure_message("GridTargetingState should be available in test environment")
		. is_not_null()
	)


func test_indicator_generation_from_container_rules() -> void:
	# Arrange: create a polygon preview like integration tests do
	var preview: Node2D = CollisionObjectTestFactory.create_polygon_test_object(self, self)
	auto_free(preview)
	# Reparent if factory already attached it somewhere
	var old_parent := preview.get_parent() if is_instance_valid(preview) else null
	if old_parent != null:
		old_parent.remove_child(preview)

	# Parent under the environment's positioner (runtime-like)
	_state.positioner.add_child(preview)
	_state.set_manual_target(preview)
	# Place positioner at 4 tiles over (64px) using canonical tile pixel size
	_state.positioner.global_position = Vector2(
		GBTestConstants.DEFAULT_TILE_PIXEL * 4, GBTestConstants.DEFAULT_TILE_PIXEL * 4
	)

	# Acquire placement rules from the container (or GBTestConstants fallback)
	var rules: Array[PlacementRule] = _container.get_placement_rules()
	if rules.size() == 0:
		# fallback to canonical collisions rule from GBTestConstants
		var cr: CollisionsCheckRule = GBTestConstants.COLLISIONS_CHECK_RULE.new()
		rules = [cr]

	# Enhanced diagnostics: trace rule identity and characteristics (use per-test local diag)
	var diag: PackedStringArray = PackedStringArray()
	diag.append("[RULE_TRACE] === CONTAINER RULE ANALYSIS ===")
	diag.append(
		(
			"[RULE_TRACE] container placement_rules size = %s"
			% [_container.get_placement_rules().size()]
		)
	)
	diag.append("[RULE_TRACE] using rules size = %s" % [rules.size()])

	for i in range(rules.size()):
		var r: PlacementRule = rules[i]
		diag.append(
			(
				"[RULE_TRACE] rule[%d] IDENTITY: object_id=%s, class=%s"
				% [i, str(r.get_instance_id()), r.get_class()]
			)
		)
		(
			diag
			. append(
				(
					"[RULE_TRACE] rule[%d] TYPE_INFO: typeof=%s, is_PlacementRule=%s, is_TileCheckRule=%s, is_CollisionsCheckRule=%s"
					% [
						i,
						typeof(r),
						str(r is PlacementRule),
						str(r is TileCheckRule),
						str(r is CollisionsCheckRule)
					]
				)
			)
		)
		if r.has_method("get_script"):
			diag.append("[RULE_TRACE] rule[%d] SCRIPT: %s" % [i, str(r.get_script())])
		# Direct property access instead of has_property() - fail fast pattern
		diag.append(
			(
				"[RULE_TRACE] rule[%d] RESOURCE_PATH: %s"
				% [i, str(r.resource_path) if "resource_path" in r else "N/A"]
			)
		)
		diag.append("[RULE_TRACE] rule[%d] STRING_REPR: %s" % [i, str(r)])

	# Ensure rules are setup and trace setup results (buffered instead of print)
	diag.append("[RULE_TRACE] === RULE SETUP PHASE ===")
	for idx in range(rules.size()):
		var rule: PlacementRule = rules[idx]
		if rule is CollisionsCheckRule:
			var collisions_rule: CollisionsCheckRule = rule as CollisionsCheckRule
			(
				diag
				. append(
					(
						"[RULE_TRACE] rule[%d] SETUP_BEFORE: apply_to_objects_mask=%s, collision_mask=%s"
						% [
							idx,
							collisions_rule.apply_to_objects_mask,
							collisions_rule.collision_mask
						]
					)
				)
			)
			var setup_issues: Array[String] = collisions_rule.setup(_state)
			diag.append(
				(
					"[RULE_TRACE] rule[%d] SETUP_RESULT: issues_count=%s, issues=%s"
					% [idx, setup_issues.size(), str(setup_issues)]
				)
			)
			(
				assert_array(setup_issues)
				. append_failure_message(
					"Rule setup failed for rule %d\n%s" % [idx, "\n".join(diag)]
				)
				. is_empty()
			)
			(
				diag
				. append(
					(
						"[RULE_TRACE] rule[%d] SETUP_AFTER: still_same_id=%s, still_CollisionsCheckRule=%s"
						% [idx, str(rule.get_instance_id()), str(rule is CollisionsCheckRule)]
					)
				)
			)
		elif rule is TileCheckRule:
			var tile_rule: TileCheckRule = rule as TileCheckRule
			var setup_issues: Array[String] = tile_rule.setup(_state)
			diag.append(
				(
					"[RULE_TRACE] rule[%d] TILE_SETUP_RESULT: issues_count=%s"
					% [idx, setup_issues.size()]
				)
			)
			(
				assert_array(setup_issues)
				. append_failure_message(
					"Rule setup failed for rule %d\n%s" % [idx, "\n".join(diag)]
				)
				. is_empty()
			)

	# Act: Run try_setup
	var report: PlacementReport = _manager.try_setup(rules, _state, true)
	(
		assert_object(report)
		. append_failure_message("IndicatorManager.try_setup returned null")
		. is_not_null()
	)

	# Diagnostics: dump report details
	if report:
		diag.append("[diagnostic] report.is_successful = %s" % [report.is_successful()])
		if report.indicators_report:
			var ind_list: Array[RuleCheckIndicator] = report.indicators_report.indicators
			diag.append("[diagnostic] indicators_report.indicators size = %s" % [ind_list.size()])
			for j in range(ind_list.size()):
				var ind: RuleCheckIndicator = ind_list[j]
				diag.append("[diagnostic] indicator[%d] = %s" % [j, str(ind)])
	# Check success
	if not report.is_successful():
		fail("try_setup reported failure: %s - %s" % [str(report.get_issues()), "\n".join(diag)])

	var indicators: Array[RuleCheckIndicator] = report.indicators_report.indicators
	(
		assert_array(indicators)
		. append_failure_message("No indicators generated (unit test)\n%s" % "\n".join(diag))
		. is_not_empty()
	)


func test_indicators_are_freed_on_reset() -> void:
	var shape_scene: Node2D = CollisionObjectTestFactory.create_polygon_test_object(self, self)
	shape_scene.global_position = DEFAULT_POSITION
	var col_checking_rules: Array[TileCheckRule] = [GBTestConstants.COLLISIONS_CHECK_RULE.new()]
	_manager.setup_indicators(shape_scene, col_checking_rules)

	(
		assert_array(_manager.get_indicators())
		. append_failure_message("No indicators generated before reset (unit test)")
		. is_not_empty()
	)

	# Reset the indicator manager and verify indicators are freed
	_manager.clear()
	(
		assert_array(_manager.get_indicators())
		. append_failure_message("Indicators should be cleared after reset")
		. is_empty()
	)
