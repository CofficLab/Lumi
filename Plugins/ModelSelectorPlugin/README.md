# ModelSelectorPlugin

Model selector plugin for Lumi. Provides a toolbar button to select LLM provider and model, with agent tool support for programmatic model switching.

## Features

- **Model selector toolbar** — button in the sidebar toolbar to switch models
- **Model browser** — popover with provider and model list, latency info, and search
- **Frequent models** — quick access to frequently used models
- **Agent tool** — `switch_model` tool for programmatic model switching
- **Availability overlay** — graceful handling when model selector is unavailable

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](../../Packages/LumiUI) | UI components |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |
| [AgentToolKit](../../Packages/AgentToolKit) | Agent tool definitions |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **Sidebar Toolbar Button** — model selector button in AI chat sidebar
- **Agent Tool** — `switch_model` tool for automated model switching
- **Root View Wrapper** — availability overlay for the entire app

### Project Structure

```
Sources/
├── ModelSelectorPlugin.swift       # Plugin entry point
├── Models/                         # Data models for entries and tabs
├── Views/                          # UI views for selector, rows, toolbar
├── Support/                        # Compatibility helpers
└── Tools/                          # Agent tool implementations
Tests/
└── PluginModelSelectorTests/       # Unit tests
```

## License

Proprietary. All rights reserved.
