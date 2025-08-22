## Tests for PolygonIndicatorHeuristics static functions.
extends GdUnitTestSuite

# Use global class_name PolygonIndicatorHeuristics directly

const TILE_SIZE := Vector2(16,16)

func _make_offsets(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v in list:
		out.append(v)
	return out

func test_is_hollow_false_for_dense_block():
	var offsets := _make_offsets([
		Vector2i(0,0), Vector2i(1,0),
		Vector2i(0,1), Vector2i(1,1)
	])
	var result := PolygonIndicatorHeuristics.is_hollow(offsets)
	assert_bool(result).append_failure_message("2x2 solid block should not be hollow").is_false()

func test_is_hollow_true_for_sparse_ring():
	# Create a 3x3 ring missing center (8 tiles) -> bbox area 9, density 9/8=1.125 < 1.5 threshold -> still false.
	# Use a larger ring to exceed factor: 5x5 ring missing interior (area 25, tiles 16, 25 > 16*1.5? 25 > 24 yes -> hollow)
	var offsets: Array[Vector2i] = []
	for x in range(-2,3):
		for y in range(-2,3):
			var edge := x == -2 or x == 2 or y == -2 or y == 2
			if edge:
				offsets.append(Vector2i(x,y))
	var result := PolygonIndicatorHeuristics.is_hollow(offsets)
	assert_bool(result).append_failure_message("5x5 ring should be hollow (bbox=25 tiles=16)").is_true()

func test_should_expand_trapezoid_positive():
	# Base offsets matching two rows with center (0,0) present; size <= 10; convex & not hollow.
	var offsets := _make_offsets([Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)])
	var ys: Array[int] = []
	var xs_by_y: Dictionary = {}
	for o in offsets:
		if not ys.has(o.y): ys.append(o.y)
		if not xs_by_y.has(o.y): xs_by_y[o.y] = []
		xs_by_y[o.y].append(o.x)
	var hollow := PolygonIndicatorHeuristics.is_hollow(offsets)
	var expand := PolygonIndicatorHeuristics.should_expand_trapezoid(true, offsets, ys, xs_by_y, hollow)
	assert_bool(expand).append_failure_message("Expected expansion criteria to pass").is_true()
	var expanded := PolygonIndicatorHeuristics.generate_trapezoid_offsets()
	assert_int(expanded.size()).append_failure_message("Expanded trapezoid should contain 13 tiles").is_equal(13)

func test_should_expand_trapezoid_blocked_by_hollow():
	# Build a sparse cross within a tall bbox to trigger hollow detection (bbox area >> tile count)
	var offsets: Array[Vector2i] = []
	# Vertical line
	for y in range(-3,4):
		offsets.append(Vector2i(0,y))
	# Horizontal short line (cross arms)
	for x in [-1,1]:
		offsets.append(Vector2i(x,0))
	# Now offsets size = 7, bbox area = (0-0+1)*( -3 to 3 => 7 ) = 7 -> Not hollow yet.
	# Add two distant horizontal arms at top/bottom to enlarge bbox width without many tiles
	for x in [-2,2]:
		offsets.append(Vector2i(x,-3))
	for x in [-2,2]:
		offsets.append(Vector2i(x,3))
	# bbox now spans x from -2..2 (5) and y -3..3 (7) => area=35; tiles ~11 -> 35 > 11*1.5 (16.5)? No -> add more spacing
	# Add mid arms at y=-2,2
	for x in [-2,2]:
		offsets.append(Vector2i(x,-2))
	for x in [-2,2]:
		offsets.append(Vector2i(x,2))
	# Recompute expected: tiles ~19, bbox area still 35 -> 35 > 28.5? yes becomes hollow
	var ys: Array[int] = []
	var xs_by_y: Dictionary = {}
	for o in offsets:
		if not ys.has(o.y): ys.append(o.y)
		if not xs_by_y.has(o.y): xs_by_y[o.y] = []
		xs_by_y[o.y].append(o.x)
	var hollow := PolygonIndicatorHeuristics.is_hollow(offsets)
	var expand := PolygonIndicatorHeuristics.should_expand_trapezoid(true, offsets, ys, xs_by_y, hollow)
	assert_bool(hollow).append_failure_message("Sparse cross structure should be hollow (bbox=%d tiles=%d)" % [ ( (2 - -2 + 1) * (3 - -3 + 1) ), offsets.size() ]).is_true()
	assert_bool(expand).append_failure_message("Expansion should be blocked by hollow pattern").is_false()

func test_prune_concave_fringe_removes_low_area_tile():
	# World polygon mostly occupies tile (0,0) with a 1px sliver into tile (1,0)
	# Tile area=256; min_area=0.12*256=30.72. Sliver area=1*16=16 (< threshold) so (1,0) should be pruned.
	var world_points := PackedVector2Array([
		Vector2(0,0), Vector2(16,0), Vector2(16,16), Vector2(17,16), Vector2(17,0), Vector2(16,0), Vector2(16,16), Vector2(0,16)
	])
	# Offsets computed externally would include (0,0) and (1,0)
	var offsets := _make_offsets([Vector2i(0,0), Vector2i(1,0)])
	var pruned := PolygonIndicatorHeuristics.prune_concave_fringe(world_points, offsets, Vector2i.ZERO, TILE_SIZE, 0.12)
	assert_int(pruned.size()).append_failure_message("Expected one tile after pruning but got %d: %s" % [pruned.size(), pruned]).is_equal(1)
	assert_bool(Vector2i(0,0) in pruned).append_failure_message("Core tile (0,0) should be retained").is_true()
	assert_bool(Vector2i(1,0) in pruned).append_failure_message("Sliver tile (1,0) should be removed").is_false()

func test_prune_concave_fringe_no_change_when_all_tiles_large():
	# Large rectangle spanning 2 tiles fully in X (32x16) => each tile area 256 fully covered.
	var world_points := PackedVector2Array([
		Vector2(0,0), Vector2(32,0), Vector2(32,16), Vector2(0,16)
	])
	var offsets := _make_offsets([Vector2i(0,0), Vector2i(1,0)])
	var pruned := PolygonIndicatorHeuristics.prune_concave_fringe(world_points, offsets, Vector2i.ZERO, TILE_SIZE, 0.12)
	assert_int(pruned.size()).append_failure_message("Should retain both tiles (no pruning)").is_equal(2)
