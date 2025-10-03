## DragManager request throttling and gating tests (isolated)
## Tests DragManager's core responsibility: ensuring only ONE build request per tile change per physics frame
## Does NOT depend on BuildingSystem - tests the gating logic in isolation
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
	
	# Disable camera checks for headless testing
	if _container.config.settings.runtime_checks:
		_container.config.settings.runtime_checks.camera_2d = false
	
	# Create and setup DragManager
	_drag_manager = auto_free(DragManager.new())
	env.add_child(_drag_manager)
	_drag_manager.resolve_gb_dependencies(_container)
	_drag_manager.set_test_mode(true)  # Disable input processing
	
	# Get references
	_targeting_state = _container.get_states().targeting
	_building_system = _container.get_systems_context().get_building_system()
	
	# Enter build mode with a simple test placeable
	var test_placeable: Placeable = PlaceableTestFactory.create_minimal_test_placeable("DragThrottleTest")
	_building_system.enter_build_mode(test_placeable)
	
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
	
	# Move to new tile by changing the positioner's position
	_targeting_state.positioner.global_position = Vector2(32, 32)  # Different tile
	_drag_manager.update_drag_state(0.016)
	
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
	
	# Move across 3 different tiles over 3 physics frames
	for i in range(3):
		_targeting_state.positioner.global_position += Vector2(16, 0)  # Move 1 tile right
		runner.simulate_frames(1)
	
	# Should have exactly 3 requests (one per tile change)
	assert_int(drag_data.build_requests).append_failure_message(
		"Should have 3 build requests for 3 tile changes across 3 frames"
	).is_equal(3)

func test_last_attempted_tile_prevents_duplicate_requests() -> void:
	# This tests the drag_data.last_attempted_tile check
	var drag_data: DragPathData = _drag_manager.start_drag()
	var _initial_tile: Vector2i = drag_data.target_tile  # Store for potential debugging
	
	# Move to new tile
	_targeting_state.positioner.global_position += Vector2(32, 0)
	runner.simulate_frames(1)
	
	var requests_after_move: int = drag_data.build_requests
	assert_int(requests_after_move).is_greater(0)
	
	# Now advance a frame WITHOUT moving (stays on same tile)
	runner.simulate_frames(1)
	
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
	runner.simulate_frames(1)
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
	_targeting_state.positioner.global_position += Vector2(32, 0)
	runner.simulate_frames(1)
	
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
	runner.simulate_frames(1)
	
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
	runner.simulate_frames(1)
	
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
	
	# Condition: All requirements met
	_targeting_state.positioner.global_position += Vector2(16, 0)
	runner.simulate_frames(1)
	assert_int(drag_data.build_requests).append_failure_message("Should count when all conditions met").is_equal(1)
	
	# Condition: Tile unchanged - should NOT count
	runner.simulate_frames(1)
	assert_int(drag_data.build_requests).append_failure_message("Should NOT count when tile unchanged").is_equal(1)
	
	# Condition: Same tile again - should NOT count (duplicate prevention)
	drag_data.target_tile = drag_data.last_attempted_tile
	runner.simulate_frames(1)
	assert_int(drag_data.build_requests).append_failure_message("Should NOT count duplicate tile").is_equal(1)
	
	# Condition: New tile, all good - should count
	_targeting_state.positioner.global_position += Vector2(16, 0)
	runner.simulate_frames(1)
	assert_int(drag_data.build_requests).append_failure_message("Should count new tile with all conditions met").is_equal(2)

#endregion
