// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLifecycleHooks",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderLifecycleHooks", targets: ["ProviderLifecycleHooks"]),
    ],
    dependencies: [
        .package(path: "../KitLLM"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLifecycleHooks",
            dependencies: [
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/ProviderLifecycleHooks"
        ),
        .testTarget(
            name: "ProviderLifecycleHooksTests",
            dependencies: ["ProviderLifecycleHooks"]
        )
    ]
)
