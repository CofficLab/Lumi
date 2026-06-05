# ChatPanelPlugin

Chat workspace panel plugin for Lumi. Provides a dedicated activity-bar entry for conversation list with chat surface support.

## Features

- **Chat workspace** — dedicated activity-bar entry for conversations
- **Conversation list** — browse and manage chat sessions
- **AI Chat surface** — integrated AI chat support
- **Project toolbar** — project-specific toolbar integration
- **Empty state** — clean placeholder when no chat is active

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](../../Packages/LumiUI) | UI components |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **Chat Panel View** — main chat workspace interface

### Project Structure

```
Sources/
├── ChatPanelPlugin.swift                  # Plugin entry point
├── ChatPanelView.swift                    # Main chat panel view
├── ChatPanelSplitWidthPersistence.swift   # Split view width persistence
└── Resources/                             # Localizable strings
Tests/
└── ChatPanelPluginTests/                  # Unit tests
```

## License

Proprietary. All rights reserved.
