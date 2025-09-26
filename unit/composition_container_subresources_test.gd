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
	assert_that(cfg.settings.messages).append_failure_message("GBConfig.messages missing").is_not_null()

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
