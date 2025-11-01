## Debug test specifically for the trapezoid coordinate calculation issue
## The runtime shows missing tile coverage in bottom corners, but collision geometry
## calculation is returning completely wrong tile coordinates
extends GdUnitTestSuite

const TRAPEZOID_POSITION: Vector2 = Vector2(440, 552)
const TILE_SIZE: Vector2 = Vector2(16, 16)


func test_trapezoid_coordinate_calculation() -> void:
	"""Debug test for trapezoid coordinate calculation issue.

	For a trapezoid at position (440, 552) with local points [(-32,12), (-16,-12), (17,-12), (32,12)]:
	- World points would be: [(408,564), (424,540), (457,540), (472,564)]
	- This spans roughly tiles from (25,33) to (29,35)
	- Relative to center tile (27,34), expected offsets might be around:
	  [(-2,-1), (-1,-1), (0,-1), (1,-1), (2,-1), (-2,0), (-1,0), (0,0), (1,0), (2,0), (-1,1), (0,1), (1,1)]
	"""
	GBTestDiagnostics.log_verbose("=== TRAPEZOID COORDINATE DEBUG TEST ===")
	GBTestDiagnostics.log_verbose(
		(
			"  Vertex %d: Local %s -> World %s -> Tile %s -> Offset %s"
			% [i, local_point, world_point, tile_coord, offset_from_center]
		)
	)
