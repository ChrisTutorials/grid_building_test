extends GdUnitTestSuite

var indicator: RuleCheckIndicator
var test_layers = 1  # Bitmask

## Logo offset away from the center for testing
var offset_logo = load("uid://bqq7otaevtlqu")

## Test container for dependency injection
const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

## Helper method to create a test logger
func create_test_logger() -> GBLogger:
	return GBLogger.create_with_injection(TEST_CONTAINER)


func before_test():
	indicator = auto_free(RuleCheckIndicator.new())
	indicator.collision_mask = test_layers
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(15.9, 15.9)
	
	# Set up visual components BEFORE adding to scene tree
	indicator.validity_sprite = auto_free(Sprite2D.new())
	indicator.invalid_settings = load("uid://h8lvjoarxq4k")
	
	# Set up valid settings
	indicator.valid_settings = auto_free(IndicatorVisualSettings.new())
	indicator.valid_settings.texture = load("uid://2odn6on7s512")  # Green tile texture
	indicator.valid_settings.modulate = Color.GREEN
	
	# Now add to scene tree after all properties are set
	add_child(indicator)


func test_setup_indicator_defaults():
	assert_object(indicator).append_failure_message("[indicator] must not be null").is_not_null()
	assert_vector(indicator.target_position).is_equal(Vector2.ZERO)


## Test that indicators start in valid state when no rules are present
func test_indicator_starts_valid_with_no_rules():
	assert_bool(indicator.valid).is_true()
	assert_object(indicator.current_display_settings).is_equal(indicator.valid_settings)


## Parameterized: pass/fail scenarios reduce setup duplication
## Each parameter: [rules:Array[Dictionary], bodies:Array[int], expected_valid:bool]
## rule spec: { "pass_on_collision": bool, "mask": int }
func test_indicator_validity_scenarios(
	rules: Array,
	bodies: Array,
	expected_valid: bool,
	test_parameters := [
		[
			[{"pass_on_collision": false, "mask": 1}], # one failing rule on layer 1
			[1],                                        # one body on layer 1
			false                                       # expected invalid
		],
		[
			[{"pass_on_collision": true, "mask": 1}],  # one passing rule on layer 1
			[1],                                        # one body on layer 1
			true                                        # expected valid
		],
		[
			[                                          # multiple rules: one pass, one fail
				{"pass_on_collision": true, "mask": 1},
				{"pass_on_collision": false, "mask": 2}
			],
			[1, 2],                                     # bodies on layers 1 and 2
			false                                       # expected invalid
		]
	]
):
	# Create and position collision bodies
	for layer in bodies:
		var body := _create_test_body()
		body.collision_layer = layer
		add_child(body)
		body.global_position = indicator.global_position

	# Create, setup, and add rules to indicator
	for r in rules:
		var rule = UnifiedTestFactory.create_test_collisions_check_rule()
		rule.pass_on_collision = r["pass_on_collision"]
		rule.collision_mask = int(r["mask"])
		var targeting_state = GridTargetingState.new(GBOwnerContext.new())
		var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
		rule.setup(test_params)
		indicator.add_rule(rule)

	# Allow physics to process
	await get_tree().physics_frame

	# Validate expected state and visuals
	assert_bool(indicator.valid).is_equal(expected_valid)
	if expected_valid:
		assert_object(indicator.current_display_settings).is_equal(indicator.valid_settings)
	else:
		assert_object(indicator.current_display_settings).is_equal(indicator.invalid_settings)


## Test that the valid_changed signal is emitted when validity state changes
func test_valid_changed_signal_emitted_on_state_change(
	rule_spec: Dictionary,
	expected_value: bool,
	test_parameters := [[{"pass_on_collision": false, "mask": 1}, false]]
):
	var signal_data = [false, false]
	var rule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = rule_spec["pass_on_collision"]
	rule.collision_mask = int(rule_spec["mask"])
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
	rule.setup(test_params)

	var collision_body = _create_test_body()
	add_child(collision_body)
	collision_body.global_position = indicator.global_position

	var signal_handler = func(is_valid: bool):
		signal_data[0] = true
		signal_data[1] = is_valid
	indicator.valid_changed.connect(signal_handler)

	indicator.add_rule(rule)
	await get_tree().physics_frame
	assert_bool(signal_data[0]).is_true()
	assert_bool(signal_data[1]).is_equal(expected_value)
	indicator.valid_changed.disconnect(signal_handler)


## Test that visual settings are properly updated when validity changes
func test_visual_settings_update_on_validity_change():
	# Verify initial state
	assert_object(indicator.current_display_settings).is_equal(indicator.valid_settings)
	assert_object(indicator.validity_sprite.texture).is_equal(indicator.valid_settings.texture)
	assert_that(indicator.validity_sprite.modulate).is_equal(indicator.valid_settings.modulate)
	
	# Create a failing rule to trigger visual change
	var failing_rule = UnifiedTestFactory.create_test_collisions_check_rule()
	failing_rule.pass_on_collision = false
	failing_rule.collision_mask = 1
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
	failing_rule.setup(test_params)
	
	var collision_body = _create_test_body()
	add_child(collision_body)
	
	# Position the collision body to overlap with the indicator
	collision_body.global_position = indicator.global_position
	
	# Add the rule to trigger visual change
	indicator.add_rule(failing_rule)
	
	# Wait for physics process to run
	await get_tree().physics_frame
	
	# Verify visual settings changed to invalid
	assert_object(indicator.current_display_settings).is_equal(indicator.invalid_settings)
	assert_object(indicator.validity_sprite.texture).is_equal(indicator.invalid_settings.texture)
	assert_that(indicator.validity_sprite.modulate).is_equal(indicator.invalid_settings.modulate)


## Test that force_validation_update properly updates the indicator state
func test_force_validation_update(
	rule_spec: Dictionary,
	expected_valid: bool,
	test_parameters := [[{"pass_on_collision": false, "mask": 1}, false]]
):
	var rule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = rule_spec["pass_on_collision"]
	rule.collision_mask = int(rule_spec["mask"])
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
	rule.setup(test_params)

	var collision_body = _create_test_body()
	add_child(collision_body)
	collision_body.global_position = indicator.global_position

	indicator.add_rule(rule)
	indicator.force_validation_update()
	assert_bool(indicator.valid).is_equal(expected_valid)
	if expected_valid:
		assert_object(indicator.current_display_settings).is_equal(indicator.valid_settings)
	else:
		assert_object(indicator.current_display_settings).is_equal(indicator.invalid_settings)


## Test that indicators properly handle rules being added after _ready
func test_rules_added_after_ready():
	# Wait for _ready to complete
	await get_tree().physics_frame
	
	# Verify initial state
	assert_bool(indicator.valid).is_true()
	
	# Create and add a failing rule after _ready
	var failing_rule = UnifiedTestFactory.create_test_collisions_check_rule()
	failing_rule.pass_on_collision = false
	failing_rule.collision_mask = 1
	
	# Initialize the rule properly for testing
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
	failing_rule.setup(test_params)
	
	var collision_body = _create_test_body()
	add_child(collision_body)
	
	# Position the collision body to overlap with the indicator
	collision_body.global_position = indicator.global_position
	
	# Add the rule
	indicator.add_rule(failing_rule)
	
	# Wait for physics process to run
	await get_tree().physics_frame
	
	# Verify the indicator is now invalid
	assert_bool(indicator.valid).is_false()
	assert_object(indicator.current_display_settings).is_equal(indicator.invalid_settings)

## Test that indicators properly handle rules being removed
func test_rules_removed():
	# Create a failing rule
	var failing_rule = UnifiedTestFactory.create_test_collisions_check_rule()
	failing_rule.pass_on_collision = false
	failing_rule.collision_mask = 1
	
	# Initialize the rule properly for testing
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
	failing_rule.setup(test_params)
	
	var collision_body = _create_test_body()
	add_child(collision_body)
	
	# Position the collision body to overlap with the indicator
	collision_body.global_position = indicator.global_position
	
	# Add the rule
	indicator.add_rule(failing_rule)
	
	# Wait for physics process to run
	await get_tree().physics_frame
	
	# Verify the indicator is invalid (provide detailed diagnostics)
	var prior_rules_count := indicator.get_rules().size()
	assert_bool(indicator.valid).append_failure_message("Indicator unexpectedly valid before rule removal; rules=%d collisions=%d" % [prior_rules_count, indicator.get_collision_count()]).is_false()
	
	# Remove the rule
	indicator.clear()
	
	# Wait for physics process to run
	await get_tree().physics_frame
	
	# Verify the indicator is now valid again
	assert_bool(indicator.valid).append_failure_message("Indicator did not become valid after clear(); remaining_rules=%d" % [indicator.get_rules().size()]).is_true()
	assert_object(indicator.current_display_settings).append_failure_message("Display settings not reverted to valid after clear()").is_equal(indicator.valid_settings)


## Testing move distance for an indicator compared to where it will still have collisions with it's shape at the starting position or not
@warning_ignore("unused_parameter")


func test_indicator_collide_and_get_contacts(
	p_move_shape_size_multiplier: Vector2,
	p_expected_empty: bool,
	test_parameters := [
		[Vector2(0, 0), false],
		[Vector2(0, -1), false],
		[Vector2(0, -2), true],
		[Vector2(1, 0), false],
		[Vector2(-2, 0), true]
	]
):
	#region Setup
	var body: StaticBody2D = _create_test_body()
	var shape: CollisionShape2D = body.get_child(0)
	var original_position = indicator.global_position
	var indicator_shape_size: Vector2 = indicator.shape.get_rect().size
	indicator.global_position = Vector2.ZERO
	body.global_position = Vector2.ZERO
	#endregion

	#region Execution
	indicator.position = original_position + (p_move_shape_size_multiplier * indicator_shape_size)
	var result: Array = indicator.shape.collide_and_get_contacts(
		indicator.global_transform, shape.shape, shape.global_transform
	)
	(
		assert_bool(result.is_empty())
		. append_failure_message("If false, is inside shape. If true, is outside.")
		. is_equal(p_expected_empty)
	)
	#endregion


@warning_ignore("unused_parameter")


## Count the number of collisions when instancing a p_test_scene at the origin 0,0 and seeing
## if it matches the expected number
func test_instance_collisions(
	p_test_scene: PackedScene, p_expected_collisions: int, test_parameters := [[offset_logo, 1]]
):
	var instance: PhysicsBody2D = auto_free(p_test_scene.instantiate())
	add_child(instance)
	indicator.collision_mask = instance.collision_layer
	indicator.force_shapecast_update()
	var collision_count: int = indicator.get_collision_count()
	assert_int(collision_count).is_equal(p_expected_collisions)


@warning_ignore("unused_parameter")


func test__update_visuals(
	p_settings: IndicatorVisualSettings, test_parameters := [[load("uid://dpph3i22e5qev")]]
) -> void:
	var updated_sprite = indicator._update_visuals(p_settings)
	assert_that(updated_sprite.modulate).is_equal(p_settings.modulate)


## Test the default return of get_tile_positon
func test_get_tile_position_default() -> void:
	var test_tile_map: TileMapLayer = auto_free(load("uid://3shi30ob8pna").instantiate())
	add_child(test_tile_map)
	var position := indicator.get_tile_position(test_tile_map)
	assert_vector(position).is_equal(Vector2i.ZERO)


## Creates a test collision body for testing rule validation
## 
## IMPORTANT POSITIONING NOTES:
## - The collision body is created at position (0, 0) by default
## - Tests MUST position the collision body to overlap with the indicator
## - Tests call: collision_body.global_position = indicator.global_position
## - This ensures the collision body and indicator are in the same location
## - Without proper positioning, collision detection will fail and tests will pass incorrectly
##
## Example usage in tests:
## ```gdscript
## var collision_body = _create_test_body()
## add_child(collision_body)
## collision_body.global_position = indicator.global_position  # CRITICAL: Position for collision
## ```
func _create_test_body() -> StaticBody2D:
	var collision_body = auto_free(StaticBody2D.new())
	collision_body.collision_layer = test_layers

	var collision_shape = auto_free(CollisionShape2D.new())
	collision_body.add_child(collision_shape)
	collision_shape.shape = RectangleShape2D.new()
	
	# IMPORTANT: The collision shape needs a size to actually collide
	# RectangleShape2D defaults to size (0, 0) which means no collision detection
	collision_shape.shape.size = Vector2(16, 16)  # Match the indicator size
	
	return collision_body
