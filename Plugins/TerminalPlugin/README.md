# TerminalPlugin

Native terminal plugin for Lumi. Provides a developer tool view with interactive terminal tabs powered by SwiftTerm and TerminalCoreKit.

## Features

- **Native terminal view** - embeds interactive terminal sessions in Lumi
- **Multiple tabs** - supports multiple terminal sessions with tab selection and close actions
- **Project working directory** - starts sessions in the current project directory when available
- **Persistent view model** - keeps terminal sessions alive across SwiftUI view rebuilds
- **Theme bridge** - lets the app provide the active editor theme for terminal rendering
- **Lifecycle cleanup** - closes all sessions when the plugin is disabled
- **Poster view** - advertises the Terminal feature in the plugin UI
- **Localization** - packages Terminal string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and project context types |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and theming |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |
| [TerminalCoreKit](../../Packages/TerminalCoreKit) | Terminal session and tab view model logic |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Native terminal emulator |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addPosterViews` | Adds the Terminal plugin poster |
| `addViewContainer` | Adds the Terminal developer tool view |

## Policy

`.optOut` - enabled by default and user-configurable, so users can disable it from plugin settings.

## Project Structure

```text
Sources/
+-- TerminalPlugin.swift                 # Plugin entry point
+-- ViewModels/
    +-- TerminalTabsViewModelSingleton.swift
+-- Views/
    +-- TerminalMainView.swift
    +-- TerminalTabItem.swift
+-- Resources/
    +-- Terminal.xcstrings               # Localization strings
Tests/
+-- PluginTerminalTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
