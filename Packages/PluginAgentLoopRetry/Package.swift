// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentLoopRetry",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentLoopRetry", targets: ["PluginAgentLoopRetry"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "PluginAgentLoopRetry",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/PluginAgentLoopRetry"
        ),
        .testTarget(
            name: "PluginAgentLoopRetryTests",
            dependencies: [
                "PluginAgentLoopRetry",
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/PluginAgentLoopRetryTests"
        ),
    ]
)
