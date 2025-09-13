extends GdUnitTestSuite

# High-value unit tests for IndicatorManager to catch failures in indicator generation and management.
# Focus areas:
#  - IndicatorManager.try_setup generates indicators with valid setup
#  - IndicatorManager handles collision layer/mask matching correctly
#  - IndicatorManager reports issues when setup fails
#  - IndicatorManager manages indicator lifecycle properly

var _logger: GBLogger

func before_test() -> void:
	_logger = GBLogger.new(GBDebugSettings.new())

# Test catches: IndicatorManager failing to generate indicators despite valid setup (integration test issue: 0 indicators)
# EXPECTED FAILURE: Catches real issue where indicator generation fails despite valid collision setup
# This test failure indicates the collision mapping/indicator generation system has issues that would cause
# integration tests to show "0 indicators generated" despite valid collision objects and rules
# Debug output shows: validation passes (no issues) but 0 indicators generated
func test_indicator_manager_try_setup_generates_indicators() -> void:
	# Create environment similar to integration test
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self, true, true)
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)  # Parent the manager

	# Create IndicatorManager directly without container
	var manager := UnifiedTestFactory.create_minimal_indicator_manager(self, parent, gts, template)

	# Create preview object with collision shape matching integration test setup
	var preview := StaticBody2D.new()
	auto_free(preview)
	preview.collision_layer = 513  # bits 0+9 from test
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	preview.add_child(shape)
	gts.target = preview

	# Create a tile check rule that should match (instead of generic PlacementRule)
	var rule := TileCheckRule.new()
	rule.apply_to_objects_mask = 1  # bit 0 should match with layer bit 0
	rule.resource_name = "test_unoccupied_space"

	var report := manager.try_setup([rule], gts)
	assert_that(report != null).append_failure_message("Expected non-null PlacementReport").is_true()
	
	# Verify indicators report structure and content
	assert_that(report.indicators_report != null).append_failure_message("Expected non-null indicators report").is_true()
	
	if report.indicators_report != null:
		var report_issues := report.indicators_report.issues
		assert_that(report_issues is Array).append_failure_message("Indicators report should have issues array").is_true()
		
		var report_indicators := report.indicators_report.indicators
		assert_that(report_indicators is Array).append_failure_message("Indicators report should have indicators array").is_true()
	
	var indicators := manager.get_indicators()
	var all_issues := report.get_all_issues()
	# NOTE: This test is EXPECTED TO FAIL - it catches a real issue in indicator generation
	# When this test passes, it means the collision mapping/indicator generation system is working correctly
	# Currently fails with: validation passes but 0 indicators generated (catches collision mapping issues)
	assert_that(indicators.size() > 0).append_failure_message("Expected indicators to be generated for preview with collision shapes. Report issues: " + str(all_issues)).is_true()
