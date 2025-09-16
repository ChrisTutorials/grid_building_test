extends GdUnitTestSuite

# High-value unit tests to catch small failures behind the integration tests that rely on IndicatorService.
# Focus areas:
#  - IndicatorService.validate_setup_environment collects targeting/template issues
#  - IndicatorService.setup_indicators reports no-collision-shapes early
#  - IndicatorService.setup_indicators reports missing CollisionMapper when nulled

var _logger: GBLogger

func before_test() -> void:
	_logger = GBLogger.new(GBDebugSettings.new())

# Test catches: Missing template and invalid targeting state causing setup failures
func test_validate_setup_environment_collects_targeting_issues() -> void:
	var service := IndicatorService.new(null, null, null, _logger)
	var preview := Node2D.new()
	auto_free(preview)
	# Missing template and invalid targeting state -> validate should fail and add issues
	var report := service.setup_indicators(preview, [])
	assert_that(report != null).is_true()
	var issues := report.issues
	assert_that(issues.size() > 0).append_failure_message("Expected issues when template/targeting are missing").is_true()
	assert_array(issues).append_failure_message("Expected template missing issue present").contains(["Indicator template is not set; cannot create indicators."])

# Test catches: Preview objects without collision shapes causing early abort
func test_setup_indicators_reports_no_collision_shapes() -> void:
	# Create environment using premade scene
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	assert_that(env_scene).is_not_null()
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)

	var gts: GridTargetingState = env.grid_targeting_system.get_state()
	var template: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var parent := Node2D.new()
	auto_free(parent)
	var service := IndicatorService.new(parent, gts, template, _logger)
	# Preview has no shapes
	var preview := Node2D.new()
	auto_free(preview)
	var report := service.setup_indicators(preview, [])
	assert_that(report != null).is_true()
	assert_array(report.issues).append_failure_message("Should report no collision shapes found").contains(["setup_indicators: no collision shapes found on test object; aborting indicator generation"])

# Test catches: Missing collision mapper causing setup failure
func test_setup_indicators_reports_missing_collision_mapper_when_nulled() -> void:
	# Create environment using premade scene
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	assert_that(env_scene).is_not_null()
	var env: AllSystemsTestEnvironment = env_scene.instantiate()
	add_child(env)

	var gts: GridTargetingState = env.grid_targeting_system.get_state()
	var template: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	var parent := Node2D.new()
	auto_free(parent)
	var service := IndicatorService.new(parent, gts, template, _logger)
	# Build a preview with a simple StaticBody2D+CollisionPolygon2D so owner_shapes isn't empty
	var preview := StaticBody2D.new()
	auto_free(preview)
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	preview.add_child(poly)
	# Force collision mapper to be missing to hit the specific branch
	service._collision_mapper = null
	var report := service.setup_indicators(preview, [])
	assert_that(report != null).is_true()
	assert_array(report.issues).append_failure_message("Should report missing collision mapper").contains(["setup_indicators: collision_mapper is not available."])
