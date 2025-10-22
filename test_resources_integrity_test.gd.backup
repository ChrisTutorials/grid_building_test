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

const TEST_ROOT: String = "res://test/"
const PLUGIN_ROOT: String = "res://addons/grid_building/"

# Allowed dependency prefixes for test resources
const ALLOWED_DEPENDENCIES := [
	"res://test/",
	"res://addons/grid_building/",
	"res://",  # Built-in Godot resources
]

# Disallowed dependency prefixes (external to test folder)
const DISALLOWED_DEPENDENCIES := [
	"res://templates/",
	"res://demos/",
]


func test_no_test_resources_depend_on_templates_or_demos() -> void:
	# Scan all test resources and scenes for external dependencies
	var test_files: Array[String] = _list_test_files(TEST_ROOT)

	assert_int(test_files.size()).append_failure_message(
		"No test files found under %s" % TEST_ROOT
	).is_greater(0)

	var violations: Array[Dictionary] = []

	for file_path in test_files:
		var resource: Resource = load(file_path)
		if resource == null:
			violations.append({
				"file": file_path,
				"issue": "Failed to load resource"
			})
			continue

		# Get all dependencies for this resource
		var dependencies: PackedStringArray = ResourceLoader.get_dependencies(file_path)

		for dep_path in dependencies:
			# Check if dependency is in disallowed location
			for disallowed in DISALLOWED_DEPENDENCIES:
				if dep_path.begins_with(disallowed):
					violations.append({
						"file": file_path,
						"dependency": dep_path,
						"issue": "Test resource depends on external folder: %s" % disallowed
					})

	# Report all violations
	if violations.size() > 0:
		var error_msg := "Test resources have external dependencies:\n"
		for violation in violations:
			error_msg += "  File: %s\n" % violation.file
			if violation.has("dependency"):
				error_msg += "    → Depends on: %s\n" % violation.dependency
			error_msg += "    Issue: %s\n" % violation.issue

		assert_bool(false).append_failure_message(error_msg).is_true()

	# Pass if no violations
	assert_int(violations.size()).append_failure_message(
		"Resource integrity check should pass with no violations - Found %d violations" % \
		violations.size()
	).is_equal(0)


func test_all_test_scenes_instantiate_without_errors() -> void:
	var scene_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tscn")

	assert_int(scene_files.size()).append_failure_message(
		"No .tscn files found under %s" % TEST_ROOT
	).is_greater(0)

	var failures: Array[Dictionary] = []

	for scene_path in scene_files:
		var packed_scene: PackedScene = load(scene_path)
		if packed_scene == null:
			failures.append({
				"scene": scene_path,
				"error": "Failed to load PackedScene"
			})
			continue

		# Try to instantiate
		var instance: Node = packed_scene.instantiate()
		if instance == null:
			failures.append({
				"scene": scene_path,
				"error": "Failed to instantiate scene"
			})
			continue

		# Cleanup
		instance.free()

	# Report failures
	if failures.size() > 0:
		var error_msg := "Failed to instantiate test scenes:\n"
		for failure in failures:
			error_msg += "  Scene: %s\n" % failure.scene
			error_msg += "    Error: %s\n" % failure.error

		assert_bool(false).append_failure_message(error_msg).is_true()

	assert_int(failures.size()).append_failure_message(
		"All test scenes should instantiate without errors - Found %d failures" % failures.size()
	).is_equal(0)


func test_all_test_resources_load_successfully() -> void:
	var resource_files: Array[String] = _list_files_by_extension(TEST_ROOT, ".tres")

	assert_int(resource_files.size()).append_failure_message(
		"No .tres files found under %s" % TEST_ROOT
	).is_greater(0)

	var failures: Array[Dictionary] = []

	for res_path in resource_files:
		var resource: Resource = load(res_path)
		if resource == null:
			failures.append({
				"resource": res_path,
				"error": "Failed to load resource"
			})

	# Report failures
	if failures.size() > 0:
		var error_msg := "Failed to load test resources:\n"
		for failure in failures:
			error_msg += "  Resource: %s\n" % failure.resource
			error_msg += "    Error: %s\n" % failure.error

		assert_bool(false).append_failure_message(error_msg).is_true()

	assert_int(failures.size()).append_failure_message(
		"All test resources should load successfully - Found %d failures" % failures.size()
	).is_equal(0)


func test_test_folder_is_portable() -> void:
	# Verify test folder only needs plugin to function
	var all_files: Array[String] = _list_test_files(TEST_ROOT)

	var external_deps: Dictionary = {}  # Path -> Array[String] of external deps

	for file_path in all_files:
		var dependencies: PackedStringArray = ResourceLoader.get_dependencies(file_path)
		var external: Array[String] = []

		for dep_path in dependencies:
			# Check if dependency is outside test/ and addons/grid_building/
			var is_internal := false
			for allowed in ["res://test/", "res://addons/grid_building/"]:
				if dep_path.begins_with(allowed):
					is_internal = true
					break

			# Skip built-in Godot resources (they're always available)
			if dep_path.begins_with("res://") and not is_internal:
				# Check if it's a disallowed external dependency
				for disallowed in DISALLOWED_DEPENDENCIES:
					if dep_path.begins_with(disallowed):
						external.append(dep_path)
						break

		if external.size() > 0:
			external_deps[file_path] = external

	# Report external dependencies
	if external_deps.size() > 0:
		var error_msg := "Test folder is NOT portable - found external dependencies:\n"
		for file_path in external_deps.keys():
			error_msg += "  File: %s\n" % file_path
			for dep in external_deps[file_path]:
				error_msg += "    → %s\n" % dep

		error_msg += "\nTest folder should only depend on:\n"
		error_msg += "  - res://test/ (self-contained)\n"
		error_msg += "  - res://addons/grid_building/ (the plugin)\n"

		assert_bool(false).append_failure_message(error_msg).is_true()

	assert_int(external_deps.size()).append_failure_message(
		"Test folder should be portable with no external dependencies - Found %d external deps" % \
		external_deps.size()
	).is_equal(0)


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
func _scan_directory_recursive(dir_path: String, extension: String, out_files: Array[String]) -> void:
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
