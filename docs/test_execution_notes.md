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

## Latest Integration Failure Summary (automated update)

Status snapshot (run on 2025-09-22):
- Total executed integration suites: 44
- Total test cases run: 387
- Failures: 16 | Skipped: 1

Top failing suites (prioritized by number of failures):

1) `building_and_placement_tests.gd` — 7 failures
   - Notable failures: tile coverage/placement validation regressions (multiple failing scenarios), isolated rectangle coverage mismatch (expected 12 tiles, got 4), and specific template_rule scenarios failing where expected=true but validated=false.
   - Diagnostics already produced by the test runner include: missing tiles lists, detailed placement environment state, and indicator summaries. Start here first.

2) `collision_mapper_configuration_test.gd` — 3 failures
   - Symptoms: CollisionMapper missing expected positions or configuration properties (`test_indicator` missing), mapped positions empty for simple shapes in some runs.
   - Action: validate CollisionMapper factory setup in test fixtures and ensure `test_indicator` wiring is present.

3) `indicator_rule_assignment_regression_test.gd` — 3 failures
   - Symptoms: Indicator validity toggles failing when collision objects are added/removed; center indicator unexpectedly invalid.
   - Action: inspect indicator collision masks and test shapes used in failing cases.

4) `indicator_manager_refactored_tests.gd` — 1 failure
   - Symptoms: `test_multiple_setup_calls` expects value > 0 but got 0. Likely a setup ordering or factory auto-add issue.

5) `indicator_manager_test.gd` — 1 failure + warnings
   - Symptoms: `test_indicator_generation_distance` failing expected spacing; additional 'orphan nodes' warnings reported for several tests.
   - Action: check indicator spacing constants and ensure tests use `auto_free()` on created nodes to avoid orphans.

Skipped test (high priority to fix):
- `indicator_manager_test.gd` had one skipped test. Root cause: test parameter decorator naming mismatch. The test harness expects `test_parameters` (snake_case) but the test defines the parameter array under a different name (e.g., `testParameters` or `_test_parameters`). Fix: rename the parameter array to `test_parameters` and include `@warning_ignore("unused_parameter")` on the test definition if needed.

Suggested triage order (short tasks):
1. Fix skipped test parameter name in `indicator_manager_test.gd` so it runs (low friction). Re-run related suite to confirm skip resolved.
2. Triage `building_and_placement_tests.gd` — examine the detailed diagnostics already emitted (tile lists, map rects, positioner state). Reproduce failing cases in isolation and enable `CollisionGeometryCalculator.debug_polygon_overlap = true` where helpful.
3. Validate CollisionMapper setup and factory wiring (fix `test_indicator` missing property in `collision_mapper_configuration_test.gd`).
4. Investigate indicator validity toggles and spacing issues — check mask configuration and constants used by indicator spacing tests.
5. Re-run full integration suites once the top 1-3 failures are resolved.

Commands to run failing suites (examples):
```bash
# Run the single suite that failed most: building_and_placement_tests.gd
TIMEOUT_SEC=300 ./run_tests_simple.sh godot/test/grid_building_test/integration/building/building_and_placement_tests.gd

# Run collision mapper tests
TIMEOUT_SEC=300 ./run_tests_simple.sh godot/test/grid_building_test/integration/collision/collision_mapper_configuration_test.gd

# Run indicator suites
TIMEOUT_SEC=300 ./run_tests_simple.sh godot/test/grid_building_test/integration/indicator/indicator_rule_assignment_regression_test.gd
```

Notes:
- Many failures include rich diagnostic messages already — prefer reading those messages (they include expected vs actual lists, environment state, indicator summaries) before changing test logic.
- Where tests fail due to changed math/thresholds, prefer adjusting test expectations only after confirming the algorithm diverged from documented/intentional behavior. Use `debug_polygon_overlap` and other per-test debug toggles to collect evidence.
