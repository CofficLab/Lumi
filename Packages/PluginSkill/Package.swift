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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderProject"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderSkill"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginSkill",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "LumiUI",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderProject",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                "ProviderSkill",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
            ],
            path: "Tests/PluginSkillTests"
        ),
    ]
)
