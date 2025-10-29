extends GdUnitTestSuite

## CollisionIndicatorIntegrationTestSuite
## Integration test suite for collision detection and indicator management systems
## Tests the interaction between CollisionMapper, IndicatorManager, and related components
## using the AllSystemsTestEnvironment for comprehensive system validation

# Test constants
const TEST_TIMEOUT_MS: int = 5000
const PERFORMANCE_TEST_ITERATIONS: int = 10
const LARGE_TILEMAP_SIZE: int = 50

# Environment setup
var test_hierarchy: AllSystemsTestEnvironment


func before_test() -> void:
	# Use the premade environment scene with validation
	var all_systems_scene: PackedScene = GBTestConstants.get_environment_scene(
		GBTestConstants.EnvironmentType.ALL_SYSTEMS
	)
	assert_that(all_systems_scene).is_not_null().append_failure_message(
		"All Systems environment scene must be available"
	)

	test_hierarchy = all_systems_scene.instantiate() as AllSystemsTestEnvironment
	assert_that(test_hierarchy).is_not_null().append_failure_message(
		"All Systems environment must instantiate successfully"
	)

	add_child(test_hierarchy)

	# Validate environment setup
	var issues: Array[String] = test_hierarchy.get_issues()
	assert_array(issues).is_empty().append_failure_message(
		"Test environment must be properly configured: " + str(issues)
	)


func after_test() -> void:
	if test_hierarchy != null:
		test_hierarchy.queue_free()
	test_hierarchy = null


#endregion
#region Collision Mapper Tests


func test_collision_mapper_basic_functionality() -> void:
	# Arrange
	var collision_mapper: CollisionMapper = test_hierarchy.indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null().append_failure_message(
		"CollisionMapper must be available from IndicatorManager"
	)

	# Create a collision object using premade scene
	var test_scene: PackedScene = load(GBTestConstants.RECT_15_TILES_PATH)
	assert_that(test_scene).is_not_null().append_failure_message(
		"Test rectangle scene must load successfully"
	)

	var collision_object: Node2D = test_scene.instantiate() as Node2D
	assert_that(collision_object).is_not_null().append_failure_message(
		"Test rectangle object must instantiate successfully"
	)

	test_hierarchy.positioner.add_child(collision_object)
	auto_free(collision_object)

	# Get the properly configured targeting state from the test environment
	var container: GBCompositionContainer = test_hierarchy.get_container()
	var targeting_state: GridTargetingState = container.get_states().targeting
	assert_that(targeting_state).is_not_null().append_failure_message(
		"Targeting state must be available from container"
	)

	# Act
	var setups: Array[CollisionTestSetup2D] = (
		CollisionTestSetup2D.create_test_setups_from_test_node(collision_object, targeting_state)
	)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null

	# Assert
	assert_that(test_setup).is_not_null().append_failure_message(
		"CollisionTestSetup2D must be created successfully"
	)

	var offsets: Dictionary[Vector2i, Array] = (
		collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
	)
	assert_dict(offsets).is_not_empty().append_failure_message(
		"Collision mapping must produce tile offsets"
	)


func test_collision_mapper_multiple_shapes() -> void:
	# Arrange
	var collision_mapper: CollisionMapper = test_hierarchy.indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null().append_failure_message(
		"CollisionMapper must be available from IndicatorManager"
	)

	# Create an object with multiple collision shapes
	var area: Area2D = Area2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = GBTestConstants.DEFAULT_TILE_SIZE.x / 2.0  # 16.0
	var collision_shape1: CollisionShape2D = CollisionShape2D.new()
	collision_shape1.shape = circle_shape
	area.add_child(collision_shape1)

	test_hierarchy.positioner.add_child(area)
	auto_free(area)

	# Add additional collision shapes
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = GBTestConstants.DEFAULT_TILE_SIZE  # Vector2(32, 32)
	var collision_shape2: CollisionShape2D = CollisionShape2D.new()
	collision_shape2.shape = rect_shape
	collision_shape2.position = GBTestConstants.ORIGIN
	area.add_child(collision_shape2)

	# Get the properly configured targeting state from the test environment
	var container: GBCompositionContainer = test_hierarchy.get_container()
	var targeting_state: GridTargetingState = container.get_states().targeting
	assert_that(targeting_state).is_not_null().append_failure_message(
		"Targeting state must be available from container"
	)

	# Act
	var setups: Array[CollisionTestSetup2D] = (
		CollisionTestSetup2D.create_test_setups_from_test_node(area, targeting_state)
	)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null

	# Assert
	assert_that(test_setup).is_not_null().append_failure_message(
		"CollisionTestSetup2D must be created for multi-shape object"
	)

	var offsets: Dictionary[Vector2i, Array] = (
		collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
	)
	assert_dict(offsets).is_not_empty().append_failure_message(
		"Collision mapping must produce tile offsets for multi-shape object"
	)


# ================================
# Indicator Manager Tests
# ================================


func test_indicator_manager_setup_basic() -> void:
	# Arrange
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	assert_that(indicator_manager).is_not_null().append_failure_message(
		"IndicatorManager must be available"
	)

	var manipulation_parent: Node2D = test_hierarchy.manipulation_parent
	assert_that(manipulation_parent).is_not_null().append_failure_message(
		"ManipulationParent must be available"
	)

	# Create simple rules
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]

	# Create area with collision shape
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	var area := Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)

	auto_free(area)

	# Test indicator setup
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()


func test_indicator_manager_cleanup() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager

	# Test cleanup functionality
	indicator_manager.tear_down()

	# Verify indicators are cleaned up
	var indicator_count: int = 0
	for child: Node in test_hierarchy.manipulation_parent.get_children():
		# Direct type checking - RuleCheckIndicator assumed to exist
		if child is RuleCheckIndicator:
			indicator_count += 1

	assert_int(indicator_count).is_equal(0)


# ================================
# Collision Performance Tests (from collision_performance_comprehensive_test.gd)
# ================================


func test_collision_performance_large_tilemap() -> void:
	# Arrange
	var collision_mapper: CollisionMapper = test_hierarchy.indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null().append_failure_message(
		"CollisionMapper must be available"
	)

	# Create a larger collision object
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(
		LARGE_TILEMAP_SIZE * GBTestConstants.DEFAULT_TILE_SIZE.x,
		LARGE_TILEMAP_SIZE * GBTestConstants.DEFAULT_TILE_SIZE.y
	)
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	test_hierarchy.positioner.add_child(area)
	auto_free(area)

	# Get the properly configured targeting state from the test environment
	var container: GBCompositionContainer = test_hierarchy.get_container()
	var targeting_state: GridTargetingState = container.get_states().targeting
	assert_that(targeting_state).is_not_null().append_failure_message(
		"Targeting state must be available from container"
	)

	# Act
	var setups: Array[CollisionTestSetup2D] = (
		CollisionTestSetup2D.create_test_setups_from_test_node(area, targeting_state)
	)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null
	assert_that(test_setup).is_not_null().append_failure_message(
		"CollisionTestSetup2D must be created for large tilemap test"
	)

	# Measure performance
	var start_time: int = Time.get_ticks_msec()
	var offsets: Dictionary[Vector2i, Array] = (
		collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
	)
	var end_time: int = Time.get_ticks_msec()

	# Assert
	var processing_time: int = end_time - start_time
	(
		assert_int(processing_time) \
		. is_less_equal(int(GBTestConstants.TEST_TIMEOUT_MS / 10.0)) \
		. append_failure_message(
			"Large tilemap collision processing should complete within reasonable time"
		)
	)
	assert_dict(offsets).is_not_empty().append_failure_message(
		"Collision mapping must produce offsets for large tilemap"
	)


func test_collision_performance_multiple_objects() -> void:
	# Arrange
	var collision_mapper: CollisionMapper = test_hierarchy.indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null().append_failure_message(
		"CollisionMapper must be available"
	)

	# Get the properly configured targeting state from the test environment
	var container: GBCompositionContainer = test_hierarchy.get_container()
	var targeting_state: GridTargetingState = container.get_states().targeting
	assert_that(targeting_state).is_not_null().append_failure_message(
		"Targeting state must be available from container"
	)

	# Create multiple collision objects
	var areas: Array[Node2D] = []
	var test_setups: Array[CollisionTestSetup2D] = []
	for i in range(PERFORMANCE_TEST_ITERATIONS):
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = GBTestConstants.DEFAULT_TILE_SIZE
		var area: Area2D = Area2D.new()
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		collision_shape.shape = rect_shape
		area.position = GBTestConstants.ORIGIN
		area.add_child(collision_shape)
		test_hierarchy.positioner.add_child(area)
		areas.append(area)
		auto_free(area)

		# Create proper test setup for each collision object using the configured targeting state
		var setups: Array[CollisionTestSetup2D] = (
			CollisionTestSetup2D.create_test_setups_from_test_node(area, targeting_state)
		)
		var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null
		test_setups.append(test_setup)

	# Act - Test processing all objects
	var start_time: int = Time.get_ticks_msec()
	var all_offsets: Dictionary[Node2D, Dictionary] = {}
	for i in range(test_setups.size()):
		var test_setup: CollisionTestSetup2D = test_setups[i]
		if test_setup != null:
			var offsets: Dictionary[Vector2i, Array] = (
				collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
			)
			all_offsets[areas[i]] = offsets
	var end_time: int = Time.get_ticks_msec()

	# Assert
	var processing_time: int = end_time - start_time
	(
		assert_int(processing_time) \
		. is_less_equal(int(GBTestConstants.TEST_TIMEOUT_MS / 5.0)) \
		. append_failure_message(
			"Multiple object collision processing should complete within reasonable time"
		)
	)
	assert_int(all_offsets.size()).is_equal(PERFORMANCE_TEST_ITERATIONS).append_failure_message(
		"All collision objects must produce offset results"
	)


# ================================
# Positioning Tests (from indicator_positioning_comprehensive_test.gd)
# ================================


func test_indicator_positioning_basic() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	var manipulation_parent: Node2D = test_hierarchy.manipulation_parent

	# Position the positioner at a specific location
	positioner.position = Vector2(0, 0)

	# Create object and rules
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	manipulation_parent.add_child(area)
	auto_free(area)

	var rules: Array[TileCheckRule] = [TileCheckRule.new()]

	# Setup indicators
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)
	assert_that(report).is_not_null()

	# Verify indicators are positioned relative to positioner
	for child: Node in manipulation_parent.get_children():
		if child is RuleCheckIndicator:  # Direct type check
			# Should be positioned relative to the positioner
			assert_that(child.global_position).is_not_equal(Vector2.ZERO)


func test_indicator_positioning_grid_alignment() -> void:
	var indicator_manager: IndicatorManager = test_hierarchy.indicator_manager
	var positioner: Node2D = test_hierarchy.positioner
	var tile_map: TileMapLayer = test_hierarchy.tile_map_layer

	# Position positioner at grid-aligned location
	var tile_size: Vector2 = tile_map.tile_set.tile_size
	positioner.position = Vector2(0, 0)  # Aligned to grid

	# Create simple test object
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(tile_size.x, tile_size.y)
	var area: Area2D = Area2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rect_shape
	area.add_child(collision_shape)
	test_hierarchy.manipulation_parent.add_child(area)
	auto_free(area)

	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var report: IndicatorSetupReport = indicator_manager.setup_indicators(area, rules)

	assert_that(report).is_not_null()
	# Verify grid alignment - indicators should snap to tile boundaries
	for child: Node in test_hierarchy.manipulation_parent.get_children():
		if child is RuleCheckIndicator:  # Direct type check
			var pos: Vector2 = child.global_position
			var x_aligned: bool = (
				fmod(pos.x, tile_size.x) < 1.0 or fmod(pos.x, tile_size.x) > tile_size.x - 1.0
			)
			var y_aligned: bool = (
				fmod(pos.y, tile_size.y) < 1.0 or fmod(pos.y, tile_size.y) > tile_size.y - 1.0
			)
			assert_bool(x_aligned or y_aligned).is_true()  # At least one axis should be aligned


func test_systems_integration_environment_validation() -> void:
	"""Test that AllSystemsTestEnvironment provides properly integrated systems"""
	# The test_hierarchy is already set up in before_test() using the premade environment

	# Validate that all essential components are available and properly typed
	assert_that(test_hierarchy).is_not_null()
	assert_that(test_hierarchy.indicator_manager).is_not_null()
	assert_that(test_hierarchy.indicator_manager is IndicatorManager).is_true()

	# Validate collision mapper is accessible through indicator manager
	var collision_mapper: CollisionMapper = test_hierarchy.indicator_manager.get_collision_mapper()
	assert_that(collision_mapper).is_not_null()
	assert_that(collision_mapper is CollisionMapper).is_true()

	# Validate tile map layer is available and properly configured
	assert_that(test_hierarchy.tile_map_layer).is_not_null()
	assert_that(test_hierarchy.tile_map_layer is TileMapLayer).is_true()
	assert_that(test_hierarchy.tile_map_layer.tile_set).is_not_null()

	# Validate positioner is available
	assert_that(test_hierarchy.positioner).is_not_null()
	assert_that(test_hierarchy.positioner is Node2D).is_true()

	# Validate manipulation parent is available
	assert_that(test_hierarchy.manipulation_parent).is_not_null()
	assert_that(test_hierarchy.manipulation_parent is Node2D).is_true()

	# Test integration: collision mapper should work with the environment
	var test_scene: PackedScene = load(GBTestConstants.RECT_15_TILES_PATH)
	var test_static_body: Node2D = test_scene.instantiate()
	test_hierarchy.positioner.add_child(test_static_body)
	auto_free(test_static_body)

	# Create test setup using the environment's components
	var targeting_state: GridTargetingState = test_hierarchy.get_container().get_states().targeting
	var setups: Array[CollisionTestSetup2D] = (
		CollisionTestSetup2D.create_test_setups_from_test_node(test_static_body, targeting_state)
	)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null

	# Test that collision mapping works with the integrated environment
	var offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
	assert_dict(offsets).is_not_empty()

	# Test indicator manager integration
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var report: IndicatorSetupReport = test_hierarchy.indicator_manager.setup_indicators(
		test_static_body, rules
	)
	assert_that(report).is_not_null()
	assert_that(report is IndicatorSetupReport).is_true()


func test_systems_environment_consolidation_validation() -> void:
	"""Test that AllSystemsTestEnvironment consolidates multiple system access points"""
	# The test_hierarchy provides consolidated access to all systems

	# Validate that all major systems are accessible through single environment
	assert_that(test_hierarchy.indicator_manager).is_not_null()
	assert_that(test_hierarchy.indicator_manager.get_collision_mapper()).is_not_null()
	assert_that(test_hierarchy.tile_map_layer).is_not_null()
	assert_that(test_hierarchy.positioner).is_not_null()
	assert_that(test_hierarchy.manipulation_parent).is_not_null()

	# Test that systems work together without requiring separate factory calls
	# This validates the consolidation benefit of AllSystemsTestEnvironment

	# Create test object using premade scene
	var test_scene: PackedScene = load(GBTestConstants.RECT_15_TILES_PATH)
	var test_static_body: Node2D = test_scene.instantiate()
	test_hierarchy.positioner.add_child(test_static_body)
	auto_free(test_static_body)

	# Test collision mapping (would require collision_mapper factory)
	var targeting_state: GridTargetingState = test_hierarchy.get_container().get_states().targeting
	var setups: Array[CollisionTestSetup2D] = (
		CollisionTestSetup2D.create_test_setups_from_test_node(test_static_body, targeting_state)
	)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null

	var collision_result: Dictionary = (
		test_hierarchy
		. indicator_manager
		. get_collision_mapper() \
		. get_tile_offsets_for_test_collisions(test_setup)
	)
	assert_dict(collision_result).is_not_empty()

	# Test indicator setup (would require indicator_manager factory)
	var rules: Array[TileCheckRule] = [TileCheckRule.new()]
	var indicator_result: IndicatorSetupReport = test_hierarchy.indicator_manager.setup_indicators(
		test_static_body, rules
	)
	assert_that(indicator_result).is_not_null()

	# Test tile map access (would require tile_map factory)
	assert_that(test_hierarchy.tile_map_layer.tile_set).is_not_null()
	var tile_size: Vector2i = test_hierarchy.tile_map_layer.tile_set.tile_size
	assert_that(tile_size.x).is_greater(0)
	assert_that(tile_size.y).is_greater(0)

	# Document the consolidation benefit
	push_warning(
		"CONSOLIDATION BENEFIT: AllSystemsTestEnvironment provides single access point for all systems"
	)
	push_warning(
		"ELIMINATES NEED: Separate factory calls for collision_mapper, indicator_manager, tile_map, positioner"
	)
	push_warning("IMPROVES: Test setup consistency and reduces boilerplate code")
