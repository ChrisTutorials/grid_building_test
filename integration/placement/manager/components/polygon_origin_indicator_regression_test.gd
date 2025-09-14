## Regression test: Polygon test object should not generate indicator at (0,0) when centered
## This reproduces a specific bug where an unexpected indicator appears at tile (0,0) for the polygon test object
## when it's centered on the positioning grid.
##
## ## Architecture Verification
## This test also verifies the correct parent node architecture:
## - **IndicatorManager**: Parents rule check indicators (visual feedback)
## - **ManipulationParent**: Parents objects being manipulated (preview instances)
##
## See docs/systems/parent_node_architecture.md for detailed architecture documentation.
extends GdUnitTestSuite

const UnifiedTestFactory = preload("res://test/grid_building_test/factories/unified_test_factory.gd")

var _container: GBCompositionContainer
var _indicator_manager: IndicatorManager
var _targeting_state: GridTargetingState
var _map: TileMapLayer
var _manipulation_parent: Node2D
var _injector: GBInjectorSystem

func before_test() -> void:
	# Use the shared test container
	if ResourceLoader.exists("uid://dy6e5p5d6ax6n"):
		_container = preload("uid://dy6e5p5d6ax6n")
	else:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Create injector system for dependency injection
	_injector = UnifiedTestFactory.create_test_injector(self, _container)
	
	# Set up tile map layer
	_map = auto_free(TileMapLayer.new())
	_map.tile_set = load("uid://d11t2vm1pby6y")  # Use standard test tileset
	add_child(_map)
	
	# Populate a small centered region for testing
	for x in range(-5, 6):
		for y in range(-5, 6):
			_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	
	# Set up targeting state
	_targeting_state = _container.get_targeting_state()
	_targeting_state.target_map = _map
	
	# Create properly typed array for maps
	var maps_array: Array = [_map]
	_targeting_state.maps = maps_array
	
	# Create positioner at the exact center (0,0 tile)
	if _targeting_state.positioner == null:
		_targeting_state.positioner = auto_free(Node2D.new())
		add_child(_targeting_state.positioner)
	
	# Position the positioner at the exact center of tile (0,0)
	_targeting_state.positioner.global_position = _map.to_global(_map.map_to_local(Vector2i.ZERO))
	
	# Create manipulation parent as child of positioner (following proper architecture)
	# ManipulationParent: Parents objects being manipulated + IndicatorManager
	_manipulation_parent = auto_free(Node2D.new())
	_manipulation_parent.name = "ManipulationParent"
	_targeting_state.positioner.add_child(_manipulation_parent)
	
	# Set manipulation parent in container state
	_container.get_states().manipulation.parent = _manipulation_parent
	
	# Set up owner context (required for many operations)
	var owner_context: GBOwnerContext = _container.get_contexts().owner
	var owner_node: Node = auto_free(Node2D.new())
	owner_node.name = "TestOwner"
	add_child(owner_node)
	var gb_owner: GBOwner = auto_free(GBOwner.new(owner_node))
	owner_context.set_owner(gb_owner)
	
	# Set up placed parent (required for BuildingState validation)
	var placed_parent: Node2D = auto_free(Node2D.new())
	_container.get_states().building.placed_parent = placed_parent
	add_child(placed_parent)
	
	# Validate targeting state is ready
	var issues := _targeting_state.get_runtime_issues()
	
	if not issues.is_empty():
		print("[SKIP] Targeting state invalid: %s" % [issues])
		return
	
	# Create placement manager as child of manipulation parent (following proper architecture)
	# IndicatorManager: Parents rule check indicators (visual feedback)
	_indicator_manager = IndicatorManager.create_with_injection(_container)
	_manipulation_parent.add_child(_indicator_manager)
	auto_free(_indicator_manager)
	
	# Set quiet debug level to reduce noise
	_container.get_debug_settings().set_debug_level(GBDebugSettings.DebugLevel.ERROR)

func test_polygon_test_object_no_indicator_at_origin_when_centered() -> void:
	"""Regression test: Polygon test object should not generate an indicator at (0,0) when centered on the positioner."""
	if _container == null:
		assert_bool(false).append_failure_message("No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object using proper collision structure
	# NOTE: UnifiedTestFactory.create_polygon_test_object creates invalid structure,
	# so we'll create our own proper collision object
	var polygon_obj: Node = Node2D.new()
	polygon_obj.name = "ProperPolygonTestObject"
	_manipulation_parent.add_child(polygon_obj)  # Preview object goes under manipulation parent
	auto_free(polygon_obj)
	polygon_obj.position = Vector2.ZERO  # Ensure it's centered
	
	# Create proper StaticBody2D with CollisionPolygon2D child
	var static_body: StaticBody2D = StaticBody2D.new()
	static_body.name = "StaticBody2D"
	static_body.collision_layer = 1  # Match the rule's apply_to_objects_mask
	static_body.collision_mask = 1
	polygon_obj.add_child(static_body)
	
	# Create collision polygon as child of StaticBody2D (proper structure)
	var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	collision_polygon.name = "CollisionPolygon2D"
	# Define a concave polygon that should generate multiple indicators
	var points: PackedVector2Array = [
		Vector2(-32, -32),  # Top-left
		Vector2(32, -32),   # Top-right  
		Vector2(32, 0),     # Right-middle
		Vector2(0, 0),      # Center (creates concave shape)
		Vector2(0, 32),     # Bottom-center
		Vector2(-32, 32),   # Bottom-left
		Vector2(-32, -32)   # Close the polygon
	]
	collision_polygon.polygon = points
	static_body.add_child(collision_polygon)
	
	# Create a basic collision rule for indicator generation
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1  # Match the polygon's collision layer
	rule.collision_mask = 1
	var rules: Array = [rule]
	
	# Act: Generate indicators using IndicatorManager
	# ARCHITECTURE: IndicatorManager automatically parents indicators to itself
	var report: IndicatorSetupReport = _indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Add diagnostic info if no indicators are generated
	if report.indicators.size() == 0:
		# Find StaticBody2D child to get collision layer info
		var found_static_body: StaticBody2D = null
		for child in polygon_obj.get_children():
			if child is StaticBody2D:
				found_static_body = child
				break
		
		# Include diagnostic information when indicators aren't generated
		var failure_details: Array = []
		failure_details.append("Targeting state issues: %s" % str(_targeting_state.get_runtime_issues()))
		
		if found_static_body:
			failure_details.append("Polygon object collision layers: %d" % found_static_body.collision_layer)
		else:
			failure_details.append("No StaticBody2D found in polygon object")
			
		failure_details.append("Rule apply_to_objects_mask: %d" % rule.apply_to_objects_mask)
		failure_details.append("Report summary: %s" % report.to_summary_string())
		var child_classes: Array = []
		for child in polygon_obj.get_children():
			child_classes.append(child.get_class())
		failure_details.append("Polygon children: %s" % str(child_classes))
		
		var full_diagnostic: String = "\n".join(failure_details)
		
		# Use the diagnostic in the assertion
		assert_bool(report.indicators.size() > 0).append_failure_message(
			"Expected indicators to be generated for polygon test object.\nDiagnostic info:\n%s" % full_diagnostic
		).is_true()
	else:
		# Standard assertion when we do have indicators
		assert_bool(report.indicators.size() > 0).append_failure_message(
			"Expected indicators to be generated for polygon test object. Report: %s" % report.to_summary_string()
		).is_true()
	
	# Collect all indicator tile positions
	var indicator_tiles: Array = []
	for indicator in report.indicators:
		var tile_pos: Vector2i = _map.local_to_map(_map.to_local(indicator.global_position))
		indicator_tiles.append(tile_pos)
	
	# The main assertion: (0,0) should NOT have an indicator
	var has_origin_indicator: bool = Vector2i.ZERO in indicator_tiles
	assert_bool(has_origin_indicator).append_failure_message(
		"REGRESSION: Found unexpected indicator at (0,0) for polygon test object. " +
		"Indicator tiles: " + str(indicator_tiles) + ". This indicates the collision detection is incorrectly " +
		"including the origin tile when the polygon is centered."
	).is_false()

func test_polygon_test_object_valid_indicators_generated() -> void:
	"""Sanity check: Ensure polygon test object generates some valid indicators, just not at (0,0)."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object under manipulation parent
	var polygon_obj: Node = UnifiedTestFactory.create_polygon_test_object(self)
	_manipulation_parent.add_child(polygon_obj)  # Preview object goes under manipulation parent
	polygon_obj.position = Vector2.ZERO
	
	# Create collision rule
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	var rules: Array = [rule]
	
	# Act: Generate indicators using IndicatorManager
	var report: IndicatorSetupReport = _indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Assert: Should have reasonable number of indicators (not zero, not excessive)
	assert_int(report.indicators.size()).append_failure_message(
		"Expected polygon test object to generate indicators. Report: %s" % report.to_summary_string()
	).is_greater(0)
	
	# Should not generate excessive indicators (regression prevention)
	assert_int(report.indicators.size()).append_failure_message(
		"Too many indicators generated for polygon test object (possible over-generation bug). " +
		"Count: %d, Report: %s" % [report.indicators.size(), report.to_summary_string()]
	).is_less_equal(15)  # Reasonable upper bound

func test_polygon_test_object_centered_preview_flag() -> void:
	"""Verify that the polygon test object correctly triggers the centered_preview flag in the report."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object as child of positioner (this should trigger centered_preview)
	var polygon_obj: Node = UnifiedTestFactory.create_polygon_test_object(self)
	_targeting_state.positioner.add_child(polygon_obj)
	
	# Create collision rule
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	var rules: Array = [rule]
	
	# Act: Generate indicators using IndicatorManager
	var report: IndicatorSetupReport = _indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Assert: notes should reflect the centering
	var notes_contain_centered: bool = false
	for note in report.notes:
		if "preview_centered" in note:
			notes_contain_centered = true
			break
	
	assert_bool(notes_contain_centered).append_failure_message(
		"Expected 'preview_centered' note in report when object is centered. Notes: %s" % [report.notes]
	).is_true()

func test_proper_parent_architecture_maintained() -> void:
	"""Verify that the correct parent node architecture is maintained during indicator generation."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object under manipulation parent
	var polygon_obj: Node = UnifiedTestFactory.create_polygon_test_object(self)
	_manipulation_parent.add_child(polygon_obj)
	
	# Create collision rule
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	var rules: Array = [rule]
	
	# Act: Generate indicators
	var report: IndicatorSetupReport = _indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Assert: Preview object should be child of manipulation parent
	assert_object(polygon_obj.get_parent()).append_failure_message(
		"Preview object should be child of ManipulationParent, not %s" % polygon_obj.get_parent().name
	).is_equal(_manipulation_parent)
	
	# Assert: All indicators should be children of indicator manager
	for indicator in report.indicators:
		assert_object(indicator.get_parent()).append_failure_message(
			"Indicator should be child of IndicatorManager, not %s. This violates the parent architecture." % indicator.get_parent().name
		).is_equal(_indicator_manager)
	
	# Assert: IndicatorManager should be child of manipulation parent
	assert_object(_indicator_manager.get_parent()).append_failure_message(
		"IndicatorManager should be child of ManipulationParent, not %s" % _indicator_manager.get_parent().name
	).is_equal(_manipulation_parent)
