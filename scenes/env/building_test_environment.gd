class_name BuildingTestEnvironment
extends GBTestEnvironment

@export var building_system : BuildingSystem
@export var gb_owner : GBOwner
@export var positioner : GridPositioner2D
@export var manipulation_parent : ManipulationParent
@export var indicator_manager : IndicatorManager

func get_issues() -> Array[String]:
	var issues : Array[String] = []
	issues.append_array(super())
	
	## We evaluate at this level because a positioner stack is set here so it should be fully valid now.
	issues.append(grid_targeting_system.get_runtime_issues())
	
	if building_system == null:
		issues.append("Missing BuildingSystem")

	# Validate setup
	issues.append_array(building_system.get_runtime_issues())
	issues.append_array(level_context.get_runtime_issues())
	issues.append_array(get_container().get_states().targeting.get_runtime_issues())
	issues.append_array(injector.get_runtime_issues())

	return issues

func get_container() -> GBCompositionContainer:
	return injector.composition_container

func get_owner_root() -> Node:
	return gb_owner.owner_root
