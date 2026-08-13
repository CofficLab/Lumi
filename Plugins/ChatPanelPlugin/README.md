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

This plugin integrates with the Lumi application by registering the Chat workspace
container. The workspace UI is composed by the always-on conversation, message,
input, and model-selector plugins.

### Project Structure

```
Resources/                                 # Localizable strings
Sources/
├── ChatPanelPlugin.swift                  # Plugin entry point
└── LumiPluginLocalization.swift           # Localized plugin strings
Tests/
├── ChatPanelLogicTests.swift              # Plugin logic tests
└── ChatSectionPluginTests.swift           # Chat section tests
```

## License

Proprietary. All rights reserved.
