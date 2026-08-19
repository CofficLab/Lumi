// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSkill",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginSkill", targets: ["PluginSkill"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
    ],
    targets: [
        .target(
            name: "PluginSkill",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderProject",
            ],
            path: "Sources/PluginSkill"
        ),
        .testTarget(
            name: "PluginSkillTests",
            dependencies: [
                "PluginSkill",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Tests/PluginSkillTests"
        ),
    ]
)
