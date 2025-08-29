class_name BuildingTestEnvironment
extends Node

@export var injector : GBInjectorSystem
@export var grid_targeting_system : GridTargetingSystem
@export var building_system : BuildingSystem
@export var world : Node2D
@export var level : Node2D
@export var level_context : GBLevelContext
@export var tile_map_layer : TileMapLayer
@export var objects_parent : Node2D
@export var placer : Node2D
@export var gb_owner : GBOwner
@export var positioner : GridPositioner2D
@export var manipulation_parent : ManipulationParent
@export var indicator_manager : IndicatorManager

func get_issues() -> Array[String]:
	var issues : Array[String] = []
	if injector == null:
		issues.append("Missing GBInjectorSystem")
	if grid_targeting_system == null:
		issues.append("Missing GridTargetingSystem")
	if building_system == null:
		issues.append("Missing BuildingSystem")
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

	# Validate setup
	issues.append_array(building_system.get_dependency_issues())
	issues.append_array(get_container().get_states().targeting.get_runtime_issues())
	issues.append_array(injector.get_runtime_issues())

	return issues

func get_container() -> GBCompositionContainer:
	return injector.composition_container
