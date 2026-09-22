// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSkill",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
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
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderSkill"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginSkill",
            dependencies: [
                "KernelCore",
                "LumiUI",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderProject",
                "ProviderSettingView",
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
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
            ],
            path: "Tests/PluginSkillTests"
        ),
    ]
)
