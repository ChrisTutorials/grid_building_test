## Test suite for GBPlacementPersistence utility class
##
## Tests the metadata-based approach for marking and persisting placed objects.
## This replaces the PlaceableInstance component node with a lightweight metadata solution.
##
## Key functionality tested:
## - Marking objects as placed (metadata setting)
## - Retrieving placement data from marked objects
## - Save/load serialization of placement data
## - Integration with Placeable resources
## - Filtering preview objects during save

extends GdUnitTestSuite

#region TEST CONSTANTS

const TEST_TRANSFORM := Transform2D(0, Vector2(100, 200))
const TEST_OBJECT_NAME := "TestBuilding"

#endregion

#region TEST SETUP

var test_placeable: Placeable
var test_object: Node2D
var test_parent: Node2D


func before_test() -> void:
	# Load test placeable using preloaded constant
	test_placeable = GBTestConstants.PLACEABLE_SMITHY
	assert_object(test_placeable).is_not_null()

	# Create test object hierarchy
	test_parent = auto_free(Node2D.new())
	test_parent.name = "TestParent"
	add_child(test_parent)

	test_object = auto_free(Node2D.new())
	test_object.name = TEST_OBJECT_NAME
	test_object.transform = TEST_TRANSFORM
	test_parent.add_child(test_object)


#endregion

#region MARKING OBJECTS AS PLACED


## Test: mark_as_placed() sets metadata on node
func test_mark_as_placed_sets_metadata() -> void:
	# Act
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Assert
	(
		assert_bool(test_object.has_meta(GBPlacementPersistence.META_KEY)) \
		. append_failure_message(
			"Expected object to have placement metadata after mark_as_placed()"
		) \
		. is_true()
	)


## Test: mark_as_placed() stores placeable path
func test_mark_as_placed_stores_placeable_path() -> void:
	# Act
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Assert
	var placement_data: Dictionary = test_object.get_meta(GBPlacementPersistence.META_KEY)
	(
		assert_str(placement_data.get("placeable_path", "")) \
		. append_failure_message("Placement data should contain placeable_path") \
		. is_equal(test_placeable.resource_path)
	)


## Test: is_placed() returns true for marked objects
func test_is_placed_returns_true_for_marked_objects() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Act & Assert
	(
		assert_bool(GBPlacementPersistence.is_placed(test_object)) \
		. append_failure_message("Expected is_placed() to return true for marked object") \
		. is_true()
	)


## Test: is_placed() returns false for unmarked objects
func test_is_placed_returns_false_for_unmarked_objects() -> void:
	# Act & Assert
	(
		assert_bool(GBPlacementPersistence.is_placed(test_object)) \
		. append_failure_message("Expected is_placed() to return false for unmarked object") \
		. is_false()
	)


## Test: get_placeable() returns correct placeable for marked objects
func test_get_placeable_returns_correct_placeable() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Act
	var retrieved_placeable: Placeable = GBPlacementPersistence.get_placeable(test_object)

	# Assert
	(
		assert_object(retrieved_placeable) \
		. append_failure_message("Expected get_placeable() to return valid Placeable resource") \
		. is_not_null()
	)

	(
		assert_str(retrieved_placeable.resource_path) \
		. append_failure_message(
			"Retrieved placeable should match original placeable resource path"
		) \
		. is_equal(test_placeable.resource_path)
	)


## Test: get_placeable() returns null for unmarked objects
func test_get_placeable_returns_null_for_unmarked_objects() -> void:
	# Act
	var retrieved_placeable: Placeable = GBPlacementPersistence.get_placeable(test_object)

	# Assert
	(
		assert_object(retrieved_placeable) \
		. append_failure_message("Expected get_placeable() to return null for unmarked object") \
		. is_null()
	)


#endregion

#region SAVE FUNCTIONALITY


## Test: save_placement_data() returns dictionary with transform
func test_save_placement_data_includes_transform() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Act
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	# Assert
	(
		assert_bool(save_data.has("transform")) \
		. append_failure_message("Save data should contain transform key") \
		. is_true()
	)

	var saved_transform: Transform2D = str_to_var(save_data["transform"])
	(
		assert_vector(saved_transform.origin) \
		. append_failure_message("Saved transform origin should match object transform") \
		. is_equal(TEST_TRANSFORM.origin)
	)


## Test: save_placement_data() returns dictionary with instance name
func test_save_placement_data_includes_instance_name() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Act
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	# Assert
	(
		assert_str(save_data.get("instance_name", "")) \
		. append_failure_message("Save data should contain instance_name matching object name") \
		. is_equal(TEST_OBJECT_NAME)
	)


## Test: save_placement_data() includes placeable data
func test_save_placement_data_includes_placeable_data() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)

	# Act
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	# Assert
	(
		assert_bool(save_data.has("placeable")) \
		. append_failure_message("Save data should contain placeable resource path") \
		. is_true()
	)

	var placeable_path: String = save_data["placeable"]
	(
		assert_str(placeable_path) \
		. append_failure_message("Placeable path should not be empty") \
		. is_not_empty()
	)

	(
		assert_str(placeable_path) \
		. append_failure_message("Placeable path should be a valid resource path") \
		. starts_with("res://")
	)


## Test: save_placement_data() returns empty dict for unmarked objects
func test_save_placement_data_returns_empty_for_unmarked_objects() -> void:
	# Act
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	# Assert
	(
		assert_int(save_data.size()) \
		. append_failure_message("Save data for unmarked object should be empty") \
		. is_equal(0)
	)


#endregion

#region LOAD FUNCTIONALITY


## Test: instance_from_save() creates new node with correct name
func test_instance_from_save_creates_node_with_correct_name() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	var load_parent: Node2D = auto_free(Node2D.new())
	add_child(load_parent)

	# Act
	var loaded_instance: Node = GBPlacementPersistence.instance_from_save(save_data, load_parent)

	# Assert
	(
		assert_object(loaded_instance) \
		. append_failure_message("instance_from_save() should return valid node") \
		. is_not_null()
	)

	(
		assert_str(loaded_instance.name) \
		. append_failure_message("Loaded instance name should match saved name") \
		. is_equal(TEST_OBJECT_NAME)
	)


## Test: instance_from_save() applies correct transform
func test_instance_from_save_applies_correct_transform() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	var load_parent: Node2D = auto_free(Node2D.new())
	add_child(load_parent)

	# Act
	var loaded_instance: Node = GBPlacementPersistence.instance_from_save(save_data, load_parent)

	# Assert
	(
		assert_vector(loaded_instance.transform.origin) \
		. append_failure_message("Loaded instance transform should match saved transform") \
		. is_equal(TEST_TRANSFORM.origin)
	)


## Test: instance_from_save() marks instance as placed with metadata
func test_instance_from_save_marks_instance_as_placed() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	var load_parent: Node2D = auto_free(Node2D.new())
	add_child(load_parent)

	# Act
	var loaded_instance: Node = GBPlacementPersistence.instance_from_save(save_data, load_parent)

	# Assert
	(
		assert_bool(GBPlacementPersistence.is_placed(loaded_instance)) \
		. append_failure_message("Loaded instance should be marked as placed") \
		. is_true()
	)


## Test: instance_from_save() adds instance to parent
func test_instance_from_save_adds_instance_to_parent() -> void:
	# Arrange
	GBPlacementPersistence.mark_as_placed(test_object, test_placeable)
	var save_data: Dictionary = GBPlacementPersistence.save_placement_data(test_object)

	var load_parent: Node2D = auto_free(Node2D.new())
	add_child(load_parent)
	var initial_child_count: int = load_parent.get_child_count()

	# Act
	var loaded_instance: Node = GBPlacementPersistence.instance_from_save(save_data, load_parent)

	# Assert
	(
		assert_int(load_parent.get_child_count()) \
		. append_failure_message(
			"Parent should have one additional child after instance_from_save()"
		) \
		. is_equal(initial_child_count + 1)
	)

	(
		assert_object(loaded_instance.get_parent()) \
		. append_failure_message("Loaded instance parent should be the provided parent node") \
		. is_same(load_parent)
	)


## Test: instance_from_save() returns null for invalid save data
func test_instance_from_save_returns_null_for_invalid_data() -> void:
	# Arrange
	var invalid_save_data: Dictionary = {"invalid": "data"}
	var load_parent: Node2D = auto_free(Node2D.new())
	add_child(load_parent)

	var loaded_instance: Node = null

	# Act & Assert: Verify push_error is called and function returns null
	await (
		assert_error(
			func():
				loaded_instance = GBPlacementPersistence.instance_from_save(
					invalid_save_data, load_parent
				)
		) \
		. is_push_error("GBPlacementPersistence: Save data missing placeable information")
	)

	# Verify function returned null
	(
		assert_object(loaded_instance) \
		. append_failure_message("instance_from_save() should return null for invalid save data") \
		. is_null()
	)


#endregion

#region PREVIEW OBJECT FILTERING


## Test: is_preview() returns true for objects with gb_preview metadata
func test_is_preview_returns_true_for_preview_objects() -> void:
	# Arrange
	test_object.set_meta("gb_preview", true)

	# Act & Assert
	(
		assert_bool(GBPlacementPersistence.is_preview(test_object)) \
		. append_failure_message(
			"Expected is_preview() to return true for object with gb_preview metadata"
		) \
		. is_true()
	)


## Test: is_preview() returns false for regular objects
func test_is_preview_returns_false_for_regular_objects() -> void:
	# Act & Assert
	(
		assert_bool(GBPlacementPersistence.is_preview(test_object)) \
		. append_failure_message(
			"Expected is_preview() to return false for object without gb_preview metadata"
		) \
		. is_false()
	)


## Test: get_placed_objects() excludes preview objects
func test_get_placed_objects_excludes_preview_objects() -> void:
	# Arrange
	var placed_object: Node2D = auto_free(Node2D.new())
	test_parent.add_child(placed_object)
	GBPlacementPersistence.mark_as_placed(placed_object, test_placeable)

	var preview_object: Node2D = auto_free(Node2D.new())
	test_parent.add_child(preview_object)
	GBPlacementPersistence.mark_as_placed(preview_object, test_placeable)
	preview_object.set_meta("gb_preview", true)

	# Act
	var placed_objects: Array[Node] = GBPlacementPersistence.get_placed_objects(test_parent)

	# Assert
	(
		assert_int(placed_objects.size()) \
		. append_failure_message(
			"get_placed_objects() should return only non-preview placed objects"
		) \
		. is_equal(1)
	)

	(
		assert_object(placed_objects[0]) \
		. append_failure_message("Returned object should be the non-preview placed object") \
		. is_same(placed_object)
	)


#endregion

#region BATCH OPERATIONS


## Test: get_placed_objects() returns all placed objects in hierarchy
func test_get_placed_objects_returns_all_placed_objects() -> void:
	# Arrange
	var placed_count: int = 3
	for i in range(placed_count):
		var placed_obj: Node2D = auto_free(Node2D.new())
		placed_obj.name = "PlacedObject%d" % i
		test_parent.add_child(placed_obj)
		GBPlacementPersistence.mark_as_placed(placed_obj, test_placeable)

	# Act
	var placed_objects: Array[Node] = GBPlacementPersistence.get_placed_objects(test_parent)

	# Assert
	(
		assert_int(placed_objects.size()) \
		. append_failure_message(
			"Expected get_placed_objects() to return all %d placed objects" % placed_count
		) \
		. is_equal(placed_count)
	)


## Test: save_all_placements() returns array of save data
func test_save_all_placements_returns_array_of_save_data() -> void:
	# Arrange
	var placed_count: int = 2
	for i in range(placed_count):
		var placed_obj: Node2D = auto_free(Node2D.new())
		placed_obj.name = "PlacedObject%d" % i
		test_parent.add_child(placed_obj)
		GBPlacementPersistence.mark_as_placed(placed_obj, test_placeable)

	# Act
	var save_data_array: Array[Dictionary] = GBPlacementPersistence.save_all_placements(test_parent)

	# Assert
	(
		assert_int(save_data_array.size()) \
		. append_failure_message(
			"Expected save_all_placements() to return %d save data entries" % placed_count
		) \
		. is_equal(placed_count)
	)

	for save_data in save_data_array:
		(
			assert_bool(save_data.has("instance_name")) \
			. append_failure_message("Each save data entry should have instance_name") \
			. is_true()
		)


## Test: load_all_placements() recreates all placed objects
func test_load_all_placements_recreates_all_placed_objects() -> void:
	# Arrange
	var placed_count: int = 2
	for i in range(placed_count):
		var placed_obj: Node2D = auto_free(Node2D.new())
		placed_obj.name = "PlacedObject%d" % i
		test_parent.add_child(placed_obj)
		GBPlacementPersistence.mark_as_placed(placed_obj, test_placeable)

	var save_data_array: Array[Dictionary] = GBPlacementPersistence.save_all_placements(test_parent)

	var load_parent: Node2D = auto_free(Node2D.new())
	add_child(load_parent)

	# Act
	var loaded_instances: Array[Node] = GBPlacementPersistence.load_all_placements(
		save_data_array, load_parent
	)

	# Assert
	(
		assert_int(loaded_instances.size()) \
		. append_failure_message(
			"Expected load_all_placements() to return %d loaded instances" % placed_count
		) \
		. is_equal(placed_count)
	)

	(
		assert_int(load_parent.get_child_count()) \
		. append_failure_message("Load parent should have %d children after loading" % placed_count) \
		. is_equal(placed_count)
	)

#endregion
