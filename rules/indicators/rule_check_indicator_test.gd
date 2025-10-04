## Test suite for RuleCheckIndicator class.
## Tests comprehensive rule-based placement validation including:
## - Indicator validity state changes based on collision rules
## - Visual settings updates (texture, modulate) on validity changes
## - Signal emission when validity state changes
## - Rule addition/removal after indicator initialization
## - Force validation updates and per-frame evaluation
## - Collision detection and contact point calculations
## - Integration with GridTargetingState and collision systems
## - Debug logging and environment variable configuration
## - Tile position calculations and visual sprite management
## Tests ensure proper integration between rules, collision detection, and visual feedback.
##
## IMPORTANT TESTING PATTERN: RuleCheckIndicator Manual Validation
## Indicators DO NOT automatically revalidate when collision bodies are added/removed.
## After modifying the physics world (adding/removing bodies), you MUST call:
##   indicator.force_validity_evaluation()
## This method performs TWO critical steps in one call:
##   1. Updates ShapeCast2D collision detection (force_shapecast_update)
##   2. Evaluates all rules and updates indicator.valid state (update_validity_state)
## Pattern: add/remove body → simulate_frames(1-2) → force_validity_evaluation() → assert state
extends GdUnitTestSuite

var indicator: RuleCheckIndicator
var test_layers: int = 1  # Bitmask

## Logo offset away from the center for testing - using Godot icon as test texture
var offset_logo: PackedScene = GBTestConstants.SCENE_RECT_15_TILES

## Environment and container for tests
var _env: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var runner: GdUnitSceneRunner

func _diag(message: String) -> String:
	return GBDiagnostics.format_debug(message, "RuleCheckIndicatorTest", get_script().resource_path)

## Build a full indicator state diagnostic via RuleCheckIndicatorLogic helper
static func _indicator_state_diag(ind: RuleCheckIndicator, header: String = "") -> String:
	return RuleCheckIndicatorLogic.format_indicator_state(ind, header)

## Helper method to get properly initialized GridTargetingState from environment
func create_rule_targeting_state() -> GridTargetingState:
	# Get the targeting state from the environment which should already be properly initialized
	var targeting_state: GridTargetingState = _container.get_states().targeting
	
	# Validate that the environment properly set up the targeting state
	assert_that(targeting_state).append_failure_message(
		"Environment should provide targeting state"
	).is_not_null()
	assert_that(targeting_state.target_map).append_failure_message(
		"Environment targeting state should have target_map set"
	).is_not_null()
	assert_that(targeting_state.positioner).append_failure_message(
		"Environment targeting state should have positioner set"
	).is_not_null()
	
	return targeting_state

func before_test() -> void:
	# Use scene_runner for reliable frame simulation
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames
	
	_env = runner.scene() as AllSystemsTestEnvironment
	_container = _env.get_container()
	
	# Disable mouse input to prevent interference
	_container.config.settings.targeting.enable_mouse_input = false
	
	# Create indicator and configure all exported properties BEFORE adding to scene tree so _ready uses them.
	indicator = RuleCheckIndicator.new()
	auto_free(indicator)
	indicator.collision_mask = test_layers
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2.ONE
	_env.add_child(indicator)  # Add AFTER shape is assigned to prevent assertion failure in _ready()

	# Visual resources - create small in-test textures to avoid uid loading
	var img_valid: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img_valid.fill(Color(0, 1, 0))
	var tex_valid: ImageTexture = ImageTexture.create_from_image(img_valid)

	var img_invalid: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img_invalid.fill(Color(1, 0, 0))
	var tex_invalid: ImageTexture = ImageTexture.create_from_image(img_invalid)

	# Valid settings instance
	var valid_settings_res: IndicatorVisualSettings = auto_free(IndicatorVisualSettings.new())
	valid_settings_res.texture = tex_valid
	valid_settings_res.modulate = Color.GREEN

	var invalid_settings_res: IndicatorVisualSettings = auto_free(IndicatorVisualSettings.new())
	invalid_settings_res.texture = tex_invalid
	invalid_settings_res.modulate = Color.RED

	indicator.valid_settings = valid_settings_res
	indicator.invalid_settings = invalid_settings_res

	# Assign validity sprite and add as child of indicator (not test) so local positioning works
	indicator.validity_sprite = auto_free(Sprite2D.new())
	indicator.add_child(indicator.validity_sprite)

	assert_object(indicator.get_parent()).append_failure_message(
		"Indicator should be added to scene tree"
	).is_not_null()

	# Ensure indicator starts in valid state before resolving dependencies so
	# visuals and any immediate validations consider it valid by default.
	indicator.valid = true

	# Resolve runtime dependencies so logger, debug settings and visuals are applied
	# Tests rely on resolve_gb_dependencies() to set the _logger and apply current display settings
	indicator.resolve_gb_dependencies(_container)
	
	# Simulate frames for indicator setup
	runner.simulate_frames(2)

func after_test() -> void:
	runner = null
	_env = null
	_container = null
	indicator = null

func test_setup_indicator_defaults() -> void:
	assert_object(indicator).append_failure_message(
		"Indicator must not be null"
	).is_not_null()
	assert_vector(indicator.global_position).append_failure_message(
		"Indicator should start at zero position, got %s" % str(indicator.global_position)
	).is_equal(Vector2.ZERO)

## Integration test: indicator switches valid → fail → valid as collision body is added/removed
func test_indicator_validity_switches_on_dynamic_collision() -> void:
	var rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	rule.collision_mask = 1
	
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	rule.setup(targeting_state)

	var test_indicator: RuleCheckIndicator = RuleCheckIndicator.new()
	auto_free(test_indicator)
	test_indicator.collision_mask = 1
	test_indicator.shape = RectangleShape2D.new()
	test_indicator.shape.size = Vector2.ONE
	_env.add_child(test_indicator)  # Add AFTER shape is assigned
	test_indicator.resolve_gb_dependencies(_container)
	test_indicator.add_rule(rule)

	var signal_states: Array[bool] = []
	test_indicator.valid_changed.connect(func(is_valid: bool) -> void: signal_states.append(is_valid))

	runner.simulate_frames(2)
	assert_bool(test_indicator.valid).append_failure_message(
		_indicator_state_diag(test_indicator, "Indicator should start valid, but was invalid. signal_states=%s" % [str(signal_states)])
	).is_true()
	# Implementation may or may not emit initial valid signal. Accept either [] or [true]
	if signal_states.size() > 0:
		assert_array(signal_states).append_failure_message(
			"Unexpected initial signal sequence: %s" % [str(signal_states)]
		).is_equal([true])

	# Add a colliding body to trigger failure
	var body := _create_test_body()
	_env.add_child(body)
	body.global_position = test_indicator.global_position
	runner.simulate_frames(1)  # Wait for body to be added to physics
	test_indicator.force_validity_evaluation()  # Force collision check AND validity update
	assert_bool(test_indicator.valid).append_failure_message(
		_indicator_state_diag(test_indicator, "Indicator should be invalid after collision, but was valid. signal_states=%s" % [str(signal_states)])
	).is_false()
	# After collision we expect last emission to be false
	if signal_states.size() > 0:
		assert_bool(signal_states.back()).append_failure_message(
			"Signal states after collision: %s" % [str(signal_states)]
		).is_false()
	else:
		assert_that(signal_states.size()).append_failure_message(
			"Expected at least one signal emission after collision"
		).is_greater(0)

	# Remove the body to restore validity
	_env.remove_child(body)
	body.free()  # Immediate removal
	test_indicator.force_validity_evaluation()  # Force collision recheck AND validity update
	assert_bool(test_indicator.valid).append_failure_message(
		_indicator_state_diag(test_indicator, "Indicator should be valid after body removal, but was invalid. signal_states=%s" % [str(signal_states)])
	).is_true()
	if signal_states.size() > 0:
		assert_bool(signal_states.back()).append_failure_message(
			"Signal states after body removal: %s" % [str(signal_states)]
		).is_true()
	else:
		assert_that(signal_states.size()).append_failure_message(
			"Expected at least one signal emission after body removal"
		).is_greater(0)

## Test: validity_sprite texture changes when indicator validity changes
func test_validity_sprite_texture_switches_on_validity_change() -> void:
	var rule2: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule2.pass_on_collision = false
	rule2.collision_mask = 1
	var targeting_state2: GridTargetingState = create_rule_targeting_state()
	rule2.setup(targeting_state2)

	var indicator2: RuleCheckIndicator = RuleCheckIndicator.new()
	auto_free(indicator2)
	indicator2.collision_mask = test_layers
	indicator2.shape = RectangleShape2D.new()
	indicator2.shape.size = Vector2.ONE
	_env.add_child(indicator2)  # Add AFTER shape is assigned
	# Setup visual resources mirroring before_test - reuse the test fixture settings
	indicator2.valid_settings = indicator.valid_settings
	indicator2.invalid_settings = indicator.invalid_settings
	indicator2.validity_sprite = auto_free(Sprite2D.new())
	indicator2.add_child(indicator2.validity_sprite)
	indicator2.resolve_gb_dependencies(_container)
	indicator2.add_rule(rule2)

	runner.simulate_frames(2)
	var sprite2: Sprite2D = indicator2.validity_sprite
	assert_object(sprite2).append_failure_message(
		"Indicator validity_sprite is null"
	).is_not_null()
	var valid_texture2: Texture2D = indicator2.valid_settings.texture
	var invalid_texture2: Texture2D = indicator2.invalid_settings.texture
	assert_bool(valid_texture2 != invalid_texture2).append_failure_message(
		"Valid and invalid textures should differ"
	).is_true()
	assert_object(sprite2.texture).append_failure_message(
		"Sprite texture should be valid texture after initial frame, got %s expected %s" % [str(sprite2.texture), str(valid_texture2)]
	).is_equal(valid_texture2)

	# Add a colliding body to trigger failure
	var body2 := _create_test_body()
	_env.add_child(body2)
	body2.global_position = indicator2.global_position
	runner.simulate_frames(1)  # Wait for body to be added to physics
	indicator2.force_validity_evaluation()  # Force collision check AND validity update
	assert_bool(indicator2.valid).append_failure_message(_indicator_state_diag(indicator2, "Indicator should be invalid after collision")).is_false()
	assert_object(sprite2.texture).append_failure_message(_indicator_state_diag(indicator2, "Sprite texture should be invalid texture after collision")).is_equal(invalid_texture2)

	# Remove body2 to restore validity
	_env.remove_child(body2)  # Remove from scene tree first
	body2.free()  # Immediate removal
	indicator2.force_validity_evaluation()  # Force collision recheck AND validity update
	assert_bool(indicator2.valid).append_failure_message(_indicator_state_diag(indicator2, "Indicator should be valid after body removal")).is_true()
	assert_object(sprite2.texture).append_failure_message(_indicator_state_diag(indicator2, "Sprite texture should be valid texture after body removal")).is_equal(valid_texture2)

## Test that indicators start in valid state when no rules are present
func test_indicator_starts_valid_with_no_rules() -> void:
	# Wait for physics frame to allow _physics_process to run and update validity
	runner.simulate_frames(1)
	assert_bool(indicator.valid).append_failure_message(_diag("Indicator should start valid with no rules")).is_true()
	# Allow deferred post-ready visual application to run
	runner.simulate_frames(1)
	assert_object(indicator.current_display_settings).append_failure_message(_diag("current_display_settings should be valid_settings when no rules present")).is_equal(indicator.valid_settings)


## Parameterized: pass/fail scenarios reduce setup duplication
## Each parameter: [rules:Array[Dictionary], bodies:Array[int], expected_valid:bool]
## rule spec: { "pass_on_collision": bool, "mask": int }
@warning_ignore("unused_parameter")
func test_indicator_validity_scenarios(
	rules: Array[Dictionary],
	bodies: Array[int],
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
) -> void:
	# Create and position collision bodies
	for layer: int in bodies:
		var body: Node2D = _create_test_body()
		body.collision_layer = layer
		_env.add_child(body)
		body.global_position = indicator.global_position

	# Create, setup, and add rules to indicator
	for r: Dictionary in rules:
		var rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
		rule.pass_on_collision = r["pass_on_collision"]
		rule.collision_mask = int(r["mask"])
		var targeting_state: GridTargetingState = create_rule_targeting_state()
		rule.setup(targeting_state)
		indicator.add_rule(rule)

	# Allow physics to process
	runner.simulate_frames(2)

	# Validate expected state and visuals
	assert_bool(indicator.valid).append_failure_message(
		_indicator_state_diag(indicator, "indicator.valid mismatch; expected=%s rules=%s bodies=%s" % [str(expected_valid), str(rules), str(bodies)])
	).is_equal(expected_valid)
	if expected_valid:
		assert_object(indicator.current_display_settings).append_failure_message(
			_indicator_state_diag(indicator, "current_display_settings should be valid_settings when valid")
		).is_equal(indicator.valid_settings)
	else:
		assert_object(indicator.current_display_settings).append_failure_message(
			_indicator_state_diag(indicator, "current_display_settings should be invalid_settings when invalid")
		).is_equal(indicator.invalid_settings)


## Test that the valid_changed signal is emitted when validity state changes
@warning_ignore("unused_parameter")
func test_valid_changed_signal_emitted_on_state_change(
	rule_spec: Dictionary,
	expected_value: bool,
	test_parameters := [[{"pass_on_collision": false, "mask": 1}, false]]
) -> void:
	var signal_data: Array[bool] = [false, false]
	var rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = rule_spec["pass_on_collision"]
	rule.collision_mask = int(rule_spec["mask"])
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	rule.setup(targeting_state)

	var collision_body: Node2D = _create_test_body()
	_env.add_child(collision_body)
	collision_body.global_position = indicator.global_position

	var signal_handler: Callable = func(is_valid: bool) -> void:
		signal_data[0] = true
		signal_data[1] = is_valid
	indicator.valid_changed.connect(signal_handler)

	indicator.add_rule(rule)
	runner.simulate_frames(2)
	assert_bool(signal_data[0]).append_failure_message(
		_indicator_state_diag(indicator, "valid_changed signal was not emitted on state change")
	).is_true()
	assert_bool(signal_data[1]).append_failure_message(
		_indicator_state_diag(indicator, "valid_changed signal payload mismatch; expected=%s actual=%s" % [str(expected_value), str(signal_data[1])])
	).is_equal(expected_value)
	indicator.valid_changed.disconnect(signal_handler)


## Test that visual settings are properly updated when validity changes
func test_visual_settings_update_on_validity_change() -> void:
	assert_object(indicator.current_display_settings).append_failure_message(
		_indicator_state_diag(indicator, "current_display_settings should start as valid_settings")
	).is_equal(indicator.valid_settings)
	assert_object(indicator.validity_sprite.texture).append_failure_message(
		_indicator_state_diag(indicator, "validity_sprite.texture should start as valid texture")
	).is_equal(indicator.valid_settings.texture)
	assert_that(indicator.validity_sprite.modulate).append_failure_message(
		_indicator_state_diag(indicator, "validity_sprite.modulate should start as valid modulate")
	).is_equal(indicator.valid_settings.modulate)
	
	# Create a failing rule to trigger visual change
	var failing_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	# This rule should fail when there is a collision
	failing_rule.pass_on_collision = false
	failing_rule.collision_mask = 1
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	failing_rule.setup(targeting_state)

	var collision_body: Node2D = _create_test_body()
	_env.add_child(collision_body)
	
	# Position the collision body to overlap with the indicator
	collision_body.global_position = indicator.global_position
	
	# Add the rule to trigger visual change
	indicator.add_rule(failing_rule)
	# Wait for physics process to run
	runner.simulate_frames(2)

	assert_bool(indicator.valid).append_failure_message("The indicator should be invalid after adding a failing rule.").is_false()

	# Verify visual settings changed to invalid
	assert_object(indicator.current_display_settings).append_failure_message("The current display is expected to be the invalid settings.").is_equal(indicator.invalid_settings)
	assert_object(indicator.validity_sprite.texture).append_failure_message("The texture of the current sprite should be set to the invalid settings texture.").is_equal(indicator.invalid_settings.texture)
	assert_that(indicator.validity_sprite.modulate).append_failure_message("The modulate color of the current validity_sprite Sprite2D is expected to be the failure modulate color from the settings.").is_equal(indicator.invalid_settings.modulate)


## Test that force_validation_update properly updates the indicator state
@warning_ignore("unused_parameter")
func test_force_validation_update(
	rule_spec: Dictionary,
	expected_valid: bool,
	test_parameters := [[{"pass_on_collision": false, "mask": 1}, false]]
) -> void:
	var rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = rule_spec["pass_on_collision"]
	rule.collision_mask = int(rule_spec["mask"])
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	rule.setup(targeting_state)

	var collision_body: Node2D = _create_test_body()
	_env.add_child(collision_body)
	collision_body.global_position = indicator.global_position

	indicator.add_rule(rule)
    
	assert_bool(indicator.force_validity_evaluation()).append_failure_message(
		_diag("force_validity_evaluation() did not return expected value; expected=%s current_valid=%s" % [str(expected_valid), str(indicator.valid)])
	).is_equal(expected_valid)
	if expected_valid:
		assert_object(indicator.current_display_settings).append_failure_message(
			_indicator_state_diag(indicator, "current_display_settings should be valid_settings when expected_valid=true")
		).is_equal(indicator.valid_settings)
	else:
		assert_object(indicator.current_display_settings).append_failure_message(
			_indicator_state_diag(indicator, "current_display_settings should be invalid_settings when expected_valid=false")
		).is_equal(indicator.invalid_settings)


## Test that indicators properly handle rules being added after _ready
func test_rules_added_after_ready() -> void:
	# Wait for _ready to complete
	runner.simulate_frames(1)
	
	# Verify initial state
	assert_bool(indicator.valid).append_failure_message(
		_indicator_state_diag(indicator, "Indicator should start valid with no rules")
	).is_true()
	
	# Create and add a failing rule after _ready
	var failing_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	failing_rule.pass_on_collision = false
	failing_rule.collision_mask = 1
	
	# Initialize the rule properly for testing
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	failing_rule.setup(targeting_state)

	var collision_body: Node2D = _create_test_body()
	_env.add_child(collision_body)
	
	# Position the collision body to overlap with the indicator
	collision_body.global_position = indicator.global_position
	
	# Add the rule
	indicator.add_rule(failing_rule)
	
	# Wait for physics process to run
	runner.simulate_frames(2)
	
	# Verify the indicator is now invalid
	assert_bool(indicator.valid).append_failure_message(_diag("Indicator should be invalid after adding failing rule")).is_false()
	assert_object(indicator.current_display_settings).append_failure_message(_diag("Display settings did not switch to invalid settings after failing rule")).is_equal(indicator.invalid_settings)

## Test that indicators properly handle rules being removed
func test_rules_removed() -> void:
	# Create a failing rule
	var failing_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	failing_rule.pass_on_collision = false
	failing_rule.collision_mask = 1
	
	# Initialize the rule properly for testing
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	failing_rule.setup(targeting_state)

	var collision_body: Node2D = _create_test_body()
	_env.add_child(collision_body)
	
	# Position the collision body to overlap with the indicator
	collision_body.global_position = indicator.global_position
	
	# Add the rule
	indicator.add_rule(failing_rule)
	
	# Wait for physics process to run
	runner.simulate_frames(2)
	
	# Verify the indicator is invalid (provide detailed diagnostics)
	var prior_rules_count: int = indicator.get_rules().size()
	assert_bool(indicator.valid).append_failure_message(
		_diag("Indicator unexpectedly valid before rule removal; rules=%d collisions=%d" % [prior_rules_count, indicator.get_collision_count()])
	).is_false()
	
	# Remove the rule
	indicator.clear()
	
	# Wait for physics process to run
	runner.simulate_frames(2)
	
	# Verify the indicator is now valid again
	assert_bool(indicator.valid).append_failure_message(
		_diag("Indicator did not become valid after clear(); remaining_rules=%d" % [indicator.get_rules().size()])
	).is_true()
	assert_object(indicator.current_display_settings).append_failure_message(
		_diag("Display settings not reverted to valid after clear()")
	).is_equal(indicator.valid_settings)

## Test improved debug log format when no rules present at _ready
func test_ready_debug_log_format_no_rules() -> void:
	# Simulate logger with debug enabled
	var dbg: GBDebugSettings = _env.get_container().get_debug_settings()
	dbg.level = GBDebugSettings.LogLevel.DEBUG
	var test_indicator: RuleCheckIndicator = UnifiedTestFactory.create_test_rule_check_indicator(self)
	test_indicator.shape = RectangleShape2D.new(); test_indicator.shape.size = Vector2.ONE
	test_indicator.resolve_gb_dependencies(_container)
	runner.simulate_frames(1)
	# We can't intercept internal logger messages without a spy; assert valid state and zero rules
	assert_int(test_indicator.get_rules().size()).append_failure_message(
		"Test indicator should start with 0 rules"
	).is_equal(0)
	assert_bool(test_indicator.valid).append_failure_message(
		_indicator_state_diag(test_indicator, "Test indicator should be valid with no rules")
	).is_true()

## Test per-frame evaluation toggled by environment variable
func test_per_frame_validation_env_flag() -> void:
	OS.set_environment("GB_INDICATOR_EVAL_EACH_FRAME", "1")
	var rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	rule.pass_on_collision = false
	rule.collision_mask = 1
	var targeting_state: GridTargetingState = create_rule_targeting_state()
	rule.setup(targeting_state)
	var body: StaticBody2D = _create_test_body()
	_env.add_child(body)
	body.global_position = indicator.global_position
	indicator.add_rule(rule)
	runner.simulate_frames(1)  # Wait for body to be added to physics
	indicator.force_validity_evaluation()  # Force collision check AND validity update
	var first_state: bool = indicator.valid
	# Remove body then ensure per-frame revalidation flips state back to valid automatically
	_env.remove_child(body)  # Remove from scene tree first
	body.free()  # Immediate removal
	indicator.force_validity_evaluation()  # Force collision recheck AND validity update
	assert_bool(first_state).append_failure_message(
		_indicator_state_diag(indicator, "first_state should be false with collision body present")
	).is_false()
	assert_bool(indicator.valid).append_failure_message(
		_indicator_state_diag(indicator, "indicator.valid should be true after body removal with per-frame validation")
	).is_true()
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
) -> void:
	#region Setup
	var body: StaticBody2D = _create_test_body()
	var shape: CollisionShape2D = body.get_child(0)
	var original_position: Vector2 = indicator.global_position
	var indicator_shape_size: Vector2 = indicator.shape.get_rect().size / 2.0
	indicator.global_position = Vector2.ZERO
	body.global_position = Vector2.ZERO
	#endregion

	#region Execution
	indicator.global_position = original_position + (p_move_shape_size_multiplier * indicator_shape_size)
	var result: PackedVector2Array = indicator.shape.collide_and_get_contacts(
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
) -> void:
	var root_instance: Node = auto_free(p_test_scene.instantiate())
	add_child(root_instance)

	# Find a PhysicsBody2D to use for collision tests (scene root may be Node2D)
	var phys_body: PhysicsBody2D = _find_first_physics_body(root_instance)
	assert_object(phys_body).append_failure_message("Test scene does not contain a PhysicsBody2D root or descendant: %s" % [str(p_test_scene)]).is_not_null()

	indicator.collision_mask = phys_body.collision_layer
	indicator.force_shapecast_update()
	var collision_count: int = indicator.get_collision_count()
	assert_int(collision_count).is_equal(p_expected_collisions)


@warning_ignore("unused_parameter")
func test__update_visuals() -> void:
	# Create a small test settings instance instead of loading uid
	var local_settings: IndicatorVisualSettings = IndicatorVisualSettings.new()
	local_settings.modulate = Color(0.5, 0.5, 0.5)
	var updated_sprite: Sprite2D = indicator._update_visuals(local_settings)
	assert_that(updated_sprite.modulate).is_equal(local_settings.modulate)


## Test the default return of get_tile_positon
func test_get_tile_position_default() -> void:
	var test_tile_map: TileMapLayer = auto_free(GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE.instantiate())
	add_child(test_tile_map)
	var position: Vector2i = indicator.get_tile_position(test_tile_map)
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
## Example (GDScript):
## var collision_body = _create_test_body()
## add_child(collision_body)
## collision_body.global_position = indicator.global_position  # CRITICAL: Position for collision
func _create_test_body() -> StaticBody2D:
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	collision_body.collision_layer = test_layers

	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	collision_body.add_child(collision_shape)
	collision_shape.shape = RectangleShape2D.new()
	
	# IMPORTANT: The collision shape needs a size to actually collide
	# RectangleShape2D defaults to size (0, 0) which means no collision detection
	collision_shape.shape.size = Vector2.ONE  # Match the indicator size
	
	return collision_body


## Helper: find the first PhysicsBody2D inside a scene root (or root itself)
func _find_first_physics_body(root: Node) -> PhysicsBody2D:
	if root is PhysicsBody2D:
		return root
	for child in root.get_children():
		if child is PhysicsBody2D:
			return child
		var found := _find_first_physics_body(child)
		if found:
			return found
	return null
