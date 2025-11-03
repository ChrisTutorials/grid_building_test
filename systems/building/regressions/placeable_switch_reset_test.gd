## Unit Test: Placeable Switch Reset Behavior
##
## Tests that when BuildingSystem.enter_build_mode() is called with a new placeable,
## the system properly resets:
## 1. All old indicators are cleared
## 2. New indicators are created for the new placeable
## 3. ManipulationParent rotation is reset to identity (0 degrees)
##
## This is a focused unit test for Issue #2:
## https://github.com/ChrisTutorials/grid_building_test/issues/2
##
## Root Cause: When switching placeables, indicators and manipulation rotation
## were not being properly reset, causing visual bugs where old indicator positions
## persisted or appeared at wrong locations.
extends GdUnitTestSuite

# Test environment and components
var env: AllSystemsTestEnvironment
var _building_system: BuildingSystem
var _indicator_manager: IndicatorManager
var _manipulation_parent: ManipulationParent
var _container: GBCompositionContainer


## Initializes test environment (AllSystemsTestEnvironment) with BuildingSystem, IndicatorManager, ManipulationParent.
## Validates all required components are available before tests run.
func before_test() -> void:
	# Create test environment using GBTestConstants
	env = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path).scene()

	# Validate environment setup
	assert_object(env).append_failure_message("Failed to create test environment").is_not_null()
	var issues: Array[String] = env.get_issues()
	(
		assert_array(issues) \
		. append_failure_message("Environment has issues: %s" % str(issues)) \
		. is_empty()
	)

	# Initialize components
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_manipulation_parent = env.manipulation_parent
	_container = env.get_container()

	# Validate required components
	(
		assert_object(_building_system) \
		. append_failure_message("BuildingSystem not available") \
		. is_not_null()
	)
	(
		assert_object(_indicator_manager) \
		. append_failure_message("IndicatorManager not available") \
		. is_not_null()
	)
	(
		assert_object(_manipulation_parent) \
		. append_failure_message("ManipulationParent not available") \
		. is_not_null()
	)


## Exits build mode if BuildingSystem is still in build mode; cleans up test state.
func after_test() -> void:
	if _building_system and _building_system.is_in_build_mode():
		_building_system.exit_build_mode()


#region PLACEABLE SWITCH RESET TESTS


## Tests that old indicators are cleared when entering build mode with a new placeable.
func test_indicators_cleared_when_switching_placeables() -> void:

	# Step 1: Enter build mode with first placeable (pillar)
	var pillar: Placeable = GBTestConstants.PLACEABLE_PILLAR_TD
	var pillar_report: PlacementReport = _building_system.enter_build_mode(pillar)

	(
		assert_bool(pillar_report.is_successful()) \
		. append_failure_message(
			"Failed to enter build mode with pillar: %s" % str(pillar_report.get_issues())
		) \
		. is_true()
	)

	# Get initial indicators
	var initial_indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	var initial_count: int = initial_indicators.size()

	(
		assert_int(initial_count) \
		. append_failure_message("Expected indicators after entering build mode with pillar") \
		. is_greater(0)
	)

	# Store references to initial indicators to verify they get freed
	var initial_indicator_ids: Array[int] = []
	for indicator in initial_indicators:
		if indicator != null:
			initial_indicator_ids.append(indicator.get_instance_id())

	# Step 2: Enter build mode with different placeable (smithy)
	var smithy: Placeable = GBTestConstants.PLACEABLE_SMITHY_TD
	var smithy_report: PlacementReport = _building_system.enter_build_mode(smithy)

	(
		assert_bool(smithy_report.is_successful()) \
		. append_failure_message(
			"Failed to enter build mode with smithy: %s" % str(smithy_report.get_issues())
		) \
		. is_true()
	)

	# Step 3: Verify old indicators were cleared
	var new_indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()

	# Check that old indicator instances are no longer valid
	var old_indicators_still_valid: int = 0
	for old_id in initial_indicator_ids:
		if instance_from_id(old_id) != null:
			old_indicators_still_valid += 1

	(
		assert_int(old_indicators_still_valid) \
		. append_failure_message(
			(
				"Old indicators should be freed when switching placeables. Found %d/%d still valid"
				% [old_indicators_still_valid, initial_indicator_ids.size()]
			)
		) \
		. is_equal(0)
	)

	# Step 4: Verify new indicators were created
	(
		assert_int(new_indicators.size()) \
		. append_failure_message("Expected new indicators after switching to smithy placeable") \
		. is_greater(0)
	)

	# Verify new indicators are actually different instances
	var new_indicator_ids: Array[int] = []
	for indicator in new_indicators:
		if indicator != null:
			new_indicator_ids.append(indicator.get_instance_id())

	# Check that none of the new indicator IDs match old indicator IDs
	for new_id in new_indicator_ids:
		(
			assert_bool(initial_indicator_ids.has(new_id)) \
			. append_failure_message(
				"New indicators should be different instances, found old indicator ID: %d" % new_id
			) \
			. is_false()
		)


## Tests that ManipulationParent rotation resets to 0 when switching placeables.
func test_manipulation_parent_rotation_reset_on_placeable_switch() -> void:

	# Step 1: Enter build mode with pillar
	var pillar: Placeable = GBTestConstants.PLACEABLE_PILLAR_TD
	var pillar_report: PlacementReport = _building_system.enter_build_mode(pillar)

	(
		assert_bool(pillar_report.is_successful()) \
		. append_failure_message(
			"Failed to enter build mode with pillar: %s" % str(pillar_report.get_issues())
		) \
		. is_true()
	)

	# Verify initial rotation is 0
	(
		assert_float(_manipulation_parent.rotation) \
		. append_failure_message(
			"ManipulationParent should start at 0 rotation, got: %f" % _manipulation_parent.rotation
		) \
		. is_equal_approx(0.0, 0.01)
	)

	# Step 2: Apply rotation to ManipulationParent (simulate rotation action)
	var rotation_degrees: float = 90.0
	_manipulation_parent.apply_rotation(rotation_degrees)

	# Verify rotation was applied
	var rotated_value: float = _manipulation_parent.rotation
	(
		assert_float(rotated_value) \
		. append_failure_message(
			"Rotation should be applied to ManipulationParent, got: %f" % rotated_value
		) \
		. is_greater(0.0)
	)

	# Step 3: Switch to different placeable (smithy)
	var smithy: Placeable = GBTestConstants.PLACEABLE_SMITHY_TD
	var smithy_report: PlacementReport = _building_system.enter_build_mode(smithy)

	(
		assert_bool(smithy_report.is_successful()) \
		. append_failure_message(
			"Failed to enter build mode with smithy: %s" % str(smithy_report.get_issues())
		) \
		. is_true()
	)

	# Step 4: Verify rotation was reset to 0
	(
		assert_float(_manipulation_parent.rotation) \
		. append_failure_message(
			(
				"ManipulationParent rotation should reset to 0 when switching placeables. Was: %f, Now: %f"
				% [rotated_value, _manipulation_parent.rotation]
			)
		) \
		. is_equal_approx(0.0, 0.01)
	)


## Tests that both rotation reset AND indicator cleanup occur together on placeable switch.
func test_rotation_reset_and_indicators_cleared_together() -> void:

	# Step 1: Enter build mode with first placeable and rotate
	var pillar: Placeable = GBTestConstants.PLACEABLE_PILLAR_TD
	var pillar_report: PlacementReport = _building_system.enter_build_mode(pillar)
	(
		assert_bool(pillar_report.is_successful()) \
		. append_failure_message("Failed to enter build mode with pillar for rotation test") \
		. is_true()
	)

	# Get initial state
	var initial_indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	var initial_indicator_count: int = initial_indicators.size()
	(
		assert_int(initial_indicator_count) \
		. append_failure_message("Expected indicators to be created for pillar placeable") \
		. is_greater(0)
	)

	# Apply rotation
	_manipulation_parent.apply_rotation(90.0)
	var rotated_value: float = _manipulation_parent.rotation
	(
		assert_float(rotated_value) \
		. append_failure_message("Rotation should be applied before placeable switch") \
		. is_greater(0.0)
	)

	# Store indicator IDs
	var initial_ids: Array[int] = []
	for indicator in initial_indicators:
		if indicator != null:
			initial_ids.append(indicator.get_instance_id())

	# Step 2: Switch placeable
	var smithy: Placeable = GBTestConstants.PLACEABLE_SMITHY_TD
	var smithy_report: PlacementReport = _building_system.enter_build_mode(smithy)
	(
		assert_bool(smithy_report.is_successful()) \
		. append_failure_message("Failed to switch to smithy placeable") \
		. is_true()
	)

	# Step 3: Verify BOTH rotation reset AND indicators cleared

	# Check rotation reset
	(
		assert_float(_manipulation_parent.rotation) \
		. append_failure_message(
			(
				"Rotation should reset to 0 on placeable switch. Before: %f, After: %f"
				% [rotated_value, _manipulation_parent.rotation]
			)
		) \
		. is_equal_approx(0.0, 0.01)
	)

	# Check indicators cleared
	var old_indicators_still_valid: int = 0
	for old_id in initial_ids:
		if instance_from_id(old_id) != null:
			old_indicators_still_valid += 1

	(
		assert_int(old_indicators_still_valid) \
		. append_failure_message(
			(
				"Old indicators should be cleared on placeable switch. %d/%d still valid"
				% [old_indicators_still_valid, initial_ids.size()]
			)
		) \
		. is_equal(0)
	)

	# Check new indicators created
	var new_indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	(
		assert_int(new_indicators.size()) \
		. append_failure_message("New indicators should be created for new placeable") \
		. is_greater(0)
	)


## Tests that reset behavior (rotation, indicators) works correctly across multiple placeable switches.
func test_multiple_placeable_switches_maintain_reset_behavior() -> void:

	var placeables: Array[Placeable] = [
		GBTestConstants.PLACEABLE_PILLAR_TD,
		GBTestConstants.PLACEABLE_SMITHY_TD,
		GBTestConstants.PLACEABLE_PILLAR_TD,  # Switch back to pillar
		GBTestConstants.PLACEABLE_SMITHY_TD  # Switch back to smithy
	]

	for i in range(placeables.size()):
		var placeable: Placeable = placeables[i]

		# Apply rotation before switch (except first iteration)
		if i > 0:
			_manipulation_parent.apply_rotation(45.0 * i)  # Different rotation each time

		# Switch placeable
		var report: PlacementReport = _building_system.enter_build_mode(placeable)
		(
			assert_bool(report.is_successful()) \
			. append_failure_message(
				"Failed to enter build mode with placeable %d: %s" % [i, str(report.get_issues())]
			) \
			. is_true()
		)

		# Verify rotation reset
		(
			assert_float(_manipulation_parent.rotation) \
			. append_failure_message(
				(
					"Rotation should reset to 0 on switch %d, got: %f"
					% [i, _manipulation_parent.rotation]
				)
			) \
			. is_equal_approx(0.0, 0.01)
		)

		# Verify indicators exist
		var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
		(
			assert_int(indicators.size()) \
			. append_failure_message("Expected indicators after switch %d" % i) \
			. is_greater(0)
		)


#endregion

#region EDGE CASE TESTS


## Tests that entering build mode with the same placeable still resets state (rotation, indicators).
func test_switching_to_same_placeable_still_resets() -> void:

	# Enter build mode with pillar
	var pillar: Placeable = GBTestConstants.PLACEABLE_PILLAR_TD
	var first_report: PlacementReport = _building_system.enter_build_mode(pillar)
	(
		assert_bool(first_report.is_successful()) \
		. append_failure_message("Failed to enter build mode with pillar for same-placeable test") \
		. is_true()
	)

	# Apply rotation
	_manipulation_parent.apply_rotation(90.0)
	(
		assert_float(_manipulation_parent.rotation) \
		. append_failure_message("Rotation should be applied before re-entering build mode") \
		. is_greater(0.0)
	)

	# "Switch" to same placeable (re-enter build mode)
	var second_report: PlacementReport = _building_system.enter_build_mode(pillar)
	(
		assert_bool(second_report.is_successful()) \
		. append_failure_message("Failed to re-enter build mode with same placeable") \
		. is_true()
	)

	# Verify rotation still reset
	(
		assert_float(_manipulation_parent.rotation) \
		. append_failure_message(
			(
				"Rotation should reset even when re-entering with same placeable, got: %f"
				% _manipulation_parent.rotation
			)
		) \
		. is_equal_approx(0.0, 0.01)
	)


## Tests that exiting build mode also clears all indicators.
func test_exit_build_mode_clears_indicators() -> void:

	# Enter build mode
	var pillar: Placeable = GBTestConstants.PLACEABLE_PILLAR_TD
	var report: PlacementReport = _building_system.enter_build_mode(pillar)
	(
		assert_bool(report.is_successful()) \
		. append_failure_message("Failed to enter build mode for exit test") \
		. is_true()
	)

	# Verify indicators exist
	var indicators_before: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	(
		assert_int(indicators_before.size()) \
		. append_failure_message("Expected indicators to exist before exiting build mode") \
		. is_greater(0)
	)

	# Exit build mode
	_building_system.exit_build_mode()

	# Verify indicators cleared
	var indicators_after: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	(
		assert_int(indicators_after.size()) \
		. append_failure_message(
			(
				"Indicators should be cleared after exiting build mode, found: %d"
				% indicators_after.size()
			)
		) \
		. is_equal(0)
	)

#endregion
