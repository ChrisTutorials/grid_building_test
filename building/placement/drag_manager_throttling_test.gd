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

func before_test() -> void:
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID)
	runner.simulate_frames(1)
	env = runner.scene() as BuildingTestEnvironment
	_container = env.get_container()
	
	# Get drag_manager from environment
	_drag_manager = env.drag_manager
	print("[TEST SETUP] DragManager physics_processing enabled: %s, in_tree: %s" % [
		_drag_manager.is_physics_processing(),
		_drag_manager.is_inside_tree()
	])
	
	# Disable camera checks for headless testing
	if _container.config.settings.runtime_checks:
		_container.config.settings.runtime_checks.camera_2d = false
	
	# Enable trace logging for DragManager debugging
	if _container.config.settings.debug:
		_container.config.settings.debug.log_level = GBEnums.LogLevel.TRACE
	
	# Set test mode to disable input processing
	_drag_manager.set_test_mode(true)
	
	# Get references FIRST
	_targeting_state = _container.get_states().targeting
	_building_system = _container.get_systems_context().get_building_system()
	
	# Disable mouse movement and processing on GridPositioner2D for manual control
	_targeting_state.positioner.set_input_processing_enabled(false)  # Disable input
	_targeting_state.positioner.set_process(false)  # Disable _process() loop
	print("[TEST SETUP] GridPositioner2D input_processing=%s, process=%s, pos=%s" % [
		_targeting_state.positioner.is_input_processing_enabled(),
		_targeting_state.positioner.is_processing(),
		_targeting_state.positioner.global_position
	])
	
	# Enter build mode with smithy placeable (has collision shapes for proper indicator generation)
	var test_placeable: Placeable = GBTestConstants.PLACEABLE_SMITHY
	var enter_result: PlacementReport = _building_system.enter_build_mode(test_placeable)
	assert_bool(enter_result.is_successful()).is_true().append_failure_message(
		"Failed to enter build mode: %s" % str(enter_result.get_issues())
	)
	
	# Verify BUILD mode is active and preview exists
	var mode_state: ModeState = _building_system._states.mode
	var building_state: BuildingState = _building_system._states.building
	assert_that(mode_state.current).is_equal(GBEnums.Mode.BUILD).append_failure_message(
		"Should be in BUILD mode, but mode is: %s" % str(mode_state.current)
	)
	assert_object(building_state.preview).is_not_null().append_failure_message(
		"BuildingSystem should have active preview after entering build mode"
	)
	
	runner.simulate_frames(1)

func after_test() -> void:
	runner = null

#region REQUEST THROTTLING TESTS

func test_no_requests_when_drag_not_started() -> void:
	# No drag started - no requests should be made
	runner.simulate_frames(5)
	
	# Should be no drag_data
	assert_object(_drag_manager.drag_data).append_failure_message(
		"drag_data should be null when drag not started"
	).is_null()

func test_no_requests_when_tile_unchanged() -> void:
	# Start drag
	var drag_data: DragPathData = _drag_manager.start_drag()
	var initial_tile: Vector2i = drag_data.target_tile
	
	# Simulate multiple physics frames WITHOUT moving positioner
	# Use public update_drag_state method instead of calling _physics_process directly
	for i in range(5):
		_drag_manager.update_drag_state(0.016)
	
	# Tile hasn't changed - should be ZERO build requests
	assert_int(drag_data.build_requests).append_failure_message(
		"No build requests should be made when tile unchanged. Initial tile: %s, Current: %s, Frames: 5" % [
			initial_tile, drag_data.target_tile
		]
	).is_equal(0)

func test_single_request_on_tile_change() -> void:
	# Start drag
	var drag_data: DragPathData = _drag_manager.start_drag()
	var initial_tile: Vector2i = drag_data.target_tile
	
	# Directly update drag_data target_tile (for throttling test, we don't need actual collision detection)
	drag_data.target_tile = Vector2i(1, 0)  # Different tile
	runner.simulate_frames(1)  # Let physics frame process the change
	
	# Should have made exactly ONE request
	assert_int(drag_data.build_requests).append_failure_message(
		"Exactly one build request should be made on tile change. Initial: %s, New: %s" % [
			initial_tile, drag_data.target_tile
		]
	).is_equal(1)

func test_physics_frame_gate_blocks_multiple_requests_same_frame() -> void:
	# This tests the _last_signal_physics_frame gate
	# Even if we artificially trigger tile changes multiple times in same frame,
	# only ONE request should go through
	
	var drag_data: DragPathData = _drag_manager.start_drag()
	var initial_requests: int = drag_data.build_requests
	
	# Manually update drag_data to simulate rapid tile changes
	var old_tile: Vector2i = drag_data.target_tile
	drag_data.target_tile = Vector2i(old_tile.x + 1, old_tile.y)
	
	# Call _physics_process multiple times in same frame
	# (This simulates what would happen if tile changed multiple times before physics update)
	_drag_manager.update_drag_state(0.016)
	var requests_after_first: int = drag_data.build_requests
	
	# Try to trigger again in SAME physics frame
	drag_data.target_tile = Vector2i(old_tile.x + 2, old_tile.y)
	_drag_manager.update_drag_state(0.016)
	var requests_after_second: int = drag_data.build_requests
	
	# Should only have ONE new request (the first one), second should be gated
	assert_int(requests_after_first - initial_requests).append_failure_message(
		"First tile change should trigger request"
	).is_equal(1)
	
	assert_int(requests_after_second - requests_after_first).append_failure_message(
		"Second tile change in SAME frame should be BLOCKED by physics frame gate"
	).is_equal(0)

func test_multiple_tile_changes_across_frames() -> void:
	var drag_data: DragPathData = _drag_manager.start_drag()
	
	# Move across 3 different tiles, with physics frame advancing between each
	for i in range(3):
		# Move to new tile position
		_targeting_state.positioner.global_position += Vector2(16, 0)  # Move 1 tile right
		runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes
	
	# Build diagnostic info
	var manager_drag_data_requests: int = _drag_manager.drag_data.build_requests if _drag_manager.drag_data else -1
	var local_drag_data_id: int = drag_data.get_instance_id()
	var manager_drag_data_id: int = _drag_manager.drag_data.get_instance_id() if _drag_manager.drag_data else -1
	var same_instance: bool = local_drag_data_id == manager_drag_data_id
	var diagnostic: String = "Test drag_data.build_requests=%d, Manager.drag_data.build_requests=%d, Same instance=%s (test_id=%d, manager_id=%d)" % [
		drag_data.build_requests, manager_drag_data_requests, same_instance, local_drag_data_id, manager_drag_data_id
	]
	
	# Should have exactly 3 requests (one per tile change, each in different frame)
	assert_int(drag_data.build_requests).append_failure_message(
		"Should have 3 build requests for 3 tile changes across 3 frames. %s" % diagnostic
	).is_equal(3)

func test_last_attempted_tile_prevents_duplicate_requests() -> void:
	# This tests the drag_data.last_attempted_tile check
	var drag_data: DragPathData = _drag_manager.start_drag()
	var _initial_tile: Vector2i = drag_data.target_tile  # Store for potential debugging
	
	# Move to new tile
	_targeting_state.positioner.global_position += Vector2(32, 0)
	runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes
	
	var requests_after_move: int = drag_data.build_requests
	assert_int(requests_after_move).is_greater(0)
	
	# Now advance a frame WITHOUT moving (stays on same tile)
	runner.simulate_frames(1)  # Triggers _physics_process → update_drag_state
	
	# Should NOT make another request for the same tile
	assert_int(drag_data.build_requests).append_failure_message(
		"Should NOT make duplicate request for same tile. Last attempted: %s, Current: %s" % [
			drag_data.last_attempted_tile, drag_data.target_tile
		]
	).is_equal(requests_after_move)

func test_drag_session_isolation() -> void:
	# First drag session
	var drag1: DragPathData = _drag_manager.start_drag()
	_targeting_state.positioner.global_position += Vector2(32, 0)
	runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes
	var drag1_requests: int = drag1.build_requests
	assert_int(drag1_requests).is_greater(0)
	
	# Stop first drag
	_drag_manager.stop_drag()
	runner.simulate_frames(1)
	
	# Start second drag session
	var drag2: DragPathData = _drag_manager.start_drag()
	
	# Second session should have fresh counter starting at 0
	assert_int(drag2.build_requests).append_failure_message(
		"New drag session should start with build_requests = 0"
	).is_equal(0)
	
	# Make a tile change in second session
	runner.simulate_frames(1)  # Advance frame first
	_targeting_state.positioner.global_position += Vector2(32, 0)
	_drag_manager.update_drag_state(0.016)
	
	# Second session should track its own requests independently
	assert_int(drag2.build_requests).append_failure_message(
		"Second drag session should track requests independently"
	).is_equal(1)

#endregion

#region MODE/PREVIEW REQUIREMENTS TESTS

func test_no_requests_when_not_in_build_mode() -> void:
	var drag_data: DragPathData = _drag_manager.start_drag()
	
	# Exit build mode
	_building_system.exit_build_mode()
	runner.simulate_frames(1)
	
	# Move to new tile
	_targeting_state.positioner.global_position += Vector2(32, 0)
	runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes
	
	# Should NOT make request when not in BUILD mode
	assert_int(drag_data.build_requests).append_failure_message(
		"Should NOT make build requests when not in BUILD mode"
	).is_equal(0)

func test_no_requests_when_no_preview() -> void:
	# Start drag in build mode with preview
	var drag_data: DragPathData = _drag_manager.start_drag()
	
	# Manually clear preview (simulate preview destruction)
	_building_system._states.building.preview = null
	
	# Move to new tile
	_targeting_state.positioner.global_position += Vector2(32, 0)
	runner.simulate_frames(2)  # Simulate 2 frames to ensure physics completes
	
	# Should NOT make request when no preview exists
	assert_int(drag_data.build_requests).append_failure_message(
		"Should NOT make build requests when no active preview"
	).is_equal(0)

#endregion

#region REQUEST COUNTING ACCURACY

func test_build_requests_counts_only_successful_gate_passes() -> void:
	# This verifies that build_requests ONLY increments when ALL conditions are met:
	# 1. Tile changed
	# 2. Physics frame gate passed
	# 3. Not duplicate tile
	# 4. In BUILD mode
	# 5. Preview exists
	
	var drag_data: DragPathData = _drag_manager.start_drag()
	assert_int(drag_data.build_requests).is_equal(0)
	
	# Condition: All requirements met - change tile using next_tile
	var start_tile: Vector2i = drag_data.target_tile
	drag_data.next_tile = Vector2i(1, 0)  # Move to tile (1, 0)
	print("[TEST] Tile change: %s -> %s" % [start_tile, drag_data.next_tile])
	
	# Manually call update_drag_state to apply tile change
	_drag_manager.update_drag_state(0.016)
	
	var diagnostic_1: String = "After first move: test_drag_data=%d, manager_drag_data=%d, target_tile=%s" % [
		drag_data.build_requests,
		_drag_manager.drag_data.build_requests if _drag_manager.drag_data else -1,
		drag_data.target_tile
	]
	assert_int(drag_data.build_requests).append_failure_message("Should count when all conditions met. %s" % diagnostic_1).is_equal(1)
	
	# Condition: Tile unchanged - should NOT count
	_drag_manager.update_drag_state(0.016)  # No tile change
	assert_int(drag_data.build_requests).append_failure_message("Should NOT count when tile unchanged").is_equal(1)
	
	# Condition: Same tile position again (no move) - should NOT count (duplicate prevention)
	_drag_manager.update_drag_state(0.016)  # No tile change
	assert_int(drag_data.build_requests).append_failure_message("Should NOT count duplicate tile").is_equal(1)
	
	# Condition: New tile, all good - should count
	drag_data.next_tile = Vector2i(2, 0)  # Move to tile (2, 0)
	_drag_manager.update_drag_state(0.016)
	var diagnostic_2: String = "After second move: test_drag_data=%d, manager_drag_data=%d, same_instance=%s" % [
		drag_data.build_requests,
		_drag_manager.drag_data.build_requests if _drag_manager.drag_data else -1,
		drag_data.get_instance_id() == (_drag_manager.drag_data.get_instance_id() if _drag_manager.drag_data else -1)
	]
	assert_int(drag_data.build_requests).append_failure_message("Should count new tile with all conditions met. %s" % diagnostic_2).is_equal(2)

#endregion
