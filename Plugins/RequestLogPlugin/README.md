# RequestLogPlugin

Request logging plugin for Lumi. Records chat request metadata and response previews for debugging and audit workflows.

## Features

- **Request middleware** - records HTTP request metadata after chat responses complete
- **Response previews** - stores response body size, preview text, and raw error detail when available
- **SwiftData history** - persists request logs in a plugin-owned database
- **Status bar browser** - exposes request log stats and paginated records from the Agent status bar
- **Filtering** - supports all, success, and failed request views
- **Retention controls** - caps stored records and cleans up older request log data
- **Localization** - packages Request Log string resources with the plugin

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [HttpKit](../../Packages/HttpKit) | HTTP request metadata captured by the middleware |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol, send middleware, and app config types |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and status bar popover UI |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `addPosterViews` | Adds the Request Log plugin poster |
| `sendMiddlewares` | Registers `RequestLogSuperSendMiddleware` |
| `addStatusBarTrailingView` | Adds the Request Log status bar browser in Agent contexts |

## Policy

`.alwaysOn` - core request logging plugin that is always registered and cannot be disabled by users.

## Project Structure

```text
Sources/
+-- RequestLogPlugin.swift              # Plugin entry point
+-- Middleware/
    +-- RequestLogSuperSendMiddleware.swift
+-- Models/
    +-- RequestLogItem.swift
    +-- RequestLogStats.swift
+-- Services/
    +-- RequestLogHistoryManager.swift
+-- ViewModels/
    +-- RequestLogBrowserViewModel.swift
+-- Views/
    +-- RequestLogDetailView.swift
    +-- RequestLogStatusBarView.swift
+-- Resources/
    +-- RequestLog.xcstrings            # Localization strings
Tests/
+-- PluginRequestLogTests.swift
+-- RequestLogItemDTOTests.swift
+-- RequestLogStatsTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
