# Renamed from test_item_container_owner.gd
extends GdUnitTestSuite

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

var _owner: TestItemContainerOwner
var _container_node: Node

func before_test():
	_owner = auto_free(TestItemContainerOwner.new())
	_container_node = auto_free(Node.new())
	add_child(_owner)
	add_child(_container_node)
	_owner.item_container = _container_node

func test_item_container_export_assignment():
	assert_object(_owner.item_container).is_equal(_container_node)

func test_item_container_null_by_default():
	var tmp_owner := TestItemContainerOwner.new()
	assert_object(tmp_owner.item_container).is_null()
	# cleanup
	tmp_owner.free()
