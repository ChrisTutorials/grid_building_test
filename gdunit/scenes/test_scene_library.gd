class_name TestSceneLibrary
extends GdUnitTestSuite

@export_group("Indicator Templates")
@export var indicator : PackedScene 			# Template
@export var indicator_min : PackedScene			
@export var indicator_iso : PackedScene

@export_group("Resources")
@export var building_settings : BuildingSettings # Test building settings
@export var building_state : BuildingState
@export var grid_targeting_settings : GridTargetingSettings
@export var placement_validator_platformer : PlacementValidator

@export_group("ManipulatableSettings")
@export var manipulatable_settings_all_allowed : ManipulatableSettings
@export var manipulatable_settings_none_allowed : ManipulatableSettings
@export var rules_2_rules_1_tile_check : ManipulatableSettings

@export_group("Placeables")
@export var placeable_isometric_building : Placeable
@export var placeable_2d_test : Placeable
@export var placeable_eclipse_skew_rotate : Placeable # Skewed and rotated eclipse shape scene
@export var placeable_eclipse : Placeable 
@export var placeable_smithy : Placeable

@export_group("Scripts")
@export var placeable_instance_script : Script

@export_group("Test Scenes")
@export var box_scripted : PackedScene
@export var keep_script_scene : PackedScene
@export var eclipse_scene : PackedScene

@export_group("Tile Maps")
@export var tile_map_buildable : PackedScene

## Tileset with "type", "color", "height" custom data properties for tiles
@export var custom_data_tile_set : TileSet

const library_path = "res://test/grid_building_test/scenes/test_scene_library.tscn"

## Creates an instance of the library scene (orphan, be sure to free)
static func instance_library() -> TestSceneLibrary:
	return load(library_path).instantiate()
