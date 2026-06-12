# FileLogPlugin

File logging plugin for Lumi. Collects current-process OSLog entries and writes them to disk with rotation and retention cleanup.

## Features

- **OSLog collection** - polls current-process OSLog entries for the Lumi subsystem
- **Disk persistence** - writes log records to plugin-owned log files
- **Log rotation** - creates a new log file on startup and when size limits are reached
- **Retention cleanup** - removes expired log files
- **Buffered ordering** - keeps recent records pending briefly so log lines are written chronologically
- **Config injection** - lets the app provide the log directory through `FileLogConfiguration`

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and policy types |
| [SuperLogKit](../../Packages/SuperLogKit) | Shared logging helpers |

## Lifecycle

| Hook | Description |
|------|-------------|
| `onEnable` | Starts `FileLogCoordinator` |
| `onDisable` | Stops `FileLogCoordinator` and flushes pending records |

## Policy

`.alwaysOn` - core system logging plugin that is always registered and cannot be disabled by users.

## Project Structure

```text
Sources/
+-- FileLogPlugin.swift          # Plugin entry point and lifecycle hooks
+-- FileLogCoordinator.swift     # OSLog polling, rotation, and cleanup
+-- FileLogConfiguration.swift   # Log directory configuration
Tests/
+-- PluginFileLogTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
