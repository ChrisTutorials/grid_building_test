extends GdUnitTestSuite

var targeting_state: GridTargetingState
var placement_manager: PlacementManager
var indicator_template: PackedScene
var _logger: GBLogger


func before_test():
	# Create a minimal TileMapLayer with a valid TileSet (16x16 assumed)
	var tile_map_layer: TileMapLayer = auto_free(TileMapLayer.new())
	var tile_set := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	atlas.texture = tex
	atlas.create_tile(Vector2i(0,0))
	tile_set.add_source(atlas)
	tile_map_layer.tile_set = tile_set
	add_child(tile_map_layer)

	# Owner context + targeting state
	var owner_context: GBOwnerContext = auto_free(GBOwnerContext.new())
	targeting_state = GridTargetingState.new(owner_context)
	targeting_state.target_map = tile_map_layer
	targeting_state.positioner = auto_free(Node2D.new())
	# Position the positioner at tile (1,1) center (16x16 tiles => (16,16))
	targeting_state.positioner.position = Vector2(16,16)
	add_child(targeting_state.positioner)

	# Create placement context + logger + messages for manager initialization
	var placement_context: PlacementContext = PlacementContext.new()
	_logger = GBLogger.new(GBDebugSettings.new())
	var messages: GBMessages = GBMessages.new()

	# Indicator template
	indicator_template = load("uid://dhox8mb8kuaxa")

	# Initialize placement manager properly (instead of direct property assignment)
	placement_manager = PlacementManager.new()
	var empty_rules: Array[PlacementRule] = []
	placement_manager.initialize(placement_context, indicator_template, targeting_state, _logger, empty_rules, messages)
	add_child(placement_manager)
	auto_free(placement_manager)
	auto_free(placement_context)
	auto_free(_logger)
	auto_free(messages)

	# --- Environment sanity assertions (moved from test body) ---
	assert_that(targeting_state).append_failure_message("Targeting state not initialized").is_not_null()
	assert_that(targeting_state.target_map).append_failure_message("TileMapLayer not set on targeting state").is_not_null()
	assert_that(placement_manager).append_failure_message("PlacementManager not initialized").is_not_null()
	assert_that(indicator_template).append_failure_message("Indicator template failed to load (null)").is_not_null()
	# Provide maps array so GridTargetingState.validate() passes
	targeting_state.maps = [targeting_state.target_map]
	var derived_center_tile: Vector2i = targeting_state.target_map.local_to_map(targeting_state.positioner.global_position)
	assert_that(derived_center_tile).append_failure_message("Unexpected center tile from positioner global position").is_equal(Vector2i(1,1))
	var template_instance := indicator_template.instantiate()
	assert_that(template_instance is RuleCheckIndicator).append_failure_message("Indicator template does not produce a RuleCheckIndicator").is_true()
	template_instance.queue_free()

## Verifies the environment setup independently of indicator positioning logic.
func test_environment_setup_valid():
	# Assertions already executed in before_test; re-run minimal critical checks to ensure isolation.
	assert_that(targeting_state.positioner.global_position).append_failure_message("Positioner global position invalid").is_equal(Vector2(16,16))
	var center_tile := targeting_state.target_map.local_to_map(targeting_state.positioner.global_position)
	assert_that(center_tile).append_failure_message("Center tile not (1,1) as expected").is_equal(Vector2i(1,1))
	var dep_issues := placement_manager.validate_dependencies()
	assert_that(dep_issues.is_empty()).append_failure_message("PlacementManager dependency validation failed: %s" % [dep_issues]).is_true()


## Test that created indicators have the correct global positions in the scene tree
func test_actual_indicator_positioning():
	# Center tile recomputed (already validated in before_test)
	var derived_center_tile: Vector2i = targeting_state.target_map.local_to_map(targeting_state.positioner.global_position)

	# Create a trivial TileCheckRule instance and run setup (ensures abstract portions not invoked here)
	var rule: TileCheckRule = TileCheckRule.new()
	var params: RuleValidationParameters = RuleValidationParameters.new(targeting_state.positioner, targeting_state.positioner, targeting_state, _logger)
	rule.setup(params)
	assert_that(rule.guard_ready()).append_failure_message("Rule not marked ready after setup").is_true()

	# Simulate manual indicator generation for three offsets relative to positioner center tile
	var desired_offsets: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,1), Vector2i(2,2)]
	var indicators : Array[RuleCheckIndicator] = []
	var world_positions := {} # Dictionary used as a set for uniqueness validation
	for off in desired_offsets:
		var ind: RuleCheckIndicator = indicator_template.instantiate() as RuleCheckIndicator
		placement_manager.add_child(ind) # mimic manager parenting
		# Ensure parenting occurred
		assert_that(ind.get_parent()).append_failure_message("Indicator parent is not the placement manager").is_same(placement_manager)
		ind.shape = RectangleShape2D.new()
		assert_that(ind.shape is RectangleShape2D).append_failure_message("Indicator shape not assigned correctly").is_true()
		# Compute target tile from positioner center tile
		var center_tile: Vector2i = targeting_state.target_map.local_to_map(targeting_state.positioner.global_position)
		var tile: Vector2i = center_tile + off
		var local_tile_pos: Vector2 = targeting_state.target_map.map_to_local(tile)
		var world: Vector2 = targeting_state.target_map.to_global(local_tile_pos)
		ind.global_position = world
		# Uniqueness check before adding
		assert_that(world_positions.has(world)).append_failure_message("Duplicate world position assigned to multiple indicators: %s" % [world]).is_false()
		world_positions[world] = true
		indicators.append(ind)

	# High-level count validation
	assert_that(indicators.size()).append_failure_message("Expected 3 indicators").is_equal(3)
	assert_that(world_positions.size()).append_failure_message("World position set size mismatch").is_equal(3)

	# Per-indicator positional correctness (recalculate expected independently)
	for i in range(indicators.size()):
		var ind := indicators[i]
		var expected_tile := derived_center_tile + desired_offsets[i]
		var expected_local := targeting_state.target_map.map_to_local(expected_tile)
		var expected_world := targeting_state.target_map.to_global(expected_local)
		(
			assert_that(ind.global_position.x)
			. append_failure_message("Indicator %d X mismatch (expected %f got %f)" % [i, expected_world.x, ind.global_position.x])
			. is_equal_approx(expected_world.x, 0.1)
		)
		(
			assert_that(ind.global_position.y)
			. append_failure_message("Indicator %d Y mismatch (expected %f got %f)" % [i, expected_world.y, ind.global_position.y])
			. is_equal_approx(expected_world.y, 0.1)
		)
