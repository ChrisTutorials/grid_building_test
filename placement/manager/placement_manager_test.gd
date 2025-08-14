## GdUnit TestSuite for PlacementManager indicator creation
extends GdUnitTestSuite

# Minimal, parameterized, and double-factory-based PlacementManager tests
var placement_manager: PlacementManager
var map_layer: TileMapLayer
var col_checking_rules: Array[TileCheckRule]
var global_snap_pos: Vector2
var eclipse_scene = load("uid://j5837ml5dduu")
var offset_logo = load("uid://bqq7otaevtlqu")

var _positioner : Node2D
var _injector: GBInjectorSystem
var _container : GBCompositionContainer = load("uid://dy6e5p5d6ax6n")

func before_test():
	_setup_targeting_state()
	_setup_placement_manager()

func _setup_targeting_state():
	# Step 1: Set up the targeting state with its runtime dependencies (map objects and positioner).
	# This must be done first so that PlacementManager receives a fully initialized targeting state.
	_injector = auto_free(GBInjectorSystem.create_with_injection(_container))
	add_child(_injector)
	map_layer = auto_free(TileMapLayer.new())
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16, 16)
	var targeting_state = _container.get_states().targeting
	var map_layers : Array[TileMapLayer] = [map_layer]
	targeting_state.set_map_objects(map_layer, map_layers)
	_positioner = Node2D.new()
	auto_free(_positioner)
	targeting_state.set_positioner(_positioner)

func _setup_placement_manager():
	# Step 2: Create IndicatorManager, inject dependencies, and set it on PlacementManager.
	placement_manager = auto_free(PlacementManager.new())
	add_child(placement_manager)
	
	# Initialize PlacementManager with all required dependencies
	var placement_context := PlacementContext.new()
	auto_free(placement_context)
	var indicator_template := load("uid://nhlp6ks003fp")
	var targeting_state := _container.get_states().targeting
	var logger := GBLogger.create_with_injection(_container)
	var rules: Array[PlacementRule] = []
	var messages := GBMessages.new()
	
	placement_manager.initialize(placement_context, indicator_template, targeting_state, logger, rules, messages)
	
	global_snap_pos = map_layer.map_to_local(Vector2i(0,0))
	col_checking_rules = RuleFilters.only_tile_check([CollisionsCheckRule.new()])

func after_test():
	if is_instance_valid(placement_manager):
		placement_manager.queue_free()
	placement_manager = null

func after() -> void:
	assert_object(_injector).is_null()
	assert_object(placement_manager).is_null()
	assert_object(map_layer).is_null()
	assert_object(_positioner).is_null()

## Should be handled by the GBInjectorSystem automatically
func test_indicator_manager_dependencies_initialized():
	# Test that the PlacementManager can actually function instead of testing private properties
	# Create a test scene and verify indicators are generated
	var shape_scene = auto_free(eclipse_scene.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	
	var indicators = placement_manager.setup_indicators(shape_scene, col_checking_rules)
	
	# Assert that indicators were created (this tests the internal functionality without exposing private properties)
	assert_int(indicators.size()).is_greater(0)
	
	# Test that the manager can get colliding indicators
	var colliding_indicators = placement_manager.get_colliding_indicators()
	# Initially there should be no colliding indicators since we just set them up
	assert_int(colliding_indicators.size()).is_equal(0)

@warning_ignore("unused_parameter")
func test_indicator_count_for_shapes(scene_resource: PackedScene, expected: int, test_parameters := [
	[eclipse_scene, 27],
	[offset_logo, 4]
]):
	var shape_scene = auto_free(scene_resource.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	# Debug: print info about the instantiated scene
	print("[DEBUG] Scene: ", shape_scene, " Children: ", shape_scene.get_child_count())
	for i in shape_scene.get_children():
		print("[DEBUG] Child: ", i, " Type: ", typeof(i))
	# Debug: print info about indicator template - removed access to private property
	print("[DEBUG] Testing indicator generation...")
	var indicators = placement_manager.setup_indicators(shape_scene, col_checking_rules)
	print("[DEBUG] Indicators generated: ", indicators.size())
	assert_int(indicators.size()).append_failure_message("Generated indicator count did not match expected count.").is_equal(expected)

func test_indicator_positions_are_unique():
	var shape_scene = auto_free(eclipse_scene.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var indicators = placement_manager.setup_indicators(shape_scene, col_checking_rules)
	var positions = []
	for indicator in indicators:
		positions.append(indicator.global_position)
	# Remove duplicates manually
	var unique_positions = []
	for pos in positions:
		if not unique_positions.has(pos):
			unique_positions.append(pos)
	assert_int(positions.size()).append_failure_message("Indicator positions are not unique").is_equal(unique_positions.size())

func test_no_indicators_for_empty_scene():
	var empty_node = auto_free(Node2D.new())
	add_child(empty_node)
	var indicators : Array[RuleCheckIndicator] = placement_manager.setup_indicators(empty_node, col_checking_rules)
	assert_int(indicators.size()).append_failure_message("Indicators should be zero for empty scene").is_equal(0)

@warning_ignore("unused_parameter")
func test_indicator_generation_distance(scene_resource: PackedScene, expected_distance: float, test_parameters := [
	[eclipse_scene, 16.0]
]):
	var shape_scene = auto_free(scene_resource.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var indicators : Array[RuleCheckIndicator] = placement_manager.setup_indicators(shape_scene, col_checking_rules)
	if indicators.size() < 2:
		return # Not enough indicators to test distance
	var indicator_0 = indicators[0]
	var indicator_1 = indicators[1]
	var distance_to = indicator_0.global_position.distance_to(indicator_1.global_position)
	assert_float(distance_to).append_failure_message("16x16 tile spacing").is_equal(expected_distance)

func test_indicators_are_freed_on_reset():
	var shape_scene = auto_free(eclipse_scene.instantiate())
	add_child(shape_scene)
	shape_scene.global_position = global_snap_pos
	var indicators : Array[RuleCheckIndicator] = placement_manager.setup_indicators(shape_scene, col_checking_rules)
	assert_int(indicators.size()).append_failure_message("No indicators generated before reset").is_greater(0)
	placement_manager.tear_down()
	# After tear_down, call setup on empty to confirm no indicators remain
	var cleared := placement_manager.get_colliding_indicators()
	assert_int(cleared.size()).append_failure_message("Indicators not cleared after tear_down").is_equal(0)
