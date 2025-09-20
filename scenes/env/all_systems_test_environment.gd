## All systems including ManipulationSystem and a full scene for object placement and manipulation integration tests
class_name AllSystemsTestEnvironment
extends BuildingTestEnvironment

@export var manipulation_system : ManipulationSystem
@export var target_highlighter : TargetHighlighter

func _ready() -> void:
	super()

func get_issues() -> Array[String]:
	var issues : Array[String] = []
	
	issues.append_array(super())
	
	if manipulation_system == null:
		issues.append("Missing ManipulationSystem")
	else:
		issues.append_array(manipulation_system.get_runtime_issues())
		
	if target_highlighter == null:
		issues.append("Missing target highlighter.")

	return issues
