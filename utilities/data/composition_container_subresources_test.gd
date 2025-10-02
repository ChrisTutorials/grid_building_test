extends GdUnitTestSuite

## Tests that validate individual GBConfig subresources referenced by the
## shared test composition container. Each test targets one subresource so
## failures isolate which ext_resource is missing or broken.

func _get_test_container() -> GBCompositionContainer:
	# Prefer the preloaded UID constant if available (preloaded test container)
	if typeof(GBTestConstants) != TYPE_NIL and "TEST_COMPOSITION_CONTAINER" in GBTestConstants:
		var base := GBTestConstants.TEST_COMPOSITION_CONTAINER
		if base and base is GBCompositionContainer:
			return base

	# Fallback: load by known test path
	var path := "res://test/grid_building_test/resources/composition_containers/test_composition_container.tres"
	var res := ResourceLoader.load(path)
	if res and res is GBCompositionContainer:
		return res

	return null

func test_settings_subresource() -> void:
	var container := _get_test_container()
	assert_that(container).append_failure_message("Test composition container not available via UID or path").is_not_null()
	if container == null:
		return
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig null on container").is_not_null()
	if cfg == null:
		return
	assert_that(cfg.settings).append_failure_message("GBConfig.settings missing").is_not_null()

func test_templates_subresource() -> void:
	var container := _get_test_container()
	assert_that(container).append_failure_message("Test composition container not available via UID or path").is_not_null()
	if container == null:
		return
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig null on container").is_not_null()
	if cfg == null:
		return
	assert_that(cfg.templates).append_failure_message("GBConfig.templates missing").is_not_null()

func test_actions_subresource() -> void:
	var container := _get_test_container()
	assert_that(container).append_failure_message("Test composition container not available via UID or path").is_not_null()
	if container == null:
		return
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig null on container").is_not_null()
	if cfg == null:
		return
	assert_that(cfg.actions).append_failure_message("GBConfig.actions missing").is_not_null()

func test_messages_subresource() -> void:
	var container := _get_test_container()
	assert_that(container).append_failure_message("Test composition container not available via UID or path").is_not_null()
	if container == null:
		return
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig null on container").is_not_null()
	if cfg == null:
		return
	# Messages were relocated from a dedicated messages subresource to the ManipulationSettings
	# (see manipulation_settings.gd). We now validate a representative subset of message string
	# properties exist and are non-empty on cfg.settings.manipulation.
	assert_that(cfg.settings).append_failure_message("GBConfig.settings missing").is_not_null()
	if cfg.settings == null:
		return
	assert_that(cfg.settings.manipulation).append_failure_message("GBSettings.manipulation missing (expected container for message strings)").is_not_null()
	if cfg.settings.manipulation == null:
		return
	var ms := cfg.settings.manipulation
	var message_props := [
		"demolish_success",
		"failed_not_demolishable",
		"move_started",
		"move_success",
		"invalid_data"
	]
	for p: String in message_props:
		var value: Variant = ms.get(p)
		assert_that(value).append_failure_message("ManipulationSettings message %s missing" % p).is_not_null()
		if typeof(value) == TYPE_STRING:
			assert_that((value as String).is_empty()).append_failure_message("ManipulationSettings message %s is empty" % p).is_false()

func test_visual_subresource() -> void:
	var container := _get_test_container()
	assert_that(container).append_failure_message("Test composition container not available via UID or path").is_not_null()
	if container == null:
		return
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig null on container").is_not_null()
	if cfg == null:
		return
	assert_that(cfg.settings.visual).append_failure_message("GBConfig.visual missing").is_not_null()

func test_runtime_checks_subresource() -> void:
	var container := _get_test_container()
	assert_that(container).append_failure_message("Test composition container not available via UID or path").is_not_null()
	if container == null:
		return
	var cfg: GBConfig = container.config
	assert_that(cfg).append_failure_message("GBConfig null on container").is_not_null()
	if cfg == null:
		return
	assert_that(cfg.settings.runtime_checks).append_failure_message("GBConfig.runtime_checks missing").is_not_null()
