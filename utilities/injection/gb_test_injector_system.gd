## **TESTING ONLY**: Extended injector system with automatic test isolation.
##
## This class extends [GBInjectorSystem] to automatically duplicate the composition
## container when loaded from scene files, ensuring test isolation without manual duplication.
##
## [b]Key Features:[/b]
## - Automatically duplicates containers during scene loading ([code]_ready()[/code])
## - Disables strict validation warnings for incomplete test setups
## - Allows tests to create minimal environments without validation noise
##
## [b]Usage in Tests:[/b]
## [codeblock]
## # In test environment scenes, use GBTestInjectorSystem instead of GBInjectorSystem
## # The container will be automatically duplicated when the scene loads
## @export var injector : GBTestInjectorSystem
## [/codeblock]
##
## [b]Known Limitation:[/b]
## Direct property assignment does [b]NOT[/b] trigger duplication:
## [codeblock]
## var injector = GBTestInjectorSystem.new()
## injector.composition_container = some_container  # NOT duplicated
## [/codeblock]
## This is because GDScript doesn't allow overriding setters for inherited @export properties.
## If you need duplication for direct assignment, call [code]_duplicate_container_if_needed()[/code] manually.
##
## [b]DO NOT use this class in production/runtime code.[/b] It exists solely for
## test isolation and should only be used in test environment scenes.
class_name GBTestInjectorSystem
extends GBInjectorSystem

## Track if we've already duplicated to avoid double-duplication
var _has_duplicated: bool = false

## Intercept NOTIFICATION_POSTINITIALIZE which is called after scene properties are set
## This is the earliest point where we can duplicate the container from a scene file
func _notification(what: int) -> void:
	if what == NOTIFICATION_POSTINITIALIZE:
		_duplicate_container_if_needed()

## Duplicate the composition_container for test isolation
## Called after properties are initialized from scene file
func _duplicate_container_if_needed() -> void:
	
	if composition_container != null and not _has_duplicated:
		_has_duplicated = true
		
		# Duplicate the container for test isolation
		var duplicated: GBCompositionContainer = composition_container.duplicate(true)
		
		# Configure runtime checks before anything uses the container
		_configure_runtime_checks(duplicated)
		
		# Log the duplication for debugging
		var logger := duplicated.get_logger()
		if logger:
			logger.log_debug("GBTestInjectorSystem: Auto-duplicated container for test isolation")
		
		# Replace with duplicated container
		composition_container = duplicated

## Override _ready to duplicate container BEFORE parent's _ready() triggers injection
func _ready() -> void:
	
	# Duplicate container if it was set from scene file BEFORE calling parent _ready
	_duplicate_container_if_needed()
	
	# Now call parent _ready which will use the duplicated container for injection
	super._ready()
	
	# NodeLocator methods have been disabled temporarily due to parse errors
	# The NodeLocator class has instance methods, not static methods

## Populate missing container dependencies from the scene tree
## This reduces false validation warnings for test environments that have the required nodes
## TEMPORARILY DISABLED - needs refactoring for proper NodeLocator usage
func _populate_container_from_scene_tree(container: GBCompositionContainer) -> void:
	return  # Disabled
	
	#if container == null:
	#	return
	#
	#var logger := container.get_logger()
	#
	## Try to find systems in the scene tree
	#var building_system: Node = NodeLocator.find_first_node_by_class(self, "BuildingSystem")
	#var manipulation_system: Node = NodeLocator.find_first_node_by_class(self, "ManipulationSystem")
	#var targeting_system: Node = NodeLocator.find_first_node_by_class(self, "GridTargetingSystem")
	#var level_context: Node = NodeLocator.find_first_node_by_class(self, "GBLevelContext")
	#
	## Populate container with found systems
	#var populated_count: int = 0
	#
	#if building_system and not container.has_building_system():
	#	container.set_building_system(building_system)
	#	populated_count += 1
	#
	#if manipulation_system and not container.has_manipulation_system():
	#	container.set_manipulation_system(manipulation_system)
	#	populated_count += 1
	#
	#if targeting_system and not container.has_grid_targeting_system():
	#	container.set_grid_targeting_system(targeting_system)
	#	populated_count += 1
	#
	#if level_context and not container.has_level_context():
	#	container.set_level_context(level_context)
	#	populated_count += 1
	#
	#if logger and populated_count > 0:
	#	logger.log_debug("GBTestInjectorSystem: Auto-populated %d dependencies from scene tree" % populated_count)

## Configure runtime checks to be lenient for test environments
## This prevents validation warnings for intentionally incomplete test setups
func _configure_runtime_checks(container: GBCompositionContainer) -> void:
	if container == null:
		return
	
	var config := container.config
	if config == null or config.settings == null:
		return
	
	var runtime_checks := config.settings.runtime_checks
	if runtime_checks == null:
		return
	
	# Disable strict validation for components that tests may omit
	# Tests can still enable specific checks if needed
	runtime_checks.building_system = false
	runtime_checks.manipulation_system = false
	runtime_checks.targeting_system = false
	
	var logger := container.get_logger()
	if logger:
		logger.log_debug("GBTestInjectorSystem: Configured lenient runtime checks for test environment")

## Helper method for explicit container duplication if needed in special cases
## Most tests won't need this since duplication is automatic on assignment
static func duplicate_container(container: GBCompositionContainer, deep: bool = true) -> GBCompositionContainer:
	if container == null:
		push_error("duplicate_container() requires a non-null container.")
		return null
	
	return container.duplicate(deep)
