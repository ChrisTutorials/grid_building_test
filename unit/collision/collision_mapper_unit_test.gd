extends GdUnitTestSuite

# Unit tests for CollisionMapper to catch guard behaviors and setup issues
# that can cause integration test failures at higher levels.

var _logger: GBLogger

func before_test():
	_logger = GBLogger.new(GBDebugSettings.new())

# Helper function to generate detailed mapper setup diagnostics
func _generate_mapper_setup_diagnostics(mapper: CollisionMapper, body: Node2D) -> String:
	var diagnostics = "Mapper Setup Diagnostics:\n"
	
	var test_indicator_valid = mapper.test_indicator != null
	var setups_valid = mapper.collision_object_test_setups != null and not mapper.collision_object_test_setups.is_empty()
	var has_body_setup = mapper.collision_object_test_setups.has(body) if setups_valid else false
	var body_setup_valid = mapper.collision_object_test_setups[body] != null if has_body_setup else false
	
	diagnostics += "- Test indicator valid: %s\n" % test_indicator_valid
	diagnostics += "- Collision setups valid: %s\n" % setups_valid
	diagnostics += "- Has body setup: %s\n" % has_body_setup
	diagnostics += "- Body setup valid: %s\n" % body_setup_valid
	
	if has_body_setup and body_setup_valid:
		var body_test_setup = mapper.collision_object_test_setups[body]
		diagnostics += "- Test setup rect_collision_test_setups: %d\n" % body_test_setup.rect_collision_test_setups.size()
		if body_test_setup.rect_collision_test_setups.size() > 0:
			var first_rect_setup = body_test_setup.rect_collision_test_setups[0]
			diagnostics += "- First rect setup shapes: %d\n" % first_rect_setup.shapes.size()
			if first_rect_setup.shapes.size() > 0:
				diagnostics += "- First shape type: %s\n" % first_rect_setup.shapes[0].get_class()
	
	return diagnostics

# Helper function to generate collision object diagnostics
func _generate_collision_object_diagnostics(body: Node2D) -> String:
	var diagnostics = "Collision Object Diagnostics:\n"
	diagnostics += "- Shape owners count: %d\n" % body.get_shape_owners().size()
	diagnostics += "- Collision layer: %d\n" % body.collision_layer
	diagnostics += "- Position: %s\n" % body.position
	diagnostics += "- Global position: %s\n" % body.global_position
	return diagnostics

# Helper function to generate layer/mask matching diagnostics
func _generate_layer_mask_diagnostics(body: Node2D, mask: int) -> String:
	var diagnostics = "Layer/Mask Matching Diagnostics:\n"
	var layer_matches_mask = (body.collision_layer & mask) != 0
	diagnostics += "- Layer: %d, Mask: %d\n" % [body.collision_layer, mask]
	diagnostics += "- Layer matches mask: %s\n" % layer_matches_mask
	diagnostics += "- Bitwise AND result: %d\n" % (body.collision_layer & mask)
	return diagnostics

# Helper function to generate comprehensive test failure analysis
func _generate_comprehensive_failure_analysis(result_size: int, expected_min: int, layer_matches: bool, guard_complete: bool, body: Node2D, rule_mask: int, mapper: CollisionMapper) -> String:
	var analysis = "\n=== COMPREHENSIVE FAILURE ANALYSIS ===\n"
	analysis += "Expected: At least %d collision positions\n" % expected_min
	analysis += "Actual: %d collision positions\n\n" % result_size

	analysis += "CRITICAL CHECKS:\n"
	analysis += "✓ Layer/Mask Match: %s\n" % ("PASS" if layer_matches else "FAIL")
	analysis += "✓ Guard Setup Complete: %s\n" % ("PASS" if guard_complete else "FAIL")
	analysis += "✓ Collision Object Valid: %s\n\n" % ("PASS" if body != null else "FAIL")

	if not guard_complete:
		analysis += "GUARD FAILURE DETAILS:\n"
		analysis += "- Test indicator: %s\n" % ("null" if mapper.test_indicator == null else "valid")
		analysis += "- Collision setups: %s\n" % ("null" if mapper.collision_object_test_setups == null else "initialized")
		if mapper.collision_object_test_setups != null:
			analysis += "- Setups count: %d\n" % mapper.collision_object_test_setups.size()
			analysis += "- Has body setup: %s\n" % mapper.collision_object_test_setups.has(body)

	if not layer_matches:
		analysis += "\nLAYER/MASK FAILURE DETAILS:\n"
		analysis += "- Body layer: %d (0b%s)\n" % [body.collision_layer, String.num_int64(body.collision_layer, 2)]
		analysis += "- Rule mask: %d (0b%s)\n" % [rule_mask, String.num_int64(rule_mask, 2)]
		analysis += "- Bitwise AND: %d (0b%s)\n" % [(body.collision_layer & rule_mask), String.num_int64((body.collision_layer & rule_mask), 2)]

	analysis += "\nCOLLISION OBJECT STATE:\n"
	analysis += _generate_collision_object_diagnostics(body)

	analysis += "\nMAPPER SETUP STATE:\n"
	analysis += _generate_mapper_setup_diagnostics(mapper, body)

	return analysis

# Helper function to generate actionable next steps
func _generate_actionable_next_steps(result_size: int, layer_matches: bool, guard_complete: bool) -> String:
	var steps = "\n=== ACTIONABLE NEXT STEPS ===\n"

	if not guard_complete:
		steps += "1. Fix mapper setup - ensure setup() is called with valid parameters\n"
		steps += "2. Verify test_indicator is not null\n"
		steps += "3. Verify collision_object_test_setups contains the collision body\n"

	if not layer_matches:
		steps += "1. Check collision layer settings on collision objects\n"
		steps += "2. Verify rule apply_to_objects_mask matches collision layers\n"
		steps += "3. Use bitwise operations to ensure proper layer/mask alignment\n"

	if result_size == 0 and guard_complete and layer_matches:
		steps += "1. Check collision shape setup and geometry\n"
		steps += "2. Verify collision shapes are properly attached to collision objects\n"
		steps += "3. Check if collision shapes have valid geometry (non-zero size)\n"
		steps += "4. Verify collision objects are added to scene tree before setup\n"

	steps += "\nDEBUGGING TOOLS:\n"
	steps += "- Use _generate_collision_object_diagnostics() for collision object state\n"
	steps += "- Use _generate_mapper_setup_diagnostics() for mapper configuration\n"
	steps += "- Use _generate_layer_mask_diagnostics() for layer/mask matching\n"
	
	return steps

# Helper function to generate test setup diagnostics
func _generate_test_setup_diagnostics(test_setup: IndicatorCollisionTestSetup) -> String:
	var diagnostics = "Test Setup Diagnostics:\n"
	diagnostics += "- Setup valid: %s\n" % test_setup.validate_setup()
	diagnostics += "- Rect collision test setups: %d\n" % test_setup.rect_collision_test_setups.size()
	return diagnostics

# Test catches: CollisionMapper guard behavior when setup() not called (EXPECTED to pass)
func test_guard_returns_empty_without_setup() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self)
	var mapper := CollisionMapper.new(gts, _logger)
	# Create a polygon owner but do not call setup(); guard should prevent mapping
	var body := StaticBody2D.new()
	auto_free(body)
	var poly := CollisionPolygon2D.new()
	body.add_child(poly)
	poly.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var rule := TileCheckRule.new()
	var result := mapper.map_collision_positions_to_rules([poly], [rule])
	assert_that(result.size()).is_equal(0).append_failure_message("Expected empty mapping when mapper.setup() not called")

# Simple test to verify basic collision detection works
func test_basic_collision_detection() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self)
	var mapper := CollisionMapper.new(gts, _logger)
	
	# Add the map to the scene tree
	if gts.target_map != null:
		add_child(gts.target_map)
	
	# Create collision object at origin with a shape that should definitely overlap
	var body := StaticBody2D.new()
	auto_free(body)
	body.collision_layer = 1
	body.position = Vector2(0, 0)  # At origin
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)  # Large shape that should overlap multiple tiles
	shape.shape = rect
	body.add_child(shape)
	
	# Add to scene tree
	add_child(body)
	
	# Setup mapper
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var test_indicator := template.instantiate()
	auto_free(test_indicator)
	
	var test_setup := IndicatorCollisionTestSetup.new(body, Vector2(16, 16))
	var setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	setups[body] = test_setup
	mapper.setup(test_indicator, setups)
	
	# Test basic collision detection
	var result := mapper.get_collision_tile_positions_with_mask([body], 1)
	
	# Debug output
	var debug_info = "Basic collision test:\n"
	debug_info += "Body position: %s\n" % body.position
	debug_info += "Shape size: %s\n" % rect.size
	debug_info += "Result size: %d\n" % result.size()
	if result.size() > 0:
		debug_info += "Found tiles: %s\n" % result.keys()
	
	assert_that(result.size()).append_failure_message(debug_info).is_greater(0)

func test_collision_layer_matching_for_tile_check_rules() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self)
	var mapper := CollisionMapper.new(gts, _logger)
	
	# Add the map to the scene tree (required for proper node operations)
	if gts.target_map != null:
		add_child(gts.target_map)
	
	# Create collision object with specific layer (513 = bits 0+9)
	var body := StaticBody2D.new()
	auto_free(body)
	body.collision_layer = 513
	body.position = Vector2(8, 8)  # Position at center of tile (0,0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	
	# Add to scene tree
	add_child(body)
	
	# Verify collision object setup
	var shape_owner_count = body.get_shape_owners().size()
	assert_that(shape_owner_count).append_failure_message("Collision object must have shape owners for collision detection").is_greater(0)
	
	assert_that(body.collision_layer).append_failure_message("Collision layer must be set to 513 for this test").is_equal(513)
	
	# Create testing indicator and setup mapper
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var test_indicator := template.instantiate()
	auto_free(test_indicator)
	
	# Create test setup and validate it
	var test_setup := IndicatorCollisionTestSetup.new(body, Vector2(16, 16))
	assert_that(test_setup.validate_setup()).append_failure_message(_generate_test_setup_diagnostics(test_setup)).is_true()
	
	var setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	setups[body] = test_setup
	mapper.setup(test_indicator, setups)
	
	# Create rule with collision mask that should match layer 513
	var rule := TileCheckRule.new()
	rule.apply_to_objects_mask = 1  # bit 0 should match with layer bit 0
	
	assert_that(rule.apply_to_objects_mask).append_failure_message("Rule mask must be 1 for this test").is_equal(1)
	
	# Verify layer and mask compatibility
	var layer_matches_mask = (body.collision_layer & rule.apply_to_objects_mask) != 0
	assert_that(layer_matches_mask).append_failure_message(_generate_layer_mask_diagnostics(body, rule.apply_to_objects_mask)).is_true()
	
	# Verify mapper setup is complete
	assert_that(mapper.test_indicator).append_failure_message("Mapper test indicator must be set after setup").is_not_null()
	assert_that(mapper.collision_object_test_setups).append_failure_message("Mapper collision setups must be initialized").is_not_null()
	assert_that(mapper.collision_object_test_setups.is_empty()).append_failure_message("Mapper collision setups must not be empty").is_false()
	assert_that(mapper.collision_object_test_setups.has(body)).append_failure_message("Mapper must have setup for the collision body").is_true()
	assert_that(mapper.collision_object_test_setups[body]).append_failure_message("Mapper body setup must not be null").is_not_null()
	
	var result := mapper.get_collision_tile_positions_with_mask([body], rule.apply_to_objects_mask)
	
	# Debug: Add detailed collision detection diagnostics
	var debug_info = "\n=== COLLISION DETECTION DEBUG ===\n"
	debug_info += "Body position: %s\n" % body.position
	debug_info += "Body global position: %s\n" % body.global_position
	debug_info += "Shape count: %d\n" % body.get_shape_owners().size()
	
	if body.get_shape_owners().size() > 0:
		var shape_owner_id = body.get_shape_owners()[0]
		var shape_owner = body.shape_owner_get_owner(shape_owner_id)
		debug_info += "First shape owner: %s\n" % shape_owner.name
		debug_info += "Shape owner position: %s\n" % shape_owner.position
		debug_info += "Shape owner global position: %s\n" % shape_owner.global_position
		
		if shape_owner is CollisionShape2D and shape_owner.shape:
			debug_info += "Shape type: %s\n" % shape_owner.shape.get_class()
			if shape_owner.shape is RectangleShape2D:
				debug_info += "Shape size: %s\n" % shape_owner.shape.size
	
	# Check test setup details
	var collision_test_setup = mapper.collision_object_test_setups[body]
	debug_info += "Test setup valid: %s\n" % collision_test_setup.validate_setup()
	debug_info += "Rect collision test setups count: %d\n" % collision_test_setup.rect_collision_test_setups.size()
	
	if collision_test_setup.rect_collision_test_setups.size() > 0:
		var first_rect_setup = collision_test_setup.rect_collision_test_setups[0]
		debug_info += "First rect setup shapes count: %d\n" % first_rect_setup.shapes.size()
		if first_rect_setup.rect_shape:
			debug_info += "First rect setup rect shape size: %s\n" % first_rect_setup.rect_shape.size
	
	# Check map details
	if gts.target_map:
		debug_info += "Map tile size: %s\n" % gts.target_map.tile_set.tile_size
		debug_info += "Map position: %s\n" % gts.target_map.position
		debug_info += "Map global position: %s\n" % gts.target_map.global_position
		
		# Check tile coordinates
		var body_tile = gts.target_map.local_to_map(gts.target_map.to_local(body.global_position))
		debug_info += "Body tile coordinates: %s\n" % body_tile
	
	debug_info += "Result size: %d\n" % result.size()
	debug_info += "================================\n"
	
	# Verify result structure
	assert_that(typeof(result)).append_failure_message("Result must be a Dictionary type").is_equal(TYPE_DICTIONARY)
	
	# Verify collision object has matching layer
	var layer_matches = PhysicsMatchingUtils2D.object_has_matching_layer(body, rule.apply_to_objects_mask)
	
	# Concise failure message with debug info
	var failure_msg = "Expected collision positions for layer %d & mask %d, but got empty result. Layer matches: %s, Result size: %d\n%s" % [
		body.collision_layer, rule.apply_to_objects_mask, layer_matches, result.size(), debug_info
	]
	
	assert_that(result.size()).append_failure_message(failure_msg).is_greater(0)

# Test catches: CollisionMapper failing to produce position-rules mapping for valid setup
# EXPECTED FAILURE: Catches real issue where position-rules mapping fails despite valid setup
# This test failure indicates the collision mapping system has issues that would cause
# integration tests to show "0 indicators generated" despite valid collision objects
func test_position_rules_mapping_produces_results() -> void:
	var gts := UnifiedTestFactory.create_minimal_targeting_state(self)
	var mapper := CollisionMapper.new(gts, _logger)
	
	# Add the map to the scene tree (required for proper node operations)
	if gts.target_map != null:
		add_child(gts.target_map)
	
	# Create collision object
	var body := StaticBody2D.new()
	auto_free(body)
	body.collision_layer = 1  # bit 0
	body.position = Vector2(8, 8)  # Position at center of tile (0,0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	
	# Add to scene tree
	add_child(body)
	
	# Debug: Check if collision object has shape owners
	var shape_owner_count = body.get_shape_owners().size()
	assert_that(shape_owner_count).append_failure_message("Collision object should have shape owners").is_greater(0)
	
	# Verify collision layer is set correctly
	assert_that(body.collision_layer).append_failure_message("Collision layer should be 1").is_equal(1)
	
	# Setup mapper
	var template := UnifiedTestFactory.create_minimal_indicator_template(self)
	var test_indicator := template.instantiate()
	auto_free(test_indicator)
	
	# Create test setup and validate it
	var test_setup := IndicatorCollisionTestSetup.new(body, Vector2(16, 16))
	assert_that(test_setup.validate_setup()).append_failure_message("Test setup should be valid").is_true()
	
	var setups: Dictionary[Node2D, IndicatorCollisionTestSetup] = {}
	setups[body] = test_setup
	mapper.setup(test_indicator, setups)
	
	# Create rule that should match
	var rule := TileCheckRule.new()
	rule.apply_to_objects_mask = 1  # bit 0
	
	# Verify rule mask matches collision layer
	assert_that(rule.apply_to_objects_mask).is_equal(1).append_failure_message("Rule mask should be 1")
	var layer_matches_mask = (body.collision_layer & rule.apply_to_objects_mask) != 0
	assert_that(layer_matches_mask).append_failure_message("Layer %d should match mask %d (bitwise AND should be non-zero)" % [body.collision_layer, rule.apply_to_objects_mask]).is_true()
	
	var position_rules_map := mapper.map_collision_positions_to_rules([body], [rule])

	# Debug: Add detailed collision detection diagnostics for position-rules mapping
	var debug_info = "\n=== POSITION-RULES MAPPING DEBUG ===\n"
	debug_info += "Body position: %s\n" % body.position
	debug_info += "Body global position: %s\n" % body.global_position
	debug_info += "Shape count: %d\n" % body.get_shape_owners().size()
	
	if body.get_shape_owners().size() > 0:
		var shape_owner_id = body.get_shape_owners()[0]
		var shape_owner = body.shape_owner_get_owner(shape_owner_id)
		debug_info += "First shape owner: %s\n" % shape_owner.name
		debug_info += "Shape owner position: %s\n" % shape_owner.position
		debug_info += "Shape owner global position: %s\n" % shape_owner.global_position
		
		if shape_owner is CollisionShape2D and shape_owner.shape:
			debug_info += "Shape type: %s\n" % shape_owner.shape.get_class()
			if shape_owner.shape is RectangleShape2D:
				debug_info += "Shape size: %s\n" % shape_owner.shape.size
	
	# Check test setup details
	var collision_test_setup = mapper.collision_object_test_setups[body]
	debug_info += "Test setup valid: %s\n" % collision_test_setup.validate_setup()
	debug_info += "Rect collision test setups count: %d\n" % collision_test_setup.rect_collision_test_setups.size()
	
	if collision_test_setup.rect_collision_test_setups.size() > 0:
		var first_rect_setup = collision_test_setup.rect_collision_test_setups[0]
		debug_info += "First rect setup shapes count: %d\n" % first_rect_setup.shapes.size()
		if first_rect_setup.rect_shape:
			debug_info += "First rect setup rect shape size: %s\n" % first_rect_setup.rect_shape.size
	
	# Check map details
	if gts.target_map:
		debug_info += "Map tile size: %s\n" % gts.target_map.tile_set.tile_size
		debug_info += "Map position: %s\n" % gts.target_map.position
		debug_info += "Map global position: %s\n" % gts.target_map.global_position
		
		# Check tile coordinates
		var body_tile = gts.target_map.local_to_map(gts.target_map.to_local(body.global_position))
		debug_info += "Body tile coordinates: %s\n" % body_tile
	
	debug_info += "Position rules map size: %d\n" % position_rules_map.size()
	debug_info += "================================\n"

	# Debug: Verify the result structure
	assert_that(typeof(position_rules_map)).is_equal(TYPE_DICTIONARY).append_failure_message("Position rules map should be a Dictionary")

	# Debug: Check mapper setup state for position-rules mapping
	var guard_complete = mapper._guard_setup_complete()
	assert_that(guard_complete).append_failure_message("Mapper guard setup must be complete for position-rules mapping").is_true()
	
	if not guard_complete:
		assert_that(mapper.test_indicator).append_failure_message("Test indicator must not be null when guard setup is incomplete").is_not_null()
		assert_that(mapper.collision_object_test_setups).append_failure_message("Collision setups must not be null when guard setup is incomplete").is_not_null()
		assert_that(mapper.collision_object_test_setups.is_empty()).append_failure_message("Collision setups must not be empty when guard setup is incomplete").is_false()

	# Concise failure message with debug info
	var failure_msg = "Expected position-rules mapping for layer %d & mask %d, but got empty result. Guard complete: %s, Map size: %d\n%s" % [
		body.collision_layer, rule.apply_to_objects_mask, guard_complete, position_rules_map.size(), debug_info
	]

	assert_that(position_rules_map.size()).append_failure_message(failure_msg).is_greater(0)
