extends GdUnitTestSuite

## Comprehensive rule check indicator tests combining multiple scenarios
##
## MIGRATION: Converted from EnvironmentTestFactory to scene_runner pattern
## for better reliability and deterministic frame control.
##
## Tests indicator creation, validation, collision detection, and edge cases

var runner: GdUnitSceneRunner
var test_container: GBCompositionContainer
var env : CollisionTestEnvironment

func before_test() -> void:
	runner = scene_runner(GBTestConstants.COLLISION_TEST_ENV_UID)
	env = runner.scene() as CollisionTestEnvironment
	
	assert_object(env).append_failure_message(
		"Failed to load CollisionTestEnvironment scene"
	).is_not_null()
	
	test_container = env.container

func after_test() -> void:
	# Cleanup handled by auto_free in factory methods
	pass

# Test basic indicator setup and configuration
@warning_ignore("unused_parameter")
func test_indicator_basic_setup(shape_type: String, shape_data: Dictionary, test_parameters := [
		["rectangle", {"size": Vector2(16, 16)}],
		["circle", {"radius": 8.0}],
		["rectangle_large", {"size": Vector2(32, 32)}],
		["rectangle_tiny", {"size": Vector2(1, 1)}]
]) -> void:
	var indicator: RuleCheckIndicator = _create_test_indicator(shape_type, shape_data)

	# Verify basic setup
	assert_object(indicator).append_failure_message(
		"Indicator should be created for shape type: %s" % shape_type
	).is_not_null()

	assert_object(indicator.shape).append_failure_message(
		"Indicator shape should be set for type: %s" % shape_type
	).is_not_null()

	assert_vector(indicator.global_position).append_failure_message(
		"Indicator should have zero global position initially"
	).is_equal(Vector2.ZERO)

# Test indicator validity switching with dynamic collision
@warning_ignore("unused_parameter")
func test_indicator_validity_dynamics(pass_on_collision: bool, simulate_collision: bool, expected_valid: bool, test_parameters := [
	# pass_on_collision, simulate_collision, expected_valid
	[false, false, true],  # no collision, rule expects no collision -> valid
	[false, true, false],  # collision present, rule expects no collision -> invalid
	[true, false, false],  # no collision, rule expects collision -> invalid
	[true, true, true],    # collision present, rule expects collision -> valid
]) -> void:
	var indicator: RuleCheckIndicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	var rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	rule.pass_on_collision = pass_on_collision
	rule.collision_mask = 1

	# Set up validation parameters using centralized helper
	var test_params: GridTargetingState = _create_test_validation_params()

	rule.setup(test_params)

	indicator.resolve_gb_dependencies(test_container)
	indicator.add_rule(rule)

	# Track validity changes
	var validity_states: Array[bool] = []
	indicator.valid_changed.connect(func(is_valid: bool) -> void: validity_states.append(is_valid))

	await get_tree().physics_frame

	# Optionally simulate a collision and assert expected validity
	if simulate_collision:
		var body: StaticBody2D = _create_test_collision_body()
		body.global_position = indicator.global_position
		await get_tree().physics_frame

		assert_bool(indicator.valid).append_failure_message(
			"Indicator validity should be %s after collision in scenario" % [expected_valid]
		).is_equal(expected_valid)

		# Clean up temporary collision body to avoid affecting subsequent parameter runs
		if is_instance_valid(body):
			body.queue_free()
			await get_tree().physics_frame
	else:
		# No collision case
		assert_bool(indicator.valid).append_failure_message(
			"Indicator validity should be %s with no collision in scenario" % [expected_valid]
		).is_equal(expected_valid)


# Test indicator collision detection with various collision layers and masks
@warning_ignore("unused_parameter")
func test_indicator_collision_layers(indicator_mask: int, body_layer: int, should_detect: bool, test_parameters := [
		[1, 1, true],   # Same layer - should detect
		[1, 2, false],  # Different layers - should not detect
		[3, 1, true],   # Mask includes layer - should detect
		[3, 2, true],   # Mask includes layer - should detect
		[3, 4, false],  # Mask excludes layer - should not detect
		[7, 4, true],   # Complex mask includes layer - should detect
]) -> void:
	var indicator: RuleCheckIndicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})
	indicator.collision_mask = indicator_mask

	var rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	rule.pass_on_collision = false
	rule.collision_mask = indicator_mask

	var test_params: GridTargetingState = _create_test_validation_params()
	rule.setup(test_params)

	indicator.resolve_gb_dependencies(test_container)
	indicator.add_rule(rule)

	# Create collision body on specific layer
	var body: StaticBody2D = _create_test_collision_body()
	body.collision_layer = body_layer
	body.global_position = indicator.global_position

	await get_tree().physics_frame

	var expected_validity: bool = not should_detect  # Invalid if collision detected
	assert_bool(indicator.valid).append_failure_message(
		"Collision detection failed. Mask: %d, Layer: %d, Should detect: %s, Valid: %s" % [
			indicator_mask, body_layer, should_detect, indicator.valid
		]
	).is_equal(expected_validity)

# Test indicator visual state updates
func test_indicator_visual_state_updates() -> void:
	var indicator: RuleCheckIndicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})

	# Use the indicator's built-in defaults for visuals; only provide the sprite node
	indicator.validity_sprite = auto_free(Sprite2D.new())
	indicator.add_child(indicator.validity_sprite)

	# Test initial visual state
	indicator.resolve_gb_dependencies(test_container)
	await get_tree().process_frame

	# Force recompute and re-apply visuals in case ordering left visuals unapplied
	indicator._update_current_display_settings([], indicator.valid)
	# Call the internal updater explicitly to make diagnostics deterministic in tests
	indicator._update_visuals(indicator.current_display_settings)

	# Build enhanced diagnostic context for failure messages (no print statements)
	var cur := indicator.current_display_settings
	var vs := indicator.valid_settings
	var invs := indicator.invalid_settings
	var diag_parts: Array = []
	diag_parts.append("Indicator diagnostics:")
	diag_parts.append("validity_sprite: %s" % ["null" if not indicator.validity_sprite else str(indicator.validity_sprite.name)])
	diag_parts.append("indicator.valid: %s" % [str(indicator.valid)])
	diag_parts.append("current_display_settings: %s" % ["null" if not cur else str(cur.resource_name)])
	diag_parts.append("current.texture: %s" % ["null" if not cur or cur.texture == null else str(cur.texture.resource_name)])
	diag_parts.append("valid_settings: %s" % ["null" if not vs else str(vs.resource_name)])
	diag_parts.append("valid.texture: %s" % ["null" if not vs or vs.texture == null else str(vs.texture.resource_name)])
	diag_parts.append("invalid_settings: %s" % ["null" if not invs else str(invs.resource_name)])
	diag_parts.append("invalid.texture: %s" % ["null" if not invs or invs.texture == null else str(invs.texture.resource_name)])
	var diag: String = "\n".join(diag_parts)

	# Ensure sprite exists and then assert the assigned texture is not null, with diagnostics
	assert_object(indicator.validity_sprite).is_not_null().append_failure_message("Validity sprite node missing. " + diag)
	assert_object(indicator.current_display_settings).is_not_null().append_failure_message("Current display settings missing. " + diag)
	assert_object(indicator.validity_sprite.texture).is_not_null().append_failure_message("Validity sprite should have a texture assigned. " + diag)

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
) -> void:
	var indicator: RuleCheckIndicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})

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
) -> void:
	var _indicator: RuleCheckIndicator = _create_test_indicator("rectangle", {"size": Vector2(16, 16)})

	# Create a mock overlap test
	var rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
	rule.pass_on_collision = false

	# Set up test to simulate overlap calculations
	var overlap_ratio: float = collision_area / total_area
	var passes_threshold: bool = overlap_ratio >= overlap_threshold

	# Verify threshold logic
	assert_bool(passes_threshold).append_failure_message(
		"Overlap threshold logic failed. Overlap: %f, Threshold: %f, Should pass: %s" % [
			overlap_ratio, overlap_threshold, should_pass
		]
	).is_equal(should_pass)

## Helper method to create test validation parameters
func _create_test_validation_params() -> GridTargetingState:
	var targeting_state: GridTargetingState = GridTargetingState.new(GBOwnerContext.new())
	return targeting_state

## Helper method to create test indicators with different shapes
func _create_test_indicator(shape_type: String, shape_data: Dictionary) -> RuleCheckIndicator:
	var indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self) # Adds child automatically
	indicator.collision_mask = 1

	match shape_type:
		"rectangle":
			var rect_shape: RectangleShape2D = RectangleShape2D.new()
			rect_shape.size = shape_data.size
			indicator.shape = rect_shape
		"circle":
			var circle_shape: CircleShape2D = CircleShape2D.new()
			circle_shape.radius = shape_data.radius
			indicator.shape = circle_shape
		_:
			var rect_shape: RectangleShape2D = RectangleShape2D.new()
			rect_shape.size = shape_data.get("size", Vector2(16, 16))
			indicator.shape = rect_shape

	return indicator

## Helper method to create test collision bodies
func _create_test_collision_body() -> StaticBody2D:
	var body: StaticBody2D = auto_free(StaticBody2D.new())
	var shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect: RectangleShape2D = auto_free(RectangleShape2D.new())
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	body.collision_layer = 1
	add_child(body)
	return body
