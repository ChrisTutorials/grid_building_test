# Test Execution Guide - Grid Building Plugin

**Reference:** This document is referenced from [copilot-instructions.md](../copilot-instructions.md) and complements [test-factory-guide.md](../project/test-factory-guide.md).

## Overview

This guide provides comprehensive instructions for running tests in the Grid Building Plugin project using GdUnit4.

## Prerequisites

### Required Software

- **Godot 4.5+** (This project uses Godot 4.5 features)
- **Git Bash** (for Windows users)
- **GdUnit4** (included in `addons/gdUnit4/`)

### Environment Setup

Set the `GODOT` environment variable to point to your Godot executable:

**Important:** Use forward slashes in Windows paths for cross-platform compatibility (see [Cross-Platform Path Handling](cross-platform-path-handling.md)):

#### Windows (PowerShell)
```powershell
$env:GODOT = "C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot"
```

#### Windows (Command Prompt)
```cmd
set GODOT=C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot
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

## Test Organization

```
test/
├── grid_building_test/         # Core plugin tests
│   ├── integration/            # Integration tests
│   ├── systems/               # System tests
│   ├── placement/             # Placement manager tests
│   ├── utilities/             # Utility function tests
│   └── validation/            # Validation tests
└── demos/                     # Demo scene tests
```

## Test Debugging Strategy

### Bottom-Up Testing Approach

When debugging test failures, always start with the lowest-level components first:

1. **Utilities** (e.g., `gb_geometry_math_test.gd`, `gb_geometry_utils_test.gd`) - Pure functions with no dependencies
2. **Data Structures** (e.g., validation parameters, rules) - Simple objects with minimal dependencies
3. **Components** (e.g., collision mapper, validators) - Mid-level objects with some dependencies
4. **Systems** (e.g., building system, manipulation system) - High-level objects with many dependencies
5. **Integration Tests** - Full system tests with complete dependency chains

### Rationale

Low-level bugs often cascade into high-level failures. Fixing utilities and components first resolves root causes rather than applying band-aids to symptoms.

### Testing Order Priority

- Start with: `test/grid_building_test/utilities/`
- Then: `test/grid_building_test/validation/`
- Then: `test/grid_building_test/placement/manager/components/`
- Then: `test/grid_building_test/systems/`
- Finally: `test/grid_building_test/integration/`

## Troubleshooting

### Common Issues and Solutions

#### 1. "Godot binary does not exist"

**Issue:** The test runner can't find Godot.

**Solutions:**
- Set the `GODOT` environment variable correctly
- Verify the path exists and is executable
- Use alternative variables: `GODOT_BIN` or ensure `godot` is in PATH

#### 2. Debug Breaks During Testing

**Issue:** Tests hang in debug breaks from assert statements.

**Solutions:**
- The test runner automatically handles debug breaks using `expect` when available
- Manual intervention may be needed if automation fails
- Remove or fix assert statements causing the breaks

#### 3. Path Conversion Issues (Windows)

**Issue:** Path errors like "Godot binary 'C:UserschrisAppData...' does not exist"

**Root Cause:** Backslashes in Windows paths get stripped by Git Bash.

**Solutions:** 
- **Always use forward slashes** in the GODOT environment variable: `C:/Users/username/...`
- See detailed guide: [Cross-Platform Path Handling](cross-platform-path-handling.md)

#### 4. Test File Not Found

**Issue:** Script can't find the test file.

**Solutions:**
- Provide full path: `test/grid_building_test/utilities/test_file.gd`
- Or just filename: `test_file.gd` (will be found automatically in `test/` directory)

#### 5. GdUnit CLI Execution Mode

**Important:** Do NOT attempt to run GdUnit CLI tests in headless mode. Always run tests with the standard Godot binary without headless flags.

### Validation Method Updates

- All GB systems and GB injectables now use `get_runtime_issues()` instead of `validate_state()`
- This returns `Array[String]` of validation issues (empty if valid)
- Update any test code that references the old method name

## Environment Variables for AI Assistants

- **Required Variables:** Always use environment variables like `%APPDATA%` or `$APPDATA` instead of hardcoded user paths
- **Godot Binary Priority:** The test runner checks these in order: `$GODOT` → `$GODOT_BIN` → `godot` (in PATH)
- **Never hardcode paths** like `C:/Godot/Godot4.exe` in test runners or shell scripts

## Test Development Best Practices

### Test Execution Policy

- Tests should be executed via shell commands to validate code changes
- User approval is required for shell command execution, but running tests is strongly encouraged
- Running tests ensures code quality and catches regressions early

### Test Discovery & Organization

- GdUnit automatically discovers and executes all test scripts by directory
- No need to create unified test suites
- Group tests by type in appropriate folders (geometry, rules, systems, etc.)

---

**Related Documents:**

- [copilot-instructions.md](../copilot-instructions.md) - Master project instructions
- [test-factory-guide.md](../project/test-factory-guide.md) - Test factory patterns
- [gdunit_runner_instructions.md](../../test/grid_building_test/docs/gdunit_runner_instructions.md) - GdUnit runner setup
- [copilot-gdscript-conventions.md](../copilot-gdscript-conventions.md) - GDScript conventions
