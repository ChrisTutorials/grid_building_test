## Test suite for InputHandler component.
##
## Validates input event routing, mode switching logic, and action handling
## without directly modifying ManipulationSystem state.

extends GdUnitTestSuite


const InputHandler = preload("uid://cpa1aghywkrdg")

var _handler: InputHandler


func before_test() -> void:
	_handler = auto_free(InputHandler.new())


## Tests that handler is constructed without errors.
func test_handler_constructs() -> void:
	assert_that(_handler).is_not_null()


## Tests mode switching for DEMOLISH action.
func test_switch_mode_demolish_from_off() -> void:
	var old_mode: int = GBEnums.Mode.OFF
	var new_mode: int = _handler.switch_mode_for_action("demolish", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.DEMOLISH)


## Tests mode toggle for DEMOLISH - should turn off if already on.
func test_switch_mode_demolish_toggle_off() -> void:
	var old_mode: int = GBEnums.Mode.DEMOLISH
	var new_mode: int = _handler.switch_mode_for_action("demolish", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.OFF)


## Tests mode switching for INFO action.
func test_switch_mode_info_from_off() -> void:
	var old_mode: int = GBEnums.Mode.OFF
	var new_mode: int = _handler.switch_mode_for_action("info", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.INFO)


## Tests mode toggle for INFO - should turn off if already on.
func test_switch_mode_info_toggle_off() -> void:
	var old_mode: int = GBEnums.Mode.INFO
	var new_mode: int = _handler.switch_mode_for_action("info", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.OFF)


## Tests mode switching for MOVE action.
func test_switch_mode_move_from_off() -> void:
	var old_mode: int = GBEnums.Mode.OFF
	var new_mode: int = _handler.switch_mode_for_action("move", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.MOVE)


## Tests mode toggle for MOVE - should turn off if already on.
func test_switch_mode_move_toggle_off() -> void:
	var old_mode: int = GBEnums.Mode.MOVE
	var new_mode: int = _handler.switch_mode_for_action("move", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.OFF)


## Tests OFF action always sets mode to OFF.
func test_switch_mode_off_from_move() -> void:
	var old_mode: int = GBEnums.Mode.MOVE
	var new_mode: int = _handler.switch_mode_for_action("off", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.OFF)


## Tests OFF action when already off stays off.
func test_switch_mode_off_from_off() -> void:
	var old_mode: int = GBEnums.Mode.OFF
	var new_mode: int = _handler.switch_mode_for_action("off", old_mode)
	assert_that(new_mode).is_equal(GBEnums.Mode.OFF)


## Tests unknown action returns unchanged mode.
func test_switch_mode_unknown_action() -> void:
	var old_mode: int = GBEnums.Mode.MOVE
	var new_mode: int = _handler.switch_mode_for_action("invalid_action", old_mode)
	assert_that(new_mode).is_equal(old_mode)


## Tests routing confirm action to placement when in MOVE mode with active manipulation.
func test_route_confirm_to_placement() -> void:
	var command: String = _handler.get_confirm_command("move_mode", true)
	assert_that(command).is_equal("try_placement")


## Tests routing confirm action to move when in MOVE mode without active manipulation.
func test_route_confirm_to_move_when_idle() -> void:
	var command: String = _handler.get_confirm_command("move_mode", false)
	assert_that(command).is_equal("try_move")


## Tests routing confirm action to demolish when in DEMOLISH mode.
func test_route_confirm_to_demolish() -> void:
	var command: String = _handler.get_confirm_command("demolish_mode", false)
	assert_that(command).is_equal("try_demolish")


## Tests routing confirm action ignores action when mode is OFF.
func test_route_confirm_ignores_off_mode() -> void:
	var command: String = _handler.get_confirm_command("off_mode", false)
	assert_that(command).is_equal("none")


## Tests that confirm action returns "none" when mode is not recognized.
func test_route_confirm_invalid_mode() -> void:
	var command: String = _handler.get_confirm_command("unknown_mode", false)
	assert_that(command).is_equal("none")


## Tests should_process_mode_action returns true when ready.
func test_should_process_mode_action_when_ready() -> void:
	var should_process: bool = _handler.should_process_mode_action(true)
	assert_that(should_process).is_true()


## Tests should_process_mode_action returns false when not ready.
func test_should_process_mode_action_when_not_ready() -> void:
	var should_process: bool = _handler.should_process_mode_action(false)
	assert_that(should_process).is_false()


## Tests mode switching is disabled when demolish is not enabled.
func test_demolish_mode_not_available_when_disabled() -> void:
	var new_mode: int = _handler.switch_mode_for_action_if_enabled(
		"demolish", GBEnums.Mode.OFF, false
	)
	assert_that(new_mode).is_equal(GBEnums.Mode.OFF)


## Tests mode switching works when demolish is enabled.
func test_demolish_mode_available_when_enabled() -> void:
	var new_mode: int = _handler.switch_mode_for_action_if_enabled(
		"demolish", GBEnums.Mode.OFF, true
	)
	assert_that(new_mode).is_equal(GBEnums.Mode.DEMOLISH)


## Tests other mode actions work regardless of demolish_enabled flag.
func test_non_demolish_modes_ignore_enabled_flag() -> void:
	var new_mode: int = _handler.switch_mode_for_action_if_enabled(
		"move", GBEnums.Mode.OFF, false
	)
	assert_that(new_mode).is_equal(GBEnums.Mode.MOVE)
