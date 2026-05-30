# PluginGitHubCLIDetect

`PluginGitHubCLIDetect` is the package-based GitHub CLI detection plugin for Lumi.

The package owns:

- `GitHubCLIDetectPlugin`: Lumi plugin entry point
- `GitHubCLICheckTool`: Agent tool adapter for `github_cli_check`
- `GitHubCLIDetectService`: `gh` installation, path, and version detection
- `Resources/GitHubCLIDetect.xcstrings`: plugin-owned localization catalog

The app should only keep a thin registration adapter while Lumi still discovers plugins from the `Lumi` module.

## Structure

```text
PluginGitHubCLIDetect
  Package.swift
  Sources/PluginGitHubCLIDetect
    Resources/GitHubCLIDetect.xcstrings
    GitHubCLICheckTool.swift
    GitHubCLIDetectPlugin.swift
    GitHubCLIDetectService.swift
  Tests/PluginGitHubCLIDetectTests
    GitHubCLIDetectPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginGitHubCLIDetect/Resources/GitHubCLIDetect.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginGitHubCLIDetectLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
