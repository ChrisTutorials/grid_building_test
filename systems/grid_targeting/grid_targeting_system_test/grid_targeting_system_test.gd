# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from

var system: GridTargetingSystem
var state: GridTargetingState
var settings: GridTargetingSettings
var positioner: Node2D
var placer: Node2D
var placed_parent: Node2D
var map_layer: TileMapLayer
var vec_max_tile_distance: Vector2
var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")


func before_test():
	state = _container.get_states().targeting

	positioner = GodotTestFactory.create_node2d(self)
	placed_parent = GodotTestFactory.create_node2d(self)
	map_layer = auto_free(GodotTestFactory.create_empty_tile_map_layer(self))

	state.target_map = map_layer
	state.maps = [map_layer]
	state.positioner = positioner

	var owner_context = UnifiedTestFactory.create_owner_context(self)
	assert_array(state.validate()).append_failure_message("Issues in setup found").is_empty()

	settings = TestSceneLibrary.grid_targeting_settings.duplicate(true)

	assert_array(settings.validate()).is_empty()
	system = auto_free(GridTargetingSystem.new())
	add_child(system)  # Add to scene tree BEFORE injection
	system.resolve_gb_dependencies(_container)

	vec_max_tile_distance = Vector2(settings.max_tile_distance, settings.max_tile_distance)


func test_has_valid_setup():
	assert_object(system.get_state()).is_not_null()
	assert_array(system.get_state().validate()).is_empty()
	assert_object(system.astar_grid).is_not_null()
	assert_vector(system.astar_grid.region.size).is_equal(Vector2i(50, 50))
	assert_int(settings.max_tile_distance).is_equal(3)


# Test the System's astar grid to see that certain locations are in or out of bounds
@warning_ignore("unused_parameter")
func test_is_in_bounds(
	p_tile_location: Vector2i,
	p_expected: bool,
	test_parameters := [
		[Vector2i(49, 49), true],
		[Vector2i(50, 50), false],
		[Vector2i(30, 30), true],
		[Vector2i(21, 21), true],
		[Vector2i(20, 20), true],
		[Vector2i(0, 0), true],
		[Vector2i(-20, -20), false],
		[Vector2i(-20, 20), false],
		[Vector2i(20, -20), false]
	]
) -> void:
	var is_in_bounds = system.astar_grid.is_in_bounds(p_tile_location.x, p_tile_location.y)
	assert_bool(is_in_bounds).is_equal(p_expected)


@warning_ignore("unused_parameter")
func test_get_max_tile_distance_tile_to_target(
	p_tile_location: Vector2i,
	p_expected_in_bounds: bool,
	p_expected_tile_distance: Variant,
	test_parameters := [
		[Vector2i(50, 50), false, null], [Vector2i(20, 20), true, vec_max_tile_distance]
	]
) -> void:
	# Access mode state through container (standard practice)
	var mode_state = _container.get_states().mode
	mode_state.current = GBEnums.Mode.BUILD
	assert_int(mode_state.current).is_equal(GBEnums.Mode.BUILD)

	var is_in_bounds = system.astar_grid.is_in_bounds(p_tile_location.x, p_tile_location.y)
	assert_bool(is_in_bounds).is_equal(p_expected_in_bounds)

	system.update_astar_grid_2d(system.astar_grid, settings)
	positioner.global_position = Vector2.ZERO  ## RESET POSITION

	var tile_distance = system.get_max_tile_distance_tile_to_target(positioner, p_tile_location)
	assert_vector(tile_distance).is_equal(p_expected_tile_distance)


## Test get max tile distance when AStar grid is set to no diaganols and manhattan search pattern
@warning_ignore("unused_parameter")
func test_get_max_tile_distance_tile_to_target_no_diaganols(
	p_test_location: Vector2i,
	p_expected_tile: Variant,
	test_parameters := [
		[Vector2i(-1, 0), Vector2.ZERO],
		[Vector2i(0, -1), Vector2.ZERO],
		[Vector2i(4, 4), Vector2(3, 0)],
		[Vector2i(1, 4), Vector2(1, 2)],
		[Vector2i(0, 4), Vector2(0, 3)]
	]
):
	set_no_diagonal_manhattan_astar_search_pattern()
	positioner.global_position = Vector2.ZERO

	var no_diag_limited_tile = system.get_max_tile_distance_tile_to_target(
		positioner, p_test_location
	)
	assert_vector(no_diag_limited_tile).is_equal(p_expected_tile)


@warning_ignore("unused_parameter")
func test_move_node_to_closest_valid_tile(
	p_target: Vector2i, p_expected_error: int, test_parameters := [[Vector2i(-200, -200), OK]]
):
	settings.limit_to_adjacent = false
	assert_object(state.target_map).is_not_null()
	var off_map_result = system.move_node_to_closest_valid_tile(p_target, positioner, placer)
	assert_int(off_map_result).is_equal(p_expected_error)


@warning_ignore("unused_parameter")
func test_snap_tile_to_region(
	p_snap_tile: Vector2i,
	p_expected_tile: Vector2i,
	test_parameters := [
		[Vector2i(26, 26), Vector2i(25, 25)], [Vector2i(-26, -26), Vector2i(-25, -25)]
	]
):
	var grid: AStarGrid2D = create_astar_grid_centered_on_0_size_50()
	var result = system.snap_tile_to_region(p_snap_tile, grid.region)
	assert_vector(result).is_equal(p_expected_tile)


func set_no_diagonal_manhattan_astar_search_pattern():
	settings.diaganol_mode = AStarGrid2D.DiagonalMode.DIAGONAL_MODE_NEVER
	settings.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	settings.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

	# Update the AStar grid with the new settings
	system.update_astar_grid_2d(system.astar_grid, settings)

	assert_int(system.astar_grid.diagonal_mode).is_equal(settings.diaganol_mode)
	assert_int(system.astar_grid.default_estimate_heuristic).is_equal(AStarGrid2D.HEURISTIC_MANHATTAN)
	assert_int(system.astar_grid.default_compute_heuristic).is_equal(AStarGrid2D.HEURISTIC_MANHATTAN)


func create_astar_grid_centered_on_0_size_50():
	var grid = auto_free(AStarGrid2D.new())
	grid.region = Rect2(-25, -25, 50, 50)

	var position = grid.region.position
	var end = grid.region.end
	assert_vector(position).is_equal(Vector2i(-25, -25))
	assert_vector(end).is_equal(Vector2i(25, 25))
	return grid
