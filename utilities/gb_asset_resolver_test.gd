extends GdUnitTestSuite

## Test suite for GBAssetResolver asset loading functionality
##
## Tests unified asset loading for placeables, category tags, and other Grid Building resources.
## Validates folder scanning, resource validation, and error handling.

const TEST_ASSETS_FOLDER = GBTestConstants.TEST_PATH_PLACEABLE_RESOURCES

func test_load_placeables_from_folder() -> void:
	# Test loading placeables from an existing folder using the detailed result method
	var result: GBAssetResolver.LoadResult = GBAssetResolver.load_placeables_with_result(TEST_ASSETS_FOLDER)

 assert_str(summary).append_failure_message( "Summary should include asset count" ) assert_str(summary).contains("Errors: 1").append_failure_message( "Summary should include error count" ) assert_str(summary).contains("Warnings: 1").append_failure_message( "Summary should include warning count" ) func test_backward_compatibility_with_placeable_loader() -> void: # Test that GBAssetResolver.load_placeables produces similar results to PlaceableLoader.get_placeables if not DirAccess.dir_exists_absolute(TEST_ASSETS_FOLDER): return # Skip if test folder doesn't exist var new_result: GBAssetResolver.LoadResult = GBAssetResolver.load_placeables_with_result(TEST_ASSETS_FOLDER) var old_result: Array = PlaceableLoader.get_placeables(TEST_ASSETS_FOLDER) if new_result.is_successful(): assert_int(new_result.assets.size()).is_equal(old_result.size()).append_failure_message( "GBAssetResolver should load same number of placeables as PlaceableLoader. New: %d, Old: %d" % [new_result.assets.size(), old_result.size()] ) # Verify all loaded assets are Placeable resources for asset: Variant in new_result.assets: assert_object(asset).is_not_null().append_failure_message( "All loaded assets should be valid" ) # Note: Type checking depends on Placeable implementation func test_simple_placeable_loading_compatibility() -> void: # Test that the simple load_placeables method maintains backward compatibility if not DirAccess.dir_exists_absolute(TEST_ASSETS_FOLDER): return # Skip if test folder doesn't exist var new_simple_result: Array[Placeable] = GBAssetResolver.load_placeables(TEST_ASSETS_FOLDER) var old_result: Array = PlaceableLoader.get_placeables(TEST_ASSETS_FOLDER) assert_int(new_simple_result.size()).is_equal(old_result.size()).append_failure_message( "Simple GBAssetResolver.load_placeables should return same count as PlaceableLoader. New: %d, Old: %d" % [new_simple_result.size(), old_result.size()] ).contains("Loaded: 0 assets")