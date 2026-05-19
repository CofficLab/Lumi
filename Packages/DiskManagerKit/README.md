# DiskManagerKit

可复用的磁盘分析与清理逻辑包。支持目录树扫描、大文件定位、缓存分析、项目依赖清理与 Xcode 清理候选检测。

## Package

- Product: `DiskManagerKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Source Layout

- `Models/`: disk, cache, cleanup, and Xcode clean item models.
- `Services/`: directory tree scanning, disk summaries, large file detection, cache cleanup, project cleanup, and Xcode cleanup.

## Testing

From this package directory:

```sh
swift test
```

Tests cover model behavior and service logic. Keep filesystem-heavy logic injectable or scoped to temporary directories so tests stay deterministic.

## Host integration

Use this package for reusable disk management behavior. Keep confirmation flows, UI presentation, and destructive-action permissions in the host app or plugin layer.
