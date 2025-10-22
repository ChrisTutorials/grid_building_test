## Unit test: Verifies preview objects are excluded from collision detection during placement
##
## ISSUE: When entering build mode, the preview object's collision shapes were being detected
## by the indicators, causing false "collision" states even though the preview should not
## collide with itself.
##
## FIX: Preview objects must be added to GridTargetingState.collision_exclusions so that
## CollisionsCheckRule.setup_indicator() adds them as exceptions to the indicator shapecasts.
##
## This test validates the fix by:
## 1. Entering build mode with a placeable that has collision shapes
## 2. Verifying the preview is added to collision_exclusions
## 3. Verifying indicators don't detect collision with the preview itself
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: BuildingTestEnvironment
var _building_system: BuildingSystem
var _indicator_manager: IndicatorManager
var _gts: GridTargetingState
var _container: GBCompositionContainer
var _positioner: Node2D

func before_test() -> void:
	# Use scene_runner for reliable frame simulation
	runner = scene_runner(GBTestConstants.BUILDING_TEST_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames

	env = runner.scene() as BuildingTestEnvironment

	# Get systems
	_building_system = env.building_system
	_indicator_manager = env.indicator_manager
	_container = env.get_container()

	# Validate critical dependencies before proceeding
	assert(_container != null, "Container must not be null")

	_gts = _container.get_targeting_state()
	assert(_gts != null, "GridTargetingState must not be null - container not properly initialized")

	_positioner = env.positioner
	assert(_positioner != null, "Positioner must not be null")

	# Position at a safe tile
	var safe_tile: Vector2i = Vector2i(0, 0)
	var tile_world: Vector2 = env.tile_map_layer.map_to_local(safe_tile)
	_positioner.global_position = tile_world

	# Clear collision_exclusions to prevent freed object issues from previous tests
	_gts.collision_exclusions.clear()

	runner.simulate_frames(1)

func after_test() -> void:
	runner = null

#region UNIT TEST CASES

## Test: Preview object is added to collision_exclusions when entering build mode
## Setup: Create placeable with collision shapes
## Act: Enter build mode
## Assert: Preview object is in collision_exclusions list
func test_preview_added_to_collision_exclusions_on_enter_build_mode() -> void:
	# Create a placeable with collision body
	var placeable: Placeable = GBTestConstants.PLACEABLE_RECT_4X2

	# Verify collision_exclusions is initially empty
	assert_array(_gts.collision_exclusions).append_failure_message(
		"collision_exclusions should start empty"
	).is_empty()

	# Enter build mode
	var report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_bool(report.is_successful()).append_failure_message(
		"enter_build_mode should succeed: %s" % str(report.get_issues())
	).is_true()

	# Simulate frames for preview creation and physics setup
	runner.simulate_frames(3)

	# Get the preview object - check both sources
	var preview_from_target: Node2D = _gts.get_target()
	var preview_from_state: Node2D = _container.get_states().building.preview

	# Enhanced diagnostics
	var diagnostic: String = _format_preview_diagnostic(preview_from_target, preview_from_state)

	# ASSERT: Preview must be created
	assert_object(preview_from_state).append_failure_message(
		"%s\nPreview must be created after enter_build_mode" % diagnostic
	).is_not_null()

	var preview: Node2D = preview_from_state

	# ASSERT: Preview must be in collision_exclusions
	var is_excluded: bool = _gts.collision_exclusions.has(preview)
	var exclusion_diagnostic: String = _format_exclusion_diagnostic(preview, is_excluded)

	assert_bool(is_excluded).append_failure_message(
		"%s\nPreview MUST be in collision_exclusions" % exclusion_diagnostic
	).is_true()

## Test: Indicators do not detect collision with preview itself
## Setup: Enter build mode, wait for indicator setup
## Act: Force indicator collision detection update
## Assert: No indicators report collision with the preview object
func test_indicators_do_not_collide_with_preview() -> void:
	# Create placeable with collision shapes
	var placeable: Placeable = GBTestConstants.PLACEABLE_RECT_4X2

	# Enter build mode
	var report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_bool(report.is_successful()).append_failure_message(
		"enter_build_mode failed: %s" % str(report.get_issues())
	).is_true()

	# Simulate frames for preview and indicator setup
	runner.simulate_frames(3)

	# Get preview and indicators - use building_state as source of truth
	var preview: Node2D = _container.get_states().building.preview
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()

	assert_object(preview).append_failure_message(
		"Preview should be created when entering build mode"
	).is_not_null()
	assert_int(indicators.size()).append_failure_message(
		"Should have created indicators for placeable"
	).is_greater(0)

	# Check if preview is excluded (should be)
	var is_preview_excluded: bool = _gts.collision_exclusions.has(preview)

	# Force update all indicators and check collision state
	var self_colliding_count: int = 0
	var indicator_details: Array[String] = []

	for indicator in indicators:
		if indicator == null or not is_instance_valid(indicator):
			continue

		# Force shapecast update
		indicator.force_shapecast_update()

		if indicator.is_colliding():
			var collider: Object = indicator.get_collider(0)

			if collider and is_instance_valid(collider):
				# Walk up node tree to find the root collision body
				var collider_root: Node = collider as Node
				while collider_root and collider_root.get_parent():
					var parent: Node = collider_root.get_parent()
					# Stop when we reach the positioner or world level
					if parent == _positioner or parent.name == "World" or parent.name == "Level":
						break
					collider_root = parent

				# Check if this is the preview itself
				if collider_root == preview:
					self_colliding_count += 1
					indicator_details.append(
						"  Indicator at %s: SELF-COLLISION detected with preview (collider: %s, type: %s)" % [
							str(indicator.global_position),
							str(collider.name),
							collider.get_class()
						]
					)
				else:
					var root_name: String = "null"
					if collider_root and is_instance_valid(collider_root):
						root_name = str(collider_root.name)
					indicator_details.append(
						"  Indicator at %s: collision with OTHER object: %s (root: %s)" % [
							str(indicator.global_position),
							(collider.name if collider and is_instance_valid(collider) else "null"),
							root_name
						]
					)

	# Build diagnostic
	var diagnostic: String = "Indicator Self-Collision Check:\n"
	var preview_name_diag: String = "null" if not (preview and is_instance_valid(preview)) else str(preview.name)
	diagnostic += "  Preview: %s\n" % preview_name_diag
	diagnostic += "  Preview excluded: %s\n" % str(is_preview_excluded)
	diagnostic += "  Total indicators: %d\n" % indicators.size()
	diagnostic += "  Self-colliding indicators: %d\n" % self_colliding_count

	if preview is CollisionObject2D:
		diagnostic += "  Preview collision_layer: %d\n" % preview.collision_layer
		diagnostic += "  Preview collision_mask: %d\n" % preview.collision_mask

	if indicator_details.size() > 0:
		diagnostic += "\nCollision Details:\n" + "\n".join(indicator_details)

	# ASSERT: Preview must be excluded
	assert_bool(is_preview_excluded).append_failure_message(
		"%s\n\nPreview must be in collision_exclusions" % diagnostic
	).is_true()

	# ASSERT: No self-collision detected
	assert_int(self_colliding_count).append_failure_message(
		"%s\n\nIndicators must NOT detect collision with preview itself" % diagnostic
	).is_equal(0)

## Test: Multiple placeables all properly exclude their previews
## Setup: Test with different placeable types
## Act: Enter build mode with each, check exclusions
## Assert: All previews properly excluded
@warning_ignore("unused_parameter")
func test_multiple_placeables_all_exclude_previews(
	placeable_name: String,
	placeable: Placeable,
	test_parameters := [
		["RECT_4X2", GBTestConstants.PLACEABLE_RECT_4X2],
	]
) -> void:
	# Enter build mode
	var report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_bool(report.is_successful()).append_failure_message(
		"enter_build_mode failed for %s: %s" % [placeable_name, str(report.get_issues())]
	).is_true()

	# Simulate frames for preview creation and physics setup
	runner.simulate_frames(4)

	# Get preview from building_state (source of truth)
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).append_failure_message(
		"Preview should be set for %s" % placeable_name
	).is_not_null()

	# Check exclusion
	var is_excluded: bool = _gts.collision_exclusions.has(preview)
	var preview_name_for_msg: String = "NULL" if not preview else str(preview.name)
	assert_bool(is_excluded).append_failure_message(
		"Preview for %s must be in collision_exclusions. Exclusions: %d, Preview: %s" % [
			placeable_name,
			_gts.collision_exclusions.size(),
			preview_name_for_msg
		]
	).is_true()

	# Exit build mode for next iteration
	_building_system.exit_build_mode()
	runner.simulate_frames(1)
	await get_tree().process_frame

## Test: Exiting build mode clears collision_exclusions
## Setup: Enter build mode (adds preview to exclusions)
## Act: Exit build mode
## Assert: collision_exclusions is cleared
func test_exit_build_mode_clears_collision_exclusions() -> void:
	var placeable: Placeable = GBTestConstants.PLACEABLE_RECT_4X2

	# Enter build mode
	var report: PlacementReport = _building_system.enter_build_mode(placeable)
	assert_bool(report.is_successful()).append_failure_message(
		"Should successfully enter build mode with valid placeable"
	).is_true()
	runner.simulate_frames(2)

	# Verify preview is excluded - use building_state
	var preview: Node2D = _container.get_states().building.preview
	assert_object(preview).append_failure_message(
		"Preview should exist after entering build mode"
	).is_not_null()
	assert_bool(_gts.collision_exclusions.has(preview)).append_failure_message(
		"Preview should be excluded after entering build mode"
	).is_true()

	# Exit build mode
	_building_system.exit_build_mode()
	runner.simulate_frames(1)

	# ASSERT: collision_exclusions should be cleared
	assert_array(_gts.collision_exclusions).append_failure_message(
		"collision_exclusions should be cleared after exiting build mode. Current size: %d" % _gts.collision_exclusions.size()
	).is_empty()

#endregion

#region DIAGNOSTIC HELPERS - DRY Pattern

## Format preview diagnostic information showing both preview sources
func _format_preview_diagnostic(preview_from_target: Node2D, preview_from_state: Node2D) -> String:
	var lines: Array[String] = []
	lines.append("Preview Creation Diagnostic:")
	var target_name: String = "NULL" if not preview_from_target else str(preview_from_target.name)
	var state_name: String = "NULL" if not preview_from_state else str(preview_from_state.name)
	lines.append("  Preview from _gts.target: %s" % target_name)
	lines.append("  Preview from building_state: %s" % state_name)
	lines.append("  Match: %s" % str(preview_from_target == preview_from_state))
	lines.append("  Building system in build mode: %s" % str(_building_system.is_in_build_mode()))
	return "\n".join(lines)

## Format collision exclusion diagnostic information
func _format_exclusion_diagnostic(preview: Node2D, is_excluded: bool) -> String:
	var lines: Array[String] = []
	lines.append("Collision Exclusion Check:")
	var preview_name: String = "NULL" if not (preview and is_instance_valid(preview)) else str(preview.name)
	lines.append("  Preview: %s" % preview_name)
	lines.append("  Preview excluded: %s" % str(is_excluded))
	lines.append("  Exclusions count: %d" % _gts.collision_exclusions.size())

	if _gts.collision_exclusions.size() > 0:
		lines.append("  Exclusions list:")
		for i in range(_gts.collision_exclusions.size()):
			var excluded: Node = _gts.collision_exclusions[i]
			var excluded_info: String = "NULL"
			if excluded and is_instance_valid(excluded):
				excluded_info = "%s (valid)" % excluded.name
			lines.append("    [%d] %s" % [i, excluded_info])

	return "\n".join(lines)

#endregion
