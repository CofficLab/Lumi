# DiskManagerPlugin

Disk management plugin for Lumi. Provides a system tool view for disk usage analysis, large file discovery, directory analysis, and cleanup workflows.

## Features

- **Disk usage overview** - shows total, used, and available disk space
- **Large file scan** - scans a selected path for large files
- **Directory analysis** - visualizes directory size breakdowns
- **Cache cleanup** - provides system cache cleaning views
- **Xcode cleanup** - groups Xcode-related cleanup targets
- **Project cleanup** - scans project directories for removable build artifacts
- **Finder integration** - reveals scanned files in Finder
- **Localization** - packages Disk Manager string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [DiskManagerKit](../../Packages/DiskManagerKit) | Disk scanning, usage, and cleanup services |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and localization helpers |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and theming |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addViewContainer` | Adds the Disk Manager system tool view |

## Policy

`.optOut` - enabled by default and user-configurable, so users can disable it from plugin settings.

## Project Structure

```text
Sources/
+-- DiskManagerPlugin.swift          # Plugin entry point
+-- ViewModels/                      # Disk, scan, and cleanup state
+-- Views/                           # Main disk manager and cleanup views
+-- Resources/
    +-- DiskManager.xcstrings        # Localization strings
Tests/
+-- PluginDiskManagerTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
