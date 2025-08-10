# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

# TestSuite generated from


func test_find_first_when_parent_null() -> void:
	var parent = null
	var result = GBSearchUtils.find_first(parent, Node)
	assert_that(result).is_null()
