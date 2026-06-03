# CaffeinatePlugin

Anti-sleep plugin for Lumi. Provides menu bar controls and agent tools for preventing macOS system sleep, optionally keeping the display awake or turning it off while the system remains active.

## Features

- **Sleep prevention** - creates macOS power assertions to keep the system awake
- **Display sleep control** - supports system-only mode or system-and-display mode
- **Timed sessions** - activates for a fixed duration or indefinitely
- **Menu bar popup** - exposes manual controls in the Lumi menu bar UI
- **Agent tools** - registers tools for activation, deactivation, status, and display sleep
- **Localization** - packages Caffeinate string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [AgentToolKit](../../Packages/AgentToolKit) | Agent tool protocols and argument types |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and localization helpers |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and theming |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addMenuBarPopupView` | Adds the Caffeinate menu bar popup view |
| `agentTools` | Registers Caffeinate agent tools |

## Agent Tools

| Tool | Description |
|------|-------------|
| `caffeinate_activate` | Activates sleep prevention with mode and duration options |
| `caffeinate_deactivate` | Restores normal system sleep behavior |
| `caffeinate_status` | Reports the current Caffeinate state |
| `caffeinate_turn_off_display` | Turns off the display while keeping the system awake |

## Policy

`.optOut` - enabled by default and user-configurable, so users can disable it from plugin settings.

## Project Structure

```text
Sources/
+-- CaffeinatePlugin.swift               # Plugin entry point
+-- CaffeinateManager.swift              # macOS power assertion manager
+-- CaffeinateMenuBarPopupView.swift     # Menu bar UI
+-- NotificationCenter+Caffeinate.swift  # Menu bar appearance notifications
+-- Resources/
    +-- Caffeinate.xcstrings             # Localization strings
+-- Tools/
    +-- CaffeinateActivateTool.swift
    +-- CaffeinateDeactivateTool.swift
    +-- CaffeinateStatusTool.swift
    +-- CaffeinateTurnOffDisplayTool.swift
Tests/
+-- PluginCaffeinateTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
