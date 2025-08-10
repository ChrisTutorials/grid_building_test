class_name TestSceneLibrary
extends GdUnitTestSuite

@export_group("Indicator Templates")
static var indicator: PackedScene = load("uid://l00rt6twodlt")
static var indicator_min: PackedScene = load("uid://ctr73a3smgupf")
static var indicator_iso: PackedScene = load("uid://cfvuw0dd8twce")

@export_group("Resources")
static var building_settings: BuildingSettings = load("uid://b02r1bgby2hcx")
static var grid_targeting_settings: GridTargetingSettings = load("uid://cob2kk7haei2t")

@export_group("ManipulatableSettings")
static var manipulatable_settings_all_allowed: ManipulatableSettings = load("uid://dn881lunp3lrm")
static var manipulatable_settings_none_allowed: ManipulatableSettings = load("uid://jonw4f3w8ofn")
static var rules_2_rules_1_tile_check: ManipulatableSettings = load("uid://5u2sgj1wk4or")

@export_group("Placeables")
static var placeable_isometric_building: Placeable = load("uid://b4s35gca8r3ep")
static var placeable_2d_test: Placeable = load("uid://jgmywi04ib7c")
static var placeable_eclipse_skew_rotate: Placeable = load("uid://cmuqt7ovi8si3")
static var placeable_eclipse: Placeable = load("uid://bdyqov56dermv")
static var placeable_smithy: Placeable = load("uid://dirh6mcrgdm3w")

@export_group("Scripts")

@export_group("Test Scenes")
static var box_scripted: PackedScene = load("uid://cgbwvur77ex84")
static var keep_script_scene: PackedScene = load("uid://bp22b3deiiyer")
static var eclipse_scene: PackedScene = load("uid://j5837ml5dduu")

@export_group("Tile Maps")
static var tile_map_layer_buildable: PackedScene = load("uid://3shi30ob8pna")

## Tileset with "type", "color", "height" custom data properties for tiles
static var custom_data_tile_set: TileSet = load("uid://b0shp63l248fm")
