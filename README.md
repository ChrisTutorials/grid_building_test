---
title: Test Runner Guide (Demo Project)
description: How to run the gdUnit4 test suite for the Grid Building demo and plugin.
---

This guide explains how contributors and demo users can run the plugin test-suite using the gdUnit4 GUI test runner. It follows the official gdUnit4 "first steps" and "getting started" guidance and documents the tested versions used for the demo project.

Versions
- gdUnit: `6.0.0`
- Godot: `4.4.1` (stable)
- Grid Building plugin: `5.0.0`

Overview

- The published demo project does not include custom shell scripts used on the author's workstation. Instead, use the Godot editor and the gdUnit4 GUI test interface to run tests in the demo.
- The test-suite lives in a separate repository: https://github.com/ChrisTutorials/grid_building_test
- When running tests against a released plugin, download the matching release from the `grid_building_test` repository releases and run the tests against the plugin version you have installed.

Download the test-suite

1. Open the test-suite repo in your browser: https://github.com/ChrisTutorials/grid_building_test
2. Switch to the `Releases` tab and download the release that matches the plugin version you want to test (for the demo site, use the release tagged for `v5.0.0`).
3. Extract the downloaded archive into a folder alongside your demo project, or clone the repository and checkout the release tag:

```
git clone https://github.com/ChrisTutorials/grid_building_test.git
cd grid_building_test
git checkout tags/v5.0.0
```

Install gdUnit4 (editor plugin)

Follow the official gdUnit4 installation steps. Short summary:

1. Open Godot Editor (4.4.1).
2. Open the Demo project or your local copy of the plugin project.
3. Install gdUnit4 as an EditorPlugin. See the official instructions: https://mikeschulze.github.io/gdUnit4/first_steps/getting-started/

Using the GUI Test Runner (recommended)

1. With the project open in the Godot editor, open the `Editor` → `Manage Plugins` and ensure `gdUnit4` is enabled.
2. Open the gdUnit4 dock (usually a panel in the editor). The UI exposes options to select test folders, run tests, and view results.
3. Point the test runner at the test-suite folder you downloaded or cloned (for example `res://../grid_building_test/test/` depending on where you placed the tests relative to the project). Use the gdUnit4 UI "Add" or "Select" folder control.
4. Run tests using the UI controls. You can run entire folders or single test files. Results and failure traces appear in the dock.

Notes about running tests in the demo project

- The demo project ships only the demo scenes and the plugin; it does not include author-specific shell scripts such as `run_tests_simple.sh`. Rely on the gdUnit4 GUI in the editor for a consistent experience across platforms.
- The tests may reference project paths or resources; ensure the demo project and the test-suite are positioned so `res://` references resolve to the expected files. If tests fail due to missing resources, double-check the repo layout.

Command-line / CI (optional)

- If you need to run tests outside the editor (CI), follow the official gdUnit4 documentation for headless or CLI runs: https://mikeschulze.github.io/gdUnit4/first_steps/settings/
- The demo project does not include the custom shell scripts used by the maintainers; for CI you'll need to adapt the project paths and the Godot executable path to your environment.

Troubleshooting

- Common issue: Tests can't find `res://` resources. Fix by ensuring the test-suite and/or plugin are imported in the same project workspace so `res://` paths match.
- Version mismatch: Always use the gdUnit release compatible with Godot `4.4.1` and the plugin version. The guide header lists the versions used for the demo.
- If a test fails due to engine differences, try running the failing test in isolation in the editor to see a full stack trace and scene state.

Further reading

- gdUnit4 first steps: https://mikeschulze.github.io/gdUnit4/first_steps/getting-started/
- gdUnit4 settings and headless/CI options: https://mikeschulze.github.io/gdUnit4/first_steps/settings/

If you'd like, I can also add a short troubleshooting checklist that lists common failing tests and how to rewire `res://` paths for the demo layout.
