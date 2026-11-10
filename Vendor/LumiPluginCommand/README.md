# LumiPluginCommand

Shared command super plugin for Lumi and its sibling applications.

The package exposes the `PluginCommand` product and module so existing hosts
can continue to use:

```swift
import PluginCommand
```

It provides:

- `CommandManager`, the default `CommandProviding` implementation that
  aggregates command groups registered by plugins across the app;
- `CommandPlugin`, a kernel super plugin that installs the command provider
  and the built-in Debug menu;
- localized Debug menu entries (open App Support / Container / Documents /
  Database directories);
- an optional DocsView "About" page contributed on macOS.

The plugin identifier defaults to `com.coffic.lumi.plugin.command`. Hosts with
their own namespace can preserve it by passing a custom bundle ID:

```swift
CommandPlugin(bundleID: "com.coffic.gitok.plugin.command")
```

## Requirements

- macOS 14+ / iOS 17+
- Swift 6.0

## Installation

```swift
.package(url: "https://github.com/CofficLab/LumiPluginCommand.git", from: "1.0.0")
```

## License

GPL-3.0
