extends GdUnitTestSuite

## Unit tests for PlaceableSequenceFactory utility class
## Tests factory methods for sequence creation and normalization

var test_placeable_1: Placeable
var test_placeable_2: Placeable
var test_placeable_3: Placeable
var test_sequence_1: PlaceableSequence
var test_sequence_2: PlaceableSequence

func before_test() -> void:
	# Create test placeables with valid packed scenes
	var simple_scene: PackedScene = PackedScene.new()

	test_placeable_1 = Placeable.new()
	test_placeable_1.display_name = "Basic Tower"
	test_placeable_1.packed_scene = simple_scene

	test_placeable_2 = Placeable.new()
	test_placeable_2.display_name = "Heavy Tower"
	test_placeable_2.packed_scene = simple_scene

	test_placeable_3 = Placeable.new()
	test_placeable_3.display_name = "Rapid Tower"
	test_placeable_3.packed_scene = simple_scene

	# Create test sequences
	test_sequence_1 = PlaceableSequence.new()
	test_sequence_1.display_name = "Defense Towers"
	test_sequence_1.placeables = [test_placeable_1, test_placeable_2]

	test_sequence_2 = PlaceableSequence.new()
	test_sequence_2.display_name = "Support Buildings"
	test_sequence_2.placeables = [test_placeable_3]

func after_test() -> void:
	test_placeable_1 = null
	test_placeable_2 = null
	test_placeable_3 = null
	test_sequence_1 = null
	test_sequence_2 = null

#region FROM_PLACEABLES TESTS

func test_from_placeables_basic_conversion() -> void:
	var placeables: Array[Placeable] = [test_placeable_1, test_placeable_2, test_placeable_3]
	var result: Array[PlaceableSequence] = PlaceableSequenceFactory.from_placeables(placeables)

	# Should create one sequence per placeable
	assert_int(result.size()).append_failure_message(
		"from_placeables should create %d sequences, created %d" % [placeables.size(), result.size()]
	).is_equal(placeables.size())

	# Each sequence should contain one placeable with preserved display name
	for i in range(result.size()):
		var sequence: PlaceableSequence = result[i]
		var original_placeable: Placeable = placeables[i]

		assert_str(sequence.display_name).append_failure_message(
			"Sequence %d display name should match original placeable" % i
		).is_equal(original_placeable.display_name)

		assert_int(sequence.placeables.size()).append_failure_message(
			"Sequence %d should contain exactly 1 placeable" % i
		).is_equal(1)

		assert_object(sequence.placeables[0]).append_failure_message(
			"Sequence %d should contain the original placeable" % i
		).is_same(original_placeable)

@warning_ignore("unused_parameter")
func test_from_placeables_scenarios(
	setup_description: String,
	input_count: int,
	null_count: int,
	expected_output_count: int,
	test_parameters := [
		# [setup_description, input_count, null_count, expected_output_count]
		["empty_array", 0, 0, 0],
		["single_placeable", 1, 0, 1],
		["multiple_placeables", 3, 0, 3],
		["with_nulls_filtered", 3, 2, 3],
		["all_nulls", 0, 3, 0],
		["mixed_valid_and_null", 2, 1, 2],
	]
) -> void:
	var input_placeables: Array[Placeable] = []

	# Add valid placeables
	var available_placeables: Array[Placeable] = [test_placeable_1, test_placeable_2, test_placeable_3]
	for i in range(input_count):
		input_placeables.append(available_placeables[i % available_placeables.size()])

	# Add nulls
	for i in range(null_count):
		input_placeables.append(null)

	var result: Array[PlaceableSequence] = PlaceableSequenceFactory.from_placeables(input_placeables)

	assert_int(result.size()).append_failure_message(
		"from_placeables with setup '%s' should produce %d sequences, got %d" %
		[setup_description, expected_output_count, result.size()]
	).is_equal(expected_output_count)

	# Verify all results are valid sequences with single placeables
	for i in range(result.size()):
		var sequence: PlaceableSequence = result[i]
		assert_int(sequence.placeables.size()).append_failure_message(
			"Converted sequence %d should contain exactly 1 placeable" % i
		).is_equal(1)
		assert_object(sequence.placeables[0]).append_failure_message(
			"Converted sequence %d should contain non-null placeable" % i
		).is_not_null()

#endregion

#region ENSURE_SEQUENCES TESTS

func test_ensure_sequences_preserves_existing_sequences() -> void:
	var mixed_input: Array = [test_sequence_1, test_placeable_1, test_sequence_2]
	var result: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(mixed_input)

	assert_int(result.size()).append_failure_message(
		"ensure_sequences should preserve all valid items: input %d, output %d" %
		[mixed_input.size(), result.size()]
	).is_equal(mixed_input.size())

	# First item should be preserved sequence
	assert_object(result[0]).append_failure_message(
		"First result should be the same PlaceableSequence object"
	).is_same(test_sequence_1)

	# Second item should be converted placeable
	assert_str(result[1].display_name).append_failure_message(
		"Second result should be converted placeable with preserved name"
	).is_equal(test_placeable_1.display_name)
	assert_int(result[1].placeables.size()).append_failure_message(
		"Converted placeable sequence should contain exactly one placeable"
	).is_equal(1)
	assert_object(result[1].placeables[0]).append_failure_message(
		"Converted placeable sequence should contain the original placeable"
	).is_same(test_placeable_1)

	# Third item should be preserved sequence
	assert_object(result[2]).append_failure_message(
		"Third result should be the same PlaceableSequence object"
	).is_same(test_sequence_2)

@warning_ignore("unused_parameter")
func test_ensure_sequences_scenarios(
	setup_description: String,
	sequence_count: int,
	placeable_count: int,
	null_count: int,
	other_type_count: int,
	expected_output_count: int,
	test_parameters := [
		# [setup_description, sequences, placeables, nulls, others, expected_output]
		["empty_array", 0, 0, 0, 0, 0],
		["only_sequences", 2, 0, 0, 0, 2],
		["only_placeables", 0, 3, 0, 0, 3],
		["mixed_sequences_and_placeables", 1, 2, 0, 0, 3],
		["with_nulls_filtered", 1, 1, 2, 0, 2],
		["with_other_types_ignored", 1, 1, 0, 2, 2],
		["complex_mixed", 2, 2, 1, 1, 4],
	]
) -> void:
	var mixed_input: Array = []

	# Add sequences
	var available_sequences: Array[PlaceableSequence] = [test_sequence_1, test_sequence_2]
	for i in range(sequence_count):
		mixed_input.append(available_sequences[i % available_sequences.size()])

	# Add placeables
	var available_placeables: Array[Placeable] = [test_placeable_1, test_placeable_2, test_placeable_3]
	for i in range(placeable_count):
		mixed_input.append(available_placeables[i % available_placeables.size()])

	# Add nulls
	for i in range(null_count):
		mixed_input.append(null)

	# Add other types (should be ignored)
	for i in range(other_type_count):
		mixed_input.append("string")  # Random other type

	var result: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(mixed_input)

	assert_int(result.size()).append_failure_message(
		"ensure_sequences with setup '%s' should produce %d sequences, got %d" %
		[setup_description, expected_output_count, result.size()]
	).is_equal(expected_output_count)

	# Verify all results are PlaceableSequence objects
	for i in range(result.size()):
		assert_bool(result[i] is PlaceableSequence).append_failure_message(
			"Result item %d should be PlaceableSequence, got %s" % [i, str(result[i].get_class())]
		).is_true()

func test_ensure_sequences_preserves_original_properties() -> void:
	var original_placeable: Placeable = test_placeable_1
	var mixed_input: Array = [original_placeable]

	var result: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(mixed_input)
	var converted_sequence: PlaceableSequence = result[0]

	# Properties should be preserved during conversion
	assert_str(converted_sequence.display_name).append_failure_message(
		"Converted sequence should preserve original display name"
	).is_equal(original_placeable.display_name)

	assert_int(converted_sequence.placeables.size()).append_failure_message(
		"Converted sequence should contain exactly 1 placeable"
	).is_equal(1)

	assert_object(converted_sequence.placeables[0]).append_failure_message(
		"Converted sequence should contain the original placeable object"
	).is_same(original_placeable)

#endregion

#region EDGE CASE TESTS

func test_null_and_empty_input_handling() -> void:
	# Test empty arrays
	var empty_placeables: Array[Placeable] = []
	var empty_result: Array[PlaceableSequence] = PlaceableSequenceFactory.from_placeables(empty_placeables)
	assert_array(empty_result).append_failure_message(
		"from_placeables with empty array should return empty result"
	).is_empty()

	var empty_mixed: Array = []
	var empty_mixed_result: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(empty_mixed)
	assert_array(empty_mixed_result).append_failure_message(
		"ensure_sequences with empty array should return empty result"
	).is_empty()

	# Test arrays with only nulls
	var only_nulls: Array[Placeable] = [null, null, null]
	var null_result: Array[PlaceableSequence] = PlaceableSequenceFactory.from_placeables(only_nulls)
	assert_array(null_result).append_failure_message(
		"from_placeables with only nulls should return empty result"
	).is_empty()

	var mixed_nulls: Array = [null, null]
	var mixed_null_result: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(mixed_nulls)
	assert_array(mixed_null_result).append_failure_message(
		"ensure_sequences with only nulls should return empty result"
	).is_empty()

func test_large_array_performance() -> void:
	# Test with larger arrays to ensure reasonable performance
	var large_placeable_array: Array[Placeable] = []
	var large_mixed_array: Array = []

	# Create 100 test items
	for i in range(100):
		var test_placeable: Placeable = Placeable.new()
		test_placeable.display_name = "Test Item %d" % i
		test_placeable.packed_scene = PackedScene.new()

		large_placeable_array.append(test_placeable)

		# Mix placeables and sequences in the mixed array
		if i % 2 == 0:
			large_mixed_array.append(test_placeable)
		else:
			var test_sequence: PlaceableSequence = PlaceableSequence.new()
			test_sequence.display_name = "Sequence %d" % i
			test_sequence.placeables = [test_placeable]
			large_mixed_array.append(test_sequence)

	var start_time: int = Time.get_ticks_msec()
	var result1: Array[PlaceableSequence] = PlaceableSequenceFactory.from_placeables(large_placeable_array)
	var time1: int = Time.get_ticks_msec() - start_time

	start_time = Time.get_ticks_msec()
	var result2: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(large_mixed_array)
	var time2: int = Time.get_ticks_msec() - start_time

	# Verify correct output sizes
	assert_int(result1.size()).append_failure_message(
		"from_placeables should convert 100 placeables to 100 sequences"
	).is_equal(100)
	assert_int(result2.size()).append_failure_message(
		"ensure_sequences should process 100 mixed items to 100 sequences"
	).is_equal(100)

	# Performance should be reasonable (< 100ms for 100 items)
	assert_int(time1).append_failure_message(
		"from_placeables should complete in reasonable time, took %d ms" % time1
	).is_less(100)

	assert_int(time2).append_failure_message(
		"ensure_sequences should complete in reasonable time, took %d ms" % time2
	).is_less(100)

func test_type_safety_and_validation() -> void:
	# Test that factory methods handle various edge cases gracefully
	var test_data: Array = [
		test_placeable_1,
		test_sequence_1,
		null,
		"string",
		42,
		Vector2.ZERO,
		RefCounted.new()
	]

	# ensure_sequences should only process valid types
	var result: Array[PlaceableSequence] = PlaceableSequenceFactory.ensure_sequences(test_data)

	# Should only convert the placeable and preserve the sequence (2 valid items)
	assert_int(result.size()).append_failure_message(
		"ensure_sequences should only process PlaceableSequence and Placeable objects, processed %d items" % result.size()
	).is_equal(2)

	# Verify the valid items were processed correctly
	var found_original_sequence: bool = false
	var found_converted_placeable: bool = false

	for sequence in result:
		if sequence == test_sequence_1:
			found_original_sequence = true
		elif sequence.display_name == test_placeable_1.display_name and sequence.placeables.size() == 1:
			found_converted_placeable = true

	assert_bool(found_original_sequence).append_failure_message(
		"Should preserve original PlaceableSequence"
	).is_true()

	assert_bool(found_converted_placeable).append_failure_message(
		"Should convert Placeable to PlaceableSequence"
	).is_true()

#endregion