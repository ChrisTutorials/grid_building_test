## Unit tests for CollisionTestSetup2D creation and dependency isolation.
##
## Isolates CollisionTestSetup2D creation issues and tests the lowest level
## dependency that's causing collision mapper tests to fail.

extends GdUnitTestSuite

# Constants
const TEST_TILE_SIZE := Vector2(16, 16)
const DEBUG_PREFIX := "DEBUG: "

func before_test() -> void:
	pass

# Helper: Create a StaticBody2D with CollisionShape2D and RectangleShape2D
func _create_body_with_rectangle_shape(size: Vector2 = TEST_TILE_SIZE) -> StaticBody2D:
	var body := StaticBody2D.new()
	auto_free(body)
	add_child(body)

	var shape := CollisionShape2D.new()
	auto_free(shape)
	var rect := RectangleShape2D.new()
	auto_free(rect)
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	return body

# Helper: Create empty StaticBody2D for testing
func _create_empty_body() -> StaticBody2D:
	var body := StaticBody2D.new()
	auto_free(body)
	add_child(body)
	return body

# Helper: Create a minimal test setup and validate it
func _create_minimal_test_setup(body: StaticBody2D, tile_size: Vector2 = TEST_TILE_SIZE) -> CollisionTestSetup2D:
	var test_setup: CollisionTestSetup2D = CollisionTestSetup2D.new(body, tile_size)
	test_setup.validate_setup()
	return test_setup

# Test: CollisionTestSetup2D creation with CollisionShape2D
func test_indicator_collision_test_setup_creation() -> void:
	# Create a StaticBody2D with CollisionShape2D
	var body := _create_body_with_rectangle_shape()

	# Create test setup
	var test_setup := _create_minimal_test_setup(body)

	# This should pass if the setup is working correctly
	assert_that(test_setup.validate_setup()).append_failure_message("CollisionTestSetup2D should validate successfully with proper collision shapes").is_true()
	assert_that(test_setup.rect_collision_test_setups.size()).append_failure_message("Expected at least one rect collision test setup").is_not_equal(0)

# Test: CollisionTestSetup2D with no shapes (should fail gracefully)
func test_indicator_collision_test_setup_empty_body() -> void:
	var body := _create_empty_body()

	var test_setup := _create_minimal_test_setup(body)

	var is_valid: bool = test_setup.validate_setup()
	assert_that(is_valid).append_failure_message("Empty body should fail validation").is_false()
	assert_that(test_setup.issues.size()).append_failure_message("Validation should produce issues for empty body").is_not_equal(0)

# Test: create_test_setups_for_collision_owners with valid collision object
func test_create_test_setups_for_collision_owners_with_valid_object() -> void:
	var body := _create_body_with_rectangle_shape()
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())

	# Set up the targeting state with the premade 31x31 test tilemap
	var test_map_scene: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var test_map := test_map_scene.instantiate() as TileMapLayer
	add_child(test_map)
	auto_free(test_map)
	targeting_state.target_map = test_map
	targeting_state.maps = [test_map]

	# Create owner_shapes dictionary manually
	var owner_shapes: Dictionary[Node2D, Array] = {}
	var shapes: Array[Shape2D] = []
	for child in body.get_children():
		if child is CollisionShape2D and child.shape:
			shapes.append(child.shape)
	owner_shapes[body] = shapes

	var owner_collision_setups: Dictionary[Node2D, CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_for_collision_owners(owner_shapes, targeting_state)

	assert_that(owner_collision_setups.size()).append_failure_message("Expected at least one test setup for valid collision object").is_greater(0)
	(
		assert_that(owner_collision_setups.has(body)) \
		. append_failure_message("Expected body to be in setups dictionary") \
		. is_true()
	)
	assert_that(owner_collision_setups[body]).append_failure_message("Expected non-null setup for body").is_not_null()
	assert_that(owner_collision_setups[body] is CollisionTestSetup2D).append_failure_message("Expected setup to be CollisionTestSetup2D instance").is_true()

# Test: create_test_setups_for_collision_owners with empty dictionary
func test_create_test_setups_for_collision_owners_empty() -> void:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())

	# Set up the targeting state with the premade 31x31 test tilemap
	var test_map_scene: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var test_map := test_map_scene.instantiate() as TileMapLayer
	add_child(test_map)
	auto_free(test_map)
	targeting_state.target_map = test_map
	targeting_state.maps = [test_map]

	var owner_shapes: Dictionary[Node2D, Array] = {}

	var owner_collision_setups: Dictionary[Node2D, CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_for_collision_owners(owner_shapes, targeting_state)

	(
		assert_that(owner_collision_setups.size()) \
		. append_failure_message("Expected empty setups dictionary for empty owner_shapes") \
		. is_equal(0)
	)

# Test: create_test_setups_from_test_node with valid collision object
func test_create_test_setups_from_test_node_with_valid_object() -> void:
	var body := _create_body_with_rectangle_shape()
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())

	# Set up the targeting state with the premade 31x31 test tilemap
	var test_map_scene: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var test_map := test_map_scene.instantiate() as TileMapLayer
	add_child(test_map)
	auto_free(test_map)
	targeting_state.target_map = test_map
	targeting_state.maps = [test_map]

	var node_collision_setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(body, targeting_state)

	assert_that(node_collision_setups.size()).append_failure_message("Expected at least one setup from valid test node").is_greater(0)
	# Should have at least one setup for the body itself or its collision shapes
	var has_valid_setup := false
	for setup: CollisionTestSetup2D in node_collision_setups:
		if setup is CollisionTestSetup2D:
			has_valid_setup = true
			break
	assert_that(has_valid_setup).append_failure_message("Expected at least one valid CollisionTestSetup2D in setups array").is_true()

# Test: create_test_setups_from_test_node with empty body
func test_create_test_setups_from_test_node_empty_body() -> void:
	var body := _create_empty_body()
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())

	# Set up the targeting state with the premade 31x31 test tilemap
	var test_map_scene: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var test_map := test_map_scene.instantiate() as TileMapLayer
	add_child(test_map)
	auto_free(test_map)
	targeting_state.target_map = test_map
	targeting_state.maps = [test_map]

	var node_collision_setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(body, targeting_state)

	# Even with no collision shapes, should return a dictionary (possibly empty or with null values)
	assert_that(node_collision_setups).append_failure_message("Expected non-null setups array even for empty body").is_not_null()

# Test: create_test_setups_from_test_node with null node (should handle gracefully)
func test_create_test_setups_from_test_node_null_input() -> void:
	var targeting_state := GridTargetingState.new(GBOwnerContext.new())

	# Set up the targeting state with a tile map
	# Set up the targeting state with the canonical premade 31x31 test tilemap
	var test_map_scene: PackedScene = GBTestConstants.TEST_TILE_MAP_LAYER_BUILDABLE
	var test_map := test_map_scene.instantiate() as TileMapLayer
	add_child(test_map)
	auto_free(test_map)
	targeting_state.target_map = test_map
	targeting_state.maps = [test_map]

	# This should not crash and should handle null input gracefully
	var node_collision_setups: Array[CollisionTestSetup2D] = CollisionTestSetup2D.create_test_setups_from_test_node(null, targeting_state)

	# Should return empty dictionary for null input
	assert_that(node_collision_setups.size()).append_failure_message(
		"Expected empty array for null input"
	).is_equal(0)
