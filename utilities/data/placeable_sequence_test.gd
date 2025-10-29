extends GdUnitTestSuite

## Unit tests for PlaceableSequence resource
## Tests sequence creation, variant access, and validation delegation

var test_placeable_1: Placeable
var test_placeable_2: Placeable
var test_placeable_3: Placeable

func before_test() -> void:
	# Create test placeables with simple packed scenes
	var simple_scene: PackedScene = PackedScene.new()

	test_placeable_1 = Placeable.new()
	test_placeable_1.display_name = "Basic Building"
	test_placeable_1.packed_scene = simple_scene

	test_placeable_2 = Placeable.new()
	test_placeable_2.display_name = "Advanced Building"
	test_placeable_2.packed_scene = simple_scene

	test_placeable_3 = Placeable.new()
	test_placeable_3.display_name = "Special Building"
	test_placeable_3.packed_scene = simple_scene

func after_test() -> void:
	test_placeable_1 = null
	test_placeable_2 = null
	test_placeable_3 = null

#region BASIC FUNCTIONALITY TESTS

func test_sequence_creation_and_properties() -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Tower Variants"
	sequence.placeables = [test_placeable_1, test_placeable_2, test_placeable_3]

	# Basic property validation
	assert_str(sequence.display_name).append_failure_message("Sequence display_name should be set correctly").is_equal("Tower Variants")
	assert_int(sequence.placeables.size()).append_failure_message("Sequence should contain 3 placeables").is_equal(3)
	assert_object(sequence.placeables[0]).append_failure_message("First placeable should be test_placeable_1").is_same(test_placeable_1)
	assert_object(sequence.placeables[1]).append_failure_message("Second placeable should be test_placeable_2").is_same(test_placeable_2)
	assert_object(sequence.placeables[2]).append_failure_message("Third placeable should be test_placeable_3").is_same(test_placeable_3)

func test_count_method() -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()

	# Empty sequence
	sequence.placeables = []
	assert_int(sequence.count()).append_failure_message(
		"Empty sequence should return count 0"
	).is_equal(0)

	# Single placeable
	sequence.placeables = [test_placeable_1]
	assert_int(sequence.count()).append_failure_message(
		"Single placeable sequence should return count 1"
	).is_equal(1)

	# Multiple placeables
	sequence.placeables = [test_placeable_1, test_placeable_2, test_placeable_3]
	assert_int(sequence.count()).append_failure_message(
		"Three placeable sequence should return count 3"
	).is_equal(3)

#endregion

#region VARIANT ACCESS TESTS

@warning_ignore("unused_parameter")
func test_get_variant_scenarios(
	index: int,
	expected_result: String,
	test_parameters := [
		# [index, expected_result_name]
		[0, "Basic Building"],
		[1, "Advanced Building"],
		[2, "Special Building"],
		[-1, ""],  # Invalid negative index
		[3, ""],   # Out of bounds index
		[999, ""]  # Way out of bounds
	]
) -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.placeables = [test_placeable_1, test_placeable_2, test_placeable_3]

	var result: Placeable = sequence.get_variant(index)

	if expected_result == "":
		assert_object(result).append_failure_message(
			"get_variant(%d) should return null for invalid index" % index
		).is_null()
	else:
		assert_object(result).append_failure_message(
			"get_variant(%d) should return valid placeable" % index
		).is_not_null()
		assert_str(result.display_name).append_failure_message(
			"get_variant(%d) should return placeable with name '%s'" % [index, expected_result]
		).is_equal(expected_result)

@warning_ignore("unused_parameter")
func test_variant_display_name_scenarios(
	index: int,
	expected_name: String,
	test_parameters := [
		# [index, expected_display_name]
		[0, "Basic Building"],
		[1, "Advanced Building"],
		[2, "Special Building"],
		[-1, "<Unknown>"],  # Invalid negative index
		[3, "<Unknown>"],   # Out of bounds index
		[999, "<Unknown>"]  # Way out of bounds
	]
) -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.placeables = [test_placeable_1, test_placeable_2, test_placeable_3]

	var result: String = sequence.variant_display_name(index)

	assert_str(result).append_failure_message(
		"variant_display_name(%d) should return '%s', got '%s'" % [index, expected_name, result]
	).is_equal(expected_name)

#endregion

#region VALIDATION TESTS

@warning_ignore("unused_parameter")
func test_editor_issues_scenarios(
	setup_description: String,
	placeable_count: int,
	null_count: int,
	invalid_count: int,
	expected_issue_count: int,
	test_parameters := [
		# [setup_description, placeables, nulls, invalids, expected_issues]
		["valid_sequence", 3, 0, 0, 0],
		["empty_sequence", 0, 0, 0, 1],  # "No placeables defined"
		["sequence_with_nulls", 2, 1, 0, 1],  # Null placeable issue
		["sequence_with_invalids", 1, 0, 1, 1],  # Invalid placeable issue
		["mixed_problems", 1, 1, 1, 2],  # Multiple issues
		["all_invalid", 0, 2, 1, 3],  # Empty + nulls + invalid
	]
) -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Test Sequence"
	sequence.placeables = []

	# Add valid placeables
	var available_placeables: Array[Placeable] = [test_placeable_1, test_placeable_2, test_placeable_3]
	for i in range(placeable_count):
		sequence.placeables.append(available_placeables[i % available_placeables.size()])

	# Add nulls
	for i in range(null_count):
		sequence.placeables.append(null)

	# Add invalid placeables (mock objects without required properties)
	for i in range(invalid_count):
		var invalid_placeable: Placeable = Placeable.new()
		# Leave packed_scene as null to create validation issue
		invalid_placeable.display_name = "Invalid %d" % i
		sequence.placeables.append(invalid_placeable)

	var issues: Array[String] = sequence.get_editor_issues()

	assert_int(issues.size()).append_failure_message(
		"Editor validation for '%s' should produce %d issues, got %d: %s" %
		[setup_description, expected_issue_count, issues.size(), str(issues)]
	).is_equal(expected_issue_count)

func test_runtime_issues_includes_editor_validation() -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Test Sequence"
	sequence.placeables = []  # Empty sequence to trigger editor issue

	var editor_issues: Array[String] = sequence.get_editor_issues()
	var runtime_issues: Array[String] = sequence.get_runtime_issues()

	# Runtime issues should include all editor issues
	assert_int(runtime_issues.size()).append_failure_message(
		"Runtime issues should include all editor issues. Editor: %d, Runtime: %d" %
		[editor_issues.size(), runtime_issues.size()]
	).is_greater_equal(editor_issues.size())

	# Verify each editor issue is present in runtime issues
	for editor_issue: String in editor_issues:
		var found_in_runtime: bool = false
		for runtime_issue: String in runtime_issues:
			if runtime_issue == editor_issue:
				found_in_runtime = true
				break
		assert_bool(found_in_runtime).append_failure_message(
			"Editor issue '%s' should be included in runtime issues" % editor_issue
		).is_true()

func test_runtime_issues_delegates_to_placeables() -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Test Sequence"

	# Create a placeable with validation issues
	var problematic_placeable: Placeable = Placeable.new()
	problematic_placeable.display_name = "Problematic Building"
	# Leave packed_scene as null to trigger validation issue

	sequence.placeables = [test_placeable_1, problematic_placeable]

	var runtime_issues: Array[String] = sequence.get_runtime_issues()

	# Should include issues from the problematic placeable
	var found_placeable_issue: bool = false
	for issue: String in runtime_issues:
		if "packed_scene" in issue.to_lower() or "scene" in issue.to_lower():
			found_placeable_issue = true
			break

	assert_bool(found_placeable_issue).append_failure_message(
		"Runtime validation should include placeable validation issues. Found issues: %s" % str(runtime_issues)
	).is_true()

#endregion

#region EDGE CASE TESTS

func test_empty_sequence_edge_cases() -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Empty Sequence"
	sequence.placeables = []

	# Count should be 0
	assert_int(sequence.count()).append_failure_message("Empty sequence should have count 0").is_equal(0)

	# get_variant should return null for any index
	assert_object(sequence.get_variant(0)).append_failure_message("Empty sequence get_variant(0) should return null").is_null()
	assert_object(sequence.get_variant(-1)).append_failure_message("Empty sequence get_variant(-1) should return null").is_null()

	# variant_display_name should return <Unknown> for any index
	assert_str(sequence.variant_display_name(0)).append_failure_message("Empty sequence variant_display_name(0) should return '<Unknown>'")\
		.is_equal("<Unknown>")

	# Should have validation issues
	var issues: Array[String] = sequence.get_editor_issues()
	assert_int(issues.size()).append_failure_message("Empty sequence should have validation issues").is_greater(0)

func test_null_placeables_handling() -> void:
	var sequence: PlaceableSequence = PlaceableSequence.new()
	sequence.display_name = "Sequence with Nulls"
	sequence.placeables = [test_placeable_1, null, test_placeable_2, null]

	# Count should include nulls
	assert_int(sequence.count()).append_failure_message(
		"Sequence count should include null placeables"
	).is_equal(4)

	# get_variant should handle nulls gracefully
	assert_object(sequence.get_variant(0)).append_failure_message(
		"First variant should return the first non-null placeable"
	).is_same(test_placeable_1)
	assert_object(sequence.get_variant(1)).append_failure_message(
		"Second variant should return null for null placeable"
	).is_null()
	assert_object(sequence.get_variant(2)).append_failure_message(
		"Third variant should return the second non-null placeable"
	).is_same(test_placeable_2)
	assert_object(sequence.get_variant(3)).append_failure_message(
		"Fourth variant should return null for null placeable"
	).is_null()

	# variant_display_name should handle nulls
	assert_str(sequence.variant_display_name(0)).append_failure_message(
		"Display name for first variant should match the placeable's name"
	).is_equal("Basic Building")
	assert_str(sequence.variant_display_name(1)).append_failure_message(
		"Display name for null variant should be '<Unknown>'"
	).is_equal("<Unknown>")

	# Should have validation issues for null placeables
	var issues: Array[String] = sequence.get_editor_issues()
	var null_issue_count: int = 0
	for issue: String in issues:
		if "null" in issue.to_lower():
			null_issue_count += 1

	assert_int(null_issue_count).append_failure_message(
		"Should have validation issues for null placeables. Issues found: %s" % str(issues)
	).is_greater(0)

#endregion