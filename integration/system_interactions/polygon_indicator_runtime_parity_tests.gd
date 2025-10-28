## Refactored polygon runtime parity test with improved debugging and DRY helpers
extends GdUnitTestSuite

const DebugHelper = preload("uid://cjtkkhcp460sg")

var _test_env: AllSystemsTestEnvironment
var _manager_validation: Dictionary
var _building_validation: Dictionary


func before_test() -> void:
	# Use pre-made environment directly for more robust setup
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(
		GBTestConstants.EnvironmentType.ALL_SYSTEMS
	)
	assert_object(env_scene).is_not_null().append_failure_message(
		"Failed to load ALL_SYSTEMS environment scene"
	)

	_test_env = env_scene.instantiate() as AllSystemsTestEnvironment
	assert_object(_test_env).is_not_null().append_failure_message(
		"Failed to instantiate environment"
	)
	add_child(_test_env)
	auto_free(_test_env)

	# Validate environment setup
	assert_object(_test_env.injector.composition_container).is_not_null()
	assert_object(_test_env.tile_map_layer).is_not_null()
	assert_object(_test_env.positioner).is_not_null()


func after_test() -> void:
	# Test environment will be auto-freed by the test framework
	_manager_validation.clear()
	_building_validation.clear()


func test_polygon_placeable_builds_and_generates_indicators() -> void:
	"""Simplified test focusing on the core functionality: building system entry and indicator generation"""

	# Step 1: Create placeable with clear debugging
	var placeable: Placeable = PlaceableTestFactory.create_polygon_test_placeable(self)
	(
		assert_object(placeable)
		. append_failure_message("Failed to create polygon test placeable")
		. is_not_null()
	)

	# Step 2: Validate building system can enter build mode
	_building_validation = DebugHelper.validate_building_system_entry(self, _test_env, placeable)
	(
		assert_bool(_building_validation.is_successful)
		. append_failure_message(
			(
				"Building system failed to enter build mode. Details:\n%s"
				% _building_validation.error_summary
			)
		)
		. is_true()
	)

	# Step 3: Validate preview exists
	var preview: Node2D = _building_validation.preview
	(
		assert_object(preview)
		. append_failure_message("No preview created after successful build mode entry")
		. is_not_null()
	)

	# Step 4: Create indicator manager and validate setup
	_manager_validation = DebugHelper.create_indicator_manager_with_validation(self, _test_env)
	(
		assert_bool(_manager_validation.is_valid)
		. append_failure_message(
			"Indicator manager setup failed. Issues: %s" % str(_manager_validation.setup_issues)
		)
		. is_true()
	)

	# Step 5: Create rule and test indicator generation
	var rule: CollisionsCheckRule = DebugHelper.create_basic_collision_rule(1)  # Match polygon collision layer
	var rules: Array[TileCheckRule] = [rule]

	var indicator_result: Dictionary = DebugHelper.validate_indicator_setup(
		_manager_validation.manager, preview, rules
	)
	(
		assert_int(indicator_result.indicator_count)
		. append_failure_message(
			"Expected indicators to be generated. Details:\n%s" % indicator_result.summary
		)
		. is_greater(0)
	)


func test_polygon_indicators_align_with_geometry() -> void:
	"""Test that indicators generated align with the actual polygon geometry"""

	# Setup: Use the same build process as above
	var placeable: Placeable = PlaceableTestFactory.create_polygon_test_placeable(self)
	_building_validation = DebugHelper.validate_building_system_entry(self, _test_env, placeable)

	# Skip test if build mode fails
	if not _building_validation.is_successful:
		var diagnostic: String = GBTestDiagnostics.flush_for_assert()
		(
			assert_bool(_building_validation.is_successful)
			. append_failure_message(
				"Build mode failed, cannot test indicator alignment. Diagnostics: %s" % diagnostic
			)
			. is_true()
		)
		return

	var preview: Node2D = _building_validation.preview
	_manager_validation = DebugHelper.create_indicator_manager_with_validation(self, _test_env)

	# Skip test if manager setup fails
	if not _manager_validation.is_valid:
		var diagnostic: String = GBTestDiagnostics.flush_for_assert()
		(
			assert_bool(_manager_validation.is_valid)
			. append_failure_message(
				(
					"Manager setup failed, cannot test indicator alignment. Diagnostics: %s"
					% diagnostic
				)
			)
			. is_true()
		)
		return

	# Generate indicators
	var rule: CollisionsCheckRule = DebugHelper.create_basic_collision_rule(1)
	var rules: Array[TileCheckRule] = [rule]
	var indicator_result: Dictionary = DebugHelper.validate_indicator_setup(
		_manager_validation.manager, preview, rules
	)

	# Skip if no indicators generated
	if indicator_result.indicator_count == 0:
		var diagnostic: String = GBTestDiagnostics.flush_for_assert()
		(
			assert_int(indicator_result.indicator_count)
			. append_failure_message(
				"No indicators generated, cannot test alignment. Diagnostics: %s" % diagnostic
			)
			. is_greater(0)
		)
		return

	# Verify at least one indicator is near the positioner center
	var center_tile: Vector2i = _test_env.tile_map_layer.local_to_map(
		_test_env.positioner.global_position
	)
	var indicators_near_center: int = 0

	for indicator: RuleCheckIndicator in indicator_result.indicators:
		var indicator_tile: Vector2i = _test_env.tile_map_layer.local_to_map(
			indicator.global_position
		)
		var distance: float = indicator_tile.distance_to(center_tile)
		if distance <= 2.0:  # Within 2 tiles of center
			indicators_near_center += 1

	(
		assert_int(indicators_near_center)
		. append_failure_message(
			"Expected at least one indicator near positioner center tile %s" % str(center_tile)
		)
		. is_greater(0)
	)


func test_polygon_preview_has_collision_polygon() -> void:
	"""Unit test to verify polygon preview contains a CollisionPolygon2D child"""

	var placeable: Placeable = PlaceableTestFactory.create_polygon_test_placeable(self)
	_building_validation = DebugHelper.validate_building_system_entry(self, _test_env, placeable)

	# This test can provide useful debugging even if build mode fails
	if not _building_validation.is_successful:
		var diagnostic: String = GBTestDiagnostics.flush_for_assert()
		(
			assert_bool(_building_validation.is_successful)
			. append_failure_message(
				(
					"Build mode failed: %s. Diagnostics: %s"
					% [_building_validation.error_summary, diagnostic]
				)
			)
			. is_true()
		)
		return

	var preview: Node2D = _building_validation.preview

	# Find CollisionPolygon2D child
	var collision_polygon: CollisionPolygon2D = null
	for child in preview.get_children():
		if child is CollisionPolygon2D:
			collision_polygon = child
			break

	(
		assert_object(collision_polygon)
		. append_failure_message(
			"Preview should contain a CollisionPolygon2D child for geometry calculations"
		)
		. is_not_null()
	)

	# Verify polygon has points
	if collision_polygon:
		(
			assert_int(collision_polygon.polygon.size())
			. append_failure_message("CollisionPolygon2D should have polygon points defined")
			. is_greater(2)
		)
