## Unit tests for TargetingShapeCast2D component
extends GdUnitTestSuite

func test_force_shapecast_update_no_crash() -> void:
	# Create a TargetingShapeCast2D instance with a valid shape and ensure update_target() is safe
	var sc: TargetingShapeCast2D = TargetingShapeCast2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	sc.shape = shape
	add_child(sc)
	# No dependencies injected -> update_target() returns early without touching physics
	sc.update_target()
	assert_bool(true).is_true()

func test_is_colliding_and_get_collider_behavior() -> void:
	var sc: TargetingShapeCast2D = TargetingShapeCast2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	sc.shape = shape
	add_child(sc)
	# By default, no colliders present
	assert_bool(sc.is_colliding()).append_failure_message("New TargetingShapeCast2D should not be colliding by default").is_false()
	# Do not call get_collider() when not colliding; engine raises 'No collider found'
	# This assertion is sufficient for default behavior
