# PluginBrowserAgent

`PluginBrowserAgent` is the package-based Browser Agent plugin for Lumi.

The package exposes the plugin adapter and tool registration layer:

- `BrowserAgentPlugin`: Lumi plugin entry point
- `BrowserAgentTool`: Agent tool adapter for `browser_agent` (powered by agent-browser CLI)
- `Resources/BrowserAgent.xcstrings`: plugin-owned localization catalog

## Structure

```text
PluginBrowserAgent
  Package.swift
  Sources/PluginBrowserAgent
    Resources/BrowserAgent.xcstrings
    BrowserAgentPlugin.swift
    BrowserAgentTool.swift
  Tests/PluginBrowserAgentTests
    BrowserAgentPluginTests.swift
```

## Test

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/PluginBrowserAgent/Resources/BrowserAgent.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginBrowserAgentLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
