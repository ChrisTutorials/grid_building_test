extends GdUnitTestSuite

# Tests for IndicatorService reconciliation behaviour: existing indicators should be reused
# when newly generated indicators share the same tile position. Reused indicators should
# have their rules cleared and then receive the new rules from the freshly-generated
# indicators. Newly-generated duplicates must be freed and not remain parented under
# the indicators parent.

var __service: IndicatorService
var __parent: Node2D
var __env: Node

func _create_env_and_service() -> Dictionary:
    var env_scene: PackedScene = GBTestConstants.get_environment_scene(GBTestConstants.EnvironmentType.ALL_SYSTEMS)
    # Use relaxed typing here because dependent environment classes may fail to compile in certain runs
    var env: Node = env_scene.instantiate()
    add_child(env)

    # Prepare a parent node for indicators
    var parent: Node2D = Node2D.new()
    add_child(parent)

    # Do not bind positioner here; caller will use env.positioner at runtime to avoid parse-time resolution
    var test_object: Node2D = null

    # Create IndicatorService with injection
    var container: GBCompositionContainer = env.get_container()
    var targeting: GridTargetingState = container.get_states().targeting
    var logger: GBLogger = container.get_logger()
    var template: PackedScene = GBTestConstants.TEST_INDICATOR_TD_PLATFORMER

    var service: IndicatorService = IndicatorService.new(parent, targeting, template, logger)
    service.resolve_gb_dependencies(container)
    # Save for teardown
    __service = service
    __parent = parent
    __env = env
    return {
        "env": env,
        "service": service,
        "parent": parent,
        "test_object": test_object,
        "container": container
    }

func before_test() -> void:
    # Proactively clear indicators and prior state to avoid orphans between retries
    if __service != null and __parent != null and is_instance_valid(__parent):
        __service.reset(__parent)
    if __parent != null and is_instance_valid(__parent):
        for child: Node in __parent.get_children():
            if child is RuleCheckIndicator:
                (child as RuleCheckIndicator).queue_free()
    __service = null
    __parent = null
    __env = null

func test_reconcile_reuses_existing_indicator_and_updates_rules() -> void:
    var ctx: Dictionary = _create_env_and_service()
    var service: IndicatorService = ctx["service"]
    var parent: Node = ctx["parent"]
    # Use the environment's positioner which is set up by the AllSystemsTestEnvironment
    var test_object: Node2D = ctx["env"].positioner

    # Build a simple position->rules map with one entry at offset (0,0)
    var rule_a: TileCheckRule = TileCheckRule.new()
    rule_a.resource_name = "A"
    var pos_map_1: Dictionary[Vector2i, Array] = {}
    pos_map_1[Vector2i(0,0)] = [rule_a]

    # Create an existing indicator via the factory (this will parent the node under `parent`)
    var existing_indicators: Array = IndicatorFactory.generate_indicators(pos_map_1, GBTestConstants.TEST_INDICATOR_TD_PLATFORMER, parent, ctx["container"].get_states().targeting, test_object)
    assert_that(existing_indicators.size() == 1)\
		.append_failure_message("Expected factory to create 1 existing indicator").is_true()
    var indicator1: RuleCheckIndicator = existing_indicators[0]
    assert_that(is_instance_valid(indicator1))\
		.append_failure_message("Existing indicator should be valid").is_true()

    # Register the existing indicators with the service (simulate prior state)
    service.set_indicators(existing_indicators)

    # Create a new indicator set (duplicate at same tile offset) with a different rule
    var rule_b: TileCheckRule = TileCheckRule.new()
    rule_b.resource_name = "B"
    var pos_map_2: Dictionary[Vector2i, Array] = {}
    pos_map_2[Vector2i(0,0)] = [rule_b]
    var new_indicators: Array = IndicatorFactory.generate_indicators(pos_map_2, GBTestConstants.TEST_INDICATOR_TD_PLATFORMER, parent, ctx["container"].get_states().targeting, test_object)
    assert_that(new_indicators.size() == 1)\
		.append_failure_message("Expected factory to create 1 new indicator").is_true()

    # Force new indicator to be at the exact same global_position as the existing one
    # to avoid any non-determinism in tile position computation across test environment variations.
    if new_indicators.size() > 0 and is_instance_valid(new_indicators[0]):
        new_indicators[0].global_position = indicator1.global_position

    # Call the internal reconcile function directly to test reuse semantics
    var reconciled: Array = service._reconcile_indicators(new_indicators)
    assert_that(reconciled.size() == 1)\
		.append_failure_message("Expected 1 reconciled indicator").is_true()

    var indicator2: RuleCheckIndicator = reconciled[0]
    # Should be the same instance (reused)
    assert_that(indicator1 == indicator2).append_failure_message("Expected indicator instance to be reused between reconcile calls").is_true()

    # The reused indicator should have had its rules updated to contain rule_b and not rule_a
    var rules_after: Array = indicator2.get_rules()
    assert_that(rules_after.size() == 1)\
		.append_failure_message("Reused indicator should have exactly 1 rule after reconcile").is_true()
    assert_that(rules_after[0].resource_name == "B")\
		.append_failure_message("Reused indicator's rule should be rule_b").is_true()

    # Diagnostic: ensure no duplicate indicator nodes remain parented under indicators parent
    var count_children: int = 0
    for child in parent.get_children():
        if child is RuleCheckIndicator:
            count_children += 1
    assert_that(count_children == 1).append_failure_message("Expected exactly one RuleCheckIndicator child under parent after reconcile").is_true()

func after_test() -> void:
    # Ensure all generated indicators are cleared to avoid orphans between tests
    if __service != null and __parent != null and is_instance_valid(__parent):
        __service.reset(__parent)
    if __parent != null and is_instance_valid(__parent):
        for child: Node in __parent.get_children():
            if child is RuleCheckIndicator:
                (child as RuleCheckIndicator).queue_free()
        __parent.queue_free()
    if __env != null and is_instance_valid(__env):
        __env.queue_free()
    __service = null
    __parent = null
    __env = null
