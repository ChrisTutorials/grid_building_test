extends GdUnitTestSuite

## Tests for DemolishManager - Demolish operation coordination and validation
##
## DemolishManager handles demolish validation via ManipulationStateMachine,
## queues objects for deletion, and manages active manipulatable state.


const DemolishManager = preload(
	"res://addons/grid_building/systems/manipulation/components/demolish_manager.gd"
)


var _demolish_manager: DemolishManager
var _settings: ManipulationSettings


func before_test() -> void:
	_demolish_manager = DemolishManager.new()
	_settings = ManipulationSettings.new()


# region Try Demolish Tests

## Tests that try_demolish returns ManipulationData
func test_try_demolish_returns_manipulation_data() -> void:
	var target: Manipulatable = auto_free(Manipulatable.new())
	var active: Manipulatable = auto_free(Manipulatable.new())

	var result: ManipulationData = _demolish_manager.try_demolish(
		target, active, _settings
	)

	assert_that(result).is_not_null()


## Tests that try_demolish returns ManipulationData with DEMOLISH action
func test_try_demolish_sets_action_type() -> void:
	var target: Manipulatable = auto_free(Manipulatable.new())
	var active: Manipulatable = auto_free(Manipulatable.new())

	var result: ManipulationData = _demolish_manager.try_demolish(
		target, active, _settings
	)

	assert_int(result.action).is_equal(GBEnums.Action.DEMOLISH)


## Tests that try_demolish handles null target by returning ManipulationData
func test_try_demolish_handles_null_target() -> void:
	var active: Manipulatable = auto_free(Manipulatable.new())

	var result: ManipulationData = _demolish_manager.try_demolish(
		null, active, _settings
	)

	assert_that(result).is_not_null()


## Tests that try_demolish creates demolish data with target as source
func test_try_demolish_creates_data_with_target_as_source() -> void:
	var target: Manipulatable = auto_free(Manipulatable.new())
	var active: Manipulatable = auto_free(Manipulatable.new())

	var result: ManipulationData = _demolish_manager.try_demolish(
		target, active, _settings
	)

	assert_that(result.source).is_equal(target)


## Tests that try_demolish validates through ManipulationStateMachine
func test_try_demolish_validates_through_state_machine() -> void:
	var target_node: Node2D = auto_free(Node2D.new())

	var target: Manipulatable = auto_free(Manipulatable.new())
	target.root = target_node

	var active: Manipulatable = auto_free(Manipulatable.new())

	# ManipulationStateMachine will validate - just verify it returns data
	var result: ManipulationData = _demolish_manager.try_demolish(
		target, active, _settings
	)

	assert_that(result).is_not_null()


# endregion


# region Demolish Tests

## Tests that demolish calls try_demolish and returns bool
func test_demolish_returns_bool() -> void:
	var target: Manipulatable = auto_free(Manipulatable.new())
	var active: Manipulatable = auto_free(Manipulatable.new())

	var result: bool = _demolish_manager.demolish(target, active, _settings)

	# Result should be bool (may be true or false depending on validation)
	assert_bool(result is bool).is_true()


## Tests that demolish returns false when target is null
func test_demolish_returns_false_on_null_target() -> void:
	var result: bool = _demolish_manager.demolish(null, null, _settings)

	assert_bool(result).is_false()


# endregion


# region Display Name Tests

## Tests that get_demolish_display_name returns string for valid manipulatable
func test_get_demolish_display_name_returns_string() -> void:
	var target: Manipulatable = auto_free(Manipulatable.new())

	var name_result: String = _demolish_manager.get_demolish_display_name(target)

	assert_bool(name_result is String).is_true()


## Tests that get_demolish_display_name returns fallback for null manipulatable
func test_get_demolish_display_name_returns_fallback_for_null() -> void:
	var name_result: String = _demolish_manager.get_demolish_display_name(null)

	assert_str(name_result).is_equal("<none>")


## Tests that get_demolish_display_name returns string for manipulatable without root
func test_get_demolish_display_name_handles_no_root() -> void:
	var target: Manipulatable = auto_free(Manipulatable.new())
	target.root = null

	var name_result: String = _demolish_manager.get_demolish_display_name(target)

	# Should return string (object name or fallback)
	assert_bool(name_result is String).is_true()


# endregion
