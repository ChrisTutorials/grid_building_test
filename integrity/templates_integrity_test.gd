# Validates that all templates load and their references are valid for distribution.
# - Loads every .tscn and .tres in res://templates/
# - Verifies ext_resource references exist
# - Allows Script references to point to res://addons/grid_building/
# - Requires referenced .tscn/.tres to also be located under res://templates/
# - Uses editor-level validation (not runtime) to avoid false positives from missing game context
# Purpose: ensure the templates folder can be packaged and work on other machines.
@tool
extends GdUnitTestSuite

const TEMPLATES_ROOT: String = "res://templates/"
const ALLOWED_SCRIPT_PREFIXES: Array[String] = [
	"res://addons/grid_building/"
]
const ALLOWED_RESOURCE_PREFIXES: Array[String] = [
	"res://addons/grid_building/",
	"res://templates/grid_building_templates/"
]

# region Helpers
static func _list_template_files(root: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return files
	dir.list_dir_begin()
	while true:
		var f: String = dir.get_next()
		if f == "":
			break
		if f.begins_with("."):
			continue
		var p := root + f
		if dir.current_is_dir():
			files.append_array(_list_template_files(p + "/"))
		else:
			if f.ends_with(".tscn") or f.ends_with(".tres"):
				files.append(p)
	dir.list_dir_end()
	return files

static func _get_attr(line: String, key: String) -> String:
	var token := key + "=\""
	var start := line.find(token)
	if start == -1:
		return ""
	start += token.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)

static func _parse_ext_resources(file_path: String) -> Array[Dictionary]:
	var refs: Array[Dictionary] = []
	var content := FileAccess.get_file_as_string(file_path)
	if content == "":
		return refs
	var lines := content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("[ext_resource"):
			var res_type := _get_attr(line, "type")
			var res_path := _get_attr(line, "path")
			if res_path != "":
				refs.append({"type": res_type, "path": res_path})
	return refs
# endregion

func test_templates_load_and_references() -> void:
	# Discover templates
	var all_templates: Array[String] = _list_template_files(TEMPLATES_ROOT)
	assert_int(all_templates.size()) \
		.append_failure_message("No templates found under %s" % TEMPLATES_ROOT).is_greater(0)

	for tpl_path in all_templates:
		# 1) The template itself must exist and load
		assert_bool(ResourceLoader.exists(tpl_path)) \
			.append_failure_message("Template missing or not imported: %s" % tpl_path).is_true()

		var res := load(tpl_path)
		assert_object(res) \
			.append_failure_message("Failed to load template (load returned null): %s" %\
				tpl_path).is_not_null()

		# 2) Validate external references
		var refs: Array[Dictionary] = _parse_ext_resources(tpl_path)
		for r in refs:
			var r_type: String = str(r.get("type", ""))
			var r_path: String = str(r.get("path", ""))
			# All referenced resources should exist
			assert_bool(ResourceLoader.exists(r_path)) \
				.append_failure_message("Missing ext_resource in %s -> type=%s path=%s" %\
					[tpl_path, r_type, r_path]).is_true()

			# Scripts may point to plugin folder; no templates-root restriction
			if r_type == "Script":
				var is_allowed := false
				for prefix in ALLOWED_SCRIPT_PREFIXES:
					if r_path.begins_with(prefix):
						is_allowed = true
						break
				# If not in allowed prefixes, also fine if kept inside templates (e.g., demo wrappers)
				if not is_allowed:
					is_allowed = r_path.begins_with(TEMPLATES_ROOT)
				assert_bool(is_allowed).append_failure_message(
					"Script reference should be inside templates or allowed plugin path. File=%s\nScript=%s" %
					[tpl_path, r_path]).is_true()
			else:
				# For ALL other resources (scenes, textures, audio, etc.), they must be in allowed locations
				# This prevents templates from referencing demo-specific art/assets
				var is_allowed := false
				for prefix in ALLOWED_RESOURCE_PREFIXES:
					if r_path.begins_with(prefix):
						is_allowed = true
						break
				assert_bool(is_allowed).append_failure_message(
					"Resource reference must be inside addon or templates folder (not demos)\n" +
					"File=%s\nType=%s\nPath=%s\nAllowed prefixes: %s" %
					[tpl_path, r_type, r_path, str(ALLOWED_RESOURCE_PREFIXES)]
				).is_true()

static func _find_config_files(root: String) -> Array[String]:
	"""Recursively finds all config.tres files in the templates directory."""
	var configs: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return configs
	dir.list_dir_begin()
	while true:
		var f: String = dir.get_next()
		if f == "":
			break
		if f.begins_with("."):
			continue
		var p := root + f
		if dir.current_is_dir():
			configs.append_array(_find_config_files(p + "/"))
		else:
			# Match config.tres or any file ending with _config.tres (like td_config.tres)
			if f == "config.tres" or f.ends_with("_config.tres"):
				configs.append(p)
	dir.list_dir_end()
	return configs

func test_template_configs_use_warning_log_level() -> void:
	# Dynamically find all config files in templates folder
	var config_files: Array[String] = _find_config_files(TEMPLATES_ROOT)

	assert_int(config_files.size()).append_failure_message(
		"No config files found under %s" % TEMPLATES_ROOT
	).is_greater(0)

	for config_path in config_files:
		assert_bool(ResourceLoader.exists(config_path)).append_failure_message(
			"Config file not found: %s" % config_path
		).is_true()

		var config := load(config_path) as GBConfig
		assert_object(config).append_failure_message(
			"Failed to load config or not a GBConfig: %s" % config_path
		).is_not_null()

		if config == null:
			continue

		# Access debug settings through config.settings
		assert_object(config.settings).append_failure_message(
			"Config has no settings object: %s" % config_path
		).is_not_null()

		if config.settings == null:
			continue

		var debug_settings := config.settings.debug as GBDebugSettings
		assert_object(debug_settings).append_failure_message(
			"Config has no debug settings: %s" % config_path
		).is_not_null()

		if debug_settings == null:
			continue

		# LogLevel.WARNING = 2
		assert_int(debug_settings.level).append_failure_message(
			"Config %s has debug level=%d, expected WARNING (2)" % [config_path, debug_settings.level]
		).is_equal(2)

func test_template_configs_have_keyboard_input_disabled() -> void:
	"""Validates that template configs ship with keyboard input disabled by default.

	Keyboard input requires users to configure positioner actions in their InputMap.
	Templates should not enable this by default to avoid runtime errors when
	those actions are not defined. Users can opt-in by enabling it in their config.
	"""
	var config_files: Array[String] = _find_config_files(TEMPLATES_ROOT)

	assert_int(config_files.size()).append_failure_message(
		"No config files found under %s" % TEMPLATES_ROOT
	).is_greater(0)

	for config_path in config_files:
		assert_bool(ResourceLoader.exists(config_path)).append_failure_message(
			"Config file not found: %s" % config_path
		).is_true()

		var config := load(config_path) as GBConfig
		assert_object(config).append_failure_message(
			"Failed to load config or not a GBConfig: %s" % config_path
		).is_not_null()

		if config == null:
			continue

		# Access targeting settings through config.settings
		assert_object(config.settings).append_failure_message(
			"Config has no settings object: %s" % config_path
		).is_not_null()

		if config.settings == null:
			continue

		var targeting_settings := config.settings.targeting as GridTargetingSettings
		assert_object(targeting_settings).append_failure_message(
			"Config has no targeting settings: %s" % config_path
		).is_not_null()

		if targeting_settings == null:
			continue

		# Keyboard input should be disabled by default in templates
		var error_msg := (
			"Config %s has enable_keyboard_input=true. Templates should ship with keyboard input " +
			"DISABLED by default.\nKeyboard input requires positioner actions (positioner_up, " +
			"positioner_down, etc.) to be defined in the user's InputMap.\nUsers should explicitly " +
			"enable this setting after configuring their input actions."
		) % config_path

		assert_bool(targeting_settings.enable_keyboard_input).append_failure_message(error_msg).is_false()

func test_template_scenes_instantiate_without_errors() -> void:
	"""Validates that all template .tscn files can be instantiated without errors.

	This simulates copying templates to a new project - each scene should:
	- Instantiate successfully (no missing dependencies, no parse errors)
	- Have no missing node references that prevent instantiation
	- Not crash during _ready()
	- Pass editor-level validation checks

	Note: We temporarily set debug level to NONE to suppress automatic runtime
	validation errors (which are expected for templates tested in isolation).
	We then programmatically check editor-level validation instead.
	"""
	var all_files: Array[String] = _list_template_files(TEMPLATES_ROOT)
	var scene_files: Array[String] = []
	for path in all_files:
		if path.ends_with(".tscn"):
			scene_files.append(path)

	assert_int(scene_files.size()).append_failure_message(
		"No .tscn files found under %s" % TEMPLATES_ROOT
	).is_greater(0)

	var successfully_instantiated := 0
	var failed_scenes: Array[String] = []

	for scene_path in scene_files:
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			failed_scenes.append(scene_path + " (failed to load as PackedScene)")
			continue

		# Instantiate the scene - this is the key test
		var instance: Node = packed_scene.instantiate()
		if instance == null:
			failed_scenes.append(scene_path + " (failed to instantiate)")
			continue

		# For system scenes, suppress automatic validation by setting debug level to NONE
		var injector := instance.get_node_or_null("GBInjectorSystem")
		var original_log_level: int = -1
		if injector != null and injector.composition_container != null:
			var debug_settings: GBDebugSettings = injector.composition_container.get_debug_settings()
			if debug_settings != null:
				original_log_level = debug_settings.level
				debug_settings.level = GBDebugSettings.LogLevel.NONE

		# Add to tree to trigger _ready() - this validates no crash during init
		add_child(instance)
		await get_tree().process_frame

		# Restore original log level
		if original_log_level >= 0 and injector != null and injector.composition_container != null:
			var debug_settings: GBDebugSettings = injector.composition_container.get_debug_settings()
			if debug_settings != null:
				debug_settings.level = original_log_level as GBDebugSettings.LogLevel

		# Verify scene is in tree (proves it loaded and initialized)
		if not instance.is_inside_tree():
			failed_scenes.append(scene_path + " (not in tree after add_child)")
		else:
			successfully_instantiated += 1

			# For system scenes, check editor-level validation (not runtime)
			if injector != null and injector.composition_container != null:
				var editor_issues: Array[String] = injector.composition_container.get_editor_issues()
				if editor_issues.size() > 0:
					failed_scenes.append(scene_path + " has editor validation issues: " + str(editor_issues))

		# Clean up
		instance.queue_free()

	# Assert that all scenes instantiated successfully
	assert_array(failed_scenes).append_failure_message(
		"Some template scenes failed to instantiate properly:\n" + "\n".join(failed_scenes)
	).is_empty()

	assert_int(successfully_instantiated).append_failure_message(
		"Expected all %d scenes to instantiate, but only %d succeeded" %\
			[scene_files.size(), successfully_instantiated]
	).is_equal(scene_files.size())

func test_template_resources_load_without_errors() -> void:
	"""Validates that all template .tres files can be loaded without errors.

	This ensures resource files are properly formatted and don't have
	circular dependencies or missing script references.
	"""
	var all_files: Array[String] = _list_template_files(TEMPLATES_ROOT)
	var resource_files: Array[String] = []
	for path in all_files:
		if path.ends_with(".tres"):
			resource_files.append(path)

	assert_int(resource_files.size()).append_failure_message(
		"No .tres files found under %s" % TEMPLATES_ROOT
	).is_greater(0)

	for res_path in resource_files:
		var resource: Resource = load(res_path)
		assert_object(resource).append_failure_message(
			"Failed to load resource: %s" % res_path
		).is_not_null()

		if resource == null:
			continue

		# Verify the resource has a valid script if it's a custom resource
		var script: Script = resource.get_script()
		if script != null:
			# Verify script can be accessed and has a valid resource_path
			assert_str(script.resource_path).append_failure_message(
				"Resource script has no resource_path: %s" % res_path
			).is_not_empty()

func test_template_configs_have_valid_structure() -> void:
	"""Validates that config files have complete, properly structured settings.

	Each config should have all required sub-resources (settings, templates, actions)
	and no null/missing critical components.
	"""
	var config_files: Array[String] = _find_config_files(TEMPLATES_ROOT)

	assert_int(config_files.size()).append_failure_message(
		"No config files found under %s" % TEMPLATES_ROOT
	).is_greater(0)

	for config_path in config_files:
		var config := load(config_path) as GBConfig

		if config == null:
			continue

		# Validate settings structure
		assert_object(config.settings).append_failure_message(
			"Config missing settings object: %s" % config_path
		).is_not_null()

		if config.settings != null:
			# Check core settings exist
			assert_object(config.settings.building).append_failure_message(
				"Config missing building settings: %s" % config_path
			).is_not_null()

			assert_object(config.settings.manipulation).append_failure_message(
				"Config missing manipulation settings: %s" % config_path
			).is_not_null()

			assert_object(config.settings.targeting).append_failure_message(
				"Config missing targeting settings: %s" % config_path
			).is_not_null()

			assert_object(config.settings.visual).append_failure_message(
				"Config missing visual settings: %s" % config_path
			).is_not_null()

			assert_object(config.settings.debug).append_failure_message(
				"Config missing debug settings: %s" % config_path
			).is_not_null()

		# Validate templates structure
		assert_object(config.templates).append_failure_message(
			"Config missing templates object: %s" % config_path
		).is_not_null()

		# Validate actions structure
		assert_object(config.actions).append_failure_message(
			"Config missing actions object: %s" % config_path
		).is_not_null()

func test_template_indicator_scenes_have_required_nodes() -> void:
	"""Validates that indicator template scenes have the required node structure.

	Each indicator scene should have:
	- Root node (typically Node2D or CanvasItem)
	- No missing node references

	Note: Not all indicator scenes may have scripts (e.g., simple shape templates)
	"""
	var all_files: Array[String] = _list_template_files(TEMPLATES_ROOT)
	var indicator_scenes: Array[String] = []
	for path in all_files:
		if path.ends_with(".tscn") and "indicator" in path.to_lower():
			indicator_scenes.append(path)

	if indicator_scenes.is_empty():
		# Not all templates may have indicator scenes, skip if none found
		return

	for scene_path in indicator_scenes:
		var packed_scene := load(scene_path) as PackedScene

		if packed_scene == null:
			continue

		var instance: Node = packed_scene.instantiate()

		if instance == null:
			continue

		# Verify root node exists and is a CanvasItem (Node2D, Sprite2D, etc.)
		# Some indicator templates may just be shapes without scripts, which is valid
		assert_bool(instance is CanvasItem or instance is Node2D).append_failure_message(
			"Indicator scene root should be a CanvasItem or Node2D: %s" % scene_path
		).is_true()

		# Clean up
		instance.queue_free()

func test_systems_and_grid_positioner_stack_work_together() -> void:
	"""Validates that systems templates work correctly when combined with grid_positioner_stack.

	The systems templates (gb_systems.tscn, gb_systems_isometric.tscn) are designed to be used
	together with grid_positioner_stack templates. This test validates they can be
	instantiated together and checks for structural integrity using editor-level validation.

	Note: We temporarily set debug level to NONE to suppress automatic runtime
	validation errors (which are expected for templates tested in isolation).
	"""
	var test_combinations : Array[Dictionary] = [
		{
			"systems": GBTestConstants.SYSTEMS_TEMPLATE,
			"grid_stack": GBTestConstants.GRID_STACK_TEMPLATE,
			"name": "Top-down/Platformer configuration"
		},
		{
			"systems": GBTestConstants.SYSTEMS_ISOMETRIC_TEMPLATE,
			"grid_stack": GBTestConstants.GRID_STACK_ISOMETRIC_TEMPLATE,
			"name": "Isometric configuration"
		}
	]

	var failed_combinations: Array[String] = []

	for combo in test_combinations:
		# Create a test scene root
		var test_root := Node2D.new()
		add_child(test_root)
		auto_free(test_root)

		# Load and instantiate the systems template
		var systems_scene := combo["systems"] as PackedScene
		if systems_scene == null:
			failed_combinations.append(combo["name"] + ": Failed to load systems scene")
			test_root.queue_free()
			continue

		var systems_instance := systems_scene.instantiate()
		if systems_instance == null:
			failed_combinations.append(combo["name"] + ": Failed to instantiate systems scene")
			test_root.queue_free()
			continue

		# Suppress automatic validation by setting debug level to NONE
		var injector := systems_instance.get_node_or_null("GBInjectorSystem")
		var original_log_level: int = -1
		if injector != null and injector.composition_container != null:
			var debug_settings: GBDebugSettings = injector.composition_container.get_debug_settings()
			if debug_settings != null:
				original_log_level = debug_settings.level
				debug_settings.level = GBDebugSettings.LogLevel.NONE

		# Load and instantiate the grid positioner stack
		var grid_stack_scene := combo["grid_stack"] as PackedScene
		if grid_stack_scene == null:
			failed_combinations.append(combo["name"] + ": Failed to load grid_positioner_stack scene")
			systems_instance.free()
			test_root.free()
			continue

		var grid_stack_instance := grid_stack_scene.instantiate()
		if grid_stack_instance == null:
			failed_combinations.append(combo["name"] + ": Failed to instantiate grid_positioner_stack scene")
			systems_instance.queue_free()
			test_root.queue_free()
			continue

		# Add both to the test root
		test_root.add_child(systems_instance)
		test_root.add_child(grid_stack_instance)

		# Wait for ready to process
		await get_tree().process_frame

		# Restore original log level
		if original_log_level >= 0 and injector != null and injector.composition_container != null:
			var debug_settings: GBDebugSettings = injector.composition_container.get_debug_settings()
			if debug_settings != null:
				debug_settings.level = original_log_level as GBDebugSettings.LogLevel

		# Verify both are in tree
		if not systems_instance.is_inside_tree():
			failed_combinations.append(combo["name"] + ": Systems instance not in tree")

		if not grid_stack_instance.is_inside_tree():
			failed_combinations.append(combo["name"] + ": Grid stack instance not in tree")

		# Verify ManipulationParent exists in the grid stack
		var manipulation_parent := grid_stack_instance.get_node_or_null("ManipulationParent")
		if manipulation_parent == null:
			failed_combinations.append(combo["name"] +
				": ManipulationParent not found in grid_positioner_stack")
		else:
			# Verify IndicatorManager exists under ManipulationParent
			var indicator_manager := manipulation_parent.get_node_or_null("IndicatorManager")
			if indicator_manager == null:
				failed_combinations.append(combo["name"] +
					": IndicatorManager not found under ManipulationParent")

		# Verify ManipulationSystem exists in systems
		var manipulation_system := systems_instance.get_node_or_null("ManipulationSystem")
		if manipulation_system == null:
			failed_combinations.append(combo["name"] + ": ManipulationSystem not found in systems template")

		# Check editor-level validation (not runtime) - templates should pass editor validation
		if injector != null and injector.composition_container != null:
			var editor_issues: Array[String] = injector.composition_container.get_editor_issues()
			if editor_issues.size() > 0:
				failed_combinations.append(combo["name"] + ": Editor validation issues: " + str(editor_issues))

		# Clean up
		test_root.queue_free()

	# Assert all combinations worked
	assert_array(failed_combinations).append_failure_message(
		"Some system + grid_positioner_stack combinations failed:\n" + "\n".join(failed_combinations)
	).is_empty()
