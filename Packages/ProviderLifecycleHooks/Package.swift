// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLifecycleHooks",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderLifecycleHooks", targets: ["ProviderLifecycleHooks"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.0"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLifecycleHooks",
            dependencies: [
                .product(name: "KitLLM", package: "LumiKitLLM"),
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
