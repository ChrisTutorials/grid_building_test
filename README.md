# Grid Building Plugin Test Suite

**Plugin Documentation:** https://gridbuilding.pages.dev/

This repository contains the comprehensive test suite for the Grid Building Plugin, providing **1410 plugin tests** covering all core functionality.

## Test Organization

This test suite provides all plugin core tests:
- **1410 plugin tests** - Complete validation of Grid Building plugin functionality
  - Unit tests for core utilities and systems
  - Integration tests for system interactions
  - Placement rule validation tests
  - Indicator generation and management tests
  - Collision detection and mapping tests
  - Building system workflow tests

**Note:** The full demo project includes additional demo-specific tests (130 tests) along with this complete plugin test suite.

## Versions

- **GdUnit4:** `6.0.0` (for Godot 4.5)
- **Godot:** `4.5` (stable) - test environment
- **Grid Building Plugin:** `5.0.1` (supports Godot 4.4.0, 4.4.1, 4.5 stable)

## Running the Tests

### 1. Install GdUnit4

Follow the official GdUnit4 installation steps:

1. Open Godot Editor (4.4.0, 4.4.1, or 4.5 stable)
2. Open your project (demo or plugin development project)
3. Install GdUnit4 as an EditorPlugin via the AssetLib or manual installation
4. See official instructions: https://mikeschulze.github.io/gdUnit4/first_steps/getting-started/

### 2. Using the GdUnit4 GUI Test Runner

1. With the project open in the Godot editor, open **Editor → Manage Plugins** and ensure GdUnit4 is enabled
2. Open the GdUnit4 dock (usually appears as a panel in the editor)
3. Use the GdUnit4 UI to add test folders or files
4. Run tests using the UI controls - you can run entire folders or individual test files
5. View results and failure traces in the dock

### 3. Test Organization Structure

Tests are organized by feature area:

- `building/` - Building system and placement tests
- `positioning/` - Grid positioning and coordinate tests
- `rules/` - Placement rule validation tests
- `integration/` - System integration tests
- `regressions/` - Regression test cases
- `utilities/` - Utility class tests
- `e2e/` - End-to-end workflow tests

## Troubleshooting

**Tests can't find resources:** Ensure the test suite is properly imported in your project workspace so `res://` paths resolve correctly.

**Version mismatch:** Always use the GdUnit4 release compatible with your Godot version (6.0.0 for Godot 4.5) and match the plugin version. See versions section above.

**Test fails in suite but passes individually:** Try running the failing test in isolation to see the full stack trace and identify isolation issues.

## Further Reading

- **Plugin Documentation:** https://gridbuilding.pages.dev/
- **GdUnit4 Getting Started:** https://mikeschulze.github.io/gdUnit4/first_steps/getting-started/
- **GdUnit4 Settings:** https://mikeschulze.github.io/gdUnit4/first_steps/settings/