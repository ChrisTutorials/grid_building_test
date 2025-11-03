extends GdUnitTestSuite

## Unit tests for ManipulationValidator component.
##
## Tests validation logic with mocked dependencies to ensure proper error handling
## and validation rules without requiring full system setup.

const ManipulationValidator = preload("uid://7nwcaiy7n3hw")

var _validator: ManipulationValidator
var _mock_settings: ManipulationSettings
var _mock_states: GBStates
var _mock_indicator_context: IndicatorContext
var _mock_owner_context: GBOwnerContext


func before_test() -> void:
	_mock_settings = auto_free(ManipulationSettings.new())
	_mock_settings.failed_object_not_manipulatable = "Object %s not manipulatable"
	_mock_settings.failed_placement_invalid = "Cannot place at %s"
	_mock_settings.unsupported_node_type = "Node type %s not supported"

	_mock_owner_context = auto_free(GBOwnerContext.new())
	_mock_states = auto_free(GBStates.new(_mock_owner_context))
	_mock_indicator_context = auto_free(IndicatorContext.new())

	_validator = auto_free(
		ManipulationValidator.new(_mock_settings, _mock_states, _mock_indicator_context)
	)


## Tests that validate_move_setup rejects null root node.
func test_validate_move_setup_rejects_null_root() -> void:
	var result: Variant = _validator.validate_move_setup(null)

	(
		assert_that(result)
		. append_failure_message("Should return error message for null root")
		. is_equal("Cannot move null root")
	)


## Tests that validate_placement_setup rejects null move data.
func test_validate_placement_setup_rejects_null_move_data() -> void:
	var result: Variant = _validator.validate_placement_setup(null)

	(
		assert_that(result)
		. append_failure_message("Should return error message for null move data")
		. is_equal("Cannot validate null move data")
	)


## Tests that validate_placement_setup rejects move data without copy.
# Generic Dictionary intentional - testing error handling with minimal data
func test_validate_placement_setup_rejects_missing_move_copy() -> void:
	var move_data: Dictionary = {"action": GBEnums.Action.MOVE}

	var result: Variant = _validator.validate_placement_setup(move_data)

	(
		assert_that(result)
		. append_failure_message("Should return error message when move_copy is missing")
		. is_equal("Move copy is not set up")
	)


## Tests that validate_demolish rejects null manipulatable.
func test_validate_demolish_rejects_null_manipulatable() -> void:
	var result: Variant = _validator.validate_demolish(null)

	(
		assert_that(result)
		. append_failure_message("Should return error message for null manipulatable")
		. is_equal("Cannot demolish null manipulatable")
	)


## Tests that validate_rotate rejects null target.
func test_validate_rotate_rejects_null_target() -> void:
	var result: Variant = _validator.validate_rotate(null, 90.0)

	(
		assert_that(result)
		. append_failure_message("Should return error message for null rotation target")
		. is_equal("Cannot rotate null target")
	)


## Tests that validate_rotate rejects non-Node2D targets.
func test_validate_rotate_rejects_non_node2d() -> void:
	var invalid_target: Node = auto_free(Node.new())

	var result: Variant = _validator.validate_rotate(invalid_target, 90.0)

	(
		assert_that(result)
		. append_failure_message("Should return error message for non-Node2D target")
		. contains("not supported")
	)


## Tests that validate_flip rejects null target.
func test_validate_flip_rejects_null_target() -> void:
	var result: Variant = _validator.validate_flip(null)

	(
		assert_that(result)
		. append_failure_message("Should return error message for null flip target")
		. is_equal("Cannot flip null target")
	)


## Tests that validate_flip rejects non-Node2D targets.
func test_validate_flip_rejects_non_node2d() -> void:
	var invalid_target: Node = auto_free(Node.new())

	var result: Variant = _validator.validate_flip(invalid_target)

	(
		assert_that(result)
		. append_failure_message("Should return error message for non-Node2D target")
		. contains("not supported")
	)
