# Test Execution Notes

## Important: Godot Version Issue

The tests are currently running with **Godot 4.5.beta4.mono** (the .NET/C# version), which causes MSBuild errors when running tests because there's no C# project file. This doesn't affect the actual test execution but may cause warnings.

### Solution Options:

1. **Use Standard Godot (Recommended)**: Switch to the non-Mono version of Godot 4.x for running tests
2. **Ignore the MSBuild error**: The tests still run despite this error
3. **Create a dummy .csproj file**: Only if you need to use the Mono version

## Test Runner Scripts

### Individual Test Execution
```bash
# Run a single test file
./test_individual.sh test/grid_building_test/utilities/gb_geometry_math_test.gd

# With custom Godot path
./test_individual.sh test/grid_building_test/utilities/gb_geometry_math_test.gd "C:/path/to/godot.exe"
```

### Batch Test Execution
```bash
# Run all tests with continue on failure
./test_all_simple.sh

# Run all tests with stop on first failure
./test_all_simple.sh --stop-on-failure

# With custom Godot path
./test_all_simple.sh "C:/path/to/godot.exe" --stop-on-failure
```

## Known Issues

1. **Timeout on batch execution**: When running all tests at once via directory (`test/grid_building_test`), the execution may timeout. This appears to be related to how gdUnit4 handles large test suites in a single execution.

2. **MSBuild Error**: The Mono version of Godot attempts to compile C# classes even though this is a pure GDScript project.

3. **Test Failures**:
   - `gb_geometry_utils_test.gd` - Has 1 failing test case
   - `gb_geometry_math_performance_test_fixed.gd` - Cannot find test cases

## Working Tests

The following utility tests are confirmed working:
- ✅ `gb_geometry_math_test.gd` - 43 test cases, all passing
- ✅ `gb_geometry_math_helpers_test.gd` - 11 test cases, all passing
- ✅ `gb_geometry_math_performance_test.gd` - 7 test cases, all passing
- ✅ `gb_search_utils_test.gd` - 1 test case, passing
- ✅ `gb_string_test.gd` - 9 test cases, all passing
- ⚠️ `gb_geometry_utils_test.gd` - 12 test cases, 1 failure
- ❌ `gb_geometry_math_performance_test_fixed.gd` - No test cases found

## Recommended Workflow

1. **Run individual test files** during development to quickly check specific functionality
2. **Use the standard (non-Mono) Godot** to avoid MSBuild errors
3. **Focus on utility tests first** as they have fewer dependencies
4. **Fix failing tests** before moving to higher-level tests

## Environment Setup

Set the GODOT environment variable to avoid specifying the path each time:
```bash
export GODOT="C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot.exe"
```

Or for the standard (non-Mono) version:
```bash
export GODOT="C:/path/to/standard/godot.exe"
```
