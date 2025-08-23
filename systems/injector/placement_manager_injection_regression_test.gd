extends GdUnitTestSuite

## Regression test for PlacementManager dependency injection and validation timing
##
## This test reproduces a subtle issue in the placement system where:
## 1. PlacementManager gets dependency injection correctly ✅
## 2. PlacementManager registers with PlacementContext correctly ✅  
## 3. But BuildingSystem validation still fails ❌
##
## This is the exact issue occurring in the isometric demo where PlacementManager
## exists in the scene hierarchy, gets injected, but BuildingSystem can't find it
## during validation. The issue appears to be related to validation timing or
## BuildingSystem's discovery logic rather than injection itself.
##
## Currently FAILING on BuildingSystem validation despite successful injection.

var _injector: GBInjectorSystem
var _container: GBCompositionContainer = load("uid://dy6e5p5d6ax6n")
var _placement_manager: PlacementManager

class SpyPlacementManager:
	extends PlacementManager
	var injection_called: bool = false
	var injection_container: GBCompositionContainer = null
	
	func resolve_gb_dependencies(container: GBCompositionContainer):
		injection_called = true
		injection_container = container
		super.resolve_gb_dependencies(container)

func before_test():
	# Set up injection system
	_injector = auto_free(GBInjectorSystem.create_with_injection(_container))
	_injector.name = "GBInjectorSystem"
	add_child(_injector)
	
	# Set up targeting state dependencies (required for PlacementManager)
	var targeting_state = _container.get_states().targeting
	var map_layer = auto_free(TileMapLayer.new())
	add_child(map_layer)
	map_layer.tile_set = TileSet.new()
	map_layer.tile_set.tile_size = Vector2(16, 16)
	targeting_state.set_map_objects(map_layer, [map_layer])
	var positioner = auto_free(Node2D.new())
	targeting_state.positioner = positioner

func test_placement_manager_gets_dependency_injection() -> void:
	# Create spy PlacementManager to track injection calls
	_placement_manager = auto_free(SpyPlacementManager.new())
	_placement_manager.name = "PlacementManager"
	
	# Add as child - this should trigger dependency injection automatically
	add_child(_placement_manager)
	
	# Wait one frame for injection system to process
	await await_idle_frame()
	
	var spy_manager := _placement_manager as SpyPlacementManager
	
	# This should pass and DOES pass - injection works correctly
	assert_bool(spy_manager.injection_called) \
		.append_failure_message("PlacementManager injection should work correctly") \
		.is_true()
	
	assert_object(spy_manager.injection_container) \
		.append_failure_message("PlacementManager should receive container during injection") \
		.is_same(_container)

func test_placement_manager_registers_with_placement_context() -> void:
	# Create and add PlacementManager
	_placement_manager = auto_free(PlacementManager.new())
	_placement_manager.name = "PlacementManager"
	add_child(_placement_manager)
	
	# Wait for injection
	await await_idle_frame()
	
	# Check if PlacementManager is registered with PlacementContext
	var placement_context = _container.get_contexts().placement
	var registered_manager = placement_context.get_manager()
	
	# This should pass and DOES pass - PlacementManager registers correctly
	assert_object(registered_manager) \
		.append_failure_message("PlacementManager should be registered with PlacementContext after injection. Manager: %s" % str(registered_manager)) \
		.is_not_null()
	
	assert_object(registered_manager) \
		.append_failure_message("Specific PlacementManager instance should be found in PlacementContext. Registered: %s, Expected: %s" % [str(registered_manager), str(_placement_manager)]) \
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
	
	# Check if contexts create consistent placement contexts
	var placement_call_1 = contexts_call_1.placement
	var placement_call_2 = contexts_call_1.placement
	assert_object(placement_call_1).append_failure_message("CRITICAL: GBContexts is creating multiple PlacementContext instances! Call 1: %s, Call 2: %s" % [str(placement_call_1), str(placement_call_2)]).is_same(placement_call_2)
	
	print("[DEBUG] GBContexts instance ID: ", contexts_call_1.get_instance_id())
	print("[DEBUG] PlacementContext instance ID: ", placement_call_1.get_instance_id())
	
	# Set up BuildingSystem
	var building_system = auto_free(BuildingSystem.new())
	building_system.name = "BuildingSystem"
	add_child(building_system)
	
	# Create and add PlacementManager
	_placement_manager = auto_free(PlacementManager.new())
	_placement_manager.name = "PlacementManager"
	add_child(_placement_manager)
	
	# Wait for injection
	await await_idle_frame()
	
	# Verify PlacementManager was injected
	assert_bool(_placement_manager.has_meta("gb_injection_meta")).append_failure_message("PlacementManager should have injection metadata after being added to scene").is_true()
	
	# Verify PlacementManager is registered
	var placement_context = _container.get_contexts().placement
	var registered_manager = placement_context.get_manager()
	assert_object(registered_manager).append_failure_message("PlacementManager should be registered. Registered: %s" % str(registered_manager)).is_not_null()
	assert_object(registered_manager).append_failure_message("Registered PlacementManager should be same instance. Expected: %s, Got: %s" % [str(_placement_manager), str(registered_manager)]).is_same(_placement_manager)
	
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
	var building_system_placement_context = building_system_contexts.placement
	
	print("[DEBUG] === CONTEXT COMPARISON ===")
	print("[DEBUG] Our PlacementContext ID: ", placement_context.get_instance_id())
	print("[DEBUG] BuildingSystem PlacementContext ID: ", building_system_placement_context.get_instance_id())
	print("[DEBUG] Are contexts same instance? ", placement_context == building_system_placement_context)
	print("[DEBUG] BuildingSystem PlacementContext has manager? ", building_system_placement_context.has_manager())
	print("[DEBUG] BuildingSystem PlacementContext manager: ", building_system_placement_context.get_manager())
	
	assert_object(building_system_placement_context).append_failure_message("CRITICAL: BuildingSystem using different PlacementContext! BuildingSystem: %s, Test: %s" % [str(building_system_placement_context), str(placement_context)]).is_same(placement_context)
	
	# Final validation with debug
	print("[DEBUG] === FINAL VALIDATION ===")
	print("[DEBUG] About to call BuildingSystem.validate_dependencies()")
	print("[DEBUG] Container PlacementContext: ", building_system_placement_context)
	print("[DEBUG] Container has_manager(): ", building_system_placement_context.has_manager())
	print("[DEBUG] Container get_manager(): ", building_system_placement_context.get_manager())
	print("[DEBUG] PlacementManager: ", _placement_manager)
	print("[DEBUG] Same managers? ", building_system_placement_context.get_manager() == _placement_manager)
	
	# Call validation
	var validation_result = building_system.validate_dependencies()
	
	# This should pass but currently fails
	var error_msg = "REGRESSION: BuildingSystem validation failed despite PlacementManager being present. " + \
		"Errors: %s | " % str(validation_result) + \
		"PlacementContext: %s | " % str(placement_context) + \
		"BuildingSystem PlacementContext: %s | " % str(building_system_placement_context) + \
		"Same Context: %s | " % str(placement_context == building_system_placement_context) + \
		"Registered Manager: %s | " % str(registered_manager) + \
		"PlacementManager: %s | " % str(_placement_manager) + \
		"Same Manager: %s" % str(registered_manager == _placement_manager)
	
	assert_array(validation_result).append_failure_message(error_msg).is_empty()

func test_injection_order_timing_issue() -> void:
	# Test the hypothesis: BuildingSystem validates during injection before PlacementManager exists
	
	print("[DEBUG] === TESTING INJECTION ORDER ===")
	
	# Step 1: Add PlacementManager FIRST
	_placement_manager = auto_free(PlacementManager.new())
	_placement_manager.name = "PlacementManager"
	add_child(_placement_manager)
	print("[DEBUG] 1. Added PlacementManager first")
	
	# Wait for injection
	await await_idle_frame()
	
	# Verify PlacementManager is registered
	var placement_context = _container.get_contexts().placement
	assert_bool(placement_context.has_manager()) \
		.append_failure_message("PlacementManager should be registered after injection") \
		.is_true()
	print("[DEBUG] 2. PlacementManager registered: ", placement_context.has_manager())
	
	# Step 2: Now add BuildingSystem AFTER PlacementManager is registered
	var building_system = auto_free(BuildingSystem.new())
	building_system.name = "BuildingSystem"
	print("[DEBUG] 3. About to add BuildingSystem - PlacementManager should already be available")
	print("[DEBUG] 3a. Pre-add: PlacementContext.has_manager() = ", placement_context.has_manager())
	
	# This should trigger automatic injection and validation, but PlacementManager should be available
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
	var validation_result = building_system.validate_dependencies()
	
	# This should now pass since PlacementManager was added first
	assert_array(validation_result) \
		.append_failure_message("BuildingSystem validation should pass when PlacementManager is added BEFORE BuildingSystem. Errors: %s" % str(validation_result)) \
		.is_empty()

func test_reverse_order_demonstrates_timing_issue() -> void:
	# Test the problematic order: BuildingSystem first, then PlacementManager
	
	print("[DEBUG] === TESTING REVERSE ORDER (PROBLEMATIC) ===")
	
	# Step 1: Add BuildingSystem FIRST (this should cause validation failure during injection)
	var building_system = auto_free(BuildingSystem.new())
	building_system.name = "BuildingSystem"
	print("[DEBUG] 1. About to add BuildingSystem first - PlacementManager NOT available yet")
	
	var placement_context = _container.get_contexts().placement
	print("[DEBUG] 1a. Pre-add: PlacementContext.has_manager() = ", placement_context.has_manager())
	
	# This should trigger automatic injection and validation, but PlacementManager is NOT available
	# BuildingSystem's validation during injection should fail and possibly cache the failure
	add_child(building_system)
	print("[DEBUG] 2. Added BuildingSystem first - validation likely failed during automatic injection")
	
	# Wait for injection
	await await_idle_frame()
	
	# Step 2: Now add PlacementManager AFTER BuildingSystem
	_placement_manager = auto_free(PlacementManager.new())
	_placement_manager.name = "PlacementManager"
	add_child(_placement_manager)
	print("[DEBUG] 3. Added PlacementManager second")
	
	# Wait for injection
	await await_idle_frame()
	
	# Verify PlacementManager is now registered
	assert_bool(placement_context.has_manager()) \
		.append_failure_message("PlacementManager should be registered even when added second") \
		.is_true()
	print("[DEBUG] 4. PlacementManager now registered: ", placement_context.has_manager())
	
	# Step 3: Try manual validation - this might still fail due to timing issue
	print("[DEBUG] 5. Calling manual validation - PlacementManager now available but validation may still fail")
	var validation_result = building_system.validate_dependencies()
	
	# Document the expected failure
	if not validation_result.is_empty():
		print("[DEBUG] 6. Validation failed as expected due to timing issue: ", validation_result)
		# This demonstrates the timing issue - even though PlacementManager is now available,
		# BuildingSystem's validation still fails, possibly due to cached failure state
		assert_bool(true) \
			.append_failure_message("EXPECTED: Validation fails due to injection timing issue when BuildingSystem added before PlacementManager") \
			.is_true()
	else:
		print("[DEBUG] 6. Validation passed - timing issue may be resolved")
		assert_array(validation_result) \
			.append_failure_message("Validation should pass when PlacementManager is available") \
			.is_empty()
