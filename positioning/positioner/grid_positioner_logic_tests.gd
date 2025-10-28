extends GdUnitTestSuite


func test_should_be_visible_respects_hide_on_handled() -> void:
	# Setup: hide_on_handled = true, input handled (not allowed)
	var targeting_settings := GridTargetingSettings.new()
	targeting_settings.hide_on_handled = true

	var mouse_status := GBMouseInputStatus.new()
	mouse_status.allowed = false

	# Act: check visibility when input is handled
	var result := GridPositionerLogic.should_be_visible(
		GBEnums.Mode.MOVE, targeting_settings, mouse_status, false  # has_mouse_world
	)

	# Assert: should be hidden when input is handled and hide_on_handled is true
	assert_bool(result).is_false().append_failure_message(
		"Expected positioner to be hidden when hide_on_handled=true and input is handled"
	)


func test_should_be_visible_when_hide_on_handled_disabled() -> void:
	# Setup: hide_on_handled = false, input handled (not allowed)
	var targeting_settings := GridTargetingSettings.new()
	targeting_settings.hide_on_handled = false

	var mouse_status := GBMouseInputStatus.new()
	mouse_status.allowed = false

	# Act: check visibility when hide_on_handled is disabled
	var result := GridPositionerLogic.should_be_visible(
		GBEnums.Mode.MOVE, targeting_settings, mouse_status, false  # has_mouse_world
	)

	# Assert: should be visible when hide_on_handled is disabled
	assert_bool(result).is_true().append_failure_message(
		"Expected positioner to be visible when hide_on_handled=false"
	)


func test_should_be_visible_respects_remain_active_in_off_mode() -> void:
	# Setup: OFF mode with remain_active_in_off_mode = true
	var targeting_settings := GridTargetingSettings.new()
	targeting_settings.remain_active_in_off_mode = true

	var mouse_status := GBMouseInputStatus.new()
	mouse_status.allowed = false

	# Act: check visibility in OFF mode when remain_active_in_off_mode is true
	var result := GridPositionerLogic.should_be_visible(
		GBEnums.Mode.OFF, targeting_settings, mouse_status, false  # has_mouse_world
	)

	# Assert: should be visible in OFF mode when remain_active_in_off_mode is true
	assert_bool(result).is_true().append_failure_message(
		"Expected positioner to be visible in OFF mode when remain_active_in_off_mode=true"
	)


func test_should_be_visible_hides_in_off_mode_when_remain_active_false() -> void:
	# Setup: OFF mode with remain_active_in_off_mode = false
	var targeting_settings := GridTargetingSettings.new()
	targeting_settings.remain_active_in_off_mode = false

	var mouse_status := GBMouseInputStatus.new()
	mouse_status.allowed = false

	# Act: check visibility in OFF mode when remain_active_in_off_mode is false
	var result := GridPositionerLogic.should_be_visible(
		GBEnums.Mode.OFF, targeting_settings, mouse_status, false  # has_mouse_world
	)

	# Assert: should be hidden in OFF mode when remain_active_in_off_mode is false
	assert_bool(result).is_false().append_failure_message(
		"Expected positioner to be hidden in OFF mode when remain_active_in_off_mode=false"
	)


func test_visibility_reconcile_hides_when_hide_on_handled_true() -> void:
	# Setup: hide_on_handled = true, input handled, currently visible
	var targeting_settings := GridTargetingSettings.new()
	targeting_settings.hide_on_handled = true

	var mouse_status := GBMouseInputStatus.new()
	mouse_status.allowed = false

	# Act: reconcile visibility when input becomes handled
	var result := GridPositionerLogic.visibility_reconcile(
		GBEnums.Mode.MOVE, targeting_settings, true, mouse_status, false  # current_visible  # has_mouse_world
	)

	# Assert: should apply change to hide when input is handled
	assert_bool(result.apply).is_true().append_failure_message(
		"Expected visibility_reconcile to apply change when hide_on_handled triggers"
	)
	(
		assert_bool(result.visible)
		. is_false()
		. append_failure_message(
			"Expected visibility_reconcile to set visible=false when hide_on_handled=true and input handled"
		)
	)
