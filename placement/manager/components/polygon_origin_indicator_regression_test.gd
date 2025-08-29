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

var _container: GBCompositionContainer
var _indicator_manager: IndicatorManager
var _targeting_state: GridTargetingState
var _map: TileMapLayer
var _manipulation_parent: Node2D
var _injector: GBInjectorSystem

func before_test():
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
	_targeting_state.maps = [_map]
	
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
	
	# Validate targeting state is ready
	var issues := _targeting_state.validate_runtime()
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

func test_polygon_test_object_no_indicator_at_origin_when_centered():
	"""Regression test: Polygon test object should not generate an indicator at (0,0) when centered on the positioner."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object and parent to manipulation parent
	# ARCHITECTURE: Preview objects being manipulated go under ManipulationParent
	var polygon_obj = UnifiedTestFactory.create_polygon_test_object(self)
	_manipulation_parent.add_child(polygon_obj)  # Preview object goes under manipulation parent
	polygon_obj.position = Vector2.ZERO  # Ensure it's centered
	
	# Create a basic collision rule for indicator generation
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1  # Match the polygon's collision layer
	rule.collision_mask = 1
	var rules: Array[TileCheckRule] = [rule]
	
	# Act: Generate indicators using IndicatorManager
	# ARCHITECTURE: IndicatorManager automatically parents indicators to itself
	var report: IndicatorSetupReport = _indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Assert: Check that we have indicators but NOT at (0,0)
	assert_bool(report.indicators.size() > 0).append_failure_message(
		"Expected indicators to be generated for polygon test object. Report: %s" % report.to_summary_string()
	).is_true()
	
	# Collect all indicator tile positions
	var indicator_tiles: Array[Vector2i] = []
	for indicator in report.indicators:
		var tile_pos = _map.local_to_map(_map.to_local(indicator.global_position))
		indicator_tiles.append(tile_pos)
	
	# The main assertion: (0,0) should NOT have an indicator
	var has_origin_indicator = Vector2i.ZERO in indicator_tiles
	assert_bool(has_origin_indicator).append_failure_message(
		"REGRESSION: Found unexpected indicator at (0,0) for polygon test object. " +
		"Indicator tiles: " + str(indicator_tiles) + ". This indicates the collision detection is incorrectly " +
		"including the origin tile when the polygon is centered."
	).is_false()
	
	# Diagnostic information
	if has_origin_indicator:
		print("REGRESSION DETECTED: Indicator at (0,0) found")
		print("All indicator tiles: %s" % [indicator_tiles])
		print("Report summary: %s" % report.to_summary_string())
		print("Report verbose: %s" % report.to_verbose_string())

func test_polygon_test_object_valid_indicators_generated():
	"""Sanity check: Ensure polygon test object generates some valid indicators, just not at (0,0)."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object under manipulation parent
	var polygon_obj = UnifiedTestFactory.create_polygon_test_object(self)
	_manipulation_parent.add_child(polygon_obj)  # Preview object goes under manipulation parent
	polygon_obj.position = Vector2.ZERO
	
	# Create collision rule
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	var rules: Array[TileCheckRule] = [rule]
	
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

func test_polygon_test_object_centered_preview_flag():
	"""Verify that the polygon test object correctly triggers the centered_preview flag in the report."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object as child of positioner (this should trigger centered_preview)
	var polygon_obj = UnifiedTestFactory.create_polygon_test_object(self)
	_targeting_state.positioner.add_child(polygon_obj)
	
	# Create collision rule
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	var rules: Array[TileCheckRule] = [rule]
	
	# Act: Generate indicators using IndicatorManager
	var report: IndicatorSetupReport = _indicator_manager.setup_indicators(polygon_obj, rules)
	
	# Assert: centered_preview flag should be true when object is child of positioner
	assert_bool(report.centered_preview).append_failure_message(
		"Expected centered_preview=true when polygon object is child of positioner. Report: %s" % report.to_summary_string()
	).is_true()
	
	# Assert: notes should reflect the centering
	var notes_contain_centered = false
	for note in report.notes:
		if "preview_centered" in note:
			notes_contain_centered = true
			break
	
	assert_bool(notes_contain_centered).append_failure_message(
		"Expected 'preview_centered' note in report when object is centered. Notes: %s" % [report.notes]
	).is_true()

func test_proper_parent_architecture_maintained():
	"""Verify that the correct parent node architecture is maintained during indicator generation."""
	if _container == null:
		print("[SKIP] No container available; test environment not wired.")
		return
	
	# Arrange: Create polygon test object under manipulation parent
	var polygon_obj = UnifiedTestFactory.create_polygon_test_object(self)
	_manipulation_parent.add_child(polygon_obj)
	
	# Create collision rule
	var rule := CollisionsCheckRule.new()
	rule.apply_to_objects_mask = 1
	rule.collision_mask = 1
	var rules: Array[TileCheckRule] = [rule]
	
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
