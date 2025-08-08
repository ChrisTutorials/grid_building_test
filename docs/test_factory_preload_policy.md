# Test Factory Usage and Preload Policy - Grid Building Plugin

## Project-Wide Rule: Do Not Preload Scripts with `class_name` for Global Usage

**Rule:**

# test_factory_preload_policy.md
- Preloading a script with `class_name` creates a local symbol that can shadow the global class, leading to confusing bugs and maintenance issues.
**Example (Correct):**
```gdscript
# Use the global class name directly
var node = GodotTestFactory.create_node2d(self)
```

**Example (Incorrect):**
```gdscript
# Do NOT preload a script with class_name for global usage
const GodotTestFactory = preload("res://test/grid_building_test/factories/godot_test_factory.gd")
var node = GodotTestFactory.create_node2d(self)
```

**Test Suite Policy:**
- GdUnitTestSuite scripts must remain anonymous (no `class_name`).
- All node creation in tests should use `GodotTestFactory` global methods, not preloads.

---

**Location:** This rule is documented in `test/grid_building_test/docs/test_factory_preload_policy.md` and referenced from project-wide documentation.
