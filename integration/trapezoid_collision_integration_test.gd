## Integration test for trapezoid shape collision detection in the runtime environment
## This test specifically reproduces the issue where the trapezoid shape from the demo
## is not generating rule check indicators at the bottom left and bottom right positions
## despite the unit tests passing for the collision geometry calculations.
##
## The goal is to isolate where in the indicator generation chain the collision
## calculations are being lost or incorrectly filtered.
extends GdUnitTestSuite

const TRAPEZOID_POSITION: Vector2 = Vector2(440, 552)  # From runtime scene analysis

## Factory method for creating the exact trapezoid from runtime analysis
static func create_trapezoid_from_runtime() -> PackedVector2Array:
	# Matches the "SimpleTrapezoid" from runtime_scene_analysis.txt
	# Polygon: [(-32.0, 12.0), (-16.0, -12.0), (17.0, -12.0), (32.0, 12.0)]
	return PackedVector2Array([
		Vector2(-32, 12), 
		Vector2(-16, -12), 
		Vector2(17, -12), 
		Vector2(32, 12)
	])

var _env: BuildingTestEnvironment
var _collision_mapper: CollisionMapper
var _targeting_state: GridTargetingState
var _indicator_manager: IndicatorManager

func before_test() -> void:
	_env = EnvironmentTestFactory.create_building_system_test_environment(self)
	_collision_mapper = _env.indicator_manager.get_collision_mapper()
	_targeting_state = _env.grid_targeting_system.get_state()
	_indicator_manager = _env.indicator_manager
	
	# Validate environment setup
	assert_object(_collision_mapper).is_not_null()
	assert_object(_targeting_state).is_not_null()
	assert_object(_indicator_manager).is_not_null()

## Test that focuses on the trapezoid collision detection integration
func test_trapezoid_collision_detection_integration() -> void:
	print("[TRAPEZOID_TRACE] === STARTING INTEGRATION TEST ===")
	
	# 1) Create the exact trapezoid from runtime
	var trapezoid_polygon: PackedVector2Array = create_trapezoid_from_runtime()
	print("[TRAPEZOID_TRACE] Trapezoid polygon: %s" % str(trapezoid_polygon))
	
	# 2) Create test object with collision shape (needs to be a physics body)
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = "TrapezoidTestObject"
	test_object.global_position = TRAPEZOID_POSITION
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = trapezoid_polygon
	collision_shape.shape = shape
	collision_shape.name = "TrapezoidCollision"
	
	test_object.add_child(collision_shape)
	
	# Add to scene tree so it's properly detected
	_env.add_child(test_object)
	auto_free(test_object)
	
	# 3) Set targeting state
	_targeting_state.target = test_object
	_targeting_state.positioner.global_position = TRAPEZOID_POSITION
	
	print("[TRAPEZOID_TRACE] Test object position: %s" % str(test_object.global_position))
	print("[TRAPEZOID_TRACE] Positioner position: %s" % str(_targeting_state.positioner.global_position))
	
	# 4) Test collision shape detection
	var owner_shapes: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)
	print("[TRAPEZOID_TRACE] Owner shapes found: %d" % owner_shapes.size())
	
	assert_int(owner_shapes.size()).append_failure_message(
		"No collision shapes detected from trapezoid test object"
	).is_greater(0)
	
	for shape_owner: Node in owner_shapes.keys():
		var shapes: Array = owner_shapes[shape_owner]
		print("[TRAPEZOID_TRACE] Owner '%s' has %d shapes" % [shape_owner.name, shapes.size()])
		for i in range(shapes.size()):
			var shape_info: Variant = shapes[i]  # Use Variant to handle any type returned
			print("[TRAPEZOID_TRACE] Shape[%d]: type=%s, polygon_size=%s" % [
				i, 
				shape_info.get("type", "unknown") if shape_info is Dictionary else "object_type",
				shape_info.get("polygon", PackedVector2Array()).size() if shape_info is Dictionary else "N/A"
			])
	
	# 5) Test CollisionGeometryUtils directly with the trapezoid polygon
	var tile_size: Vector2 = Vector2(16, 16)
	# Convert position to center tile coordinate
	var center_tile: Vector2i = Vector2i(
		int(TRAPEZOID_POSITION.x / tile_size.x),
		int(TRAPEZOID_POSITION.y / tile_size.y)
	)
	
	# IMPORTANT: Convert polygon to world space before collision calculation
	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point in trapezoid_polygon:
		world_polygon.append(point + TRAPEZOID_POSITION)
	
	var tile_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		world_polygon, tile_size, center_tile
	)
	print("[TRAPEZOID_TRACE] Direct collision calculation tile offsets: %s" % str(tile_offsets))
	
	# 6) Expected tiles based on the visual evidence from the runtime image
	# The runtime shows indicators missing at bottom-left and bottom-right extensions
	var expected_missing_tiles: Array[Vector2i] = [
		Vector2i(-2, 1),  # Bottom left extension
		Vector2i(2, 1)    # Bottom right extension  
	]
	
	var expected_present_tiles: Array[Vector2i] = [
		Vector2i(-2, 0),  # Left extension (should be present)
		Vector2i(2, 0),   # Right extension (should be present)
		Vector2i(0, 0),   # Center (should be present)
		Vector2i(-1, 0),  # Left-center (should be present)
		Vector2i(1, 0)    # Right-center (should be present)
	]
	
	print("[TRAPEZOID_TRACE] Checking for expected missing tiles: %s" % str(expected_missing_tiles))
	print("[TRAPEZOID_TRACE] Checking for expected present tiles: %s" % str(expected_present_tiles))
	
	# 7) Verify that the collision calculation includes the expected tiles
	for tile: Vector2i in expected_present_tiles:
		var is_present: bool = tile_offsets.has(tile)
		print("[TRAPEZOID_TRACE] Expected tile %s present: %s" % [tile, is_present])
	
	for tile: Vector2i in expected_missing_tiles:
		var is_present: bool = tile_offsets.has(tile)
		print("[TRAPEZOID_TRACE] Expected missing tile %s present: %s" % [tile, is_present])
		if is_present:
			print("[TRAPEZOID_TRACE] *** KEY FINDING: Tile %s is calculated but not appearing in runtime!" % tile)

## Test the collision mapping integration specifically  
func test_collision_mapper_integration() -> void:
	print("[MAPPER_TRACE] === COLLISION MAPPER INTEGRATION TEST ===")
	
	# Create trapezoid test object with proper physics body
	var trapezoid_polygon: PackedVector2Array = create_trapezoid_from_runtime()
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = "TrapezoidMapperTest"
	test_object.global_position = TRAPEZOID_POSITION
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = trapezoid_polygon
	collision_shape.shape = shape
	test_object.add_child(collision_shape)
	
	# Add to scene tree
	_env.add_child(test_object)
	auto_free(test_object)
	
	# Get collision shapes
	var owner_shapes: Dictionary = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)
	assert_int(owner_shapes.size()).is_greater(0)
	
	# Create collision test rules
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	var tile_check_rules: Array[TileCheckRule] = [collision_rule]
	
	# Test the collision mapper directly
	print("[MAPPER_TRACE] Testing collision_mapper.map_collision_positions_to_rules")
	
	# Convert owner_shapes.keys() to properly typed Array[Node2D]
	var col_objects: Array[Node2D] = []
	for shape_owner: Node in owner_shapes.keys():
		if shape_owner is Node2D:
			col_objects.append(shape_owner as Node2D)
	
	var position_rules_map: Dictionary = _collision_mapper.map_collision_positions_to_rules(
		col_objects, tile_check_rules
	)
	
	print("[MAPPER_TRACE] Position rules map size: %d" % position_rules_map.size())
	var positions: Array = position_rules_map.keys()
	positions.sort()  # Sort for consistent output
	print("[MAPPER_TRACE] Mapped positions: %s" % str(positions))
	
	# Check for expected positions 
	var expected_extensions: Array[Vector2i] = [
		Vector2i(-2, 1),  # Bottom left that should be mapped
		Vector2i(2, 1)    # Bottom right that should be mapped
	]
	
	for pos: Vector2i in expected_extensions:
		var is_mapped: bool = position_rules_map.has(pos)
		print("[MAPPER_TRACE] Expected extension %s mapped: %s" % [pos, is_mapped])
		if not is_mapped:
			print("[MAPPER_TRACE] *** ISSUE FOUND: Position %s not mapped by collision_mapper!" % pos)

## Test the full indicator generation integration
func test_full_indicator_generation_integration() -> void:
	print("[INTEGRATION_TRACE] === FULL INDICATOR GENERATION INTEGRATION ===")
	
	# Create trapezoid with exact runtime setup
	var trapezoid_polygon: PackedVector2Array = create_trapezoid_from_runtime()
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = "TrapezoidFullTest"
	test_object.global_position = TRAPEZOID_POSITION
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()  
	shape.points = trapezoid_polygon
	collision_shape.shape = shape
	test_object.add_child(collision_shape)
	
	# Add to scene tree
	_env.add_child(test_object)
	auto_free(test_object)
	
	# Set targeting state
	_targeting_state.target = test_object
	_targeting_state.positioner.global_position = TRAPEZOID_POSITION
	
	# Create placement rules
	var collision_rule: CollisionsCheckRule = UnifiedTestFactory.create_test_collisions_check_rule()
	var placement_rules: Array[PlacementRule] = [collision_rule]
	
	# Run the full indicator generation pipeline
	print("[INTEGRATION_TRACE] Running IndicatorManager.try_setup")
	var report: PlacementReport = _indicator_manager.try_setup(placement_rules, _targeting_state, true)
	
	assert_object(report).append_failure_message("PlacementReport is null").is_not_null()
	
	if not report.is_successful():
		print("[INTEGRATION_TRACE] Placement failed with issues: %s" % str(report.get_issues()))
		fail("Placement report indicates failure")
	
	# Get generated indicators
	var indicators: Array[RuleCheckIndicator] = report.indicators_report.indicators
	print("[INTEGRATION_TRACE] Generated indicators count: %d" % indicators.size())
	
	# Extract indicator positions from their names (format: "RuleCheckIndicator-Offset(X,Y)")
	var indicator_positions: Array[Vector2i] = []
	for indicator: RuleCheckIndicator in indicators:
		var name_parts: PackedStringArray = indicator.name.split("-Offset(")
		if name_parts.size() >= 2:
			var offset_str: String = name_parts[1].split(")")[0]
			var offset_parts: PackedStringArray = offset_str.split(",")
			if offset_parts.size() >= 2:
				var offset_x: int = int(offset_parts[0])
				var offset_y: int = int(offset_parts[1])
				var offset: Vector2i = Vector2i(offset_x, offset_y)
				indicator_positions.append(offset)
	
	indicator_positions.sort()  # Sort for consistent output
	print("[INTEGRATION_TRACE] Indicator positions: %s" % str(indicator_positions))
	
	# Check for the missing positions from runtime
	var missing_positions: Array[Vector2i] = [
		Vector2i(-2, 1),  # Bottom left
		Vector2i(2, 1)    # Bottom right
	]
	
	for pos: Vector2i in missing_positions:
		var has_indicator: bool = indicator_positions.has(pos)
		print("[INTEGRATION_TRACE] Position %s has indicator: %s" % [pos, has_indicator])
		
		if not has_indicator:
			print("[INTEGRATION_TRACE] *** RUNTIME ISSUE CONFIRMED: Position %s missing from indicators!" % pos)
		else:
			print("[INTEGRATION_TRACE] *** Position %s correctly generated!" % pos)
	
	# This test should help us identify exactly where the issue occurs
	assert_array(indicators).append_failure_message(
		"No indicators generated for trapezoid shape"
	).is_not_empty()