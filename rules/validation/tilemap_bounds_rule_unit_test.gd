## Unit tests for WithinTilemapBoundsRule to reproduce template_rule_pass failure
## Reproduces issue from building_and_placement_tests where WithinTilemapBoundsRule fails
## even when position is within bounds
extends GdUnitTestSuite

var _logger: GBLogger
var runner: GdUnitSceneRunner
var _env: CollisionTestEnvironment


func before_test() -> void:
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV.resource_path)
	_env = runner.scene() as CollisionTestEnvironment
	_logger = _env.get_container().get_logger()


# Helper to create minimal test setup using the SAME tilemap as test environments
# This ensures we're testing against the actual tilemap configuration used in integration tests
func _create_test_rule_setup() -> Dictionary[String, Variant]:
	var setup: Dictionary[String, Variant] = {}

	# Use the SAME preloaded tilemap that the test environments use
	# This is critical for reproducing the actual integration test conditions
	var packed_tilemap: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var tile_map: TileMapLayer = packed_tilemap.instantiate() as TileMapLayer
	add_child(tile_map)
	auto_free(tile_map)

	# Verify the tilemap has the expected dimensions and TileData
	var used_rect: Rect2i = tile_map.get_used_rect()
	var expected_rect: Rect2i = Rect2i(-15, -15, 31, 31)  # From (-15, -15) to (15, 15) inclusive
	assert(
		used_rect == expected_rect,
		(
			"Preloaded tilemap should have expected dimensions: %s, got: %s"
			% [expected_rect, used_rect]
		)
	)

	setup["tile_map"] = tile_map
	setup["tile_set"] = tile_map.tile_set

	# Create targeting state
	var targeting_state: GridTargetingState = GridTargetingState.new(GBOwnerContext.new())
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]

	# Create positioner
	var positioner: Node2D = auto_free(Node2D.new())
	add_child(positioner)
	targeting_state.positioner = positioner

	# Create target (like placer in integration test)
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	targeting_state.set_manual_target(target)

	setup["targeting_state"] = targeting_state
	setup["positioner"] = positioner
	setup["target"] = target

	return setup


# UNIT TEST TO VALIDATE PRELOADED TILEMAP CONFIGURATION
# This test verifies that the preloaded tilemap has proper TileData setup
# that should allow WithinTilemapBoundsRule to pass validation
func test_preloaded_tilemap_has_valid_tile_data() -> void:
	var packed_tilemap: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var tile_map: TileMapLayer = packed_tilemap.instantiate() as TileMapLayer
	add_child(tile_map)
	auto_free(tile_map)

	# Verify basic tilemap properties
	(
		assert_object(tile_map) \
		. append_failure_message("TileMapLayer should instantiate successfully from packed scene") \
		. is_not_null()
	)
	(
		assert_object(tile_map.tile_set) \
		. append_failure_message("TileMapLayer should have a valid tile_set") \
		. is_not_null()
	)

	var used_rect: Rect2i = tile_map.get_used_rect()
	var expected_rect: Rect2i = Rect2i(-15, -15, 31, 31)
	(
		assert_that(used_rect) \
		. append_failure_message(
			(
				"Tilemap used rect should match integration test: expected %s, got %s"
				% [expected_rect, used_rect]
			)
		) \
		. is_equal(expected_rect)
	)
	var tile_size: Vector2i = tile_map.tile_set.tile_size
	var expected_tile_size: Vector2i = Vector2i(16, 16)
	assert_vector(Vector2(tile_size)).is_equal(Vector2(expected_tile_size)).append_failure_message(
		(
			"Tilemap tile_size should match integration test: expected %s, got %s"
			% [expected_tile_size, tile_size]
		)
	)

	# Test the exact position from the failing integration test
	var integration_test_world_pos: Vector2 = Vector2(8.0, 8.0)  # "Positioner position: (8.0, 8.0)"
	var integration_test_tile: Vector2i = tile_map.local_to_map(
		tile_map.to_local(integration_test_world_pos)
	)

	# This should be tile (0, 0) based on 16x16 tiles and 8.0 world position
	var expected_tile: Vector2i = Vector2i(0, 0)
	(
		assert_vector(Vector2(integration_test_tile)) \
		. append_failure_message("Integration test position should map to expected tile") \
		. is_equal(Vector2(expected_tile))
	)

	# Verify that tile (0,0) has valid TileData
	var tile_data: TileData = tile_map.get_cell_tile_data(expected_tile)
	(
		assert_object(tile_data) \
		. append_failure_message(
			(
				"Integration test tile position %s should have valid TileData for "
				+ "WithinTilemapBoundsRule to pass" % expected_tile
			)
		) \
		. is_not_null()
	)


# UNIT TEST TO REPRODUCE INTEGRATION FAILURE: WithinTilemapBoundsRule
# This reproduces the template_rule_pass failure where rule fails even when position is within bounds
# Integration test shows: Positioner position: (8.0, 8.0), Map used rect: [P: (-15, -15), S: (31, 31)],
# Position within bounds: true
func test_within_tilemap_bounds_rule_at_valid_position() -> void:
	var setup: Dictionary[String, Variant] = _create_test_rule_setup()
	var targeting_state: GridTargetingState = setup["targeting_state"]
	var positioner: Node2D = setup["positioner"]
	var target: Node2D = setup["target"]

	# Set positions exactly like the failing integration test
	positioner.global_position = Vector2(8.0, 8.0)  # Same as integration test
	target.global_position = Vector2(0.0, 0.0)  # Same as integration test

	# Create the rule
	var rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	rule.setup(targeting_state)

	# Allow frame for setup (use runner for deterministic frame simulation)
	runner.simulate_frames(1)

	# Create a test indicator at the positioner position like integration test does
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	# Set shape BEFORE adding to scene tree to avoid assertion failure
	test_indicator.shape = RectangleShape2D.new()
	(test_indicator.shape as RectangleShape2D).size = Vector2.ONE

	# Assign the rule to the indicator so it can properly validate
	test_indicator.add_rule(rule)

	add_child(test_indicator)
	test_indicator.global_position = positioner.global_position  # (8.0, 8.0)

	# Force physics update and allow _ready() to process
	runner.simulate_frames(2)

	# Force validity evaluation to eliminate any timing issues
	# This ensures the indicator has evaluated all rules immediately
	test_indicator.force_validity_evaluation()

	# Test the rule directly
	var failing_indicators: Array[RuleCheckIndicator] = rule.get_failing_indicators(
		[test_indicator]
	)
	var is_valid: bool = failing_indicators.size() == 0

	(
		assert_bool(is_valid) \
		. append_failure_message(
			(
				"WITHIN TILEMAP BOUNDS RULE UNIT TEST FAILURE:\nThis reproduces the integration test failure. "
				+ "Position should be within tilemap bounds but rule is failing."
			)
		) \
		. is_true()
	)


# Test rule with position outside bounds to verify it correctly fails
func test_within_tilemap_bounds_rule_at_invalid_position() -> void:
	var setup: Dictionary[String, Variant] = _create_test_rule_setup()
	var tile_map: TileMapLayer = setup["tile_map"]
	var targeting_state: GridTargetingState = setup["targeting_state"]

	# Create rule
	var rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	rule.setup(targeting_state)

	await get_tree().process_frame

	# Create indicator at position definitely outside bounds
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	# Set shape BEFORE adding to scene tree to avoid assertion failure
	test_indicator.shape = RectangleShape2D.new()
	(test_indicator.shape as RectangleShape2D).size = Vector2.ONE

	# Assign the rule to the indicator so it can properly validate
	test_indicator.add_rule(rule)

	add_child(test_indicator)
	test_indicator.global_position = Vector2(1000.0, 1000.0)  # Way outside bounds

	runner.simulate_frames(2)

	# Force validity evaluation to eliminate timing issues
	test_indicator.force_validity_evaluation()

	# Debug ValidationResults directly (buffered)
	var validation_results: ValidationResults = rule._is_over_valid_tile(test_indicator, tile_map)
	GBTestDiagnostics.log_verbose("DEBUG ValidationResults:")
	GBTestDiagnostics.log_verbose("  is_successful(): %s" % [validation_results.is_successful()])
	GBTestDiagnostics.log_verbose("  has_errors(): %s" % [validation_results.has_errors()])
	GBTestDiagnostics.log_verbose("  get_errors(): %s" % [validation_results.get_errors()])
	GBTestDiagnostics.log_verbose(
		"  has_failing_rules(): %s" % [validation_results.has_failing_rules()]
	)

	# Test the rule - should fail for out of bounds position
	var failing_indicators: Array[RuleCheckIndicator] = rule.get_failing_indicators(
		[test_indicator]
	)
	var is_valid: bool = failing_indicators.size() == 0

	# This should fail since position is outside bounds
	(
		assert_bool(is_valid) \
		. append_failure_message("WithinTilemapBoundsRule should fail for out-of-bounds position") \
		. is_false()
	)


# Test edge case: position exactly on boundary
@warning_ignore("unused_parameter")
func test_within_tilemap_bounds_rule_boundary_positions(
	boundary_description: String,
	tile_position: Vector2i,
	expected_valid: bool,
	test_parameters := [
		["top_left_corner", Vector2i(-15, -15), true],
		["bottom_right_corner", Vector2i(15, 15), true],
		["center", Vector2i(0, 0), true],
		["outside_top_left", Vector2i(-16, -16), false],
		["outside_bottom_right", Vector2i(16, 16), false]
	]
) -> void:
	var setup: Dictionary[String, Variant] = _create_test_rule_setup()
	var tile_map: TileMapLayer = setup["tile_map"]
	var targeting_state: GridTargetingState = setup["targeting_state"]

	var rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	rule.setup(targeting_state)
	await get_tree().process_frame

	# Create indicator at the boundary position
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	# Set shape BEFORE adding to scene tree to avoid assertion failure
	test_indicator.shape = RectangleShape2D.new()
	(test_indicator.shape as RectangleShape2D).size = Vector2.ONE

	# Assign the rule to the indicator so it can properly validate
	test_indicator.add_rule(rule)

	add_child(test_indicator)
	var world_position: Vector2 = tile_map.to_global(tile_map.map_to_local(tile_position))
	test_indicator.global_position = world_position

	runner.simulate_frames(2)

	# Force validity evaluation to eliminate timing issues
	test_indicator.force_validity_evaluation()

	# Debug ValidationResults for failing cases (buffered)
	if not expected_valid:
		var validation_results: ValidationResults = rule._is_over_valid_tile(
			test_indicator, tile_map
		)
		GBTestDiagnostics.log_verbose(
			"DEBUG ValidationResults for '%s' at %s:" % [boundary_description, str(tile_position)]
		)
		GBTestDiagnostics.log_verbose(
			"  is_successful(): %s" % [validation_results.is_successful()]
		)
		GBTestDiagnostics.log_verbose("  has_errors(): %s" % [validation_results.has_errors()])
		GBTestDiagnostics.log_verbose("  get_errors(): %s" % [validation_results.get_errors()])

	var failing_indicators: Array[RuleCheckIndicator] = rule.get_failing_indicators(
		[test_indicator]
	)
	var is_valid: bool = failing_indicators.size() == 0

	var used_rect: Rect2i = tile_map.get_used_rect()
	(
		assert_bool(is_valid) \
		. append_failure_message(
			(
				"Boundary test '%s': tile %s should be %s. Used rect: %s, Within bounds: %s, Rule result: %s"
				% [
					boundary_description,
					str(tile_position),
					"valid" if expected_valid else "invalid",
					str(used_rect),
					str(used_rect.has_point(tile_position)),
					"valid" if is_valid else "invalid"
				]
			)
		) \
		. is_equal(expected_valid)
	)


# UNIT TEST TO REPRODUCE INTEGRATION FAILURE: Multiple rules validation
# This reproduces the multiple_rules_pass failure where individual rules pass but combination fails
# Integration test shows: 4 indicators with valid=true and colliding=false, but overall validation fails
func test_multiple_rules_validation_combination() -> void:
	var setup: Dictionary[String, Variant] = _create_test_rule_setup()
	var targeting_state: GridTargetingState = setup["targeting_state"]
	var positioner: Node2D = setup["positioner"]
	var target: Node2D = setup["target"]

	# Set positions like integration test
	positioner.global_position = Vector2(8.0, 8.0)
	target.global_position = Vector2(0.0, 0.0)

	# Create the same rule combination as integration test multiple_valid scenario
	var bounds_rule: WithinTilemapBoundsRule = WithinTilemapBoundsRule.new()
	bounds_rule.setup(targeting_state)

	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.pass_on_collision = false  # Same as integration test
	collision_rule.collision_mask = 2  # Same as integration test (different layer, no collision)
	collision_rule.apply_to_objects_mask = 2  # Same as integration test
	collision_rule.setup(targeting_state)

	await get_tree().process_frame

	# Create test indicator like integration test
	var test_indicator: RuleCheckIndicator = auto_free(RuleCheckIndicator.new())
	# Set shape BEFORE adding to scene tree to avoid assertion failure
	test_indicator.shape = RectangleShape2D.new()
	(test_indicator.shape as RectangleShape2D).size = Vector2.ONE
	test_indicator.collision_mask = 2  # Match the collision rule

	# Assign both rules to the indicator so it can properly validate
	test_indicator.add_rule(bounds_rule)
	test_indicator.add_rule(collision_rule)

	add_child(test_indicator)
	test_indicator.global_position = positioner.global_position

	runner.simulate_frames(2)

	# Force validity evaluation to eliminate timing issues
	test_indicator.force_validity_evaluation()

	# Test each rule individually first
	var bounds_failing: Array[RuleCheckIndicator] = bounds_rule.get_failing_indicators(
		[test_indicator]
	)
	var bounds_valid: bool = bounds_failing.size() == 0

	var collision_failing: Array[RuleCheckIndicator] = collision_rule.get_failing_indicators(
		[test_indicator]
	)
	var collision_valid: bool = collision_failing.size() == 0

	# Test combined validation (both rules must pass)
	var all_rules: Array[TileCheckRule] = [bounds_rule, collision_rule]
	var combined_failing: Array[TileCheckRule] = []

	# Simulate the validation logic that happens in PlacementValidator/IndicatorManager
	for rule in all_rules:
		var rule_failing: Array[RuleCheckIndicator] = rule.get_failing_indicators([test_indicator])
		if rule_failing.size() > 0:
			combined_failing.append(rule)

	var combined_valid: bool = combined_failing.size() == 0

	# Generate diagnostics
	# Generate detailed diagnostics using helper
	var diagnostics: String = _generate_multiple_rules_diagnostics(
		bounds_rule, collision_rule, test_indicator
	)

	# Individual rules should pass (like integration test shows valid=true for indicators)
	(
		assert_bool(bounds_valid) \
		. append_failure_message("Bounds rule should pass individually:\n%s" % diagnostics) \
		. is_true()
	)

	(
		assert_bool(collision_valid) \
		. append_failure_message("Collision rule should pass individually:\n%s" % diagnostics) \
		. is_true()
	)

	# Combined validation should also pass (this is where integration test fails)
	(
		assert_bool(combined_valid) \
		. append_failure_message(
			(
				"MULTIPLE RULES VALIDATION UNIT TEST FAILURE:\n%s\nThis reproduces the integration test "
				+ (
					"failure in multiple_rules_pass. Individual rules pass but combined validation fails."
					% diagnostics
				)
			)
		) \
		. is_true()
	)


# DIAGNOSTIC HELPERS for rule validation testing


# Helper to generate bounds rule diagnostics
func _generate_bounds_rule_diagnostics(
	rule: WithinTilemapBoundsRule,
	indicator: RuleCheckIndicator,
	tile_map: TileMapLayer,
	positioner: Node2D,
	target: Node2D
) -> String:
	var diagnostics: String = "WithinTilemapBoundsRule Unit Test Diagnostics:\n"
	diagnostics += (
		"- Positioner position: %s (matches integration test)\n" % str(positioner.global_position)
	)
	diagnostics += (
		"- Target position: %s (matches integration test)\n" % str(target.global_position)
	)
	diagnostics += "- Indicator position: %s\n" % str(indicator.global_position)
	diagnostics += "- Map used rect: %s\n" % str(tile_map.get_used_rect())
	diagnostics += "- Map tile size: %s\n" % str(tile_map.tile_set.tile_size)

	# Convert positions to tile coordinates for analysis
	var positioner_tile: Vector2i = tile_map.local_to_map(
		tile_map.to_local(positioner.global_position)
	)
	var target_tile: Vector2i = tile_map.local_to_map(tile_map.to_local(target.global_position))
	var indicator_tile: Vector2i = tile_map.local_to_map(
		tile_map.to_local(indicator.global_position)
	)
	var used_rect: Rect2i = tile_map.get_used_rect()

	diagnostics += (
		"- Positioner tile: %s (within bounds: %s)\n"
		% [str(positioner_tile), str(used_rect.has_point(positioner_tile))]
	)
	diagnostics += (
		"- Target tile: %s (within bounds: %s)\n"
		% [str(target_tile), str(used_rect.has_point(target_tile))]
	)
	diagnostics += (
		"- Indicator tile: %s (within bounds: %s)\n"
		% [str(indicator_tile), str(used_rect.has_point(indicator_tile))]
	)
	diagnostics += "- Used rect bounds: %s\n" % str(used_rect)
	diagnostics += (
		"- Rule setup successful: %s\n"
		% (str(rule._ready) if rule.has_method("_ready") else "unknown")
	)

	# Check actual TileData at indicator position to diagnose WithinTilemapBoundsRule issue
	var tile_data: TileData = tile_map.get_cell_tile_data(indicator_tile)
	diagnostics += (
		"- TileData at indicator position: %s (null means no tile set)\n"
		% ("valid" if tile_data != null else "null")
	)
	if tile_data != null:
		diagnostics += (
			"- TileData properties: source_id=%d\n" % tile_map.get_cell_source_id(indicator_tile)
		)
	else:
		# If TileData is null, check if we can manually set the tile
		var cell_source_id: int = tile_map.get_cell_source_id(indicator_tile)
		var cell_atlas_coords: Vector2i = tile_map.get_cell_atlas_coords(indicator_tile)
		diagnostics += (
			"- Cell source_id: %d, atlas_coords: %s\n" % [cell_source_id, str(cell_atlas_coords)]
		)

	# CRITICAL: Check indicator runtime issues - this might be the real problem!
	var indicator_issues: Array[String] = indicator.get_runtime_issues()
	diagnostics += (
		"- Indicator runtime issues: %s (empty = valid indicator)\n"
		% ("none" if indicator_issues.is_empty() else str(indicator_issues))
	)
	diagnostics += "- Indicator has shape: %s\n" % ("yes" if indicator.shape != null else "no")
	diagnostics += (
		"- Indicator shape type: %s\n"
		% (indicator.shape.get_class() if indicator.shape != null else "none")
	)
	if indicator.shape != null and indicator.shape is RectangleShape2D:
		diagnostics += (
			"- Rectangle shape size: %s\n" % str((indicator.shape as RectangleShape2D).size)
		)

	return diagnostics


# Helper to generate multiple rules validation diagnostics
func _generate_multiple_rules_diagnostics(
	bounds_rule: WithinTilemapBoundsRule,
	collision_rule: CollisionsCheckRule,
	indicator: RuleCheckIndicator
) -> String:
	var bounds_failing: Array[RuleCheckIndicator] = bounds_rule.get_failing_indicators([indicator])
	var collision_failing: Array[RuleCheckIndicator] = collision_rule.get_failing_indicators(
		[indicator]
	)

	var bounds_valid: bool = bounds_failing.size() == 0
	var collision_valid: bool = collision_failing.size() == 0
	var combined_valid: bool = bounds_valid and collision_valid

	var diagnostics: String = "Multiple Rules Unit Test Diagnostics:\n"
	diagnostics += (
		"- Bounds rule valid: %s (failing count: %d)\n" % [str(bounds_valid), bounds_failing.size()]
	)
	diagnostics += (
		"- Collision rule valid: %s (failing count: %d)\n"
		% [str(collision_valid), collision_failing.size()]
	)
	diagnostics += (
		"- Combined validation valid: %s (failing rules: %d)\n"
		% [str(combined_valid), (1 if not bounds_valid else 0) + (1 if not collision_valid else 0)]
	)
	diagnostics += "- Indicator position: %s\n" % str(indicator.global_position)
	diagnostics += "- Indicator colliding: %s\n" % str(indicator.is_colliding())
	diagnostics += (
		"- Collision rule mask: %d, Indicator mask: %d\n"
		% [collision_rule.collision_mask, indicator.collision_mask]
	)

	return diagnostics
