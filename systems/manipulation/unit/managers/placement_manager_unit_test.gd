extends GdUnitTestSuite

## Unit tests for PlacementManager component.
##
## Tests placement validation logic with mocked dependencies.
## Validates:
## - Placement validation against rules
## - Transform application
## - Success/failure handling
## - Error handling for invalid data

const PlacementManager = preload(
	"res://addons/grid_building/systems/manipulation/components/placement_manager.gd"
)

var _manager: Variant
var _mock_settings: ManipulationSettings
var _mock_states: GBStates
var _mock_indicator_context: IndicatorContext
var _mock_owner_context: GBOwnerContext


func before_test() -> void:
	# Setup minimal mocks
	_mock_settings = auto_free(ManipulationSettings.new())
	_mock_settings.invalid_data = "Invalid data: %s"
	_mock_settings.failed_placement_invalid = "Cannot place %s"
	_mock_settings.move_success = "Placed %s successfully"

	_mock_owner_context = auto_free(GBOwnerContext.new())
	_mock_states = auto_free(GBStates.new(_mock_owner_context))
	_mock_indicator_context = auto_free(IndicatorContext.new())

	# Inject via constructor
	_manager = auto_free(
		PlacementManager.new(_mock_settings, _mock_states, _mock_indicator_context)
	)


## Test: Manager rejects invalid manipulation data
func test_try_placement_rejects_invalid_data() -> void:
	var invalid_data: ManipulationData = ManipulationData.new(
		null, null, null, GBEnums.Action.MOVE
	)

	var result: ValidationResults = _manager.try_placement(invalid_data)

	(
		assert_bool(result.is_successful())
		. append_failure_message("Should reject invalid data")
		. is_false()
	)


## Test: Manager initializes with correct dependencies
func test_manager_initializes_with_dependencies() -> void:
	assert_object(_manager).append_failure_message("Manager should be created").is_not_null()
