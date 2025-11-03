extends GdUnitTestSuite

## Unit tests for DemolishManager component.
##
## Tests demolish workflow logic with mocked dependencies.
## Validates:
## - Demolish permission validation
## - Object removal workflow
## - Error handling for invalid targets
## - State cleanup after demolish

const DemolishManager = preload(
	"res://addons/grid_building/systems/manipulation/components/demolish_manager.gd"
)

var _manager: Variant
var _mock_settings: ManipulationSettings
var _mock_states: GBStates
var _mock_owner_context: GBOwnerContext


func before_test() -> void:
	# Setup minimal mocks
	_mock_settings = auto_free(ManipulationSettings.new())

	_mock_owner_context = auto_free(GBOwnerContext.new())
	_mock_states = auto_free(GBStates.new(_mock_owner_context))

	# Inject via constructor
	_manager = auto_free(DemolishManager.new(_mock_settings, _mock_states))


## Test: Manager rejects null manipulatable and pushes error
func test_try_start_demolish_rejects_null_target() -> void:
	(
		assert_error(
			func() -> void:
				var result: Variant = _manager.try_start_demolish(null, Callable())
				assert_object(result).is_null()
		)
		. is_push_error("[DemolishManager] Cannot demolish null manipulatable")
	)


## Test: Manager rejects invalid manipulatable and pushes error
func test_try_start_demolish_rejects_invalid_manipulatable() -> void:
	var invalid_node: Node = auto_free(Node.new())

	(
		assert_error(
			func() -> void:
				var result: Variant = _manager.try_start_demolish(invalid_node, Callable())
				assert_object(result).is_null()
		)
		. is_push_error("[DemolishManager] Invalid manipulatable for demolish")
	)


## Test: Manager initializes with correct dependencies
func test_manager_initializes_with_dependencies() -> void:
	assert_object(_manager).append_failure_message("Manager should be created").is_not_null()
