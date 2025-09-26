## Testing environment for collision tests. Collision mapper etc
class_name CollisionTestEnvironment
extends GBTestEnvironment

@export var indicator_manager : IndicatorManager

var collision_mapper : CollisionMapper
var logger : GBLogger

var rule_validation_parameters : Dictionary
var targeting_state : GridTargetingState
var container : GBCompositionContainer

func _ready() -> void:
	# Initialize container reference for convenience
	container = get_container()
	
	# Initialize logger from container
	if container:
		logger = container.get_logger()
	
	# Initialize rule validation parameters directly
	rule_validation_parameters = {
		"validation_container": container,
		"rule_context": GBOwnerContext.new(),
		"rules": []
	}
	
	# Initialize targeting state
	if container and container.get_states():
		targeting_state = container.get_states().targeting
		
		# Initialize collision mapper if we have the required components
		if targeting_state and logger:
			collision_mapper = CollisionMapper.new(targeting_state, logger)
	
	# Set up level context with proper targeting state configuration
	_setup_level_context()
	
	# Ensure indicator_manager references the injected manager from context
	if container:
		var indicator_context: IndicatorContext = container.get_indicator_context()
		if indicator_context and indicator_context.has_manager():
			# Use the injected manager from the context instead of any scene export
			indicator_manager = indicator_context.get_manager()

## Set up the level context with target map and apply to targeting state
func _setup_level_context() -> void:
	# Ensure level_context has target_map set
	if level_context.target_map == null:
		level_context.target_map = tile_map_layer
	if level_context.maps.is_empty():
		level_context.maps = [tile_map_layer]
	
	# Apply level context settings to targeting state
	if container and container.get_states():
		var states: GBStates = container.get_states()
		if states.targeting and states.building:
			level_context.apply_to(states.targeting, states.building)

func get_issues() -> Array[String]:
	var issues : Array[String] = super()
	
	if indicator_manager == null:
		issues.append("Missing IndicatorManager")
		
	var expects_zero_position := true
	if container and container.config and container.config.settings and container.config.settings.targeting:
		expects_zero_position = container.config.settings.targeting.position_on_enable_policy == GridTargetingSettings.RecenterOnEnablePolicy.NONE

	if expects_zero_position:
		if not positioner.global_position.is_equal_approx(Vector2.ZERO):
			issues.append("Global positioner is at unexpected location for test setup. Actual: %s Expected: %s" % [Vector2.ZERO, positioner.global_position])
	
	return issues

func get_container() -> GBCompositionContainer:
	return injector.composition_container
