class_name BuildingTestEnvironment
extends GBTestEnvironment

@export var building_system : BuildingSystem
@export var gb_owner : GBOwner
@export var manipulation_parent : ManipulationParent
@export var indicator_manager : IndicatorManager

func get_issues() -> Array[String]:
	var issues : Array[String] = []
	issues.append_array(super())
	
	## We evaluate at this level because a positioner stack is set here so it should be fully valid now.
	issues.append_array(grid_targeting_system.get_runtime_issues())
	
	if building_system == null:
		issues.append("Missing BuildingSystem")

	# Validate setup
	issues.append_array(building_system.get_runtime_issues())
	issues.append_array(level_context.get_runtime_issues())
	issues.append_array(injector.get_runtime_issues())

	# Ensure level_context has target_map set
	if level_context.target_map == null:
		level_context.target_map = tile_map_layer
	if level_context.maps.is_empty():
		level_context.maps = [tile_map_layer]

	# Ensure tiles are placed between -5 x,y and +5 x,y for collision testing
	for x in range(-5, 6):
		for y in range(-5, 6):
			var tile_coords: Vector2i = Vector2i(x, y)
			if tile_map_layer.get_cell_source_id(tile_coords) == -1:
				# Place a default tile if missing
				tile_map_layer.set_cell(tile_coords, 0, Vector2i(0, 0))

	return issues

func _ready() -> void:
	# Ensure indicator_manager references the injected manager from context
	if get_container():
		var indicator_context: IndicatorContext = get_container().get_indicator_context()
		if indicator_context and indicator_context.has_manager():
			# Use the injected manager from the context instead of any scene export
			indicator_manager = indicator_context.get_manager()
		
		# Configure runtime checks - BuildingTestEnvironment intentionally has no manipulation system
		var runtime_checks: GBRuntimeChecks = get_container().get_runtime_checks()
		if runtime_checks:
			runtime_checks.manipulation_system = false

func get_container() -> GBCompositionContainer:
	return injector.composition_container
	
## Returns the collision mapper used by the indicator manager
func get_collision_mapper() -> CollisionMapper:
	return indicator_manager.get_collision_mapper() if indicator_manager else null

func get_owner_root() -> Node:
	return gb_owner.owner_root
