# LumiKitReminder

Shared break-reminder infrastructure for Lumi and its sibling applications.

The package exposes the `KitReminder` product and module. It is a reusable kit,
not a plugin, and contains no host-specific composition or UI contributions.

## Package

- Manifest package: `LumiKitReminder`
- Product / Target: `KitReminder`
- Platform: macOS 14+
- Swift tools: 6.0

## Features

- Cancellable reminder timers with sleep/wake catch-up.
- Pluggable production and test environments.
- Persistent active state, selected intervals, and custom intervals.
- Per-day reminder counters backed by plugin-scoped storage.
- Multi-screen reminder overlays with fade-in and fade-out animations.

## Swift Package integration

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiKitReminder.git", from: "1.0.0")
]
```

Then add the product to the consuming target:

```swift
.product(name: "KitReminder", package: "LumiKitReminder")
```

Hosts remain responsible for registering `StorageProviding`. Plugins pass their
plugin-scoped storage directory to `ReminderEnvironment.attachStateStore(directory:)`.

## Testing

```sh
swift test
```
