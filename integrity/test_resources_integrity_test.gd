## Test Resources Integrity Test
##
## Validates that all test resources and scenes are self-contained:
## - Test resources only depend on res://test/ and res://addons/grid_building/
## - No dependencies on res://templates/, res://demos/, or other external folders
## - All scenes can be instantiated without errors
## - All resources can be loaded successfully
##
## Purpose: Ensure test folder can be distributed with the plugin for validation
## without requiring templates or demo assets.

extends GdUnitTestSuite

const TEST_ROOT: String = GBTestConstants.TEST_PATH_TEST
const PLUGIN_ROOT: String = "res://addons/grid_building/"

# Allowed dependency prefixes for test resources
const ALLOWED_DEPENDENCIES: Array[String] = [
	GBTestConstants.TEST_PATH_TEST,
	"res://addons/grid_building/",
	"res://",  # Built-in Godot resources
]

# Disallowed dependency prefixes (external to test folder)
const DISALLOWED_DEPENDENCIES: Array[String] = [
	GBTestConstants.TEST_PATH_TEMPLATES,
	GBTestConstants.TEST_PATH_DEMOS,
]

const PORTABLE_ALLOWED_DEPENDENCIES: Array[String] = [
	GBTestConstants.TEST_PATH_TEST,
	"res://addons/grid_building/",
]


func test_no_test_resources_depend_on_templates_or_demos() -> void:
	var test_files: Array[String] = _list_test_files(TEST_ROOT)

	(
		assert_int(test_files.size()) \
		. append_failure_message("No test files found under %s" % TEST_ROOT) \
		. is_greater(0)
	)

	var violations: Array[Dictionary] = []

	for file_path: String in test_files:
		var resource: Resource = load(file_path)
		if resource == null:
			violations.append({"file": file_path, "issue": "Failed to load resource"})
			continue

		var dependencies: PackedStringArray = ResourceLoader.get_dependencies(file_path)
		for dep_path: String in dependencies:
			for disallowed: String in DISALLOWED_DEPENDENCIES:
				if dep_path.begins_with(disallowed):
					violations.append(
						{
							"file": file_path,
							"dependency": dep_path,
							"issue": "Test resource depends on external folder: %s" % disallowed
						}
					)

	var failure_msg := (
		"Resource integrity check should pass with no violations - Found %d violations"
		% violations.size()
	)
	if violations.size() > 0:
		failure_msg += "\nTest resources have external dependencies:\n"
		for violation: Dictionary in violations:
			failure_msg += "  File: %s\n" % violation.file
			if violation.has("dependency"):
				failure_msg += "    → Depends on: %s\n" % violation.dependency
			failure_msg += "    Issue: %s\n" % violation.issue

	assert_int(violations.size()).append_failure_message(failure_msg).is_equal(0)


func test_all_test_scenes_instantiate_without_errors() -> void:
	var scene_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tscn")

	(
		assert_int(scene_files.size()) \
		. append_failure_message("No .tscn files found under %s" % TEST_ROOT) \
		. is_greater(0)
	)

	var failures: Array[Dictionary] = []

	for scene_path: String in scene_files:
		var packed_scene: PackedScene = load(scene_path)
		if packed_scene == null:
			failures.append({"scene": scene_path, "error": "Failed to load PackedScene"})
			continue

		var instance: Node = packed_scene.instantiate()
		if instance == null:
			failures.append({"scene": scene_path, "error": "Failed to instantiate scene"})
			continue

		instance.free()

	var failure_msg := (
		"All test scenes should instantiate without errors - Found %d failures" % failures.size()
	)
	if failures.size() > 0:
		failure_msg += "\nFailed to instantiate test scenes:\n"
		for failure: Dictionary in failures:
			failure_msg += "  Scene: %s\n" % failure.scene
			failure_msg += "    Error: %s\n" % failure.error

	assert_int(failures.size()).append_failure_message(failure_msg).is_equal(0)


func test_all_test_resources_load_successfully() -> void:
	var resource_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tres")

	(
		assert_int(resource_files.size()) \
		. append_failure_message("No .tres files found under %s" % TEST_ROOT) \
		. is_greater(0)
	)

	var failures: Array[Dictionary] = []

	for res_path: String in resource_files:
		var resource: Resource = load(res_path)
		if resource == null:
			failures.append({"resource": res_path, "error": "Failed to load resource"})

	var failure_msg := (
		"All test resources should load successfully - Found %d failures" % failures.size()
	)
	if failures.size() > 0:
		failure_msg += "\nFailed to load test resources:\n"
		for failure: Dictionary in failures:
			failure_msg += "  Resource: %s\n" % failure.resource
			failure_msg += "    Error: %s\n" % failure.error

	assert_int(failures.size()).append_failure_message(failure_msg).is_equal(0)


func test_test_folder_is_portable() -> void:
	# Verify test folder only needs plugin to function
	var all_files: Array[String] = _list_test_files(TEST_ROOT)

	var external_deps: Dictionary[String, Array] = {}  # Path -> Array of external deps

	for file_path: String in all_files:
		var dependencies: PackedStringArray = ResourceLoader.get_dependencies(file_path)
		var external: Array[String] = []

		for dep_path: String in dependencies:
			var is_internal := false
			for allowed: String in PORTABLE_ALLOWED_DEPENDENCIES:
				if dep_path.begins_with(allowed):
					is_internal = true
					break

			if dep_path.begins_with("res://") and not is_internal:
				for disallowed: String in DISALLOWED_DEPENDENCIES:
					if dep_path.begins_with(disallowed):
						external.append(dep_path)
						break

		if external.size() > 0:
			external_deps[file_path] = external

	var failure_msg := (
		"Test folder should be portable with no external dependencies - Found %d external deps"
		% external_deps.size()
	)
	if external_deps.size() > 0:
		failure_msg += "\nTest folder is NOT portable - found external dependencies:\n"
		for file_path: String in external_deps.keys():
			failure_msg += "  File: %s\n" % file_path
			for dep: String in external_deps[file_path]:
				failure_msg += "    → %s\n" % dep

		failure_msg += "\nTest folder should only depend on:\n"
		failure_msg += "  - res://test/ (self-contained)\n"
		failure_msg += "  - res://addons/grid_building/ (the plugin)\n"

	assert_int(external_deps.size()).append_failure_message(failure_msg).is_equal(0)


## Helper: List all .tscn and .tres files under a root path
func _list_test_files(root_path: String) -> Array[String]:
	var files: Array[String] = []
	files.append_array(_list_files_by_extension(root_path, ".tscn"))
	files.append_array(_list_files_by_extension(root_path, ".tres"))
	return files


## Helper: List all files with specific extension under a root path
func _list_files_by_extension(root_path: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	_scan_directory_recursive(root_path, extension, files)
	return files


## Helper: Recursively scan directory for files with extension
func _scan_directory_recursive(
	dir_path: String, extension: String, out_files: Array[String]
) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := dir_path.path_join(file_name)

		if dir.current_is_dir():
			# Recurse into subdirectory
			_scan_directory_recursive(full_path, extension, out_files)
		elif file_name.ends_with(extension):
			# Add matching file
			out_files.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## PHASE C ENHANCEMENTS: Deeper resource validation


## Validates that scene files don't reference missing external resources
## Catches "stampede failures" where one missing resource breaks 100+ tests
func test_scene_external_references_resolve() -> void:
	var test_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tscn")
	var broken_refs: Dictionary = {}  # file_path -> Array[missing_dep]

	for file_path: String in test_files:
		var dependencies: PackedStringArray = ResourceLoader.get_dependencies(file_path)
		var missing: Array[String] = []

		for dep_path: String in dependencies:
			# Check if dependency exists
			if not ResourceLoader.exists(dep_path):
				missing.append(dep_path)

		if missing.size() > 0:
			broken_refs[file_path] = missing

	var failure_msg := (
		"Found %d scene(s) with broken external references"
		% broken_refs.size()
	)

	if broken_refs.size() > 0:
		failure_msg += "\n\nBroken references (missing resources):\n"
		for file_path: String in broken_refs.keys():
			failure_msg += "  Scene: %s\n" % file_path
			for missing_dep: String in broken_refs[file_path]:
				failure_msg += "    ❌ Missing: %s\n" % missing_dep

		failure_msg += "\nWhy this matters:"
		failure_msg += (
			"\n  • One missing resource can cause 100+ test failures (stampede)"
		)
		failure_msg += "\n  • Fix by restoring the resource or removing the reference"

	assert_int(broken_refs.size()).append_failure_message(failure_msg).is_equal(0)


## Validates that .tres resource files can be loaded successfully
## Catches corrupted or invalid resource files
func test_tres_resources_loadable() -> void:
	var tres_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tres")
	var failed_loads: Array[String] = []

	for file_path: String in tres_files:
		var resource: Resource = load(file_path)
		if resource == null:
			failed_loads.append(file_path)

	var failure_msg := (
		"Found %d .tres file(s) that failed to load" % failed_loads.size()
	)

	if failed_loads.size() > 0:
		failure_msg += "\n\nFailed to load:\n"
		for file_path: String in failed_loads:
			failure_msg += "  ❌ %s\n" % file_path

		failure_msg += "\nPossible causes:"
		failure_msg += "\n  • Corrupted resource file"
		failure_msg += "\n  • Missing script attachment"
		failure_msg += "\n  • Invalid property values"
		failure_msg += "\n  • Circular dependencies"

	(
		assert_int(failed_loads.size())
		. append_failure_message(failure_msg)
		. is_equal(0)
	)


## Validates that scene files can be instantiated without errors
## Catches script errors, missing scripts, or invalid node structures
func test_scene_files_instantiable() -> void:
	var tscn_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tscn")
	var failed_instantiation: Dictionary = {}  # file_path -> error_msg

	for file_path: String in tscn_files:
		var packed_scene: PackedScene = load(file_path)

		if packed_scene == null:
			failed_instantiation[file_path] = "Failed to load PackedScene"
			continue

		# Try to instantiate
		var instance: Node = packed_scene.instantiate()

		if instance == null:
			failed_instantiation[file_path] = "instantiate() returned null"
		else:
			# Success - clean up
			instance.queue_free()

	var failure_msg := (
		"Found %d scene(s) that failed to instantiate"
		% failed_instantiation.size()
	)

	if failed_instantiation.size() > 0:
		failure_msg += "\n\nFailed to instantiate:\n"
		for file_path: String in failed_instantiation.keys():
			failure_msg += "  ❌ %s\n" % file_path
			failure_msg += "     Reason: %s\n" % failed_instantiation[file_path]

		failure_msg += "\nPossible causes:"
		failure_msg += "\n  • Missing script file"
		failure_msg += "\n  • Script compilation errors"
		failure_msg += "\n  • Invalid node structure"
		failure_msg += "\n  • RefCounted script on Node (should extend Node)"

	(
		assert_int(failed_instantiation.size())
		. append_failure_message(failure_msg)
		. is_equal(0)
	)
