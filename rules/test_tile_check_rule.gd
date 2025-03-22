extends GdUnitTestSuite

var rule : TileCheckRule

func before_test():
	rule = TileCheckRule.new()
	
func test_validate_condition():
	var result : TileCheckRuleResult = rule.validate_condition()
	assert_object(result).is_instanceof(TileCheckRuleResult)

## Test basic function with no indicators
func test_get_tile_positions():
	var tiles : Array[Vector2i] = rule.get_tile_positions()
	assert_array(tiles).is_empty()
