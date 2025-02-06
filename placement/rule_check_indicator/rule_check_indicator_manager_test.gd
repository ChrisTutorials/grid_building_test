# GdUnit generated TestSuite
class_name RuleCheckIndicatorManagerTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://addons/grid_building/placement/rule_check_indicator/rule_check_indicator_manager.gd'

var library : TestSceneLibrary
var rci_manager : RuleCheckIndicatorManager
var tile_set : TileSet = preload("res://test/grid_building_test/resources/test_tile_set.tres")
var tile_map : TileMap
var placement_validator : PlacementValidator
var base_rules : Array[PlacementRule]
var col_checking_rules : Array[TileCheckRule] = RuleFilters.only_tile_check(base_rules)
var targeting_state : GridTargetingState
var building_settings : BuildingSettings
var user_state : UserState

var placer : Node
var placed_parent : Node2D
var positioner : GridPositioner2D

var global_snap_pos

var test_indicator = preload("res://test/grid_building_test/scenes/indicators/test_indicator.tscn")
const eclipse_scene_path = "res://test/grid_building_test/scenes/test_elipse.tscn"

func before():
	library = auto_free(TestSceneLibrary.instance_library())
	assert_object(library.indicator).is_not_null()
	
	tile_map = auto_free(TileMap.new())
	add_child(tile_map)
	tile_map.tile_set = tile_set
	tile_map.add_layer(0)
	
	# Fill tile_map
	for x in range(-100, 100, 1):
		for y in range (-100, 100, 1):
			var cords = Vector2i(x, y)
			tile_map.set_cell(0, cords, 0, Vector2i(0,0))
			
	placer = auto_free(Node2D.new())
	add_child(placer)
	user_state = UserState.new()
	user_state.user = placer
	
	placed_parent = auto_free(Node2D.new())
	add_child(placed_parent)
	
	base_rules = [CollisionsCheckRule.new()]
	col_checking_rules = RuleFilters.only_tile_check(base_rules)
	placement_validator = PlacementValidator.new()

func before_test():
	targeting_state = GridTargetingState.new()
	targeting_state.target_map = tile_map
	targeting_state.maps = [tile_map]
	
	#region Positioner Node2D Setup
	positioner = auto_free(GridPositioner2D.new())
	positioner.name = "GridPositioner2D"
	positioner.shape = RectangleShape2D.new()
	positioner.shape.size = Vector2(16.0, 16.0)
	positioner.targeting_state = targeting_state
	positioner.targeting_settings = GridTargetingSettings.new()
	add_child(positioner)
	#endregion
	
	targeting_state.positioner = positioner
	targeting_state.origin_state = user_state
	
	building_settings = library.building_settings.duplicate(true)
	
	rci_manager = auto_free(RuleCheckIndicatorManager.new(library.indicator, targeting_state))
	add_child(rci_manager)
	
	# Snap rule indicator to tilemap 0,0
	global_snap_pos = tile_map.map_to_local(Vector2i(0,0))
	
	var validation_rules = RuleValidationParameters.new(
		placer,
		auto_free(Node2D.new()),
		targeting_state
	)
	
	placement_validator.indicator_manager = rci_manager
	var setup_result = placement_validator.setup(base_rules, validation_rules)
	assert_bool(setup_result).append_failure_message("Setup failed to run successfully on placement_validator").is_true()
	assert_object(rci_manager.indicator_template).append_failure_message("Indicator template expected to be set on rci_manager.").is_not_null()
	

## Tests that the number of indicators generated for p_shape_scene matches the p_expected_indicators
@warning_ignore("unused_parameter")
func test_setup_indicators(p_shape_scene_path : String, p_expected_indicators : int, test_parameters = [
	[eclipse_scene_path, 27]
]):
	var shape_scene = auto_free(load(p_shape_scene_path).instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var indicators : Array[RuleCheckIndicator] = rci_manager.setup_indicators(shape_scene, col_checking_rules)
	assert_int(indicators.size()).append_failure_message("Generated indicator count did not match expected count.").is_equal(p_expected_indicators)

## Ensure proper freeing of objects after using get_or_create_testing_indicator
## followed by freeing the rci_manager
func test_get_or_create_testing_indicator_on_free():
	## Setup
	rci_manager.get_or_create_testing_indicator(test_indicator)
	var testing_indicator = rci_manager._testing_indicator
	assert_object(testing_indicator).is_not_null()
	
	## Free Test
	rci_manager.free()
	assert_that(testing_indicator).is_null()

# Check that the distance between indicators 0 and 1 is the expected value
@warning_ignore("unused_parameter")
func test_indicator_generation_distance(p_shape_scene_path : String, p_expected_distance : float, test_parameters = [
	[eclipse_scene_path, 16.0]
]):
	var shape_scene = auto_free(load(p_shape_scene_path).instantiate())
	add_child(shape_scene)
	var indicators : Array[RuleCheckIndicator] = rci_manager.setup_indicators(shape_scene, col_checking_rules)
	var indicator_0 = rci_manager.indicators[0]
	var indicator_1 = rci_manager.indicators[1]
	var distance_to = indicator_0.global_position.distance_to(indicator_1.global_position)
	assert_float(distance_to).append_failure_message("16x16 tile spacing").is_equal(p_expected_distance)
	
func test_rect_15_tile_shape_count():
	#region Setup
	var test_rect_15_tiles = load("res://test/grid_building_test/scenes/test_rect_15_tiles.tscn").instantiate()
	add_child(test_rect_15_tiles)
	test_rect_15_tiles.global_position = global_snap_pos
	#endregion
	
	#region Execution
	var col_objects : Array[CollisionObject2D] = rci_manager._find_collision_objects(test_rect_15_tiles)
	assert_array(col_objects).is_not_empty()
	var expected_collisions = 15
	var tile_positions = rci_manager._get_collision_tile_positions_with_mask(col_objects, 1)
	assert_int(tile_positions.size()).append_failure_message("Expected to have %d positions where tiles collide" % expected_collisions).is_equal(expected_collisions)
	var generated_indicators = rci_manager.setup_indicators(test_rect_15_tiles, col_checking_rules)
	assert_int(generated_indicators.size()).is_equal(15)
	var distance_to = rci_manager.indicators[0].global_position.distance_to(rci_manager.indicators[1].global_position)
	assert_float(distance_to).append_failure_message("16x16 tile spacing").is_equal(16.0)
	#endregion
	
	#region Cleanup
	rci_manager.clear()
	test_rect_15_tiles.free()
	#endregion
	
func test_track_indicators():
	assert_int(rci_manager.indicators.size()).is_equal(0)
	rci_manager.free_indicators([])
	assert_int(rci_manager.indicators.size()).is_equal(0)
	
	var indicator = library.indicator.instantiate()
	rci_manager.track_indicators([indicator])
	assert_int(rci_manager.indicators.size()).is_equal(1)
	
	rci_manager.free_indicators([indicator])
	assert_int(rci_manager.indicators.size()).is_equal(0)
	
	var indicators_to_remove : Array[RuleCheckIndicator] = []
	
	for i in range(0,10,1):
		var new_indicator = library.indicator.instantiate()
		rci_manager.track_indicators([new_indicator])
		indicators_to_remove.append(new_indicator)
		
	assert_int(rci_manager.indicators.size()).is_equal(10)
	rci_manager.free_indicators(indicators_to_remove)
	assert_int(rci_manager.indicators.size()).is_equal(0)

func _compare_transform_adjusted_rects(p_test_rect : Rect2, p_transform : Transform2D, p_col_object : CollisionObject2D):
	rci_manager.indicator_creation_testing_parameters.clear()
	var setup : IndicatorCollisionTestSetup = rci_manager._get_or_create_test_params(p_col_object)
	
	for rect_test in setup.rect_collision_test_setups:
		var shape_owner = rect_test.shape_owner
		var created_rect : Rect2 = rect_test.rect_shape.get_rect()
		var directly_adjusted_rect : Rect2 = Rect2(p_test_rect)
		assert_float(p_transform.get_skew()).is_equal_approx(shape_owner.global_transform.get_skew(), 0.01)
		assert_float(p_transform.get_rotation()).is_equal_approx(shape_owner.global_transform.get_rotation(), 0.01)
		directly_adjusted_rect *= p_transform

		assert_vector(directly_adjusted_rect.size).is_equal(created_rect.size)
		assert_vector(directly_adjusted_rect.position).is_equal(created_rect.position)

func test_setup_indicators_rotated_elipse():
	#region setup
	var test_object = auto_free(load("res://test/grid_building_test/scenes/test_elipse.tscn").instantiate())
	var rules : Array[PlacementRule] = [CollisionsCheckRule.new()]
	add_child(test_object)
	
	var test_params = RuleValidationParameters.new(
		placer, test_object, targeting_state
	)
	
	for rule in rules:
		rule.setup(test_params)
	var tile_check_rules = RuleFilters.only_tile_check(rules)
	#endregion
	
	var indicators = rci_manager.setup_indicators(test_object, tile_check_rules)
	assert_array(indicators).has_size(24)
	
	for indicator in indicators:
		assert_int(indicators.count(indicator)).is_equal(1)
	
	assert_int(indicators.size()).is_equal(24)

func test_expected_connections() -> void:
	assert_array(rci_manager.tree_entered.get_connections()).is_not_empty() # Tree entered to setup placement validator
	assert_array(rci_manager.tree_exited.get_connections()).is_not_empty() # Tree exited to clear self from placement validator
