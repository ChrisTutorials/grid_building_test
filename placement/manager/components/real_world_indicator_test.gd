class_name RealWorldIndicatorTest
extends GdUnitTestSuite

## Tests indicator positioning using the exact same setup as the real system

var building_system: BuildingSystem
var placement_manager: PlacementManager
var targeting_state: GridTargetingState
var positioner: Node2D

func before_test():
	# Create the exact same setup as the real system would use
	var container = auto_free(GBCompositionContainer.new())
	
	# Set up targeting state with real tile map
	targeting_state = container.get_states().targeting
	var tile_map_layer = GBDoubleFactory.create_test_tile_map_layer(self)
	targeting_state.target_map = tile_map_layer
	targeting_state.set_positioner(auto_free(Node2D.new()))
	
	# Set up building system
	building_system = auto_free(BuildingSystem.new())
	building_system.resolve_gb_dependencies(container)
	add_child(building_system)
	
	# Set up placement manager
	placement_manager = container.get_contexts().placement.get_manager()

## Test with a real placeable that has collision shapes like in the screenshot
func test_real_world_indicator_positioning():
	# Load a real placeable similar to what's in the screenshot
	var eclipse_placeable = TestSceneLibrary.placeable_eclipse
	assert_that(eclipse_placeable).is_not_null()
	
	# Create preview instance (this is what BuildingSystem does)
	var preview = building_system.instance_preview(eclipse_placeable)
	assert_that(preview).is_not_null()
	
	print("Preview global_position: %s" % preview.global_position)
	print("Positioner global_position: %s" % targeting_state.positioner.global_position)
	
	# Set up placement rules (this triggers indicator creation)
	var params = RuleValidationParameters.new(
		auto_free(Node.new()),  # placer
		preview,                # target (preview instance)
		targeting_state
	)
	
	var success = placement_manager.try_setup(eclipse_placeable.placement_rules, params)
	assert_that(success).is_true()
	
	# Get the created indicators
	var indicators = placement_manager.get_indicators()
	assert_that(indicators.size()).is_greater(0)
	
	print("Number of indicators created: %d" % indicators.size())
	
	# Check first few indicator positions vs preview position
	for i in range(min(3, indicators.size())):
		var indicator = indicators[i]
		print("Indicator %d global_position: %s" % [i, indicator.global_position])
		
		# Calculate expected position based on preview position and collision detection
		# The indicator should be positioned relative to the preview's collision shapes
		# Since preview is a child of positioner, indicator positions should align with preview collision coverage
		
		# For now, just verify that indicators are not all at the same position (they should spread out)
		if i > 0:
			var prev_indicator = indicators[i-1]
			assert_that(indicator.global_position).append_failure_message("Indicators should not all be at the same position").is_not_equal(prev_indicator.global_position)
