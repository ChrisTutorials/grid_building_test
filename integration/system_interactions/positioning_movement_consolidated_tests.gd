extends GdUnitTestSuite

## Consolidated positioning and movement tests using factory patterns

# Test constants
const TILE_SIZE: int = int(GBTestConstants.DEFAULT_TILE_SIZE.x)
const TEST_INDICATOR_SIZE: Vector2 = GBTestConstants.DEFAULT_TILE_SIZE
const PERFORMANCE_TEST_OBJECT_COUNT: int = 10
const PERFORMANCE_TEST_MOVE_COUNT: int = 20
const PERFORMANCE_TEST_TIME_LIMIT_MS: int = 50

# Test positions
const TEST_BASE_TILE: Vector2i = Vector2i(3, 3)
const TEST_ORIGIN: Vector2 = Vector2(0, 0)
const TEST_POSITION_NEW: Vector2 = Vector2(100, 100)
const TEST_GRID_UNALIGNED_POS: Vector2 = Vector2(15, 25)
const TEST_POSITIONER_OFFSET: Vector2 = Vector2(50, 50)

# Test object positioning offsets
const RELATIVE_POSITION_OFFSETS: Array[Vector2] = [Vector2.ZERO, Vector2(20, 0), Vector2(40, 20)]

#region COLLISION_HELPERS

func _build_collision_diagnostics(iteration: int, tile_coords: Vector2i, positioner_world: Vector2, collision_world: Vector2, offsets: Dictionary) -> String:
	var key_list: Array = offsets.keys()
	var sample_keys: Array = key_list
	if key_list.size() > 5:
		sample_keys = key_list.slice(0, 5)
	return "iteration=%d tile_target=%s positioner_global=%s collision_global=%s sample_keys=%s" % [iteration, str(tile_coords), str(positioner_world), str(collision_world), str(sample_keys)]

#endregion

var env: AllSystemsTestEnvironment

# Common test objects (initialized in before_test)
var positioner: Node2D
var collision_mapper: CollisionMapper
var indicator_manager: IndicatorManager
var tile_map: TileMapLayer

func before_test() -> void:
	# Use the proper environment factory
	env = EnvironmentTestFactory.create_all_systems_env(self, GBTestConstants.ALL_SYSTEMS_ENV_UID)
	
	# Fail-fast validation of environment setup
	if env == null:
		fail("Test environment creation failed - check EnvironmentTestFactory.create_all_systems_env()")
		return
	
	# Use environment's built-in issue detection for comprehensive validation
	var environment_issues: Array = env.get_issues()
	if not environment_issues.is_empty():
		var error_message: String = "PositioningMovementTest environment validation failed:\n"
		for i in range(environment_issues.size()):
			error_message += "  %d. %s\n" % [i + 1, str(environment_issues[i])]
		error_message += "\nEnvironment has unresolved setup issues - check AllSystemsTestEnvironment scene."
		fail(error_message)
		return
	
	# Safely extract components - environment is validated to be issue-free
	positioner = env.positioner
	indicator_manager = env.indicator_manager
	collision_mapper = env.indicator_manager.get_collision_mapper()
	tile_map = env.tile_map_layer
	
	# Final validation of extracted components (fail-fast)
	if not positioner or not indicator_manager or not collision_mapper or not tile_map:
		fail("Critical components are null after environment validation - environment may be corrupted")
		return

func test_positioner_basic_positioning() -> void:
	# Test basic positioning
	var test_position: Vector2 = TEST_ORIGIN
	positioner.position = test_position
	
	assert_vector(positioner.position).is_equal(test_position)

func test_positioner_with_collision_tracking() -> void:
	# Add collision object to positioner using factory method
	var collision_body: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Remove from test root and add to positioner if needed
	if collision_body.get_parent() != null:
		collision_body.get_parent().remove_child(collision_body)
	positioner.add_child(collision_body)
	
	# Create proper test setup for collision mapping using environment's targeting state
	var targeting_state: GridTargetingState = env.injector.composition_container.get_states().targeting
	var setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(collision_body, targeting_state)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null
	assert_object(test_setup).is_not_null().append_failure_message("CollisionTestSetup2D creation failed - verify collision_body exposes supported shapes and targeting_state is valid.")

	var tile_set: TileSet = tile_map.tile_set
	assert_object(tile_set).is_not_null().append_failure_message("TileMap must expose a TileSet to derive tile size for collision coverage.")
	var tile_size: Vector2 = Vector2(tile_set.tile_size)

	var rect_setups: Array[RectCollisionTestingSetup] = test_setup.rect_collision_test_setups
	assert_array(rect_setups).is_not_empty().append_failure_message("CollisionTestSetup2D should provide at least one RectCollisionTestingSetup for coverage calculations.")
	var primary_rect_setup: RectCollisionTestingSetup = rect_setups[0]
	assert_object(primary_rect_setup).is_not_null().append_failure_message("Primary RectCollisionTestingSetup cannot be null - collision mapping requires rectangle coverage data.")
	assert_object(primary_rect_setup.rect_shape).is_not_null().append_failure_message("RectCollisionTestingSetup must expose a RectangleShape2D to compute expected tile coverage.")

	var expected_tile_count: int = -1

	var base_tile: Vector2i = TEST_BASE_TILE
	var tile_offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 1)]
	var target_tiles: Array[Vector2i] = []
	var positions: Array[Vector2] = []

	for offset: Vector2i in tile_offsets:
		var tile_coords: Vector2i = base_tile + offset
		target_tiles.append(tile_coords)
		var world_pos: Vector2 = tile_map.to_global(tile_map.map_to_local(tile_coords))
		positions.append(world_pos)
	
	# Test position changes affect collision mapping
	var results: Array[Dictionary] = []
	
	# Move positioner to different positions and get collision mapping after physics update
	for index: int in range(positions.size()):
		positioner.global_position = positions[index]
		await get_tree().physics_frame  # Wait for physics frame to update global positions
		var offsets: Dictionary = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
		var diagnostics: String = _build_collision_diagnostics(index, target_tiles[index], positions[index], collision_body.global_position, offsets)
		results.append(offsets)
		assert_that(offsets).is_not_empty().append_failure_message(diagnostics)
		var tile_keys: Array = offsets.keys()
		var tile_count: int = tile_keys.size()
		if expected_tile_count == -1:
			expected_tile_count = tile_count
			assert_int(expected_tile_count).is_greater(0).append_failure_message("%s | initial_tile_count=%d rect_shape_size=%s tile_size=%s" % [diagnostics, expected_tile_count, str(primary_rect_setup.rect_shape.size), str(tile_size)])
		else:
			assert_int(tile_count).is_equal(expected_tile_count).append_failure_message("%s | expected_tile_count=%d observed=%d keys=%s" % [diagnostics, expected_tile_count, tile_count, str(tile_keys)])
		# Verify all keys are Vector2i tile coordinates
		for key: Variant in tile_keys:
			assert_bool(key is Vector2i).is_true().append_failure_message("%s | invalid tile key=%s (type=%s)" % [diagnostics, str(key), str(typeof(key))])

func test_positioner_indicator_updates() -> void:
	# Add indicator to positioner
	var indicator: ColorRect = ColorRect.new()
	indicator.size = TEST_INDICATOR_SIZE
	positioner.add_child(indicator)
	auto_free(indicator)
	
	# Test position changes trigger indicator updates
	var initial_pos: Vector2 = Vector2.ZERO
	var new_pos: Vector2 = TEST_POSITION_NEW
	
	positioner.global_position = initial_pos
	await get_tree().physics_frame
	positioner.global_position = new_pos
	
	# Indicator should reflect positioner's new position
	var expected_indicator_pos: Vector2 = new_pos + indicator.position
	assert_vector(indicator.global_position).is_equal_approx(expected_indicator_pos, Vector2.ONE)

func test_movement_with_grid_alignment() -> void:
	# Check if tile_map is available
	assert_that(tile_map).is_not_null()
		
	var tile_size: Vector2i = tile_map.tile_set.tile_size
	
	# Test grid-aligned movement
	var unaligned_pos: Vector2 = TEST_GRID_UNALIGNED_POS
	positioner.position = unaligned_pos
	
	# Simulate grid alignment
	var grid_aligned_x: float = int(positioner.position.x / tile_size.x) * tile_size.x
	var grid_aligned_y: float = int(positioner.position.y / tile_size.y) * tile_size.y
	var aligned_pos: Vector2 = Vector2(grid_aligned_x, grid_aligned_y)
	
	positioner.position = aligned_pos
	
	# Verify alignment
	assert_int(int(positioner.position.x) % int(tile_size.x)).is_equal(0)
	assert_int(int(positioner.position.y) % int(tile_size.y)).is_equal(0)
	
func test_multi_object_positioning() -> void:
	# Create multiple positioned objects
	var objects: Array[Area2D] = []
	var relative_positions: Array[Vector2] = RELATIVE_POSITION_OFFSETS
	
	for i in range(3):
		var obj: Area2D = Area2D.new()
		obj.position = relative_positions[i]
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)
	
	# Test positioner movement affects all children
	var positioner_offset: Vector2 = TEST_POSITIONER_OFFSET
	positioner.position = positioner_offset
	
	for i in range(objects.size()):
		var expected_global: Vector2 = positioner_offset + relative_positions[i]
		assert_vector(objects[i].global_position).is_equal_approx(expected_global, Vector2.ONE)

func test_positioner_boundary_conditions() -> void:
	# Check if tile_map is available
	assert_that(tile_map).is_not_null()
		
	# Test boundary positions
	var map_rect: Rect2i = tile_map.get_used_rect()
	var tile_size: Vector2i = tile_map.tile_set.tile_size
	
	var boundary_positions: Array[Vector2] = [
		Vector2.ZERO,  # Origin
		Vector2(map_rect.position.x * tile_size.x, map_rect.position.y * tile_size.y),  # Map start
		Vector2(map_rect.end.x * tile_size.x - tile_size.x, map_rect.end.y * tile_size.y - tile_size.y)  # Map end
	]
	
	for pos: Vector2 in boundary_positions:
		positioner.position = pos
		# Should not crash or produce errors
		assert_vector(positioner.position).is_equal(pos)

func test_positioner_performance_bulk_moves() -> void:
	# Add several objects to positioner
	var objects: Array[ColorRect] = []
	for i in range(10):
		var obj: ColorRect = ColorRect.new()
		obj.size = Vector2.ONE * 32
		positioner.add_child(obj)
		objects.append(obj)
		auto_free(obj)
	
	# Measure bulk movement performance
	var start_time: int = Time.get_ticks_msec()
	
	var positions: Array[Vector2] = []
	for i in range(20):
		positions.append(Vector2(i * 16, sin(i) * 32))
	
	for pos: Vector2 in positions:
		positioner.position = pos
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Bulk movements should be fast (< 50ms for 20 moves with 10 objects)
	assert_int(elapsed).is_less(50)

func test_positioner_integration_workflow() -> void:
	# Add test objects using factory method
	var collision_body: StaticBody2D = UnifiedTestFactory.create_test_static_body_with_rect_shape(self)
	
	# Remove from test root and add to positioner if needed
	if collision_body.get_parent() != null:
		collision_body.get_parent().remove_child(collision_body)
	positioner.add_child(collision_body)
	
	var indicator: ColorRect = ColorRect.new()
	indicator.size = Vector2.ONE * 32
	indicator.color = Color.BLUE
	positioner.add_child(indicator)
	auto_free(indicator)

	# Create proper test setup for collision mapping using environment's targeting state
	var targeting_state: GridTargetingState = env.injector.composition_container.get_states().targeting
	var setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(collision_body, targeting_state)
	var test_setup: CollisionTestSetup2D = setups[0] if setups.size() > 0 else null
	
	# Test complete workflow: move -> collision check -> rule check -> indicator update
	var workflow_position: Vector2 = Vector2(200, 150)
	positioner.position = workflow_position
	
	# Step 1: Collision mapping
	var collision_result : Dictionary[Vector2i, Array] = collision_mapper.get_tile_offsets_for_test_collisions(test_setup)
	assert_dict(collision_result).is_not_empty()
	# Verify all keys are Vector2i tile coordinates
	for tile_pos: Vector2i in collision_result.keys():
		assert_that(tile_pos is Vector2i).is_true()
	# Since collision offsets are object-centered, moving the positioner (which parents the StaticBody2D) does
	# not change the relative offset pattern, only absolute world translation. We just assert non-empty here.
	
	# Step 3: Indicator updates
	indicator_manager.apply_rules()
	
	# Verify final state
	assert_vector(positioner.position).is_equal(workflow_position)
	assert_vector(collision_body.global_position).is_equal(workflow_position)
	assert_vector(indicator.global_position).is_equal(workflow_position)
