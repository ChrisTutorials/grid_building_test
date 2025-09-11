extends EditorScript


func _run():
	trapezoid: Node = PackedVector2Array(
		[Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)]
	)

	# Test a few specific tile positions
	var test_positions = [
		Vector2(-16, 0),  # Should overlap (center-left)
		Vector2(0, 0),  # Should overlap (center)
		Vector2(16, 0),  # Should overlap (center-right)
		Vector2(-16, 16),  # Should overlap (bottom-left)
		Vector2(0, 16),  # Should overlap (bottom-center)
		Vector2(16, 16),  # Should overlap (bottom-right)
		Vector2(-48, 0),  # Should NOT overlap (far left)
		Vector2(48, 0),  # Should NOT overlap (far right)
	]

	for pos in test_positions:
		var area = GBGeometryMath.intersection_area_with_tile(trapezoid, pos, Vector2(16, 16), 0)
		var overlaps = area > 1.0
		print("Tile at ", pos, ": area=", area, ", overlaps=", overlaps)
