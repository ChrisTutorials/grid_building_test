## Utility to snapshot and diff class instance counts within the active scene tree.
## NOTE: This only inspects Nodes reachable from the scene tree root. Orphan/leaked
## nodes that are completely detached will not be seen here, but overall object
## count deltas (Performance.OBJECT_COUNT) are also captured for context.
class_name GBClassCountLogger
extends RefCounted

## Recursively counts node classes under the provided root.
func snapshot_tree(root: Node) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	if root:
		_count_classes(root, counts)
	return counts

func _count_classes(node: Node, counts: Dictionary[String, int]) -> void:
	var cls: String = node.get_class()
	counts[cls] = (counts.get(cls, 0) as int) + 1
	for child in node.get_children():
		_count_classes(child, counts)

## Returns classes whose count increased (positive diff) between old_counts and new_counts.
func diff_increases(old_counts: Dictionary[String, int], new_counts: Dictionary[String, int]) -> Dictionary[String, int]:
	var inc: Dictionary[String, int] = {}
	for k in new_counts.keys():
		var before: int = old_counts.get(k, 0)
		var after: int = new_counts[k]
		if after > before:
			inc[k] = after - before
	return inc

## Returns total object count (all Object instances) if monitor available, else -1.
func total_object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))
