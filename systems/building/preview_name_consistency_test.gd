# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite for issue #10: Preview loses root scene name when setting same placeable twice

var system: BuildingSystem
var targeting_state: GridTargetingState
var mode_state: ModeState
var placer: Node2D
var placed_parent: Node2D
var _container: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var placeable_2d_test: Placeable = load("uid://jgmywi04ib7c")


func before_test():
	# Create scene nodes
	placer = GodotTestFactory.create_node2d(self)
	placed_parent = GodotTestFactory.create_node2d(self)
	var grid_positioner = GodotTestFactory.create_node2d(self)
	var map_layer = GodotTestFactory.create_tile_map_layer(self)

	# Access shared states from the pre-configured test container (do NOT auto_free)
	var states := _container.get_states()
	targeting_state = states.targeting
	targeting_state.positioner = grid_positioner
	targeting_state.target_map = map_layer
	targeting_state.maps = [map_layer]
	mode_state = states.mode

	# Proper owner setup: create a GBOwner node and resolve dependencies so the container's
	# owner context (and thus BuildingState._owner_context) has a valid owner_root
	var gb_owner := GBOwner.new(placer)
	add_child(gb_owner)
	gb_owner.resolve_gb_dependencies(_container)

	# Build system with injected dependencies
	system = auto_free(BuildingSystem.create_with_injection(_container))
	add_child(system)

	# Assign placed_parent so built instances have a parent
	states.building.placed_parent = placed_parent


func test_same_placeable_twice_preserves_name():
	# Test issue #10: When the same placeable is set twice in a row
	# via enter_build_mode, the preview instance should retain the
	# root PackedScene's name consistently.

	var expected_name = placeable_2d_test.get_packed_root_name()

	# First call to enter_build_mode
	var success1 = system.enter_build_mode(placeable_2d_test)
	assert_bool(success1).is_true()

	var preview1 = _container.get_states().building.preview
	assert_object(preview1).is_not_null()
	assert_str(preview1.name).is_equal(expected_name)

	# Second call to enter_build_mode with same placeable
	var success2 = system.enter_build_mode(placeable_2d_test)
	assert_bool(success2).is_true()

	var preview2 = _container.get_states().building.preview
	assert_object(preview2).is_not_null()
	(
		assert_str(preview2.name)
		. override_failure_message(
			(
				"Preview name should remain '%s' but got '%s' on second assignment"
				% [expected_name, preview2.name]
			)
		)
		. is_equal(expected_name)
	)

	# Ensure it's a different instance (not the same object)
	assert_object(preview2).is_not_same(preview1)


func test_different_placeables_have_correct_names():
	# Verify that different placeables get their correct names
	var placeable1 = placeable_2d_test
	var placeable2 = TestSceneLibrary.placeable_eclipse

	var expected_name1 = placeable1.get_packed_root_name()
	var expected_name2 = placeable2.get_packed_root_name()

	# Set first placeable
	system.enter_build_mode(placeable1)
	var preview1 = _container.get_states().building.preview
	assert_str(preview1.name).is_equal(expected_name1)

	# Set second placeable
	system.enter_build_mode(placeable2)
	var preview2 = _container.get_states().building.preview
	assert_str(preview2.name).is_equal(expected_name2)

	# Set first placeable again
	system.enter_build_mode(placeable1)
	var preview3 = _container.get_states().building.preview
	assert_str(preview3.name).is_equal(expected_name1)
