## ManipulationValidator Component Tests
##
## Tests for validation logic extracted from ManipulationSystem.
extends GdUnitTestSuite

# Preload the validator component by its UID
const ManipulationValidator = preload("uid://dxtyu2qvuwg8h")

var _validator: Resource


func before_test() -> void:
	_validator = ManipulationValidator.new()


#region Setup Validation Tests

## Tests validator rejects null data.
func test_validate_move_setup_rejects_null_data() -> void:
	var result: Variant = _validator.validate_move_setup(null)
	assert_bool(result.is_valid).is_false().append_failure_message("Should reject null")


## Tests validator rejects null source.
func test_validate_move_setup_rejects_null_source() -> void:
	var data: Dictionary[String, Variant] = {"source": null}
	var result: Variant = _validator.validate_move_setup(data)
	assert_bool(result.is_valid).is_false().append_failure_message("Should reject null source")


## Tests validator rejects null source root.
func test_validate_move_setup_rejects_null_root() -> void:
	var data: Dictionary[String, Variant] = {"source": {"root": null}}
	var result: Variant = _validator.validate_move_setup(data)
	assert_bool(result.is_valid).is_false().append_failure_message("Should reject null root")


## Tests validator accepts valid move setup.
func test_validate_move_setup_accepts_valid() -> void:
	var root: Node2D = auto_free(Node2D.new())
	var data: Dictionary[String, Variant] = {"source": {"root": root}}
	var result: Variant = _validator.validate_move_setup(data)
	assert_bool(result.is_valid).is_true().append_failure_message("Should accept valid")

#endregion


#region Placement Validation Tests

## Tests validator rejects placement without move_copy.
func test_validate_placement_rejects_no_move_copy() -> void:
	var root: Node2D = auto_free(Node2D.new())
	var data: Dictionary[String, Variant] = {"source": {"root": root}, "move_copy": null}
	var result: Variant = _validator.validate_placement_setup(data)
	assert_bool(result.is_valid).is_false().append_failure_message("Should reject no copy")


## Tests validator accepts valid placement setup.
func test_validate_placement_accepts_valid() -> void:
	var root1: Node2D = auto_free(Node2D.new())
	var root2: Node2D = auto_free(Node2D.new())
	var data: Dictionary[String, Variant] = {"source": {"root": root1}, "move_copy": {"root": root2}}
	var result: Variant = _validator.validate_placement_setup(data)
	assert_bool(result.is_valid).is_true().append_failure_message("Should accept valid")

#endregion


#region Dependency Validation Tests

## Tests validator rejects missing dependencies (parameterized).
@warning_ignore("unused_parameter")
func test_validate_dependencies_rejects_missing(
	missing_name: String,
	test_parameters := [
		["states"],
		["settings"],
		["actions"],
		["indicator_context"],
		["logger"],
	]
) -> void:
	var deps: Dictionary[String, Variant] = {}
	if missing_name != "states":
		deps["states"] = {}
	if missing_name != "settings":
		deps["settings"] = {}
	if missing_name != "actions":
		deps["actions"] = {}
	if missing_name != "indicator_context":
		deps["indicator_context"] = {}
	if missing_name != "logger":
		deps["logger"] = {}
	
	var result: Variant = _validator.validate_dependencies(deps)
	assert_bool(result.is_valid).is_false().append_failure_message("Should reject missing %s" % missing_name)


## Tests validator accepts all dependencies present.
func test_validate_dependencies_accepts_all() -> void:
	var deps: Dictionary[String, Variant] = {
		"states": {},
		"settings": {},
		"actions": {},
		"indicator_context": {},
		"logger": {},
	}
	var result: Variant = _validator.validate_dependencies(deps)
	assert_bool(result.is_valid).is_true().append_failure_message("Should accept all")

#endregion


#region Demolish Validation Tests

## Tests validator rejects non-demolishable.
func test_validate_demolish_rejects_non_demolishable() -> void:
	var target: Dictionary[String, Variant] = {"is_demolishable": false}
	var result: Variant = _validator.validate_demolish(target)
	assert_bool(result.is_valid).is_false().append_failure_message("Should reject")


## Tests validator accepts demolishable.
func test_validate_demolish_accepts_demolishable() -> void:
	var target: Dictionary[String, Variant] = {"is_demolishable": true}
	var result: Variant = _validator.validate_demolish(target)
	assert_bool(result.is_valid).is_true().append_failure_message("Should accept")

#endregion


#region Rotation Validation Tests

## Tests validator rejects invalid rotations (parameterized).
@warning_ignore("unused_parameter")
func test_validate_rotate_rejects_invalid(
	degrees: float,
	test_parameters := [
		[-45.0],
		[15.0],
		[359.0],
	]
) -> void:
	var result: Variant = _validator.validate_rotate(degrees)
	assert_bool(result.is_valid).is_false().append_failure_message("Reject %f" % degrees)


## Tests validator accepts valid rotations (parameterized).
@warning_ignore("unused_parameter")
func test_validate_rotate_accepts_valid(
	degrees: float,
	test_parameters := [
		[0.0],
		[90.0],
		[180.0],
		[270.0],
		[360.0],
	]
) -> void:
	var result: Variant = _validator.validate_rotate(degrees)
	assert_bool(result.is_valid).is_true().append_failure_message("Accept %f" % degrees)

#endregion
