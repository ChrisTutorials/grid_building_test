extends GdUnitTestSuite

## Verifies that an indicator becomes invalid (valid == false) within a physics frame
## when overlapping a blocking StaticBody2D using a CollisionsCheckRule.

var logger: GBLogger
var targeting_state: GridTargetingState
var tile_map: TileMapLayer
var placer: Node
var preview: Node2D
var collisions_rule: CollisionsCheckRule
var params: RuleValidationParameters
var indicator: RuleCheckIndicator

func before_test():
	# Minimal targeting state setup
	targeting_state = auto_free(GridTargetingState.new(GBOwnerContext.new()))
	var positioner: Node2D = auto_free(Node2D.new())
	add_child(positioner)
	targeting_state.positioner = positioner
	# Simple tile map
	tile_map = auto_free(TileMapLayer.new())
	add_child(tile_map)
	tile_map.tile_set = load("uid://d11t2vm1pby6y")
	targeting_state.target_map = tile_map
	placer = auto_free(Node.new())
	add_child(placer)

	# Preview object with a collision body so rule can exclude it
	preview = auto_free(Node2D.new())
	add_child(preview)
	var preview_body := StaticBody2D.new()
	preview.add_child(preview_body)

	# Logger (using container factory if available)
	var debug_settings := GBDebugSettings.new(GBDebugSettings.DebugLevel.VERBOSE)
	logger = GBLogger.new(debug_settings)

	# Rule setup
	collisions_rule = CollisionsCheckRule.new()
	collisions_rule.collision_mask = 1
	collisions_rule.initialize(logger)
	params = RuleValidationParameters.new(placer, preview, targeting_state)
	collisions_rule.setup(params)

	# Indicator overlapping a static body
	indicator = auto_free(RuleCheckIndicator.new([collisions_rule], logger))
	indicator.shape = RectangleShape2D.new()
	indicator.shape.size = Vector2(16, 16)
	indicator.collision_mask = 1
	add_child(indicator)
	indicator.global_position = Vector2.ZERO

	var blocking_body := StaticBody2D.new()
	blocking_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16,16)
	shape.shape = rect
	blocking_body.add_child(shape)
	add_child(blocking_body)
	blocking_body.global_position = indicator.global_position

	# Link indicator to rule (already added via constructor but ensure array membership)
	if !collisions_rule.indicators.has(indicator):
		indicator.add_rule(collisions_rule)

func test_indicator_becomes_invalid_on_collision() -> void:
	# Allow a couple of frames for physics process to run
	await get_tree().process_frame
	indicator._physics_process(0.016) # Manual invoke to ensure update
	await get_tree().process_frame
	assert_bool(indicator.valid).append_failure_message("Indicator should be invalid due to collision").is_false()
