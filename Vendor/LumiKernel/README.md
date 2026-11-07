# LumiKernel

`LumiKernel` is a small, application-agnostic Swift package for composing
modular apps from typed providers and lifecycle-managed plugins.

The public library product and Swift module are both named `KernelCore`, so
existing hosts can continue to use:

```swift
import KernelCore
```

## Scope

`KernelCore` owns only generic runtime mechanisms:

- typed provider registration and resolution;
- plugin registration, dependency ordering, and lifecycle management;
- synchronous and asynchronous plugin phases;
- plugin enable-state persistence contracts;
- contribution ownership and rollback;
- typed event publishing and legacy notification bridging.

It does not define application providers, views, storage implementations,
logging frameworks, or UI contracts. Those belong in the host application or
in separate provider packages.

## Requirements

- Swift 6.0 or later
- macOS 14 or later
- iOS 17 or later
- No external package dependencies

## Usage

```swift
import KernelCore

@MainActor
protocol StorageProviding: AnyObject {
    func path(for pluginID: String) -> URL
}

@MainActor
let kernel = KernelCoreContainer()
try kernel.registerProvider(StorageProviding.self, storage)

if let storage = kernel.resolveProvider(StorageProviding.self) {
    print(storage.path(for: "com.example.feature"))
}
```

Plugins use the same container to register capabilities and participate in
startup and shutdown:

```swift
@MainActor
final class FeaturePlugin: SuperPlugin {
    let id = "com.example.feature"
    let metadata = PluginMetadata(
        id: "com.example.feature",
        name: "Feature",
        policy: .enabledByDefault
    )

    func onBoot(kernel: KernelCoreContainer) throws {
        // Register providers and contributions here.
    }
}

try kernel.start(plugins: [FeaturePlugin()])
try kernel.stop()
```

`dependencies` expresses hard plugin dependencies. `order` is only a stable
ordering preference among plugins whose dependencies are already satisfied.
Startup validates duplicate IDs, missing dependencies, and cycles before
booting; failures roll back the startup batch.

## Repository layout

- `Sources/KernelCore`: public runtime and contracts
- `Tests/KernelCoreTests`: lifecycle, registry, event, and rollback tests
- `Examples`: minimal host integration example

## Local development

```sh
swift test
```

This repository is currently consumed locally by the Coffic applications. A
remote GitHub package and semantic version tags will be added after the API
boundary has been validated across Lumi, GameFactory, GitOK, and Netto.
