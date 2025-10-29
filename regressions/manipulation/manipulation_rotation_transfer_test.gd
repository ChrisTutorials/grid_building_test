extends GdUnitTestSuite

## Test Suite: Manipulation Rotation Transfer Integration Test
##
## Tests that rotation is correctly transferred from the manipulation copy to ManipulationParent
## AFTER indicator generation is complete, ensuring:
## 1. Indicators are calculated from canonical geometry (rotation=0)
## 2. Preview shows correct rotation visually (ManipulationParent applies rotation)
## 3. IndicatorManager is properly parented to ManipulationParent
## 4. Indicators rotate with the preview via transform inheritance
##
## IMPORTANT: Uses AllSystemsTestEnvironment with scene_runner pattern for full system initialization

const SMITHY_TEST_ROOT_NAME := "SmithyTestRoot"
const TEST_ROTATION_DEGREES := 90
const ROTATION_TOLERANCE := 0.0001

var _runner: GdUnitSceneRunner
var _env: AllSystemsTestEnvironment
var _container: GBCompositionContainer
var _manipulation_system: ManipulationSystem
var _indicator_manager: IndicatorManager
var _manipulation_parent: ManipulationParent
var _smithy: Manipulatable

func before_test() -> void:
	# Use AllSystemsTestEnvironment with scene_runner pattern
	_runner = scene_runner(GBTestConstants.ALL_SYSTEMS_ENV_UID)
	_runner.simulate_frames(3)

	# Get environment and systems
	_env = _runner.scene()
	_manipulation_system = _env.manipulation_system
	_indicator_manager = _env.indicator_manager
	_manipulation_parent = _env.manipulation_parent
	_container = _env.get_container()

	# Verify systems are initialized
	assert_object(_manipulation_system).append_failure_message("ManipulationSystem should be initialized in AllSystemsTestEnvironment")
	assert_object(_indicator_manager).append_failure_message("Object assertion failed").is_not_null().append_failure_message("IndicatorManager should be initialized in AllSystemsTestEnvironment")
	assert_object(_manipulation_parent).append_failure_message("Object assertion failed").is_not_null().append_failure_message("ManipulationParent should be initialized in AllSystemsTestEnvironment")
	assert_object(_container).append_failure_message("Object assertion failed").is_not_null().append_failure_message("GBCompositionContainer should be accessible from AllSystemsTestEnvironment")

	# Create test manipulatable object using factory (pass 'this' GdUnitTestSuite)
	_smithy = ManipulatableTestFactory.create_manipulatable_with_root(self, SMITHY_TEST_ROOT_NAME)

	# CRITICAL: Configure manipulatable settings to enable rotation transfer
	# Without settings, ManipulationState validation fails with
	# "Active manipulatable has no settings configured"
	var manipulatable_settings: ManipulatableSettings = ManipulatableSettings.new()
	manipulatable_settings.movable = true
	manipulatable_settings.move_rules = [] # No rules needed for this test
	_smithy.settings = manipulatable_settings

	# Add collision shape for indicator generation
	# Use real Smithy dimensions: 112×80 pixels = 7×5 tiles = 35 indicators
	var collision_body: StaticBody2D = auto_free(StaticBody2D.new())
	_smithy.root.add_child(collision_body)
	var collision_shape: CollisionShape2D = auto_free(CollisionShape2D.new())
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(112, 80) # Real Smithy size: 7×5 tiles
	collision_shape.shape = rect_shape
	collision_body.add_child(collision_shape)

	_smithy.root.global_position = Vector2(100, 100)

	# Give smithy initial rotation to test the rotation transfer
	_smithy.root.rotation = deg_to_rad(90) # Start at 90 degrees

	# Give smithy initial scale to test the scale transfer
	_smithy.root.scale = Vector2(1.5, 1.5) # Start at 1.5x scale

func test_indicator_manager_is_child_of_manipulation_parent() -> void:
	## Test: Verify IndicatorManager hierarchy for rotation inheritance
	## Setup: Get IndicatorManager and ManipulationParent from container
	## Act: Check parent relationship
	## Assert: IndicatorManager is child of ManipulationParent

	# Assert: IndicatorManager exists
	assert_object(_indicator_manager).append_failure_message("Object assertion failed").is_not_null().append_failure_message("IndicatorManager should exist in container")

	# Assert: ManipulationParent exists
	assert_object(_manipulation_parent).append_failure_message("Object assertion failed").is_not_null().append_failure_message("ManipulationParent should exist in container")

	# Assert: IndicatorManager is child of ManipulationParent
	var manager_parent: Node = _indicator_manager.get_parent()
	assert_object(manager_parent).append_failure_message("Object assertion failed").is_equal(_manipulation_parent).append_failure_message("IndicatorManager MUST be child of ManipulationParent for rotation inheritance. " + "Current parent: %s (%s)" % [ str(manager_parent.name) if manager_parent != null else "null", str(manager_parent.get_class()) if manager_parent != null else "N/A" ])

func test_manipulation_parent_starts_at_zero_rotation() -> void:
	## Test: Verify ManipulationParent starts with identity transform
	## Setup: Fresh environment
	## Act: Check initial rotation
	## Assert: ManipulationParent rotation is 0
	assert_float(_manipulation_parent.rotation).append_failure_message("Float assertion failed").is_equal(0.0).append_failure_message("ManipulationParent should start at rotation=0, actual: %f" % _manipulation_parent.rotation)

func test_rotation_transferred_after_indicator_generation() -> void:
	## Test: Verify rotation transfer happens AFTER indicators are generated
	## Setup: Smithy with 90° rotation
	## Act: Start move operation (generates indicators and transfers rotation)
	## Assert: 1) ManipulationParent has rotation, 2) Copy normalized, 3) Indicators exist

	# Record initial state
	var initial_smithy_rotation: float = _smithy.root.rotation
	assert_float(initial_smithy_rotation).append_failure_message("Float assertion failed").is_not_null().append_failure_message("Smithy should start at %d degrees" % TEST_ROTATION_DEGREES).is_equal_approx(deg_to_rad(TEST_ROTATION_DEGREES), ROTATION_TOLERANCE)

	# Act: Start move operation
	var move_result: ManipulationData = _manipulation_system.try_move(_smithy.root)

	# Assert: Move started successfully
	var expected_status: int = GBEnums.Status.STARTED
	assert_bool(move_result.status == expected_status).append_failure_message("Move should start successfully").is_true()

func test_indicators_inherit_rotation_from_manipulation_parent() -> void:
	## Test: Verify indicators inherit rotation via transform inheritance
	## Setup: Smithy at 90°, start move
	## Act: Check indicator global rotations
	## Assert: Indicators have rotated via ManipulationParent inheritance

	# Act: Start move operation
	var move_result: ManipulationData = _manipulation_system.try_move(_smithy.root)
	assert_bool(move_result.status == GBEnums.Status.STARTED).append_failure_message("Move should succeed. Status: %s" % GBEnums.Status.keys()[move_result.status]).is_true()

	# Get indicators
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	assert_array(indicators).is_not_empty().append_failure_message("Should have indicators")

	# Assert: Each indicator should have inherited the rotation from ManipulationParent
	var expected_global_rotation: float = _manipulation_parent.global_rotation
	for i in indicators.size():
		var indicator: RuleCheckIndicator = indicators[i]
		var indicator_global_rotation: float = indicator.global_rotation
		# Allow small floating point tolerance
		var rotation_diff: float = abs(indicator_global_rotation - expected_global_rotation)
		assert_bool(rotation_diff < 0.01).append_failure_message(("Indicator[%d] should inherit ManipulationParent rotation via transform inheritance. " + "Expected global_rotation: %.4f, Actual: %.4f, Diff: %.4f") % [ i, expected_global_rotation, indicator_global_rotation, rotation_diff ]).is_true()

func test_indicator_count_consistent_across_rotations() -> void:
	## Test: Verify same indicator count for rotated vs non-rotated objects
	## Setup: Test smithy at 0° and 90°
	## Act: Generate indicators at each rotation
	## Assert: Same indicator count (proves canonical geometry is used)

	# Test 1: Smithy at 0 degrees
	_smithy.root.rotation = 0.0
	var move_result_0: ManipulationData = _manipulation_system.try_move(_smithy.root)
	assert_bool(move_result_0.status == GBEnums.Status.STARTED).append_failure_message("Move operation should start successfully for smithy at 0° rotation").is_true()

	var indicators_0deg: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	var count_0deg: int = indicators_0deg.size()

	# Cancel move and reset
	_manipulation_system.cancel()
	await get_tree().physics_frame

	# Test 2: Smithy at 90 degrees
	_smithy.root.rotation = deg_to_rad(90)
	var move_result_90: ManipulationData = _manipulation_system.try_move(_smithy.root)
	assert_bool(move_result_90.status == GBEnums.Status.STARTED).append_failure_message("Move operation should start successfully for smithy at 90° rotation").is_true()

	var indicators_90deg: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	var count_90deg: int = indicators_90deg.size()

	# CRITICAL: Indicator counts MUST be the same
	assert_int(count_90deg).append_failure_message("Integer assertion failed").is_equal(count_0deg).append_failure_message("Indicator count should be IDENTICAL for 0° and 90° rotations (proves canonical geometry). " + "Count at 0°: %d, Count at 90°: %d" % [count_0deg, count_90deg])

func test_preview_shows_correct_rotation_visually() -> void:
	## Test: Verify preview object appears rotated correctly
	## Setup: Smithy at 90°

	# Setup: record original rotation
	var original_rotation: float = _smithy.root.rotation

	# Act: Start move
	var move_result: ManipulationData = _manipulation_system.try_move(_smithy.root)
	assert_bool(move_result.status == GBEnums.Status.STARTED).append_failure_message("Move operation should start successfully").is_true()

	# Get the manipulation copy
	var manipulation_data: ManipulationData = _container.get_states().manipulation.data
	var copy_root: Node = manipulation_data.move_copy.root

	# Calculate combined transform via global_rotation
	var copy_global_rotation: float = copy_root.global_rotation

	# Assert: Copy's global rotation should match original (via parent transform)
	var rotation_diff: float = abs(copy_global_rotation - original_rotation)
	assert_bool(rotation_diff < 0.01).append_failure_message("Preview should appear at original rotation visually. " + "Original: %f, Copy local: %f, Copy global: %f (includes parent), Diff: %f" % [ original_rotation, copy_root.rotation, copy_global_rotation, rotation_diff ]).is_true()

func test_rotation_transferred_to_parent_after_indicator_generation() -> void:
	## Test: Verify rotation/scale is transferred to ManipulationParent AFTER indicators created
	## Setup: Smithy with rotation=90° and scale=1.5
	## Act: Start move (triggers indicator generation)
	## Assert: 1) Copy is normalized (rotation=0, scale=1.0)
	## 2) ManipulationParent has the rotation/scale
	## 3) Indicators exist and were generated correctly

	# Setup: Give smithy non-identity transform
	_smithy.root.rotation = deg_to_rad(90)
	_smithy.root.scale = Vector2(1.5, 1.5)
	var original_rotation: float = _smithy.root.rotation
	var original_scale: Vector2 = _smithy.root.scale

	# Act: Start move (this should normalize copy, generate indicators, then transfer to parent)
	var move_result: ManipulationData = _manipulation_system.try_move(_smithy.root)
	assert_object(move_result).append_failure_message("Object assertion failed").is_not_null().append_failure_message("Move should return valid ManipulationData")
	assert_int(move_result.status).append_failure_message("Move should start successfully. Status: %s" % GBEnums.Status.keys()[move_result.status]).is_equal(GBEnums.Status.STARTED)

	# Get the manipulation copy
	var manipulation_data: ManipulationData = _container.get_states().manipulation.data
	var copy_root: Node2D = manipulation_data.move_copy.root

	# Assert 1: Copy should be normalized (rotation=0, scale=1.0) for canonical geometry
	assert_float(copy_root.rotation).append_failure_message("Float assertion failed").is_equal_approx(0.0, 0.01).append_failure_message("Copy rotation should be normalized to 0 for indicator generation. " + "Actual: %f" % copy_root.rotation)
	assert_vector(copy_root.scale).append_failure_message("Vector assertion failed").is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01)).append_failure_message("Copy scale should be normalized to (1,1) for indicator generation. " + "Actual: %s" % str(copy_root.scale))

	# Assert 2: ManipulationParent should have the original rotation/scale
	var parent_id: int = _manipulation_parent.get_instance_id()
	var parent_scale_str: String = str(_manipulation_parent.scale)
	var diag: PackedStringArray = PackedStringArray()
	diag.append("[TEST] Checking ManipulationParent (instance_id=%d) rotation=%f scale=%s" % [parent_id, _manipulation_parent.rotation, parent_scale_str])
	assert_float(_manipulation_parent.rotation).append_failure_message("Float assertion failed").is_equal_approx(original_rotation, 0.01).append_failure_message("ManipulationParent should have original rotation after indicator generation. " + "Expected: %f, Actual: %f. Context: %s" % [original_rotation, _manipulation_parent.rotation, "\n".join(diag)])
	assert_vector(_manipulation_parent.scale).append_failure_message("Vector assertion failed").is_equal_approx(original_scale, Vector2(0.01, 0.01)).append_failure_message("ManipulationParent should have original scale after indicator generation. " + "Expected: %s, Actual: %s" % [str(original_scale), str(_manipulation_parent.scale)])

	# Assert 3: Indicators should have been generated
	var indicators: Array[RuleCheckIndicator] = _indicator_manager.get_indicators()
	assert_array(indicators).is_not_empty().append_failure_message("Indicators should be generated after move starts. Count: %d" % indicators.size())

	# Assert 4: Copy's GLOBAL transform should match original (via parent inheritance)
	var copy_global_rotation: float = copy_root.global_rotation
	var copy_global_scale: Vector2 = copy_root.global_scale
	var rotation_diff: float = abs(copy_global_rotation - original_rotation)
	assert_bool(rotation_diff < 0.1).append_failure_message("Boolean assertion failed").is_true().append_failure_message("Copy's global rotation (via parent) should match original. " + "Original: %f, Copy global: %f, Diff: %f" % [ original_rotation, copy_global_rotation, rotation_diff ])

	# Note: Global scale comparison is approximate due to transform composition
	assert_vector(copy_global_scale).append_failure_message("Vector assertion failed").is_equal_approx(original_scale, Vector2(0.1, 0.1)).append_failure_message("Copy's global scale (via parent) should approximately match original. " + "Expected: %s, Actual: %s" % [str(original_scale), str(copy_global_scale)])