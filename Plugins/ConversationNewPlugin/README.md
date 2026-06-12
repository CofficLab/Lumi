# ConversationNewPlugin

New conversation plugin for Lumi. Provides the header toolbar button used to start a new AI chat conversation with the current project context.

## Features

- **New chat button** - adds a toolbar button for starting a fresh conversation
- **Project context forwarding** - passes selected project name and path into the new conversation
- **Language preference forwarding** - preserves the active project language preference
- **AI chat gating** - contributes UI only when the current plugin context supports AI chat
- **Localization** - packages Conversation New string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and chat/project context types |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addToolBarTrailingView` | Adds the new conversation toolbar button in AI chat contexts |

## Policy

`.alwaysOn` - core chat toolbar plugin that is always registered and cannot be disabled by users.

## Project Structure

```text
Sources/
+-- ConversationNewHeaderPlugin.swift # Plugin entry point
+-- ConversationNewRuntime.swift      # Runtime hook placeholder
+-- NewChatButton.swift               # Toolbar button view
+-- Resources/
    +-- ConversationNew.xcstrings     # Localization strings
Tests/
+-- PluginConversationNewTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
