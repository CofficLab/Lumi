# SkillPlugin

Skill context plugin for Lumi. Loads project skills from `.agent/skills/`, injects their summaries into Agent prompts, and shows available skills in the status bar.

## Features

- **Skill discovery** - scans the current project's `.agent/skills/` directory
- **Prompt injection** - adds available skill summaries to transient system prompts
- **Language-aware prompts** - builds Chinese or English skill summaries from the current language preference
- **Status bar count** - shows the number of available skills for the current project
- **Skill popover** - displays skill title, version, and description
- **Poster view** - advertises the Skills feature in the plugin UI
- **Localization** - packages Skill string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [AgentToolKit](../../Packages/AgentToolKit) | Language preference types |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and send middleware types |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and status bar popover UI |
| [SkillKit](../../Packages/SkillKit) | Skill discovery and prompt building |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addPosterViews` | Adds the Skills plugin poster |
| `sendMiddlewares` | Registers `SkillSendMiddleware` |
| `addStatusBarTrailingView` | Adds the Skills status bar view |

## Policy

`.alwaysOn` - core skill context plugin that is always registered and cannot be disabled by users.

## Project Structure

```text
Sources/
+-- SkillPlugin.swift              # Plugin entry point
+-- Middleware/
    +-- SkillSendMiddleware.swift
+-- Views/
    +-- SkillStatusBarView.swift
+-- Resources/
    +-- Skill.xcstrings            # Localization strings
Tests/
+-- PluginSkillTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
