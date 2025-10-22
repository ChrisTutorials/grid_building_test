## DragManager unit tests focusing on API and state management
## Scope: Validate non-physics-dependent DragManager APIs
## Physics-driven tile detection tested in integration tests
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: BuildingTestEnvironment
var _container: GBCompositionContainer
var _drag_manager: DragManager

func before_test() -> void:
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID)
	runner.simulate_frames(1)
	env = runner.scene() as BuildingTestEnvironment
	_container = env.get_container()
	if _container.config.settings.runtime_checks:
		_container.config.settings.runtime_checks.camera_2d = false
	_drag_manager = DragManager.new()
	env.add_child(_drag_manager)
	_drag_manager.resolve_gb_dependencies(_container)
	runner.simulate_frames(1)

func after_test() -> void:
	runner = null

func test_start_drag_creates_drag_data() -> void:
	_drag_manager.set_test_mode(true)
	var drag_data: DragPathData = _drag_manager.start_drag()
	assert_object(drag_data)
  .append_failure_message("start_drag() should return DragPathData").is_not_null()
	assert_bool(_drag_manager.is_dragging())
  .append_failure_message("is_dragging() should return true").is_true()

func test_stop_drag_clears_drag_data() -> void:
	_drag_manager.set_test_mode(true)
	_drag_manager.start_drag()
	_drag_manager.stop_drag()
	assert_object(_drag_manager.drag_data).append_failure_message("drag_data should be null").is_null()
	assert_bool(_drag_manager.is_dragging())
  .append_failure_message("is_dragging() should return false").is_false()

func test_cannot_start_drag_while_already_dragging() -> void:
	_drag_manager.set_test_mode(true)
	var first_drag: DragPathData = _drag_manager.start_drag()
	var second_drag: DragPathData = _drag_manager.start_drag()
	assert_object(second_drag)
  .append_failure_message("start_drag() should return null when already dragging").is_null()
	assert_object(_drag_manager.drag_data)
  .append_failure_message("Original drag_data should remain").is_same(first_drag)

func test_set_test_mode_controls_input_processing() -> void:
	assert_bool(_drag_manager.is_processing_input())
  .append_failure_message("Input processing should be enabled by default").is_true()
	_drag_manager.set_test_mode(true)
	assert_bool(_drag_manager.is_processing_input())
  .append_failure_message("Test mode should disable input processing").is_false()
	_drag_manager.set_test_mode(false)
	assert_bool(_drag_manager.is_processing_input())
  .append_failure_message("Disabling test mode should re-enable input").is_true()

func test_format_drag_state_helper() -> void:
	_drag_manager.set_test_mode(true)
	var drag_data: DragPathData = _drag_manager.start_drag()
	var formatted: String = DragManager.format_drag_state(drag_data)
	assert_str(formatted)
  .append_failure_message("format_drag_state should return non-empty string").is_not_empty()
	assert_bool(formatted.contains("DragState"))
  .append_failure_message("Should contain 'DragState'").is_true()

func test_format_drag_state_handles_null() -> void:
	var formatted: String = DragManager.format_drag_state(null)
	assert_str(formatted).append_failure_message("format_drag_state(null) should return graceful string").is_equal("[DragState: null]")
