# AppManagerPlugin

Manage installed applications for Lumi.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Features

- **Application listing** — browse all installed macOS applications
- **App details** — view app size, version, and related files
- **App cache management** — scan and clean application cache
- **Application scanning** — scan the system for installed apps
- **Detailed app view** — comprehensive information for each application

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](https://github.com/CofficLab/LumiUI) | UI components |
| [KitSuperLog](../../Packages/KitSuperLog) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **App Manager View** — main interface for managing installed applications
- **Loading View** — displayed during app scanning
- **Scanning View** — progress indicator during app discovery
- **Empty View** — shown when no applications are found
- **Detail View** — detailed information for a selected app
- **App Row** — compact representation of an application

### Project Structure

```
Sources/
├── AppManagerPlugin.swift          # Plugin entry point
├── Models/
│   ├── AppModel.swift              # Application data model
│   ├── AppCacheItem.swift          # Cache item model
│   └── RelatedFile.swift           # Related file model
├── Services/
│   ├── AppService.swift            # Application listing service
│   ├── CacheManager.swift          # Cache management service
│   └── AppCleanerHelper.swift      # App cleaner helper
├── ViewModels/
│   └── AppManagerViewModel.swift   # View model
├── Views/
│   ├── AppManagerView.swift        # Main view
│   ├── AppManagerDetailView.swift  # Detail view
│   ├── AppManagerLoadingView.swift # Loading view
│   ├── AppManagerScanningView.swift# Scanning view
│   ├── AppManagerEmptyView.swift   # Empty view
│   └── AppRow.swift                # App row view
└── Resources/
    └── AppManager.xcstrings        # Localization strings
Tests/
└── AppManagerPluginTests/          # Unit tests
```

## License

Proprietary. All rights reserved.

