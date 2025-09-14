class_name PlacementRuleTestFactory
extends RefCounted

## PlacementRule Test Factory
## Centralized creation of placement rules for testing
## Following GdUnit best practices: DRY principle, centralize common object creation

## Standard collision layer and mask constants for consistency
const DEFAULT_COLLISION_LAYER: int = 1
const DEFAULT_COLLISION_MASK: int = 1

## Creates a CollisionsCheckRule with standard test configuration
## @param apply_mask: Objects mask to apply rule to
## @param collision_mask: Collision mask for detection
## @param pass_on_collision: Whether to allow placement on collision
static func create_collision_rule_with_settings(apply_mask: int, collision_mask: int, pass_on_collision: bool = true) -> CollisionsCheckRule:
	var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
	collision_rule.apply_to_objects_mask = apply_mask
	collision_rule.collision_mask = collision_mask
	collision_rule.pass_on_collision = pass_on_collision
	
	# Initialize messages to prevent setup issues
	if collision_rule.messages == null:
		collision_rule.messages = CollisionRuleSettings.new()
	
	return collision_rule

## Creates a ValidPlacementTileRule with standard test configuration
## @param apply_mask: Objects mask to apply rule to
static func create_valid_tile_rule(apply_mask: int = DEFAULT_COLLISION_LAYER) -> ValidPlacementTileRule:
	var tile_rule: ValidPlacementTileRule = ValidPlacementTileRule.new()
	tile_rule.apply_to_objects_mask = apply_mask
	return tile_rule

## Creates a default collision rule with standard test settings
static func create_default_collision_rule() -> CollisionsCheckRule:
	return create_collision_rule_with_settings(DEFAULT_COLLISION_LAYER, DEFAULT_COLLISION_MASK, true)

## Creates a set of standard placement rules for testing
## @param include_tile_rule: Whether to include ValidPlacementTileRule
static func create_standard_placement_rules(include_tile_rule: bool = true) -> Array[PlacementRule]:
	var rules: Array[PlacementRule] = []
	
	# Always include collision rule
	rules.append(create_default_collision_rule())
	
	# Optionally include tile rule
	if include_tile_rule:
		rules.append(create_valid_tile_rule())
	
	return rules

## Creates placement rules from existing rule templates
## @param base_collision_rule: Template collision rule to copy settings from
## @param base_tile_rule: Template tile rule to copy settings from
static func create_rules_from_templates(base_collision_rule: CollisionsCheckRule = null, base_tile_rule: TileCheckRule = null) -> Array[PlacementRule]:
	var rules: Array[PlacementRule] = []
	
	if base_collision_rule != null:
		var collision_rule: CollisionsCheckRule = CollisionsCheckRule.new()
		collision_rule.apply_to_objects_mask = base_collision_rule.apply_to_objects_mask
		collision_rule.collision_mask = base_collision_rule.collision_mask
		collision_rule.pass_on_collision = base_collision_rule.pass_on_collision
		if collision_rule.messages == null:
			collision_rule.messages = CollisionRuleSettings.new()
		rules.append(collision_rule)
	
	if base_tile_rule != null and base_tile_rule is ValidPlacementTileRule:
		var tile_rule: ValidPlacementTileRule = ValidPlacementTileRule.new()
		tile_rule.apply_to_objects_mask = base_tile_rule.apply_to_objects_mask
		rules.append(tile_rule)
	
	return rules
