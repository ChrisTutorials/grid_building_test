extends GdUnitTestSuite

## Test suite to demonstrate the enhanced AI hook with actual failures

func test_intentional_failure_to_show_hook_output() -> void:
	var expected := 2
	var actual := 1
	assert_int(actual).append_failure_message("Expected %d but got %d" % [expected, actual]).is_equal(expected)

func test_another_failure() -> void:
	var result := "hello"
	assert_str(result).append_failure_message("Expected 'world' but got '%s'" % result).is_equal("world")

func test_successful_test() -> void:
	assert_int(1).is_equal(1)
