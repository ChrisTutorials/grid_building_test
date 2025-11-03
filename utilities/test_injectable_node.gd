## Simple test node that can receive dependency injection.
## Used for testing the injection system.
extends Node

var _injected_container: GBCompositionContainer = null


func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_injected_container = p_container
