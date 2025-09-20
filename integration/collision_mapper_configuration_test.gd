## Integration test specifically focused on collision mapper configuration issues
## This test isolates the problem where collision geometry calculation works correctly
## but the collision mapper fails to generate indicators for calculated tile positions
extends GdUnitTestSuite

var _env: BuildingTestEnvironment
var _collision_mapper: CollisionMapper
var _targeting_state: GridTargetingState
var _indicator_manager: IndicatorManager

func before_test() -> void:
	_env = EnvironmentTestFactory.create_building_system_test_environment(self)
	_collision_mapper = _env.indicator_manager.get_collision_mapper()
	_targeting_state = _env.grid_targeting_system.get_state()
	_indicator_manager = _env.indicator_manager
	
	# Validate basic environment setup
	assert_object(_collision_mapper).is_not_null()
	assert_object(_targeting_state).is_not_null()
	assert_object(_indicator_manager).is_not_null()
	
	print("[CONFIG_TRACE] Environment setup complete")
	print("[CONFIG_TRACE] CollisionMapper class: %s" % _collision_mapper.get_class())
	print("[CONFIG_TRACE] IndicatorManager class: %s" % _indicator_manager.get_class())

## Test collision mapper initialization and configuration
func test_collision_mapper_initialization() -> void:
	print("[CONFIG_TRACE] === COLLISION MAPPER INITIALIZATION TEST ===")
	
	# Check if collision mapper has required dependencies
	var has_test_indicator: bool = _collision_mapper.get("test_indicator") != null
	var has_test_setups: bool = _collision_mapper.get("test_setups") != null
	
	print("[CONFIG_TRACE] Collision mapper has test_indicator: %s" % has_test_indicator)
	print("[CONFIG_TRACE] Collision mapper has test_setups: %s" % has_test_setups)
	
	# Check collision mapper internal state
	if _collision_mapper.has_method("get_test_setups"):
		var test_setups: Array = _collision_mapper.get_test_setups()
		var count_str: String = str(test_setups.size()) if test_setups != null else "null"
		print("[CONFIG_TRACE] Test setups count: %s" % count_str)
	else:
		print("[CONFIG_TRACE] CollisionMapper missing get_test_setups method")
	
	# Check if collision mapper is properly initialized
	if _collision_mapper.has_method("is_initialized"):
		var is_initialized: bool = _collision_mapper.is_initialized()
		print("[CONFIG_TRACE] CollisionMapper initialized: %s" % is_initialized)
		if not is_initialized:
			print("[CONFIG_TRACE] *** ISSUE: CollisionMapper not initialized!")
	else:
		print("[CONFIG_TRACE] CollisionMapper missing is_initialized method")

## Test collision mapper with minimal configuration
func test_collision_mapper_minimal_setup() -> void:
	print("[CONFIG_TRACE] === MINIMAL COLLISION MAPPER SETUP TEST ===")
	
	# Create minimal test object
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = "MinimalTestObject"
	test_object.global_position = Vector2(100, 100)
	
	# Add simple square collision shape
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision_shape.shape = shape
	test_object.add_child(collision_shape)
	
	_env.add_child(test_object)
	auto_free(test_object)
	
	# Set targeting state
	_targeting_state.target = test_object
	_targeting_state.positioner.global_position = test_object.global_position
	
	print("[CONFIG_TRACE] Test object created at position: %s" % test_object.global_position)
	
	# Try to initialize collision mapper if method exists
	if _collision_mapper.has_method("initialize"):
		_collision_mapper.initialize()
		print("[CONFIG_TRACE] Called collision_mapper.initialize()")
	
	# Test collision mapping with correct parameters
	var col_objects: Array[Node2D] = [test_object]
	var tile_check_rules: Array[TileCheckRule] = []  # Empty rules for minimal test
	
	var position_rules: Dictionary = _collision_mapper.map_collision_positions_to_rules(col_objects, tile_check_rules)
	print("[CONFIG_TRACE] Position rules result: %s" % position_rules)
	print("[CONFIG_TRACE] Position rules type: %s" % type_string(typeof(position_rules)))
	
	if position_rules is Dictionary:
		print("[CONFIG_TRACE] Position rules keys: %s" % position_rules.keys())
		print("[CONFIG_TRACE] Position rules size: %d" % position_rules.size())
	else:
		print("[CONFIG_TRACE] Position rules is not a Dictionary!")
	
	# Check if any positions were mapped
	var has_mappings: bool = false
	if position_rules is Dictionary and position_rules.size() > 0:
		has_mappings = true
		print("[CONFIG_TRACE] ✓ Collision mapping successful with %d positions" % position_rules.size())
	else:
		print("[CONFIG_TRACE] ✗ Collision mapping failed - no positions mapped")
	
	# This should pass if collision mapper is working at all
	assert_bool(has_mappings).is_true().append_failure_message(
		"CollisionMapper should map at least one position for a simple square shape"
	)

## Test collision mapper configuration requirements
func test_collision_mapper_configuration_requirements() -> void:
	print("[CONFIG_TRACE] === COLLISION MAPPER CONFIGURATION REQUIREMENTS TEST ===")
	
	# Check what's needed for collision mapper to work
	var required_properties: Array[String] = ["test_indicator", "test_setups"]
	var missing_properties: Array[String] = []
	
	for prop: String in required_properties:
		if _collision_mapper.get(prop) == null:
			missing_properties.append(prop)
			print("[CONFIG_TRACE] Missing required property: %s" % prop)
		else:
			print("[CONFIG_TRACE] Has required property: %s" % prop)
	
	# Try to configure collision mapper with required properties
	if "test_indicator" in missing_properties:
		print("[CONFIG_TRACE] Attempting to create test_indicator...")
		# Try to create a test indicator if possible
		if _collision_mapper.has_method("set_test_indicator"):
			# Create a mock indicator
			var mock_indicator: Node2D = Node2D.new()
			mock_indicator.name = "MockTestIndicator"
			_collision_mapper.set_test_indicator(mock_indicator)
			print("[CONFIG_TRACE] Set mock test_indicator")
		else:
			print("[CONFIG_TRACE] CollisionMapper missing set_test_indicator method")
	
	if "test_setups" in missing_properties:
		print("[CONFIG_TRACE] Attempting to create test_setups...")
		if _collision_mapper.has_method("set_test_setups"):
			# Create minimal test setups array
			var mock_setups: Array = []
			_collision_mapper.set_test_setups(mock_setups)
			print("[CONFIG_TRACE] Set empty test_setups array")
		else:
			print("[CONFIG_TRACE] CollisionMapper missing set_test_setups method")
	
	# Report configuration status
	if missing_properties.is_empty():
		print("[CONFIG_TRACE] ✓ All required properties configured")
	else:
		print("[CONFIG_TRACE] ✗ Still missing properties: %s" % missing_properties)

## Test creating proper collision mapper configuration
func test_proper_collision_mapper_setup() -> void:
	print("[CONFIG_TRACE] === PROPER COLLISION MAPPER SETUP TEST ===")
	
	# Create test object with trapezoid shape (our problem case)
	var trapezoid_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	
	var test_object: StaticBody2D = StaticBody2D.new()
	test_object.name = "ProperTestObject"  
	test_object.global_position = Vector2(440, 552)
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = trapezoid_polygon
	collision_shape.shape = shape
	test_object.add_child(collision_shape)
	
	_env.add_child(test_object)
	auto_free(test_object)
	
	# Set targeting state
	_targeting_state.target = test_object
	_targeting_state.positioner.global_position = test_object.global_position
	
	print("[CONFIG_TRACE] Created trapezoid test object at: %s" % test_object.global_position)
	
	# Calculate expected tiles using CollisionGeometryUtils (our verified working calculation)
	var tile_size: Vector2 = Vector2(16, 16)
	var center_tile: Vector2i = Vector2i(int(test_object.global_position.x / tile_size.x), int(test_object.global_position.y / tile_size.y))
	
	var world_polygon: PackedVector2Array = PackedVector2Array()
	for point in trapezoid_polygon:
		world_polygon.append(point + test_object.global_position)
	
	var expected_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		world_polygon, tile_size, center_tile
	)
	
	print("[CONFIG_TRACE] Expected tile offsets (from CollisionGeometryUtils): %s" % expected_offsets)
	print("[CONFIG_TRACE] Expected tile count: %d" % expected_offsets.size())
	
	# Test collision mapping with correct parameters
	var col_objects: Array[Node2D] = [test_object] 
	var tile_check_rules: Array[TileCheckRule] = []  # Empty rules for now
	
	var position_rules: Dictionary = _collision_mapper.map_collision_positions_to_rules(col_objects, tile_check_rules)
	
	print("[CONFIG_TRACE] CollisionMapper position_rules type: %s" % type_string(typeof(position_rules)))
	var size_str: String = str(position_rules.size()) if position_rules is Dictionary else "not_dict"
	print("[CONFIG_TRACE] CollisionMapper position_rules size: %s" % size_str)
	
	var mapped_positions: Array[Vector2i] = []
	if position_rules is Dictionary:
		for pos: Variant in position_rules.keys():
			if pos is Vector2i:
				mapped_positions.append(pos)
			else:
				print("[CONFIG_TRACE] Non-Vector2i position key: %s (type: %s)" % [pos, type_string(typeof(pos))])
	
	print("[CONFIG_TRACE] CollisionMapper mapped positions: %s" % mapped_positions)
	print("[CONFIG_TRACE] CollisionMapper mapped count: %d" % mapped_positions.size())
	
	# Compare collision mapper results vs expected
	var missing_positions: Array[Vector2i] = []
	var expected_positions: Array[Vector2i] = []
	
	# Convert expected offsets to absolute positions
	for offset in expected_offsets:
		expected_positions.append(center_tile + offset)
	
	print("[CONFIG_TRACE] Expected absolute positions: %s" % expected_positions)
	
	# Find missing positions
	for expected_pos in expected_positions:
		if not mapped_positions.has(expected_pos):
			missing_positions.append(expected_pos)
	
	print("[CONFIG_TRACE] Missing positions: %s" % missing_positions)
	
	# Report the discrepancy
	if missing_positions.is_empty():
		print("[CONFIG_TRACE] ✓ All expected positions mapped by CollisionMapper")
	else:
		print("[CONFIG_TRACE] ✗ CollisionMapper missing %d positions: %s" % [missing_positions.size(), missing_positions])
		
		# Specifically check for our problem tiles
		var problem_offsets: Array[Vector2i] = [Vector2i(-2, 1), Vector2i(2, 1)]  # Bottom corners
		for offset: Vector2i in problem_offsets:
			var problem_pos: Vector2i = center_tile + offset
			if missing_positions.has(problem_pos):
				print("[CONFIG_TRACE] *** CONFIRMED: Problem tile %s (offset %s) missing from CollisionMapper!" % [problem_pos, offset])
	
	# Test should highlight the configuration issue
	assert_int(missing_positions.size()).append_failure_message(
		"CollisionMapper should map all %d expected positions but is missing %d: %s" % [expected_positions.size(), missing_positions.size(), str(missing_positions)]
	).is_equal(0)
