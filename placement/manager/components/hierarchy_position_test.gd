extends GdUnitTestSuite

## Test to understand the actual coordinate relationships in the hierarchy

func test_hierarchy_positions():
	# Create the hierarchy as shown in the user's screenshot
	var world = auto_free(Node2D.new())
	world.name = "World"
	
	var grid_positioner = auto_free(Node2D.new())
	grid_positioner.name = "GridPositioner"
	world.add_child(grid_positioner)
	
	var manipulation_parent = auto_free(Node2D.new())
	manipulation_parent.name = "ManipulationParent"
	grid_positioner.add_child(manipulation_parent)
	
	var placement_manager = auto_free(Node2D.new())
	placement_manager.name = "PlacementManager"
	manipulation_parent.add_child(placement_manager)
	
	# Position the grid positioner at a specific location (like mouse position)
	grid_positioner.global_position = Vector2(100, 100)
	
	print("GridPositioner global_position: %s" % grid_positioner.global_position)
	print("ManipulationParent global_position: %s" % manipulation_parent.global_position)
	print("PlacementManager global_position: %s" % placement_manager.global_position)
	
	# Create a preview object as child of manipulation parent (like the system does)
	var preview = auto_free(Node2D.new())
	preview.name = "Preview"
	manipulation_parent.add_child(preview)
	preview.position = Vector2.ZERO  # Local position relative to manipulation parent
	
	print("Preview global_position: %s" % preview.global_position)
	print("Preview local position relative to ManipulationParent: %s" % preview.position)
	
	# Create an indicator as child of placement manager  
	var indicator = auto_free(Node2D.new())
	indicator.name = "Indicator"
	placement_manager.add_child(indicator)
	
	# Test: If we want indicator to be at same global position as preview
	indicator.global_position = preview.global_position
	print("Indicator global_position: %s" % indicator.global_position)
	print("Indicator local position relative to PlacementManager: %s" % indicator.position)
	
	# Verify they're at the same global position
	assert_that(indicator.global_position.x).is_equal_approx(preview.global_position.x, 0.1)
	assert_that(indicator.global_position.y).is_equal_approx(preview.global_position.y, 0.1)
