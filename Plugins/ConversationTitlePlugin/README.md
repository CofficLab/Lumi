# ConversationTitlePlugin

Conversation title plugin for Lumi. Provides the package entry point and title policy resources for automatic conversation title generation.

## Features

- **Auto title metadata** - declares the Conversation Title plugin for Agent chat
- **Title generation policy** - contains logic for deciding when a conversation should be auto-titled
- **Localization** - packages Conversation Title string resources with the plugin
- **Future middleware/tool sources** - source files exist for title middleware and title update tooling, but are currently excluded from this SwiftPM target

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [AgentToolKit](../../Packages/AgentToolKit) | Agent tool types used by excluded tool sources |
| [LLMKit](../../Packages/LLMKit) | LLM configuration types used by excluded middleware sources |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol, message, and chat context types |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

The packaged plugin currently returns no send middleware or agent tools because `Sources/Middleware` and `Sources/Tools` are excluded in `Package.swift`.

## Policy

`.alwaysOn` - core conversation title plugin that is always registered and cannot be disabled by users.

## Project Structure

```text
Sources/
+-- ConversationTitlePlugin.swift      # Plugin entry point
+-- Policy/
    +-- AutoConversationTitlePolicy.swift
+-- Resources/
    +-- ConversationTitle.xcstrings    # Localization strings
+-- Middleware/                        # Excluded from current target
+-- Tools/                             # Excluded from current target
Tests/
+-- PluginConversationTitleTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
