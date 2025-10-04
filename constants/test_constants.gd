## GBTestConstants - Centralized test constants for Grid Building plugin tests
##
## Provides common constants used across test suites to ensure consistency
## and avoid magic numbers in test code.
##
## Usage: const GBTestConstants = preload("res://test/grid_building_test/constants/test_constants.gd")

# class_name GBTestConstants  # Removed to avoid global class warning

## Common test positions
const CENTER: Vector2 = Vector2(0, 0)
const TOP_LEFT: Vector2 = Vector2(-100, -100)
const OFF_GRID: Vector2 = Vector2(1000, 1000)

## Default tile/map sizes
const DEFAULT_TILE_SIZE: Vector2 = Vector2(16, 16)
const DEFAULT_CENTER_TILE: Vector2i = Vector2i(0, 0)

## Test object UIDs (placeholder - update with actual UIDs)
const PLACEABLE_RECT_4X2: String = "uid://placeholder_rect4x2"

## Test timeouts and performance thresholds
const TEST_TIMEOUT_MS: int = 5000
const MAX_PERFORMANCE_INDICATORS: int = 100

## Environment scene types
enum EnvironmentType {
	ALL_SYSTEMS,
	BUILDING_TEST,
	COLLISION_TEST,
	ISOMETRIC_TEST
}

## Get environment scene for the specified type
static func get_environment_scene(env_type: EnvironmentType) -> PackedScene:
	match env_type:
		EnvironmentType.ALL_SYSTEMS:
			return load("uid://ioucajhfxc8b")  # ALL_SYSTEMS_ENV_UID
		EnvironmentType.BUILDING_TEST:
			return load("uid://placeholder_building")
		EnvironmentType.COLLISION_TEST:
			return load("uid://placeholder_collision")
		EnvironmentType.ISOMETRIC_TEST:
			return load("uid://placeholder_isometric")
		_:
			push_error("Unknown environment type: %d" % env_type)
			return null

## Validate that test environment scenes exist and are loadable
static func validate_environment_scenes() -> bool:
	for env_type: int in EnvironmentType.values():
		var scene: PackedScene = get_environment_scene(env_type)
		if scene == null:
			push_error("Environment scene for type %d is null" % env_type)
			return false
	return true