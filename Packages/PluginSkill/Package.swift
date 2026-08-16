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
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "PluginSkill",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderAgentLoop",
                "ProviderMessage",
                "ProviderProject",
            ],
            path: "Sources/PluginSkill"
        ),
        .testTarget(
            name: "PluginSkillTests",
            dependencies: [
                "PluginSkill",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Tests/PluginSkillTests"
        ),
    ]
)
