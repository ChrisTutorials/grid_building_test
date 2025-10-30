extends GdUnitTestSuite

# This test suite is dedicated to isolating and verifying the coordinate
# transformation logic within the IndicatorFactory. It focuses on the core
# function of converting a tile-based offset into a correct global position,
# which is the root of the positioning bug.

const TestIndicatorScene = preload("uid://dhox8mb8kuaxa")

var _tile_map: TileMapLayer
var _targeting_state: GridTargetingState
var _positioner: Node2D


func before_test() -> void:
	# Minimal setup to test coordinate logic
	_tile_map = auto_free(TileMapLayer.new())
	_tile_map.tile_set = TileSet.new()
	_tile_map.tile_set.tile_size = Vector2(16, 16)
	add_child(_tile_map)

	_positioner = auto_free(Node2D.new())
	add_child(_positioner)

	var owner_context := GBOwnerContext.new()
	_targeting_state = GridTargetingState.new(owner_context)
	_targeting_state.target_map = _tile_map
	_targeting_state.positioner = _positioner

	# Ensure a clean state for each test
	_tile_map.global_position = Vector2.ZERO
	_positioner.global_position = Vector2.ZERO
	await await_idle_frame()


func test_tile_to_global_position_logic() -> void:
	# Arrange: Position the positioner at a known tile
	var positioner_tile := Vector2i(10, 10)
	_positioner.global_position = _tile_map.map_to_local(positioner_tile)

	# The offset from the collision system that causes the bug
	var suspicious_offset := Vector2i(51, 21)
	## NOTE: Keep the nested dictionary static typing
	var position_rules_map: Dictionary[Vector2i, Array] = {suspicious_offset: []}

	# Act
	var indicators: Array[RuleCheckIndicator] = IndicatorFactory.generate_indicators(
		position_rules_map, TestIndicatorScene, _positioner, _targeting_state, _positioner  # Parent node for the indicators  # Test object is the positioner itself for simplicity
	)

	# Assert
	(
		assert_int(indicators.size()) \
		. append_failure_message("IndicatorFactory should generate 1 indicator for 1 offset") \
		. is_equal(1)
	)
	var indicator: Node2D = indicators[0]

	# Re-calculate expected position manually to verify logic
	var calculated_positioner_tile: Vector2i = _tile_map.local_to_map(
		_tile_map.to_local(_positioner.global_position)
	)
	var target_tile: Vector2i = calculated_positioner_tile + suspicious_offset
	var expected_global_position: Vector2 = _tile_map.to_global(_tile_map.map_to_local(target_tile))

	var actual_global_position: Vector2 = indicator.global_position
	var distance: float = actual_global_position.distance_to(expected_global_position)

	var failure_message := (
		"""
	Coordinate transformation logic is flawed.
	- Positioner Tile: %s
	- Suspicious Offset: %s
	- Calculated Target Tile: %s
	- Expected Global Position: %s
	- Actual Global Position: %s
	- Distance Error: %.2f pixels
	"""
		% [
			calculated_positioner_tile,
			suspicious_offset,
			target_tile,
			expected_global_position,
			actual_global_position,
			distance
		]
	)

	assert_vector(actual_global_position).append_failure_message(failure_message).is_equal_approx(
		expected_global_position, Vector2(0.1, 0.1)
	)
