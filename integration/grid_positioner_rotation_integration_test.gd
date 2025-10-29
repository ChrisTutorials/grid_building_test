## Integration test for ManipulationParent rotation functionality
## Tests the grid-aware rotation integration with ManipulationParent input handling
##
## NOTE: Rotation logic has been moved from GridPositioner2D to ManipulationParent.
## GridPositioner2D now focuses strictly on tile center targeting.
extends GdUnitTestSuite

# Test environment
var manipulation_parent: ManipulationParent
var test_map: TileMapLayer
var test_object: Node2D
var manipulation_state: ManipulationState
var manipulation_settings: ManipulationSettings
var actions: GBActions
var container: GBCompositionContainer


func before_test() -> void:
	# Create test tilemap with auto_free
	test_map = auto_free(TileMapLayer.new())
	test_map.tile_set = TileSet.new()
	add_child(test_map)

	# Create test object to rotate (this will be the manipulated object)
	test_object = auto_free(Node2D.new())
	test_object.global_position = Vector2(100, 100)
	add_child(test_object)

	# Create manipulation parent with auto_free
	manipulation_parent = auto_free(ManipulationParent.new())
	add_child(manipulation_parent)

	# Create dependency container with auto_free
	container = auto_free(GBCompositionContainer.new())

	# Set up configuration with settings
	var config: GBConfig = auto_free(GBConfig.new())
	var settings: GBSettings = auto_free(GBSettings.new())

	# Set up manipulation settings
	manipulation_settings = auto_free(ManipulationSettings.new())
	manipulation_settings.enable_rotate = true
	settings.manipulation = manipulation_settings

	# Set up actions
	actions = auto_free(GBActions.new())
	actions.rotate_left = "rotate_left"
	actions.rotate_right = "rotate_right"

	# Configure the config resource
	config.settings = settings
	config.actions = actions
	container.config = config

	# Set up states after container is configured
	var owner_context: GBOwnerContext = auto_free(GBOwnerContext.new())
	var states: GBStates = auto_free(GBStates.new(owner_context))
	manipulation_state = states.manipulation

	# Set up targeting state with our test map
	states.targeting.target_map = test_map

	# Create a manipulatable for the test object
	var manipulatable: Manipulatable = auto_free(Manipulatable.new())
	manipulatable.root = test_object

	# Create manipulation data
	var manipulation_data: ManipulationData = auto_free(
		ManipulationData.new(
			manipulation_parent, manipulatable, manipulatable, GBEnums.Action.ROTATE
		)
	)

	# Inject dependencies and start manipulation
	manipulation_parent.resolve_gb_dependencies(container)
	manipulation_state.data = manipulation_data


func after_test() -> void:
	# auto_free() will handle cleanup automatically
	pass


## Test that grid-aware rotation methods work correctly
func test_grid_aware_rotation_input_handling() -> void:
	# Set initial rotation to North (0 degrees)
	manipulation_parent.rotation = 0.0

	# Apply grid-aware clockwise rotation directly (the method we're actually testing)
	var _new_degrees: float = manipulation_parent.apply_grid_rotation_clockwise(test_map)

	# Verify rotation was applied using grid-aware rotation (should be 90 degrees = East)
	var expected_rotation := deg_to_rad(90.0)
	(
		assert_float(manipulation_parent.rotation)
		. append_failure_message(
			(
				"ManipulationParent should be rotated to 90 degrees (East direction), got %.6f"
				% manipulation_parent.rotation
			)
		)
		. is_equal_approx(expected_rotation, 0.1)
	)


## Test counter-clockwise grid-aware rotation
func test_grid_aware_rotation_counter_clockwise() -> void:
	# Set initial rotation to North (0 degrees)
	manipulation_parent.rotation = 0.0

	# Apply grid-aware counter-clockwise rotation directly
	var _new_degrees: float = manipulation_parent.apply_grid_rotation_counter_clockwise(test_map)

	# Verify rotation was applied (should be 270 degrees = West)
	var expected_rotation := deg_to_rad(270.0)
	(
		assert_float(manipulation_parent.rotation)
		. append_failure_message(
			(
				"ManipulationParent should be rotated to 270 degrees (West direction), got %.6f"
				% manipulation_parent.rotation
			)
		)
		. is_equal_approx(expected_rotation, 0.1)
	)


## Test that simple degree-based rotation works as fallback when no TileMapLayer is available
func test_simple_degree_rotation_fallback() -> void:
	# Test simple degree rotation directly (without TileMapLayer)
	manipulation_settings.rotate_increment_degrees = 45.0  # Use 45-degree increments

	# Set initial rotation
	manipulation_parent.rotation = 0.0

	# Apply simple degree rotation directly (simulate right rotation)
	manipulation_parent.apply_rotation(-45.0)  # Negative because right rotation is negative in Godot

	# Verify simple degree rotation was applied (45 degrees)
	var expected_rotation := deg_to_rad(-45.0)  # Negative because right rotation is negative in Godot
	(
		assert_float(manipulation_parent.rotation)
		. append_failure_message(
			(
				"ManipulationParent should use simple degree rotation as fallback, got %.6f"
				% manipulation_parent.rotation
			)
		)
		. is_equal_approx(expected_rotation, 0.1)
	)


## Test that rotation is disabled when settings are disabled
func test_rotation_disabled_when_settings_disabled() -> void:
	# Disable rotation
	manipulation_settings.enable_rotate = false

	# Set initial rotation
	manipulation_parent.rotation = 0.0
	var initial_rotation := manipulation_parent.rotation

	# Create rotation input event with auto_free
	var input_map_action: InputEventAction = auto_free(InputEventAction.new())
	input_map_action.action = "rotate_right"
	input_map_action.pressed = true

	# Call the input handler
	manipulation_parent._unhandled_input(input_map_action)

	# Verify rotation was NOT applied
	(
		assert_float(manipulation_parent.rotation)
		. append_failure_message("Rotation should be ignored when enable_rotate is false")
		. is_equal(initial_rotation)
	)


## Test grid-aware rotation methods directly
func test_direct_grid_aware_rotation_methods() -> void:
	# Test clockwise rotation
	manipulation_parent.rotation = 0.0  # Start at North (0 degrees)
	var new_degrees: float = manipulation_parent.apply_grid_rotation_clockwise(test_map)
	(
		assert_float(new_degrees)
		. append_failure_message(
			(
				"Clockwise rotation from North (0°) should result in 90° (East), got %.2f°"
				% new_degrees
			)
		)
		. is_equal_approx(90.0, 0.1)
	)

	# Test counter-clockwise rotation
	manipulation_parent.rotation = 0.0  # Reset to North (0 degrees)
	new_degrees = manipulation_parent.apply_grid_rotation_counter_clockwise(test_map)
	(
		assert_float(new_degrees)
		. append_failure_message(
			(
				"Counter-clockwise rotation from North (0°) should result in 270° (West), got %.2f°"
				% new_degrees
			)
		)
		. is_equal_approx(270.0, 0.1)
	)


## Test that children of ManipulationParent are rotated along with the parent
func test_children_inherit_rotation() -> void:
	# Add test object as child of manipulation parent
	if test_object.get_parent():
		test_object.get_parent().remove_child(test_object)
	manipulation_parent.add_child(test_object)

	# Set initial rotations
	manipulation_parent.rotation = 0.0
	test_object.rotation = 0.0

	# Rotate the manipulation parent
	manipulation_parent.apply_rotation(90.0)

	# Verify the child inherits the rotation through transform inheritance
	var child_global_rotation := test_object.global_rotation
	var expected_rotation := deg_to_rad(90.0)
	(
		assert_float(child_global_rotation)
		. append_failure_message("Child objects should inherit rotation from ManipulationParent")
		. is_equal_approx(expected_rotation, 0.1)
	)


## Test complete rotation sequence maintains cardinal directions
func test_rotation_sequence_maintains_cardinal_directions() -> void:
	# Start at North (0 degrees)
	manipulation_parent.rotation = 0.0

	# Rotate clockwise: North -> East -> South -> West -> North
	# Expected degrees for each step
	var expected_degrees_sequence := [90.0, 180.0, 270.0, 0.0]  # East, South, West, North
	var direction_names := ["East", "South", "West", "North"]

	for i in range(4):
		# Apply clockwise rotation
		var new_degrees: float = manipulation_parent.apply_grid_rotation_clockwise(test_map)
		var expected_degrees: float = expected_degrees_sequence[i]

		# Normalize to 0-360 range for comparison
		var normalized_degrees := fmod(new_degrees, 360.0)
		if normalized_degrees < 0:
			normalized_degrees += 360.0
		elif normalized_degrees > 359.9:  # Within 0.1 of 360 - treat as 0
			normalized_degrees = 0.0

		(
			assert_float(normalized_degrees)
			. append_failure_message(
				(
					"Step %d: Expected %.1f° (%s), got %.2f° (normalized from %.2f°)"
					% [i + 1, expected_degrees, direction_names[i], normalized_degrees, new_degrees]
				)
			)
			. is_equal_approx(expected_degrees, 0.1)
		)

		# Verify node rotation matches expected degrees (in radians)
		var node_degrees := fmod(rad_to_deg(manipulation_parent.rotation), 360.0)
		if node_degrees < 0:
			node_degrees += 360.0
		# Handle near-360 values (floating point imprecision) - treat as 0 degrees
		elif node_degrees > 359.9:  # Within 0.1 of 360
			node_degrees = 0.0
		(
			assert_float(node_degrees)
			. append_failure_message(
				(
					"Step %d: Node rotation should be %.1f° (%s), got %.2f°"
					% [i + 1, expected_degrees, direction_names[i], node_degrees]
				)
			)
			. is_equal_approx(expected_degrees, 0.1)
		)
