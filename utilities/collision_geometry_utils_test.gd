extends GdUnitTestSuite

const CollisionGeometryUtils = preload("res://addons/grid_building/utilities/collision_geometry_utils.gd")

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var tile_map_layer: TileMapLayer

func before_test():
	tile_map_layer = auto_free(TileMapLayer.new())
	add_child(tile_map_layer)
	tile_map_layer.tile_set = TileSet.new()
	tile_map_layer.tile_set.tile_size = Vector2(16, 16)

## Parameterized test for build_shape_transform with different rotations & scales
@warning_ignore("unused_parameter")
func test_build_shape_transform_param(
	col_obj_rot: float,
	col_obj_scale: Vector2,
	shape_rot: float,
	shape_scale: Vector2,
	shape_local_pos: Vector2,
	expected_origin: Vector2,
	test_parameters := [
		# No transforms
		[0.0, Vector2.ONE, 0.0, Vector2.ONE, Vector2.ZERO, Vector2.ZERO],
		# Object moved, shape offset
		[0.0, Vector2.ONE, 0.0, Vector2.ONE, Vector2(8, 4), Vector2(8, 4)],
		# Object rotated 90deg, shape at (16,0) => offset rotates to approximately (0,16)
		[PI/2.0, Vector2.ONE, 0.0, Vector2.ONE, Vector2(16, 0), Vector2(0, 16)],
		# Object scaled 2x uniformly, shape local (4,4) => (8,8)
		[0.0, Vector2(2,2), 0.0, Vector2.ONE, Vector2(4,4), Vector2(8,8)],
	]
):
	var obj: Node2D = auto_free(Node2D.new())
	add_child(obj)
	obj.global_position = Vector2.ZERO
	obj.rotation = col_obj_rot
	obj.scale = col_obj_scale
	var shape_owner: Node2D = auto_free(Node2D.new())
	obj.add_child(shape_owner)
	shape_owner.position = shape_local_pos
	shape_owner.rotation = shape_rot
	shape_owner.scale = shape_scale
	var xform = CollisionGeometryUtils.build_shape_transform(obj, shape_owner)
	if abs(col_obj_rot - PI/2.0) < 0.0001:
		# Allow tiny precision drift on rotated origin X
		assert_float(xform.origin.x).append_failure_message("Rotated origin X mismatch").is_equal_approx(expected_origin.x, 0.001)
		assert_float(xform.origin.y).append_failure_message("Rotated origin Y mismatch").is_equal(expected_origin.y)
	else:
		assert_vector(xform.origin).append_failure_message("Origin mismatch for parameters: %s" % [test_parameters]).is_equal(expected_origin)

## Test world polygon transform stability when parented vs unparented
func test_polygon_world_transform_parenting_effect():
	var positioner: Node2D = auto_free(Node2D.new())
	add_child(positioner)
	positioner.position = Vector2(32,32)
	var parented_poly: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	positioner.add_child(parented_poly)
	parented_poly.polygon = PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)])
	var unparented_poly: CollisionPolygon2D = auto_free(CollisionPolygon2D.new())
	add_child(unparented_poly)
	unparented_poly.global_position = Vector2(64,64)
	unparented_poly.polygon = parented_poly.polygon
	var world_parented_initial = CollisionGeometryUtils.to_world_polygon(parented_poly)
	var world_unparented_initial = CollisionGeometryUtils.to_world_polygon(unparented_poly)
	# Move positioner; parented points should shift; unparented stay same
	positioner.position = Vector2(64,64)
	var world_parented_after = CollisionGeometryUtils.to_world_polygon(parented_poly)
	var world_unparented_after = CollisionGeometryUtils.to_world_polygon(unparented_poly)
	# Validate parented moved
	assert_bool(world_parented_initial[0] != world_parented_after[0]).append_failure_message("Parented polygon world point should change after moving positioner").is_true()
	# Validate unparented unchanged
	assert_bool(world_unparented_initial[0] == world_unparented_after[0]).append_failure_message("Unparented polygon world point should remain constant").is_true()

## Parameterized bounds->tile range edge handling
@warning_ignore("unused_parameter")
func test_compute_tile_iteration_range_param(
	bounds: Rect2,
	expected_start: Vector2i,
	expected_end_exclusive: Vector2i,
	test_parameters := [
		# Based on current compute_tile_iteration_range logic (inclusive end -> +1)
		[Rect2(Vector2(0,0), Vector2(16,16)), Vector2i(0,0), Vector2i(2,2)],
		[Rect2(Vector2(15.999,15.999), Vector2(16,16)), Vector2i(0,0), Vector2i(2,2)],
		[Rect2(Vector2(16,0), Vector2(16,16)), Vector2i(1,0), Vector2i(3,2)],
	]
):
	var result = CollisionGeometryUtils.compute_tile_iteration_range(bounds, tile_map_layer)
	assert_vector(result["start"]).append_failure_message("Start tile mismatch for bounds %s" % [bounds]).is_equal(expected_start)
	assert_vector(result["end_exclusive"]).append_failure_message("End exclusive mismatch for bounds %s" % [bounds]).is_equal(expected_end_exclusive)
