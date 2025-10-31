## Test environment for grid building tests.
##
## This is a CRITICAL infrastructure file used by hundreds of test suites across the project.
## Any changes here affect the entire test suite and must maintain backward compatibility.
##
## [b]Architecture:[/b]
## - Uses [GBTestInjectorSystem] which automatically duplicates composition containers
##   for test isolation, preventing cross-test contamination
## - Follows the System/State separation pattern:
##   * Systems manage behavior and lifecycle
##   * States hold configuration and data
##   * Properties are accessed via [code]system.get_state().property[/code]
##
## [b]Test Isolation:[/b]
## - Container duplication via GBTestInjectorSystem
## - Explicit state clearing in _ready()
## - Independent scene instance per test
##
## [b]Usage Pattern:[/b]
## [codeblock]
## var env := EnvironmentTestFactory.instance_all_systems_env(test, "default_scene_uid")
## var container := env.get_container()
## var states := container.get_states()
## # Access systems through container, not directly
## [/codeblock]
class_name GBTestEnvironment
extends Node

#region Exported Dependencies
## System responsible for dependency injection and container duplication for test isolation.
@export var injector: GBTestInjectorSystem

## System managing grid-based targeting and cursor positioning.
@export var grid_targeting_system: GridTargetingSystem

## Node responsible for following mouse/keyboard input and positioning objects on the grid.
@export var positioner: GridPositioner2D

## Component for detecting targets via shape casting (collision-based targeting).
@export var targeter: TargetingShapeCast2D

## Root node for the entire test world coordinate space.
@export var world: Node2D

## Container for level-specific content (maps, objects, etc).
@export var level: Node2D

## Context providing level-specific settings and configuration.
@export var level_context: GBLevelContext

## Primary tilemap layer for placement validation and collision detection.
@export var tile_map_layer: TileMapLayer

## Parent node where test objects (buildings, manipulatable, etc) are instantiated.
@export var objects_parent: Node2D

## Node representing where objects should be placed (typically same as positioner).
@export var placer: Node2D
#endregion


#region Validation Helpers
## Validates a required component and appends issue if null.
## [param component] Component to validate
## [param component_name] Display name for error message
## [param issues] Array to append error to
func _validate_required(component: Variant, component_name: String, issues: Array[String]) -> void:
	if component == null:
		issues.append("Missing %s" % component_name)


## Validates a component with runtime issues method.
## [param component] Component to validate (must have get_runtime_issues())
## [param component_name] Display name for error message
## [param issues] Array to append errors to
func _validate_with_runtime_issues(component: Variant, component_name: String, issues: Array[String]) -> void:
	if component == null:
		issues.append("Missing %s" % component_name)
	else:
		issues.append_array(component.get_runtime_issues())


## Validates scene hierarchy relationships.
## [param issues] Array to append errors to
func _validate_scene_structure(issues: Array[String]) -> void:
	if level != null and world != null and level.get_parent() != world:
		issues.append("Level should be the direct child of the World Node2D")


#endregion


#region Public API
## Validates all test environment dependencies and returns list of issues.
## [return] Array of validation error strings (empty if valid)
func get_issues() -> Array[String]:
	var issues: Array[String] = []

	# Core systems with runtime validation
	_validate_with_runtime_issues(injector, "GBInjectorSystem", issues)
	_validate_with_runtime_issues(grid_targeting_system, "GridTargetingSystem", issues)
	_validate_with_runtime_issues(level_context, "LevelContext", issues)

	# Required nodes
	_validate_required(positioner, "Positioner", issues)
	_validate_required(world, "World", issues)
	_validate_required(level, "Level", issues)
	_validate_required(tile_map_layer, "TileMapLayer", issues)
	_validate_required(objects_parent, "ObjectsParent", issues)
	_validate_required(placer, "Placer", issues)

	# Targeter with shape validation
	if targeter == null:
		issues.append("TargetingShapeCast2D missing")
	elif targeter.shape == null:
		(
			issues
			. append(
				"TargetingShapeCast2D has no shape attached. This will error and be unable to target anything."
			)
		)

	# TileMapLayer specific validation
	if tile_map_layer != null and tile_map_layer.tile_set == null:
		issues.append("Missing TileSet in TileMapLayer")

	# Scene structure validation
	_validate_scene_structure(issues)

	return issues


## Gets the composition container from the injector system.
## [return] Container instance or null if injector not set
func get_container() -> GBCompositionContainer:
	return injector.composition_container if injector else null


## Gets the logger from the composition container.
## [return] Logger instance or null if container not available
func get_logger() -> GBLogger:
	var container: GBCompositionContainer = get_container()
	return container.get_logger() if container else null


## Returns the number of tiles that actually exist on the tile map layer.
## Useful for validating test setup and tilemap population.
## [return] Number of used cells in the tilemap
func get_tile_count() -> int:
	if tile_map_layer == null:
		return 0
	return tile_map_layer.get_used_cells().size()


#endregion


#region Initialization
## Initializes test environment and resets state for test isolation.
##
## [b]CRITICAL for test isolation:[/b]
## - Clears targeting state to prevent stale data from previous tests
## - Sets up target_map on GridTargetingState (not on GridTargetingSystem)
##
## [b]System/State Pattern:[/b]
## GridTargetingSystem manages behavior, GridTargetingState holds data.
## Properties like target_map must be set on the state resource via:
## [code]system.get_state().property = value[/code]
func _ready() -> void:
	_initialize_targeting_state()


## Initializes targeting state for test isolation.
## Clears any stale state and configures the target tilemap.
func _initialize_targeting_state() -> void:
	if grid_targeting_system == null:
		return

	var targeting_state := grid_targeting_system.get_state()
	if targeting_state == null:
		push_warning("[GBTestEnvironment] GridTargetingSystem has null state")
		return

	# Clear any stale target/collider state from previous test runs
	targeting_state.clear()

	# Set target_map on the STATE, not the system
	# This follows the System/State separation pattern where:
	# - System (GridTargetingSystem) manages behavior
	# - State (GridTargetingState) holds configuration/data
	targeting_state.target_map = tile_map_layer
#endregion
