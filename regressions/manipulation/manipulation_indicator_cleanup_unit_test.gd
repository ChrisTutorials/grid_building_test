## Unit test isolating indicator cleanup bug in ManipulationSystem.cancel()
##
## BUG: When cancel() is called, indicators from previous manipulation persist
## Root Cause: ManipulationSystem.cancel() doesn't call IndicatorManager.clear()
##
## Expected: cancel() should clean up ALL indicators from the cancelled manipulation
## Actual: Indicators remain in scene tree, causing multiplication in subsequent operations
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var _env: AllSystemsTestEnvironment
var _indicator_manager: IndicatorManager
var _manipulation_system: ManipulationSystem
var _container: GBCompositionContainer
var _targeting_state: GridTargetingState

func before_test() -> void:
	# Use scene_runner for reliable frame simulation (avoids await isolation issues)
	runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	runner.simulate_frames(2)  # Initial setup frames
	
	_env = runner.scene() as AllSystemsTestEnvironment
	assert_that(_env).is_not_null()
	
	# Get systems from environment
	_container = _env.get_container()
	_manipulation_system = _env.manipulation_system
	_indicator_manager = _env.indicator_manager
	_targeting_state = _container.get_states().targeting

func after_test() -> void:
	# Clean up test state
	if _targeting_state:
		_targeting_state.collision_exclusions = []
	runner = null
	_env = null
	_manipulation_system = null
	_indicator_manager = null
	_targeting_state = null

## Test: IndicatorManager has indicators before cancel()
func test_indicators_exist_before_cancel() -> void:
	# Setup: Create test object and start move to generate indicators
	var test_object := _create_test_manipulatable("TestObject", Vector2(200, 200))
	
	# Start move (should generate indicators) - this is synchronous
	var move_data := _manipulation_system.try_move(test_object)
	assert_object(move_data).is_not_null().append_failure_message("try_move returned null")
	assert_object(move_data.status).is_equal(GBEnums.Status.STARTED).append_failure_message(
		"Move should have started. Status: %s, Message: %s" % [str(move_data.status), move_data.message]
	)
	
	# Validate placement to ensure indicators are fully set up
	var validation_result := _indicator_manager.validate_placement()
	
	# Get indicator count
	var indicators_before := _get_indicator_count()
	
	# Assert: Should have indicators before cancel
	assert_int(indicators_before).is_greater(0).append_failure_message(
		"Test setup failed: Expected indicators to be generated before cancel(), but found 0. " +
		"Validation result: %s, Move rules: %s" % [str(validation_result), str(test_object.get_move_rules())]
	)

## Test: cancel() should remove ALL indicators
func test_cancel_removes_all_indicators() -> void:
	# Setup: Create test object and start move
	var test_object := _create_test_manipulatable("TestObject", Vector2(200, 200))
	var move_data := _manipulation_system.try_move(test_object)
	assert_object(move_data).is_not_null()
	
	# Validate to ensure indicators are set up (synchronous)
	_indicator_manager.validate_placement()
	
	var indicators_before := _get_indicator_count()
	assert_int(indicators_before).is_greater(0)
	
	# Act: Cancel manipulation (synchronous)
	_manipulation_system.cancel()
	
	# Assert: All indicators should be removed (synchronous check)
	var indicators_after := _get_indicator_count()
	assert_int(indicators_after).is_equal(0).append_failure_message(
		"BUG: cancel() should remove all indicators. " +
		"Before: %d indicators, After: %d indicators" % [indicators_before, indicators_after]
	)

## Test: Multiple cancel() calls don't accumulate indicators
func test_sequential_move_cancel_no_indicator_accumulation() -> void:
	# Setup: Track indicator counts across multiple move/cancel cycles
	var counts: Array[int] = []
	
	# Perform 3 move/cancel cycles
	for i in range(3):
		var test_object := _create_test_manipulatable("TestObject_%d" % i, Vector2(200 + i * 100, 200))
		var move_data := _manipulation_system.try_move(test_object)
		assert_object(move_data).is_not_null()
		
		# Validate to ensure indicators are set up (synchronous)
		_indicator_manager.validate_placement()
		
		# Record indicator count before cancel
		counts.append(_get_indicator_count())
		
		# Cancel (synchronous)
		_manipulation_system.cancel()
	
	# Assert: All cycles should generate same number of indicators
	# If cancel() doesn't clean up, counts would be: [N, 2N, 3N]
	# Correct behavior: [N, N, N]
	var first_count := counts[0]
	for i in range(1, counts.size()):
		var current_count := counts[i]
		assert_int(current_count).is_equal(first_count).append_failure_message(
			"BUG: Indicator accumulation detected! Cycle 0: %d indicators, Cycle %d: %d indicators. Expected same count, but indicators are multiplying!" % [first_count, i, current_count]
		)

## Test: Indicator count after cancel should be exactly zero
func test_indicator_manager_empty_after_cancel() -> void:
	# Setup: Generate indicators
	var test_object := _create_test_manipulatable("TestObject", Vector2(200, 200))
	_manipulation_system.try_move(test_object)
	
	# Validate to ensure indicators are set up (synchronous)
	_indicator_manager.validate_placement()
	
	assert_int(_get_indicator_count()).is_greater(0)
	
	# Act: Cancel (synchronous)
	_manipulation_system.cancel()
	
	# Assert: IndicatorManager should report zero indicators (synchronous check)
	var indicator_children := _indicator_manager.get_children()
	var rule_check_indicators := indicator_children.filter(
		func(child: Node) -> bool: return child is RuleCheckIndicator
	)
	
	assert_int(rule_check_indicators.size()).is_equal(0).append_failure_message(
		"BUG: IndicatorManager still has %d RuleCheckIndicator children after cancel()" % 
		rule_check_indicators.size()
	)

## Helper: Create manipulatable test object
func _create_test_manipulatable(p_name: String, p_position: Vector2) -> Manipulatable:
	var root := Node2D.new()
	root.name = p_name
	root.position = p_position
	auto_free(root)
	
	# Add collision body
	var body := CharacterBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	body.add_child(shape)
	
	# Add manipulatable component
	var manipulatable := Manipulatable.new()
	manipulatable.name = "Manipulatable"
	manipulatable.root = root
	var settings := ManipulatableSettings.new()
	settings.movable = true
	
	# Add move rules to settings so indicators will be generated
	var collision_rule := CollisionsCheckRule.new()
	settings.move_rules = [collision_rule]
	manipulatable.settings = settings
	
	root.add_child(manipulatable)
	
	_env.add_child(root)
	runner.simulate_frames(1)
	
	return manipulatable

## Helper: Count indicators in IndicatorManager
func _get_indicator_count() -> int:
	var count := 0
	for child in _indicator_manager.get_children():
		if child is RuleCheckIndicator:
			count += 1
	return count
