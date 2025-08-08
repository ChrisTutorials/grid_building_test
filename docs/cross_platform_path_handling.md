# Cross-Platform Path Handling - Grid Building Plugin

**Reference:** This document addresses Windows path handling issues with Git Bash and VS Code tasks.

## Issue Summary

**Issue:** Windows file paths with backslashes get corrupted when passed through Git Bash shells, causing test execution failures.

**Example Error:**
```
Error: The specified Godot binary 'C:UserschrisAppDataRoaminggodotenvgodotbingodot' does not exist.
Converted path: 'C:UserschrisAppDataRoaminggodotenvgodotbingodot'
```

**Root Cause:** Backslashes (`\`) in Windows paths are interpreted as escape characters by bash, causing them to be stripped from the path.

## Solutions

### Environment Variable Path Format

**✅ CORRECT:** Use forward slashes in environment variables for cross-platform compatibility:

```bash
# Windows PowerShell/Command Prompt
set GODOT=C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot

# Or in PowerShell
$env:GODOT = "C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot"

# Linux/Mac
export GODOT="/path/to/godot/binary"
```

**❌ INCORRECT:** Using backslashes in environment variables:
```bash
set GODOT=C:\Users\chris\AppData\Roaming\godotenv\godot\bin\godot  # Gets corrupted in bash
```

### VS Code Tasks Configuration

Update `.vscode/tasks.json` to handle Windows paths properly:

```json
{
    "label": "Run GdUnit Test",
    "type": "shell",
    "command": "C:\\Program Files\\Git\\bin\\bash.exe",
    "args": [
        "--login",
        "-i",
        "./run_gdunit_test.sh",
        "'${file}'",
        "\"${env:GODOT}\""  // Double quotes protect the path
    ],
    "options": {
        "cwd": "${workspaceFolder}"
    },
    "group": {
        "kind": "test",
        "isDefault": true
    }
}
```

### Shell Script Improvements

The `run_gdunit_test.sh` script already contains Windows path conversion logic, but it requires properly formatted input paths.

**Key Requirements:**
1. Environment variables should use forward slashes
2. Paths should be quoted when passed to bash
3. The conversion logic handles both formats but works best with forward slashes

## Implementation Guidelines

### For AI Assistants

When documenting or suggesting environment variable paths:

1. **Always recommend forward slashes** for Windows paths in environment variables
2. **Quote paths** when passing them through shell commands
3. **Test path conversion** before assuming it works

### For Users

1. **Set GODOT environment variable** using forward slashes:
   ```
   C:/Users/username/AppData/Roaming/godotenv/godot/bin/godot
   ```

2. **Verify the path** works in both Command Prompt and Git Bash:
   ```bash
   echo $GODOT
   "$GODOT" --version
   ```

3. **Use quoted paths** in manual shell commands:
   ```bash
   ./run_gdunit_test.sh "test_file.gd" "C:/path/to/godot"
   ```

## Testing Path Conversion

To test if your environment is configured correctly:

```bash
# Check environment variable
echo "GODOT path: $GODOT"

# Test if file exists
if [ -f "$GODOT" ]; then
    echo "✅ Godot binary found"
    "$GODOT" --version
else
    echo "❌ Godot binary not found at: $GODOT"
fi
```

## Historical Context

### Failed Attempts (August 7, 2025)
- **Issue:** `GODOT=C:\Users\chris\AppData\Roaming\godotenv\godot\bin\godot`
- **Result:** Path corrupted to `C:UserschrisAppDataRoaminggodotenvgodotbingodot`
- **Solution:** Use forward slashes: `GODOT=C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot`

### Working Configuration
```bash
# Environment variable (forward slashes)
GODOT=C:/Users/chris/AppData/Roaming/godotenv/godot/bin/godot

# VS Code task passes quoted path
"${env:GODOT}"

# Shell script converts to appropriate format
```

## Related Issues

- **Git Bash Path Conversion:** Windows drives (C:) must be converted to Unix format (/c/)
- **Cygpath Availability:** Script falls back to manual conversion if `cygpath` is unavailable
- **File Extension:** Script automatically adds `.exe` if needed

---

**Related Documents:**
- [test_execution_guide.md](test_execution_guide.md) - Main test execution documentation
- [gdunit_runner_instructions.md](../../test/grid_building_test/docs/gdunit_runner_instructions.md) - GdUnit runner setup

**Enforcement:**
Always use forward slashes in environment variables when documenting cross-platform solutions.
