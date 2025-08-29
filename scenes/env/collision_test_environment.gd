## Testing environment for collision tests. Collision mapper etc
class_name CollisionTestEnvironment
extends GBTestEnvironment

func get_issues() -> Array[String]:
	return super()

func get_container() -> GBCompositionContainer:
	return get_lazy_injector().composition_container

## Lazy find if called before scene ready
func get_lazy_injector() -> GBInjectorSystem:
	if injector == null:
		return find_children("", "GBInjectorSystem")[0].composition_container

	return injector
