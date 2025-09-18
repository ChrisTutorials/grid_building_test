class_name PlaceableTestFactory
extends RefCounted

## Placeable Test Factory  
## Centralized creation of Placeable objects for testing
## Following GdUnit best practices: DRY principle, centralize common object creation

## Creates a test placeable with standard rules configuration
## @param base_placeable: Base placeable to copy scene from (e.g., smithy_placeable)
## @param display_name: Display name for the test placeable
## @param include_tile_rule: Whether to include ValidPlacementTileRule
static func create_test_placeable_with_rules(base_placeable: Placeable, display_name: String = "Test Placeable With Rules", include_tile_rule: bool = true) -> Placeable:
	var placeable: Placeable = Placeable.new()
	placeable.packed_scene = base_placeable.packed_scene
	placeable.display_name = display_name
	
	# Use PlacementRuleTestFactory for consistent rule creation
	placeable.placement_rules = PlacementRuleTestFactory.create_standard_placement_rules(include_tile_rule)
	
	return placeable

## Creates a polygon test placeable (extracted from UnifiedTestFactory)
## @param test_instance: Test instance for node management
static func create_polygon_test_placeable(test_instance: Node) -> Placeable:
	assert(test_instance != null, "test parameter cannot be null")
	
	var placeable := Placeable.new()
	assert(placeable != null, "Failed to create Placeable instance")
	
	placeable.resource_name = "TestPolygonPlaceable"
	assert(placeable.resource_name == "TestPolygonPlaceable", "Failed to set resource_name")
	
	# Create a basic packed scene reference (we'll create the scene dynamically)
	var scene := PackedScene.new()
	assert(scene != null, "Failed to create PackedScene instance")
	
	var polygon_obj := CollisionObjectTestFactory.create_polygon_test_object(test_instance, test_instance)
	assert(polygon_obj != null, "create_polygon_test_object returned null")
	
	var pack_result := scene.pack(polygon_obj)
	assert(pack_result == OK, "Failed to pack polygon object into scene: " + str(pack_result))
	
	placeable.packed_scene = scene
	assert(placeable.packed_scene != null, "Failed to assign packed_scene to placeable")
	assert(placeable.packed_scene == scene, "Packed scene assignment verification failed")
	
	return placeable

## Creates a polygon test setup with rules and placeable
## @param test_instance: Test instance for node management
static func create_polygon_test_setup(test_instance: Node) -> Dictionary:
	var polygon_placeable: Placeable = create_polygon_test_placeable(test_instance)
	
	# Extract rules from polygon placeable or create default rules if none exist
	var rules: Array[PlacementRule] = []
	if polygon_placeable.placement_rules != null and not polygon_placeable.placement_rules.is_empty():
		rules = polygon_placeable.placement_rules
	else:
		# Create default rules for polygon testing using PlacementRuleTestFactory
		var collision_rule: CollisionsCheckRule = PlacementRuleTestFactory.create_default_collision_rule()
		collision_rule.pass_on_collision = true  # Allow placement even with collisions for test
		rules.append(collision_rule)
	
	return {
		"rules": rules,
		"placeable": polygon_placeable
	}

## Creates a basic test placeable without placement rules
## @param base_placeable: Base placeable to copy scene from
## @param display_name: Display name for the placeable
static func create_basic_test_placeable(base_placeable: Placeable, display_name: String = "Basic Test Placeable") -> Placeable:
	var placeable: Placeable = Placeable.new()
	placeable.packed_scene = base_placeable.packed_scene
	placeable.display_name = display_name
	placeable.placement_rules = []
	
	return placeable

## Creates a smithy-based test placeable using loaded smithy resource
## @param smithy_placeable: The loaded smithy placeable resource
## @param include_tile_rule: Whether to include ValidPlacementTileRule
static func create_smithy_test_placeable(smithy_placeable: Placeable, include_tile_rule: bool = true) -> Placeable:
	return create_test_placeable_with_rules(smithy_placeable, "Smithy Test Placeable", include_tile_rule)

## Validates that a placeable has the required configuration for testing
## @param placeable: The placeable to validate
## @param context: Context string for error messages
static func validate_test_placeable(placeable: Placeable, context: String = "Test placeable") -> bool:
	if placeable == null:
		push_error("%s: placeable is null" % context)
		return false
	
	if placeable.packed_scene == null:
		push_error("%s: packed_scene is null" % context)
		return false
	
	if placeable.placement_rules == null:
		push_warning("%s: placement_rules is null, tests may fail" % context)
	
	return true
