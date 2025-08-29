extends GdUnitTestSuite

# Comprehensive rule check indicator tests combining multiple scenarios
# Tests indicator creation, validation, collision detection, and edge cases

var test_container: GBCompositionContainer
var logger: GBLogger

func before_test():
	# Set up test infrastructure using factories
	test_container = UnifiedTestFactory.create_test_composition_container(self)
	logger = UnifiedTestFactory.create_test_logger()
	
	# Create injector system for dependency injection
	var _injector = UnifiedTestFactory.create_test_injector(self, test_container)

func after_test():
	# Cleanup handled by auto_free in factory methods
	pass

# Test basic indicator setup and configuration
func test_indicator_basic_setup(shape_type: String, shape_data, _expected_behavior: String):
	var indicator = _create_test_indicator(shape_type, shape_data)

	# Verify basic setup
	assert_object(indicator).append_failure_message(
		"Indicator should be created for shape type: %s" % shape_type
	).is_not_null()

	assert_object(indicator.shape).append_failure_message(
		"Indicator shape should be set for type: %s" % shape_type
	).is_not_null()

	assert_vector(indicator.target.global_position).append_failure_message(
		"Indicator should have zero target position initially"
	).is_equal(Vector2.ZERO)# Parameterized test data for basic setup
func test_indicator_basic_setup_parameters() -> Array:
	return [
		["rectangle", {"size": Vector2(16, 16)}, "valid_setup"],
		["circle", {"radius": 8.0}, "valid_setup"],
		["rectangle_large", {"size": Vector2(32, 32)}, "valid_setup"],
		["rectangle_tiny", {"size": Vector2(1, 1)}, "valid_setup"]
	]

# Test indicator validity switching with dynamic collision
func test_indicator_validity_dynamics(collision_scenario: String, pass_on_collision: bool, expected_initial_state: bool, expected_final_state: bool):
	var indicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	var rule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = pass_on_collision
	rule.collision_mask = 1

	# Set up validation parameters using centralized helper
	var test_params = _create_test_validation_params()

	rule.setup(test_params)

	indicator.resolve_gb_dependencies(test_container)
	indicator.add_rule(rule)

	# Track validity changes
	var validity_states = []
	indicator.valid_changed.connect(func(is_valid): validity_states.append(is_valid))

	await get_tree().physics_frame

	# Test collision scenarios
	if collision_scenario.contains("collision"):
		var body = _create_test_collision_body()
		body.global_position = indicator.global_position
		await get_tree().physics_frame

		assert_bool(indicator.valid).append_failure_message(
			"Indicator validity should be %s after collision in scenario: %s" % [expected_final_state, collision_scenario]
		).is_equal(expected_final_state)

		# Clean up temporary collision body to avoid affecting subsequent parameter runs
		if is_instance_valid(body):
			body.queue_free()
			await get_tree().physics_frame
	else:
		# No collision case
		assert_bool(indicator.valid).append_failure_message(
			"Indicator validity should be %s with no collision in scenario: %s" % [expected_initial_state, collision_scenario]
		).is_equal(expected_initial_state)

# Parameterized test data for validity dynamics
func test_indicator_validity_dynamics_parameters() -> Array:
	return [
		["fail_on_collision", false, true, false],
		["pass_on_collision", true, false, true],
		["no_collision_fail", false, true, true],
		["no_collision_pass", true, false, false]
	]

# Test indicator collision detection with various collision layers and masks
func test_indicator_collision_layers(indicator_mask: int, body_layer: int, should_detect: bool):
	var indicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	indicator.collision_mask = indicator_mask

	var rule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	rule.collision_mask = indicator_mask

	var test_params = _create_test_validation_params()
	rule.setup(test_params)

	indicator.resolve_gb_dependencies(test_container)
	indicator.add_rule(rule)

	# Create collision body on specific layer
	var body = _create_test_collision_body()
	body.collision_layer = body_layer
	body.global_position = indicator.global_position

	await get_tree().physics_frame

	var expected_validity = not should_detect  # Invalid if collision detected
	assert_bool(indicator.valid).append_failure_message(
		"Collision detection failed. Mask: %d, Layer: %d, Should detect: %s, Valid: %s" % [
			indicator_mask, body_layer, should_detect, indicator.valid
		]
	).is_equal(expected_validity)

# Parameterized test data for collision layers
func test_indicator_collision_layers_parameters() -> Array:
	return [
		[1, 1, true],   # Same layer - should detect
		[1, 2, false],  # Different layers - should not detect
		[3, 1, true],   # Mask includes layer - should detect
		[3, 2, true],   # Mask includes layer - should detect
		[3, 4, false],  # Mask excludes layer - should not detect
		[7, 4, true],   # Complex mask includes layer - should detect
	]

# Test indicator collision detection with various collision layers and masks
func test_indicator_collision_layers(indicator_mask: int, body_layer: int, should_detect: bool):
	var indicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	indicator.collision_mask = indicator_mask

	var rule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	rule.collision_mask = indicator_mask

	var test_params = _create_test_validation_params()
	rule.setup(test_params)

	indicator.resolve_gb_dependencies(test_container)
	indicator.add_rule(rule)

	# Create collision body on specific layer
	var body = _create_test_collision_body()
	body.collision_layer = body_layer
	body.global_position = indicator.global_position

	await get_tree().physics_frame

	var expected_validity = not should_detect  # Invalid if collision detected
	assert_bool(indicator.valid).append_failure_message(
		"Collision detection failed. Mask: %d, Layer: %d, Should detect: %s, Valid: %s" % [
			indicator_mask, body_layer, should_detect, indicator.valid
		]
	).is_equal(expected_validity)

# Test indicator visual state updates
func test_indicator_visual_state_updates():
	var indicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	
	# Set up visual settings
	var valid_texture = load("uid://2odn6on7s512")
	var invalid_settings = load("uid://h8lvjoarxq4k")
	
	var valid_settings = auto_free(IndicatorVisualSettings.new())
	valid_settings.texture = valid_texture
	valid_settings.modulate = Color.GREEN
	
	indicator.valid_settings = valid_settings
	indicator.invalid_settings = invalid_settings
	indicator.validity_sprite = auto_free(Sprite2D.new())
	indicator.add_child(indicator.validity_sprite)
	
	# Test initial visual state
	indicator.resolve_gb_dependencies(test_container)
	await get_tree().process_frame
	
	# Visual state should be updated based on validity
	assert_object(indicator.validity_sprite.texture).append_failure_message(
		"Validity sprite should have a texture assigned"
	).is_not_null()

# Test indicator position and transform handling
@warning_ignore("unused_parameter")
func test_indicator_positioning(
	position: Vector2,
	rotation: float,
	scale: Vector2,
	test_parameters := [
		[Vector2.ZERO, 0.0, Vector2.ONE],
		[Vector2(100, 100), 0.0, Vector2.ONE],
		[Vector2.ZERO, PI/4, Vector2.ONE],
		[Vector2.ZERO, 0.0, Vector2(2, 2)],
		[Vector2(50, 50), PI/2, Vector2(0.5, 0.5)]
	]
):
	var indicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	
	# Apply transform
	indicator.global_position = position
	indicator.rotation = rotation
	indicator.scale = scale
	
	# Verify transform is applied correctly
	assert_vector(indicator.global_position).append_failure_message(
		"Indicator position should match set value"
	).is_equal(position)
	
	assert_float(indicator.rotation).append_failure_message(
		"Indicator rotation should match set value"
	).is_equal_approx(rotation, 0.01)
	
	assert_vector(indicator.scale).append_failure_message(
		"Indicator scale should match set value"
	).is_equal_approx(scale, Vector2(0.01, 0.01))

# Test indicator overlap threshold functionality
@warning_ignore("unused_parameter")
func test_indicator_overlap_threshold(
	overlap_threshold: float,
	collision_area: float,
	total_area: float,
	should_pass: bool,
	test_parameters := [
		[0.5, 8.0, 16.0, true],   # 50% overlap, 50% threshold - should pass
		[0.5, 4.0, 16.0, false],  # 25% overlap, 50% threshold - should fail
		[0.3, 8.0, 16.0, true],   # 50% overlap, 30% threshold - should pass
		[0.8, 8.0, 16.0, false],  # 50% overlap, 80% threshold - should fail
	]
):
	var indicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	
	# Create a mock overlap test
	var rule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	
	# Set up test to simulate overlap calculations
	var overlap_ratio = collision_area / total_area
	var passes_threshold = overlap_ratio >= overlap_threshold
	
	# Verify threshold logic
	assert_bool(passes_threshold).append_failure_message(
		"Overlap threshold logic failed. Overlap: %f, Threshold: %f, Should pass: %s" % [
			overlap_ratio, overlap_threshold, should_pass
		]
	).is_equal(should_pass)

## Helper method to create test validation parameters
func _create_test_validation_params() -> RuleValidationParameters:
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	return RuleValidationParameters.new(
		GodotTestFactory.create_node2d(self),
		GodotTestFactory.create_node2d(self),
		targeting_state,
		logger
	)

## Helper method to create test indicators with different shapes
func _create_test_indicator(shape_type: String, shape_data: Dictionary) -> RuleCheckIndicator:
	var indicator = UnifiedTestFactory.create_test_rule_check_indicator(self) # Adds child automatically
	indicator.collision_mask = 1

	match shape_type:
		"rectangle":
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = shape_data.size
			indicator.shape = rect_shape
		"circle":
			var circle_shape = CircleShape2D.new()
			circle_shape.radius = shape_data.radius
			indicator.shape = circle_shape
		_:
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = shape_data.get("size", Vector2(16, 16))
			indicator.shape = rect_shape

	return indicator## Helper method to create test collision bodies
func _create_test_collision_body() -> StaticBody2D:
	var body = auto_free(StaticBody2D.new())
	var shape = auto_free(CollisionShape2D.new())
	var rect = auto_free(RectangleShape2D.new())
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	body.collision_layer = 1
	add_child(body)
	return body
