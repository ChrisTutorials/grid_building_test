## Shared helper functions for manipulation regression tests
##
## Provides common utilities for creating test objects, setting up environments,
## and validating manipulation behavior. Follows DRY principles to reduce duplication
## across manipulation test suites.

class_name ManipulationTestHelpers
extends RefCounted


## Create a manipulatable object with collision for manipulation testing
##
## @param p_parent: Parent node to add the object to
## @param p_name: Name for the root node
## @param p_position: World position for the object
## @param p_size: Size of the collision shape (default 32x32)
## @param p_with_move_rules: Whether to add move rules for indicator generation
## @return: The Manipulatable component (access root via manipulatable.root)
static func create_test_manipulatable(
	p_parent: Node,
	p_name: String,
	p_position: Vector2,
	p_size: Vector2 = Vector2(32, 32),
	p_with_move_rules: bool = true
) -> Manipulatable:
	var root := Node2D.new()
	root.name = p_name
	root.position = p_position

	# Add collision body
	var body := CharacterBody2D.new()
	body.name = "Body"
	body.collision_layer = 1  # This body IS on layer 1
	body.collision_mask = 1  # This body DETECTS collisions on layer 1
	root.add_child(body)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape"
	var rect := RectangleShape2D.new()
	rect.size = p_size
	shape.shape = rect
	body.add_child(shape)

	# Add manipulatable component
	var manipulatable := Manipulatable.new()
	manipulatable.name = "Manipulatable"
	manipulatable.root = root

	# Configure settings
	var settings := ManipulatableSettings.new()
	settings.movable = true
	settings.rotatable = false
	settings.flip_horizontal = false
	settings.flip_vertical = false

	# Add move rules if requested (required for indicator generation)
	if p_with_move_rules:
		var collision_rule := CollisionsCheckRule.new()
		var bounds_rule := WithinTilemapBoundsRule.new()
		settings.move_rules = [collision_rule, bounds_rule]

	manipulatable.settings = settings
	root.add_child(manipulatable)

	# Add placement shape for targeting (optional but useful)
	var placement_area := Area2D.new()
	placement_area.name = "PlacementShape"
	placement_area.collision_layer = 2048  # Targetable layer
	root.add_child(placement_area)

	var placement_shape := CollisionShape2D.new()
	var placement_rect := RectangleShape2D.new()
	placement_rect.size = p_size
	placement_shape.shape = placement_rect
	placement_area.add_child(placement_shape)

	# Add to parent and return
	p_parent.add_child(root)

	return manipulatable


## Create a collision obstacle for testing validation failures
##
## @param p_parent: Parent node to add the obstacle to
## @param p_position: World position for the obstacle
## @param p_size: Size of the collision shape (default 32x32)
## @param p_collision_layer: Collision layer bit (default 1)
## @return: The StaticBody2D obstacle
static func create_collision_obstacle(
	p_parent: Node,
	p_position: Vector2,
	p_size: Vector2 = Vector2(32, 32),
	p_collision_layer: int = 1
) -> StaticBody2D:
	var obstacle := StaticBody2D.new()
	obstacle.name = "Obstacle"
	obstacle.global_position = p_position
	obstacle.collision_layer = p_collision_layer
	obstacle.collision_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = p_size
	shape.shape = rect
	obstacle.add_child(shape)

	p_parent.add_child(obstacle)

	return obstacle


## Count RuleCheckIndicator children in IndicatorManager
##
## @param p_indicator_manager: The IndicatorManager to inspect
## @return: Number of RuleCheckIndicator children
static func get_indicator_count(p_indicator_manager: IndicatorManager) -> int:
	var count := 0
	for child: Node in p_indicator_manager.get_children():
		if child is RuleCheckIndicator:
			count += 1
	return count


## Format manipulation status for diagnostic messages
##
## @param p_status: The GBEnums.Status value
## @return: Human-readable status string
static func format_status(p_status: int) -> String:
	match p_status:
		GBEnums.Status.CREATED:
			return "CREATED"
		GBEnums.Status.STARTED:
			return "STARTED"
		GBEnums.Status.FINISHED:
			return "FINISHED"
		GBEnums.Status.FAILED:
			return "FAILED"
		GBEnums.Status.CANCELED:
			return "CANCELED"
		_:
			return "UNKNOWN(%d)" % p_status
