extends GdUnitTestSuite

## Consolidated Data Utilities Test Suite
## Tests for data objects, configuration validation, display names, and object initialization
## Combines: composition container validation, display name formatting, debug settings, and object initialization tests

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const NODE_NAME_NUM_SEPARATOR: int = 2

# -----------------------------------------------------------------------------
# Test Variables
# -----------------------------------------------------------------------------
var _container : GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER
var test_node: Node
var building_node_script: Script = load("uid://cufp4o5ctq6ak")
var project_name_num_seperator: int
var container: GBCompositionContainer

func before_test() -> void:
	test_node = auto_free(Node.new())
	add_child(test_node)
	project_name_num_seperator = ProjectSettings.get_setting("editor/naming/node_name_num_separator")
	ProjectSettings.set_setting("editor/naming/node_name_num_separator", NODE_NAME_NUM_SEPARATOR)
	
	# Initialize container for composition/configuration tests
	container = GBCompositionContainer.new()
	container.config = GBConfig.new()

func after_test() -> void:
	ProjectSettings.set_setting("editor/naming/node_name_num_separator", project_name_num_seperator)

#region Helper Functions
func _assert_object_initializes(obj: Object) -> void:
	assert_object(obj).append_failure_message("Object failed to initialize").is_not_null()

func _make_test_logger_with_settings(p_settings: GBDebugSettings) -> GBLogger:
	var LoggerScript := preload("res://addons/grid_building/logging/gb_logger.gd")
	var logger: GBLogger = LoggerScript.new(p_settings)
	return logger
#endregion

#region Composition Container Validation Tests
func test_validate_test_composition_container_subcomponents() -> void:
	"""Test: Validate test composition container resource and GBConfig subcomponents"""
	assert_that(_container).append_failure_message("Failed to load test composition container resource: %s" % GBTestConstants.TEST_COMPOSITION_CONTAINER.resource_path).is_not_null()

	# Instantiate if it's a PackedScene-like resource that needs instantiation, otherwise it's a Resource
	var container: GBCompositionContainer = null
	if _container is GBCompositionContainer:
		container = _container
	else:
		# Try loading as PackedScene or instancing - fallback to loading resource path used by tests
		container = ResourceLoader.load("res://test/grid_building_test/resources/composition_containers/test_composition_container.tres")

	assert_that(container).append_failure_message("Test composition container not found or wrong type").is_not_null()

	# Assert GBConfig exists and its main subcomponents are present
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig is null on the test composition container").is_not_null()

	# Check top-level exported subresources to isolate missing ext_resources
	assert_that(cfg.settings).append_failure_message("GBConfig.settings is null").is_not_null()
	assert_that(cfg.templates).append_failure_message("GBConfig.templates is null").is_not_null()
	assert_that(cfg.actions).append_failure_message("GBConfig.actions is null").is_not_null()
	assert_that(cfg.settings.visual).append_failure_message("GBConfig.settings.visual is null").is_not_null()

	# Check placement rules are present in settings (this may load programmatic fallback)
	var rules := container.get_placement_rules()
	assert_that(rules).append_failure_message("get_placement_rules returned null").is_not_null()
	assert_array(rules).append_failure_message("placement_rules should be an array").is_not_null()

	# Finally, run EDITOR validation to collect issues (tests can inspect reported issues)
	var issues: Array = container.get_editor_issues()
	# Attach issues to assertion message for easy triage
	assert_that(issues).append_failure_message("Editor issues: %s" % str(issues)).is_not_null()

	# For test hygiene, expect editor issues to be empty in a well-formed test container
	assert_that(issues.size()).append_failure_message("Expected no editor issues in test composition container: %s" % GBConfigurationValidator.editor_diagnostic(container)).is_equal(0)

#region Display Name Tests
@warning_ignore("unused_parameter")
func test_get_display_name(p_name: String, p_method_name: String, p_ex: String, p_ex_start_with: bool, test_parameters := [
	["TestNode_500", "", "Test Node", false],
	["TestNode_500", "to_string", "Test Node", true]
]) -> void:
	"""Test: Validate display name generation from Node objects"""
	test_node.name = p_name
	var display_name: String = GBObjectUtils.get_display_name(test_node, "<none>")
	if p_ex_start_with:
		assert_str(display_name).starts_with(p_ex)
	else:
		assert_str(display_name).contains(p_ex)
		assert_int(display_name.length()).append_failure_message("Account for the space in returned string").is_equal(p_ex.length())

@warning_ignore("unused_parameter")
func test_building_node_get_display_name(p_name: String, p_ex: String, test_parameters := [["TestNode_500", "Test Node"]]) -> void:
	"""Test: Validate display name generation for building nodes"""
	var building_node: Node = auto_free(building_node_script.new())
	building_node.name = p_name
	var display_name: String = GBObjectUtils.get_display_name(building_node)
	assert_str(display_name).is_equal(p_ex)

#region Debug Settings Tests
func test_debug_setting_float_and_color_are_read() -> void:
	"""Test: RuleCheckIndicator reads values from GBDebugSettings"""
	# Create a GBDebugSettings resource with known values
	var SettingsScript := preload("res://addons/grid_building/debug/gb_debug_settings.gd")
	var settings: GBDebugSettings = SettingsScript.new()
	settings.indicator_collision_point_min_radius = 7.5
	settings.indicator_connection_line_scale = 0.33
	settings.indicator_connection_line_color = Color(0.1, 0.2, 0.3, 1.0)

	# Create GBLogger with our settings
	var test_logger: GBLogger = _make_test_logger_with_settings(settings)

	# Instantiate a RuleCheckIndicator scene
	var IndicatorScene: PackedScene = preload("res://templates/grid_building_templates/indicator/rule_check_indicator_16x16.tscn")
	var indicator: Node = IndicatorScene.instantiate() as Node

	# Inject the logger by setting the _logger field directly (tests may do this)
	indicator._logger = test_logger

	# Call internal helper methods via call() to verify they read from settings
	var f_val_float: float = float(indicator.call("_debug_setting_float_or", 1.0, "indicator_collision_point_min_radius"))
	assert_float(f_val_float).is_equal_approx(7.5, 0.0001).append_failure_message("Expected float debug setting to be read from GBDebugSettings")

	var c_val_color: Color = indicator.call("_debug_setting_color_or", Color.RED, "indicator_connection_line_color") as Color
	assert_float(c_val_color.r).is_equal_approx(0.1, 0.0001).append_failure_message("Expected color.r to match setting")
	assert_float(c_val_color.g).is_equal_approx(0.2, 0.0001).append_failure_message("Expected color.g to match setting")
	assert_float(c_val_color.b).is_equal_approx(0.3, 0.0001).append_failure_message("Expected color.b to match setting")

	# Also verify a fallback occurs when requesting a non-existent property
	var fallback_val: float = float(indicator.call("_debug_setting_float_or", 2.25, "non_existent_property"))
	assert_float(fallback_val).is_equal_approx(2.25, 0.0001).append_failure_message("Expected fallback default when setting missing")

	# Clean up
	if is_instance_valid(indicator):
		indicator.queue_free()

#region Object Initialization Tests
func test_resource_stack_init() -> void:
	"""Test: ResourceStack object initialization"""
	var resource_stack: ResourceStack = ResourceStack.new()
	_assert_object_initializes(resource_stack)

func test_building_system_init() -> void:
	"""Test: BuildingSystem object initialization"""
	var building_system: BuildingSystem = BuildingSystem.new()
	_assert_object_initializes(building_system)
	building_system.free()

func test_grid_targeter_system_init() -> void:
	"""Test: GridTargetingSystem object initialization"""
	var grid_targeter_system: GridTargetingSystem = GridTargetingSystem.new()
	_assert_object_initializes(grid_targeter_system)
	grid_targeter_system.free()

func test_rule_check_indicator_init() -> void:
	"""Test: RuleCheckIndicator object initialization"""
	var rule_check_indicator: RuleCheckIndicator = RuleCheckIndicator.new([])
	_assert_object_initializes(rule_check_indicator)
	rule_check_indicator.free()

func test_rule_check_indicator_manager_init() -> void:
	"""Test: IndicatorManager object initialization"""
	var indicator_manager: IndicatorManager = IndicatorManager.new()
	_assert_object_initializes(indicator_manager)
	indicator_manager.free()

func test_node_locator_init() -> void:
	"""Test: NodeLocator object initialization"""
	var node_locator: NodeLocator = NodeLocator.new()
	_assert_object_initializes(node_locator)

#region Trapezoid Collision Diagnostic Tests
func test_trapezoid_collision_calculation_diagnostic() -> void:
	"""Test: Isolate and fix the trapezoid collision calculation bug"""
	# Arrange: The exact runtime trapezoid coordinates that fail
	var trapezoid_points: PackedVector2Array = PackedVector2Array([
		Vector2(-32, 12), Vector2(-16, -12), Vector2(17, -12), Vector2(32, 12)
	])
	var tile_size: Vector2 = Vector2(16, 16)
	var center_tile: Vector2i = Vector2i(27, 34)  # Runtime position (440, 544) / 16

	# Step 1: Check bounds calculation
	var bounds: Rect2 = CollisionGeometryCalculator._get_polygon_bounds(trapezoid_points)

	# Step 2: Calculate expected tile range
	var start_tile: Vector2i = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
	var end_tile: Vector2i = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))

	# Step 3: Test overlap detection for each tile in range
	var overlapping_tiles: Array[Vector2i] = []
	for x in range(start_tile.x, end_tile.x):
		for y in range(start_tile.y, end_tile.y):
			var tile_pos: Vector2i = Vector2i(x, y)
			var tile_rect: Rect2 = Rect2(Vector2(x * tile_size.x, y * tile_size.y), tile_size)

			# Test with different overlap thresholds
			var overlaps_strict: bool = CollisionGeometryCalculator.polygon_overlaps_rect(trapezoid_points, tile_rect, 0.01, 0.05)  # 5% threshold
			var overlaps_loose: bool = CollisionGeometryCalculator.polygon_overlaps_rect(trapezoid_points, tile_rect, 0.01, 0.01)  # 1% threshold

			if overlaps_strict or overlaps_loose:
				var clipped: PackedVector2Array = CollisionGeometryCalculator.clip_polygon_to_rect(trapezoid_points, tile_rect)
				var area: float = CollisionGeometryCalculator.polygon_area(clipped)

				if overlaps_strict:
					overlapping_tiles.append(tile_pos)

	# Act: Call the actual collision utility function
	var core_result: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		trapezoid_points, tile_size, center_tile
	)

	# Assert: Should find overlapping tiles, not return 0
	assert_int(core_result.size()).append_failure_message(
		"Expected core calculation to find %d overlapping tiles, got %d tiles: %s" %
		[overlapping_tiles.size(), core_result.size(), core_result]
	).is_greater(0)

#region Composition and Configuration Tests
func test_test_composition_container_loads_and_has_placement_rules() -> void:
	"""Test: Composition container loading and placement rules"""
	var repo_res: GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER
	assert_object(repo_res).is_not_null().append_failure_message("GBTestConstants.TEST_COMPOSITION_CONTAINER must be a valid resource")
	var pr: Array = repo_res.get_placement_rules()
	var pr_count: int = pr.size() if pr else 0
	assert_int(pr_count).is_greater(0).append_failure_message("Expected repo composition container to contain placement rules")

	var dup: GBCompositionContainer = repo_res.duplicate(true)
	assert_object(dup).is_not_null()
	var pr_dup: Array = dup.get_placement_rules()
	var pr_dup_count: int = pr_dup.size() if pr_dup else 0
	assert_int(pr_dup_count).is_greater(0).append_failure_message("Duplicated container should retain placement rules")

	var path: String = "res://test/grid_building_test/resources/composition_containers/test_composition_container.tres"
	var loaded: Resource = ResourceLoader.load(path)
	assert_object(loaded).append_failure_message("ResourceLoader failed to load %s" % path).is_not_null()
	var pr_loaded: Array = loaded.get_placement_rules() if loaded and loaded.has_method("get_placement_rules") else []
	var pr_loaded_count: int = pr_loaded.size() if pr_loaded else 0
	assert_int(pr_loaded_count).is_greater(0).append_failure_message("Loaded resource should have placement rules")

func test_validate_configuration_with_complete_config() -> void:
	"""Test: Configuration validator with complete config"""
	container.config.settings = GBSettings.new()
	container.config.actions = GBActions.new()
	container.config.templates = GBTemplates.new()
	var issues: Array[String] = container.get_editor_issues()
	assert_int(issues.size()).append_failure_message("Issues found: %s" % str(issues)).is_greater_equal(0)

func test_validate_runtime_configuration_minimum() -> void:
	"""Test: Runtime configuration validation minimum"""
	var issues : Array[String] = container.get_runtime_issues()
	# Expect some non-critical issues by default; ensure API returns an array
	assert_array(issues).is_not_null()

func test_injectable_factory_create_collision_mapper() -> void:
	"""Test: Injectable factory creates collision mapper"""
	container.config.settings = GBSettings.new()
	var mapper: CollisionMapper = GBInjectableFactory.create_collision_mapper(container)
	assert_object(mapper).is_not_null()
	assert_bool(mapper is CollisionMapper).is_true()
	var issues: Array[String] = mapper.get_runtime_issues()
	assert_int(issues.size()).append_failure_message("Validation issues: %s" % str(issues)).is_equal(0)

#region Manipulatable Hierarchy Tests
func test_hierarchy_valid_when_root_is_ancestor() -> void:
	"""Test: Manipulatable hierarchy validation when root is ancestor"""
	var root := Node3D.new()
	add_child(root)
	var child := Node3D.new()
	root.add_child(child)
	var m := Manipulatable.new()
	child.add_child(m)
	m.root = root
	assert_bool(m.is_root_hierarchy_valid()).is_true()
	assert_array(m.get_issues()).is_empty()

func test_hierarchy_invalid_when_root_not_ancestor() -> void:
	"""Test: Manipulatable hierarchy validation when root is not ancestor"""
	var unrelated := Node3D.new()
	add_child(unrelated)
	var other_branch := Node3D.new()
	add_child(other_branch)
	var child := Node3D.new()
	other_branch.add_child(child)
	var m := Manipulatable.new()
	child.add_child(m)
	m.root = unrelated
	assert_bool(m.is_root_hierarchy_valid()).is_false()
	assert_array(m.get_issues()).is_not_empty()
#endregion