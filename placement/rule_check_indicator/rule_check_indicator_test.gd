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
	# Create indicator and configure all exported properties BEFORE adding to scene tree so _ready uses them.
	indicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	indicator.collision_mask = test_layers
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(15.9, 15.9)

	# Visual resources
	var valid_sprite_tex: Texture2D = load("uid://2odn6on7s512")
	var invalid_settings_res: IndicatorVisualSettings = load("uid://h8lvjoarxq4k")

	# Valid settings instance
	var valid_settings_res: IndicatorVisualSettings = auto_free(IndicatorVisualSettings.new())
	valid_settings_res.texture = valid_sprite_tex
	valid_settings_res.modulate = Color.GREEN

	indicator.valid_settings = valid_settings_res
	indicator.invalid_settings = invalid_settings_res

	# Assign validity sprite and add as child of indicator (not test) so local positioning works
	indicator.validity_sprite = auto_free(Sprite2D.new())
	indicator.add_child(indicator.validity_sprite)

	# Now add indicator to test scene once fully configured
	if indicator.get_parent() == null:
		add_child(indicator)


func test_setup_indicator_defaults():
		assert_object(indicator).append_failure_message("[indicator] must not be null").is_not_null()
		assert_vector(indicator.target_position).is_equal(Vector2.ZERO)

## Integration test: indicator switches valid → fail → valid as collision body is added/removed
func test_indicator_validity_switches_on_dynamic_collision():
	var logger := create_test_logger()
	var rule := UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	rule.collision_mask = 1
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, logger)
	rule.setup(test_params)

	var test_indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	test_indicator.shape = RectangleShape2D.new(); test_indicator.shape.size = Vector2(16,16)
	test_indicator.resolve_gb_dependencies(TEST_CONTAINER)
	test_indicator.add_rule(rule)

	var signal_states := []
	test_indicator.valid_changed.connect(func(is_valid): signal_states.append(is_valid))

	await get_tree().physics_frame
	assert_bool(test_indicator.valid).append_failure_message("Indicator should start valid, but was invalid. signal_states=%s" % [str(signal_states)]).is_true()
	# Implementation may or may not emit initial valid signal. Accept either [] or [true]
	if signal_states.size() > 0:
		assert_array(signal_states).append_failure_message("Unexpected initial signal sequence: %s" % [str(signal_states)]).is_equal([true])

	# Add a colliding body to trigger failure
	var body := _create_test_body(); 
	add_child(body)
	body.global_position = test_indicator.global_position
	await get_tree().physics_frame
	assert_bool(test_indicator.valid).append_failure_message("Indicator should be invalid after collision, but was valid. signal_states=%s" % [str(signal_states)]).is_false()
	# After collision we expect last emission to be false
	assert_bool(signal_states.back()).append_failure_message("Signal states after collision: %s" % [str(signal_states)]).is_false()

	# Remove the body to restore validity
	body.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(test_indicator.valid).append_failure_message("Indicator should be valid after body removal, but was invalid. signal_states=%s" % [str(signal_states)]).is_true()
	assert_bool(signal_states.back()).append_failure_message("Signal states after body removal: %s" % [str(signal_states)]).is_true()

## Test: validity_sprite texture changes when indicator validity changes
func test_validity_sprite_texture_switches_on_validity_change():
	var logger2 := create_test_logger()
	var rule2 := UnifiedTestFactory.create_test_collisions_check_rule()
	rule2.pass_on_collision = false
	rule2.collision_mask = 1
	var targeting_state2 = GridTargetingState.new(GBOwnerContext.new())
	var test_params2 = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state2, logger2)
	rule2.setup(test_params2)

	var indicator2: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	indicator2.shape = RectangleShape2D.new(); indicator2.shape.size = Vector2(16,16)
	indicator2.collision_mask = test_layers
	# Setup visual resources mirroring before_test
	var valid_sprite_tex2: Texture2D = load("uid://2odn6on7s512")
	var invalid_settings_res2: IndicatorVisualSettings = load("uid://h8lvjoarxq4k")
	var valid_settings_res2: IndicatorVisualSettings = auto_free(IndicatorVisualSettings.new())
	valid_settings_res2.texture = valid_sprite_tex2
	valid_settings_res2.modulate = Color.GREEN
	indicator2.valid_settings = valid_settings_res2
	indicator2.invalid_settings = invalid_settings_res2
	indicator2.validity_sprite = auto_free(Sprite2D.new())
	indicator2.add_child(indicator2.validity_sprite)
	indicator2.resolve_gb_dependencies(TEST_CONTAINER)
	indicator2.add_rule(rule2)

	await get_tree().physics_frame
	var sprite2 := indicator2.validity_sprite
	assert_object(sprite2).append_failure_message("Indicator validity_sprite is null").is_not_null()
	var valid_texture2 = indicator2.valid_settings.texture
	var invalid_texture2 = indicator2.invalid_settings.texture
	assert_bool(valid_texture2 != invalid_texture2).append_failure_message("Valid and invalid textures should differ").is_true()
	assert_object(sprite2.texture).append_failure_message("Sprite texture should be valid texture after initial frame").is_equal(valid_texture2)

	# Add a colliding body to trigger failure
	var body2 := _create_test_body(); add_child(body2)
	body2.global_position = indicator2.global_position
	await get_tree().physics_frame
	assert_bool(indicator2.valid).append_failure_message("Indicator should be invalid after collision").is_false()
	assert_object(sprite2.texture).append_failure_message("Sprite texture should be invalid texture after collision").is_equal(invalid_texture2)

	# Remove the body to restore validity
	body2.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(indicator2.valid).append_failure_message("Indicator should be valid after body removal").is_true()
	assert_object(sprite2.texture).append_failure_message("Sprite texture should be valid texture after body removal").is_equal(valid_texture2)

## Test that indicators start in valid state when no rules are present
func test_indicator_starts_valid_with_no_rules():
	assert_bool(indicator.valid).is_true()
	# Allow deferred post-ready visual application to run
	await get_tree().physics_frame
	assert_object(indicator.current_display_settings).is_equal(indicator.valid_settings)


## Parameterized: pass/fail scenarios reduce setup duplication
## Each parameter: [rules:Array[Dictionary], bodies:Array[int], expected_valid:bool]
## rule spec: { "pass_on_collision": bool, "mask": int }
@warning_ignore("unused_parameter")
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
@warning_ignore("unused_parameter")
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
	# Verify initial state (allow deferred visuals to apply)
	await get_tree().physics_frame
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
@warning_ignore("unused_parameter")
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

## Test improved debug log format when no rules present at _ready
func test_ready_debug_log_format_no_rules():
	# Simulate logger with debug enabled
	var logger := create_test_logger()
	var dbg := logger.get_debug_settings()
	dbg.level = GBDebugSettings.DebugLevel.DEBUG
	var test_indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	test_indicator.shape = RectangleShape2D.new(); test_indicator.shape.size = Vector2(8,8)
	test_indicator.resolve_gb_dependencies(TEST_CONTAINER)
	await get_tree().process_frame
	# We can't intercept internal logger messages without a spy; assert valid state and zero rules
	assert_int(test_indicator.get_rules().size()).is_equal(0)
	assert_bool(test_indicator.valid).is_true()

## Test per-frame evaluation toggled by environment variable
func test_per_frame_validation_env_flag():
	OS.set_environment("GB_INDICATOR_EVAL_EACH_FRAME", "1")
	var rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	rule.collision_mask = 1
	var targeting_state = GridTargetingState.new(GBOwnerContext.new())
	var test_params = RuleValidationParameters.new(GodotTestFactory.create_node2d(self), GodotTestFactory.create_node2d(self), targeting_state, create_test_logger())
	rule.setup(test_params)
	var body: StaticBody2D = _create_test_body(); add_child(body); body.global_position = indicator.global_position
	indicator.add_rule(rule)
	await get_tree().physics_frame
	var first_state = indicator.valid
	# Remove body then ensure per-frame revalidation flips state back to valid automatically
	body.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(first_state).is_false()
	assert_bool(indicator.valid).is_true()
	OS.set_environment("GB_INDICATOR_EVAL_EACH_FRAME", "0")


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
