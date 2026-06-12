# BrewManagerPlugin

Homebrew package management plugin for Lumi. Provides a developer tool view for inspecting installed packages, checking updates, searching packages, and running install, uninstall, or upgrade actions through BrewKit.

## Features

- **Installed packages** - lists Homebrew formulae and casks installed on the system
- **Outdated packages** - shows packages with available updates
- **Package search** - searches Homebrew packages with stale-result handling
- **Package actions** - installs, uninstalls, upgrades single packages, or upgrades all outdated packages
- **Environment check** - detects whether Homebrew is installed before loading package data
- **Localization** - packages Brew Manager string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+
- Homebrew installed for live package operations

## Dependencies

| Package | Description |
|---------|-------------|
| [BrewKit](../../Packages/BrewKit) | Homebrew package service and models |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and localization helpers |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and theming |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addViewContainer` | Adds the Brew Manager developer tool view |

## Policy

`.optOut` - enabled by default and user-configurable, so users can disable it from plugin settings.

## Project Structure

```text
Sources/
+-- BrewManagerPlugin.swift           # Plugin entry point
+-- ViewModels/
    +-- BrewManagerViewModel.swift    # Package state and actions
+-- Views/
    +-- BrewManagerView.swift         # Main package manager UI
+-- Resources/
    +-- BrewManager.xcstrings         # Localization strings
Tests/
+-- PluginBrewManagerTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
