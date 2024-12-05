# GdUnit generated TestSuite
class_name GridTargetingSystemTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/grid_targeting_system/grid_targeting_system.gd'

var library : TestSceneLibrary
var system : GridTargetingSystem
var state : GridTargetingState
var settings : GridTargetingSettings
var positioner : Node2D
var placer : Node2D
var placed_parent : Node2D
var tile_map : TileMap

func before():
	library = auto_free(TestSceneLibrary.instance_library())

func before_test():
	state = GridTargetingState.new()
	
	positioner = auto_free(Node2D.new())
	add_child(positioner)
	
	placer = auto_free(Node2D.new())
	add_child(placer)
	
	placed_parent = auto_free(Node2D.new())
	add_child(placed_parent)
	
	tile_map = auto_free(library.tile_map_buildable.instantiate())
	add_child(tile_map)
	
	state.target_map = tile_map
	state.maps = [tile_map]
	state.positioner = positioner
	var origin_state = UserState.new()
	state.origin_state = origin_state
	origin_state.user = placer
	assert_bool(state.validator.validate()).append_failure_message("State passes validation check.").is_true()
	
	settings = library.grid_targeting_settings.duplicate(true)
	assert_bool(settings.validator.validate()).append_failure_message("Settings passes validation check.").is_true()
	system = auto_free(GridTargetingSystem.new())
	system.state = state
	system.settings = settings
	system.mode_state = ModeState.new()
	# clear_signal_watcher()

func test_has_valid_setup():
	assert_object(system.state).append_failure_message("Building state must be set.").is_not_null()
	assert_bool(system.state.validate_setup()).is_true()
	assert_object(system.astar_grid).append_failure_message("Astar grid was not generated").is_not_null()
	assert_vector(system.astar_grid.region.size).is_equal(Vector2i(50,50))
	assert_int(settings.max_tile_distance).append_failure_message("Tests by default expect this to be 3").is_equal(3)

# Test the System's astar grid to see that certain locations are in or out of bounds
func test_is_in_bounds(p_tile_location : Vector2i, p_expected : bool, test_parameters = [
	[Vector2i(49,49), true],
	[Vector2i(50,50), false],
	[Vector2i(30,30), true],
	[Vector2i(21,21), true],
	[Vector2i(20,20), true],
	[Vector2i(0,0), true],
	[Vector2i(-20,-20), false],
	[Vector2i(-20, 20), false],
	[Vector2i(20, -20), false]

]) -> void:
	var is_in_bounds = system.astar_grid.is_in_bounds(p_tile_location.x, p_tile_location.y)
	assert_bool(is_in_bounds).is_equal(p_expected)

func test_get_max_tile_distance_tile_to_target(p_tile_location : Vector2i, p_expected_in_bounds : bool, p_expected_tile_distance : Variant, test_parameters = [
	[Vector2i(50,50), false, null],
	[Vector2i(20,20), true, Vector2(settings.max_tile_distance, settings.max_tile_distance)]
]) -> void:
	system.mode_state.mode = GBEnums.Mode.BUILD
	assert_that(system.mode_state.mode).append_failure_message("Should be in build mode.").is_equal(GBEnums.Mode.BUILD)
	
	var is_in_bounds = system.astar_grid.is_in_bounds(p_tile_location.x, p_tile_location.y)
	assert_bool(is_in_bounds).is_equal(p_expected_in_bounds)
	
	system.update_astar_grid_2d(system.astar_grid, system.settings)
	positioner.global_position = Vector2.ZERO ## RESET POSITION
	
	var tile_distance = system.get_max_tile_distance_tile_to_target(positioner, p_tile_location)
	assert_that(tile_distance).is_equal(p_expected_tile_distance)

## Test get max tile distance when AStar grid is set to no diaganols and manhattan search pattern
func test_get_max_tile_distance_tile_to_target_no_diaganols(p_test_location : Vector2i, p_expected_tile : Variant, test_parameters = [
	[Vector2i(-1,0), Vector2.ZERO],
	[Vector2i(0,-1), Vector2.ZERO],
	[Vector2i(4, 4), Vector2(3,0)],
	[Vector2i(1, 4), Vector2(1,2)],
	[Vector2i(0, 4), Vector2(0,3)]
]):
	set_NO_diaganol_manhattan_astar_search_pattern()
	positioner.global_position = Vector2.ZERO

	var no_diag_limited_tile = system.get_max_tile_distance_tile_to_target(positioner, p_test_location)
	assert_that(no_diag_limited_tile).is_equal(p_expected_tile)

func test_move_node_to_closest_valid_tile(p_target : Vector2i, p_expected_error : int, test_parameters = [
	[Vector2i(-200,-200), OK]
]):
	settings.limit_to_adjacent = false
	assert_object(state.target_map).append_failure_message("Tile map set to valid value").is_not_null()
	var off_map_result = system.move_node_to_closest_valid_tile(p_target, positioner, placer)
	assert_that(off_map_result).append_failure_message("Did not run successfully").is_equal(p_expected_error)

func test_snap_tile_to_region(p_snap_tile : Vector2i, p_expected_tile : Vector2i, test_parameters = [
	[Vector2i(26,26), Vector2i(25,25)],
	[Vector2i(-26,-26), Vector2i(-25, -25)]
]):
	var grid : AStarGrid2D = create_astar_grid_centered_on_0_size_50()
	var test_tile_bottom_right = Vector2i(26,26)
	var result = system.snap_tile_to_region(p_snap_tile, grid.region)
	assert_vector(result).is_equal(p_expected_tile)

func set_NO_diaganol_manhattan_astar_search_pattern():
	settings.diaganol_mode = AStarGrid2D.DiagonalMode.DIAGONAL_MODE_NEVER
	settings.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	settings.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	assert_that(system.astar_grid.diagonal_mode).append_failure_message("AStar Diaganol mode set properly.").is_equal(settings.diaganol_mode)
	assert_that(system.astar_grid.default_estimate_heuristic).append_failure_message("4 direction calculation expected.").is_equal(AStarGrid2D.HEURISTIC_MANHATTAN)
	assert_that(system.astar_grid.default_compute_heuristic).append_failure_message("4 direction calculation expected.").is_equal(AStarGrid2D.HEURISTIC_MANHATTAN)

func create_astar_grid_centered_on_0_size_50():
	var grid = auto_free(AStarGrid2D.new())
	grid.region = Rect2(-25,-25,50,50)
	
	var position = grid.region.position
	var end = grid.region.end
	assert_vector(position).append_failure_message("Start should have been half size negative").is_equal(Vector2i(-25,-25))
	assert_vector(end).append_failure_message("End is half size").is_equal(Vector2i(25,25))
	return grid
