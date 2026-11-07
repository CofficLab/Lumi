# LumiProviders

Shared provider contracts and default implementations used by Coffic Lab apps.

## Products

- `ProviderCommand`: application command registration and dispatch contracts.
- `ProviderContentView`: main content view registration and rendering.
- `ProviderDocsView`: plugin-contributed about and manual entries.
- `ProviderRailView`: shared rail tab registration, filtering, and rendering.
- `ProviderPluginControl`: plugin enablement and control contracts built on `LumiKernel`.
- `ProviderPluginManaging`: plugin listing, lifecycle management, and change observation.
- `ProviderRootView`: platform-neutral root view regions, overlays, trailing panes, and change observation.
- `ProviderStorage`: shared app storage and plugin enabled-state persistence.
- `ProviderStore`: in-app purchase and subscription contracts (tiers, entitlement, purchase presentation).
- `ProviderTheme`: shared theme values, built-in palettes, and theme selection state.
- `ProviderToast`: non-blocking toast presentation contracts.
- `ProviderToolbar`: shared toolbar item registration, filtering, and rendering.

Each product is an independent Swift module and can be added to a target separately.

## ProviderRootView

`ProviderRootView` defines the capabilities an app may expose from its root view without prescribing a single layout. It supports optional regions such as toolbar, activity bar, sidebar, rail, content header, content, footer, and status bar, plus ordered overlays and an optional trailing pane.

The contract is shared by macOS and iOS. Each app remains responsible for composing these regions with the layout system that fits its platform: AppKit-oriented layouts on macOS and adaptive SwiftUI layouts on iOS. Apps can implement only the regions they need, or use `DefaultRootViewProviding` for the built-in storage and observation behavior.

An app with a richer layout can subclass the default implementation and override only its root composition:

```swift
@MainActor
final class PluginRootView: DefaultRootViewProviding {
    override func makeRootView() -> AnyView {
        AnyView(MyPlatformRootLayout(
            toolbar: toolbarView,
            content: contentView,
            trailingPane: trailingPane
        ))
    }
}
```

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "ProviderCommand", package: "LumiProviders"),
            .product(name: "ProviderPluginManaging", package: "LumiProviders"),
            .product(name: "ProviderStorage", package: "LumiProviders"),
            .product(name: "ProviderTheme", package: "LumiProviders"),
        ]
    ),
]
```

## ProviderStore

`ProviderStore` defines the in-app purchase and subscription contracts that Coffic Lab apps share: subscription tiers, entitlement snapshots, entitlement observation, purchase presentation, and the product catalog contract.

The module is deliberately **contract-only**. It depends on Foundation alone — no StoreKit, no SwiftUI, no LumiUI, no `KernelCore` — so it can be adopted by any target (including unit tests) without dragging a purchase framework into the dependency graph. The StoreKit 2 lifecycle (transaction listening, entitlement calibration, product fetching, verification) lives in the separate [LumiStoreKit](https://github.com/CofficLab/LumiStoreKit) tool package.

### Types

- `StoreTier`: ordered subscription tier (`none` / `pro` / `ultimate`) with `isFree`, `isProOrHigher`, and `isUltimateOrHigher`, plus `defaultDisplayName` (English fallback; apps may override it with a localized version).
- `StoreEntitlementSnapshot`: value snapshot of `tier` + `expiresAt`. `effectiveTier` is the single source of truth for access decisions: **an expired subscription is equivalent to the free tier**, not "has bought before". Expiry keeps a 60-second grace period so a renewal is not misread as expired because of clock skew.
- `StoreEntitlementProviding`: the capability contract answering "what tier is the current user?". `entitlement` is the source of truth and `tier` is derived from it, so the two can never disagree about expiry.
- `StoreEntitlementEvent` / `StoreEntitlementObserverHandle`: typed change notification; the event carries only the new tier, never StoreKit transaction details.
- `StorePurchasePresenting`: the single action "please present the purchase panel". The store plugin is the only implementation; trigger points (limit reached, drop import) request presentation without knowing how it is rendered.
- `StoreProductSnapshot` / `StoreProductKind`: neutral product representation that does not expose `StoreKit.Product`.
- `StoreProductCatalog` / `StaticStoreProductCatalog`: the product-ID → tier mapping contract. Each app supplies its own ID table; `tier(for:)` denies unknown products by default rather than granting them.

### Usage

An app declares its own product table and implements the capability:

```swift
import ProviderStore

struct MyStoreCatalog: StoreProductCatalog {
    let productTiers: [String: StoreTier] = [
        "com.example.pro.monthly": .pro,
        "com.example.pro.yearly": .pro,
    ]
}

@MainActor
final class MyEntitlementProvider: StoreEntitlementProviding {
    var entitlement: StoreEntitlementSnapshot = .none

    func addObserver(
        _ callback: @escaping (StoreEntitlementEvent) -> Void
    ) -> any StoreEntitlementObserverHandle {
        // StoreKit-backed implementation; the contract only requires
        // that changes are published on the main thread.
        ...
    }
}
```

Consumers resolve the capability through the kernel and read one conclusion:

```swift
let tier = kernel.resolveProvider((any StoreEntitlementProviding).self)?.tier ?? .none
if tier.isFree {
    // Show the limit notice; request the purchase panel when tapped.
}
```

### Deriving an entitlement from a mechanism result

The StoreKit tool layer reports *which subscription product IDs are active and when they expire* — it knows nothing about tiers, which are product semantics. `StoreProductCatalog` provides the standard translation step:

```swift
let snapshot = catalog.entitlement(
    activeProductIDs: holding.activeSubscriptionProductIDs,
    latestExpiration: holding.latestExpiration
)
```

Products absent from the catalog resolve to no tier and are skipped, which is the guard against a paid purchase that grants nothing.

## Requirements

- Swift tools 6.0+
- macOS 14+
- iOS 17

## Tests

```sh
swift test
```
