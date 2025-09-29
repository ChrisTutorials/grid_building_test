#!/usr/bin/env -S godot --headless --script
extends SceneTree

## Grid Building Demo Scene Analyzer
## Specialized analyzer for debugging grid building demo scenes with custom classes
## Usage: godot --headless --script grid_building_scene_analyzer.gd -- <scene_path>

func _initialize() -> void:
	print("=== GRID BUILDING DEMO SCENE ANALYZER ===")
	
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = ""
	
	if args.size() > 0:
		scene_path = args[0]
	
	if scene_path == "" or not scene_path.ends_with(".tscn"):
		print("ERROR: No scene file specified")
		print("Usage: godot --headless --script grid_building_scene_analyzer.gd -- <scene_path>")
		quit(1)
		return
	
	print("Analyzing grid building demo scene: " + scene_path)
	
	# Convert to resource path if needed
	var resource_path: String = scene_path
	if not resource_path.begins_with("res://"):
		resource_path = "res://" + resource_path
	
	# Load and analyze the scene
	var scene_resource: Resource = load(resource_path)
	if not scene_resource:
		print("ERROR: Could not load scene: " + resource_path)
		quit(1)
		return
	
	var scene_instance: Node = scene_resource.instantiate()
	if not scene_instance:
		print("ERROR: Could not instantiate scene")
		quit(1)
		return
	
	# Generate grid building specific analysis
	var analysis: String = _generate_grid_building_analysis(scene_instance)
	print(analysis)
	
	# Clean up
	scene_instance.queue_free()
	quit(0)

func _generate_grid_building_analysis(scene_root: Node) -> String:
	"""Generate comprehensive grid building scene analysis."""
	var output: String = ""
	
	output += "=== GRID BUILDING SCENE ANALYSIS ===\n"
	output += "Scene: %s\n" % scene_root.name
	output += "Generated at: %s\n\n" % Time.get_datetime_string_from_system()
	
	# Grid Building Component Analysis
	output += _analyze_grid_building_components(scene_root)
	
	# Placement Indicators Analysis
	output += _analyze_placement_indicators(scene_root)
	
	# Building Objects Analysis
	output += _analyze_building_objects(scene_root)
	
	# TileMap Analysis
	output += _analyze_tilemaps(scene_root)
	
	# System Components Analysis
	output += _analyze_system_components(scene_root)
	
	# Generic Node Analysis (for completeness)
	output += _analyze_all_node_types(scene_root)
	
	return output

func _analyze_grid_building_components(scene_root: Node) -> String:
	"""Analyze core grid building components using direct class detection."""
	var output: String = "=== GRID BUILDING COMPONENTS ANALYSIS ===\n"
	
	# Find components using direct class detection
	var components: Dictionary = {}
	_find_grid_building_nodes(scene_root, components)
	
	# Expected counts for typical grid building demo
	var expected_counts: Dictionary = {
		"RuleCheckIndicator": "X (variable)", 
		"IndicatorManager": "1",
		"GridPositioner": "1", 
		"GBInjectorSystem": "1",
		"BuildingSystem": "1", 
		"GridTargetingSystem": "1",
		"ManipulationSystem": "1"
	}
	
	# Report findings
	for target_class: String in expected_counts:
		var expected: String = expected_counts[target_class]
		if target_class in components:
			var nodes: Array = components[target_class]
			output += "✓ %s: %d found (Expected: %s)\n" % [target_class, nodes.size(), expected]
			for node: Node in nodes:
				output += "  - %s at %s\n" % [node.name, node.get_path()]
		else:
			output += "✗ %s: 0 found (Expected: %s)\n" % [target_class, expected]
	
	output += "\n"
	return output

func _analyze_placement_indicators(scene_root: Node) -> String:
	"""Analyze placement indicators in detail."""
	var output: String = "=== PLACEMENT INDICATORS ANALYSIS ===\n"
	
	var all_shapecasts: Array[Node] = _find_all_shapecasts(scene_root)
	output += "Total ShapeCast2D nodes: %d\n\n" % all_shapecasts.size()
	
	if all_shapecasts.size() > 0:
		for i in range(all_shapecasts.size()):
			var shapecast: Node = all_shapecasts[i]
			output += "[%d] %s\n" % [i+1, shapecast.name]
			output += "  Class: %s\n" % shapecast.get_class()
			output += "  Position: %s (global: %s)\n" % [shapecast.position, shapecast.global_position]
			output += "  Rotation: %.2f° | Scale: %s\n" % [shapecast.rotation_degrees, shapecast.scale]
			output += "  Visible: %s | Enabled: %s\n" % [shapecast.visible, shapecast.enabled if shapecast.has_method("set_enabled") else "N/A"]
			
			# Parent information
			if shapecast.get_parent():
				output += "  Parent: %s (%s)\n" % [shapecast.get_parent().name, shapecast.get_parent().get_class()]
			
			# Shape analysis
			if shapecast.shape:
				output += "  Shape: %s\n" % shapecast.shape.get_class()
				if shapecast.shape is RectangleShape2D:
					output += "    Size: %s\n" % shapecast.shape.size
				elif shapecast.shape is CircleShape2D:
					output += "    Radius: %.2f\n" % shapecast.shape.radius
				elif shapecast.shape is ConvexPolygonShape2D:
					output += "    Points: %d\n" % shapecast.shape.points.size()
			else:
				output += "  Shape: None\n"
			
			# Grid building pattern recognition and rule type analysis
			var name_lower: String = shapecast.name.to_lower()
			var patterns: Array[String] = []
			var rule_types: Array[String] = []
			
			if "indicator" in name_lower:
				patterns.append("Indicator")
			if "offset" in name_lower:
				patterns.append("Offset")
			if "testing" in name_lower:
				patterns.append("Testing")
			if "position" in name_lower:
				patterns.append("Position")
			if "error" in name_lower or "err" in name_lower:
				patterns.append("Error")
			
			# Analyze for rule types if this appears to be a RuleCheckIndicator
			if "indicator" in name_lower or "rule" in name_lower:
				# Check for common rule type patterns in name
				if "overlap" in name_lower or "collision" in name_lower:
					rule_types.append("Overlap/Collision")
				if "distance" in name_lower or "spacing" in name_lower:
					rule_types.append("Distance/Spacing")
				if "boundary" in name_lower or "edge" in name_lower:
					rule_types.append("Boundary/Edge")
				if "resource" in name_lower or "cost" in name_lower:
					rule_types.append("Resource/Cost")
				if "terrain" in name_lower or "tile" in name_lower:
					rule_types.append("Terrain/Tile")
				if "valid" in name_lower or "placement" in name_lower:
					rule_types.append("Placement Validation")
				if "count" in name_lower or "limit" in name_lower:
					rule_types.append("Count/Limit")
				
				# Check if node has script and analyze for rule type
				if shapecast.get_script():
					var script: Script = shapecast.get_script()
					if script.resource_path:
						var script_name: String = script.resource_path.get_file().to_lower()
						if "overlap" in script_name:
							rule_types.append("Script: Overlap Rule")
						elif "distance" in script_name:
							rule_types.append("Script: Distance Rule")
						elif "boundary" in script_name:
							rule_types.append("Script: Boundary Rule")
						elif "resource" in script_name:
							rule_types.append("Script: Resource Rule")
						elif "terrain" in script_name:
							rule_types.append("Script: Terrain Rule")
						else:
							rule_types.append("Script: Custom Rule")
				
				# Check for custom properties that might indicate rule type
				if shapecast.has_method("get_rule_type"):
					var rule_type: Variant = shapecast.get_rule_type()
					if rule_type:
						rule_types.append("Property: %s" % rule_type)
				
				if shapecast.has_method("get_validation_type"):
					var validation_type: Variant = shapecast.get_validation_type()
					if validation_type:
						rule_types.append("Validation: %s" % validation_type)
			
			if patterns.size() > 0:
				output += "  Grid Patterns: %s\n" % ", ".join(patterns)
			
			if rule_types.size() > 0:
				output += "  Rule Types: %s\n" % ", ".join(rule_types)
			elif "indicator" in name_lower or "rule" in name_lower:
				output += "  Rule Types: Generic/Unknown\n"
			
			# Visual children analysis
			var visual_children: Array[String] = []
			for child in shapecast.get_children():
				if child is Sprite2D:
					var info: String = "Sprite2D"
					if child.texture:
						info += " (texture: %s)" % child.texture.resource_path.get_file()
					if child.modulate != Color.WHITE:
						info += " (modulate: %s)" % child.modulate
					if child.scale != Vector2.ONE:
						info += " (scale: %s)" % child.scale
					visual_children.append(info)
				elif child is AnimatedSprite2D:
					var info: String = "AnimatedSprite2D"
					if child.sprite_frames:
						info += " (%s)" % child.animation
					visual_children.append(info)
			
			if visual_children.size() > 0:
				output += "  Visuals: %s\n" % ", ".join(visual_children)
			
			output += "\n"
	
	return output

func _analyze_building_objects(scene_root: Node) -> String:
	"""Analyze building objects and structures."""
	var output: String = "=== BUILDING OBJECTS ANALYSIS ===\n"
	
	# Find StaticBody2D nodes (likely buildings)
	var static_bodies: Array[Node] = _find_all_nodes_of_type(scene_root, "StaticBody2D")
	output += "Building objects (StaticBody2D): %d found\n\n" % static_bodies.size()
	
	for i in range(static_bodies.size()):
		var building: Node = static_bodies[i]
		output += "[%d] %s\n" % [i+1, building.name]
		output += "  Class: %s\n" % building.get_class()
		output += "  Position: %s (global: %s)\n" % [building.position, building.global_position]
		output += "  Rotation: %.2f° | Scale: %s\n" % [building.rotation_degrees, building.scale]
		output += "  Collision Layer: %d | Mask: %d\n" % [building.collision_layer, building.collision_mask]
		
		# Analyze collision shapes
		var collision_shapes: Array[String] = []
		var collision_polygons: Array[String] = []
		var areas: Array[String] = []
		var sprites: Array[String] = []
		
		for child in building.get_children():
			if child is CollisionShape2D:
				var shape_info: String = child.shape.get_class() if child.shape else "None"
				if child.shape is RectangleShape2D:
					shape_info += " (size: %s)" % child.shape.size
				elif child.shape is CircleShape2D:
					shape_info += " (radius: %.2f)" % child.shape.radius
				collision_shapes.append(shape_info)
			elif child is CollisionPolygon2D:
				collision_polygons.append("Polygon (%d points)" % child.polygon.size())
			elif child is Area2D:
				areas.append("%s (%s)" % [child.name, child.get_class()])
			elif child is Sprite2D:
				var sprite_info: String = "Sprite2D"
				if child.texture:
					sprite_info += " (%s)" % child.texture.resource_path.get_file()
				sprites.append(sprite_info)
		
		if collision_shapes.size() > 0:
			output += "  Collision Shapes: %s\n" % ", ".join(collision_shapes)
		if collision_polygons.size() > 0:
			output += "  Collision Polygons: %s\n" % ", ".join(collision_polygons)
		if areas.size() > 0:
			output += "  Areas: %s\n" % ", ".join(areas)
		if sprites.size() > 0:
			output += "  Sprites: %s\n" % ", ".join(sprites)
		
		# Check for grid building specific components
		var gb_components: Array[String] = []
		for child in building.get_children():
			var child_class: String = child.get_class()
			if "GB" in child_class or "Grid" in child_class or "Building" in child_class:
				gb_components.append("%s (%s)" % [child.name, child_class])
		
		if gb_components.size() > 0:
			output += "  Grid Building Components: %s\n" % ", ".join(gb_components)
		
		output += "\n"
	
	return output

func _analyze_tilemaps(scene_root: Node) -> String:
	"""Analyze TileMapLayer nodes for grid configuration."""
	var output: String = "=== TILEMAP ANALYSIS ===\n"
	
	var tilemaps: Array[Node] = _find_all_nodes_of_type(scene_root, "TileMapLayer")
	output += "TileMapLayer nodes: %d found\n\n" % tilemaps.size()
	
	for i in range(tilemaps.size()):
		var tilemap: Node = tilemaps[i]
		output += "[%d] %s\n" % [i+1, tilemap.name]
		output += "  Position: %s (global: %s)\n" % [tilemap.position, tilemap.global_position]
		output += "  Enabled: %s | Modulate: %s\n" % [tilemap.enabled, tilemap.modulate]
		
		if tilemap.tile_set:
			var tileset: TileSet = tilemap.tile_set
			output += "  TileSet: %s\n" % tileset.resource_path.get_file()
			output += "  Tile Shape: %d (%s)\n" % [tileset.tile_shape, _get_tile_shape_name(tileset.tile_shape)]
			output += "  Tile Layout: %d (%s)\n" % [tileset.tile_layout, _get_tile_layout_name(tileset.tile_layout)]
			output += "  Tile Size: %s\n" % tileset.tile_size
			output += "  Tile Offset Axis: %d (%s)\n" % [tileset.tile_offset_axis, _get_tile_offset_axis_name(tileset.tile_offset_axis)]
			
			# Count used tiles
			var used_cells: Array[Vector2i] = tilemap.get_used_cells()
			output += "  Used Cells: %d\n" % used_cells.size()
			
			if used_cells.size() > 0:
				var bounds_min: Vector2i = used_cells[0]
				var bounds_max: Vector2i = used_cells[0]
				for cell: Vector2i in used_cells:
					bounds_min.x = min(bounds_min.x, cell.x)
					bounds_min.y = min(bounds_min.y, cell.y)
					bounds_max.x = max(bounds_max.x, cell.x)
					bounds_max.y = max(bounds_max.y, cell.y)
				output += "  Cell Bounds: %s to %s\n" % [bounds_min, bounds_max]
				output += "  Grid Size: %s cells\n" % (bounds_max - bounds_min + Vector2i.ONE)
		else:
			output += "  TileSet: None\n"
		
		output += "\n"
	
	return output

func _analyze_system_components(scene_root: Node) -> String:
	"""Analyze grid building system components."""
	var output: String = "=== SYSTEM COMPONENTS ANALYSIS ===\n"
	
	# Find system nodes
	var systems_node: Node = _find_node_by_name(scene_root, "Systems")
	if systems_node:
		output += "✓ Systems node found: %s (%s)\n" % [systems_node.name, systems_node.get_class()]
		output += "  Child Count: %d\n" % systems_node.get_child_count()
		
		for child in systems_node.get_children():
			output += "  - %s (%s)\n" % [child.name, child.get_class()]
			
			# Analyze specific system types
			if "Injector" in child.name:
				output += "    Function: Dependency injection system\n"
			elif "Building" in child.name:
				output += "    Function: Building placement and management\n"
			elif "Targeting" in child.name:
				output += "    Function: Grid targeting and cursor positioning\n"
			elif "Manipulation" in child.name:
				output += "    Function: Building manipulation (move, delete, etc.)\n"
			elif "Audio" in child.name:
				output += "    Function: Audio management\n"
			elif "Save" in child.name or "Load" in child.name:
				output += "    Function: Save/Load functionality\n"
	else:
		output += "✗ Systems node not found\n"
	
	output += "\n"
	return output

func _analyze_all_node_types(scene_root: Node) -> String:
	"""Analyze all node types for completeness."""
	var output: String = "=== ALL NODE TYPES DISTRIBUTION ===\n"
	
	var node_counts: Dictionary = {}
	_collect_all_node_types(scene_root, node_counts)
	
	var sorted_types: Array = node_counts.keys()
	sorted_types.sort()
	
	for node_type: String in sorted_types:
		output += "  %s: %d\n" % [node_type, node_counts[node_type]]
	
	output += "\nTotal nodes: %d\n" % _count_total_nodes(scene_root)
	output += "\n"
	
	return output

# Helper functions
func _find_all_shapecasts(node: Node) -> Array[Node]:
	var shapecasts: Array[Node] = []
	if node is ShapeCast2D:
		shapecasts.append(node)
	for child in node.get_children():
		shapecasts.append_array(_find_all_shapecasts(child))
	return shapecasts

func _find_grid_building_nodes(node: Node, components: Dictionary) -> void:
	"""Recursively find grid building nodes by direct class name matching."""
	var node_class: String = node.get_class()
	
	# Check for exact grid building class matches
	var target_classes: Array[String] = ["RuleCheckIndicator", "IndicatorManager", "GridPositioner", 
						  "GBInjectorSystem", "BuildingSystem", "GridTargetingSystem", 
						  "ManipulationSystem"]
	
	for target_class: String in target_classes:
		if node_class == target_class or node.is_class(target_class):
			if not target_class in components:
				components[target_class] = []
			components[target_class].append(node)
	
	# Recursively check children
	for child in node.get_children():
		_find_grid_building_nodes(child, components)

func _find_all_nodes_of_type(node: Node, type_name: String) -> Array[Node]:
	var found_nodes: Array[Node] = []
	if node.get_class() == type_name or node.is_class(type_name):
		found_nodes.append(node)
	for child in node.get_children():
		found_nodes.append_array(_find_all_nodes_of_type(child, type_name))
	return found_nodes

func _find_node_by_name(search_root: Node, target_name: String) -> Node:
	if search_root.name == target_name:
		return search_root
	for child in search_root.get_children():
		var result: Node = _find_node_by_name(child, target_name)
		if result:
			return result
	return null

func _collect_all_node_types(node: Node, counts: Dictionary) -> void:
	var node_type: String = node.get_class()
	if node_type in counts:
		counts[node_type] += 1
	else:
		counts[node_type] = 1
	for child: Node in node.get_children():
		_collect_all_node_types(child, counts)

func _count_total_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_total_nodes(child)
	return count

func _get_tile_shape_name(shape: int) -> String:
	match shape:
		TileSet.TILE_SHAPE_SQUARE: return "SQUARE"
		TileSet.TILE_SHAPE_ISOMETRIC: return "ISOMETRIC"
		TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE: return "HALF_OFFSET_SQUARE"
		TileSet.TILE_SHAPE_HEXAGON: return "HEXAGON"
		_: return "UNKNOWN"

func _get_tile_layout_name(layout: int) -> String:
	match layout:
		0: return "STACKED"
		1: return "STACKED_OFFSET"
		2: return "STAIRS_RIGHT"
		3: return "STAIRS_DOWN"
		4: return "DIAMOND_RIGHT"
		5: return "DIAMOND_DOWN"
		_: return "UNKNOWN"

func _get_tile_offset_axis_name(axis: int) -> String:
	match axis:
		0: return "HORIZONTAL"
		1: return "VERTICAL"
		_: return "UNKNOWN"
