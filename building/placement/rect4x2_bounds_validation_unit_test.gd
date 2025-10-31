## Unit tests isolating pre-validation bounds for RECT_4X2
## Purpose: Reproduce "Tried placing outside of valid map area" seen in integration
## Strategy: Use IndicatorManager + PlacementValidator directly, compute safe tiles from used_rect,
## and assert pre-validation succeeds at start tile, with rich diagnostics.
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
extends GdUnitTestSuite

# Test constants to eliminate magic numbers
const SAFE_START_TILE := GBTestConstants.ORIGIN_I
const OUTSIDE_OFFSET := 2
const PLACEABLE_RECT_4X2 := GBTestConstants.PLACEABLE_RECT_4X2

var runner: GdUnitSceneRunner
var env: BuildingTestEnvironment
var _building_system: BuildingSystem
var _container: GBCompositionContainer
var _indicator_manager: IndicatorManager
var _placement_validator: PlacementValidator
var _map: TileMapLayer
var _targeting_state: GridTargetingState
var _positioner: Node2D
var _isolation_state: Dictionary


## Test setup and initialization.
func before_test() -> void:
	# MIGRATION: Use scene_runner WITHOUT frame simulation
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV.resource_path)
	env = runner.scene() as BuildingTestEnvironment

	(
		assert_object(env) \
		. append_failure_message("Failed to load BuildingTestEnvironment scene") \
		. is_not_null()
	)

	# Direct property access - type-safe
	_container = env.get_container()
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_placement_validator = _indicator_manager.get_placement_validator()
	_map = env.tile_map_layer
	_positioner = env.positioner
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	_targeting_state = targeting_system.get_state()

	# Set up targeting state
	if _targeting_state.target_map == null:
		_targeting_state.target_map = _map
	_targeting_state.set_manual_target(env.placer)

	# Ensure test-friendly targeting settings (no auto snapping/restriction side-effects)
	_apply_test_targeting_settings()

	# Ensure any existing placement rules are configured with the test targeting state
	# Prefer configuring the rule provided by the composition container (single source-of-truth)
	# instead of creating a duplicate. Call `setup()` so the rules receive the GridTargetingState
	# and are bound to the correct `TileMapLayer` used by the test environment.
	var placement_rules: Array[PlacementRule] = _container.get_placement_rules()

	## Collisions Check Rule + Within Tilemaps Bound Rule
	(
		assert_int(placement_rules.size()) \
		. append_failure_message(
			"[TEST_DEBUG] before_test: placement_rules.size()=%d" % placement_rules.size()
		) \
		. is_equal(2)
	)

	# Diagnostic: assert that all setup rules reference the same map instance as the test _map
	for i in range(placement_rules.size()):
		var r2: PlacementRule = placement_rules[i]
		if r2 == null or not (r2 is PlacementRule):
			continue
		if r2.has_method("get_target_map"):
			var rule_map: TileMapLayer = r2.call("get_target_map") as TileMapLayer
			# If rule exposes the target_map, assert it's the same TileMapLayer instance used by the test
			(
				assert_bool(rule_map == _map) \
				. append_failure_message(
					"PlacementRule at index %d is not bound to the test tilemap (_map)." % i
				) \
				. is_true()
			)

	## Ensure tile map layer meets expectations
	var used_rect: Rect2i = _map.get_used_rect()
	var expected_size: Vector2i = Vector2i(31, 31)
	assert_vector(Vector2(used_rect.size)).is_equal(Vector2(expected_size)).append_failure_message(
		"Tilemap used_rect.size should be %s but was %s" % [expected_size, used_rect.size]
	)

	# Set up test isolation to prevent mouse interference
	_isolation_state = GBTestIsolation.setup_building_test_isolation(
		_positioner, _map, _container.get_logger()
	)


# Helper guard method: Extract complex conditional for targeting settings configuration
func _apply_test_targeting_settings() -> void:
	# Guard: Check if targeting settings path exists
	if not _has_targeting_settings():
		return
	_container.config.settings.targeting.restrict_to_map_area = false
	_container.config.settings.targeting.limit_to_adjacent = false


# Helper guard method: Check if targeting settings are accessible (3+ conditionals)
func _has_targeting_settings() -> bool:
	return (
		_container != null
		and _container.config != null
		and _container.config.settings != null
		and _container.config.settings.targeting != null
	)


# Helper method to move positioner to a specific tile
func _move_positioner_to_tile(target_tile: Vector2i) -> void:
	# Move positioner to target tile and verify
	var local_pos: Vector2 = _map.map_to_local(target_tile)
	var global_pos: Vector2 = _map.to_global(local_pos)
	_positioner.global_position = global_pos


# Helper method to enter build mode for a placeable
func _enter_build_mode_for_placeable(placeable: Placeable) -> PlacementReport:
	var setup_report: PlacementReport = _building_system.enter_build_mode(placeable)
	(
		assert_object(setup_report) \
		. append_failure_message("enter_build_mode returned null") \
		. is_not_null()
	)
	(
		assert_bool(setup_report.is_successful()) \
		. append_failure_message(
			"enter_build_mode should succeed; issues=" + str(setup_report.get_issues())
		) \
		. is_true()
	)
	return setup_report


# Helper method to validate placement and return results
func _validate_placement() -> ValidationResults:
	return _indicator_manager.validate_placement()


# Helper method to get indicator positions as tile coordinates (relative to tile map)
func _get_indicator_tile_positions_as_strings() -> Array[String]:
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	var indicator_tile_positions: Array[String] = []
	for indicator: Object in indicators:
		if indicator != null:
			# Convert indicator's global position to tile coordinates relative to the tile map
			# Result is in tile units (e.g., (17, 3) means tile at x=17, y=3 in tile map coordinates)
			var tile_pos: Vector2i = _map.local_to_map(_map.to_local(indicator.global_position))
			indicator_tile_positions.append(str(tile_pos))
	return indicator_tile_positions


# Helper method to assert validation success with diagnostics
func _assert_validation_success(result: ValidationResults, context_message: String) -> void:
	var indicator_tile_positions: Array[String] = _get_indicator_tile_positions_as_strings()
	var used_rect: Rect2i = _map.get_used_rect()
	var issues: Array[String] = result.get_issues()

	var formatted_message: String = "\n" + context_message + "\n"
	formatted_message += "├─ Validation Issues: " + str(issues) + "\n"
	formatted_message += (
		"├─ Tile Map Used Rect: "
		+ str(used_rect)
		+ " (covers tiles from "
		+ str(used_rect.position)
		+ " to "
		+ str(used_rect.position + used_rect.size - Vector2i.ONE)
		+ ")\n"
	)
	formatted_message += "└─ Indicator Tile Positions (relative to tile map coordinate system):\n"

	# Format indicator positions in a more readable way
	for i in range(indicator_tile_positions.size()):
		var position_str: String = indicator_tile_positions[i]
		var prefix: String = "    "
		if i == indicator_tile_positions.size() - 1:
			prefix += "└─ "
		else:
			prefix += "├─ "
		formatted_message += prefix + position_str
	if i < indicator_tile_positions.size() - 1:
		formatted_message += "\n"

	assert_bool(result.is_successful()).append_failure_message(
		formatted_message
	).is_true()
## Pre validation is successful for rect4x2 start tile.
func test_pre_validation_is_successful_for_rect4x2_start_tile() -> void:
	# Arrange
	# Reset positions to ensure consistent testing regardless of scene layout
	_map.global_position = Vector2(0, 0)
	_positioner.global_position = Vector2(0, 0)

	var start_tile: Vector2i = SAFE_START_TILE
	_move_positioner_to_tile(start_tile)

	# Use actual runtime path: enter build mode to ensure indicators are created
	var placeable: Placeable = PLACEABLE_RECT_4X2

	# Replace raw prints with assert chains so failure reports include these diagnostics
	(
		assert_object(_positioner) \
		. append_failure_message(
			(
				"start_tile=%s positioner.global_position=%s before_build"
				% [str(start_tile), str(_positioner.global_position)]
			)
		) \
		. is_not_null()
	)
	(
		assert_object(_targeting_state) \
		. append_failure_message(
			(
				"targeting_state.positioner.global_position=%s"
				% str(_targeting_state.positioner.global_position)
			)
		) \
		. is_not_null()
	)
	(
		assert_bool(_positioner == _targeting_state.positioner) \
		. append_failure_message(
			"Are they the same object? %s" % str(_positioner == _targeting_state.positioner)
		) \
		. is_true()
	)

	# Ensure the building system uses the correct targeting state
	var targeting_system: GridTargetingSystem = env.grid_targeting_system
	(
		assert_object(targeting_system.get_state().positioner) \
		. append_failure_message(
			(
				"targeting_system.get_state().positioner.global_position=%s"
				% str(targeting_system.get_state().positioner.global_position)
			)
		) \
		. is_not_null()
	)

	_enter_build_mode_for_placeable(placeable)

	# Guard: Some runtime flows may recenter/snap the positioner on entering build mode
	# (e.g., via input). For this unit test we explicitly restore the positioner to the intended
	# start tile before validating.
	_move_positioner_to_tile(start_tile)

	# DEBUG: Check positioner position after build mode
	var positioner_tile_after: Vector2i = _map.local_to_map(
		_map.to_local(_positioner.global_position)
	)
	(
		assert_bool(positioner_tile_after == start_tile) \
		. append_failure_message(
			(
				"Positioner must be on start_tile after setup; positioner_tile_after=%s "
				+ (
					"global_pos=%s start_tile=%s"
					% [
						str(positioner_tile_after),
						str(_positioner.global_position),
						str(start_tile)
					]
				)
			)
		) \
		. is_true()
	)

	# Act
	var result: ValidationResults = _validate_placement()

	# Assert
	_assert_validation_success(
		result, "Pre-validation should pass at start_tile " + str(start_tile)
	)
## Bounds tiles have tile data.


func test_bounds_tiles_have_tile_data() -> void:
	var start_tile: Vector2i = SAFE_START_TILE
	var td: TileData = _map.get_cell_tile_data(start_tile)
	(
		assert_object(td) \
		. append_failure_message(
			(
				"Start tile must have TileData; start_tile="
				+ str(start_tile)
				+ " used_rect="
				+ str(_map.get_used_rect())
			)
		) \
		. is_not_null()
## Pre validation out of bounds outside used rect.
	)


func test_pre_validation_out_of_bounds_outside_used_rect() -> void:
	# Arrange: move clearly outside the used_rect to guarantee OOB
	# Reset positions to ensure consistent testing regardless of scene layout
	_map.global_position = Vector2(0, 0)
	_positioner.global_position = Vector2(0, 0)

	var ur: Rect2i = _map.get_used_rect()
	# Compute an outside tile clearly to the left of used rect
	var outside_tile: Vector2i = Vector2i(ur.position.x - OUTSIDE_OFFSET, ur.position.y)

	# Guard: ensure outside_tile is actually outside used_rect - if not, fail with diagnostic details
	var is_outside: bool = not ur.has_point(outside_tile)
	(
		assert_bool(is_outside) \
		. append_failure_message(
			(
				"Computed outside_tile is not outside used_rect - outside_tile="
				+ str(outside_tile)
				+ " used_rect="
				+ str(ur)
				+ ". Adjust OUTSIDE_OFFSET or inspect map setup."
			)
		) \
		. is_true()
	)

	# Move the positioner and capture tiles for diagnostics
	_move_positioner_to_tile(outside_tile)
	var positioner_tile_after: Vector2i = _map.local_to_map(
		_map.to_local(_positioner.global_position)
	)
	var placeable: Placeable = PLACEABLE_RECT_4X2
	_enter_build_mode_for_placeable(placeable)

	# Act
	var result: ValidationResults = _validate_placement()

	# Collect indicator tile positions for additional diagnostics
	var indicator_positions: Array[String] = _get_indicator_tile_positions_as_strings()

	# Assert: Must fail when obviously outside
	# Build a human-friendly, multi-line failure message
	var failure_message_lines: Array[String] = []
	failure_message_lines.append(
		"Pre-validation failed: expected failure when placement is outside used_rect."
	)
	failure_message_lines.append("  outside_tile: " + str(outside_tile))
	failure_message_lines.append(
		(
			"  used_rect:    "
			+ str(ur)
			+ " (covers tiles from "
			+ str(ur.position)
			+ " to "
			+ str(ur.position + ur.size - Vector2i.ONE)
			+ ")"
		)
	)
	failure_message_lines.append("  positioner_after_tile: " + str(positioner_tile_after))
	failure_message_lines.append("  validator_issues: " + str(result.get_issues()))
	failure_message_lines.append("  indicator_tiles:")
	for pos_str in indicator_positions:
		failure_message_lines.append("    - " + pos_str)

	var failure_message: String = "\n" + "\n".join(failure_message_lines) + "\n"

	assert_bool(result.is_successful()).append_failure_message(
		failure_message
	).is_false()
