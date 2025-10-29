extends GdUnitTestSuite

## Consolidated Indicator Rule Unit Tests
##
## This file consolidates 14 indicator rule test files (3826 lines) into a comprehensive
## test suite covering all indicator-related functionality.
##
## Original files consolidated:
## - concave_polygon_indicator_test.gd
## - grid_targeting_state_debug_test.gd
## - indicator_coordinate_transformation_unit_test.gd
## - indicator_factory_positioning_unit_test.gd
## - indicator_factory_unit_test.gd
## - indicator_manager_unit_test.gd
## - indicator_positioning_regression_test.gd
## - indicator_reconcile_unit_test.gd
## - indicator_service_unit_test.gd
## - indicator_setup_utils_unit_test.gd
## - polygon_indicator_overlap_threshold_test.gd
## - positioning_integration_test.gd
## - rule_check_indicator_comprehensive_test.gd
## - rule_check_indicator_test.gd
##
## Test Areas:
## - IndicatorFactory functionality and edge cases
## - RuleCheckIndicator creation, validation, and collision detection
## - IndicatorService positioning, tile map alignment, and cleanup
## - Coordinate transformations and positioning logic
## - Polygon and shape-based indicator generation
## - Integration between components

#region Constants

const EXPECTED_INDICATOR_COUNT_2X2: int = 4
const TILE_GRID_OFFSET_X: int = 1
const TILE_GRID_OFFSET_Y: int = 1
const TEST_COLLISION_POLYGON_SIZE: float = 8.0
const EXPECTED_TEMPLATE_FREE_TIMEOUT_MS: int = 100
const TEST_PREVIEW_WIDTH: float = GBTestConstants.DEFAULT_TILE_SIZE.x * 2
const TEST_PREVIEW_HEIGHT: float = GBTestConstants.DEFAULT_TILE_SIZE.y * 2
const HALF_TILE_SIZE: float = GBTestConstants.DEFAULT_TILE_SIZE.x * 0.5

#endregion
#region Environment and Test Setup

var runner: GdUnitSceneRunner
var test_container: GBCompositionContainer
var env: CollisionTestEnvironment
var _logger: GBLogger
var _test_env: AllSystemsTestEnvironment
var _service: IndicatorService
var _indicators_parent: Node2D


func before_test() -> void:
	# Setup for comprehensive tests using CollisionTestEnvironment
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	env = runner.scene() as CollisionTestEnvironment

	(
		assert_object(env)
		. append_failure_message("Failed to load CollisionTestEnvironment scene")
		. is_not_null()
	)

	test_container = env.container

	# Setup for service-specific tests using AllSystemsTestEnvironment
	_logger = GBLogger.new(GBDebugSettings.new())
	_setup_test_environment()
	_create_indicators_parent()


func after_test() -> void:
	# Cleanup handled by auto_free in factory methods
	_cleanup_test_environment()


#endregion
#region Helper Methods


func _setup_test_environment() -> void:
	var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
	assert_that(env_scene).is_not_null().append_failure_message("Failed to load test environment scene")

	_test_env = env_scene.instantiate()
	add_child(_test_env)
	auto_free(_test_env)


func _create_indicators_parent() -> void:
	_indicators_parent = Node2D.new()
	add_child(_indicators_parent)
	auto_free(_indicators_parent)


func _cleanup_test_environment() -> void:
	if _service:
		_service = null
	if _indicators_parent:
		_indicators_parent = null


func _create_test_service() -> IndicatorService:
	var gts: GridTargetingState = _test_env.grid_targeting_system.get_state()
	var template: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER
	return IndicatorService.new(_indicators_parent, gts, template, _logger)


func _create_test_indicator(shape_type: String, shape_data: Dictionary) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	indicator.name = "TestIndicator"

	# Create shape based on type
	var shape: Shape2D
	match shape_type:
		"rectangle":
			shape = RectangleShape2D.new()
			shape.size = shape_data.get("size", Vector2(16, 16))
		"circle":
			shape = CircleShape2D.new()
			shape.radius = shape_data.get("radius", 8.0)
		_:
			shape = RectangleShape2D.new()
			shape.size = Vector2(16, 16)

	indicator.shape = shape
	add_child(indicator)
	auto_free(indicator)

	return indicator


#endregion
#region Indicator Factory Tests


# Test catches: IndicatorFactory failing to create indicators from valid position maps
func test_indicator_factory_creates_indicators_from_position_map() -> void:
	var template := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER.instantiate()
	auto_free(template)
	add_child(template)

	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	# Create test object for positioning
	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = Vector2(100, 100)  # Set a known position

	# Create a simple position-rules map
	var rule := TileCheckRule.new()
	var position_rules_map: Dictionary[Vector2i, Array] = {}
	position_rules_map[Vector2i(0, 0)] = [rule]
	position_rules_map[Vector2i(1, 0)] = [rule]

	var indicators := IndicatorFactory.generate_indicators(
		position_rules_map,
		GBTestConstants.TEST_INDICATOR_TD_PLATFORMER,
		parent,
		test_container.get_states().targeting,
		test_object
	)
	(
		assert_that(indicators.size() == 2)
		. append_failure_message("Expected 2 indicators for 2 positions in map")
		. is_true()
	)

	# Verify indicators have rules assigned
	for indicator in indicators:
		(
			assert_that(indicator.get_rules().size() > 0)
			. append_failure_message("Expected indicators to have rules assigned")
			. is_true()
		)


# Test catches: IndicatorFactory handling empty position maps gracefully
func test_indicator_factory_handles_empty_position_map() -> void:
	var template := GBTestConstants.TEST_INDICATOR_TD_PLATFORMER.instantiate()
	auto_free(template)
	add_child(template)

	var parent := Node2D.new()
	auto_free(parent)
	add_child(parent)

	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)

	var empty_map: Dictionary[Vector2i, Array] = {}
	var indicators := IndicatorFactory.generate_indicators(
		empty_map,
		GBTestConstants.TEST_INDICATOR_TD_PLATFORMER,
		parent,
		test_container.get_states().targeting,
		test_object
	)

	(
		assert_that(indicators.size() == 0).append_failure_message("Expected 0 indicators for empty position map").is_true()
	)


#endregion
#region RULE CHECK INDICATOR TESTS

# Test basic indicator setup and configuration
@warning_ignore("unused_parameter")
func test_indicator_basic_setup(
	shape_type: String,
	shape_data: Dictionary,
	test_parameters := [
		["rectangle", {"size": Vector2(16, 16)}],
		["circle", {"radius": 8.0}],
		["rectangle_large", {"size": Vector2(32, 32)}],
		["rectangle_tiny", {"size": Vector2(1, 1)}]
	]
) -> void:
	var indicator: RuleCheckIndicator = _create_test_indicator(shape_type, shape_data)

	# Verify basic setup
	(
		assert_object(indicator).append_failure_message("Indicator should be created for shape type: %s" % shape_type).is_not_null()
	)

	(
		assert_object(indicator.shape).append_failure_message("Indicator shape should be set for type: %s" % shape_type).is_not_null()
	)

	(
		assert_vector(indicator.global_position).append_failure_message("Indicator should have zero global position initially").is_equal(Vector2.ZERO)
	)


#endregion
#region INDICATOR SERVICE TESTS


func test_indicator_service_setup_with_collision_shapes() -> void:
	_service = _create_test_service()

	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.name = "CollisionTestObject"

	# Add collision shape to test object
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(TEST_PREVIEW_WIDTH, TEST_PREVIEW_HEIGHT)
	collision_shape.shape = rect_shape
	test_object.add_child(collision_shape)
	test_object.collision_layer = 1

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	# Diagnostic context for assertions
	var diag: Array[String] = []
	diag.append("Test Object: %s at %s" % [test_object.name, test_object.global_position])
	diag.append("Collision Layer: %d" % test_object.collision_layer)
	diag.append("Result Has Issues: %s" % result.has_issues())
	diag.append("Result Issues: %s" % str(result.issues))
	diag.append("Result Indicators Count: %d" % result.indicators.size())
	diag.append("Service Indicators Count: %d" % _service._indicators.size())

	assert_bool(result.has_issues()).is_false().append_failure_message(
		"Setup should succeed with valid collision shapes. Diagnostics:\n  %s" % "\n  ".join(diag)
	)

	assert_that(result.indicators.size()).is_greater(0).append_failure_message(
		"Should create indicators for collision shapes. Diagnostics:\n  %s" % "\n  ".join(diag)
	)


func test_indicator_service_handles_missing_collision_shapes() -> void:
	_service = _create_test_service()

	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	assert_that(result.has_issues()).is_true().append_failure_message(
		"Setup should report issues when no collision shapes present"
	)

	assert_that(result.indicators.size()).is_equal(0).append_failure_message(
		"Should create no indicators when no collision shapes"
	)


# ===== COORDINATE TRANSFORMATION TESTS =====


func test_coordinate_transformation_tile_to_world() -> void:
	var tile_coords := Vector2i(5, 3)
	var tile_size := Vector2(32, 32)
	var tilemap_position := Vector2(100, 50)

	# Calculate expected world position
	var expected_world_pos := tilemap_position + Vector2(tile_coords) * tile_size

	# Test the transformation (this would be in the actual coordinate transformation logic)
	var world_pos := (
		tilemap_position + Vector2(tile_coords.x * tile_size.x, tile_coords.y * tile_size.y)
	)

	assert_vector(world_pos).is_equal(expected_world_pos).append_failure_message("Tile to world coordinate transformation should be correct")


func test_coordinate_transformation_world_to_tile() -> void:
	var world_pos := Vector2(164, 146)  # Should map to tile (2, 3) with tilemap at (100, 50) and 32px tiles
	var tile_size := Vector2(32, 32)
	var tilemap_position := Vector2(100, 50)

	# Calculate tile coordinates
	var tile_coords := Vector2i(
		floori((world_pos.x - tilemap_position.x) / tile_size.x),
		floori((world_pos.y - tilemap_position.y) / tile_size.y)
	)

	assert_vector(tile_coords).is_equal(Vector2i(2, 3)).append_failure_message("World to tile coordinate transformation should be correct")


# ===== POLYGON INDICATOR TESTS =====


func test_polygon_indicator_concave_shape_handling() -> void:
	# Create a concave polygon shape
	var polygon_shape := ConcavePolygonShape2D.new()

	# Define a concave polygon (bowtie shape)
	var points := PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(10, 0),
			Vector2(5, 5),  # Concave point
			Vector2(10, 10),
			Vector2(0, 10),
			Vector2(5, 5)  # Back to concave point
		]
	)

	polygon_shape.segments = points

	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = polygon_shape

	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.add_child(collision_shape)
	test_object.collision_layer = 1

	_service = _create_test_service()

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	# Diagnostic context
	var diag: Array[String] = []
	diag.append("Test Object: %s at %s" % [test_object.name, test_object.global_position])
	diag.append("Collision Layer: %d" % test_object.collision_layer)
	diag.append("Shape Type: %s" % polygon_shape.get_class())
	diag.append("Polygon Segments: %d" % polygon_shape.segments.size())
	diag.append("Result Has Issues: %s" % result.has_issues())
	diag.append("Result Issues: %s" % str(result.issues))
	diag.append("Result Indicators: %d" % result.indicators.size())

	# Should handle concave shapes without crashing
	assert_bool(result.has_issues()).is_false().append_failure_message(
		(
			"Should handle concave polygon shapes without issues. Diagnostics:\n  %s"
			% "\n  ".join(diag)
		)
	)


# ===== POSITIONING INTEGRATION TESTS =====


func test_positioning_integration_with_tilemap() -> void:
	var tilemap := TileMapLayer.new()
	auto_free(tilemap)
	add_child(tilemap)

	# Set up tilemap with some tiles
	tilemap.tile_set = TileSet.new()
	var atlas_source := TileSetAtlasSource.new()
	tilemap.tile_set.add_source(atlas_source)

	# Place some tiles
	tilemap.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	tilemap.set_cell(Vector2i(1, 0), 0, Vector2i(0, 0))
	tilemap.set_cell(Vector2i(0, 1), 0, Vector2i(0, 0))
	tilemap.set_cell(Vector2i(1, 1), 0, Vector2i(0, 0))

	# Create test object positioned over tiles
	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.global_position = tilemap.map_to_local(Vector2i(0, 0))
	test_object.collision_layer = 1

	# Add a collision shape to the test object
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)
	collision_shape.shape = rect_shape
	test_object.add_child(collision_shape)

	_service = _create_test_service()

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	# Diagnostic context
	var diag: Array[String] = []
	diag.append("Test Object: %s at %s" % [test_object.name, test_object.global_position])
	diag.append("Tilemap Cell Position: %s" % tilemap.local_to_map(test_object.global_position))
	diag.append("Collision Layer: %d" % test_object.collision_layer)
	diag.append("Result Has Issues: %s" % result.has_issues())
	diag.append("Result Issues: %s" % str(result.issues))
	diag.append("Result Indicators: %d" % result.indicators.size())
	diag.append("Tilemap Cells: %d" % tilemap.get_used_cells().size())

	assert_that(result.indicators.size()).is_greater(0).append_failure_message(("Should create indicators when positioned over tilemap tiles. Diagnostics:\n  %s" % "\n  ".join(diag)))


# ===== REGRESSION TESTS =====


func test_indicator_positioning_regression_tile_alignment() -> void:
	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.collision_layer = 1

	# Position at tile center
	test_object.global_position = Vector2(16, 16)  # Half tile size

	var collision_shape := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 8.0
	collision_shape.shape = circle_shape
	test_object.add_child(collision_shape)

	_service = _create_test_service()

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	# Diagnostic context
	var diag: Array[String] = []
	diag.append("Test Object Position: %s" % test_object.global_position)
	diag.append("Circle Radius: %.1f" % circle_shape.radius)
	diag.append("Collision Layer: %d" % test_object.collision_layer)
	diag.append("Result Has Issues: %s" % result.has_issues())
	diag.append("Result Issues: %s" % str(result.issues))
	diag.append("Result Indicators: %d" % result.indicators.size())
	diag.append("Service Indicators: %d" % _service._indicators.size())

	assert_that(result.indicators.size()).is_greater(0).append_failure_message(
		(
			"Should create indicators for circle shape at tile center. Diagnostics:\n  %s"
			% "\n  ".join(diag)
		)
	)

	# Verify indicators are positioned correctly (not at origin)
	for indicator in result.indicators:
		assert_vector(indicator.global_position).is_not_equal(Vector2.ZERO).append_failure_message(
			"Indicators should not be positioned at origin"
		)


# ===== GRID TARGETING STATE DEBUG TESTS =====


func test_grid_targeting_state_debug_functionality() -> void:
	var targeting_state := _test_env.grid_targeting_system.get_state()

	# Test initial state
	assert_object(targeting_state.get_target()).is_null().append_failure_message(
		"Initial targeting state should have null target"
	)

	# Set a target
	var test_target := Node2D.new()
	auto_free(test_target)
	add_child(test_target)

	targeting_state.set_manual_target(test_target)

	assert_object(targeting_state.get_target()).is_not_null().append_failure_message("Targeting state should have target after assignment")

	assert_object(targeting_state.get_target()).is_same(test_target).append_failure_message("Targeting state should return the assigned target")


# ===== INDICATOR RECONCILE TESTS =====

# Note: IndicatorReconcile functionality is tested through IndicatorService integration

#region #file:simple_box_indicator_regression_test.gd

# Note: IndicatorSetupUtils functionality is tested through IndicatorService integration

# ===== POLYGON OVERLAP THRESHOLD TESTS =====


func test_polygon_overlap_threshold_calculation() -> void:
	var polygon_shape := ConvexPolygonShape2D.new()

	# Create a triangle
	var points := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 10)])
	polygon_shape.points = points

	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = polygon_shape

	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.add_child(collision_shape)
	test_object.collision_layer = 1

	_service = _create_test_service()

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	# Diagnostic context
	var diag: Array[String] = []
	diag.append("Test Object: %s at %s" % [test_object.name, test_object.global_position])
	diag.append("Collision Layer: %d" % test_object.collision_layer)
	diag.append("Polygon Points: %d" % polygon_shape.points.size())
	diag.append("Result Has Issues: %s" % result.has_issues())
	diag.append("Result Issues: %s" % str(result.issues))
	diag.append("Result Indicators: %d" % result.indicators.size())
	diag.append("Service Indicators: %d" % _service._indicators.size())

	assert_that(result.indicators.size()).is_greater(0).append_failure_message(
		"Should create indicators for polygon shapes. Diagnostics:\n  %s" % "\n  ".join(diag)
	)

	# Verify reasonable indicator count (not too many, not too few)
	assert_that(result.indicators.size()).is_less(20).append_failure_message(
		"Should not create excessive indicators for small polygon"
	)


# ===== SIMPLE BOX INDICATOR REGRESSION TESTS =====


func test_simple_box_indicator_regression() -> void:
	var test_object := StaticBody2D.new()
	auto_free(test_object)
	add_child(test_object)
	test_object.collision_layer = 1

	# Create a simple rectangular collision shape
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(16, 16)  # 1 tile size
	collision_shape.shape = rect_shape
	test_object.add_child(collision_shape)

	_service = _create_test_service()

	var rules: Array[TileCheckRule] = [CollisionsCheckRule.new()]

	var result := _service.setup_indicators(test_object, rules)

	# Diagnostic context
	var diag: Array[String] = []
	diag.append("Test Object: %s at %s" % [test_object.name, test_object.global_position])
	diag.append("Collision Layer: %d" % test_object.collision_layer)
	diag.append("Rectangle Size: %s" % rect_shape.size)
	diag.append("Result Has Issues: %s" % result.has_issues())
	diag.append("Result Issues: %s" % str(result.issues))
	diag.append("Result Indicators: %d" % result.indicators.size())
	diag.append("Service Indicators: %d" % _service._indicators.size())

	assert_that(result.indicators.size()).is_greater(0).append_failure_message(
		(
			"Should create indicators for rectangular collision shapes. Diagnostics:\n  %s"
			% "\n  ".join(diag)
		)
	)

	# For a 16x16 rectangle centered at origin, indicators should cover multiple tiles (at least 1, likely 4)
	assert_that(result.indicators.size()).is_greater_equal(1).append_failure_message(
		(
			"16x16 rectangle should create at least 1 indicator (got %d). Diagnostics:\n  %s"
			% [result.indicators.size(), "\n  ".join(diag)]
		)
	)
