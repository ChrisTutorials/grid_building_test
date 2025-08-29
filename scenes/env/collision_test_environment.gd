## Testing environment for collision tests. Collision mapper etc
class_name CollisionTestEnvironment
extends GBTestEnvironment


func get_issues() -> Array[String]:
	var issues : Array[String] = super()
	
	return issues

func get_container() -> GBCompositionContainer:
	return injector.composition_container
