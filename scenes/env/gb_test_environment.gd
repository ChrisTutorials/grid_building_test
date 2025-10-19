## Test environment for grid building tests
##
## Uses [GBTestInjectorSystem] which automatically duplicates composition containers
## for test isolation. This prevents cross-test contamination.
class_name GBTestEnvironment
extends Node

@export var injector : GBTestInjectorSystem
@export var grid_targeting_system : GridTargetingSystem
@export var positioner : GridPositioner2D
@export var targeter : TargetingShapeCast2D
@export var world : Node2D
@export var level : Node2D
@export var level_context : GBLevelContext
@export var tile_map_layer : TileMapLayer
@export var objects_parent : Node2D
@export var placer : Node2D

func get_issues() -> Array[String]:
	var issues : Array[String] = []
	if injector == null:
		issues.append("Missing GBInjectorSystem")
	else:
		issues.append_array(injector.get_runtime_issues())

	if positioner == null:
		issues.append("Missing Positioner")
		
	if targeter == null:
		issues.append("TargeterShapeCast2D missing")
	elif targeter.shape == null:
		issues.append("TargeterShapecast2D has no shape attached. This will error and be unable to target anything.")

	if grid_targeting_system == null:
		issues.append("Missing GridTargetingSystem")
	else:
		issues.append_array(grid_targeting_system.get_runtime_issues())
		
	if world == null:
		issues.append("Missing World")
	if level == null:
		issues.append("Missing Level")
	if level_context == null:
		issues.append("Missing LevelContext")
	else:
		issues.append_array(level_context.get_runtime_issues())

	if tile_map_layer == null:
		issues.append("Missing TileMapLayer")

	if tile_map_layer.tile_set == null:
		issues.append("Missing TileSet in TileMapLayer")

	if objects_parent == null:
		issues.append("Missing ObjectsParent")

	if placer == null:
		issues.append("Missing Placer")
		
	if level.get_parent() != world:
		issues.append("Level should be the direct child of the World Node2D")

	return issues

func get_container() -> GBCompositionContainer:
	return injector.composition_container if injector else null

func get_logger() -> GBLogger:
	var container : GBCompositionContainer = get_container()
	return container.get_logger() if container else null

## Returns the number of tiles that actually exist on the tile map layer.
func get_tile_count() -> int:
	if tile_map_layer == null:
		return 0
	return tile_map_layer.get_used_cells().size()

func _ready() -> void:
	# Clear targeting state for test isolation
	# Even though GBTestInjectorSystem duplicates the container, the targeting state
	# object inside the duplicated container may carry over stale target/collider state
	# from the previous test run. Clear it here to ensure clean state.
	if grid_targeting_system != null:
		grid_targeting_system.clear()
		grid_targeting_system.target_map = tile_map_layer
