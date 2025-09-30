## Test Suite: Preview Name Consistency Tests
##
## Validates that building system preview instances maintain consistent naming
## when the same placeable is set multiple times, and that different placeables
## receive their correct root scene names. Tests address issue #10 where preview
## names were lost on repeated assignments of the same placeable.

extends GdUnitTestSuite

#region Test Environment Variables
var env: AllSystemsTestEnvironment
var system: BuildingSystem
var targeting_state: GridTargetingState
var mode_state: ModeState
var _container: GBCompositionContainer
var placeable_2d_test: Placeable = load("uid://jgmywi04ib7c")
var placeable_with_rules: Placeable
#endregion

#region Setup and Teardown
func before_test() -> void:
	# Validate test resources are loaded
	assert_object(placeable_2d_test).is_not_null()

	# Create complete all systems test environment
	env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	_container = env.get_container()
	system = env.building_system
	
	# Access shared states from the pre-configured test container
	var states := _container.get_states()
	assert_object(states).is_not_null()
	targeting_state = states.targeting
	mode_state = states.mode

	# Assign placed_parent so built instances have a parent
	states.building.placed_parent = env
	
	# Create a placeable with rules for testing
	placeable_with_rules = _create_test_placeable_with_rules()
	assert_object(placeable_with_rules).append_failure_message(
		"Test placeable with rules should be created successfully"
	).is_not_null()
	assert_array(placeable_with_rules.placement_rules).append_failure_message(
		"Test placeable should have placement rules configured"
	).is_not_empty()
#endregion

#region Setup and Teardown
func after_test() -> void:
	# Ensure building system is in a clean state for next test
	if system and system.is_in_build_mode():
		system.exit_build_mode()
#endregion

#region Preview Name Consistency Tests
func test_same_placeable_twice_preserves_name() -> void:
	# Test issue #10: When the same placeable is set twice in a row
	# via enter_build_mode, the preview instance should retain the
	# root PackedScene's name consistently.

	var expected_name: String = _get_expected_preview_name(placeable_with_rules)

	# First call to enter_build_mode
	var report1: PlacementReport = system.enter_build_mode(placeable_with_rules)
	assert_bool(report1.is_successful()).append_failure_message(
		"First enter_build_mode should succeed, but failed with: " + str(report1.get_issues())
	).is_true()

	var preview1: Node2D = _get_current_preview()
	_assert_preview_valid_and_named(preview1, expected_name)

	# Second call to enter_build_mode with same placeable
	var report2: PlacementReport = system.enter_build_mode(placeable_with_rules)
	assert_bool(report2.is_successful()).append_failure_message(
		"Second enter_build_mode should succeed, but failed with: " + str(report2.get_issues())
	).is_true()

	var preview2: Node2D = _get_current_preview()
	_assert_preview_valid_and_named(preview2, expected_name)

	# Ensure it's a different instance (not the same object)
	assert_object(preview2).is_not_same(preview1)


func test_different_placeables_have_correct_names() -> void:
	# Verify that different placeables get their correct names
	var placeable1: Placeable = placeable_with_rules
	var placeable2: Placeable = _create_different_test_placeable_with_rules()

	var expected_name1: String = _get_expected_preview_name(placeable1)
	var expected_name2: String = _get_expected_preview_name(placeable2)

	# Set first placeable
	system.enter_build_mode(placeable1)
	var preview1: Node2D = _get_current_preview()
	_assert_preview_valid_and_named(preview1, expected_name1)

	# Set second placeable
	system.enter_build_mode(placeable2)
	var preview2: Node2D = _get_current_preview()
	_assert_preview_valid_and_named(preview2, expected_name2)

	# Set first placeable again
	system.enter_build_mode(placeable1)
	var preview3: Node2D = _get_current_preview()
	_assert_preview_valid_and_named(preview3, expected_name1)
#endregion

#region Helper Functions - DRY Patterns
## Gets the current building preview from the building state
func _get_current_preview() -> Node2D:
	return _container.get_states().building.preview

## Gets the expected preview name for a placeable
func _get_expected_preview_name(placeable: Placeable) -> String:
	return placeable.get_packed_root_name()

## Asserts that preview is not null and has the expected name
func _assert_preview_valid_and_named(preview: Node2D, expected_name: String) -> void:
	assert_object(preview).append_failure_message(
		"Building system preview should not be null after enter_build_mode"
	).is_not_null()
	
	if preview != null:
		assert_str(preview.name).append_failure_message(
			"Preview name should be '%s' but was '%s'" % [expected_name, preview.name]
		).is_equal(expected_name)

func _create_test_placeable_with_rules() -> Placeable:
	# Create a copy of the test placeable and add placement rules
	var placeable: Placeable = Placeable.new()
	placeable.packed_scene = placeable_2d_test.packed_scene
	placeable.display_name = "Test Placeable With Rules"
	
	# Create properly configured collision rule
	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = 1
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	# Initialize messages to prevent setup issues
	if collision_rule.messages == null:
		collision_rule.messages = CollisionRuleSettings.new()
	
	# Create tile rule with proper configuration
	var tile_rule: ValidPlacementTileRule = ValidPlacementTileRule.new()
	tile_rule.expected_tile_custom_data = {"buildable": true}
	
	placeable.placement_rules = [collision_rule, tile_rule]
	return placeable

func _create_different_test_placeable_with_rules() -> Placeable:
	# Create a different placeable for testing name differences
	var placeable: Placeable = Placeable.new()
	placeable.packed_scene = GBTestConstants.eclipse_scene  # Use a different scene
	placeable.display_name = "Different Test Placeable"
	
	# Create properly configured collision rule
	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = 1
	collision_rule.collision_mask = 1
	collision_rule.pass_on_collision = false
	# Initialize messages to prevent setup issues
	if collision_rule.messages == null:
		collision_rule.messages = CollisionRuleSettings.new()
	
	# Create tile rule with proper configuration
	var tile_rule: ValidPlacementTileRule = ValidPlacementTileRule.new()
	tile_rule.expected_tile_custom_data = {"buildable": true}
	
	placeable.placement_rules = [collision_rule, tile_rule]
	return placeable
#endregion
