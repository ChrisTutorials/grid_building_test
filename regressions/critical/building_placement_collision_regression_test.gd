## Regression test for building placement collision detection failure
##
## PROBLEM (2025-09-30): Building placement tests failing with false collision reports
## - test_building_placement_attempt: "Colliding on 1 tile(s)" when no collision should occur
## - test_single_placement_per_tile_constraint: Same collision false positive
## - test_complete_building_workflow: Same collision false positive
##
## ROOT CAUSE: Collision rules were incorrectly reporting collisions in empty areas
## This happens when:
## 1. Collision shapes are not properly configured on test objects
## 2. Collision layers/masks are misaligned between test setup and rule validation
## 3. Target positioning places collision shapes in unintended collision states
##
## This regression test validates that basic placement attempts in clear areas
## do NOT trigger false collision reports, ensuring the core building workflow
## remains functional.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var env: AllSystemsTestEnvironment
var building_system: BuildingSystem
var targeting_state: GridTargetingState
var positioner: GridPositioner2D
var map: TileMapLayer
var user_node: Node2D
var container: GBCompositionContainer
var logger: GBLogger


func before_test() -> void:
	# Use scene_runner for reliable frame simulation
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV.resource_path)
	runner.simulate_frames(2)  # Initial setup frames

	env = runner.scene() as AllSystemsTestEnvironment
	assert_that(env).is_not_null().append_failure_message(
		"All Systems environment must instantiate successfully"
	)

	# Validate environment setup
	var issues: Array[String] = env.get_issues()
	assert_array(issues).is_empty().append_failure_message(
		"Environment setup has issues: %s" % str(issues)
	)

	building_system = env.building_system
	targeting_state = env.grid_targeting_system.get_state()
	positioner = targeting_state.positioner
	map = targeting_state.target_map
	container = env.get_container()
	logger = container.get_logger()

	# Create test collision target
	user_node = auto_free(Node2D.new())
	env.add_child(user_node)  # Add to env, not test suite


func after_test() -> void:
	if building_system and building_system.is_in_build_mode():
		building_system.exit_build_mode()
	runner = null


func test_smithy_placement_in_clear_area_should_not_report_collision() -> void:
	# REGRESSION: Building placement was reporting "Colliding on 1 tile(s)" in clear areas

	# Setup: Position in a clear area within map bounds
	# Use tile (10, 10) which provides ample space for 7x5 smithy on 31x31 map
	var clear_tile: Vector2i = Vector2i(10, 10)
	_position_target_at_tile(clear_tile)

	# Note: Not adding collision shapes to target - preview will create its own collision objects
	# This avoids the issue where old target collision bodies interfere with new preview collision detection

	runner.simulate_frames(2)  # Let position settle and physics update

	# Act: Enter build mode with smithy (standard test placeable)
	var enter_report: PlacementReport = building_system.enter_build_mode(
		GBTestConstants.PLACEABLE_SMITHY
	)

	# Assert: Should enter build mode successfully
	(
		assert_bool(enter_report.is_successful()) \
		. append_failure_message(
			"Enter build mode failed - issues: %s" % str(enter_report.get_issues())
		) \
		. is_true()
	)

	# Act: Attempt to build at the clear position
	var placement_report: PlacementReport = building_system.try_build()

	# Assert: CRITICAL - Should NOT report any collisions in clear area
	(
		assert_object(placement_report) \
		. append_failure_message("try_build() returned null - indicates system failure") \
		. is_not_null()
	)

	var issues: Array[String] = placement_report.get_issues()
	var has_collision_issue: bool = false
	for issue in issues:
		if "Colliding on" in issue:
			has_collision_issue = true
			break

	(
		assert_bool(has_collision_issue) \
		. append_failure_message(
			(
				"REGRESSION: False collision detected in clear area - issues: %s. This breaks basic building functionality."
				% str(issues)
			)
		) \
		. is_false()
	)

	# Assert: Placement should succeed
	(
		assert_bool(placement_report.is_successful()) \
		. append_failure_message(
			"Placement should succeed in clear area - issues: %s" % str(issues)
		) \
		. is_true()
	)


func test_collision_rule_configuration_validity() -> void:
	# REGRESSION: Validate that collision rules are properly configured

	# Setup target in clear area (use tile 10,10 with ample space for 7x5 smithy)
	var clear_tile: Vector2i = Vector2i(10, 10)
	_position_target_at_tile(clear_tile)
	# Note: Not adding collision shapes to avoid interference

	runner.simulate_frames(2)  # Let position settle and physics update

	# Validate that the container is available
	(
		assert_object(container) \
		. append_failure_message("GBCompositionContainer not available in environment") \
		. is_not_null()
	)

	# Enter build mode to trigger rule setup
	var enter_report: PlacementReport = building_system.enter_build_mode(
		GBTestConstants.PLACEABLE_SMITHY
	)
	assert_bool(enter_report.is_successful()).is_true()

	# Validate that collision detection is working as expected in clear area
	var collision_mapper: CollisionMapper = env.indicator_manager.get_collision_mapper()
	(
		assert_object(collision_mapper) \
		. append_failure_message("CollisionMapper not available for validation") \
		. is_not_null()
	)

	# Check if collision detection is working as expected in clear area
	var test_nodes: Array[Node2D] = [user_node as Node2D]
	var collision_results: Dictionary[Vector2i, Array] = collision_mapper.get_collision_tile_positions_with_mask(
		test_nodes, 1
	)

	# In a clear area, collision detection should find no blocking objects
	var blocking_tiles: int = collision_results.size()
	(
		assert_int(blocking_tiles) \
		. append_failure_message(
			(
				"REGRESSION: Collision detection finding blocking objects in clear area - found %d blocking tiles"
				% blocking_tiles
			)
		) \
		. is_equal(0)
	)


#region HELPER METHODS


func _position_target_at_tile(tile_coords: Vector2i) -> void:
	## Position the target node at the center of the specified tile
	var world_position: Vector2 = map.map_to_local(tile_coords)
	positioner.global_position = world_position
	user_node.global_position = world_position
	targeting_state.set_manual_target(user_node)

	logger.log_debug(
		"Positioned target at tile %s (world: %s)" % [str(tile_coords), str(world_position)]
	)


func _setup_minimal_collision_shape_on_target() -> void:
	## Add minimal collision shape to target for indicator generation
	## Without this, rules that depend on indicators will fail with "no indicators"
	var static_body: StaticBody2D = StaticBody2D.new()
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(16, 16)  # Single tile size
	collision_shape.shape = shape
	static_body.collision_layer = 1
	static_body.collision_mask = 1

	static_body.add_child(collision_shape)
	user_node.add_child(static_body)

	logger.log_debug("Added minimal collision shape to target for indicator generation")

#endregion
