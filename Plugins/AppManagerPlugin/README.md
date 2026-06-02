# AppManagerPlugin

Manage installed applications for Lumi.

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
| [LumiUI](../../Packages/LumiUI) | UI components |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

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
