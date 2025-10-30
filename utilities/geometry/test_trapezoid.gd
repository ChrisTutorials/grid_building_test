extends EditorScript


func _run() -> void:
	var trapezoid := PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	# Test a few specific tile positions
	var test_positions: Array[Vector2] = [
		Vector2(-16, 0),  # Should overlap (center-left)
		Vector2(0, 0),  # Should overlap (center)
		Vector2(16, 0),  # Should overlap (center-right)
		Vector2(-16, 16),  # Should overlap (bottom-left)
		Vector2(0, 16),  # Should overlap (bottom-center)
		Vector2(16, 16),  # Should overlap (bottom-right)
		Vector2(-48, 0),  # Should NOT overlap (far left)
		Vector2(48, 0),  # Should NOT overlap (far right)
	]

	for pos: Vector2 in test_positions:
		var area: float = GBGeometryMath.intersection_area_with_tile(
			trapezoid, pos, Vector2(16.0, 16.0), TileSet.TileShape.TILE_SHAPE_SQUARE
		)
		# Debug output removed - use test failure messages for debugging instead
