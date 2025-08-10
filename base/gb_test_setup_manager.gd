class_name GBTestSetupManager
extends RefCounted

## Test setup manager that provides robust, validated test environments
## to minimize setup failure points and ensure consistent test behavior

const TEST_CONTAINER: GBCompositionContainer = preload("uid://dy6e5p5d6ax6n")

# ================================
# Setup Validation
# ================================

## Validate that all required dependencies are available
static func validate_dependencies(test: GdUnitTestSuite) -> bool:
	var issues = []
	
	# Check if test container is available
	if not TEST_CONTAINER:
		issues.append("Test container not available")
	
	# Check if required scripts are loadable
	var required_scripts = [
		"BuildingSystem",
		"ManipulationSystem", 
		"GridTargetingSystem",
		"PlacementManager",
		"PlacementContext"
	]
	
	for script_name in required_scripts:
		if not ClassDB.class_exists(script_name):
			issues.append("Required class %s not found" % script_name)
	
	if issues.size() > 0:
		for issue in issues:
			test.log("Dependency Issue: %s" % issue)
		return false
	
	return true

## Validate that a test setup is complete and ready
static func validate_test_setup(setup: Dictionary, required_components: Array[String], test: GdUnitTestSuite) -> bool:
	var missing_components = []
	
	for component in required_components:
		if not setup.has(component) or setup[component] == null:
			missing_components.append(component)
	
	if missing_components.size() > 0:
		test.log("Missing components: %s" % missing_components)
		return false
	
	return true

# ================================
# Robust Setup Methods
# ================================

## Create a complete building system test environment with validation
static func create_robust_building_system_test(test: GdUnitTestSuite) -> Dictionary:
	# Validate dependencies first
	if not validate_dependencies(test):
		test.fail("Dependencies not available")
		return {}
	
	var setup = {}
	
	# Create container and states
	setup.container = TEST_CONTAINER
	setup.states = setup.container.get_states()
	
	# Create basic scene components
	setup.placer = GodotTestFactory.create_node2d(test)
	setup.placed_parent = GodotTestFactory.create_node2d(test)
	setup.grid_positioner = GodotTestFactory.create_node2d(test)
	setup.map_layer = GodotTestFactory.create_tile_map_layer(test)
	
	# Setup targeting state
	setup.targeting_state = setup.states.targeting
	setup.targeting_state.positioner = setup.grid_positioner
	setup.targeting_state.target_map = setup.map_layer
	setup.targeting_state.maps = [setup.map_layer]
	
	# Setup building state
	setup.user_context = _create_robust_owner_context(setup.placer, test)
	setup.states.building.placer_state = setup.user_context
	setup.states.building.placed_parent = setup.placed_parent
	
	# Create and validate building system
	setup.system = BuildingSystem.create_with_injection(setup.container)
	test.auto_free(setup.system)
	test.add_child(setup.system)
	
	# Validate system dependencies
	if setup.system.has_method("validate_dependencies"):
		var issues = setup.system.validate_dependencies()
		if issues.size() > 0:
			test.log("Building system dependency issues: %s" % issues)
	
	# Create placement manager
	setup.placement_manager = _create_robust_placement_manager(setup.grid_positioner, setup.container, test)
	setup.placement_context = _create_robust_placement_context(test)
	
	# Validate complete setup
	var required_components = [
		"container", "states", "placer", "placed_parent", "grid_positioner",
		"map_layer", "targeting_state", "user_context", "system",
		"placement_manager", "placement_context"
	]
	
	if not validate_test_setup(setup, required_components, test):
		test.fail("Building system test setup incomplete")
		return {}
	
	test.log("Building system test setup completed successfully")
	return setup

## Create a complete manipulation system test environment with validation
static func create_robust_manipulation_system_test(test: GdUnitTestSuite) -> Dictionary:
	if not validate_dependencies(test):
		test.fail("Dependencies not available")
		return {}
	
	var setup = {}
	
	# Create container and states
	setup.container = TEST_CONTAINER
	setup.states = setup.container.get_states()
	
	# Create basic scene components
	setup.placer = GodotTestFactory.create_node2d(test)
	setup.placed_parent = GodotTestFactory.create_node2d(test)
	setup.grid_positioner = GodotTestFactory.create_node2d(test)
	setup.map_layer = GodotTestFactory.create_tile_map_layer(test)
	
	# Setup targeting state
	setup.targeting_state = setup.states.targeting
	setup.targeting_state.positioner = setup.grid_positioner
	setup.targeting_state.target_map = setup.map_layer
	setup.targeting_state.maps = [setup.map_layer]
	
	# Setup manipulation state
	setup.manipulation_state = setup.states.manipulation
	setup.manipulation_state.targeting_state = setup.targeting_state
	
	# Create and validate manipulation system
	setup.system = ManipulationSystem.create_with_injection(setup.container)
	test.auto_free(setup.system)
	test.add_child(setup.system)
	
	# Validate system dependencies
	if setup.system.has_method("validate_dependencies"):
		var issues = setup.system.validate_dependencies()
		if issues.size() > 0:
			test.log("Manipulation system dependency issues: %s" % issues)
	
	# Validate complete setup
	var required_components = [
		"container", "states", "placer", "placed_parent", "grid_positioner",
		"map_layer", "targeting_state", "manipulation_state", "system"
	]
	
	if not validate_test_setup(setup, required_components, test):
		test.fail("Manipulation system test setup incomplete")
		return {}
	
	test.log("Manipulation system test setup completed successfully")
	return setup

## Create a complete grid targeting system test environment with validation
static func create_robust_grid_targeting_system_test(test: GdUnitTestSuite) -> Dictionary:
	if not validate_dependencies(test):
		test.fail("Dependencies not available")
		return {}
	
	var setup = {}
	
	# Create container and states
	setup.container = TEST_CONTAINER
	setup.states = setup.container.get_states()
	
	# Create basic scene components
	setup.placer = GodotTestFactory.create_node2d(test)
	setup.placed_parent = GodotTestFactory.create_node2d(test)
	setup.grid_positioner = GodotTestFactory.create_node2d(test)
	setup.map_layer = GodotTestFactory.create_tile_map_layer(test)
	
	# Setup targeting state
	setup.targeting_state = setup.states.targeting
	setup.targeting_state.positioner = setup.grid_positioner
	setup.targeting_state.target_map = setup.map_layer
	setup.targeting_state.maps = [setup.map_layer]
	
	# Create and validate grid targeting system
	setup.system = GridTargetingSystem.create_with_injection(setup.container)
	test.auto_free(setup.system)
	test.add_child(setup.system)
	
	# Validate system dependencies
	if setup.system.has_method("validate_dependencies"):
		var issues = setup.system.validate_dependencies()
		if issues.size() > 0:
			test.log("Grid targeting system dependency issues: %s" % issues)
	
	# Validate complete setup
	var required_components = [
		"container", "states", "placer", "placed_parent", "grid_positioner",
		"map_layer", "targeting_state", "system"
	]
	
	if not validate_test_setup(setup, required_components, test):
		test.fail("Grid targeting system test setup incomplete")
		return {}
	
	test.log("Grid targeting system test setup completed successfully")
	return setup

# ================================
# Helper Setup Methods
# ================================

## Create a robust owner context with validation
static func _create_robust_owner_context(owner_node: Node, test: GdUnitTestSuite) -> GBOwnerContext:
	var context = GBOwnerContext.new()
	var gb_owner = GBOwner.new(owner_node)
	context.set_owner(gb_owner)
	
	# Validate context creation
	if not context or not context.get_owner():
		test.fail("Failed to create valid owner context")
		return null
	
	return context

## Create a robust placement manager with validation
static func _create_robust_placement_manager(
	grid_positioner: Node2D,
	container: GBCompositionContainer,
	test: GdUnitTestSuite
) -> PlacementManager:
	var placement_manager = PlacementManager.new()
	test.auto_free(placement_manager)
	
	# Resolve dependencies
	placement_manager.resolve_gb_dependencies(container)
	
	# Add to scene
	grid_positioner.add_child(placement_manager)
	
	# Validate manager creation
	if not placement_manager or not placement_manager.get_parent():
		test.fail("Failed to create valid placement manager")
		return null
	
	return placement_manager

## Create a robust placement context with validation
static func _create_robust_placement_context(test: GdUnitTestSuite) -> PlacementContext:
	var context = PlacementContext.new()
	test.auto_free(context)
	
	# Validate context creation
	if not context:
		test.fail("Failed to create valid placement context")
		return null
	
	return context

# ================================
# Setup Recovery Methods
# ================================

## Attempt to recover from setup failures
static func recover_from_setup_failure(setup: Dictionary, test: GdUnitTestSuite) -> bool:
	test.log("Attempting to recover from setup failure...")
	
	# Try to clean up partial setup
	for key in setup:
		var value = setup[key]
		if value is Node and is_instance_valid(value):
			if value.get_parent():
				value.get_parent().remove_child(value)
			value.queue_free()
	
	setup.clear()
	
	# Wait a frame for cleanup
	await test.get_tree().process_frame
	
	test.log("Setup recovery completed")
	return true

## Create a minimal working test environment
static func create_minimal_test_environment(test: GdUnitTestSuite) -> Dictionary:
	var setup = {}
	
	# Create only essential components
	setup.container = TEST_CONTAINER
	setup.placer = GodotTestFactory.create_node2d(test)
	setup.grid_positioner = GodotTestFactory.create_node2d(test)
	
	test.log("Minimal test environment created")
	return setup

# ================================
# Setup Verification Methods
# ================================

## Verify that a test environment is ready for testing
static func verify_test_environment(setup: Dictionary, test: GdUnitTestSuite) -> bool:
	if not setup or setup.is_empty():
		test.fail("Test setup is empty")
		return false
	
	# Check for null values
	for key in setup:
		if setup[key] == null:
			test.fail("Test setup contains null value for key: %s" % key)
			return false
	
	# Check for invalid nodes
	for key in setup:
		var value = setup[key]
		if value is Node and not is_instance_valid(value):
			test.fail("Test setup contains invalid node for key: %s" % key)
			return false
	
	test.log("Test environment verification passed")
	return true

## Run a comprehensive test environment health check
static func run_environment_health_check(setup: Dictionary, test: GdUnitTestSuite) -> bool:
	var health_issues = []
	
	# Check container health
	if setup.has("container"):
		var container = setup.container
		if not container or not container.get_states():
			health_issues.append("Container or states not available")
	
	# Check system health
	if setup.has("system"):
		var system = setup.system
		if not system or not is_instance_valid(system):
			health_issues.append("System not valid")
		elif system.has_method("validate_dependencies"):
			var issues = system.validate_dependencies()
			if issues.size() > 0:
				health_issues.append("System has dependency issues: %s" % issues)
	
	# Check scene graph health
	if setup.has("placer") and setup.has("grid_positioner"):
		var placer = setup.placer
		var positioner = setup.grid_positioner
		if not is_instance_valid(placer) or not is_instance_valid(positioner):
			health_issues.append("Scene nodes not valid")
	
	if health_issues.size() > 0:
		for issue in health_issues:
			test.log("Health Check Issue: %s" % issue)
		return false
	
	test.log("Environment health check passed")
	return true
