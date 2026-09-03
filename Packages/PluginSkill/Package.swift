// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSkill",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginSkill", targets: ["PluginSkill"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginSkill",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderProject",
                "ProviderSkill",
                "KitLocalization",
            ],
            path: "Sources/PluginSkill",
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                .copy("../../Resources/BuiltinSkills"),
            ]
        ),
        .testTarget(
            name: "PluginSkillTests",
            dependencies: [
                "PluginSkill",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
            ],
            path: "Tests/PluginSkillTests"
        ),
    ]
)