# Test Execution Guide

This guide provides comprehensive instructions for running tests in the Grid Building Plugin project.

## Prerequisites

### Required Software
- **Godot 4.5+** (This project uses Godot 4.5 features)
- **Git Bash** (for Windows users)
- **GdUnit4** (included in `addons/gdUnit4/`)

### Environment Setup

Set the `GODOT` environment variable to point to your Godot executable:

#### Windows (PowerShell)
```powershell
$env:GODOT = "C:\Users\chris\AppData\Roaming\godotenv\godot\bin\godot.exe"
```

#### Windows (Command Prompt)
```cmd
set GODOT=C:\Users\chris\AppData\Roaming\godotenv\godot\bin\godot.exe
```

#### Linux/Mac
```bash
export GODOT="/path/to/godot"
```

## Running Tests

### Using VS Code Tasks (Recommended)

1. Open the Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`)
2. Run "Tasks: Run Task"
3. Select "Run GdUnit Test"
4. The currently open test file will be executed

### Using Command Line

#### Run a Single Test File

##### Windows (PowerShell)
```powershell
& "C:\Program Files\Git\bin\bash.exe" -c "./run_gdunit_test.sh test/grid_building_test/utilities/gb_geometry_math_test.gd"
```

##### Git Bash / Linux / Mac
```bash
./run_gdunit_test.sh test/grid_building_test/utilities/gb_geometry_math_test.gd
```

Example (demo visuals distinct-colors validation):

```bash
./run_gdunit_test.sh test/demos/demo_composition_containers_visual_settings_test.gd
```

#### Run All Tests in a Directory

##### Windows (PowerShell)
```powershell
& "C:\Program Files\Git\bin\bash.exe" -c "./run_gdunit_test.sh test/grid_building_test/"
```

##### Git Bash / Linux / Mac
```bash
./run_gdunit_test.sh test/grid_building_test/
```

#### Run All Tests
```bash
./run_gdunit_test.sh test/
```

### Direct Godot Execution

You can also run tests directly using Godot's command line:

```bash
godot --path . --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd -- --add test/grid_building_test --verbose
```

Note: If you don't set GODOT/GODOT_BIN, the runner will try to use `godot` from your PATH.

## Test Organization

```text
test/
├── grid_building_test/         # Core plugin tests
│   ├── integration/            # Integration tests
│   ├── systems/               # System tests
│   ├── placement/             # Placement manager tests
│   ├── utilities/             # Utility function tests
│   └── validation/            # Validation tests
└── demos/                     # Demo scene tests
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Godot binary does not exist"

**Problem:** The test runner can't find Godot.

**Solution:**
- Ensure `GODOT` environment variable is set correctly
- Verify the path points to an existing Godot executable
- On Windows, use forward slashes or escaped backslashes in paths

#### 2. Path Conversion Issues

**Problem:** Windows paths aren't being converted correctly (e.g., "C:UserschrisAppData...")

**Solution:**
- The test runner script now handles path conversion automatically
- If issues persist, use Git Bash directly instead of PowerShell
- Ensure you're using the latest version of `run_gdunit_test.sh`

#### 3. Test File Not Found

**Problem:** The test runner can't locate your test file.

**Solution:**
- Provide the full path relative to project root: `test/grid_building_test/utilities/test_file.gd`
- Or just provide the filename: `test_file.gd` (will search in test/ directory)
- Ensure the file extension is `.gd`

#### 4. Debug Breaks / Tests Hanging

**Problem:** Tests hang at debug breakpoints.

**Solution:**
- The test runner removes the `-d` flag to prevent debug breaks
- If tests still hang, check for `assert()` statements in your code
- Install `expect` tool for automatic debug break handling (optional)

#### 5. MSBuild Error (Mono/C# projects)

**Problem:** "MSBuild error MSB1003: Specify a project or solution file"

**Solution:**
- This is a warning for Mono builds and can be safely ignored for GDScript-only projects
- If you have C# code, ensure a `.csproj` or `.sln` file exists in the project root

## Important Notes for AI Assistants

### Method Name Changes
- **OLD:** `validate_state()` 
- **NEW:** `validate_dependencies()`
- All GB systems and GB injectables now use the new method name
- Returns `Array[String]` of validation issues (empty if valid)

### Environment Variables
- Always use environment variables (`GODOT`, `GODOT_BIN`) for Godot paths
- Never hardcode paths like `C:/Godot/Godot4.exe`
- The test runner checks these in order: `$GODOT` → `$GODOT_BIN` → `godot` (in PATH)

### Test Execution Best Practices
1. Run tests before committing code changes
2. Use parameterized tests for better coverage
3. Keep test functions focused and minimal
4. Use `auto_free()` for proper node cleanup
5. Prefer real objects over mocks/stubs

### Test Writing Guidelines
- Test files should extend `GdUnitTestSuite`
- Use `before_test()` for setup, `after_test()` for cleanup
- Name test functions with `test_` prefix
- Use descriptive test names that explain what's being tested
- Add `append_failure_message()` for better debugging

## Exit Codes

The test runner returns different exit codes:

- `0`: All tests passed
- `1`: Test failures or errors
- `2`: Infinite debug break loop detected
- `124`: Timeout reached (DEBUG_BREAK_TIMEOUT_SEC)

### Debugger Break Monitoring (Anti-hang)

The unified runners (`run_gdunit_test.sh`, `test_all_simple.sh`, `test_individual.sh`) stream Godot output and watch for repeated debugger breaks ("Debugger Break" or `debug>` prompts).

Environment variables:

- `DEBUG_BREAK_THRESHOLD` (default: `3`)  Maximum allowed breaks before the process is force-killed with exit code `2`.
- `DEBUG_BREAK_TIMEOUT_SEC` (default: `900`)  Wall-clock timeout; if exceeded the test process is terminated with exit code `124`.

Override examples:

```bash
DEBUG_BREAK_THRESHOLD=1 ./run_gdunit_test.sh test/grid_building_test/integration/
DEBUG_BREAK_TIMEOUT_SEC=120 ./run_gdunit_test.sh test/
DEBUG_BREAK_THRESHOLD=5 DEBUG_BREAK_TIMEOUT_SEC=300 ./run_gdunit_test.sh test/demos/
```

Rationale: Previously, hitting an assertion inside engine code could yield hundreds of repeated breaks and multi-minute hangs. The streaming monitor enforces fast failure while still surfacing the first few frames for debugging.

## Additional Resources

- [GdUnit4 Documentation](https://github.com/MikeSchulze/gdUnit4)
- [Godot Testing Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)
- [Project Copilot Instructions](.github/copilot-instructions.md)

## Appendix: Verified commands on Windows (Git Bash via PowerShell)

Use Git Bash to invoke the runner script:

```powershell
# Single file
& "C:\\Program Files\\Git\\bin\\bash.exe" -c "./run_gdunit_test.sh test/grid_building_test/integration/building_workflow_integration_test.gd"

# Directory
& "C:\\Program Files\\Git\\bin\\bash.exe" -c "./run_gdunit_test.sh test/grid_building_test/"

# All tests
& "C:\\Program Files\\Git\\bin\\bash.exe" -c "./run_gdunit_test.sh test/"
```

Notes:

- Exit code 100 indicates test failures; 0 indicates success
- HTML report generated under `reports/report_XX/index.html`

Avoid:

- Direct headless Godot invocation for GdUnit: often exits with code 103
- `bash` without full path on Windows if not in PATH
