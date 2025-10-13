## Test Constants
##
## Centralized constants for test environment UIDs, paths, and configuration values.
## This ensures consistency across all test files and provides a single point of maintenance.
class_name GBTestConstants
extends RefCounted

#region Environment Types
## Enum for environment types to avoid string-based matching
enum EnvironmentType {
	ALL_SYSTEMS,
	BUILDING_TEST,
	COLLISION_TEST,
	ISOMETRIC_TEST
}
#endregion

#region Environment Scene UIDs
## These UIDs correspond to test environment scenes that provide pre-configured
## systems and components for various test scenarios.

## All Systems Test Environment - Complete grid building system setup
## Path: res://test/grid_building_test/scenes/env/all_systems_test_environment.tscn
const ALL_SYSTEMS_ENV_UID: String = "uid://ioucajhfxc8b"

## Building Test Environment - Focused on building system components
## Path: res://test/grid_building_test/scenes/env/building_test_environment.tscn
const BUILDING_TEST_ENV_UID: String = "uid://c4ujk08n8llv8"

## Collision Test Environment - Optimized for collision and placement testing
## Path: res://test/grid_building_test/scenes/env/collision_test_environment.tscn
const COLLISION_TEST_ENV_UID: String = "uid://cdrtd538vrmun"

## Isometric Test Environment - Optimized for isometric tile mapping and collision testing
## Path: res://test/grid_building_test/scenes/env/isometric_test_environment.tscn
const ISOMETRIC_TEST_ENV_UID: String = "uid://d3yeah2uexha2"

## Environment Scene Paths
##
## Fallback paths in case UID loading fails. These should match the UIDs above.
const ALL_SYSTEMS_ENV_PATH: String = "res://test/grid_building_test/scenes/env/all_systems_test_environment.tscn"
const BUILDING_TEST_ENV_PATH: String = "res://test/grid_building_test/scenes/env/building_test_environment.tscn"
const COLLISION_TEST_ENV_PATH: String = "res://test/grid_building_test/scenes/env/collision_test_environment.tscn"
const ISOMETRIC_TEST_ENV_PATH: String = "res://test/grid_building_test/scenes/env/isometric_test_environment.tscn"

#endregion
#region Placement Rules

const COLLISIONS_CHECK_RULE : CollisionsCheckRule = preload("uid://du7xu07247202")

#endregion
#region Test Object Scene UIDs
## UIDs for test objects used in collision and placement testing

## Rectangular test object (15 tiles coverage)
const SCENE_RECT_15_TILES: PackedScene = preload("uid://blgwelirrimr1")

## Gigantic egg test object
const GIGANTIC_EGG_UID: String = "uid://dr0nu4jwbvhvx"

## Test pillar object
const PILLAR_UID: String = "uid://enlg28ry7lxk"

## Ellipse test object
const ELLIPSE_UID: String = "uid://j5837ml5dduu"

## Eclipse test scene (alias for ellipse)
static var eclipse_scene : PackedScene = preload("uid://j5837ml5dduu")

#endregion
#region Placeables

## Test smithy placeable (7x5 tiles - large)
const PLACEABLE_SMITHY: Placeable = preload("uid://dirh6mcrgdm3w")

## Good placeable test for polygon
const PLACEABLE_TRAPEZOID : Placeable = preload("uid://c8i072rgno71t")

## Small 2D test placeable (single tile) - IMPORTANT: has no CollisionObject2D so will not collide with anything.
const PLACEABLE_NO_COL_TEST_2D: Placeable = preload("uid://jgmywi04ib7c")

## Small rectangular test placeable (4x2 tiles - 64x32 px)
const PLACEABLE_RECT_4X2: Placeable = preload("res://test/grid_building_test/resources/placeable/test_placeable_rect_4x2.tres")

## Top-down demo pillar placeable - used for rotation indicator testing
const PLACEABLE_PILLAR_TD: Placeable = preload("uid://dratv0oi76yl5")

## Top-down demo smithy placeable - large building for testing
const PLACEABLE_SMITHY_TD: Placeable = preload("uid://bifgdqn17060d")

#endregion
#region Object Scene Paths
## Fallback paths for test objects
const RECT_15_TILES_PATH: String = "res://test/grid_building_test/scenes/objects/test_rect_15_tiles.tscn"
const SMITHY_PATH: String = "res://test/grid_building_test/scenes/objects/test_smithy.tscn"
const GIGANTIC_EGG_PATH: String = "res://test/grid_building_test/scenes/objects/test_gigantic_egg.tscn"
const PILLAR_PATH: String = "res://test/grid_building_test/scenes/objects/test_pillar.tscn"
const ELLIPSE_PATH: String = "res://test/grid_building_test/scenes/objects/test_elipse.tscn"
const PLACEABLE_INSTANCE_2D_PATH: String = "res://test/grid_building_test/scenes/objects/test_placeable_instance_scene_2d.tscn"
const TEST_2D_OBJECT_PATH: String = "res://test/grid_building_test/scenes/objects/2d_test_object.tscn"
const SKEW_ROTATION_RECT_PATH: String = "res://test/grid_building_test/scenes/objects/test_skew_rotation_rect.tscn"
const ISOMETRIC_BUILDING_PATH: String = "res://test/grid_building_test/scenes/objects/isometric_building.tscn"
const SCRIPT_KEEP_SCENE_PATH: String = "res://test/grid_building_test/scenes/objects/script_keep_scene.tscn"

#endregion

#region Test Indicators

## Top down platformer square indicator for placement rule testing
static var TEST_INDICATOR_TD_PLATFORMER : PackedScene = preload("uid://dhox8mb8kuaxa")

## Isometric indicator for placement rule testing
static var TEST_INDICATOR_ISOMETRIC : PackedScene = preload("uid://bas7hdwotyoiy")

#endregion
#region Test Configuration Constants
## Common values used across multiple tests

## Default tile size for test environments
const DEFAULT_TILE_SIZE: Vector2 = Vector2(16, 16)

## Default test grid size
const DEFAULT_GRID_SIZE: Vector2i = Vector2i(20, 20)

## Test timeout for async operations (milliseconds)
const TEST_TIMEOUT_MS: int = 5000

## Maximum number of indicators to generate in performance tests
const MAX_PERFORMANCE_INDICATORS: int = 1000

## Expected tile count for 31x31 buildable tile map (31 * 31 = 961)
const EXPECTED_31X31_TILE_COUNT: int = 31 * 31

## Default collision layer for test objects
const TEST_COLLISION_LAYER: int = 1

## Default collision mask for test objects
const TEST_COLLISION_MASK: int = 1

## Test composition container for dependency injection - Used for Top Down and Sidescrolling games with square tiles
const TEST_COMPOSITION_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

## Default isometric composition container for isometric-game specific tests
const ISO_COMPOSITION_CONTAINER : GBCompositionContainer = preload("uid://kxdod6rj5icx")

#endregion
#region Common Test Positions
## Frequently used positions in test scenarios
const ORIGIN: Vector2 = Vector2.ZERO
const CENTER: Vector2 = Vector2(160, 160)  # 5x5 tiles at 32px
const TOP_LEFT: Vector2 = Vector2(32, 32)
const TOP_RIGHT: Vector2 = Vector2(288, 32)
const BOTTOM_LEFT: Vector2 = Vector2(32, 288)
const BOTTOM_RIGHT: Vector2 = Vector2(288, 288)
const OFF_GRID: Vector2 = Vector2(50, 50)  # Not aligned to tile boundaries

## Default center tile for positioner initialization - should be within map bounds for all test environments
const DEFAULT_CENTER_TILE: Vector2i = Vector2i(0, 0)

#endregion
#region Test Tile Maps and Sets

## Buildable tile map layer for testing
static var TEST_TILE_MAP_LAYER_BUILDABLE : PackedScene = preload("res://test/grid_building_test/scenes/tile_map/TEST_buildable_31x31_tile_map.tscn")

## Tileset with "type", "color", "height" custom data properties for tiles
static var TEST_CUSTOM_DATA_TILE_SET : TileSet = preload("uid://b0shp63l248fm")

#endregion
## Static methods for validating test constants and scenes

## Validate that all environment scenes exist and can be loaded
static func validate_environment_scenes() -> Array[String]:
	var issues: Array[String] = []

	# Check ALL_SYSTEMS environment
	var all_systems_scene := load(ALL_SYSTEMS_ENV_UID)
	if not all_systems_scene:
		# Fallback to path loading
		all_systems_scene = load(ALL_SYSTEMS_ENV_PATH)
		if not all_systems_scene:
			issues.append("All Systems environment scene not found: " + ALL_SYSTEMS_ENV_PATH)

	return issues

## Get the best available scene reference (UID first, then path fallback)
static func get_environment_scene(environment_type: EnvironmentType) -> PackedScene:
	var scene: PackedScene = null

	match environment_type:
		EnvironmentType.ALL_SYSTEMS:
			scene = load(ALL_SYSTEMS_ENV_UID)
			if not scene:
				scene = load(ALL_SYSTEMS_ENV_PATH)
		EnvironmentType.BUILDING_TEST:
			scene = load(BUILDING_TEST_ENV_UID)
			if not scene:
				scene = load(BUILDING_TEST_ENV_PATH)
		EnvironmentType.COLLISION_TEST:
			scene = load(COLLISION_TEST_ENV_UID)
			if not scene:
				scene = load(COLLISION_TEST_ENV_PATH)
		EnvironmentType.ISOMETRIC_TEST:
			scene = load(ISOMETRIC_TEST_ENV_UID)
			if not scene:
				scene = load(ISOMETRIC_TEST_ENV_PATH)

	return scene

## Returns an array of test placeables for use as test parameters
static func get_placeables() -> Array[Placeable]:
	var placeables : Array[Placeable] = [
		PLACEABLE_SMITHY,
		PLACEABLE_TRAPEZOID
	]
	return placeables

## Check if a test object scene exists
static func validate_test_object_scene(object_uid: String) -> bool:
	var scene := load(object_uid)
	return scene != null

## Assert that the tile map in the given environment has the expected number of tiles
## test_suite: The GdUnitTestSuite instance for making assertions
## environment: The test environment containing the tile map
## expected_width: Expected width of the tile grid
## expected_height: Expected height of the tile grid
static func assert_tile_map_size(test_suite: GdUnitTestSuite, environment: GBTestEnvironment, expected_width: int, expected_height: int) -> void:
	var expected_count: int = expected_width * expected_height
	
	test_suite.assert_object(environment.tile_map_layer).append_failure_message("Tile map layer should be available").is_not_null()
	test_suite.assert_int(environment.get_tile_count()).append_failure_message(
		"Tile map should have expected number of tiles for %dx%d grid (%d tiles)" % [expected_width, expected_height, expected_count]
	).is_equal(expected_count)

## Duplicate a GBCompositionContainer for safe modification in tests.
##
## TEST ISOLATION BEST PRACTICE:
## Always duplicate containers before modifying their settings to prevent
## cross-test contamination. Modified cached resources persist across tests.
##
## Usage:
##   var container_copy: GBCompositionContainer = GBTestConstants.duplicate_container(original_container)
##   container_copy.config.settings.targeting.enable_mouse_input = false
##
## [param container] The container to duplicate
## [return] A deep copy of the container safe for modification
static func duplicate_container(container: GBCompositionContainer) -> GBCompositionContainer:
	if container == null:
		push_error("GBTestConstants.duplicate_container: Cannot duplicate null container")
		return null
	
	# Use Godot's built-in duplicate() with DUPLICATE_USE_INSTANTIATION flag
	# This creates a deep copy including all sub-resources
	return container.duplicate(true) as GBCompositionContainer
