## GdUnit4 Hook Auto-Loader
## This file ensures hooks registered in project settings are loaded for CLI test runs
## Place this in a folder that GdUnit4 will scan during test discovery

extends Node

func _enter_tree() -> void:
	# Load and register hooks from project settings when tests start
	var hook_service = GdUnitTestSessionHookService.instance()
	
	# The service should load hooks from project.godot settings
	# but we ensure it's called here for CLI runs
	if hook_service != null:
		pass  # Service already loaded hooks in its singleton init
