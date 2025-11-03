extends GdUnitTestSuite

## Unit tests for PhysicsLayerManager component.
##
## Tests physics layer enable/disable logic.
## Validates:
## - Layer validation
## - Enable/disable operations
## - Tracking of disabled objects
## - Error handling for invalid inputs

const PhysicsLayerManager = preload(
	"res://addons/grid_building/systems/manipulation/components/physics_layer_manager.gd"
)

var _manager: PhysicsLayerManager


func before_test() -> void:
	_manager = auto_free(PhysicsLayerManager.new())


## Test: Manager validates layer range
func test_is_valid_layer_accepts_valid_range() -> void:
	var result_0: bool = _manager.is_valid_layer(0)
	var result_31: bool = _manager.is_valid_layer(31)

	assert_bool(result_0).append_failure_message("Layer 0 should be valid").is_true()
	assert_bool(result_31).append_failure_message("Layer 31 should be valid").is_true()


## Test: Manager rejects invalid layer values
func test_is_valid_layer_rejects_invalid_range() -> void:
	var result_negative: bool = _manager.is_valid_layer(-1)
	var result_too_high: bool = _manager.is_valid_layer(32)

	assert_bool(result_negative).append_failure_message("Negative layer should be invalid").is_false()
	(
		assert_bool(result_too_high)
		. append_failure_message("Layer > 31 should be invalid")
		. is_false()
	)


## Test: Manager handles null target gracefully
func test_disable_layer_handles_null_target() -> void:
	var disabled_track: Dictionary = {}

	var result: bool = _manager.disable_layer(null, 1, disabled_track)

	assert_bool(result).append_failure_message("Should return false for null target").is_false()


## Test: Manager handles empty disabled track
func test_enable_layers_handles_empty_track() -> void:
	var disabled_track: Dictionary = {}

	var result: bool = _manager.enable_layers(disabled_track, 1)

	assert_bool(result).append_failure_message("Should return true for empty track").is_true()
