## Minimal integration test to isolate the trapezoid shape indicator generation issue.
## This test specifically reproduces the issue where the trapezoid shape from the demo
## is not generating rule check indicators at the bottom left and bottom right positions.
extends GdUnitTestSuite

const TRAPEZOID_POSITION: Vector2 = Vector2(440, 552)  # From runtime scene analysis

## Factory method for creating the exact trapezoid from runtime analysis
static func create_trapezoid_from_runtime() -> PackedVector2Array:
	# Matches the "SimpleTrapezoid" from runtime_scene_analysis.txt
	# Polygon: [(-32.0, 12.0), (-16.0, -12.0), (17.0, -12.0), (32.0, 12.0)]
	return PackedVector2Array([
		Vector2(-32, 12),
		Vector2(-16, -12),
		Vector2(17, -12),
		Vector2(32, 12)
	])

var _env: BuildingTestEnvironment
var _collision_mapper: CollisionMapper
var _targeting_state: GridTargetingState
var _indicator_manager: IndicatorManager

func before_test() -> void:
	_env = EnvironmentTestFactory.create_building_system_test_environment(self)
	_collision_mapper = _env.indicator_manager.get_collision_mapper()
	_targeting_state = _env.grid_targeting_system.get_state()
	_indicator_manager = _env.indicator_manager

	# Validate environment setup
	assert_object(_collision_mapper)
  .append_failure_message("CollisionMapper should be initialized in test environment").is_not_null()
	assert_object(_targeting_state).append_failure_message("GridTargetingState should be initialized in test environment").is_not_null()
	assert_object(_indicator_manager)
  .append_failure_message("IndicatorManager should be initialized in test environment").is_not_null()

## Test that focuses on isolating the trapezoid indicator generation issue
func test_trapezoid_full_pipeline_integration() -> void:
	GBTestDiagnostics.buffer("[TRAPEZOID] === FULL PIPELINE TEST ===")

	# 1) Create the trapezoid test object
	var trapezoid_polygon: PackedVector2Array = create_trapezoid_from_runtime()
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = "TrapezoidFullTest"
	test_object.global_position = TRAPEZOID_POSITION

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = trapezoid_polygon
	collision_shape.shape = shape
	test_object.add_child(collision_shape)

	# Add to scene tree
	_env.add_child(test_object)
	auto_free(test_object)

	# 2) Set targeting state
	_targeting_state.set_manual_target(test_object)
	_targeting_state.positioner.global_position = TRAPEZOID_POSITION

	GBTestDiagnostics.buffer("[TRAPEZOID] Test object created at position: %s" % str(test_object.global_position))

	# 3) Test collision geometry calculation directly first
	var tile_size: Vector2 = Vector2(16, 16)
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		trapezoid_polygon, TRAPEZOID_POSITION, tile_size
	)
	GBTestDiagnostics.buffer("[TRAPEZOID] Direct collision calculation found %d tile offsets:" % tile_offsets.size())

	# Sort for consistent output
	var sorted_offsets: Array[Vector2i] = tile_offsets.duplicate()
	sorted_offsets.sort()
	for offset in sorted_offsets:
			GBTestDiagnostics.buffer("[TRAPEZOID]   tile offset: %s" % str(offset))

	# 4) Expected missing tiles from runtime analysis
	var expected_missing_tiles: Array[Vector2i] = [
		Vector2i(-2, 1),  # Bottom left extension
		Vector2i(2, 1)    # Bottom right extension
	]

	GBTestDiagnostics.buffer("[TRAPEZOID] Checking for expected missing tiles:")
	for tile: Vector2i in expected_missing_tiles:
		var is_present: bool = tile_offsets.has(tile)
		GBTestDiagnostics.buffer("[TRAPEZOID]   tile %s present in calculations: %s" % [str(tile), is_present])
		if not is_present:
			GBTestDiagnostics.buffer("[TRAPEZOID]   >>> COLLISION CALCULATION ISSUE: Tile %s missing from direct calculations!" % str(tile))

	# 5) Now test the full indicator generation pipeline
	var collision_rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	var placement_rules: Array[PlacementRule] = [collision_rule]

	GBTestDiagnostics.buffer("[TRAPEZOID] Running IndicatorManager.try_setup with %d placement rules" % placement_rules.size())
	var report: PlacementReport = _indicator_manager.try_setup(placement_rules, _targeting_state, true)

	assert_object(report).append_failure_message("PlacementReport is null\n%s" % GBTestDiagnostics.flush_for_assert()).is_not_null()

	if not report.is_successful():
		GBTestDiagnostics.buffer("[TRAPEZOID] Placement failed with issues: %s" % str(report.get_issues()))
		fail("Placement report indicates failure - %s" % GBTestDiagnostics.flush_for_assert())

	# 6) Extract generated indicators
	var indicators: Array[RuleCheckIndicator] = report.indicators_report.indicators
	GBTestDiagnostics.buffer("[TRAPEZOID] Generated indicators count: %d" % indicators.size())

	# Extract indicator positions from their names (format: "RuleCheckIndicator-Offset(X,Y)")
	var indicator_positions: Array[Vector2i] = []
	for indicator: RuleCheckIndicator in indicators:
		var name_parts: PackedStringArray = indicator.name.split("-Offset(")
		if name_parts.size() >= 2:
			var offset_str: String = name_parts[1].split(")")[0]
			var offset_parts: PackedStringArray = offset_str.split(",")
			if offset_parts.size() >= 2:
				var offset_x: int = int(offset_parts[0])
				var offset_y: int = int(offset_parts[1])
				var offset: Vector2i = Vector2i(offset_x, offset_y)
				indicator_positions.append(offset)

	indicator_positions.sort()  # Sort for consistent output
	GBTestDiagnostics.buffer("[TRAPEZOID] Generated indicator positions:")
	for pos in indicator_positions:
		GBTestDiagnostics.buffer("[TRAPEZOID]   indicator position: %s" % str(pos))

	# 7) Check for the missing positions from runtime
	GBTestDiagnostics.buffer("[TRAPEZOID] Checking if missing positions are generated:")
	for pos: Vector2i in expected_missing_tiles:
		var has_indicator: bool = indicator_positions.has(pos)
		GBTestDiagnostics.buffer("[TRAPEZOID]   position %s has indicator: %s" % [str(pos), has_indicator])

		if not has_indicator:
			GBTestDiagnostics.buffer("[TRAPEZOID]   >>> ISSUE CONFIRMED: Position %s missing from indicators!" % str(pos))
		else:
			GBTestDiagnostics.buffer("[TRAPEZOID]   >>> SUCCESS: Position %s correctly generated!" % str(pos))

	# 8) Compare collision calculations to indicator generation
	GBTestDiagnostics.buffer("[TRAPEZOID] COMPARISON:")
	GBTestDiagnostics.buffer("[TRAPEZOID]   Direct collision calculation tiles: %d" % tile_offsets.size())
	GBTestDiagnostics.buffer("[TRAPEZOID]   Generated indicators: %d" % indicators.size())

	if tile_offsets.size() != indicators.size():
		GBTestDiagnostics.buffer("[TRAPEZOID]   >>> MISMATCH: Different count between calculations and indicators!")

		# Find missing tiles
		for calc_tile in sorted_offsets:
			if not indicator_positions.has(calc_tile):
				GBTestDiagnostics.buffer("[TRAPEZOID]   >>> LOST IN PIPELINE: Tile %s calculated but no indicator generated" % str(calc_tile))
	else:
		GBTestDiagnostics.buffer("[TRAPEZOID]   >>> COUNTS MATCH: Same number of calculations and indicators")

	# This test helps us identify exactly where in the pipeline the issue occurs
	assert_array(indicators).append_failure_message(
		"No indicators generated for trapezoid shape. Direct collision tiles: %d, Generated indicators: %d, Pipeline match: %s\n%s" % [
			tile_offsets.size(),
			indicators.size(),
			"YES" if tile_offsets.size() == indicators.size() else "NO - Lost in pipeline",
			GBTestDiagnostics.flush_for_assert()
		]
	).is_not_empty()