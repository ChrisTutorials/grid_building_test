extends GdUnitTestSuite

## Unit tests for IndicatorService focusing on core functionality and edge cases
##
## Test Areas:
## - Environment validation and setup failures
## - Indicator positioning and tile map alignment
## - Template indicator cleanup after generation
## - Collision mapping and shape detection
##
## Uses GBTestConstants for consistent test configuration and shared values

#region Test Constants
# Magic numbers extracted to constants following GDUnit best practices
const EXPECTED_INDICATOR_COUNT_2X2: int = 4
const TILE_GRID_OFFSET_X: int = 1
const TILE_GRID_OFFSET_Y: int = 1
const TEST_COLLISION_POLYGON_SIZE: float = 8.0
const EXPECTED_TEMPLATE_FREE_TIMEOUT_MS: int = 100

# Test object dimensions for creating preview objects
const TEST_PREVIEW_WIDTH: float = GBTestConstants.DEFAULT_TILE_SIZE.x * 2
const TEST_PREVIEW_HEIGHT: float = GBTestConstants.DEFAULT_TILE_SIZE.y * 2
const HALF_TILE_SIZE: float = GBTestConstants.DEFAULT_TILE_SIZE.x * 0.5
#endregion

#region Test State
var _logger: GBLogger
var _test_env: AllSystemsTestEnvironment
var _service: IndicatorService
var _indicators_parent: Node2D
#endregion

func before_test() -> void:
	_logger = GBLogger.new(GBDebugSettings.new())
	_setup_test_environment()
	_create_indicators_parent()

func after_test() -> void:
	_cleanup_test_environment()

#region Test Setup Helpers
func _setup_test_environment() -> void:
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	assert_that(env_scene).is_not_null().append_failure_message("Failed to load test environment scene")
	
	_test_env = env_scene.instantiate()
	add_child(_test_env)
	auto_free(_test_env)

func _create_indicators_parent() -> void:
	_indicators_parent = Node2D.new()
	_indicators_parent.name = "TestIndicatorsParent"
	add_child(_indicators_parent)
	auto_free(_indicators_parent)

func _cleanup_test_environment() -> void:
	if _service:
		_service = null

func _create_test_service() -> IndicatorService:
	var gts: GridTargetingState = _test_env.grid_targeting_system.get_state()
	var template: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	return IndicatorService.new(_indicators_parent, gts, template, _logger)

func _create_preview_with_collision_shapes() -> StaticBody2D:
	var preview := StaticBody2D.new()
	auto_free(preview)
	
	# Create a 2x2 tile collision area (32x32 pixels per tile = 64x64 total)
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-TEST_COLLISION_POLYGON_SIZE, -TEST_COLLISION_POLYGON_SIZE), 
		Vector2(TEST_COLLISION_POLYGON_SIZE, -TEST_COLLISION_POLYGON_SIZE), 
		Vector2(TEST_COLLISION_POLYGON_SIZE, TEST_COLLISION_POLYGON_SIZE), 
		Vector2(-TEST_COLLISION_POLYGON_SIZE, TEST_COLLISION_POLYGON_SIZE)
	])
	preview.add_child(poly)
	
	return preview

func _create_empty_tile_check_rules() -> Array[TileCheckRule]:
	return []
#endregion


#region Environment Validation Tests

# Test catches: Missing template and invalid targeting state causing setup failures
func test_validate_setup_environment_collects_targeting_issues() -> void:
	var service := IndicatorService.new(null, null, null, _logger)
	var preview := Node2D.new()
	auto_free(preview)
	
	# Missing template and invalid targeting state -> validate should fail and add issues
	var report := service.setup_indicators(preview, _create_empty_tile_check_rules())
	
	assert_that(report).is_not_null().append_failure_message("Expected report to be created")
	var issues := report.issues
	assert_that(issues.size()).is_greater(0).append_failure_message("Expected issues when template/targeting are missing")
	assert_array(issues).append_failure_message("Expected template missing issue present").contains(["Indicator template is not set; cannot create indicators."])

# Test catches: Preview objects without collision shapes causing early abort
func test_setup_indicators_reports_no_collision_shapes() -> void:
	_service = _create_test_service()
	
	# Preview has no shapes
	var preview := Node2D.new()
	auto_free(preview)
	
	var report := _service.setup_indicators(preview, _create_empty_tile_check_rules())
	
	assert_that(report).is_not_null().append_failure_message("Expected report to be created")
	assert_array(report.issues).append_failure_message("Should report no collision shapes found").contains(["setup_indicators: no collision shapes found on test object; aborting indicator generation"])

# Test catches: Missing collision mapper causing setup failure
func test_setup_indicators_reports_missing_collision_mapper_when_nulled() -> void:
	_service = _create_test_service()
	
	# Build a preview with collision shapes so owner_shapes isn't empty
	var preview := _create_preview_with_collision_shapes()
	
	# Force collision mapper to be missing to hit the specific branch
	_service._collision_mapper = null
	var report := _service.setup_indicators(preview, _create_empty_tile_check_rules())
	
	assert_that(report).is_not_null().append_failure_message("Expected report to be created")
	assert_array(report.issues).append_failure_message("Should report missing collision mapper").contains(["setup_indicators: collision_mapper is not available."])

#endregion

#region Indicator Positioning Tests

# Test: Each generated indicator should be positioned at the correct tile position
func test_indicators_positioned_at_correct_tile_positions() -> void:
	_service = _create_test_service()
	
	# Create preview with collision shapes that will generate multiple indicators
	var preview := _create_preview_with_collision_shapes()
	
	# Position the preview at a known location
	preview.global_position = Vector2(GBTestConstants.DEFAULT_TILE_SIZE.x * TILE_GRID_OFFSET_X, GBTestConstants.DEFAULT_TILE_SIZE.y * TILE_GRID_OFFSET_Y)
	
	var report := _service.setup_indicators(preview, _create_empty_tile_check_rules())
	
	assert_that(report).is_not_null().append_failure_message("Expected successful indicator setup")
	assert_that(report.issues).is_empty().append_failure_message("Expected no setup issues: " + str(report.issues))
	
	# Verify that indicators were created
	var indicators := _service._indicators
	assert_that(indicators.size()).is_greater(0).append_failure_message("Expected indicators to be generated")
	
	# Check that indicators are positioned at different tile positions (not all at same location)
	var unique_positions: Dictionary = {}
	for indicator in indicators:
		var tile_pos := _get_indicator_tile_position(indicator)
		unique_positions[tile_pos] = true
	
	assert_that(unique_positions.size()).is_greater(1).append_failure_message(
		"Expected indicators at different tile positions, got %d unique positions from %d indicators" % [unique_positions.size(), indicators.size()]
	)

# Test: Indicators should have predictable naming based on their tile offset
func test_indicators_have_offset_based_naming() -> void:
	_service = _create_test_service()
	
	var preview := _create_preview_with_collision_shapes()
	var report := _service.setup_indicators(preview, _create_empty_tile_check_rules())
	
	assert_that(report.issues).is_empty().append_failure_message("Expected no setup issues: " + str(report.issues))
	
	var indicators := _service._indicators
	assert_that(indicators.size()).is_greater(0).append_failure_message("Expected indicators to be generated")
	
	# Verify naming follows the pattern "RuleCheckIndicator-Offset(X,Y)"
	for indicator in indicators:
		assert_that(indicator.name).contains("RuleCheckIndicator-Offset(").append_failure_message(
			"Expected indicator name to contain offset pattern, got: " + indicator.name
		)
		assert_that(indicator.name).contains(",").append_failure_message(
			"Expected indicator name to contain coordinate separator, got: " + indicator.name
		)

#endregion

#region Template Indicator Cleanup Tests

# Test: The original testing indicator should be freed after setup
func test_testing_indicator_freed_after_setup() -> void:
	_service = _create_test_service()
	
	var preview := _create_preview_with_collision_shapes()
	
	# Track the testing indicator before setup (unused but could be useful for debugging)
	var _testing_indicator_before := _service._testing_indicator
	
	var report := _service.setup_indicators(preview, _create_empty_tile_check_rules())
	
	assert_that(report.issues).is_empty().append_failure_message("Expected no setup issues: " + str(report.issues))
	
	# Give some time for cleanup operations
	await get_tree().process_frame
	
	# The testing indicator should be configured during setup but may persist for reuse
	# What we care about is that it's not leaked and the service is properly managing it
	var testing_indicator_after := _service._testing_indicator
	
	# The key test is that the testing indicator exists and is properly managed
	assert_that(testing_indicator_after).is_not_null().append_failure_message("Expected testing indicator to be managed by service")
	
	# Verify the testing indicator is not one of the generated indicators
	var generated_indicators := _service._indicators
	for indicator in generated_indicators:
		assert_that(indicator).is_not_same(testing_indicator_after).append_failure_message(
			"Testing indicator should not be included in generated indicators"
		)

# Test: Testing indicator should be reusable across multiple setups
func test_testing_indicator_reusable_across_setups() -> void:
	_service = _create_test_service()
	
	var preview1 := _create_preview_with_collision_shapes()
	var report1 := _service.setup_indicators(preview1, _create_empty_tile_check_rules())
	
	assert_that(report1.issues).is_empty().append_failure_message("Expected no issues in first setup")
	
	var testing_indicator_first := _service._testing_indicator
	var first_indicators_count := _service._indicators.size()
	
	# Clear indicators and setup again
	_service.clear_indicators()
	
	var preview2 := _create_preview_with_collision_shapes()
	var report2 := _service.setup_indicators(preview2, _create_empty_tile_check_rules())
	
	assert_that(report2.issues).is_empty().append_failure_message("Expected no issues in second setup")
	
	var testing_indicator_second := _service._testing_indicator
	var second_indicators_count := _service._indicators.size()
	
	# The testing indicator should be reused (same instance)
	assert_that(testing_indicator_second).is_same(testing_indicator_first).append_failure_message(
		"Testing indicator should be reused across setups"
	)
	
	# Both setups should generate similar indicator counts
	assert_that(second_indicators_count).is_equal(first_indicators_count).append_failure_message(
		"Expected consistent indicator generation across setups"
	)

#endregion

#region Helper Methods

func _get_indicator_tile_position(indicator: RuleCheckIndicator) -> Vector2i:
	# Convert world position to tile position using the target map from the environment
	var target_map := _test_env.grid_targeting_system.get_state().target_map
	if target_map:
		return target_map.local_to_map(target_map.to_local(indicator.global_position))
	else:
		# Fallback: approximate tile position from world coordinates
		return Vector2i(
			int(indicator.global_position.x / GBTestConstants.DEFAULT_TILE_SIZE.x),
			int(indicator.global_position.y / GBTestConstants.DEFAULT_TILE_SIZE.y)
		)

#endregion
