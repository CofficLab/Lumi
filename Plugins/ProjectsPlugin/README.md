# ProjectsPlugin

Project management plugin for Lumi. Maintains the global recent projects list, provides a toolbar project selector, and supplies project context to agent tools.

## Features

- **Recent projects** — maintains a global list of recently opened projects
- **Toolbar selector** — project picker in the title toolbar when the active view supports it
- **Agent tools** — `list_projects`, `get_current_project`, `add_project` tools for agent use
- **Send middleware** — injects current project context into agent requests
- **Overlay guidance** — shows project selection guidance when no project is active

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](../../Packages/LumiUI) | UI components |
| [AgentToolKit](../../Packages/AgentToolKit) | Agent tool definitions |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **Title Toolbar View** — project selector in the title bar
- **Root View Overlay** — project selection overlay and guidance
- **Agent Tools** — project management tools for the AI assistant

### Project Structure

```
Sources/
├── ProjectsPlugin.swift        # Plugin entry point
└── ProjectsEvents.swift         # Project-related events
Tests/
└── ProjectsPluginTests/         # Unit tests
```

## License

Proprietary. All rights reserved.
