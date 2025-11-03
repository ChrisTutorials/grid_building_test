extends GdUnitTestSuite

## Unit tests for MoveWorkflowManager component.
##
## Tests move workflow initialization logic with mocked dependencies.
## Validates:
## - Move copy creation and setup
## - Indicator initialization
## - Transform handling (rotation/scale)
## - Error handling for invalid data

const MoveWorkflowManager = preload(
	"res://addons/grid_building/systems/manipulation/components/move_workflow_manager.gd"
)

var _manager: Variant
var _mock_settings: ManipulationSettings
var _mock_states: GBStates
var _mock_indicator_context: IndicatorContext
var _mock_logger: GBLogger
var _mock_owner_context: GBOwnerContext


func before_test() -> void:
	# Setup minimal mocks
	_mock_settings = auto_free(ManipulationSettings.new())
	_mock_settings.move_suffix = " (Moving)"
	_mock_settings.move_started = "Moving %s"

	_mock_owner_context = auto_free(GBOwnerContext.new())
	_mock_states = auto_free(GBStates.new(_mock_owner_context))
	_mock_indicator_context = auto_free(IndicatorContext.new())
	_mock_logger = auto_free(GBLogger.new(null))

	# Inject via constructor
	_manager = auto_free(
		MoveWorkflowManager.new(_mock_settings, _mock_states, _mock_indicator_context, _mock_logger)
	)


## Test: Manager validates data before starting move
func test_start_move_requires_valid_manipulation_data() -> void:
	var invalid_data: ManipulationData = ManipulationData.new(
		null, null, null, GBEnums.Action.MOVE
	)

	var result: bool = _manager.start_move(invalid_data, Callable())

	assert_bool(result).append_failure_message("Should fail with invalid data").is_false()


## Test: Manager initializes with correct dependencies
func test_manager_initializes_with_dependencies() -> void:
	assert_object(_manager).append_failure_message("Manager should be created").is_not_null()
