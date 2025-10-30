## Integration tests for GridPositioner2D positioning behavior
##
## These tests validate GridPositioner2D positioning logic by calling methods directly
## rather than simulating input events. This approach ensures:
## - Zero user input interference during test execution
## - Deterministic, repeatable test results
## - Fast execution without await/frame simulation overhead
## - Clear test intent (testing positioning logic, not input handling)
extends GdUnitTestSuite

const TILE_SIZE: int = 16

var env: CollisionTestEnvironment
var runner: GdUnitSceneRunner
var positioner: GridPositioner2D
var tile_map: TileMapLayer


func before_test() -> void:
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV)
	runner.simulate_frames(2)
	env = runner.scene() as CollisionTestEnvironment

	# Cache frequently used references
	positioner = env.positioner
	tile_map = env.tile_map_layer

	# Configure settings for positioning tests
	var container: GBCompositionContainer = env.get_container()
	container.config.settings.targeting.enable_mouse_input = true
	container.config.settings.targeting.enable_keyboard_input = true
	container.config.settings.targeting.restrict_to_map_area = false
	container.config.settings.targeting.limit_to_adjacent = false

	# Ensure positioner is ready for testing
	positioner.set_input_processing_enabled(true)
	positioner.process_mode = Node.PROCESS_MODE_INHERIT

	runner.simulate_frames(1)


func after_test() -> void:
	pass
	# Cleanup handled by auto_free


#region HELPER METHODS


## Move positioner to tile and verify position
func _move_to_tile_and_verify(target_tile: Vector2i) -> void:
	GBPositioning2DUtils.move_to_tile_center(positioner, target_tile, tile_map)
	var expected_global: Vector2 = tile_map.to_global(tile_map.map_to_local(target_tile))
	var actual_global: Vector2 = positioner.global_position
	var delta_px: float = expected_global.distance_to(actual_global)
	(
		assert_vector(actual_global) \
		. append_failure_message(
			(
				"Position tile %s: expected_global=%s, actual=%s, delta=%.2fpx"
				% [str(target_tile), str(expected_global), str(actual_global), delta_px]
			)
		) \
		. is_equal_approx(expected_global, Vector2.ONE)
	)


## Get current tile position
func _get_current_tile() -> Vector2i:
	return GBPositioning2DUtils.get_tile_from_global_position(positioner.global_position, tile_map)


## Assert positioner is at expected tile
func _assert_at_tile(expected_tile: Vector2i, context: String) -> void:
	var actual_tile := _get_current_tile()
	(
		assert_that(actual_tile) \
		. append_failure_message(
			(
				"%s: expected=%s, actual=%s, pos=%s"
				% [context, str(expected_tile), str(actual_tile), str(positioner.global_position)]
			)
		) \
		. is_equal(expected_tile)
	)


#endregion

#region DEPENDENCY INJECTION TESTS


func test_injector_injects_positioner_and_settings() -> void:
	var injector: GBInjectorSystem = env.injector
	var container: GBCompositionContainer = env.get_container()

	assert_object(env).append_failure_message("Environment missing").is_not_null()
	assert_object(injector).append_failure_message("GBInjectorSystem missing").is_not_null()
	assert_object(container).append_failure_message("GBCompositionContainer missing").is_not_null()
	assert_object(positioner).append_failure_message("GridPositioner2D missing").is_not_null()

	var meta_present := positioner.has_meta(GBInjectorSystem.INJECTION_META_KEY)
	(
		assert_bool(meta_present) \
		. append_failure_message("Positioner must have injector meta after injection") \
		. is_true()
	)

	if meta_present:
		var meta: Dictionary[String, Variant] = positioner.get_meta(
			GBInjectorSystem.INJECTION_META_KEY
		)
		var expected_id: int = int(injector.get_instance_id())
		var actual_id: int = meta.get("injector_id", -1)
		(
			assert_int(actual_id) \
			. append_failure_message(
				(
					"Injector ID: expected=%d, actual=%d, meta_keys=%s"
					% [expected_id, actual_id, str(meta.keys())]
				)
			) \
			. is_equal(expected_id)
		)

	var issues: Array[String] = positioner.get_runtime_issues()
	(
		assert_array(issues) \
		. append_failure_message(
			"GridPositioner2D should have no runtime issues post-injection, got: %s" % str(issues)
		) \
		. is_empty()
	)


#endregion

#region TILE POSITIONING TESTS


func test_positioner_moves_to_specific_tile() -> void:
	_move_to_tile_and_verify(Vector2i(10, 10))


func test_keyboard_tile_movement() -> void:
	var start_tile := Vector2i(5, 5)
	GBPositioning2DUtils.move_to_tile_center(positioner, start_tile, tile_map)

	positioner._move_positioner_by_tile(Vector2i(0, -1))
	_assert_at_tile(Vector2i(5, 4), "After UP")

	positioner._move_positioner_by_tile(Vector2i(0, 1))
	_assert_at_tile(Vector2i(5, 5), "After DOWN")

	positioner._move_positioner_by_tile(Vector2i(-1, 0))
	_assert_at_tile(Vector2i(4, 5), "After LEFT")

	positioner._move_positioner_by_tile(Vector2i(1, 0))
	_assert_at_tile(Vector2i(5, 5), "After RIGHT")


#endregion

#region VIEWPORT CENTERING TESTS


func test_move_to_viewport_center() -> void:
	var result_tile: Vector2i = positioner.move_to_viewport_center_tile()
	var is_valid: bool = result_tile != Vector2i(-1, -1)
	(
		assert_bool(is_valid) \
		. append_failure_message(
			"move_to_viewport_center_tile() returned invalid: %s" % str(result_tile)
		) \
		. is_true()
	)
	_assert_at_tile(result_tile, "After viewport center")


#endregion

#region MULTIPLE MOVEMENT TESTS


func test_combined_movements() -> void:
	GBPositioning2DUtils.move_to_tile_center(positioner, Vector2i(10, 10), tile_map)
	_assert_at_tile(Vector2i(10, 10), "Initial position")

	positioner._move_positioner_by_tile(Vector2i(2, 0))
	_assert_at_tile(Vector2i(12, 10), "After keyboard RIGHT 2")

	GBPositioning2DUtils.move_to_tile_center(positioner, Vector2i(5, 5), tile_map)
	_assert_at_tile(Vector2i(5, 5), "After direct position")

	var center_tile := positioner.move_to_viewport_center_tile()
	_assert_at_tile(center_tile, "After viewport center")


#endregion

#region COORDINATE CONVERSION TESTS


func test_coordinate_conversions() -> void:
	var test_tiles: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(5, 5), Vector2i(10, 10), Vector2i(15, 15)
	]

	for tile in test_tiles:
		GBPositioning2DUtils.move_to_tile_center(positioner, tile, tile_map)
		var result_tile := _get_current_tile()
		var global_pos := positioner.global_position
		(
			assert_that(result_tile) \
			. append_failure_message(
				(
					"Round-trip: target=%s, global=%s, result=%s, delta=%s"
					% [str(tile), str(global_pos), str(result_tile), str(tile - result_tile)]
				)
			) \
			. is_equal(tile)
		)


#endregion

#region RUNTIME VALIDATION TESTS


func test_runtime_issues_when_dependencies_missing() -> void:
	# Create positioner in isolation to avoid auto-injection from test environment
	var isolated_scene := Node.new()
	var test_positioner: GridPositioner2D = GridPositioner2D.new()
	isolated_scene.add_child(test_positioner)
	auto_free(isolated_scene)

	var issues: Array[String] = test_positioner.get_runtime_issues()
	var issue_count: int = issues.size()

	(
		assert_array(issues) \
		. append_failure_message(
			(
				"Positioner without dependencies should report issues, got %d: %s"
				% [issue_count, str(issues)]
			)
		) \
		. is_not_empty()
	)

	var min_expected: int = 3
	(
		assert_int(issue_count) \
		. append_failure_message(
			(
				"Expected >= %d dependency issues, got %d: %s"
				% [min_expected, issue_count, str(issues)]
			)
		) \
		. is_greater_equal(min_expected)
	)

#endregion
