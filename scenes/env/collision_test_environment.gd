## Testing environment for collision tests. Collision mapper etc
class_name CollisionTestEnvironment
extends Node

@export var injector : GBInjectorSystem
@export var grid_targeting_system : GridTargetingSystem
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
	if grid_targeting_system == null:
		issues.append("Missing GridTargetingSystem")
	if world == null:
		issues.append("Missing World")
	if level == null:
		issues.append("Missing Level")
	if level_context == null:
		issues.append("Missing LevelContext")
	if tile_map_layer == null:
		issues.append("Missing TileMapLayer")
	if objects_parent == null:
		issues.append("Missing ObjectsParent")
	if placer == null:
		issues.append("Missing Placer")
	return issues
