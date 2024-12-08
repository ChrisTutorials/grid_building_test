extends GdUnitTestSuite

var indicator : RuleCheckIndicator
var collision_body : StaticBody2D
var collision_shape : CollisionShape2D

var test_layers = 1 # Bitmask

func before_test():
	indicator = auto_free(RuleCheckIndicator.new())
	indicator.collision_mask = test_layers
	add_child(indicator)
	indicator.shape = RectangleShape2D.new()
	
	collision_body = auto_free(StaticBody2D.new())
	collision_body.collision_layer = test_layers
	add_child(collision_body)
	
	indicator.validity_sprite = auto_free(Sprite2D.new())
	indicator.invalid_settings = IndicatorVisualSettings.new()
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(15.9, 15.9)
	indicator.invalid_settings = load("res://test/grid_building_test/resources/settings/indicator_visual/invalid_visual.tres")
	
	collision_shape = CollisionShape2D.new()
	collision_body.add_child(collision_shape)
	
	collision_shape.shape = RectangleShape2D.new()
	
func test_setup_indicator_defaults():
	assert_object(indicator).append_failure_message("[indicator] must not be null").is_not_null()
	assert_vector(indicator.target_position).is_equal(Vector2.ZERO)

## Testing move distance for an indicator compared to where it will still have collisions with it's shape at the starting position or not
@warning_ignore("unused_parameter")
func test_indicator_collide_and_get_contacts(p_move_shape_size_multiplier : Vector2, p_expected_empty : bool, test_parameters = [
	[Vector2(0, 0), false],
	[Vector2(0, -1), false],
	[Vector2(0, -2), true],
	[Vector2(1, 0), false],
	[Vector2(-2, 0), true]
]):
	#region Setup
	var original_position = indicator.global_position
	var indicator_shape_size : Vector2 = indicator.shape.get_rect().size
	indicator.global_position = Vector2.ZERO
	collision_body.global_position = Vector2.ZERO
	#endregion
	
	#region Execution
	indicator.position = original_position + (p_move_shape_size_multiplier * indicator_shape_size)
	var result : Array = indicator.shape.collide_and_get_contacts(indicator.global_transform, collision_shape.shape, collision_shape.global_transform)
	assert_bool(result.is_empty()).append_failure_message("If false, is inside shape. If true, is outside.").is_equal(p_expected_empty)
	#endregion


@warning_ignore("unused_parameter")
func test__update_visuals(p_settings : IndicatorVisualSettings, test_parameters = [
	[load("res://test/grid_building_test/resources/settings/indicator_visual/orange_visual.tres")]
]) -> void:
	var updated_sprite = indicator._update_visuals(p_settings)
	assert_that(updated_sprite.modulate).is_equal(p_settings.modulate)
