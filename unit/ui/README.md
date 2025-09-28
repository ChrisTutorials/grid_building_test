# UI Tests

This directory contains user interface and logging system tests for the Grid Building plugin.

## Test Coverage

- **gb_action_log_failed_reasons_test.gd**: Comprehensive test suite for GBActionLog failure reason display functionality
  - Tests `append_validation_results()` method with failed reason logging
  - Demonstrates and validates the bug where detailed validation failure reasons don't appear in build logs when `print_failed_reasons=true`
  - Validates proper behavior when failed reasons are disabled
  - Tests successful build scenarios

## Running UI Tests

```bash
# Run all UI tests
GODOT=/path/to/godot ./run_gdunit_test.sh godot/test/grid_building_test/ui/

# Run specific UI test
GODOT=/path/to/godot ./run_gdunit_test.sh godot/test/grid_building_test/ui/gb_action_log_failed_reasons_test.gd
```

## Test Organization

UI tests follow the grid_building_test structure and focus on:
- User interface components
- Logging and feedback systems  
- Action log functionality
- UI state management
- User interaction workflows