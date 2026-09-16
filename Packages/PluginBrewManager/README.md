# BrewManagerPlugin

Homebrew package management plugin for Lumi. Provides a developer tool view for inspecting installed packages, checking updates, searching packages, and running install, uninstall, or upgrade actions through BrewKit.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

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
| [LumiUI](https://github.com/CofficLab/LumiUI) | Shared Lumi UI components and theming |
| [KitSuperLog](../../Packages/KitSuperLog) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addViewContainer` | Adds the Brew Manager developer tool view |

## Policy

`.optIn` - disabled by default and user-configurable, so users can enable it from plugin settings.

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

