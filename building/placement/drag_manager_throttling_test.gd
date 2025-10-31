## DragManager request throttling and gating tests (isolated)
## Tests DragManager's core responsibility: ensuring only ONE build request per tile change per physics frame
## Does NOT depend on BuildingSystem - tests the gating logic in isolation
##
## TESTING PATTERN: Uses GdUnitSceneRunner directly with BuildingTestEnvironment scene
## This pattern is PREFERRED over test factories because:
## - runner.simulate_frames() only works with nodes in the scene tree
## - Test environments already have all components wired and ready (like drag_manager)
## - Factory-created nodes are NOT in scene tree, so physics processing doesn't work
## - Scene runner provides deterministic frame simulation for timing-dependent tests
##
## DEPRECATION NOTE: Consider environment test factories deprecated in favor of scene_runner()
## approach for tests that need frame simulation or physics processing.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: BuildingTestEnvironment
var _container: GBCompositionContainer
var _drag_manager: DragManager
var _targeting_state: GridTargetingState
var _building_system: BuildingSystem


## Sets up test environment with DragManager and building systems for throttling tests.
func before_test() -> void:
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV.resource_path)
	runner.simulate_frames(2)  # Initial setup frames

	env = runner.scene() as BuildingTestEnvironment
	_container = env.get_container()

	# Disable mouse input FIRST to prevent interference
	_container.config.settings.targeting.enable_mouse_input = false

	# Disable camera checks for headless testing
	if _container.config.settings.runtime_checks:
		_container.config.settings.runtime_checks.camera_2d = false

	# Enable trace logging for DragManager debugging
	_container.get_logger().set_log_level(GBDebugSettings.LogLevel.TRACE)

	# Get references EARLY and validate
	_targeting_state = _container.get_states().targeting
	_building_system = _container.get_systems_context().get_building_system()

	# Validate critical references before continuing
	(
		assert_object(_targeting_state) \
		. append_failure_message("GridTargetingState should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state.positioner) \
		. append_failure_message("GridPositioner2D should not be null") \
		. is_not_null()
	)
	(
		assert_object(_building_system) \
		. append_failure_message("BuildingSystem should not be null") \
		. is_not_null()
	)

	# Disable mouse movement and processing on GridPositioner2D for manual control
	_targeting_state.positioner.set_input_processing_enabled(false)
	_targeting_state.positioner.set_process(false)

	# Get drag_manager from environment
	_drag_manager = env.drag_manager
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)

	# Set test mode to disable input processing
	_drag_manager.set_test_mode(true)

	runner.simulate_frames(1)

	# Enter build mode with smithy placeable (has collision shapes for proper indicator generation)
	var test_placeable: Placeable = GBTestConstants.PLACEABLE_SMITHY
	var enter_result: PlacementReport = _building_system.enter_build_mode(test_placeable)
	(
		assert_bool(enter_result.is_successful()) \
		. append_failure_message("Failed to enter build mode: %s" % str(enter_result.get_issues())) \
		. is_true()
	)

	# Verify BUILD mode is active and preview exists
	var mode_state: ModeState = _building_system._states.mode
	var building_state: BuildingState = _building_system._states.building
	(
		assert_that(mode_state.current) \
		. append_failure_message(
			"Should be in BUILD mode, but mode is: %s" % str(mode_state.current)
		) \
		. is_equal(GBEnums.Mode.BUILD)
	)
	(
		assert_object(building_state.preview) \
		. append_failure_message(
			"BuildingSystem should have active preview after entering build mode"
		) \
		. is_not_null()
	)

	runner.simulate_frames(1)


## Cleans up test environment after each test.
func after_test() -> void:
	_drag_manager = null
	_building_system = null
	_targeting_state = null
	_container = null
	env = null
	runner = null


#region REQUEST THROTTLING TESTS


## Tests that no build requests are made when drag has not been started.
func test_no_requests_when_drag_not_started() -> void:
	# No drag started - no requests should be made
	runner.simulate_frames(5)

	# Should be no drag_data
	(
		assert_object(_drag_manager.drag_data) \
		. append_failure_message("drag_data should be null when drag not started") \
		. is_null()
	)


## Tests that no build requests are made when tile position remains unchanged during drag.
func test_no_requests_when_tile_unchanged() -> void:
	# Start drag
	var drag_data: DragPathData = _drag_manager.start_drag()
	var initial_tile: Vector2i = drag_data.target_tile

	# Simulate multiple physics frames WITHOUT moving positioner
	for i in range(5):
		runner.simulate_frames(1)

	# Tile hasn't changed - should be ZERO build requests
	(
		assert_int(drag_data.build_requests) \
		. append_failure_message(
			(
				"No build requests should be made when tile unchanged. Initial tile: %s, Current: %s, Frames: 5"
				% [initial_tile, drag_data.target_tile]
			)
		) \
		. is_equal(0)
	)


## Tests that exactly one build request is made when tile changes during drag.
func test_single_request_on_tile_change() -> void:
	# Validate drag manager state
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)

	# Start drag
	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_tile: Vector2i = drag_data.target_tile
	var initial_requests: int = drag_data.build_requests

	# Move positioner to new tile position
	var tile_map: TileMapLayer = _targeting_state.target_map
	var new_tile_pos: Vector2 = tile_map.map_to_local(Vector2i(1, 0))
	_targeting_state.positioner.global_position = new_tile_pos
	_drag_manager.update_drag_state(0.016)  # Let physics frame process the change

	# Should have made exactly ONE request
	var final_requests: int = drag_data.build_requests
	var requests_made: int = final_requests - initial_requests
	(
		assert_int(requests_made) \
		. append_failure_message(
			(
				"Exactly one build request should be made on tile change. Initial: %s, New: %s, Initial requests: %d, Final: %d, Made: %d"
				% [
					initial_tile,
					drag_data.target_tile,
					initial_requests,
					final_requests,
					requests_made
				]
			)
		) \
		. is_equal(1)
	)


## Tests that physics frame gate blocks multiple requests within the same frame.
func test_physics_frame_gate_blocks_multiple_requests_same_frame() -> void:
	# This tests the _last_signal_physics_frame gate
	# Even if we artificially trigger tile changes multiple times in same frame,
	# only ONE request should go through

	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)

	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_requests: int = drag_data.build_requests
	var tile_map: TileMapLayer = _targeting_state.target_map

	# Move positioner to first new tile
	var old_tile: Vector2i = drag_data.target_tile
	var first_tile_pos: Vector2 = tile_map.map_to_local(Vector2i(old_tile.x + 1, old_tile.y))
	_targeting_state.positioner.global_position = first_tile_pos
	_drag_manager.update_drag_state(0.016)
	var requests_after_first: int = drag_data.build_requests

	# Move to second tile in SAME physics frame (should be gated)
	var second_tile_pos: Vector2 = tile_map.map_to_local(Vector2i(old_tile.x + 2, old_tile.y))
	_targeting_state.positioner.global_position = second_tile_pos
	_drag_manager.update_drag_state(0.016)
	var requests_after_second: int = drag_data.build_requests

	# Should only have ONE new request (the first one), second should be gated
	var first_change_requests: int = requests_after_first - initial_requests
	(
		assert_int(first_change_requests) \
		. append_failure_message(
			(
				"First tile change should trigger request. Initial: %d, After first: %d, Delta: %d"
				% [initial_requests, requests_after_first, first_change_requests]
			)
		) \
		. is_equal(1)
	)

	var second_change_requests: int = requests_after_second - requests_after_first
	(
		assert_int(second_change_requests) \
		. append_failure_message(
			(
				"Second tile change in SAME frame should be BLOCKED by physics frame gate. After first: %d, After second: %d, Delta: %d"
				% [requests_after_first, requests_after_second, second_change_requests]
			)
		) \
		. is_equal(0)
	)


## Tests that multiple tile changes across different frames generate separate requests.
func test_multiple_tile_changes_across_frames() -> void:
	# Validate critical references
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state) \
		. append_failure_message("GridTargetingState should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state.positioner) \
		. append_failure_message("GridPositioner2D should not be null") \
		. is_not_null()
	)

	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_requests: int = drag_data.build_requests
	var tile_map: TileMapLayer = _targeting_state.target_map

	# Move across 3 different tiles, with physics frame advancing between each
	for i in range(3):
		# Reset gate to simulate new physics frame
		_drag_manager.reset_physics_frame_gate()
		# Move positioner to next tile
		var current_tile: Vector2i = drag_data.target_tile
		var next_tile_pos: Vector2 = tile_map.map_to_local(
			Vector2i(current_tile.x + 1, current_tile.y)
		)
		_targeting_state.positioner.global_position = next_tile_pos
		_drag_manager.update_drag_state(0.016)

	# Build diagnostic info
	var final_requests: int = drag_data.build_requests
	var requests_made: int = final_requests - initial_requests
	var manager_drag_data_requests: int = (
		_drag_manager.drag_data.build_requests if _drag_manager.drag_data else -1
	)
	var local_drag_data_id: int = drag_data.get_instance_id()
	var manager_drag_data_id: int = (
		_drag_manager.drag_data.get_instance_id() if _drag_manager.drag_data else -1
	)
	var same_instance: bool = local_drag_data_id == manager_drag_data_id
	var diagnostic: String = (
		"Initial=%d, Final=%d, Made=%d, Manager=%d, Same instance=%s (test_id=%d, manager_id=%d)"
		% [
			initial_requests,
			final_requests,
			requests_made,
			manager_drag_data_requests,
			same_instance,
			local_drag_data_id,
			manager_drag_data_id
		]
	)

	# Should have exactly 3 requests (one per tile change, each in different frame)
	(
		assert_int(requests_made) \
		. append_failure_message(
			"Should have 3 build requests for 3 tile changes across frames. %s" % diagnostic
		) \
		. is_equal(3)
	)


## Tests that last_attempted_tile prevents duplicate requests for the same tile.
func test_last_attempted_tile_prevents_duplicate_requests() -> void:
	# This tests the drag_data.last_attempted_tile check
	# Validate critical references
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state) \
		. append_failure_message("GridTargetingState should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state.positioner) \
		. append_failure_message("GridPositioner2D should not be null") \
		. is_not_null()
	)

	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_tile: Vector2i = drag_data.target_tile
	var initial_requests: int = drag_data.build_requests
	var tile_map: TileMapLayer = _targeting_state.target_map

	# Move positioner to new tile
	var new_tile_pos: Vector2 = tile_map.map_to_local(Vector2i(initial_tile.x + 2, initial_tile.y))
	_targeting_state.positioner.global_position = new_tile_pos
	_drag_manager.update_drag_state(0.016)

	var requests_after_move: int = drag_data.build_requests
	var requests_from_move: int = requests_after_move - initial_requests
	(
		assert_int(requests_from_move) \
		. append_failure_message(
			(
				"Should have made at least one request after tile change. Initial: %d, After: %d, Delta: %d"
				% [initial_requests, requests_after_move, requests_from_move]
			)
		) \
		. is_greater(0)
	)

	# Now advance a frame WITHOUT moving (stays on same tile)
	_drag_manager.reset_physics_frame_gate()
	_drag_manager.update_drag_state(0.016)

	var final_requests: int = drag_data.build_requests
	# Should NOT make another request for the same tile
	(
		assert_int(final_requests) \
		. append_failure_message(
			(
				"Should NOT make duplicate request for same tile. Last attempted: %s, Current: %s, After move: %d, Final: %d"
				% [
					drag_data.last_attempted_tile,
					drag_data.target_tile,
					requests_after_move,
					final_requests
				]
			)
		) \
		. is_equal(requests_after_move)
	)


## Tests that drag sessions are properly isolated with independent request counters.
func test_drag_session_isolation() -> void:
	# Validate critical references
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state) \
		. append_failure_message("GridTargetingState should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state.positioner) \
		. append_failure_message("GridPositioner2D should not be null") \
		. is_not_null()
	)

	# First drag session
	var drag1: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag1) \
		. append_failure_message("First start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var drag1_initial_tile: Vector2i = drag1.target_tile
	var tile_map: TileMapLayer = _targeting_state.target_map
	var new_tile_pos: Vector2 = tile_map.map_to_local(
		Vector2i(drag1_initial_tile.x + 2, drag1_initial_tile.y)
	)
	_targeting_state.positioner.global_position = new_tile_pos
	_drag_manager.update_drag_state(0.016)

	var drag1_requests: int = drag1.build_requests
	(
		assert_int(drag1_requests) \
		. append_failure_message(
			(
				"First drag session should have made at least one request. Requests: %d"
				% drag1_requests
			)
		) \
		. is_greater(0)
	)

	# Stop first drag
	_drag_manager.stop_drag()
	_drag_manager.reset_physics_frame_gate()

	# Start second drag session
	var drag2: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag2) \
		. append_failure_message("Second start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	# Second session should have fresh counter starting at 0
	(
		assert_int(drag2.build_requests) \
		. append_failure_message("New drag session should start with build_requests = 0") \
		. is_equal(0)
	)

	# Make a tile change in second session
	_drag_manager.reset_physics_frame_gate()  # Advance frame first
	var drag2_initial_tile: Vector2i = drag2.target_tile
	var new_tile_pos2: Vector2 = tile_map.map_to_local(
		Vector2i(drag2_initial_tile.x + 2, drag2_initial_tile.y)
	)
	_targeting_state.positioner.global_position = new_tile_pos2
	_drag_manager.update_drag_state(0.016)

	# Second session should track its own requests independently
	(
		assert_int(drag2.build_requests) \
		. append_failure_message(
			(
				"Second drag session should track requests independently. Drag1 requests: %d, Drag2 requests: %d"
				% [drag1_requests, drag2.build_requests]
			)
		) \
		. is_equal(1)
	)


#endregion

#region MODE/PREVIEW REQUIREMENTS TESTS


## Tests that no build requests are made when not in build mode.
func test_no_requests_when_not_in_build_mode() -> void:
	# Validate critical references
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)
	(
		assert_object(_building_system) \
		. append_failure_message("BuildingSystem should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state) \
		. append_failure_message("GridTargetingState should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state.positioner) \
		. append_failure_message("GridPositioner2D should not be null") \
		. is_not_null()
	)

	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_requests: int = drag_data.build_requests

	# Exit build mode
	_building_system.exit_build_mode()
	runner.simulate_frames(1)

	# Move to new tile by setting positioner position
	var current_tile: Vector2i = drag_data.target_tile
	var tile_map: TileMapLayer = _targeting_state.target_map
	var new_tile_pos: Vector2 = tile_map.map_to_local(Vector2i(current_tile.x + 2, current_tile.y))
	_targeting_state.positioner.global_position = new_tile_pos
	runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes

	# Should NOT make request when not in BUILD mode
	var final_requests: int = drag_data.build_requests
	var requests_made: int = final_requests - initial_requests
	(
		assert_int(requests_made) \
		. append_failure_message(
			(
				"Should NOT make build requests when not in BUILD mode. Initial: %d, Final: %d, Made: %d"
				% [initial_requests, final_requests, requests_made]
			)
		) \
		. is_equal(0)
	)


## Tests that no build requests are made when no preview exists.
func test_no_requests_when_no_preview() -> void:
	# Validate critical references
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)
	(
		assert_object(_building_system) \
		. append_failure_message("BuildingSystem should not be null") \
		. is_not_null()
	)
	(
		assert_object(_building_system._states) \
		. append_failure_message("BuildingSystem._states should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state) \
		. append_failure_message("GridTargetingState should not be null") \
		. is_not_null()
	)
	(
		assert_object(_targeting_state.positioner) \
		. append_failure_message("GridPositioner2D should not be null") \
		. is_not_null()
	)

	# Start drag in build mode with preview
	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_requests: int = drag_data.build_requests

	# Manually clear preview (simulate preview destruction)
	_building_system._states.building.preview = null

	# Move to new tile by setting positioner position
	var current_tile: Vector2i = drag_data.target_tile
	var tile_map: TileMapLayer = _targeting_state.target_map
	var new_tile_pos: Vector2 = tile_map.map_to_local(Vector2i(current_tile.x + 2, current_tile.y))
	_targeting_state.positioner.global_position = new_tile_pos
	runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes

	# Should NOT make request when no preview exists
	var final_requests: int = drag_data.build_requests
	var requests_made: int = final_requests - initial_requests
	(
		assert_int(requests_made) \
		. append_failure_message(
			(
				"Should NOT make build requests when no active preview. Initial: %d, Final: %d, Made: %d"
				% [initial_requests, final_requests, requests_made]
			)
		) \
		. is_equal(0)
	)


#endregion

#region REQUEST COUNTING ACCURACY


## Tests that build_requests counter only increments when all gating conditions are met.
func test_build_requests_counts_only_successful_gate_passes() -> void:
	# This verifies that build_requests ONLY increments when ALL conditions are met:
	# 1. Tile changed
	# 2. Physics frame gate passed
	# 3. Not duplicate tile
	# 4. In BUILD mode
	# 5. Preview exists

	# Validate critical references
	(
		assert_object(_drag_manager) \
		. append_failure_message("DragManager should not be null") \
		. is_not_null()
	)

	var drag_data: DragPathData = _drag_manager.start_drag()
	(
		assert_object(drag_data) \
		. append_failure_message("start_drag() should return valid DragPathData") \
		. is_not_null()
	)

	var initial_requests: int = drag_data.build_requests
	(
		assert_int(initial_requests) \
		. append_failure_message("Initial build_requests should be 0, got %d" % initial_requests) \
		. is_equal(0)
	)

	# Condition: All requirements met - change tile by moving positioner
	var start_tile: Vector2i = drag_data.target_tile
	var tile_map: TileMapLayer = _targeting_state.target_map
	var new_tile_pos1: Vector2 = tile_map.map_to_local(Vector2i(1, 0))  # Move to tile (1, 0)
	_targeting_state.positioner.global_position = new_tile_pos1

	# Manually call update_drag_state to apply tile change
	_drag_manager.update_drag_state(0.016)
	runner.simulate_frames(1)

	var requests_after_first: int = drag_data.build_requests
	var first_delta: int = requests_after_first - initial_requests
	var diagnostic_1: String = (
		"After first move: initial=%d, after_first=%d, delta=%d, start_tile=%s, target_tile=%s"
		% [initial_requests, requests_after_first, first_delta, start_tile, drag_data.target_tile]
	)
	(
		assert_int(first_delta) \
		. append_failure_message("Should count when all conditions met. %s" % diagnostic_1) \
		. is_equal(1)
	)

	# Condition: Tile unchanged - should NOT count
	_drag_manager.update_drag_state(0.016)  # No tile change
	var requests_after_no_change: int = drag_data.build_requests
	var no_change_delta: int = requests_after_no_change - requests_after_first
	(
		assert_int(no_change_delta) \
		. append_failure_message(
			(
				"Should NOT count when tile unchanged. After first: %d, After no change: %d, Delta: %d"
				% [requests_after_first, requests_after_no_change, no_change_delta]
			)
		) \
		. is_equal(0)
	)

	# Condition: Same tile position again (no move) - should NOT count (duplicate prevention)
	_drag_manager.update_drag_state(0.016)  # No tile change
	var requests_after_duplicate: int = drag_data.build_requests
	var duplicate_delta: int = requests_after_duplicate - requests_after_no_change
	(
		assert_int(duplicate_delta) \
		. append_failure_message(
			(
				"Should NOT count duplicate tile. After no change: %d, After duplicate: %d, Delta: %d"
				% [requests_after_no_change, requests_after_duplicate, duplicate_delta]
			)
		) \
		. is_equal(0)
	)

	# Condition: New tile, all good - should count
	# Reset physics frame gate to simulate advancing to new physics frame
	_drag_manager.reset_physics_frame_gate()

	var new_tile_pos2: Vector2 = tile_map.map_to_local(Vector2i(2, 0))  # Move to tile (2, 0)
	_targeting_state.positioner.global_position = new_tile_pos2
	# Call update_drag_state directly - no need to wait for physics frames
	_drag_manager.update_drag_state(0.016)

	var requests_after_second: int = drag_data.build_requests
	var second_delta: int = requests_after_second - requests_after_duplicate
	var total_delta: int = requests_after_second - initial_requests
	var diagnostic_2: String = (
		"After second move: duplicate=%d, after_second=%d, second_delta=%d, total_delta=%d, same_instance=%s"
		% [
			requests_after_duplicate,
			requests_after_second,
			second_delta,
			total_delta,
			(
				drag_data.get_instance_id()
				== (_drag_manager.drag_data.get_instance_id() if _drag_manager.drag_data else -1)
			)
		]
	)
	(
		assert_int(total_delta) \
		. append_failure_message("Should count new tile with all conditions met. %s" % diagnostic_2) \
		. is_equal(2)
	)

#endregion
