## Testing environment for collision tests. Collision mapper etc
class_name CollisionTestEnvironment
extends GBTestEnvironment

@export var indicator_manager : IndicatorManager

func get_issues() -> Array[String]:
	var issues : Array[String] = super()
	
	if indicator_manager == null:
		issues.append("Missing IndicatorManager")
	
	return issues

func get_container() -> GBCompositionContainer:
	return injector.composition_container
