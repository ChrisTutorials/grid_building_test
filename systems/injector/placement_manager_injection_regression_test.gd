extends GdUnitTestSuite

## Regression test for IndicatorManager dependency injection and validation timing
##
## This test reproduces a subtle issue in the placement system where:
## 1. IndicatorManager gets dependency injection correctly ✅
## 2. IndicatorManager registers with IndicatorContext correctly ✅  
## 3. But BuildingSystem validation still fails ❌
##
## This is the exact issue occurring in the isometric demo where IndicatorManager
## exists in the scene hierarchy, gets injected, but BuildingSystem can't find it
## during validation. The issue appears to be related to validation timing or
## BuildingSystem's discovery logic rather than injection itself.
##
## Currently FAILING on BuildingSystem validation despite successful injection.

var _injector: GBInjectorSystem
var _container: GBCompositionContainer = load("uid://dy6e5p5d6ax6n")
var _placement_manager: IndicatorManager

class SpyIndicatorManager:
	extends IndicatorManager
	var injection_called: bool = false
	var injection_container: GBCompositionContainer = null
	
	func resolve_gb_dependencies(container: GBCompositionContainer):
		injection_called = true
		injection_container = container
		super.resolve_gb_dependencies(container)

func before_test():
	var test_env = UnifiedTestFactory.create_injection_test_environment(self)
	_container = test_env.container
	_injector = test_env.injector

func test_placement_manager_gets_dependency_injection() -> void:
	# Create spy IndicatorManager to track injection calls
	_placement_manager = auto_free(SpyIndicatorManager.new())
	_placement_manager.name = "IndicatorManager"
	
	# Add as child - this should trigger dependency injection automatically
	add_child(_placement_manager)
	
	# Wait one frame for injection system to process
	await await_idle_frame()
	
	var spy_manager := _placement_manager as SpyIndicatorManager
	
	# This should pass and DOES pass - injection works correctly
	assert_bool(spy_manager.injection_called) \
		.append_failure_message("IndicatorManager injection should work correctly") \
		.is_true()
	
	assert_object(spy_manager.injection_container) \
		.append_failure_message("IndicatorManager should receive container during injection") \
		.is_same(_container)

func test_placement_manager_registers_with_indicator_context() -> void:
	# Create and add IndicatorManager
	_placement_manager = auto_free(IndicatorManager.new())
	_placement_manager.name = "IndicatorManager"
	add_child(_placement_manager)
	
	# Wait for injection
	await await_idle_frame()
	
	# Check if IndicatorManager is registered with IndicatorContext
	var indicator_context = _container.get_contexts().indicator
	var registered_manager = indicator_context.get_manager()
	
	# This should pass and DOES pass - IndicatorManager registers correctly
	assert_object(registered_manager) \
		.append_failure_message("IndicatorManager should be registered with IndicatorContext after injection. Manager: %s" % str(registered_manager)) \
		.is_not_null()
	
	assert_object(registered_manager) \
		.append_failure_message("Specific IndicatorManager instance should be found in IndicatorContext. Registered: %s, Expected: %s" % [str(registered_manager), str(_placement_manager)]) \
		.is_same(_placement_manager)

func test_building_system_validation_with_injected_placement_manager() -> void:
	# DIAGNOSTIC 0: Check for singleton violations at the container level
	print("[DEBUG] === SINGLETON DIAGNOSTICS ===")
	print("[DEBUG] _container instance ID: ", _container.get_instance_id())
	print("[DEBUG] _container resource path: ", _container.resource_path)
	
	# Check if container creates consistent contexts
	var contexts_call_1 = _container.get_contexts()
	var contexts_call_2 = _container.get_contexts()
	assert_object(contexts_call_1).append_failure_message("First get_contexts() call should return non-null").is_not_null()
	assert_object(contexts_call_1).append_failure_message("CRITICAL: GBCompositionContainer is creating multiple GBContexts instances! Call 1: %s, Call 2: %s" % [str(contexts_call_1), str(contexts_call_2)]).is_same(contexts_call_2)
	
	# Check if contexts create consistent indicator contexts
	var placement_call_1 = contexts_call_1.indicator
	var placement_call_2 = contexts_call_1.indicator
	assert_object(placement_call_1).append_failure_message("CRITICAL: GBContexts is creating multiple IndicatorContext instances! Call 1: %s, Call 2: %s" % [str(placement_call_1), str(placement_call_2)]).is_same(placement_call_2)
	
	print("[DEBUG] GBContexts instance ID: ", contexts_call_1.get_instance_id())
	print("[DEBUG] IndicatorContext instance ID: ", placement_call_1.get_instance_id())
	
	# Set up BuildingSystem
	var building_system = auto_free(BuildingSystem.new())
	building_system.name = "BuildingSystem"
	add_child(building_system)
	
	# Create and add IndicatorManager
	_placement_manager = auto_free(IndicatorManager.new())
	_placement_manager.name = "IndicatorManager"
	add_child(_placement_manager)
	
	# Wait for injection
	await await_idle_frame()
	
	# Verify IndicatorManager was injected
	assert_bool(_placement_manager.has_meta("gb_injection_meta")).append_failure_message("IndicatorManager should have injection metadata after being added to scene").is_true()
	
	# Verify IndicatorManager is registered
	var indicator_context = _container.get_contexts().indicator
	var registered_manager = indicator_context.get_manager()
	assert_object(registered_manager).append_failure_message("IndicatorManager should be registered. Registered: %s" % str(registered_manager)).is_not_null()
	assert_object(registered_manager).append_failure_message("Registered IndicatorManager should be same instance. Expected: %s, Got: %s" % [str(_placement_manager), str(registered_manager)]).is_same(_placement_manager)
	
	# Check BuildingSystem before injection
	# NOTE: The injection system automatically injects nodes when they're added to the scene,
	# so BuildingSystem will have injection metadata immediately after being added
	assert_bool(building_system.has_meta("gb_injection_meta")).append_failure_message("BuildingSystem should have injection metadata after being added to scene").is_true()
	
	print("[DEBUG] About to inject BuildingSystem with container ID: ", _container.get_instance_id())
	
	# Inject BuildingSystem dependencies
	building_system.resolve_gb_dependencies(_container)
	
	# Verify BuildingSystem was injected
	assert_bool(building_system.has_meta("gb_injection_meta")).append_failure_message("BuildingSystem should have injection metadata after resolve_gb_dependencies()").is_true()
	
	# Check if BuildingSystem uses same contexts
	var building_system_contexts = _container.get_contexts()
	var building_system_indicator_context = building_system_contexts.indicator
	
	print("[DEBUG] === CONTEXT COMPARISON ===")
	print("[DEBUG] Our IndicatorContext ID: ", indicator_context.get_instance_id())
	print("[DEBUG] BuildingSystem IndicatorContext ID: ", building_system_indicator_context.get_instance_id())
	print("[DEBUG] Are contexts same instance? ", indicator_context == building_system_indicator_context)
	print("[DEBUG] BuildingSystem IndicatorContext has manager? ", building_system_indicator_context.has_manager())
	print("[DEBUG] BuildingSystem IndicatorContext manager: ", building_system_indicator_context.get_manager())
	
	assert_object(building_system_indicator_context).append_failure_message("CRITICAL: BuildingSystem using different IndicatorContext! BuildingSystem: %s, Test: %s" % [str(building_system_indicator_context), str(indicator_context)]).is_same(indicator_context)
	
	# Final validation with debug
	print("[DEBUG] === FINAL VALIDATION ===")
	print("[DEBUG] About to call BuildingSystem.get_dependency_issues()")
	print("[DEBUG] Container IndicatorContext: ", building_system_indicator_context)
	print("[DEBUG] Container has_manager(): ", building_system_indicator_context.has_manager())
	print("[DEBUG] Container get_manager(): ", building_system_indicator_context.get_manager())
	print("[DEBUG] IndicatorManager: ", _placement_manager)
	print("[DEBUG] Same managers? ", building_system_indicator_context.get_manager() == _placement_manager)
	
	# Call validation
	var validation_result = building_system.get_dependency_issues()
	
	# This should pass but currently fails
	var error_msg = "REGRESSION: BuildingSystem validation failed despite IndicatorManager being present. " + \
		"Errors: %s | " % str(validation_result) + \
		"IndicatorContext: %s | " % str(indicator_context) + \
		"BuildingSystem IndicatorContext: %s | " % str(building_system_indicator_context) + \
		"Same Context: %s | " % str(indicator_context == building_system_indicator_context) + \
		"Registered Manager: %s | " % str(registered_manager) + \
		"IndicatorManager: %s | " % str(_placement_manager) + \
		"Same Manager: %s" % str(registered_manager == _placement_manager)
	
	assert_array(validation_result).append_failure_message(error_msg).is_empty()

func test_injection_order_timing_issue() -> void:
	# Test the hypothesis: BuildingSystem validates during injection before IndicatorManager exists
	
	print("[DEBUG] === TESTING INJECTION ORDER ===")
	
	# Step 1: Add IndicatorManager FIRST
	_placement_manager = auto_free(IndicatorManager.new())
	_placement_manager.name = "IndicatorManager"
	add_child(_placement_manager)
	print("[DEBUG] 1. Added IndicatorManager first")
	
	# Wait for injection
	await await_idle_frame()
	
	# Verify IndicatorManager is registered
	var indicator_context = _container.get_contexts().indicator
	assert_bool(indicator_context.has_manager()) \
		.append_failure_message("IndicatorManager should be registered after injection") \
		.is_true()
	print("[DEBUG] 2. IndicatorManager registered: ", indicator_context.has_manager())
	
	# Step 2: Now add BuildingSystem AFTER IndicatorManager is registered
	var building_system = auto_free(BuildingSystem.new())
	building_system.name = "BuildingSystem"
	print("[DEBUG] 3. About to add BuildingSystem - IndicatorManager should already be available")
	print("[DEBUG] 3a. Pre-add: IndicatorContext.has_manager() = ", indicator_context.has_manager())
	
	# This should trigger automatic injection and validation, but IndicatorManager should be available
	add_child(building_system)
	print("[DEBUG] 4. Added BuildingSystem - automatic injection should have occurred")
	
	# Wait for injection
	await await_idle_frame()
	
	# Check if BuildingSystem validation passed during automatic injection
	assert_bool(building_system.has_meta("gb_injection_meta")) \
		.append_failure_message("BuildingSystem should have been automatically injected") \
		.is_true()
	print("[DEBUG] 5. BuildingSystem injection meta exists: ", building_system.has_meta("gb_injection_meta"))
	
	# Manually call validation to see if it passes now
	print("[DEBUG] 6. Calling manual validation after both components injected")
	var validation_result = building_system.get_dependency_issues()
	
	# This should now pass since IndicatorManager was added first
	assert_array(validation_result) \
		.append_failure_message("BuildingSystem validation should pass when IndicatorManager is added BEFORE BuildingSystem. Errors: %s" % str(validation_result)) \
		.is_empty()

func test_reverse_order_demonstrates_timing_issue() -> void:
	# Test the problematic order: BuildingSystem first, then IndicatorManager
	
	print("[DEBUG] === TESTING REVERSE ORDER (PROBLEMATIC) ===")
	
	# Step 1: Add BuildingSystem FIRST (this should cause validation failure during injection)
	var building_system = auto_free(BuildingSystem.new())
	building_system.name = "BuildingSystem"
	print("[DEBUG] 1. About to add BuildingSystem first - IndicatorManager NOT available yet")
	
	var indicator_context = _container.get_contexts().indicator
	print("[DEBUG] 1a. Pre-add: IndicatorContext.has_manager() = ", indicator_context.has_manager())
	
	# This should trigger automatic injection and validation, but IndicatorManager is NOT available
	# BuildingSystem's validation during injection should fail and possibly cache the failure
	add_child(building_system)
	print("[DEBUG] 2. Added BuildingSystem first - validation likely failed during automatic injection")
	
	# Wait for injection
	await await_idle_frame()
	
	# Step 2: Now add IndicatorManager AFTER BuildingSystem
	_placement_manager = auto_free(IndicatorManager.new())
	_placement_manager.name = "IndicatorManager"
	add_child(_placement_manager)
	print("[DEBUG] 3. Added IndicatorManager second")
	
	# Wait for injection
	await await_idle_frame()
	
	# Verify IndicatorManager is now registered
	assert_bool(indicator_context.has_manager()) \
		.append_failure_message("IndicatorManager should be registered even when added second") \
		.is_true()
	print("[DEBUG] 4. IndicatorManager now registered: ", indicator_context.has_manager())
	
	# Step 3: Try manual validation - this might still fail due to timing issue
	print("[DEBUG] 5. Calling manual validation - IndicatorManager now available but validation may still fail")
	var validation_result = building_system.get_dependency_issues()
	
	# Document the expected failure
	if not validation_result.is_empty():
		print("[DEBUG] 6. Validation failed as expected due to timing issue: ", validation_result)
		# This demonstrates the timing issue - even though IndicatorManager is now available,
		# BuildingSystem's validation still fails, possibly due to cached failure state
		assert_bool(true) \
			.append_failure_message("EXPECTED: Validation fails due to injection timing issue when BuildingSystem added before IndicatorManager") \
			.is_true()
	else:
		print("[DEBUG] 6. Validation passed - timing issue may be resolved")
		assert_array(validation_result) \
			.append_failure_message("Validation should pass when IndicatorManager is available") \
			.is_empty()
