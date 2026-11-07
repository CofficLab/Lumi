# LumiPluginStorage

Shared storage super plugin for Lumi and its sibling applications.

The package exposes the `PluginStorage` product and module so existing hosts
can continue to use:

```swift
import PluginStorage
```

It provides:

- `StorageSuperPlugin`, which registers `StorageProviding` during kernel boot;
- `StorageService`, which scopes plugin and core data directories;
- `StoragePathResolver`, which exposes the same root convention to legacy hosts
  before they adopt the kernel lifecycle;
- a stable default root under Application Support, separated by bundle ID and
  debug/production major-version directories.

The storage contract remains in
[`LumiProviders`](https://github.com/CofficLab/LumiProviders), while this
package owns the default implementation and lifecycle registration.

## Swift Package integration

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiPluginStorage.git", from: "1.0.0")
]
```

Then add `PluginStorage` to the target dependencies and include
`try StorageSuperPlugin()` in the host's plugin factory.

Hosts that need a custom or test root can use:

```swift
try StorageSuperPlugin(dataRootDirectory: customRoot)
```

If the host already registered a `StorageProviding` implementation, the
shared plugin preserves it.

## Development

```sh
swift test
```
