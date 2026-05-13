# DiskManagerKit

Disk analysis and cleanup logic for Lumi.

`DiskManagerKit` contains reusable services for inspecting disk usage, building directory trees, locating large files, analyzing caches, cleaning project dependencies, and handling Xcode cleanup candidates.

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

The tests cover model behavior and service logic. Keep filesystem-heavy logic injectable or scoped to temporary directories so tests stay deterministic.

## App Integration

Use this package for reusable disk management behavior. Keep confirmation flows, UI presentation, and destructive-action permissions in the app or plugin layer.
