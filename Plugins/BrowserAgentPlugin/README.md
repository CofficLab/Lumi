# BrowserAgentPlugin

Browser automation plugin for Lumi. Provides the `browser_agent` agent tool, backed by the `agent-browser` CLI.

## Features

- **Browser automation tool** - registers `browser_agent` for agent workflows
- **Command execution** - forwards parsed commands to the `agent-browser` CLI
- **Safe timeout bounds** - clamps command timeouts to 1-300 seconds
- **CLI discovery** - searches common macOS install paths and login shell PATH
- **Localization** - packages Browser Agent string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+
- `agent-browser` CLI installed and available on PATH or a known install path

## Dependencies

| Package | Description |
|---------|-------------|
| [AgentToolKit](../../Packages/AgentToolKit) | Agent tool protocols and argument types |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and localization helpers |
| [ShellKit](../../Packages/ShellKit) | Shell command execution and command discovery |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `agentTools` | Registers the `browser_agent` tool |

## Policy

`.alwaysOn` - core browser automation plugin that is always registered and cannot be disabled by users.

## Structure

```text
BrowserAgentPlugin
  Package.swift
  Sources/
    Resources/BrowserAgent.xcstrings
    BrowserAgentPlugin.swift
    BrowserAgentTool.swift
  Tests/
    BrowserAgentPluginTests.swift
```

## Testing

```bash
swift test
```

## Localization

Package-owned translations live in `Sources/Resources/BrowserAgent.xcstrings`.

Code in this package should localize with `Bundle.module`, not the app main bundle. Use `PluginBrowserAgentLocalization.string(_:)` for plugin metadata so package tests and app integration read from the same resource bundle.
